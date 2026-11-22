class_name CarTuning
extends Resource
## Every tunable number of the car physics (CarMotor). Units: metres, seconds, radians.
## Edited in data/car/car_tuning.tres (see docs/EDITING_GUIDE.md). Speeds are in m/s
## (× 3.6 = km/h shown in the HUD).

@export_group("Engine")
## Engine power per kg (m²/s³): the acceleration is power / speed, so the car pulls hard at low
## speed and less near the top. With `drag` it sets the top speed: (power / drag)^(1/3).
@export var power := 1090.0
## Most the rear tyres can push (m/s²), the limit at low speed.
@export var traction := 13.0
## Air drag coefficient (per metre): deceleration = drag × speed².
@export var drag := 0.0016
## Deceleration without throttle or brake (m/s²).
@export var engine_brake := 2.5

@export_group("Brakes and grip")
## Full braking deceleration (m/s²), limited by the grip.
@export var brake_decel := 30.0
## Tyre grip (m/s²): cornering limit at speed and the limit for braking/accelerating;
## braking takes part of it away from cornering (combined_grip).
@export var grip := 34.0
## How much braking/accelerating takes away from cornering: 1 = full friction circle (full
## braking leaves ~half the cornering grip), 0 = braking never limits steering.
## User 2026-11-22: braking felt like locked wheels -> 0.5 (full braking keeps ~3/4).
@export_range(0.0, 1.0) var combined_grip := 0.5
## Extra cornering grip at low speed (user 2026-11-22: "the slower, the more it turns"):
## +low_speed_grip_bonus at standstill, fading out until low_speed_grip_speed (m/s).
@export var low_speed_grip_bonus := 0.35
@export var low_speed_grip_speed := 45.0
## Grip multiplier off the track (gravel/grass).
@export var runoff_grip := 0.6
## Extra deceleration off the track: runoff_drag × speed, at most runoff_drag_max (m/s²).
@export var runoff_drag := 0.85
@export var runoff_drag_max := 22.0

@export_group("Steering")
## Distance between the axles (m): shorter turns more sharply.
@export var wheelbase := 3.6
## Steering angle at standstill (rad); it shrinks with speed (steer_falloff_speed).
@export var max_steer_angle := 0.5
## At this speed (m/s) the steering angle is halved.
@export var steer_falloff_speed := 20.0
## How fast the steering follows the keys (full lock per second).
@export var steer_speed := 6.0

@export_group("Reverse")
@export var reverse_accel := 6.0
@export var reverse_speed := 10.0

@export_group("KERS")
## Uses per lap (refilled at the line), each lasts kers_duration s and adds kers_accel m/s²
## on throttle (works at any speed). User 2026-11-22: shorter and stronger (1.25 s, +4).
@export var kers_uses := 3
@export var kers_duration := 1.25
@export var kers_accel := 4.0

@export_group("Slipstream")
## Full tow right behind a car, none at slip_time seconds behind it (user: 1.5 s).
@export var slip_time := 1.5
## Air drag is cut by up to this share in the tow.
@export var slip_drag_reduction := 0.3
## Half-width of the tow behind a car (m) at the car, growing by slip_widening per metre.
@export var slip_half_width := 2.2
@export var slip_widening := 0.03
## How fast the tow builds up and fades after leaving it (share per second): the car slows
## down gradually, not at once (user requirement).
@export var slip_rise := 3.0
@export var slip_decay := 1.25
## No tow below this speed (m/s).
@export var slip_min_speed := 20.0

@export_group("Tyres")
## With tyre wear on: metres from new (100 %) to dead (0 %) tyres.
@export var tyre_life := 15000.0
## Grip and brakes lose this share by the time the tyres reach the cliff...
@export var tyre_loss_at_cliff := 0.12
## ...the condition (0..1) where the wear gets steep...
@export var tyre_cliff := 0.3
## ...and this share at 0 %.
@export var tyre_loss_dead := 0.3

@export_group("Size")
## Car body (m), also used for contact and track limits.
@export var length := 5.2
@export var width := 1.9


## Cornering grip (m/s²) at a speed, before braking/gravel reduce it.
func cornering_grip(speed: float) -> float:
	return grip * (1.0 + low_speed_grip_bonus * clampf(1.0 - absf(speed) / low_speed_grip_speed, 0.0, 1.0))


## Top speed on a flat straight without help (m/s).
func top_speed() -> float:
	return pow(power / drag, 1.0 / 3.0)
