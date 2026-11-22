class_name KersGauge
extends Control
## HUD gauge above the speed: three KERS charges (lit = available, blue bar = burst running,
## outlined only = locked until every car has crossed the line after the start)
## and, with tyre wear on, the tyre condition in % (green -> yellow -> red). (The slipstream is
## not shown - user 2026-11-22.)

const CHARGE := Color(0.35, 0.75, 1.0)
const EMPTY := Color(0.25, 0.27, 0.32)

var _uses := 0
var _max_uses := 3
var _active := 0.0
var _locked := false
var _tyres := -1.0
var _kers_text := ""
var _tyre_text := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kers_text = tr("HUD_KERS")
	_tyre_text = tr("HUD_TYRES")


func show_state(uses_left: int, max_uses: int, active_fraction: float, locked: bool = false) -> void:
	if uses_left == _uses and max_uses == _max_uses and is_equal_approx(active_fraction, _active) and locked == _locked:
		return
	_locked = locked
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
	draw_style_box(HudStyle.panel(CHARGE), Rect2(Vector2.ZERO, size))
	var font := HudStyle.bold()
	draw_string(font, Vector2(22, 28), _kers_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, HudStyle.DIM)
	var box := Vector2(26, 14)
	for i in _max_uses:
		var x := size.x - 20 - (_max_uses - i) * (box.x + 6)
		if _locked:
			draw_rect(Rect2(x, 15, box.x, box.y), EMPTY)
			draw_rect(Rect2(x, 15, box.x, box.y), CHARGE.darkened(0.35), false, 2.0)
		else:
			draw_rect(Rect2(x, 15, box.x, box.y), CHARGE if i < _uses else EMPTY)
	if _active > 0.0:
		draw_rect(Rect2(22, 36, (size.x - 42) * _active, 4), CHARGE)
	if _tyres >= 0.0:
		var color := Color(0.4, 0.9, 0.45) if _tyres > 0.6 else (Color(1, 0.8, 0.3) if _tyres > 0.3 else Color(1, 0.35, 0.3))
		draw_string(font, Vector2(22, 64), _tyre_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, HudStyle.DIM)
		draw_string(font, Vector2(size.x - 92, 64), "%d %%" % roundi(_tyres * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 19, color)
