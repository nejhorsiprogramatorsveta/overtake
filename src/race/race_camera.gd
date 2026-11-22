class_name RaceCamera
extends Camera2D
## North-up camera (user decision 2026-11-22): follows the car, looks ahead in the direction
## of travel and zooms out with speed, so the BP boards and corners are visible in time.
## World units are metres; zoom = screen pixels per metre.

## Visible height of the world (m) when standing and at top speed.
const VIEW_SLOW := 80.0
const VIEW_FAST := 150.0
const FAST_SPEED := 85.0
## Look-ahead: seconds of travel, capped (m).
const LOOK_AHEAD_TIME := 0.45
const LOOK_AHEAD_MAX := 50.0
const FOLLOW_RATE := 6.0
const ZOOM_RATE := 1.5

var target: Car
var _view_height := VIEW_SLOW
var _offset := Vector2.ZERO


func _init() -> void:
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS  # moved in physics ticks (interpolated)


func snap() -> void:
	if target:
		_offset = Vector2.ZERO
		global_position = target.state.position
		reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var speed := target.state.velocity.length()
	var wanted_offset := target.state.velocity * LOOK_AHEAD_TIME
	wanted_offset = wanted_offset.limit_length(LOOK_AHEAD_MAX)
	_offset = _offset.lerp(wanted_offset, clampf(FOLLOW_RATE * delta, 0.0, 1.0))
	global_position = target.state.position + _offset
	var wanted_height := lerpf(VIEW_SLOW, VIEW_FAST, clampf(speed / FAST_SPEED, 0.0, 1.0))
	_view_height = lerpf(_view_height, wanted_height, clampf(ZOOM_RATE * delta, 0.0, 1.0))
	var screen_height := get_viewport_rect().size.y
	zoom = Vector2.ONE * (screen_height / _view_height)
