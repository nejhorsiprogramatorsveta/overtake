extends TestCase
## Every track of the catalog (M5): the pit lane is usable and stays off the asphalt, the racing
## line is smooth and on the asphalt, an Expert bot drives clean laps in the expected time and the
## scenery has room for woods and stands.

const DT := 1.0 / 60.0
## Expected Expert lap (s) per track: Austria ~43, Brazil ~45, China ~59 (tight T1-T2 spiral).
const EXPERT_LAP := {"austria": Vector2(41.0, 45.0), "brazil": Vector2(43.0, 48.0), "china": Vector2(55.0, 62.0), "las_vegas": Vector2(54.0, 60.0), "avus": Vector2(52.0, 58.0)}

## AVUS has only two braking zones (Nordkurve, Suedkurve hairpin).
const MIN_BOARDS := {"avus": 2}

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
		var pitted := 0
		while racer.laps.laps < 2 and time < 200.0:
			time += DT
			var input := racer.bot.drive(racer, null, 3)
			if racer.pit_stop.update(racer.car, input.clutch, DT):  # must not happen: no pit wanted
				pitted += 1
				racer.laps.update(racer.car.query.distance, time, DT)
				continue
			racer.car.simulate(input, DT)
			racer.laps.update(racer.car.query.distance, time, DT)
			if absf(racer.car.query.lateral) - (track.half_width() + TrackData.KERB_WIDTH) > tuning.width * 0.5:
				off += 1
		var expected: Vector2 = EXPERT_LAP.get(id, Vector2(30.0, 80.0))
		check_eq(racer.laps.laps, 2, "%s: two laps done" % id)
		check_eq(off, 0, "%s: never off the track" % id)
		check_eq(pitted, 0, "%s: no pit stop when not wanted (user 2026-11-24: Las Vegas bots kept pitting)" % id)
		check(racer.laps.best_lap > expected.x and racer.laps.best_lap < expected.y, "%s: Expert lap %.2f s" % [id, racer.laps.best_lap])
		racer.car.free()


## The pit entry is taken by position (PitLane.is_at_entry): the racing line must stay well away
## from the lane side there, or anybody on the line drives into the pits.
func test_racing_line_keeps_away_from_the_pit_entry() -> void:
	for id in TrackCatalog.ids():
		var track := TrackCatalog.get_track(id)
		var lane := PitLane.build(track, rules)
		var line := RacingLine.for_track(track)
		var closest := -INF
		for k in range(-15, 10):
			var index := track._index_at(fposmod(lane.entry_distance + k * 2.0, track.length))
			closest = maxf(closest, line.lateral(index) * lane.side)
		check(closest < track.half_width() - 5.0, "%s: line %.1f m towards the pit side at the entry (trigger at half width - 4)" % [id, closest])


func test_scenery_fits_every_track() -> void:
	for id in TrackCatalog.ids():
		var track := TrackCatalog.get_track(id)
		var scenery := TrackScenery.for_track(track)
		scenery.setup(track, PitLane.build(track, rules))
		if scenery is CityScenery:  # Las Vegas at night: buildings and the sphere instead of woods
			var city := scenery as CityScenery
			check(city.buildings.size() > 100, "%s: city blocks (%d buildings)" % [id, city.buildings.size()])
			check(city.sphere != Vector2.INF, "%s: the sphere has room" % id)
			check(city.sphere.distance_to(track.landmarks["sphere"]) < 60.0, "%s: the sphere near its real place" % id)
		else:
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
		var needed: int = MIN_BOARDS.get(id, 4)
		check(bp.count() >= needed, "%s: at least %d BP boards (%d)" % [id, needed, bp.count()])
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
	check(bp.distances[0] > 180.0, "China T1 board moved from 164 m to %.0f m" % bp.distances[0])


## User 2026-11-24: the last corner of Las Vegas at 320 km/h was far too late. The offsets are
## measured arriving faster (tow / KERS) with a reaction margin: this board stands earlier than
## the plain profile.
func test_fast_last_corner_in_las_vegas_has_an_early_board() -> void:
	var track := TrackCatalog.get_track("las_vegas")
	var line := RacingLine.for_track(track)
	var profile := line.profile(tuning)
	var lane := PitLane.build(track, rules)
	var measured := BrakingPoints.find(track, profile, rules.bp_min_speed_drop, lane)
	var offsets := track.bp_offsets
	track.bp_offsets = []
	var plain := BrakingPoints.find(track, profile, rules.bp_min_speed_drop, lane)
	track.bp_offsets = offsets
	var last := plain.count() - 1
	check(plain.entry_speeds[last] * 3.6 > 300.0, "the last corner comes after a very fast straight")
	check(measured.distances[last] < plain.distances[last], "board %.0f m before the plain profile" % (plain.distances[last] - measured.distances[last]))
