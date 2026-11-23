class_name RaceHud
extends CanvasLayer
## In-race overlay (M3G game style, HudStyle): position, lap and lap times with the live order
## below them (left), minimap (top right), speed gauge (bottom right), KERS/tyre gauge (above it),
## start lights (top centre, race only), messages, the pit popup and the results table.
## A finished lap flashes its time in TV colours (purple / green / yellow), a position change
## flashes green or red. Built in code; texts via tr() keys.

## How long a finished lap's time stays in place of the running time (s).
const LAP_FLASH_TIME := 3.0
const POSITION_FLASH_TIME := 1.5

var minimap := Minimap.new()
## Only in a race (null in practice).
var start_lights: StartLightsView
var kers_gauge := KersGauge.new()
var speed_gauge := SpeedGauge.new()
var pit_popup := PitPopup.new()
var stats := StatsOverlay.new()
var _lap_label := HudStyle.label(22)
var _time_label := HudStyle.label(34)
var _last_label := HudStyle.label(17, HudStyle.DIM)
var _best_label := HudStyle.label(17, HudStyle.DIM)
var _penalty_label := HudStyle.label(17, HudStyle.LOSS)
var _message := HudStyle.label(30)
var _message_left := 0.0
var _position_label := HudStyle.label(46, HudStyle.GOLD)
var _position := 0
var _position_flash := 0.0
var _lap_flash := 0.0
var _lap_flash_text := ""
var _lap_flash_color := Color.WHITE
var results := ResultsView.new()
## Live order (race only, null in practice).
var standings: StandingsView


func setup(track: TrackData, with_start: bool) -> void:
	var left := VBoxContainer.new()
	left.position = Vector2(16, 16)
	left.add_theme_constant_override("separation", 10)
	add_child(left)
	var times := _panel(left, Vector2(260, 0))
	if with_start:
		standings = StandingsView.new()
		standings.custom_minimum_size = Vector2(260, 0)
		left.add_child(standings)
	for label: Label in [_position_label, _lap_label, _time_label, _last_label, _best_label, _penalty_label]:
		times.add_child(label)
	_position_label.visible = false
	_penalty_label.visible = false

	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_constant_override("outline_size", 10)
	_message.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_message.anchor_left = 0.0
	_message.anchor_right = 1.0
	_message.offset_top = 190
	_message.offset_bottom = 232
	add_child(_message)

	var map_panel := PanelContainer.new()
	map_panel.add_theme_stylebox_override("panel", HudStyle.panel())
	map_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	map_panel.offset_left = -246
	map_panel.offset_right = -16
	map_panel.offset_top = 16
	map_panel.offset_bottom = 236
	add_child(map_panel)
	minimap.custom_minimum_size = Vector2(200, 200)
	map_panel.add_child(minimap)
	minimap.setup(track)

	for gauge: Control in [speed_gauge, kers_gauge]:
		add_child(gauge)
		gauge.anchor_left = 1.0
		gauge.anchor_right = 1.0
		gauge.anchor_top = 1.0
		gauge.anchor_bottom = 1.0
		gauge.offset_left = -256
		gauge.offset_right = -16
	speed_gauge.offset_top = -116
	speed_gauge.offset_bottom = -16
	kers_gauge.offset_top = -204
	kers_gauge.offset_bottom = -126

	var pit_center := CenterContainer.new()
	pit_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pit_center.anchor_top = 0.55  # lower part of the screen: the car stays visible
	pit_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pit_center)
	pit_center.add_child(pit_popup)

	if with_start:
		start_lights = StartLightsView.new()
		add_child(start_lights)
		var width := start_lights.custom_minimum_size.x
		start_lights.anchor_left = 0.5
		start_lights.anchor_right = 0.5
		start_lights.offset_left = -width * 0.5
		start_lights.offset_right = width * 0.5
		start_lights.offset_top = 24
		start_lights.offset_bottom = 24 + start_lights.custom_minimum_size.y

	add_child(results)
	stats.anchor_left = 0.5
	stats.anchor_right = 0.5
	stats.offset_left = -220
	stats.offset_right = 220
	stats.offset_top = 250
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(stats)


## F3: show or hide the FPS / network overlay.
func toggle_stats() -> void:
	stats.visible = not stats.visible


