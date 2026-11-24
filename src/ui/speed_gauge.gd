class_name SpeedGauge
extends Control
## HUD speed (M3G): big km/h number and a segmented bar under it (green, yellow, red towards
## the top speed); the lit segments turn blue while KERS is pushing. On the grid the bar shows
## the engine revs instead (user 2026-11-24): with the throttle held it climbs to the limiter
## (the last segment flickers) while the speed stays 0 km/h; after the start it shows speed again.

const SEGMENTS := 24
const MAX_KMH := 340.0
const OFF := Color(0.2, 0.21, 0.25)
const KERS := Color(0.35, 0.75, 1.0)
## Revs on the grid: idle share of the bar, and how fast the revs rise / fall (share per s).
const IDLE_REVS := 0.15
const REV_RISE := 3.0
const REV_FALL := 2.0

var _kmh := 0
var _kers := false
var _unit := ""
## Engine revs 0..1 shown on the grid, -1 = the bar shows the speed.
var revs := -1.0
var _rev_target := -1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_unit = tr("HUD_KMH")


func show_speed(kmh: float, kers_active: bool) -> void:
	var rounded := roundi(kmh)
	if rounded == _kmh and kers_active == _kers:
		return
	_kmh = rounded
	_kers = kers_active
	queue_redraw()


## On the grid: rev the engine (throttle held) or idle; off the grid (null) the bar shows speed.
func show_revs(on_grid: bool, throttle: bool) -> void:
	_rev_target = (1.0 if throttle else IDLE_REVS) if on_grid else -1.0


func _process(delta: float) -> void:
	if _rev_target < 0.0:
		if revs >= 0.0:
			revs = -1.0
			queue_redraw()
		return
	revs = move_toward(maxf(revs, 0.0), _rev_target, (REV_RISE if _rev_target > revs else REV_FALL) * delta)
	queue_redraw()  # also the limiter flicker


## Segments lit: by the revs on the grid (the last one flickers at the limiter), else by speed.
func lit_segments() -> int:
	if revs >= 0.0:
		var lit := int(revs * SEGMENTS + 0.5)
		if lit >= SEGMENTS and (Time.get_ticks_msec() / 70) % 2 == 0:
			lit -= 1
		return lit
	return int(clampf(_kmh / MAX_KMH, 0.0, 1.0) * SEGMENTS + 0.5)


## Colour of a lit segment by its share of the bar.
static func segment_color(share: float) -> Color:
	if share < 0.6:
		return HudStyle.GREEN
	if share < 0.85:
		return HudStyle.YELLOW
	return HudStyle.LOSS


func _draw() -> void:
	draw_style_box(HudStyle.panel(), Rect2(Vector2.ZERO, size))
	var font := HudStyle.bold()
	var text := str(_kmh)
	var number_size := 56
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, number_size).x
	var unit_width := font.get_string_size(_unit, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var right := size.x - 18.0
	draw_string(font, Vector2(right - unit_width - 8.0 - width, 62), text, HORIZONTAL_ALIGNMENT_LEFT, -1, number_size, HudStyle.TEXT)
	draw_string(font, Vector2(right - unit_width, 62), _unit, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, HudStyle.DIM)
	var lit := lit_segments()
	var bar := Rect2(22, size.y - 24, size.x - 40, 10)
	var step := bar.size.x / SEGMENTS
	for i in SEGMENTS:
		var color := OFF
		if i < lit:
			color = KERS if _kers else segment_color(float(i) / SEGMENTS)
		draw_rect(Rect2(bar.position.x + i * step, bar.position.y, step - 2.0, bar.size.y), color)
