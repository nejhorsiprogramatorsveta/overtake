class_name ResultsView
extends CenterContainer
## Race results (PLAN.md B): position, driver, time (winner) or gap, penalties, best lap,
## start reaction and pit stops; the player's row is highlighted. Cars still racing show
## their running state and the table updates until everyone has finished.
## Buttons: race again, back to the menu (online: back to the lobby, M4).

signal restart_pressed
signal menu_pressed

const COLUMNS := ["RESULTS_POS", "RESULTS_DRIVER", "RESULTS_TIME", "RESULTS_PENALTY", "RESULTS_BEST", "RESULTS_REACTION", "RESULTS_PITS"]
const HIGHLIGHT := Color(1.0, 0.85, 0.2)

var _title := Label.new()
var _grid := GridContainer.new()
var _restart := Button.new()
var _menu := Button.new()
var _wait := Label.new()
var _shown := false
## Rebuild the table only when something in it changed.
var _signature := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.09, 0.94)
	style.border_width_top = 4
	style.border_color = Color(0.86, 0.13, 0.15)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 34)
	box.add_child(_title)
	_grid.columns = COLUMNS.size()
	_grid.add_theme_constant_override("h_separation", 26)
	_grid.add_theme_constant_override("v_separation", 8)
	box.add_child(_grid)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	_restart.text = "RESULTS_AGAIN"
	_restart.custom_minimum_size = Vector2(200, 46)
	_restart.pressed.connect(restart_pressed.emit)
	buttons.add_child(_restart)
	_menu.text = "RESULTS_MENU"
	_menu.custom_minimum_size = Vector2(200, 46)
	_menu.pressed.connect(menu_pressed.emit)
	buttons.add_child(_menu)
	_wait.text = "RESULTS_WAIT_HOST"
	_wait.visible = false
	_wait.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_wait)


## Online: the host takes everyone back to the lobby, the others wait for that or leave.
func set_online(online: bool, host: bool) -> void:
	if not online:
		return
	_restart.text = "RESULTS_LOBBY"
	_restart.visible = host
	_menu.text = "RESULTS_LEAVE"
	_wait.visible = not host


func show_results(order: Array[Racer], start: RaceStart, track: TrackData) -> void:
	var signature := ""
	for racer in order:
		signature += "%s|%s|%s|%.3f|%d;" % [racer.name, racer.finished, racer.retired, racer.penalty(start), racer.pit_stop.stops]
	if signature == _signature:
		return
	_signature = signature
	_title.text = tr("RESULTS_TITLE").format({"track": tr(track.name_key)})
	for child in _grid.get_children():
		child.free()
	for key: String in COLUMNS:
		_cell(tr(key), Color(0.6, 0.62, 0.68), 16)
	var winner_time := order[0].total_time(start) if not order.is_empty() else -1.0
	for i in order.size():
		var racer := order[i]
		var color := HIGHLIGHT if racer.is_player else Color.WHITE
		_cell(str(i + 1), color)
		_cell(racer.name, color)
		var time_text := tr("RESULTS_RUNNING")
		if racer.finished:
			if i == 0:
				time_text = RaceHud.format_time(racer.total_time(start))
			elif racer.laps.laps < order[0].laps.laps:
				time_text = tr("STANDINGS_LAPS").format({"laps": order[0].laps.laps - racer.laps.laps})
			else:
				time_text = "+%.3f" % (racer.total_time(start) - winner_time)
		elif racer.retired:
			time_text = tr("RESULTS_RETIRED")
		_cell(time_text, color)
		var penalty := racer.penalty(start)
		_cell("+%d s" % roundi(penalty) if penalty > 0.0 else "–", Color(1, 0.45, 0.4) if penalty > 0.0 else color)
		_cell(RaceHud.format_time(racer.laps.best_lap), color)
		var entry := racer.start_entry
		var reaction := "–"
		if entry.jump_start:
			reaction = tr("RESULTS_JUMP_START")
		elif entry.reaction >= 0.0:
			reaction = "%.3f s" % entry.reaction
		_cell(reaction, color)
		_cell(str(racer.pit_stop.stops), color)
	if not _shown:
		_shown = true
		visible = true
		(_restart if _restart.visible else _menu).grab_focus()


func _cell(text: String, color: Color, size: int = 20) -> void:
	var label := Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	_grid.add_child(label)
