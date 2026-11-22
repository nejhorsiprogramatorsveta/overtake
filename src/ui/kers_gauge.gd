class_name KersGauge
extends Control
## HUD gauge above the speed: three KERS charges (lit = available, blue bar = burst running)
## and, with tyre wear on, the tyre condition in % (green -> yellow -> red). (The slipstream is
## not shown - user 2026-11-22.)

const BACK := Color(0.06, 0.07, 0.09, 0.72)
const CHARGE := Color(0.35, 0.75, 1.0)
const EMPTY := Color(0.25, 0.27, 0.32)

var _uses := 0
var _max_uses := 3
var _active := 0.0
var _tyres := -1.0
var _kers_text := ""
var _tyre_text := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kers_text = tr("HUD_KERS")
	_tyre_text = tr("HUD_TYRES")


func show_state(uses_left: int, max_uses: int, active_fraction: float) -> void:
	if uses_left == _uses and max_uses == _max_uses and is_equal_approx(active_fraction, _active):
		return
	_uses = uses_left
	_max_uses = max_uses
	_active = active_fraction
	queue_redraw()


## Tyre condition 0..1, or -1 when tyre wear is off (row hidden).
func show_tyres(condition: float) -> void:
	var rounded := roundf(condition * 100.0) / 100.0 if condition >= 0.0 else -1.0
	if rounded != _tyres:
		_tyres = rounded
		queue_redraw()


func _draw() -> void:
	var back := StyleBoxFlat.new()
	back.bg_color = BACK
	back.set_corner_radius_all(6)
	draw_style_box(back, Rect2(Vector2.ZERO, size))
	var font := get_theme_default_font()
	draw_string(font, Vector2(12, 26), _kers_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.75, 0.77, 0.83))
	var box := Vector2(26, 14)
	for i in _max_uses:
		var x := size.x - 12 - (_max_uses - i) * (box.x + 6)
		draw_rect(Rect2(x, 13, box.x, box.y), CHARGE if i < _uses else EMPTY)
	if _active > 0.0:
		draw_rect(Rect2(12, 32, (size.x - 24) * _active, 4), CHARGE)
	if _tyres >= 0.0:
		var color := Color(0.4, 0.9, 0.45) if _tyres > 0.6 else (Color(1, 0.8, 0.3) if _tyres > 0.3 else Color(1, 0.35, 0.3))
		draw_string(font, Vector2(12, 60), _tyre_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.75, 0.77, 0.83))
		draw_string(font, Vector2(118, 60), "%d %%" % roundi(_tyres * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, color)
