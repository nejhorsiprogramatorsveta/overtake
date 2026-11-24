extends SceneTree
## Dev tool: measures for every BP board of a track how much later (or earlier, negative) than
## the ideal speed profile the real car (CarMotor, steered like a bot at full pace) can start
## braking and still stay on the asphalt and kerbs, and stores that minus a reaction margin in
## data/tracks/<id>.json as "bp_offsets" (TrackData.bp_offset_at, BrakingPoints). The car arrives
## faster than the profile like a player with the tow or KERS at the end of a long straight (up
## to SPEED_FACTOR, speed_factor(); user 2026-11-24: the last corner of Las Vegas at 320 km/h was
## far too late) and the margin is REACTION seconds at that speed. Run after the racing line changed:
##   tools/godot --headless --path . -s tools/bp_offsets.gd -- [--track=<id>]

const STEP := 5.0
const MIN_SHIFT := -30.0
const MAX_SHIFT := 80.0
## Extra entry speed: none below SLOW_ENTRY, SPEED_FACTOR from FAST_ENTRY (km/h; fast entry =
## long straight = most to gain from the tow and KERS).
const SPEED_FACTOR := 1.05
const SLOW_ENTRY := 230.0
const FAST_ENTRY := 310.0
const REACTION := 0.15


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
		var best := INF  # INF = even the earliest shift fails (probe start problem): keep the profile
		var shift := MIN_SHIFT
		var factor := speed_factor(bp.entry_speeds[b] * 3.6)
		while shift <= MAX_SHIFT and _clean(track, tuning, line, profile, lane, rules, bp.distances[b], shift, factor):
			best = shift
			shift += STEP
		var margin := REACTION * bp.entry_speeds[b] * factor
		var offset := 0.0 if best == INF else clampf(snappedf(best - margin, 1.0), MIN_SHIFT, MAX_SHIFT)
		offsets.append([snappedf(bp.distances[b], 0.1), offset])
		print("%s: BP %.0f m (%.0f km/h) -> %+.0f m (latest clean %+.0f)" % [id, bp.distances[b], bp.entry_speeds[b] * 3.6, offset, best])
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	data["bp_offsets"] = offsets
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(data, "", false) + "\n")


static func speed_factor(entry_kmh: float) -> float:
	return 1.0 + (SPEED_FACTOR - 1.0) * clampf((entry_kmh - SLOW_ENTRY) / (FAST_ENTRY - SLOW_ENTRY), 0.0, 1.0)


## Braking `delay` metres after the board, arriving `factor` faster: does the car stay on the
## asphalt and kerbs?
func _clean(track: TrackData, tuning: CarTuning, line: RacingLine, profile: SpeedProfile, lane: PitLane,
		rules: RaceRules, board: float, delay: float, factor: float) -> bool:
	var car := Car.new()
	car.setup(track, tuning, Color.WHITE, false)
	var begin := board - 120.0
	var index := track._index_at(fposmod(begin, track.length))
	car.place(begin, track.racing_line[index])
	var entry := profile.speeds[index] * factor
	car.state.velocity = Vector2.from_angle(car.state.heading) * entry
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
			# the tow / KERS keeps the extra speed up to the braking point
			car.state.velocity = car.state.velocity.normalized() * maxf(car.state.velocity.length(), entry)
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
