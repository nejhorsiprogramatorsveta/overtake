extends TestCase
## Bots drive clean laps by the racing line; harder bots are faster; Expert is near the target
## lap time (Austria ~45 s); bots start on the lights and pit for new tyres.

const DT := 1.0 / 60.0

var rules: RaceRules = load("res://data/race/race_rules.tres")
var tuning: CarTuning = load("res://data/car/car_tuning.tres")
var track := TrackCatalog.get_track("austria")


func _bot(difficulty: BotDriver.Difficulty, wear: bool = false) -> Racer:
	var racer := Racer.new("Bot", Color.BLUE, false)
	racer.car = Car.new()
	racer.car.setup(track, tuning, Color.BLUE, wear)
	racer.car.place(track.length - 40.0, 0.0)
	racer.laps = LapTracker.new(track)
	racer.shortcuts = ShortcutCheck.new(rules)
	racer.pit_stop = PitStop.new(PitLane.build(track, rules), rules, 0)
	racer.laps.line_crossed.connect(racer.car.kers.refill)
	racer.bot = BotDriver.new(RacingLine.for_track(track), tuning, difficulty, 7)
	return racer


## Drives until `laps` laps are done (or the time runs out); returns the race time.
## Ticks with the whole car beyond the kerb in the last _run.
var off_track_ticks := 0


func _run(racer: Racer, laps: int, max_seconds: float, laps_left: int = 3) -> float:
	var time := 0.0
	off_track_ticks = 0
	while racer.laps.laps < laps and time < max_seconds:
		time += DT
		var input := racer.bot.drive(racer, null, laps_left)
		if racer.pit_stop.update(racer.car, input.clutch, DT):
			racer.laps.update(racer.car.query.distance, time, DT)
			continue
		racer.car.simulate(input, DT)
		racer.laps.update(racer.car.query.distance, time, DT)
		var beyond := absf(racer.car.query.lateral) - (track.half_width() + TrackData.KERB_WIDTH)
		if beyond > tuning.width * 0.5:
			off_track_ticks += 1
	return time


func test_bots_drive_clean_laps_and_harder_is_faster() -> void:
	var times := {}
	for difficulty: BotDriver.Difficulty in [BotDriver.Difficulty.EASY, BotDriver.Difficulty.EXPERT]:
		var racer := _bot(difficulty)
		_run(racer, 2, 150.0)
		check_eq(racer.laps.laps, 2, "difficulty %d completes two laps" % difficulty)
		check(off_track_ticks == 0, "difficulty %d stays on the track (%d ticks off)" % [difficulty, off_track_ticks])
		times[difficulty] = racer.laps.best_lap
		racer.car.free()
	check(times[BotDriver.Difficulty.EXPERT] < times[BotDriver.Difficulty.EASY] - 2.0,
			"Expert faster than Easy (%.2f vs %.2f)" % [times[BotDriver.Difficulty.EXPERT], times[BotDriver.Difficulty.EASY]])
	check(times[BotDriver.Difficulty.EXPERT] > 41.0 and times[BotDriver.Difficulty.EXPERT] < 44.5,
			"Expert lap clearly under the 45 s target (user 2026-11-22: Expert was too easy) (%.2f)" % times[BotDriver.Difficulty.EXPERT])


func test_bot_reacts_to_the_lights() -> void:
	var racer := _bot(BotDriver.Difficulty.HARD)
	var start := RaceStart.new(rules, 5)
	while start.time < 20.0 and racer.start_entry.held:
		start.update(DT)
		var input := racer.bot.drive(racer, start, 3)
		start.update_entry(racer.start_entry, input.clutch)
	check(not racer.start_entry.held, "the bot leaves the grid")
	check(not racer.start_entry.jump_start, "no jump start")
	check(racer.start_entry.reaction > 0.1 and racer.start_entry.reaction < 0.5, "human-like reaction (%.3f)" % racer.start_entry.reaction)
	racer.car.free()


func test_bot_pits_for_new_tyres() -> void:
	var racer := _bot(BotDriver.Difficulty.MEDIUM, true)
	racer.car.tyres.condition = 0.25
	_run(racer, 1, 120.0)
	check_eq(racer.pit_stop.stops, 1, "worn tyres: one pit stop")
	check(racer.car.tyres.condition > 0.8, "new tyres on")
	racer.car.free()


