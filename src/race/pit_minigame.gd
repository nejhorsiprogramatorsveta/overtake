class_name PitMinigame
extends RefCounted
## The pit stop "release" minigame (PLAN.md B, user: press Space as late as possible): after a
## short wait a bar runs from 0 to 100 %. Pressing at fraction f gives a stop of
## lerp(pit_worst, pit_best, f) seconds - later is faster; not pressing before the bar ends is
## a fumble (pit_worst + pit_fumble). The car leaves once the stop time is over (never before
## the press). Deterministic: driven by update() ticks.

var rules: RaceRules
var elapsed := 0.0
## Bar position 0..1 at the press, -1 = not pressed yet.
var pressed_at := -1.0
var fumbled := false
## Total stationary time once decided, else -1.
var stop_time := -1.0


func _init(race_rules: RaceRules) -> void:
	rules = race_rules


## Bar position 0..1 (0 during the wait).
func bar() -> float:
	return clampf((elapsed - rules.pit_prepare) / rules.pit_bar_time, 0.0, 1.0)


func decided() -> bool:
	return stop_time >= 0.0


## True once the car may leave.
func finished() -> bool:
	return decided() and elapsed >= stop_time


## Call every tick while the car stands in its box; `press` = Space pressed this tick (edge).
func update(dt: float, press: bool) -> void:
	elapsed += dt
	if decided():
		return
	if press and elapsed >= rules.pit_prepare:
		pressed_at = bar()
		stop_time = maxf(lerpf(rules.pit_worst, rules.pit_best, pressed_at), elapsed)
	elif bar() >= 1.0:
		fumbled = true
		stop_time = rules.pit_worst + rules.pit_fumble
