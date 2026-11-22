extends TestCase
## Every track of the catalog (M5): the pit lane is usable and stays off the asphalt, the racing
## line is smooth and on the asphalt, an Expert bot drives clean laps in the expected time and the
## scenery has room for woods and stands.

const DT := 1.0 / 60.0
## Expected Expert lap (s) per track: Austria ~43, Australia ~49, China ~59 (tight T1-T2 spiral).
const EXPERT_LAP := {"austria": Vector2(41.0, 45.0), "australia": Vector2(46.5, 51.5), "china": Vector2(55.0, 62.0)}

var rules: RaceRules = load("res://data/race/race_rules.tres")
var tuning: CarTuning = load("res://data/car/car_tuning.tres")


func test_pit_lanes_are_usable_everywhere() -> void:
	for id in TrackCatalog.ids():
		var track := TrackCatalog.get_track(id)
		var lane := PitLane.build(track, rules)
		check(lane.length > 250.0, "%s: pit lane long enough (%.0f m)" % [id, lane.length])
		check(lane.box_count() >= 6, "%s: at least 6 garages (%d)" % [id, lane.box_count()])
		var query := TrackQuery.new()
		var closest := INF
		var s := 60.0
		while s < lane.length - 60.0:
			query.index = -1
			query.update(track, lane.position_at(s))
			closest = minf(closest, absf(query.lateral))
			s += 2.0
		check(closest > track.half_width() + TrackData.KERB_WIDTH + 2.0, "%s: pit lane off the asphalt (closest %.1f m)" % [id, closest])


func test_racing_lines_are_smooth_and_on_the_asphalt() -> void:
	for id in TrackCatalog.ids():
		var track := TrackCatalog.get_track(id)
		var line := RacingLine.for_track(track)
		var jump := 0.0
		var widest := 0.0
		for i in track.point_count():
			jump = maxf(jump, absf(line.curvatures[i] - line.curvatures[(i + 1) % track.point_count()]))
			widest = maxf(widest, absf(track.racing_line[i]))
		check(jump < 0.015, "%s: no kinks (%.4f)" % [id, jump])
		check(widest <= track.half_width() - 1.9, "%s: line on the asphalt (%.1f m)" % [id, widest])


func test_expert_bot_laps_cleanly_in_the_expected_time() -> void:
	for id in TrackCatalog.ids():
		var track := TrackCatalog.get_track(id)
		var racer := Racer.new("Bot", Color.BLUE, false)
		racer.car = Car.new()
		racer.car.setup(track, tuning, Color.BLUE)
		racer.car.place(track.length - 40.0, 0.0)
		racer.laps = LapTracker.new(track)
		racer.pit_stop = PitStop.new(PitLane.build(track, rules), rules, 0)
		racer.laps.line_crossed.connect(racer.car.kers.refill)
		racer.bot = BotDriver.new(RacingLine.for_track(track), tuning, BotDriver.Difficulty.EXPERT, 3)
		var time := 0.0
		var off := 0
		while racer.laps.laps < 2 and time < 200.0:
			time += DT
			var input := racer.bot.drive(racer, null, 3)
			racer.car.simulate(input, DT)
			racer.laps.update(racer.car.query.distance, time, DT)
			if absf(racer.car.query.lateral) - (track.half_width() + TrackData.KERB_WIDTH) > tuning.width * 0.5:
				off += 1
		var expected: Vector2 = EXPERT_LAP.get(id, Vector2(30.0, 80.0))
		check_eq(racer.laps.laps, 2, "%s: two laps done" % id)
		check_eq(off, 0, "%s: never off the track" % id)
		check(racer.laps.best_lap > expected.x and racer.laps.best_lap < expected.y, "%s: Expert lap %.2f s" % [id, racer.laps.best_lap])
		racer.car.free()


func test_scenery_fits_every_track() -> void:
	for id in TrackCatalog.ids():
		var track := TrackCatalog.get_track(id)
		var scenery := TrackScenery.new()
		scenery.setup(track, PitLane.build(track, rules))
		check(scenery.trees.size() > 100, "%s: woods (%d trees)" % [id, scenery.trees.size()])
		check(scenery.stands.size() >= 2, "%s: grandstands (%d)" % [id, scenery.stands.size()])
		scenery.free()
