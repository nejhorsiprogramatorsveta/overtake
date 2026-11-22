extends Control
## Settings of an offline session, opened from the menu by "Trénink" or "Závod"
## (user 2026-11-22): track, car colour (with a preview), tyre wear and, for a race, the
## number of laps. Bots (count, difficulty) are added in M3. Built in code; Esc = back.

const MENU_PATH := "res://src/ui/main_menu.tscn"
const RACE_PATH := "res://src/race/race.tscn"
const SWATCH := Vector2(40, 40)

var _track_option := OptionButton.new()
var _tyre_check := CheckButton.new()
var _laps_spin := SpinBox.new()
var _swatches: Array[Button] = []
var _preview := CarView.new()
var _color_index := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(MenuBackground.new())
	var race := RaceController.next_mode == RaceController.Mode.RACE
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(560, 0)
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)
	var title := Label.new()
	title.text = "SETUP_RACE_TITLE" if race else "SETUP_PRACTICE_TITLE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	column.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 12)
	column.add_child(grid)
	grid.add_child(_label("SETUP_TRACK"))
	for id in TrackCatalog.ids():
		_track_option.add_item(tr(TrackCatalog.NAME_KEYS[id]))
		_track_option.set_item_metadata(_track_option.item_count - 1, id)
		if id == TrackCatalog.id_or_default(Settings.practice_track):
			_track_option.select(_track_option.item_count - 1)
	_track_option.custom_minimum_size = Vector2(320, 42)
	grid.add_child(_track_option)

	grid.add_child(_label("SETUP_CAR"))
	var car_box := VBoxContainer.new()
	grid.add_child(car_box)
	var swatches := GridContainer.new()
	swatches.columns = 5
	swatches.add_theme_constant_override("h_separation", 8)
	swatches.add_theme_constant_override("v_separation", 8)
	car_box.add_child(swatches)
	for i in CarColors.COLORS.size():
		var swatch := Button.new()
		swatch.custom_minimum_size = SWATCH
		swatch.tooltip_text = CarColors.NAME_KEYS[i]
		swatch.pressed.connect(_select_color.bind(i))
		swatches.add_child(swatch)
		_swatches.append(swatch)
	var preview_box := Control.new()
	preview_box.custom_minimum_size = Vector2(240, 90)
	car_box.add_child(preview_box)
	_preview.position = Vector2(120, 45)
	_preview.scale = Vector2.ONE * 26.0
	preview_box.add_child(_preview)

	grid.add_child(_label("SETUP_TYRE_WEAR"))
	_tyre_check.button_pressed = Settings.tyre_wear
	_tyre_check.tooltip_text = "MENU_TYRE_WEAR_HINT"
	grid.add_child(_tyre_check)

	if race:
		grid.add_child(_label("SETUP_LAPS"))
		_laps_spin.min_value = 1
		_laps_spin.max_value = 30
		_laps_spin.value = Settings.race_laps
		_laps_spin.custom_minimum_size = Vector2(140, 40)
		grid.add_child(_laps_spin)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)
	var back := Button.new()
	back.text = "SETTINGS_BACK"
	back.custom_minimum_size = Vector2(0, 50)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(_go_back)
	buttons.add_child(back)
	var start := Button.new()
	start.text = "SETUP_START"
	start.custom_minimum_size = Vector2(0, 50)
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start.pressed.connect(_start)
	buttons.add_child(start)
	_select_color(clampi(Settings.car_color, 0, CarColors.COLORS.size() - 1))
	start.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_go_back()


func _select_color(index: int) -> void:
	_color_index = index
	for i in _swatches.size():
		var style := StyleBoxFlat.new()
		style.bg_color = CarColors.COLORS[i]
		style.set_corner_radius_all(4)
		style.set_border_width_all(3 if i == index else 1)
		style.border_color = Color.WHITE if i == index else Color(0, 0, 0, 0.6)
		for state in ["normal", "hover", "pressed", "focus"]:
			_swatches[i].add_theme_stylebox_override(state, style)
	_preview.body_color = CarColors.color(index)
	_preview.queue_redraw()


func _save() -> void:
	Settings.practice_track = str(_track_option.get_item_metadata(_track_option.selected))
	Settings.tyre_wear = _tyre_check.button_pressed
	Settings.car_color = _color_index
	if RaceController.next_mode == RaceController.Mode.RACE:
		Settings.race_laps = int(_laps_spin.value)
	Settings.save()


func _start() -> void:
	_save()
	get_tree().change_scene_to_file(RACE_PATH)


func _go_back() -> void:
	_save()
	get_tree().change_scene_to_file(MENU_PATH)


func _label(key: String) -> Label:
	var label := Label.new()
	label.text = key
	label.add_theme_font_size_override("font_size", 22)
	return label
