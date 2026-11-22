class_name RaceController
extends Node2D
## Offline session on the chosen track (M1/M2): PRACTICE = rolling start and endless timed
## laps; RACE = grid, start lights with the clutch, RaceRules.laps laps and a finish screen.
## BP boards show the recommended braking points; K = KERS (3x per lap), slipstream behind cars;
## track limits warn and (in a race) add penalties. (M2 adds more rules, M3 bots, M4 network.)
## Physics runs at 60 Hz in _physics_process; drawing is smoothed by physics interpolation.

enum Mode { PRACTICE, RACE }

const MENU_PATH := "res://src/ui/main_menu.tscn"
const TUNING_PATH := "res://data/car/car_tuning.tres"
const RULES_PATH := "res://data/race/race_rules.tres"
const PLAYER_COLOR := Color(0.86, 0.13, 0.15)
## The practice car starts this far before the line, so the first crossing starts lap 1.
const START_BEHIND_LINE := 40.0

## Set by the menu before opening the scene.
static var next_mode := Mode.PRACTICE

var mode := Mode.PRACTICE
var track: TrackData
var tuning: CarTuning
var rules: RaceRules
var player: Car
var laps: LapTracker
var start: RaceStart
var start_entry := RaceStart.Entry.new()
var limits: TrackLimits
var braking_points: BrakingPoints
var bp_markers := BpMarkers.new()
var camera := RaceCamera.new()
var hud := RaceHud.new()
## Race clock in seconds, advanced by the physics ticks (deterministic).
var race_time := 0.0
## Total race time incl. penalties once the player has finished, else -1.
var result_time := -1.0


func _ready() -> void:
	mode = next_mode
	track = TrackCatalog.get_track(Settings.practice_track)
	tuning = load(TUNING_PATH)
	rules = load(RULES_PATH)
	var track_view := TrackView.new()
	add_child(track_view)
	track_view.setup(track)
	braking_points = BrakingPoints.find(track, SpeedProfile.compute(track, tuning), rules.bp_min_speed_drop)
	add_child(bp_markers)
	bp_markers.show_points(track, braking_points)
	player = Car.new()
	add_child(player)
	player.setup(track, tuning, PLAYER_COLOR)
	laps = LapTracker.new(track)
	limits = TrackLimits.new(rules)
	laps.line_crossed.connect(player.kers.refill)
	if mode == Mode.RACE:
		player.place(track.length - rules.grid_first, -rules.grid_lateral)
		start = RaceStart.new(rules, randi())
	else:
		player.place(track.length - START_BEHIND_LINE, 0.0)
	add_child(camera)
	camera.target = player
	camera.make_current()
	camera.snap()
	add_child(hud)
	hud.setup(track, mode == Mode.RACE)


func _physics_process(delta: float) -> void:
	race_time += delta
	var input := CarInput.from_keyboard()
	if start:
		var was_out := start.lights_out()
		start.update(delta)
		if start.lights_out() and not was_out:
			laps.start_from_grid(start.go_time)
		if start.update_entry(start_entry, input.clutch):
			player.hold()
			return
	player.simulate(input, delta)
	laps.update(player.query.distance, race_time, delta)
	if result_time < 0.0:
		_report_limits(limits.update(track, player.query, tuning.width, player.state.velocity.length() * delta))
	if mode == Mode.RACE and result_time < 0.0 and laps.laps >= rules.laps:
		result_time = laps.last_crossing - start.go_time + total_penalty()


## All seconds added to the race time (jump start + track limits).
func total_penalty() -> float:
	return (start.penalty(start_entry) if start else 0.0) + limits.penalty


func _report_limits(event: TrackLimits.Event) -> void:
	var seconds := {"seconds": "%d" % roundi(rules.track_limit_penalty)}
	match event:
		TrackLimits.Event.WARNING:
			if mode == Mode.RACE:
				hud.show_message(tr("LIMITS_WARNING").format({"count": limits.violations, "max": rules.track_limit_warnings}), Color(1, 0.75, 0.3))
			else:
				hud.show_message(tr("LIMITS_PRACTICE").format({"count": limits.violations}), Color(1, 0.75, 0.3))
		TrackLimits.Event.PENALTY:
			if mode == Mode.RACE:
				hud.show_message(tr("LIMITS_PENALTY").format(seconds), Color(1, 0.35, 0.3))
			else:
				hud.show_message(tr("LIMITS_PRACTICE").format({"count": limits.violations}), Color(1, 0.75, 0.3))
		TrackLimits.Event.SHORTCUT:
			if mode == Mode.RACE:
				hud.show_message(tr("LIMITS_SHORTCUT").format({"seconds": "%d" % roundi(rules.shortcut_penalty)}), Color(1, 0.35, 0.3))
			else:
				hud.show_message(tr("LIMITS_SHORTCUT_PRACTICE"), Color(1, 0.75, 0.3))


func _process(_delta: float) -> void:
	hud.show_speed(player.speed_kmh())
	hud.kers_gauge.show_state(player.kers.uses_left, tuning.kers_uses,
			player.kers.active_left / tuning.kers_duration, player.state.tow)
	var total := rules.laps if mode == Mode.RACE else 0
	var status := ""
	if start and not start.lights_out():
		status = tr("HUD_ON_GRID")
	elif result_time >= 0.0:
		status = tr("FINISH_TITLE")
	hud.show_laps(mini(laps.laps + 1, total) if total > 0 else laps.laps + 1, total,
			laps.current_lap_time(race_time), laps.last_lap, laps.best_lap, status)
	hud.minimap.show_cars(PackedVector2Array([player.state.position]), PackedColorArray([PLAYER_COLOR]))
	if start:
		hud.start_lights.show_start(start, start_entry, race_time)
	if mode == Mode.RACE:
		hud.show_penalty(total_penalty())
	if result_time >= 0.0:
		hud.show_finish(result_time, total_penalty(), laps.best_lap)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_tree().change_scene_to_file(MENU_PATH)
