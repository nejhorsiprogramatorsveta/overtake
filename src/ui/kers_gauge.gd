class_name KersGauge
extends Control
## HUD gauge above the speed: three KERS charges (lit = available, blue bar = burst running)
## and the slipstream bar (fills while in the tow, empties slowly after leaving it).

const BACK := Color(0.06, 0.07, 0.09, 0.72)
const CHARGE := Color(0.35, 0.75, 1.0)
const EMPTY := Color(0.25, 0.27, 0.32)
const TOW := Color(0.95, 0.95, 0.95)

var _uses := 0
var _max_uses := 3
var _active := 0.0
var _tow := 0.0
var _kers_text := ""
var _tow_text := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kers_text = tr("HUD_KERS")
	_tow_text = tr("HUD_SLIPSTREAM")


func show_state(uses_left: int, max_uses: int, active_fraction: float, tow: float) -> void:
	if uses_left == _uses and max_uses == _max_uses and is_equal_approx(active_fraction, _active) and absf(tow - _tow) < 0.01:
		return
	_uses = uses_left
	_max_uses = max_uses
	_active = active_fraction
	_tow = tow
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
	draw_string(font, Vector2(12, 58), _tow_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.75, 0.77, 0.83))
	var bar := Rect2(118, 47, size.x - 130, 10)
	draw_rect(bar, EMPTY)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * _tow, bar.size.y)), TOW)
