extends TestCase
## Pit lane geometry, the pit stop minigame and the autopilot through the pit lane.

const DT := 1.0 / 60.0

var rules: RaceRules = load("res://data/race/race_rules.tres")
var tuning: CarTuning = load("res://data/car/car_tuning.tres")
var track := TrackCatalog.get_track("austria")


func test_pit_lane_runs_along_the_main_straight_on_the_inside() -> void:
	var lane := PitLane.build(track, rules)
	check_eq(lane.side, 1.0, "Austria runs clockwise: pit lane on the right (inside)")
	check(lane.length > 250.0, "long enough (%.0f m)" % lane.length)
	check(lane.box_count() >= 6, "room for at least 6 garages (%d)" % lane.box_count())
	var query := TrackQuery.new()
	query.update(track, lane.position_at(lane.length * 0.5))
	check(absf(query.lateral - lane.lane_lateral()) < 1.0, "middle of the lane is beside the track")
	query.index = -1
	query.update(track, lane.position_at(0.0))
	check(absf(query.lateral) < track.half_width(), "the entry starts on the asphalt")


func test_late_press_is_fast_early_press_slow_no_press_fumble() -> void:
	var results := {}
	for press_bar: float in [0.95, 0.1, 2.0]:
		var game := PitMinigame.new(rules)
		while not game.finished():
			game.update(DT, game.bar() >= press_bar and game.elapsed >= rules.pit_prepare)
		results[press_bar] = game.elapsed
		if press_bar > 1.0:
			check(game.fumbled, "no press: fumble")
	check(results[0.95] < 2.4, "late press: about 2 s (%.2f)" % results[0.95])
	check(results[0.1] > 4.0, "early press: slow (%.2f)" % results[0.1])
	check(results[2.0] >= rules.pit_worst + rules.pit_fumble - 0.02, "fumble: +3 s (%.2f)" % results[2.0])


func test_space_held_from_before_does_not_count() -> void:
	var game := PitMinigame.new(rules)
	var lane := PitLane.build(track, rules)
	var stop := PitStop.new(lane, rules, 0)
	stop.phase = PitStop.Phase.STOPPED
	stop.minigame = game
	stop._was_pressed = true
	var car := _car(lane)
	for i in 10:
		stop.update(car, true, DT)  # still holding Space from the start/before
	check_eq(game.pressed_at, -1.0, "holding Space is not a press")
	car.free()


func test_autopilot_takes_the_car_through_the_pit_lane() -> void:
	var lane := PitLane.build(track, rules)
	var car := _car(lane)
	car.place(lane.entry_distance, lane.side * (track.half_width() - 2.0))
	car.state.velocity = car.state.forward() * 60.0
	car.tyres.condition = 0.4
	var stop := PitStop.new(lane, rules, 2)
	var ticks := 0
	var entered := false
	var max_speed_in_lane := 0.0
	var stopped_ticks := 0
	while ticks < 60 * 40:
		ticks += 1
		var press := stop.phase == PitStop.Phase.STOPPED and stop.minigame.bar() > 0.9
		if stop.update(car, press, DT):
			entered = true
			if stop.phase == PitStop.Phase.IN_LANE and stop.s > rules.pit_blend:
				max_speed_in_lane = maxf(max_speed_in_lane, stop.speed)
			if stop.phase == PitStop.Phase.STOPPED:
				stopped_ticks += 1
		elif entered:
			break
	check(entered, "turning in hands the car to the autopilot")
	check(not stop.active(), "the car is released at the lane end")
	check(max_speed_in_lane <= rules.pit_speed + 0.01, "speed limit kept")
	check(stopped_ticks * DT > 1.8 and stopped_ticks * DT < 2.6, "about 2 s in the box (%.2f)" % (stopped_ticks * DT))
	check_eq(car.tyres.condition, 1.0, "new tyres")
	var query := TrackQuery.new()
	query.update(track, car.state.position)
	check(absf(query.lateral) < track.half_width(), "back on the track")
	check(car.state.velocity.length() > 15.0, "leaves at pit speed")
	car.free()


func _car(lane: PitLane) -> Car:
	var car := Car.new()
	car.setup(track, tuning, Color.RED, true)
	return car
