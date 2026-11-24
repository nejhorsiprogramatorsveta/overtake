extends Control
## "Jak hrát" from the main menu (user 2026-11-24): four short cards - controls, BP boards, KERS,
## pit stops with tyre wear - each with a cut-out of a real track (Austria, drawn like in the
## race) and arrows, key caps and labels on it. The track is built once into the first
## picture's viewport; the others show the same world (shared World2D) from their own spot.
## Key names follow the player's bindings. Esc = back.

const MENU_PATH := "res://src/ui/main_menu.tscn"
const TRACK_ID := "austria"
const PLAYER_COLOR := 1
const OTHER_COLOR := 3
const BRAKE := Color(1.0, 0.35, 0.3)
const TURN := Color(0.4, 0.9, 0.45)
const KERS_BLUE := Color(0.35, 0.75, 1.0)
const PIT_YELLOW := Color(1.0, 0.85, 0.2)

var track: TrackData
var tuning: CarTuning
var rules: RaceRules
var line: RacingLine
var lane: PitLane
var shots: Array[HelpShot] = []
var _world := Node2D.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(MenuBackground.new())
	track = TrackCatalog.get_track(TRACK_ID)
	tuning = load("res://data/car/car_tuning.tres")
	rules = load("res://data/race/race_rules.tres")
	line = RacingLine.for_track(track)
	lane = PitLane.build(track, rules)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	center.add_child(column)
	var title := Label.new()
	title.text = "HELP_TITLE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	column.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	column.add_child(grid)
	var keys := {"throttle": _key(&"throttle"), "brake": _key(&"brake"), "left": _key(&"steer_left"),
			"right": _key(&"steer_right"), "clutch": _key(&"clutch"), "kers": _key(&"kers")}
	for card: Array in [["HELP_CONTROLS_TITLE", "HELP_CONTROLS_TEXT", _controls_shot],
			["HELP_BP_TITLE", "HELP_BP_TEXT", _bp_shot], ["HELP_KERS_TITLE", "HELP_KERS_TEXT", _kers_shot],
			["HELP_PIT_TITLE", "HELP_PIT_TEXT", _pit_shot]]:
		_card(grid, card[0], tr(card[1]).format(keys), card[2])
	var back := Button.new()
	back.text = "SETTINGS_BACK"
	back.custom_minimum_size = Vector2(300, 46)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_go_back)
	column.add_child(back)
	back.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_go_back()


func _go_back() -> void:
	get_tree().change_scene_to_file(MENU_PATH)


## The first key of an action ("W"), as the player bound it.
static func _key(action: StringName) -> String:
	var events := KeyBindings.events(action)
	return KeyBindings.display(events[0]) if not events.is_empty() else "–"


## A card in `parent`; added to the tree first, so its viewport can share the world.
func _card(parent: Control, title_key: String, text: String, fill: Callable) -> void:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var title := Label.new()
	title.text = title_key
	title.add_theme_font_override("font", HudStyle.bold())
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)
	var shot := HelpShot.new()
	box.add_child(shot)
	if shots.is_empty():
		_build_world(shot.viewport)
	else:
		shot.viewport.world_2d = shots[0].viewport.world_2d
	shots.append(shot)
	fill.call(shot)
	var label := Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(HelpShot.SIZE.x, 0)
	label.add_theme_font_size_override("font_size", 16)
	box.add_child(label)


## The track as in the race: ground, pit lane, scenery, BP boards.
func _build_world(viewport: SubViewport) -> void:
	viewport.add_child(_world)
	var view := TrackView.new()
	_world.add_child(view)
	var grid: Array[Vector2] = []
	for slot in 4:
		grid.append(RaceStart.grid_slot(track, rules, slot))
	view.setup(track, grid)
	var pit_view := PitLaneView.new()
	_world.add_child(pit_view)
	pit_view.setup(lane, 0, CarColors.color(PLAYER_COLOR))
	var scenery := TrackScenery.for_track(track)
	_world.add_child(scenery)
	scenery.setup(track, lane)
	var markers := BpMarkers.new()
	_world.add_child(markers)
	markers.show_points(track, _braking_points())


func _braking_points() -> BrakingPoints:
	return BrakingPoints.find(track, line.profile(tuning), rules.bp_min_speed_drop, lane)


func _car(at: Vector2, heading: float, color_index: int) -> void:
	var car := CarView.new()
	car.tuning = tuning
	var color := CarColors.color(color_index)
	car.body_color = color
	car.accent_color = CarColors.accent_for(color)
	car.helmet_color = CarColors.helmet_for(color)
	car.livery = CarLivery.for_color(color)
	car.position = at
	car.rotation = heading
	_world.add_child(car)


## World point on the racing line `distance` metres along the lap.
func _on_line(distance: float) -> Vector2:
	var d := fposmod(distance, track.length)
	return track.position_at(d, track.racing_line[track._index_at(d)])


