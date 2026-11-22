class_name Kers
extends RefCounted
## KERS (PLAN.md B): the K key gives a burst of extra drive, CarTuning.kers_uses times per
## lap, refilled every time the car crosses the line. One press = one use (holding the key
## does not chain uses); the boost only pushes while the throttle is pressed.
## In a session KERS starts locked and is released for everyone once every car has crossed the
## line after the start (user 2026-11-22; release_due).

var tuning: CarTuning
var uses_left := 0
## Seconds of the current burst left (0 = not active).
var active_left := 0.0
## Locked = presses are ignored (start of the session, until release_due).
var locked := false
var _was_pressed := false


func _init(car_tuning: CarTuning) -> void:
	tuning = car_tuning
	uses_left = tuning.kers_uses


func is_active() -> bool:
	return active_left > 0.0


## A use can be started now (not locked, charges left, no burst running).
func available() -> bool:
	return not locked and uses_left > 0 and not is_active()


## KERS is released when every car has crossed the line since the start, or at the latest when
## the first car completes a lap (a car left standing on the grid must not block the others).
static func release_due(trackers: Array[LapTracker]) -> bool:
	for tracker in trackers:
		if tracker.laps >= 1:
			return true
	for tracker in trackers:
		if tracker.crossings < 1:
			return false
	return not trackers.is_empty()


## A new lap: all uses back (a running burst continues).
func refill() -> void:
	uses_left = tuning.kers_uses


## Call every tick with the KERS key; sets the car's boost for this tick.
func update(state: CarState, pressed: bool, throttle: bool, dt: float) -> void:
	if pressed and not _was_pressed and available():
		uses_left -= 1
		active_left = tuning.kers_duration
	_was_pressed = pressed
	state.boost_accel = tuning.kers_accel if is_active() and throttle else 0.0
	active_left = maxf(active_left - dt, 0.0)
