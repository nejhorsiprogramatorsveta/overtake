class_name PitPopup
extends PanelContainer
## The pit stop popup (PLAN.md B, like in F1 games): a bar runs from 0 to 100 %, only its end is
## green - press Space as late as possible; afterwards the stop time or the fumble is shown until the car leaves.

const BAR_SIZE := Vector2(380, 30)
const EARLY := Color(0.85, 0.25, 0.2)
const MIDDLE := Color(0.85, 0.55, 0.2)
const LATE := Color(0.25, 0.9, 0.35)
const MARKER := Color.WHITE

var _title := Label.new()
var _bar := Control.new()
var _text := Label.new()
var _fraction := 0.0
var _pressed_at := -1.0
var _rules: RaceRules


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.09, 0.9)
	style.border_width_top = 3
	style.border_color = Color(1.0, 0.85, 0.2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	for label: Label in [_title, _text]:
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 28)
	_title.text = tr("PIT_TITLE")
	_text.add_theme_font_size_override("font_size", 20)
	_bar.custom_minimum_size = BAR_SIZE
	_bar.draw.connect(_draw_bar)
	box.add_child(_title)
	box.add_child(_bar)
	box.add_child(_text)
	visible = false


## Called every frame with the player's pit stop.
func show_stop(stop: PitStop) -> void:
	var game := stop.minigame
	visible = game != null and stop.phase == PitStop.Phase.STOPPED
	if not visible:
		return
	_rules = stop.rules
	_fraction = game.bar()
	_pressed_at = game.pressed_at
	if game.fumbled:
		_text.text = tr("PIT_FUMBLE").format({"seconds": "%d" % roundi(stop.rules.pit_fumble)})
		_text.add_theme_color_override("font_color", EARLY)
	elif game.decided():
		_text.text = tr("PIT_RESULT").format({"time": "%.1f" % game.stop_time})
		_text.add_theme_color_override("font_color", LATE)
	else:
		_text.text = tr("PIT_HINT").format({"key": KeyBindings.action_text(&"clutch")})
		_text.add_theme_color_override("font_color", Color.WHITE)
	_bar.queue_redraw()


func _draw_bar() -> void:
	var green_from := 0.85
	if _rules:
		green_from = _rules.pit_green_from
	var red_width := BAR_SIZE.x * green_from
	var steps := 20
	for i in steps:
		var w := red_width / steps
		_bar.draw_rect(Rect2(i * w, 0, w + 0.5, BAR_SIZE.y), EARLY.lerp(MIDDLE, float(i) / (steps - 1)))
	_bar.draw_rect(Rect2(red_width, 0, BAR_SIZE.x - red_width, BAR_SIZE.y), LATE)
	_bar.draw_rect(Rect2(red_width - 1, -3, 2, BAR_SIZE.y + 6), Color.WHITE * Color(1, 1, 1, 0.6))
	var x := (_pressed_at if _pressed_at >= 0.0 else _fraction) * BAR_SIZE.x
	_bar.draw_rect(Rect2(x - 3, -5, 6, BAR_SIZE.y + 10), MARKER)
