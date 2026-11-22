extends TestCase
## KERS (3 uses per lap, one press = one use, refill at the line) and slipstream (1.5 s window,
## narrow cone, gradual fade, less drag = higher speed).

const DT := 1.0 / 60.0

var tuning: CarTuning = load("res://data/car/car_tuning.tres")


func _car(position: Vector2, speed: float) -> CarState:
	var state := CarState.new()
	state.position = position
	state.velocity = Vector2(speed, 0.0)
	return state


func test_kers_is_a_short_strong_burst() -> void:
	check(tuning.kers_duration <= 1.3 and tuning.kers_accel >= 3.5, "user 2026-11-22: half as long, stronger")


func test_three_uses_per_lap_and_refill() -> void:
	var kers := Kers.new(tuning)
	var state := CarState.new()
	for use in 4:
		kers.update(state, true, true, DT)  # press
		kers.update(state, true, true, DT)  # still held: no second use
		var active := kers.is_active()
		check_eq(active, use < tuning.kers_uses, "use %d %s" % [use + 1, "works" if use < 3 else "is refused"])
		for i in roundi(tuning.kers_duration / DT) + 2:
			kers.update(state, false, true, DT)
		check(not kers.is_active(), "burst ends after the duration")
	check_eq(kers.uses_left, 0, "all uses spent")
	kers.refill()
	check_eq(kers.uses_left, tuning.kers_uses, "new lap: uses back")


func test_boost_only_with_throttle_and_raises_top_speed() -> void:
	var kers := Kers.new(tuning)
	var state := CarState.new()
	kers.update(state, true, false, DT)
	check_eq(state.boost_accel, 0.0, "no boost without throttle")
	kers.update(state, true, true, DT)
	check_eq(state.boost_accel, tuning.kers_accel, "boost with throttle")
	var normal := _car(Vector2.ZERO, tuning.top_speed())
	var boosted := _car(Vector2.ZERO, tuning.top_speed())
	boosted.boost_accel = tuning.kers_accel
	var input := CarInput.new()
	input.throttle = true
	for i in roundi(tuning.kers_duration / DT):
		CarMotor.step(normal, input, tuning, DT)
		CarMotor.step(boosted, input, tuning, DT)
	check(boosted.velocity.x > normal.velocity.x + 2.0, "KERS adds speed at the top (%.1f vs %.1f)" % [boosted.velocity.x, normal.velocity.x])


func test_tow_only_close_behind_and_in_the_cone() -> void:
	var leader := _car(Vector2(100.0, 0.0), 60.0)
	var others: Array[CarState] = [leader]
	var close := _car(Vector2(80.0, 0.0), 60.0)  # ~0.25 s behind
	check(Slipstream.target(close, others, tuning) > 0.75, "close behind: strong tow")
	var far := _car(Vector2(100.0 - 60.0 * 1.6, 0.0), 60.0)  # 1.6 s behind
	check_eq(Slipstream.target(far, others, tuning), 0.0, "more than 1.5 s behind: no tow")
	var mid := _car(Vector2(100.0 - 60.0 * 1.0, 0.0), 60.0)
	var mid_tow := Slipstream.target(mid, others, tuning)
	check(mid_tow > 0.0 and mid_tow < 0.5, "1 s behind: weak tow (%.2f)" % mid_tow)
	var beside := _car(Vector2(80.0, 6.0), 60.0)
	check_eq(Slipstream.target(beside, others, tuning), 0.0, "pulled out to the side: no tow")
	var ahead := _car(Vector2(120.0, 0.0), 60.0)
	check_eq(Slipstream.target(ahead, others, tuning), 0.0, "the car in front gets no tow")
	var slow := _car(Vector2(90.0, 0.0), 10.0)
	check_eq(Slipstream.target(slow, others, tuning), 0.0, "no tow at low speed")


func test_tow_fades_gradually_after_pulling_out() -> void:
	var leader := _car(Vector2(100.0, 0.0), 60.0)
	var others: Array[CarState] = [leader]
	var me := _car(Vector2(85.0, 0.0), 60.0)
	for i in 60:
		Slipstream.update(me, others, tuning, DT)
	var full := me.tow
	check(full > 0.75 and me.drag_multiplier < 0.8, "in the tow the drag drops (%.2f)" % me.drag_multiplier)
	me.position.y = 8.0  # pull out to overtake
	for i in roundi(0.3 / DT):
		Slipstream.update(me, others, tuning, DT)
	check(me.tow > 0.2 and me.tow < full, "0.3 s after pulling out the tow is still fading (%.2f)" % me.tow)
	for i in roundi(1.0 / DT):
		Slipstream.update(me, others, tuning, DT)
	check_eq(me.tow, 0.0, "gone after about a second")
	check_eq(me.drag_multiplier, 1.0, "normal drag again")


func test_drafting_car_is_faster() -> void:
	var leader := _car(Vector2(30.0, 0.0), 80.0)
	var drafter := _car(Vector2(0.0, 0.0), 80.0)
	var others: Array[CarState] = [leader]
	var input := CarInput.new()
	input.throttle = true
	for i in roundi(1.0 / DT):
		Slipstream.update(drafter, others, tuning, DT)
		CarMotor.step(leader, input, tuning, DT)
		CarMotor.step(drafter, input, tuning, DT)
	check(drafter.velocity.x > leader.velocity.x + 1.0, "the tow pulls the car closer (%.1f vs %.1f)" % [drafter.velocity.x, leader.velocity.x])
