class_name Kers
extends RefCounted
## KERS (PLAN.md B): the K key gives a burst of extra drive, CarTuning.kers_uses times per
## lap, refilled every time the car crosses the line. One press = one use (holding the key
## does not chain uses); the boost only pushes while the throttle is pressed.

var tuning: CarTuning
var uses_left := 0
## Seconds of the current burst left (0 = not active).
var active_left := 0.0
var _was_pressed := false


func _init(car_tuning: CarTuning) -> void:
	tuning = car_tuning
	uses_left = tuning.kers_uses


func is_active() -> bool:
	return active_left > 0.0


## A new lap: all uses back (a running burst continues).
func refill() -> void:
	uses_left = tuning.kers_uses


## Call every tick with the KERS key; sets the car's boost for this tick.
func update(state: CarState, pressed: bool, throttle: bool, dt: float) -> void:
	if pressed and not _was_pressed and uses_left > 0 and not is_active():
		uses_left -= 1
		active_left = tuning.kers_duration
	_was_pressed = pressed
	state.boost_accel = tuning.kers_accel if is_active() and throttle else 0.0
	active_left = maxf(active_left - dt, 0.0)
