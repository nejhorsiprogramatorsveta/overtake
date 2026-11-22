extends Control
## Online lobby (M4, PLAN.md C): the addresses the host shares (LAN / Tailscale, never the
## public IP, with the room code), the players with their car colours, the own colour (each
## colour once), the race settings (only the host changes them, everybody sees them), Start
## (host, at least two players) and Leave. Built in code; listens to Session.

const SWATCH := Vector2(40, 32)

var _addresses := VBoxContainer.new()
var _players_title := Label.new()
var _players := VBoxContainer.new()
var _swatches: Array[Button] = []
var _track := OptionButton.new()
var _laps := SpinBox.new()
var _wear := CheckButton.new()
var _bots := SpinBox.new()
var _difficulty := OptionButton.new()
var _grid := OptionButton.new()
var _start := Button.new()
var _status := Label.new()
## True while the controls are being filled from Session (no echo back to the host).
var _filling := false


func _ready() -> void:
	add_child(MenuBackground.new())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 36)
	panel.add_child(columns)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(470, 0)
	left.add_theme_constant_override("separation", 10)
	columns.add_child(left)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(430, 0)
	right.add_theme_constant_override("separation", 10)
	columns.add_child(right)

	var title := Label.new()
	title.text = "LOBBY_TITLE"
	title.add_theme_font_size_override("font_size", 40)
	left.add_child(title)
	left.add_child(_addresses)
	_players_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_players_title.add_theme_font_size_override("font_size", 22)
	left.add_child(_players_title)
	left.add_child(_players)
	left.add_child(_label("LOBBY_YOUR_COLOR"))
	var swatches := GridContainer.new()
	swatches.columns = 6
	swatches.add_theme_constant_override("h_separation", 6)
	swatches.add_theme_constant_override("v_separation", 6)
	left.add_child(swatches)
	for i in CarColors.COLORS.size():
		var swatch := Button.new()
		swatch.custom_minimum_size = SWATCH
		swatch.tooltip_text = CarColors.NAME_KEYS[i]
		swatch.pressed.connect(Session.request_color.bind(i))
		swatches.add_child(swatch)
		_swatches.append(swatch)

	right.add_child(_label("LOBBY_RACE_SETTINGS"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)
	right.add_child(grid)
	for id in TrackCatalog.ids():
		_track.add_item(tr(TrackCatalog.NAME_KEYS[id]))
		_track.set_item_metadata(_track.item_count - 1, id)
	for key: String in ["DIFFICULTY_EASY", "DIFFICULTY_MEDIUM", "DIFFICULTY_HARD", "DIFFICULTY_EXPERT"]:
		_difficulty.add_item(tr(key))
	for key: String in ["GRID_PEOPLE_BACK", "GRID_RANDOM", "GRID_PEOPLE_FRONT"]:
		_grid.add_item(tr(key))
	_laps.min_value = 1
	_laps.max_value = LobbyValidator.MAX_LAPS
	_bots.min_value = 0
	_bots.max_value = LobbyValidator.MAX_CARS - 1
	for row: Array in [["SETUP_TRACK", _track], ["SETUP_LAPS", _laps], ["SETUP_TYRE_WEAR", _wear],
			["SETUP_BOTS", _bots], ["SETUP_DIFFICULTY", _difficulty], ["SETUP_GRID", _grid]]:
		grid.add_child(_label(row[0]))
		var control: Control = row[1]
		control.custom_minimum_size = Vector2(240, 40)
		grid.add_child(control)
	_track.item_selected.connect(func(_i: int) -> void: _send_settings())
	_laps.value_changed.connect(func(_v: float) -> void: _send_settings())
	_wear.toggled.connect(func(_on: bool) -> void: _send_settings())
	_bots.value_changed.connect(func(_v: float) -> void: _send_settings())
	_difficulty.item_selected.connect(func(_i: int) -> void: _send_settings())
	_grid.item_selected.connect(func(_i: int) -> void: _send_settings())

	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(430, 0)
	right.add_child(_status)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	right.add_child(buttons)
	var leave := Button.new()
	leave.text = "LOBBY_LEAVE"
	leave.custom_minimum_size = Vector2(0, 50)
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leave.pressed.connect(Session.leave)
	buttons.add_child(leave)
	_start.text = "LOBBY_START"
	_start.custom_minimum_size = Vector2(0, 50)
	_start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_start.pressed.connect(Session.start_race)
	buttons.add_child(_start)

	Session.players_changed.connect(_refresh)
	Session.settings_changed.connect(_refresh)
	_fill_addresses()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		Session.leave()


func _label(key: String) -> Label:
	var label := Label.new()
	label.text = key
	label.add_theme_font_size_override("font_size", 20)
	return label


## Host: the addresses to send to friends, each with a copy button.
func _fill_addresses() -> void:
	if not Session.is_host():
		return
	_addresses.add_child(_label("LOBBY_SHARE_TITLE"))
	var entries := Session.share_addresses()
	var has_tailscale := false
	for entry in entries:
		has_tailscale = has_tailscale or entry.kind == &"tailscale"
		var kind := Label.new()
		kind.text = "LOBBY_ADDRESS_TAILSCALE" if entry.kind == &"tailscale" else "LOBBY_ADDRESS_LAN"
		kind.add_theme_font_size_override("font_size", 16)
		_addresses.add_child(kind)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var address := LineEdit.new()
		address.text = entry.address
		address.editable = false
		address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(address)
		var copy := Button.new()
		copy.text = "LOBBY_COPY"
		copy.pressed.connect(func() -> void:
			DisplayServer.clipboard_set(entry.address)
			copy.text = "LOBBY_COPIED")
		row.add_child(copy)
		_addresses.add_child(row)
	if entries.is_empty():
		_addresses.add_child(_wrapped("LOBBY_NO_ADDRESS"))
	_addresses.add_child(_wrapped("LOBBY_HINT_TAILSCALE_ON" if has_tailscale else "LOBBY_HINT_TAILSCALE_OFF"))
	_addresses.add_child(_wrapped("LOBBY_SHARE_SAFETY"))


func _wrapped(key: String) -> Label:
	var label := Label.new()
	label.text = key
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(430, 0)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.72, 0.74, 0.8))
	return label


