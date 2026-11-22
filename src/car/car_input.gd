class_name CarInput
extends RefCounted
## One tick of driver input (keyboard player, bot or network).

var throttle := false
var brake := false
## -1 left, 0 straight, 1 right.
var steer := 0.0
var clutch := false
var kers := false


static func from_keyboard() -> CarInput:
	var input := CarInput.new()
	input.throttle = Input.is_action_pressed(&"throttle")
	input.brake = Input.is_action_pressed(&"brake")
	input.steer = Input.get_axis(&"steer_left", &"steer_right")
	input.clutch = Input.is_action_pressed(&"clutch")
	input.kers = Input.is_action_pressed(&"kers")
	return input