## Points along the racing line between two distances (every 4 m).
func _line_points(from: float, to: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var d := from
	while d < to:
		points.append(_on_line(d))
		d += 4.0
	points.append(_on_line(to))
	return points


## The player's car on the grid, the keys around it, and the start lights.
func _controls_shot(shot: HelpShot) -> void:
	var slot := RaceStart.grid_slot(track, rules, 0)
	var heading := track.heading_at(slot.x)
	var at := track.position_at(slot.x, slot.y)
	_car(at, heading, PLAYER_COLOR)
	var other := RaceStart.grid_slot(track, rules, 1)
	_car(track.position_at(other.x, other.y), track.heading_at(other.x), OTHER_COLOR)
	var forward := Vector2.from_angle(heading)
	var right := Vector2(-forward.y, forward.x)
	shot.frame(PackedVector2Array([at - forward * 9.0, at + forward * 9.0, at + right * 6.0, at - right * 6.0]), 6.0)
	shot.key(at + forward * 7.0, _key(&"throttle"))
	shot.key(at - forward * 7.0, _key(&"brake"))
	shot.key(at - right * 4.5, _key(&"steer_left"))
	shot.key(at + right * 4.5, _key(&"steer_right"))
	shot.extra = func(canvas: Control) -> void:
		for i in 5:
			canvas.draw_circle(Vector2(26.0 + i * 22.0, 22.0), 8.0, Color(0.9, 0.1, 0.1))
		HelpShot.text_at(canvas, Vector2(84.0, 48.0), tr("HELP_LABEL_LIGHTS"), Color.WHITE, 14)
		HelpShot.key_cap(canvas, Vector2(HelpShot.SIZE.x - 80.0, HelpShot.SIZE.y - 26.0), _key(&"clutch"))
		HelpShot.text_at(canvas, Vector2(HelpShot.SIZE.x - 80.0, HelpShot.SIZE.y - 52.0), tr("HELP_LABEL_CLUTCH"), Color.WHITE, 14)


## The first BP board: full throttle up to it, brake in a straight line, then turn in.
func _bp_shot(shot: HelpShot) -> void:
	var bp := _braking_points()
	var board := bp.distances[0]
	var apex := _apex_after(board)
	var car_at := board - 40.0
	_car(_on_line(car_at), track.heading_at(fposmod(car_at, track.length)), PLAYER_COLOR)
	var turn_in := lerpf(board, apex, 0.75)
	var points := _line_points(car_at - 10.0, apex + 25.0)
	shot.frame(points, 14.0)
	shot.path(_line_points(board, turn_in), BRAKE, tr("HELP_LABEL_BRAKE"))
	shot.path(_line_points(turn_in, apex + 25.0), TURN, tr("HELP_LABEL_TURN"))


## Distance of the slowest point of the corner after a braking point.
func _apex_after(from: float) -> float:
	var profile := line.profile(tuning)
	var best := from
	var d := from
	while d < from + 250.0:
		if profile.speeds[track._index_at(fposmod(d, track.length))] < profile.speeds[track._index_at(fposmod(best, track.length))]:
			best = d
		d += 4.0
	return best


## Out of the first corner onto the straight: KERS.
func _kers_shot(shot: HelpShot) -> void:
	var apex := _apex_after(_braking_points().distances[0])
	var car_at := apex + 20.0
	_car(_on_line(car_at), track.heading_at(fposmod(car_at, track.length)), PLAYER_COLOR)
	shot.frame(_line_points(apex - 10.0, apex + 190.0), 12.0)
	shot.path(_line_points(car_at + 6.0, apex + 175.0), KERS_BLUE, _key(&"kers"))
	shot.extra = func(canvas: Control) -> void:
		for i in 3:
			canvas.draw_rect(Rect2(14.0 + i * 26.0, 14.0, 22.0, 12.0), KERS_BLUE)
		HelpShot.text_at(canvas, Vector2(52.0, 42.0), tr("HELP_LABEL_KERS_USES"), Color.WHITE, 14)


## The pit entry, the lane to the own garage, and the minigame bar.
func _pit_shot(shot: HelpShot) -> void:
	var box := lane.box_distance(0)
	var points := PackedVector2Array()
	var s := 0.0
	while s < box:
		points.append(lane.position_at(s))
		s += 4.0
	points.append(lane.position_at(box))
	var direction := lane.direction_at(box)
	_car(lane.position_at(box), direction.angle(), PLAYER_COLOR)
	var view := points.duplicate()
	view.append(track.position_at(lane.entry_distance - 40.0, 0.0))
	view.append(lane.position_at(box + 30.0))
	shot.frame(view, 22.0)
	shot.label(points[0], tr("HELP_LABEL_PIT_ENTRY"), PIT_YELLOW)
	var arrow := points.slice(1, maxi(points.size() - 3, 2))
	shot.path(arrow, PIT_YELLOW, tr("HELP_LABEL_GARAGE"))
	shot.extra = func(canvas: Control) -> void:
		var bar := Rect2(70.0, 38.0, 170.0, 12.0)
		canvas.draw_rect(bar.grow(2.0), HelpShot.OUTLINE)
		canvas.draw_rect(bar, Color(0.35, 0.36, 0.4))
		var green := bar.size.x * rules.pit_green_from
		canvas.draw_rect(Rect2(bar.position + Vector2(green, 0.0), Vector2(bar.size.x - green, bar.size.y)), TURN)
		var mark := bar.position + Vector2(bar.size.x * 0.95, -4.0)
		canvas.draw_colored_polygon(PackedVector2Array([mark, mark + Vector2(-6, -9), mark + Vector2(6, -9)]), Color.WHITE)
		HelpShot.text_at(canvas, bar.position + Vector2(bar.size.x * 0.5, -22.0), tr("HELP_LABEL_PIT_BAR").format({"clutch": _key(&"clutch")}), Color.WHITE, 14)
