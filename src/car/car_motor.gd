class_name CarMotor
## Shared, deterministic car physics for players, bots and the network (no scene access).
## Top-down "arcade-sim" model (PLAN.md B):
## - engine power / speed, limited by traction, + KERS boost; air drag × speed² (less in a tow);
## - softened FRICTION CIRCLE: braking/accelerating takes part of the cornering grip
##   (CarTuning.combined_grip), so braking hard while steering understeers a little -> brake
##   mostly in a straight line at the BP board, but the car still turns under braking;
## - more cornering grip at low speed (slow corners feel nimble, CarTuning.cornering_grip);
## - the same grip everywhere on the asphalt, less grip and strong drag off it (gravel);
## - worn tyres (CarState.grip_multiplier) lower the grip and the brakes;
## - the steering angle shrinks with speed; the velocity follows the heading (grip), any
##   sideways speed (e.g. after contact) is scrubbed off by the remaining grip.


## Below this speed (m/s) full throttle spins the rear wheels a little (look only).
const WHEELSPIN_SPEED := 14.0


static func step(state: CarState, input: CarInput, tuning: CarTuning, dt: float) -> void:
	var forward := state.forward()
	var right := Vector2(-forward.y, forward.x)
	var v_long := state.velocity.dot(forward)
	var v_lat := state.velocity.dot(right)
	var speed := absf(v_long)
	var surface := (1.0 if state.on_track else tuning.runoff_grip) * state.grip_multiplier
	var grip := tuning.grip * surface

	state.steer = move_toward(state.steer, clampf(input.steer, -1.0, 1.0), tuning.steer_speed * dt)

	# Longitudinal tyre force (always within the grip).
	var a_tyre := 0.0
	if input.brake:
		if v_long > 0.0:
			a_tyre = -tuning.brake_decel * state.grip_multiplier
		elif v_long > -tuning.reverse_speed:
			a_tyre = -tuning.reverse_accel
	elif input.throttle:
		if v_long < 0.0:
			a_tyre = tuning.brake_decel
		else:
			a_tyre = minf(tuning.traction, tuning.power / maxf(v_long, 1.0)) + state.boost_accel
	elif speed > 0.1:
		a_tyre = -signf(v_long) * tuning.engine_brake
	a_tyre = clampf(a_tyre, -grip, grip)
	var usage := a_tyre / grip
	var lateral_grip := tuning.cornering_grip(speed) * surface * sqrt(maxf(1.0 - tuning.combined_grip * usage * usage, 0.0))

	# Steering: the yaw rate the driver asks for, cut down to what the remaining grip allows.
	var max_angle := tuning.max_steer_angle / (1.0 + speed / tuning.steer_falloff_speed)
	var yaw_rate := v_long * tan(state.steer * max_angle) / tuning.wheelbase
	var lateral_needed := absf(v_long * yaw_rate)
	var over := lateral_needed / lateral_grip - 1.0 if lateral_grip > 0.0 else 0.0
	if lateral_needed > lateral_grip:
		yaw_rate *= lateral_grip / lateral_needed
	state.heading = wrapf(state.heading + yaw_rate * dt, -PI, PI)

	# Drag and gravel act on top of the tyres.
	var a_long := a_tyre - tuning.drag * state.drag_multiplier * v_long * speed
	if not state.on_track:
		a_long -= signf(v_long) * minf(tuning.runoff_drag * speed, tuning.runoff_drag_max)
	var new_long := v_long + a_long * dt
	if v_long != 0.0 and signf(new_long) != signf(v_long):
		new_long = 0.0  # braking/rolling out stops the car; reversing starts from standstill
	new_long = maxf(new_long, -tuning.reverse_speed)
	if not input.throttle and not input.brake and absf(new_long) < 0.1:
		new_long = 0.0  # rolled to a stop
	var lateral_left := maxf(lateral_grip - absf(v_long * yaw_rate), grip * 0.25)
	var new_lat := move_toward(v_lat, 0.0, lateral_left * dt)

	# Look only (skid marks, smoke): scrubbing tyres and wheelspin.
	state.slide = clampf(maxf(over, 0.0) * 1.5 + maxf(absf(v_lat) - 1.5, 0.0) * 0.25, 0.0, 1.0) if speed > 8.0 else 0.0
	state.wheelspin = clampf(1.0 - v_long / WHEELSPIN_SPEED, 0.0, 1.0) \
			if input.throttle and not input.brake and v_long >= 0.0 and state.on_track else 0.0
	var new_forward := state.forward()
	state.velocity = new_forward * new_long + Vector2(-new_forward.y, new_forward.x) * new_lat
	state.position += state.velocity * dt
