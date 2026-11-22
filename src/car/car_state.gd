class_name CarState
extends RefCounted
## Complete physical state of one car (what CarMotor changes each tick and what the
## network will send). Metres, m/s, radians; heading 0 = east, growing clockwise on screen.

var position := Vector2.ZERO
var heading := 0.0
var velocity := Vector2.ZERO
## Current steering -1 (left) .. 1 (right); follows the keys smoothly.
var steer := 0.0
## Set each tick by race systems (M2: KERS raises power, slipstream lowers drag).
var power_multiplier := 1.0
var drag_multiplier := 1.0
## False while the car is off the asphalt (gravel/grass); set by Car from the track.
var on_track := true


func forward() -> Vector2:
	return Vector2.from_angle(heading)


## Signed speed along the car (negative when reversing).
func forward_speed() -> float:
	return velocity.dot(forward())


func copy_from(other: CarState) -> void:
	position = other.position
	heading = other.heading
	velocity = other.velocity
	steer = other.steer
	power_multiplier = other.power_multiplier
	drag_multiplier = other.drag_multiplier
	on_track = other.on_track
