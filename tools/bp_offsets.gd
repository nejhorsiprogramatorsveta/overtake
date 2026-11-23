extends SceneTree
## Dev tool: measures for every BP board of a track how much later than the ideal speed profile
## the real car (CarMotor, steered like a bot at full pace) can start braking and still stay on
## the asphalt and kerbs, and stores that minus SAFETY metres in data/tracks/<id>.json as
## "bp_offsets" (TrackData.bp_offset_at, BrakingPoints). Run after the racing line changed:
##   tools/godot --headless --path . -s tools/bp_offsets.gd -- [--track=<id>]

const STEP := 5.0
const MAX_SHIFT := 80.0
const SAFETY := 5.0


func _initialize() -> void:
	var only := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--track="):
			only = argument.trim_prefix("--track=")
	for id in TrackCatalog.ids():
		if only.is_empty() or id == only:
			_measure(id)
	quit()


func _measure(id: String) -> void:
	var path := "res://data/tracks/%s.json" % id
	var track := TrackData.load_file(path)
	track.bp_offsets.clear()  # measure from the plain profile
	var tuning: CarTuning = load("res://data/car/car_tuning.tres")
	var rules: RaceRules = load("res://data/race/race_rules.tres")
	var line := RacingLine.new()
	line.track = track
	for i in track.point_count():
		line.points.append(track.points[i] + track.normal(i) * track.racing_line[i])
	line.curvatures = TrackData.curvatures_of(line.points)
	var profile := line.profile(tuning)
	var lane := PitLane.build(track, rules)
	var bp := BrakingPoints.find(track, profile, rules.bp_min_speed_drop, lane)
	var offsets := []
	for b in bp.count():
		var best := 0.0
		var shift := STEP
		while shift <= MAX_SHIFT and _clean(track, tuning, line, profile, lane, rules, bp.distances[b], shift):
			best = shift
			shift += STEP
		var offset := maxf(best - SAFETY, 0.0)
		offsets.append([snappedf(bp.distances[b], 0.1), offset])
		print("%s: BP %.0f m -> %.0f m later" % [id, bp.distances[b], offset])
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	data["bp_offsets"] = offsets
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(data, "", false) + "\n")


## Braking `delay` metres after the board: does the car stay on the asphalt and kerbs?
func _clean(track: TrackData, tuning: CarTuning, line: RacingLine, profile: SpeedProfile, lane: PitLane,
		rules: RaceRules, board: float, delay: float) -> bool:
	var car := Car.new()
	car.setup(track, tuning, Color.WHITE, false)
	var begin := board - 120.0
	var index := track._index_at(fposmod(begin, track.length))
	car.place(begin, track.racing_line[index])
	car.state.velocity = Vector2.from_angle(car.state.heading) * profile.speeds[index]
	var racer := Racer.new("probe", Color.WHITE, false)
	racer.car = car
	racer.pit_stop = PitStop.new(lane, rules, 0)
	var bot := BotDriver.new(line, tuning, BotDriver.Difficulty.EXPERT, 1)
	bot.pace = 1.0
	bot.wobble = 0.0
	var travelled := 0.0
	var ok := true
	for tick in 60 * 15:
		var input := bot.drive(racer, null, 0)
		var into := fposmod(car.query.distance - board + 200.0, track.length) - 200.0
		if into < delay:
			input.brake = false
			input.throttle = true
		var before := car.state.position
		car.simulate(input, 1.0 / 60.0)
		travelled += before.distance_to(car.state.position)
		if absf(car.query.lateral) > track.half_width() + TrackData.KERB_WIDTH:
			ok = false
			break
		if travelled > 120.0 + delay + 350.0:
			break
	car.free()
	return ok
