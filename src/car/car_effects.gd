class_name CarEffects
extends RefCounted
## Look-only effects of one car (M3G): faint skid marks from tyres that scrub or spin
## (CarState.slide / wheelspin) into the shared SkidMarks layer, and dust from the wheels in the
## gravel into the shared TyreSmoke layer (no tyre smoke - user 2026-11-22: distracting). No influence on the
## physics; without layers (tests, menus) it does nothing.

const DUST := Color(0.55, 0.45, 0.3, 0.6)
## Effects start above these values.
const SLIDE_MIN := 0.12
const SPIN_MIN := 0.25
const DUST_SPEED := 6.0
## A mark segment is laid every this many metres (fewer, longer segments).
const MARK_STEP := 0.8
## Wheel positions in the car (metres: x forward, y right); rear wheels first.
const WHEELS: Array[Vector2] = [Vector2(-1.85, -0.75), Vector2(-1.85, 0.75), Vector2(1.55, -0.78), Vector2(1.55, 0.78)]

var marks: SkidMarks
var smoke: TyreSmoke
var _mark_from: Array = [null, null, null, null]
var _rng := RandomNumberGenerator.new()


## Call after every physics tick with the car's state and whether it is on the asphalt.
func update(state: CarState, on_track: bool) -> void:
	var at := Transform2D(state.heading, state.position)
	var speed := state.velocity.length()
	var scrub := state.slide if state.slide > SLIDE_MIN and on_track else 0.0
	var spin := state.wheelspin if state.wheelspin > SPIN_MIN and speed > 0.5 and on_track else 0.0
	for i in WHEELS.size():
		var wheel := at * WHEELS[i]
		var strength := maxf(scrub, spin if i < 2 else 0.0)
		_mark(i, wheel, strength)
		if smoke == null:
			continue
		if not on_track and speed > DUST_SPEED and _rng.randf() < minf(speed / 40.0, 1.0) * 0.5:
			var spray := state.velocity * 0.3 + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.5, 2.0)
			smoke.puff(wheel, spray, DUST, _rng.randf_range(0.9, 1.4), _rng.randf_range(0.6, 0.9))


## The car jumped (placed, pit lane, contact push): no mark across the gap.
func reset() -> void:
	_mark_from = [null, null, null, null]


func _mark(i: int, wheel: Vector2, strength: float) -> void:
	if strength <= 0.0 or marks == null:
		_mark_from[i] = null
		return
	if _mark_from[i] == null:
		_mark_from[i] = wheel
		return
	var from: Vector2 = _mark_from[i]
	if from.distance_to(wheel) >= MARK_STEP:
		marks.add(from, wheel, strength)
		_mark_from[i] = wheel
