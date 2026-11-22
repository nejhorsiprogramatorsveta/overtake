extends TestCase
## CarMotor: acceleration, top speed, braking, the friction circle, gravel and reversing.

const DT := 1.0 / 60.0

var tuning: CarTuning = load("res://data/car/car_tuning.tres")


func _input(throttle: bool, brake: bool, steer: float = 0.0) -> CarInput:
	var input := CarInput.new()
	input.throttle = throttle
	input.brake = brake
	input.steer = steer
	return input


func _run(state: CarState, input: CarInput, seconds: float) -> void:
	for i in roundi(seconds / DT):
		CarMotor.step(state, input, tuning, DT)


func _moving(speed: float) -> CarState:
	var state := CarState.new()
	state.velocity = Vector2(speed, 0.0)
	return state


func test_accelerates_and_reaches_top_speed() -> void:
	var state := CarState.new()
	_run(state, _input(true, false), 3.0)
	check(state.velocity.x > 25.0 and state.velocity.x < 45.0, "0-3 s ends at 90-160 km/h (got %.1f m/s)" % state.velocity.x)
	_run(state, _input(true, false), 60.0)
	check(absf(state.velocity.x - tuning.top_speed()) < 1.0, "top speed matches tuning (%.1f vs %.1f)" % [state.velocity.x, tuning.top_speed()])
	check(absf(state.position.y) < 0.001 and absf(state.heading) < 0.0001, "drives straight without steering")


func test_braking_distance_is_realistic_but_short() -> void:
	var state := _moving(80.0)
	var start := state.position.x
	var ticks := 0
	while state.velocity.x > 0.0 and ticks < 1000:
		CarMotor.step(state, _input(false, true), tuning, DT)
		ticks += 1
	var distance := state.position.x - start
	check(distance > 70.0 and distance < 110.0, "288 km/h to 0 in 70-110 m (got %.1f m)" % distance)
	check_eq(state.velocity.x, 0.0, "braking stops the car without reversing")


func test_braking_while_turning_understeers() -> void:
	var turning := _moving(60.0)
	_run(turning, _input(false, false, 1.0), 1.0)
	var braking_turn := _moving(60.0)
	_run(braking_turn, _input(false, true, 1.0), 1.0)
	check(absf(turning.heading) > absf(braking_turn.heading) * 1.5,
			"full braking leaves much less grip for turning (%.2f vs %.2f rad)" % [turning.heading, braking_turn.heading])


func test_cornering_is_limited_by_grip() -> void:
	var state := _moving(60.0)
	_run(state, _input(true, false, 1.0), 0.5)
	var lateral_accel := state.velocity.length() * absf(state.heading) / 0.5
	check(lateral_accel <= tuning.grip * 1.05, "lateral acceleration stays within the grip (%.1f)" % lateral_accel)


func test_gravel_slows_the_car_down() -> void:
	var state := CarState.new()
	state.on_track = false
	_run(state, _input(true, false), 60.0)
	check(state.velocity.x < tuning.top_speed() * 0.45, "top speed off the track below 45 %% (got %.1f)" % state.velocity.x)
	var fast := _moving(80.0)
	fast.on_track = false
	_run(fast, _input(true, false), 2.0)
	check(fast.velocity.x < 50.0, "running wide at speed costs a lot of speed (got %.1f)" % fast.velocity.x)


func test_reverses_slowly_when_brake_held_at_standstill() -> void:
	var state := CarState.new()
	_run(state, _input(false, true), 5.0)
	check(state.velocity.x < -tuning.reverse_speed * 0.9 and state.velocity.x >= -tuning.reverse_speed - 0.01,
			"reverses up to the reverse speed (got %.1f)" % state.velocity.x)
	_run(state, _input(true, false), 0.5)
	check(state.velocity.x >= 0.0, "throttle stops the reversing car first")


func test_same_inputs_give_the_same_result() -> void:
	var a := _moving(30.0)
	var b := _moving(30.0)
	for i in 300:
		var input := _input(i % 7 != 0, i % 11 == 0, sin(i * 0.1))
		CarMotor.step(a, input, tuning, DT)
		CarMotor.step(b, input, tuning, DT)
	check(a.position == b.position and a.velocity == b.velocity and a.heading == b.heading, "deterministic")
