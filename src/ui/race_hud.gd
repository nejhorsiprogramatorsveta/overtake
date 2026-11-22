class_name RaceHud
extends CanvasLayer
## In-race overlay: lap and lap times (top left), minimap (top right), speed (bottom right).
## Built in code; texts via tr() keys.

const PANEL_COLOR := Color(0.06, 0.07, 0.09, 0.72)
const DIM := Color(0.75, 0.77, 0.83)

var minimap := Minimap.new()
var _lap_label := Label.new()
var _time_label := Label.new()
var _last_label := Label.new()
var _best_label := Label.new()
var _speed_label := Label.new()
var _unit_label := Label.new()


func setup(track: TrackData) -> void:
	var times := _panel(Control.PRESET_TOP_LEFT, Vector2(16, 16), Vector2(250, 0))
	for label: Label in [_lap_label, _time_label, _last_label, _best_label]:
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		times.add_child(label)
	_lap_label.add_theme_font_size_override("font_size", 30)
	_time_label.add_theme_font_size_override("font_size", 26)
	for label: Label in [_last_label, _best_label]:
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", DIM)

	var map_panel := PanelContainer.new()
	map_panel.add_theme_stylebox_override("panel", _style())
	map_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	map_panel.offset_left = -236
	map_panel.offset_right = -16
	map_panel.offset_top = 16
	map_panel.offset_bottom = 236
	add_child(map_panel)
	minimap.custom_minimum_size = Vector2(200, 200)
	map_panel.add_child(minimap)
	minimap.setup(track)

	var speed_panel := PanelContainer.new()
	speed_panel.add_theme_stylebox_override("panel", _style())
	add_child(speed_panel)
	speed_panel.anchor_left = 1.0
	speed_panel.anchor_right = 1.0
	speed_panel.anchor_top = 1.0
	speed_panel.anchor_bottom = 1.0
	speed_panel.offset_left = -196
	speed_panel.offset_right = -16
	speed_panel.offset_top = -116
	speed_panel.offset_bottom = -16
	speed_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	speed_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var speed := VBoxContainer.new()
	speed.add_theme_constant_override("separation", 0)
	speed_panel.add_child(speed)
	for label: Label in [_speed_label, _unit_label]:
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		speed.add_child(label)
	_speed_label.add_theme_font_size_override("font_size", 52)
	_unit_label.add_theme_font_size_override("font_size", 16)
	_unit_label.add_theme_color_override("font_color", DIM)
	_unit_label.text = tr("HUD_KMH")


func show_laps(lap_number: int, lap_time: float, last_lap: float, best_lap: float) -> void:
	_lap_label.text = tr("HUD_LAP").format({"lap": lap_number})
	_time_label.text = format_time(lap_time) if lap_time >= 0.0 else tr("HUD_OUT_LAP")
	_last_label.text = tr("HUD_LAST_LAP").format({"time": format_time(last_lap)})
	_best_label.text = tr("HUD_BEST_LAP").format({"time": format_time(best_lap)})


func show_speed(kmh: float) -> void:
	_speed_label.text = str(roundi(kmh))


## 1:05.432, or "–" for no time yet.
static func format_time(seconds: float) -> String:
	if seconds < 0.0:
		return "–"
	var millis := roundi(seconds * 1000.0)
	return "%d:%02d.%03d" % [millis / 60000, (millis / 1000) % 60, millis % 1000]


func _panel(preset: Control.LayoutPreset, offset: Vector2, min_size: Vector2) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style())
	panel.custom_minimum_size = min_size
	add_child(panel)
	panel.set_anchors_and_offsets_preset(preset)
	panel.position += offset
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	return box


func _style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	return style
