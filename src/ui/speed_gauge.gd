class_name SpeedGauge
extends Control
## HUD speed and RPM monitor (M3G; RPM monitor user 2026-11-24): big km/h number, the gear on
## the left and a segmented rev bar under them in F1 shift-light colours (green, red, blue
## towards the limiter; the last segment flickers at the limiter). The revs come from
## EngineRevs (on the grid the engine revs freely at 0 km/h).

const SEGMENTS := 24
const OFF := Color(0.2, 0.21, 0.25)
const SHIFT_BLUE := Color(0.35, 0.6, 1.0)

var _kmh := 0
var _unit := ""
## Rev share 0..1 shown by the bar, and the gear.
var revs := 0.0
var gear := 1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_unit = tr("HUD_KMH")


func show_speed(kmh: float) -> void:
	var rounded := roundi(kmh)
	if rounded != _kmh:
		_kmh = rounded
		queue_redraw()


## Every frame: the rev share (EngineRevs.share) and the gear.
func show_revs(share: float, current_gear: int) -> void:
	revs = clampf(share, 0.0, 1.0)
	gear = current_gear
	queue_redraw()  # also the limiter flicker


## Segments lit by the revs; at the limiter the last one flickers.
func lit_segments() -> int:
	var lit := int(revs * SEGMENTS + 0.5)
	if lit >= SEGMENTS and (Time.get_ticks_msec() / 70) % 2 == 0:
		lit -= 1
	return lit


## Shift-light colour of a lit segment by its share of the bar.
static func segment_color(share: float) -> Color:
	if share < 0.55:
		return HudStyle.GREEN
	if share < 0.8:
		return HudStyle.LOSS
	return SHIFT_BLUE


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
	draw_string(font, Vector2(26, 62), str(gear), HORIZONTAL_ALIGNMENT_LEFT, -1, 40, HudStyle.GOLD)
	var lit := lit_segments()
	var bar := Rect2(22, size.y - 24, size.x - 40, 10)
	var step := bar.size.x / SEGMENTS
	for i in SEGMENTS:
		var color := segment_color(float(i) / SEGMENTS) if i < lit else OFF
		draw_rect(Rect2(bar.position.x + i * step, bar.position.y, step - 2.0, bar.size.y), color)
