class_name EngineRevs
extends RefCounted
## Engine revs for the HUD's RPM monitor (user 2026-11-24). The car model has no gearbox, so an
## 8-speed box is assumed: each gear tops out at GEAR_STEP of the next gear's top speed, the revs
## follow from the speed in the current gear, it shifts up at the limiter and down when the revs
## in the lower gear would be high enough. After a shift the needle falls quickly instead of
## jumping. On the grid the engine revs freely: the throttle takes it to the limiter at 0 km/h.
## Look only - the physics do not use it.

const GEARS := 8
const IDLE_RPM := 4000.0
const MAX_RPM := 12500.0
## Top speed in top gear (km/h); each lower gear tops out at GEAR_STEP of the next one.
const TOP_KMH := 345.0
const GEAR_STEP := 0.81
## Shift down once the lower gear would run below this share of its top speed (its revs).
const DOWNSHIFT_SHARE := 0.7
## Free revving on the grid, and how fast the revs fall (rpm per second).
const RISE := 26000.0
const FALL := 16000.0

var rpm := IDLE_RPM
var gear := 1


## Top speed of a gear (km/h).
static func gear_top_kmh(g: int) -> float:
	return TOP_KMH * pow(GEAR_STEP, GEARS - g)


## Every frame. free_revving = standing on the grid (clutch in): only the throttle moves the revs.
func update(kmh: float, throttle: bool, free_revving: bool, dt: float) -> void:
	var target: float
	if free_revving:
		gear = 1
		target = MAX_RPM if throttle else IDLE_RPM
		rpm = move_toward(rpm, target, (RISE if target > rpm else FALL) * dt)
		return
	while gear < GEARS and kmh >= gear_top_kmh(gear) * 0.995:
		gear += 1
	while gear > 1 and kmh < gear_top_kmh(gear - 1) * DOWNSHIFT_SHARE:
		gear -= 1
	target = clampf(MAX_RPM * kmh / gear_top_kmh(gear), IDLE_RPM, MAX_RPM)
	rpm = target if target >= rpm else move_toward(rpm, target, FALL * dt)


## 0 at idle, 1 at the limiter.
func share() -> float:
	return clampf((rpm - IDLE_RPM) / (MAX_RPM - IDLE_RPM), 0.0, 1.0)
