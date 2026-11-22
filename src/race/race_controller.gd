class_name RaceController
extends Node2D
## Offline session on the chosen track: PRACTICE = rolling start and endless timed laps;
## RACE = grid, start lights with the clutch, the chosen number of laps, results. Every driver is a
## Racer; in a race the chosen number of bots (BotDriver) start with the player. BP boards, KERS, slipstream, track limits, tyre wear
## and the pit lane (autopilot + Space minigame) as in PLAN.md B.
## Physics runs at 60 Hz in _physics_process; drawing is smoothed by physics interpolation.

enum Mode { PRACTICE, RACE }

const MENU_PATH := "res://src/ui/main_menu.tscn"
const TUNING_PATH := "res://data/car/car_tuning.tres"
const RULES_PATH := "res://data/race/race_rules.tres"
## The practice car starts this far before the line, so the first crossing starts lap 1.
const START_BEHIND_LINE := 40.0
## Results appear this long after the player crosses the line.
const RESULTS_DELAY := 2.0
## Names of the computer drivers (invented).
const BOT_NAMES: Array[String] = ["Novák", "Rossi", "Müller", "Dubois", "Kowalski", "Hansen", "Silva",
		"Tanaka", "García", "Larsen", "Horvat"]

## Set by the menu before opening the scene.
static var next_mode := Mode.PRACTICE

var mode := Mode.PRACTICE
var track: TrackData
var tuning: CarTuning
var rules: RaceRules
var racers: Array[Racer] = []
var me: Racer
## The player's car (camera, HUD).
var player: Car
var start: RaceStart
var pit_lane: PitLane
var racing_line: RacingLine
var braking_points: BrakingPoints
var bp_markers := BpMarkers.new()
## Grip factor the shown BP boards were computed for (they move earlier as the tyres wear).
var _bp_grip := 1.0
var camera := RaceCamera.new()
var hud := RaceHud.new()
## Race clock in seconds, advanced by the physics ticks (deterministic).
var race_time := 0.0
## Set when the first car finishes: everyone else finishes at their next line crossing.
var leader_finished := false
## Laps of this race (chosen in the session settings).
var total_laps := 5


func _ready() -> void:
	mode = next_mode
	track = TrackCatalog.get_track(Settings.practice_track)
	tuning = load(TUNING_PATH)
	rules = load(RULES_PATH)
	total_laps = Settings.race_laps
	var track_view := TrackView.new()
	add_child(track_view)
	track_view.setup(track)
	pit_lane = PitLane.build(track, rules)
	var pit_view := PitLaneView.new()
	add_child(pit_view)
	racing_line = RacingLine.for_track(track)
	braking_points = BrakingPoints.find(track, racing_line.profile(tuning), rules.bp_min_speed_drop)
	add_child(bp_markers)
	bp_markers.show_points(track, braking_points)
	if mode == Mode.RACE:
		start = RaceStart.new(rules, randi())
	var player_name := Settings.player_name if not Settings.player_name.is_empty() else tr("PLAYER_DEFAULT_NAME")
	var player_color := CarColors.color(Settings.car_color)
	var bots := Settings.bot_count if mode == Mode.RACE else 0
	var player_slot := _player_grid_slot(bots + 1)
	var colors := CarColors.COLORS.duplicate()
	colors.remove_at(clampi(Settings.car_color, 0, colors.size() - 1))
	var bot_index := 0
	for slot in bots + 1:
		if slot == player_slot:
			me = _add_racer(player_name, player_color, true, slot)
			continue
		var bot := _add_racer(BOT_NAMES[bot_index % BOT_NAMES.size()], colors[bot_index % colors.size()], false, slot)
		bot.bot = BotDriver.new(racing_line, tuning, Settings.bot_difficulty as BotDriver.Difficulty, randi())
		bot_index += 1
	player = me.car
	pit_view.setup(pit_lane, 0, player_color)
	add_child(camera)
	camera.target = player
	camera.make_current()
	camera.snap()
	add_child(hud)
	hud.setup(track, mode == Mode.RACE)
	hud.results.restart_pressed.connect(get_tree().reload_current_scene)
	hud.results.menu_pressed.connect(get_tree().change_scene_to_file.bind(MENU_PATH))


## Grid slot of the player among `count` cars (session setting: back, random, pole).
func _player_grid_slot(count: int) -> int:
	match Settings.grid_start:
		1:
			return randi() % count
		2:
			return 0
	return count - 1


func _add_racer(racer_name: String, color: Color, is_player: bool, slot: int) -> Racer:
	var racer := Racer.new(racer_name, color, is_player)
	racer.car = Car.new()
	add_child(racer.car)
	racer.car.setup(track, tuning, color, Settings.tyre_wear)
	racer.laps = LapTracker.new(track)
	racer.limits = TrackLimits.new(rules)
	racer.pit_stop = PitStop.new(pit_lane, rules, racers.size())
	racer.laps.line_crossed.connect(racer.car.kers.refill)
	racer.laps.lap_completed.connect(_on_lap_completed.bind(racer))
	if mode == Mode.RACE:
		var side := -1.0 if slot % 2 == 0 else 1.0
		racer.car.place(track.length - rules.grid_first - slot * rules.grid_spacing, side * rules.grid_lateral)
	else:
		racer.car.place(track.length - START_BEHIND_LINE, 0.0)
	racers.append(racer)
	return racer


