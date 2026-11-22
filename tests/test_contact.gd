extends TestCase
## CarCollision (soft contact, anti-ramming), IncidentJudge (penalties) and bots in traffic.

const DT := 1.0 / 60.0

var rules: RaceRules = load("res://data/race/race_rules.tres")
var tuning: CarTuning = load("res://data/car/car_tuning.tres")
var track := TrackCatalog.get_track("austria")


func _state(position: Vector2, speed: float, heading: float = 0.0) -> CarState:
	var state := CarState.new()
	state.position = position
	state.heading = heading
	state.velocity = Vector2.from_angle(heading) * speed
	return state


func test_hit_from_behind_slows_the_hitter_not_the_victim() -> void:
	var hitter := _state(Vector2(0, 0), 60.0)
	var victim := _state(Vector2(4.5, 0.3), 40.0)
	var states: Array[CarState] = [hitter, victim]
	var contacts := CarCollision.resolve(states, tuning, rules)
	check_eq(contacts.size(), 1, "one contact")
	check_eq(contacts[0].striker, 0, "the car behind is the striker")
	check(hitter.velocity.x < 45.0, "the hitter loses most of its speed (%.1f)" % hitter.velocity.x)
	check(victim.velocity.x < 45.0, "the victim is only nudged forward (%.1f)" % victim.velocity.x)
	check(absf(victim.velocity.y) <= rules.max_side_push + 0.01, "and barely sideways (%.2f)" % victim.velocity.y)


func test_side_by_side_contact_is_symmetric_and_limited() -> void:
	var left := _state(Vector2(0, 0), 50.0)
	var right := _state(Vector2(0.5, 1.6), 50.0)
	right.velocity.y = -8.0  # steering into the other car
	var states: Array[CarState] = [left, right]
	var contacts := CarCollision.resolve(states, tuning, rules)
	check_eq(contacts.size(), 1, "contact")
	check(absf(left.velocity.y) <= rules.max_side_push + 0.01, "the pushed car moves sideways at most %.1f m/s (%.2f)" % [rules.max_side_push, left.velocity.y])
	check(left.position.distance_to(right.position) > 1.6, "pushed apart")


func test_no_contact_when_apart() -> void:
	var states: Array[CarState] = [_state(Vector2(0, 0), 50.0), _state(Vector2(0, 3.0), 50.0)]
	check(CarCollision.resolve(states, tuning, rules).is_empty(), "3 m apart side by side: no contact")


func _racer(racer_name: String, distance: float, lateral: float) -> Racer:
	var racer := Racer.new(racer_name, Color.WHITE, false)
	racer.car = Car.new()
	racer.car.setup(track, tuning, Color.WHITE)
	racer.car.place(distance, lateral)
	racer.laps = LapTracker.new(track)
	racer.shortcuts = ShortcutCheck.new(rules)
	racer.pit_stop = PitStop.new(PitLane.build(track, rules), rules, 0)
	return racer


func test_judge_penalises_a_hard_hit_only_if_the_victim_suffers() -> void:
	var judge := IncidentJudge.new(rules)
	var striker := _racer("S", 300.0, 0.0)
	var victim := _racer("V", 305.0, 0.0)
	victim.car.state.velocity = victim.car.state.forward() * 50.0
	var contact := CarCollision.Contact.new()
	contact.striker = 0
	contact.closing_speed = 12.0
	judge.report(contact, striker, victim, 10.0)
	victim.car.state.velocity *= 0.5  # the victim is spun down by the hit
	judge.update(10.0 + rules.incident_check_time + 0.01)
	check_eq(striker.incident_penalty, rules.incident_penalty, "+5 s for the striker")
	check_eq(victim.incident_penalty, 0.0, "nothing for the victim")
	# Light touch: not judged.
	var light := CarCollision.Contact.new()
	light.striker = 0
	light.closing_speed = 2.0
	judge.report(light, striker, victim, 20.0)
	judge.update(25.0)
	check_eq(striker.incidents, 1, "a light touch is not penalised")
	# Second penalty in the same lap: ghost.
	judge.report(contact, striker, victim, 30.0)
	victim.car.state.on_track = false
	judge.update(30.0 + rules.incident_check_time + 0.01)
	check_eq(striker.incidents, 2, "second penalty")
	check(striker.ghost_until > 30.0 + rules.repeat_ghost_time - 0.1, "repeat in the same lap: ghost for 5 s")
	for racer: Racer in [striker, victim]:
		racer.car.free()


func test_faster_bot_overtakes_a_slower_one_cleanly() -> void:
	var line := RacingLine.for_track(track)
	var slow := _racer("Slow", track.length - 30.0, line.lateral(track.point_count() - 8))
	var fast := _racer("Fast", track.length - 60.0, line.lateral(track.point_count() - 15))
	slow.bot = BotDriver.new(line, tuning, BotDriver.Difficulty.EASY, 1)
	fast.bot = BotDriver.new(line, tuning, BotDriver.Difficulty.EXPERT, 2)
	var racers: Array[Racer] = [slow, fast]
	var judge := IncidentJudge.new(rules)
	var time := 0.0
	var passed_at := -1.0
	while time < 90.0:
		time += DT
		for racer in racers:
			var input := racer.bot.drive(racer, null, 5, racers, time)
			racer.car.simulate(input, DT)
			racer.laps.update(racer.car.query.distance, time, DT)
		var states: Array[CarState] = [slow.car.state, fast.car.state]
		for contact in CarCollision.resolve(states, tuning, rules):
			judge.report(contact, racers[contact.a], racers[contact.b], time)
		judge.update(time)
		if passed_at < 0.0 and fast.progress() > slow.progress() + 20.0:
			passed_at = time
	check(passed_at > 0.0, "Expert gets past Easy within 90 s (at %.1f s)" % passed_at)
	check_eq(fast.incidents + slow.incidents, 0, "without a penalised collision")
	for racer in racers:
		racer.car.free()
