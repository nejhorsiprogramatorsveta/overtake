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
	racer.limits = TrackLimits.new(rules)
	racer.pit_stop = PitStop.new(PitLane.build(track, rules), rules, 0)
	racer.laps.line_crossed.connect(racer.car.kers.refill)
	racer.bot = BotDriver.new(RacingLine.for_track(track), tuning, difficulty, 7)
	return racer


## Drives until `laps` laps are done (or the time runs out); returns the race time.
func _run(racer: Racer, laps: int, max_seconds: float, laps_left: int = 3) -> float:
	var time := 0.0
	while racer.laps.laps < laps and time < max_seconds:
		time += DT
		var input := racer.bot.drive(racer, null, laps_left)
		if racer.pit_stop.update(racer.car, input.clutch, DT):
			racer.laps.update(racer.car.query.distance, time, DT)
			continue
		racer.car.simulate(input, DT)
		racer.laps.update(racer.car.query.distance, time, DT)
		racer.limits.update(track, racer.car.query, tuning.width, racer.car.state.velocity.length() * DT)
	return time


func test_bots_drive_clean_laps_and_harder_is_faster() -> void:
	var times := {}
	for difficulty: BotDriver.Difficulty in [BotDriver.Difficulty.EASY, BotDriver.Difficulty.EXPERT]:
		var racer := _bot(difficulty)
		_run(racer, 2, 150.0)
		check_eq(racer.laps.laps, 2, "difficulty %d completes two laps" % difficulty)
		check(racer.limits.violations == 0, "difficulty %d stays inside the track limits (%d)" % [difficulty, racer.limits.violations])
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