func _refresh() -> void:
	if not is_inside_tree():
		return
	_filling = true
	var host := Session.is_host()
	_players_title.text = tr("LOBBY_PLAYERS").format({"count": Session.players.size(), "max": Session.MAX_PLAYERS})
	for child in _players.get_children():
		child.queue_free()
	var my_id := Session.my_id()
	var taken: Dictionary[int, bool] = {}
	for peer_id: int in Session.players:
		var entry: Dictionary = Session.players[peer_id]
		taken[int(entry.color)] = peer_id != my_id
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var swatch := ColorRect.new()
		swatch.color = CarColors.color(entry.color)
		swatch.custom_minimum_size = Vector2(22, 22)
		row.add_child(swatch)
		var name_label := Label.new()
		name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		name_label.text = str(entry.name)
		if peer_id == 1:
			name_label.text += " " + tr("LOBBY_HOST_TAG")
		if peer_id == my_id:
			name_label.text += " " + tr("LOBBY_YOU_TAG")
			name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		row.add_child(name_label)
		_players.add_child(row)
	var mine: int = Session.players.get(my_id, {}).get("color", -1)
	for i in _swatches.size():
		var style := StyleBoxFlat.new()
		style.bg_color = CarColors.COLORS[i] if not taken.get(i, false) else CarColors.COLORS[i].darkened(0.6)
		style.set_corner_radius_all(4)
		style.set_border_width_all(3 if i == mine else 1)
		style.border_color = Color.WHITE if i == mine else Color(0, 0, 0, 0.6)
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			_swatches[i].add_theme_stylebox_override(state, style)
		_swatches[i].disabled = taken.get(i, false)
	var settings := Session.settings
	if not settings.is_empty():
		for i in _track.item_count:
			if _track.get_item_metadata(i) == settings.track:
				_track.select(i)
		_laps.value = settings.laps
		_wear.button_pressed = settings.tyre_wear
		_bots.max_value = maxi(LobbyValidator.MAX_CARS - Session.players.size(), 0)
		_bots.value = settings.bots
		_difficulty.select(settings.difficulty)
		_grid.select(settings.grid)
	for control: Control in [_track, _laps, _wear, _bots, _difficulty, _grid]:
		control.set("disabled", not host)
		control.set("editable", host)
	_start.visible = host
	_start.disabled = not Session.can_start_race()
	if host:
		_status.text = "" if Session.can_start_race() else tr("LOBBY_NEED_PLAYERS").format({"min": Session.MIN_PLAYERS_TO_START})
	else:
		_status.text = tr("LOBBY_WAITING_FOR_HOST")
	_filling = false


func _send_settings() -> void:
	if _filling or not Session.is_host():
		return
	Session.set_settings({"track": str(_track.get_item_metadata(_track.selected)), "laps": int(_laps.value),
			"tyre_wear": _wear.button_pressed, "bots": int(_bots.value), "difficulty": _difficulty.selected,
			"grid": _grid.selected})
