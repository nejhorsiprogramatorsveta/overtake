class_name CarState
extends RefCounted
## Complete physical state of one car (what CarMotor changes each tick and what the
## network will send). Metres, m/s, radians; heading 0 = east, growing clockwise on screen.

var position := Vector2.ZERO
var heading := 0.0
var velocity := Vector2.ZERO
## Current steering -1 (left) .. 1 (right); follows the keys smoothly.
var steer := 0.0
## Extra drive (m/s²) while KERS is active (Kers sets it each tick).
var boost_accel := 0.0
## Slipstream strength 0..1 (Slipstream.update); cuts the air drag.
var tow := 0.0
## Air drag multiplier from the tow (1 = normal).
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
	boost_accel = other.boost_accel
	tow = other.tow
	drag_multiplier = other.drag_multiplier
	on_track = other.on_track
