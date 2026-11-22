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
## Total tyre grip (m/s²) shared by braking/accelerating and cornering (friction circle):
## braking hard leaves little grip for turning, so brake in a straight line first.
@export var grip := 34.0
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
@export var steer_speed := 5.0

@export_group("Reverse")
@export var reverse_accel := 6.0
@export var reverse_speed := 10.0

@export_group("Size")
## Car body (m), also used for contact and track limits.
@export var length := 5.2
@export var width := 1.9


## Top speed on a flat straight without help (m/s).
func top_speed() -> float:
	return pow(power / drag, 1.0 / 3.0)