## total_laps 0 = practice (no limit); status replaces the running time (on the grid, finished).
func show_laps(lap_number: int, total_laps: int, lap_time: float, last_lap: float, best_lap: float, status: String = "") -> void:
	if total_laps > 0:
		_lap_label.text = tr("HUD_LAP_OF").format({"lap": lap_number, "total": total_laps})
	else:
		_lap_label.text = tr("HUD_LAP").format({"lap": lap_number})
	HudStyle.set_color(_time_label, HudStyle.TEXT)
	if not status.is_empty():
		_time_label.text = status
	elif _lap_flash > 0.0:
		_time_label.text = _lap_flash_text
		HudStyle.set_color(_time_label, _lap_flash_color)
	else:
		_time_label.text = format_time(lap_time) if lap_time >= 0.0 else tr("HUD_OUT_LAP")
	_last_label.text = tr("HUD_LAST_LAP").format({"time": format_time(last_lap)})
	_best_label.text = tr("HUD_BEST_LAP").format({"time": format_time(best_lap)})


## A short race message in the middle at the top (shortcuts, penalties) for `seconds`.
func show_message(text: String, color: Color, seconds: float = 3.0) -> void:
	_message.text = text
	_message.add_theme_color_override("font_color", color)
	_message_left = seconds


## A lap was finished: its time replaces the running time for a moment, in the TV colour
## (purple = fastest of the session, green = own best, yellow = slower).
func show_lap_completed(lap_time: float, kind: RaceRanking.LapKind) -> void:
	_lap_flash = LAP_FLASH_TIME
	_lap_flash_text = format_time(lap_time)
	_lap_flash_color = [HudStyle.PURPLE, HudStyle.GREEN, HudStyle.YELLOW][kind]
	HudStyle.pop(_time_label)


## Race position, e.g. "P2/8" (race only); a change flashes green (gained) or red (lost).
func show_position(position: int, count: int) -> void:
	_position_label.visible = true
	_position_label.text = tr("HUD_POSITION").format({"position": position, "count": count})
	if _position > 0 and position != _position:
		_position_flash = POSITION_FLASH_TIME
		HudStyle.set_color(_position_label, HudStyle.GAIN if position < _position else HudStyle.LOSS)
		HudStyle.pop(_position_label)
	_position = position


## Total penalty so far (race), hidden when zero.
func show_penalty(seconds: float) -> void:
	_penalty_label.visible = seconds > 0.0
	_penalty_label.text = tr("FINISH_PENALTY").format({"seconds": "%d" % roundi(seconds)})


func _process(delta: float) -> void:
	if _message_left > 0.0:
		_message_left -= delta
		if _message_left <= 0.0:
			_message.text = ""
	_lap_flash = maxf(_lap_flash - delta, 0.0)
	if _position_flash > 0.0:
		_position_flash -= delta
		if _position_flash <= 0.0:
			HudStyle.set_color(_position_label, HudStyle.GOLD)


func show_speed(kmh: float, kers_active: bool = false) -> void:
	speed_gauge.show_speed(kmh, kers_active)


## "+1 kolo", "+2 kola", "+5 kol" (Czech plural).
static func laps_behind(laps: int) -> String:
	var key := "STANDINGS_LAPS" if laps == 1 else ("STANDINGS_LAPS_FEW" if laps >= 2 and laps <= 4 else "STANDINGS_LAPS_MANY")
	return TranslationServer.translate(key).format({"laps": laps})


## 1:05.432, or "–" for no time yet.
static func format_time(seconds: float) -> String:
	if seconds < 0.0:
		return "–"
	var millis := roundi(seconds * 1000.0)
	return "%d:%02d.%03d" % [millis / 60000, (millis / 1000) % 60, millis % 1000]


func _panel(parent: Control, min_size: Vector2) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", HudStyle.panel())
	panel.custom_minimum_size = min_size
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	panel.add_child(box)
	return box


## Message when the player cut the track (in practice only informative).
func show_shortcut(rules: RaceRules, is_race: bool) -> void:
	if is_race:
		show_message(tr("LIMITS_SHORTCUT").format({"seconds": "%d" % roundi(rules.shortcut_penalty)}), Color(1, 0.35, 0.3))
	else:
		show_message(tr("LIMITS_SHORTCUT_PRACTICE"), Color(1, 0.75, 0.3))