func _physics_process(delta: float) -> void:
	race_time += delta
	if start:
		var was_out := start.lights_out()
		start.update(delta)
		if start.lights_out() and not was_out:
			for racer in racers:
				racer.laps.start_from_grid(start.go_time)
	for racer in racers:
		var input: CarInput
		if racer.finished:
			input = CarInput.new()  # cool-down: the car rolls out after the flag
		elif racer.bot:
			input = racer.bot.drive(racer, start, total_laps - racer.laps.laps - 1)
		else:
			input = CarInput.from_keyboard()
		_tick(racer, input, delta)


func _tick(racer: Racer, input: CarInput, delta: float) -> void:
	var car := racer.car
	if start and start.update_entry(racer.start_entry, input.clutch):
		car.hold()
		return
	var pit := racer.pit_stop
	var was_in_pit := pit.active()
	if pit.update(car, input.clutch, delta):
		if not was_in_pit:
			car.set_ghost(true)
			if racer.is_player:
				hud.show_message(tr("PIT_LIMITER"), Color(1.0, 0.85, 0.2))
		racer.laps.update(car.query.distance, race_time, delta)
		return
	if was_in_pit:
		car.set_ghost(false)
		racer.limits.reset_position()
	car.simulate(input, delta, _other_states(racer))
	racer.laps.update(car.query.distance, race_time, delta)
	if not racer.finished:
		var event := racer.limits.update(track, car.query, tuning.width, car.state.velocity.length() * delta)
		if racer.is_player:
			_report_limits(event)


func _other_states(racer: Racer) -> Array[CarState]:
	var states: Array[CarState] = []
	for other in racers:
		if other != racer and not other.pit_stop.active():
			states.append(other.car.state)
	return states


func _on_lap_completed(_lap_time: float, racer: Racer) -> void:
	if mode != Mode.RACE or racer.finished:
		return
	if racer.laps.laps >= total_laps or leader_finished:
		racer.finished = true
		racer.finish_time = racer.laps.last_crossing
		leader_finished = true
		if racer.is_player:
			hud.show_message(tr("FINISH_TITLE"), Color.WHITE, RESULTS_DELAY)


func _report_limits(event: TrackLimits.Event) -> void:
	var limits := me.limits
	var warn := Color(1, 0.75, 0.3)
	var bad := Color(1, 0.35, 0.3)
	match event:
		TrackLimits.Event.WARNING:
			if mode == Mode.RACE:
				hud.show_message(tr("LIMITS_WARNING").format({"count": limits.violations, "max": rules.track_limit_warnings}), warn)
			else:
				hud.show_message(tr("LIMITS_PRACTICE").format({"count": limits.violations}), warn)
		TrackLimits.Event.PENALTY:
			if mode == Mode.RACE:
				hud.show_message(tr("LIMITS_PENALTY").format({"seconds": "%d" % roundi(rules.track_limit_penalty)}), bad)
			else:
				hud.show_message(tr("LIMITS_PRACTICE").format({"count": limits.violations}), warn)
		TrackLimits.Event.SHORTCUT:
			if mode == Mode.RACE:
				hud.show_message(tr("LIMITS_SHORTCUT").format({"seconds": "%d" % roundi(rules.shortcut_penalty)}), bad)
			else:
				hud.show_message(tr("LIMITS_SHORTCUT_PRACTICE"), warn)


func _process(_delta: float) -> void:
	var laps := me.laps
	hud.show_speed(player.speed_kmh())
	hud.kers_gauge.show_state(player.kers.uses_left, tuning.kers_uses,
			player.kers.active_left / tuning.kers_duration, player.state.tow)
	var total := total_laps if mode == Mode.RACE else 0
	var status := ""
	if start and not start.lights_out():
		status = tr("HUD_ON_GRID")
	elif me.finished:
		status = tr("FINISH_TITLE")
	hud.show_laps(mini(laps.laps + 1, total) if total > 0 else laps.laps + 1, total,
			laps.current_lap_time(race_time), laps.last_lap, laps.best_lap, status)
	var positions := PackedVector2Array()
	var colors := PackedColorArray()
	for racer in racers:
		positions.append(racer.car.state.position)
		colors.append(racer.color)
	hud.minimap.show_cars(positions, colors)
	if start:
		hud.start_lights.show_start(start, me.start_entry, race_time)
	if mode == Mode.RACE:
		hud.show_penalty(me.penalty(start))
		hud.show_position(RaceRanking.position_of(me, racers, start), racers.size())
		if me.finished and race_time - me.finish_time >= RESULTS_DELAY:
			hud.results.show_results(RaceRanking.order(racers, start), start, track)
	hud.pit_popup.show_stop(me.pit_stop)
	hud.kers_gauge.show_tyres(player.tyres.condition if player.tyres.enabled else -1.0)
	_update_braking_points()


## The player's BP boards follow the tyre grip in steps of 1 % (PLAN.md B: dynamic BP).
func _update_braking_points() -> void:
	var grip := snappedf(player.tyres.grip_factor(), 0.01)
	if is_equal_approx(grip, _bp_grip):
		return
	_bp_grip = grip
	braking_points = BrakingPoints.find(track, racing_line.profile(tuning, grip), rules.bp_min_speed_drop)
	bp_markers.show_points(track, braking_points)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_tree().change_scene_to_file(MENU_PATH)