func test_racing_line_is_smooth_and_wider_than_the_centre_line() -> void:
	# User 2026-11-22: the old line kinked at the apex (radius 11 m in a 17 m hairpin), so the
	# bots braked in odd places. The line must corner wider than the centre line, without kinks.
	var line := RacingLine.for_track(track)
	var n := track.point_count()
	var line_max := 0.0
	var centre_max := 0.0
	var jump := 0.0
	for i in n:
		line_max = maxf(line_max, absf(line.curvatures[i]))
		centre_max = maxf(centre_max, absf(track.curvatures[i]))
		jump = maxf(jump, absf(line.curvatures[i] - line.curvatures[(i + 1) % n]))
		check(absf(track.racing_line[i]) <= track.half_width() - 1.9, "line keeps the car on the asphalt at %d" % i)
	check(1.0 / line_max > 1.5 / centre_max, "tightest radius %.1f m vs centre %.1f m" % [1.0 / line_max, 1.0 / centre_max])
	check(jump < 0.01, "no kinks (largest curvature step %.4f)" % jump)
	var ideal := line.profile(tuning).lap_time
	var centre := SpeedProfile.compute(track, tuning).lap_time
	check(ideal < centre - 5.0, "the line is much faster than the centre (%.1f vs %.1f s)" % [ideal, centre])


func test_slow_bots_corner_slower_but_not_on_the_straights() -> void:
	var line := RacingLine.for_track(track)
	var full := line.profile(tuning)
	var slow := line.profile(tuning, 1.0, 0.5)
	var full_top := 0.0
	var slow_top := 0.0
	var slowest := 0
	for i in track.point_count():
		full_top = maxf(full_top, full.speeds[i])
		slow_top = maxf(slow_top, slow.speeds[i])
		if full.speeds[i] < full.speeds[slowest]:
			slowest = i
	# Only the slower corner exit costs a little top speed; the old pace scaling capped it at pace.
	check(slow_top > full_top * 0.93, "nearly the same speed on the straights (%.1f vs %.1f)" % [slow_top, full_top])
	check(slow.speeds[slowest] < full.speeds[slowest] * 0.8, "slower in the corners")
	# An Easy bot at its planned speed on the fastest straight keeps the throttle (no braking).
	var fastest := 0
	for i in track.point_count():
		if full.speeds[i] > full.speeds[fastest]:
			fastest = i
	var racer := _bot(BotDriver.Difficulty.EASY)
	racer.car.place(track.distances[(fastest - 3 + track.point_count()) % track.point_count()], track.racing_line[fastest])
	racer.car.state.velocity = Vector2.from_angle(racer.car.state.heading) * full.speeds[fastest] * 0.97
	var input := racer.bot.drive(racer, null, 3)
	check(not input.brake, "no braking on the straight")
	racer.car.free()


func test_bot_brakes_for_a_braking_car_ahead() -> void:
	# Same speed, but the car ahead brakes hard: the bot must not wait until it is slower.
	var bot := _bot(BotDriver.Difficulty.EXPERT)
	var leader := _bot(BotDriver.Difficulty.EASY)
	var straight := 0
	var full := RacingLine.for_track(track).profile(tuning)
	for i in track.point_count():
		if full.speeds[i] > full.speeds[straight]:
			straight = i
	var d := track.distances[straight] - 60.0
	bot.car.place(d, track.racing_line[straight])
	leader.car.place(d + 16.0, track.racing_line[straight])
	for racer in [bot, leader]:
		racer.car.state.velocity = Vector2.from_angle(racer.car.state.heading) * 60.0
	leader.car.state.accel = -30.0
	var others: Array[Racer] = [bot, leader]
	check(bot.bot.drive(bot, null, 3, others).brake, "brakes behind a braking car")
	leader.car.state.accel = 0.0
	check(not bot.bot.drive(bot, null, 3, others).brake, "no braking behind a car at the same speed")
	bot.car.free()
	leader.car.free()
