class_name Slipstream
## Slipstream / tow (PLAN.md B, user: "1.5 s behind the car in front"): a car right behind
## another car, within slip_time seconds and inside a narrow cone behind it, has less air
## drag. Leaving the cone does not cut the effect at once - the tow fades over ~0.8 s, so the
## car slows down gradually. Computed by every car for itself from the cars it sees, so it
## needs no network traffic.


## Target tow 0..1 behind the best car ahead (no smoothing).
static func target(me: CarState, others: Array[CarState], tuning: CarTuning) -> float:
	var speed := me.velocity.length()
	if speed < tuning.slip_min_speed:
		return 0.0
	var best := 0.0
	for leader in others:
		if leader == me:
			continue
		var leader_speed := leader.velocity.length()
		if leader_speed < tuning.slip_min_speed:
			continue
		var leader_forward := leader.forward()
		if leader_forward.dot(me.forward()) < 0.85:
			continue  # not driving the same way
		var behind := (leader.position - me.position).dot(leader_forward) - tuning.length
		if behind <= 0.0:
			continue  # level or ahead of the "leader"
		var gap := behind / leader_speed
		if gap >= tuning.slip_time:
			continue
		var lateral := absf((me.position - leader.position).dot(Vector2(-leader_forward.y, leader_forward.x)))
		if lateral > tuning.slip_half_width + behind * tuning.slip_widening:
			continue
		best = maxf(best, 1.0 - gap / tuning.slip_time)
	return best


## Moves the car's tow towards the target (quick build-up, slow fade) and sets its drag.
static func update(me: CarState, others: Array[CarState], tuning: CarTuning, dt: float) -> void:
	var wanted := target(me, others, tuning)
	var rate := tuning.slip_rise if wanted > me.tow else tuning.slip_decay
	me.tow = move_toward(me.tow, wanted, rate * dt)
	me.drag_multiplier = 1.0 - tuning.slip_drag_reduction * me.tow
