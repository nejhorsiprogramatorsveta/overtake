class_name RaceStart
extends RefCounted
## Standing start (PLAN.md B): grid -> five red lights one by one -> random hold -> lights out.
## Drivers hold W + clutch (Space) and let the clutch go as soon as the lights go out.
## - Letting go after the lights are out: the car leaves, reaction = release - lights out.
## - Letting go while the lights are on (after holding it): jump start, +5 s; the car is held
##   until the lights go out, then leaves at once.
## - Not holding the clutch when the lights go out: bogged start, leaves no_clutch_delay later.
## The lights go out a random RaceRules.hold_min..hold_max after the fifth light came on (user
## 2026-11-22: never the same rhythm). Deterministic: the hold comes from a seed (host sends it, M4).

enum Phase { GRID, LIGHTS, HOLD, GO }

## Per-car start state.
class Entry:
	extends RefCounted
	var held := true
	var clutch_seen := false
	var jump_start := false
	## Seconds from lights out to leaving; -1 while still held.
	var reaction := -1.0

var rules: RaceRules
var phase := Phase.GRID
## Seconds since the start sequence began.
var time := 0.0
var hold_time := 0.0
## Time when the lights went out, -1 before.
var go_time := -1.0


## Grid slot as Vector2(distance along the lap, lateral): staggered pairs behind the line.
static func grid_slot(track: TrackData, rules: RaceRules, slot: int) -> Vector2:
	var side := -1.0 if slot % 2 == 0 else 1.0
	return Vector2(track.length - rules.grid_first - slot * rules.grid_spacing, side * rules.grid_lateral)


func _init(race_rules: RaceRules, seed_value: int) -> void:
	rules = race_rules
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	hold_time = rng.randf_range(rules.hold_min, rules.hold_max)


## Red lights on now (0-5).
func lights_on() -> int:
	match phase:
		Phase.LIGHTS:
			return clampi(int((time - rules.grid_time) / rules.light_interval) + 1, 1, 5)
		Phase.HOLD:
			return 5
	return 0


func lights_out() -> bool:
	return phase == Phase.GO


func update(dt: float) -> void:
	time += dt
	var lights_start := rules.grid_time
	var all_on := lights_start + rules.light_interval * 4.0
	if phase == Phase.GRID and time >= lights_start:
		phase = Phase.LIGHTS
	if phase == Phase.LIGHTS and time >= all_on:
		phase = Phase.HOLD
	if phase == Phase.HOLD and time >= all_on + hold_time:
		phase = Phase.GO
		go_time = all_on + hold_time


## Call every tick for every car (after update); returns true while the car must stay put.
func update_entry(entry: Entry, clutch: bool) -> bool:
	if not entry.held:
		return false
	if phase != Phase.GO:
		if clutch:
			entry.clutch_seen = true
		elif entry.clutch_seen and phase != Phase.GRID and not entry.jump_start:
			entry.jump_start = true
		elif entry.clutch_seen and phase == Phase.GRID:
			entry.clutch_seen = false  # let go before the lights came on: no penalty
		return true
	var since_go := time - go_time
	if entry.jump_start:
		_release(entry, 0.0)
	elif entry.clutch_seen and not clutch:
		_release(entry, since_go)
	elif not entry.clutch_seen and since_go >= rules.no_clutch_delay:
		_release(entry, since_go)
	return entry.held


func penalty(entry: Entry) -> float:
	return rules.jump_start_penalty if entry.jump_start else 0.0


func _release(entry: Entry, reaction: float) -> void:
	entry.held = false
	entry.reaction = reaction
