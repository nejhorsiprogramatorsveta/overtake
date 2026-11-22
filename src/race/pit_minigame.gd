class_name PitMinigame
extends RefCounted
## The pit stop "release" minigame (PLAN.md B, user: press Space as late as possible): after a
## short wait a bar runs from 0 to 100 %. Only its end is green: pressing there gives the
## fastest stops (pit_good -> pit_best), earlier is slower (pit_worst -> pit_good); not pressing
## before the bar ends is a fumble (pit_worst + pit_fumble). The car leaves once the stop time is over (never before
## the press). Deterministic: driven by update() ticks.

var rules: RaceRules
var elapsed := 0.0
## Bar position 0..1 at the press, -1 = not pressed yet.
var pressed_at := -1.0
var fumbled := false
## Time the car will stand in its box once decided, else -1.
var stop_time := -1.0


func _init(race_rules: RaceRules) -> void:
	rules = race_rules


## Bar position 0..1 (0 during the wait).
func bar() -> float:
	return clampf((elapsed - rules.pit_prepare) / rules.pit_bar_time, 0.0, 1.0)


## Stop time for a press at bar position f (0..1).
func stop_time_at(f: float) -> float:
	if f >= rules.pit_green_from:
		return lerpf(rules.pit_good, rules.pit_best, (f - rules.pit_green_from) / (1.0 - rules.pit_green_from))
	return lerpf(rules.pit_worst, rules.pit_good, f / rules.pit_green_from)


func decided() -> bool:
	return stop_time >= 0.0


## True if the press hit the green zone.
func in_green() -> bool:
	return pressed_at >= rules.pit_green_from


## Call every tick from the pit entry on; `press` = Space pressed this tick (edge).
func update(dt: float, press: bool) -> void:
	elapsed += dt
	if decided():
		return
	if press and elapsed >= rules.pit_prepare:
		pressed_at = bar()
		stop_time = stop_time_at(pressed_at)
	elif bar() >= 1.0:
		fumbled = true
		stop_time = rules.pit_worst + rules.pit_fumble
