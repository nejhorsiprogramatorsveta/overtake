class_name StartLightsView
extends Control
## The start gantry at the top of the screen: five pairs of red lights (PLAN.md B), the hint
## to hold throttle + clutch, and afterwards the reaction time or the jump-start penalty.

const UNIT := Vector2(46, 92)
const GAP := 12.0
const LIGHT_RADIUS := 15.0
const RED := Color(1.0, 0.12, 0.1)
const OFF := Color(0.18, 0.05, 0.05)
const HOUSING := Color(0.07, 0.07, 0.08, 0.92)
const MESSAGE_TIME := 3.0

var _lights := 0
var _visible_lights := true
var _message := Label.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(UNIT.x * 5 + GAP * 4, UNIT.y + 60)
	_message.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", 26)
	_message.add_theme_constant_override("outline_size", 8)
	_message.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.position = Vector2(-260, UNIT.y + 12)
	_message.size = Vector2(custom_minimum_size.x + 520, 40)
	add_child(_message)


## Called every frame by the race with the start state and the player's entry.
func show_start(start: RaceStart, entry: RaceStart.Entry, race_time: float) -> void:
	_lights = start.lights_on()
	_visible_lights = not start.lights_out() or race_time - start.go_time < 1.0
	var jump := tr("START_JUMP").format({"seconds": "%d" % roundi(start.rules.jump_start_penalty)})
	if not start.lights_out():
		if entry.jump_start:
			_set_message(jump, RED)
		else:
			_set_message(tr("START_HINT").format({"throttle": KeyBindings.action_text(&"throttle"),
					"clutch": KeyBindings.action_text(&"clutch")}), Color.WHITE)
	elif not entry.held and race_time - (start.go_time + entry.reaction) < MESSAGE_TIME:
		if entry.jump_start:
			_set_message(jump, RED)
		elif not entry.clutch_seen:
			_set_message(tr("START_NO_CLUTCH"), Color(1, 0.75, 0.3))
		else:
			_set_message(tr("START_REACTION").format({"time": "%.3f" % entry.reaction}), Color(0.5, 1, 0.55))
	else:
		_message.text = ""
	visible = _visible_lights or not _message.text.is_empty()
	queue_redraw()


func _set_message(text: String, color: Color) -> void:
	_message.text = text
	_message.add_theme_color_override("font_color", color)


func _draw() -> void:
	if not _visible_lights:
		return
	for i in 5:
		var rect := Rect2(Vector2(i * (UNIT.x + GAP), 0), UNIT)
		draw_rect(rect, HOUSING)
		for row in 2:
			var centre := rect.position + Vector2(UNIT.x * 0.5, UNIT.y * (0.28 + row * 0.44))
			draw_circle(centre, LIGHT_RADIUS, RED if i < _lights else OFF)
