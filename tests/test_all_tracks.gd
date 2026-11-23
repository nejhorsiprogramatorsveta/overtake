extends TestCase
## Every track of the catalog (M5): the pit lane is usable and stays off the asphalt, the racing
## line is smooth and on the asphalt, an Expert bot drives clean laps in the expected time and the
## scenery has room for woods and stands.

const DT := 1.0 / 60.0
## Expected Expert lap (s) per track: Austria ~43, Brazil ~45, China ~59 (tight T1-T2 spiral).
const EXPERT_LAP := {"austria": Vector2(41.0, 45.0), "brazil": Vector2(43.0, 48.0), "china": Vector2(55.0, 62.0)}

var rules: RaceRules = load("res://data/race/race_rules.tres")
var tuning: CarTuning = load("res://data/car/car_tuning.tres")


func test_pit_lanes_are_usable_everywhere() -> void:
	for id in TrackCatalog.ids():
		var track := TrackCatalog.get_track(id)
		var lane := PitLane.build(track, rules)
		check(lane.length > 250.0, "%s: pit lane long enough (%.0f m)" % [id, lane.length])
		check(lane.box_count() >= LobbyValidator.MAX_CARS, "%s: a garage for every car (%d)" % [id, lane.box_count()])
		for box in lane.box_count():
			check(lane.is_full_offset(lane.box_distance(box)), "%s: garage %d beside the straight lane" % [id, box])
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


func test_bp_boards_stand_where_braking_starts_and_beside_their_own_part() -> void:
	# User 2026-11-22: some BP boards in China were "completely off".
	for id in TrackCatalog.ids():
		var track := TrackCatalog.get_track(id)
		var line := RacingLine.for_track(track)
		var lane := PitLane.build(track, rules)
		var bp := BrakingPoints.find(track, line.profile(tuning), rules.bp_min_speed_drop, lane)
		check(bp.count() >= 4, "%s: at least 4 BP boards (%d)" % [id, bp.count()])
		var reach := track.half_width() + TrackData.KERB_WIDTH + BpMarkers.BOARD_OFFSET
		for i in bp.count():
			var index := track._index_at(bp.distances[i])
			check(absf(line.curvatures[index]) <= 1.0 / BrakingPoints.MIN_START_RADIUS, "%s: BP at %.0f m starts before the corner" % [id, bp.distances[i]])
			check(bp.entry_speeds[i] - bp.corner_speeds[i] >= rules.bp_min_speed_drop, "%s: BP at %.0f m is a real braking zone" % [id, bp.distances[i]])
			if not bp.boards[i]:
				continue
			var query := TrackQuery.new()
			query.update(track, track.position_at(bp.distances[i], bp.sides[i] * reach))
			var along := absf(query.distance - bp.distances[i])
			check(minf(along, track.length - along) < BrakingPoints.OWN_PART, "%s: board at %.0f m beside its own part" % [id, bp.distances[i]])
			check(absf(query.lateral) > track.half_width() + TrackData.KERB_WIDTH, "%s: board at %.0f m off the asphalt" % [id, bp.distances[i]])
			var board := track.position_at(bp.distances[i], bp.sides[i] * (reach + BpMarkers.BOARD_SIZE.x * 0.5))
			var nearest := INF
			for point in lane.points:
				nearest = minf(nearest, point.distance_to(board))
			check(nearest >= BrakingPoints.PIT_CLEARANCE - 1.0, "%s: board at %.0f m off the pit lane (%.1f m)" % [id, bp.distances[i], nearest])


func test_bp_boards_move_earlier_with_worn_tyres() -> void:
	# User 2026-11-23: with tyre wear each player's own boards must move (RaceHudFeed per 1 % grip).
	for id in TrackCatalog.ids():
		var track := TrackCatalog.get_track(id)
		var line := RacingLine.for_track(track)
		var lane := PitLane.build(track, rules)
		var fresh := BrakingPoints.find(track, line.profile(tuning, 1.0), rules.bp_min_speed_drop, lane)
		var worn := BrakingPoints.find(track, line.profile(tuning, 0.8), rules.bp_min_speed_drop, lane)
		var earlier := 0
		for i in fresh.count():
			for j in worn.count():
				var apart := fresh.distances[i] - worn.distances[j]
				if apart > -5.0 and apart < 120.0:  # the same corner
					check(apart >= -0.01, "%s: worn tyres never move a board later (%.0f m)" % [id, fresh.distances[i]])
					if apart > 2.0:
						earlier += 1
		check(earlier >= fresh.count() / 2, "%s: most boards move earlier with worn tyres (%d of %d)" % [id, earlier, fresh.count()])


func test_measured_bp_offsets_move_boards_later_in_china() -> void:
	var track := TrackCatalog.get_track("china")
	check(track.bp_offset_at(164.0) >= 20.0, "China T1: the board stands later than the plain profile")
	var line := RacingLine.for_track(track)
	var bp := BrakingPoints.find(track, line.profile(tuning), rules.bp_min_speed_drop, PitLane.build(track, rules))
	check(bp.distances[0] > 190.0, "China T1 board moved from 164 m to %.0f m" % bp.distances[0])
