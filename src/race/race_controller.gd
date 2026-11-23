class_name RaceController
extends Node2D
## A session on one track. Offline: PRACTICE = rolling start and endless timed laps; RACE = grid,
## start lights with the clutch, the chosen number of laps, results, with bots (BotDriver).
## Online (Session IN_RACE, M4): the race of Session.race_setup; OnlineRace moves the remote cars
## and talks to the network, the host decides finish, penalties and results (PLAN.md C).
## Every driver is a Racer. BP boards, KERS, slipstream, shortcut check, tyre wear and the pit
## lane (autopilot + Space minigame) as in PLAN.md B. KERS unlocks once every car has crossed
## the line after the start. Physics runs at 60 Hz in _physics_process; drawing is smoothed by
## physics interpolation. The HUD is fed by RaceHudFeed.

enum Mode { PRACTICE, RACE }

const MENU_PATH := "res://src/ui/main_menu.tscn"
const TUNING_PATH := "res://data/car/car_tuning.tres"
const RULES_PATH := "res://data/race/race_rules.tres"
## The practice car starts this far before the line, so the first crossing starts lap 1.
const START_BEHIND_LINE := 40.0
## Results appear this long after the player crosses the line.
const RESULTS_DELAY := 2.0
## A second Esc within this many seconds leaves the race.
const LEAVE_CONFIRM_TIME := 2.0
## Painted grid boxes (the most cars in a race).
const GRID_SLOTS := LobbyValidator.MAX_CARS

## Set by the menu before opening the scene (offline).
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
var judge: IncidentJudge
var braking_points: BrakingPoints
var bp_markers := BpMarkers.new()
var pit_view: PitLaneView
## Tyre marks of all cars (between the track and the cars).
var skid_marks := SkidMarks.new()
## Gravel dust of all cars.
var tyre_smoke := TyreSmoke.new()
var camera := RaceCamera.new()
var hud := RaceHud.new()
## Online race glue (null offline).
var online: OnlineRace
## Race clock in seconds, advanced by the physics ticks.
var race_time := 0.0
## Set when the first car finishes: everyone else finishes at their next line crossing.
var leader_finished := false
var total_laps := 5
var tyre_wear := false
## KERS is locked for everyone until all cars have crossed the line after the start.
var kers_released := false
var _escape_time := -100.0


func _ready() -> void:
	var setup := Session.race_setup if Session.phase == Session.Phase.IN_RACE else {}
	mode = Mode.RACE if not setup.is_empty() else next_mode
	track = TrackCatalog.get_track(setup.settings.track if not setup.is_empty() else Settings.practice_track)
	tuning = load(TUNING_PATH)
	rules = load(RULES_PATH)
	total_laps = setup.settings.laps if not setup.is_empty() else Settings.race_laps
	tyre_wear = setup.settings.tyre_wear if not setup.is_empty() else Settings.tyre_wear
	judge = IncidentJudge.new(rules)
	judge.penalised.connect(_on_penalised)
	_build_scenery()
	if mode == Mode.RACE:
		start = RaceStart.new(rules, setup.seed if not setup.is_empty() else randi())
	if setup.is_empty():
		_build_offline_racers()
	else:
		online = OnlineRace.new(self)
		online.build_racers(setup)
		add_child(online)  # after the racers: its "loaded" message needs them
	player = me.car
	_warm_up_profiles()
	pit_view.setup(pit_lane, me.pit_stop.box_slot, me.color)  # the player's own garage
	add_child(camera)
	camera.target = player
	camera.make_current()
	camera.snap()
	add_child(hud)
	hud.setup(track, mode == Mode.RACE)
	hud.results.set_online(online != null, Session.is_host())
	hud.results.restart_pressed.connect(_on_restart)
	hud.results.menu_pressed.connect(_leave)


func _build_scenery() -> void:
	var track_view := TrackView.new()
	add_child(track_view)
	var grid: Array[Vector2] = []
	for slot in GRID_SLOTS:
		grid.append(RaceStart.grid_slot(track, rules, slot))
	track_view.setup(track, grid)
	pit_lane = PitLane.build(track, rules)
	pit_view = PitLaneView.new()
	add_child(pit_view)
	var scenery := TrackScenery.new()
	add_child(scenery)
	scenery.setup(track, pit_lane)
	add_child(skid_marks)
	add_child(tyre_smoke)
	racing_line = RacingLine.for_track(track)
	braking_points = BrakingPoints.find(track, racing_line.profile(tuning), rules.bp_min_speed_drop, pit_lane)
	add_child(bp_markers)
	bp_markers.show_points(track, braking_points)


func _build_offline_racers() -> void:
	var player_name := Settings.player_name if not Settings.player_name.is_empty() else tr("PLAYER_DEFAULT_NAME")
	var bots := Settings.bot_count if mode == Mode.RACE else 0
	var player_slot := _player_grid_slot(bots + 1)
	var colors := CarColors.COLORS.duplicate()
	colors.remove_at(clampi(Settings.car_color, 0, colors.size() - 1))
	var bot_index := 0
	for slot in bots + 1:
		if slot == player_slot:
			me = add_racer(player_name, CarColors.color(Settings.car_color), true, slot)
			continue
		var bot := add_racer(RaceSetup.BOT_NAMES[bot_index % RaceSetup.BOT_NAMES.size()], colors[bot_index % colors.size()], false, slot)
		bot.bot = BotDriver.new(racing_line, tuning, Settings.bot_difficulty as BotDriver.Difficulty, randi())
		bot_index += 1


## Grid slot of the player among `count` cars (session setting: back, random, pole).
func _player_grid_slot(count: int) -> int:
	match Settings.grid_start:
		1:
			return randi() % count
		2:
			return 0
	return count - 1


func add_racer(racer_name: String, color: Color, is_player: bool, slot: int) -> Racer:
	var racer := Racer.new(racer_name, color, is_player)
	racer.car = Car.new()
	add_child(racer.car)
	racer.car.setup(track, tuning, color, tyre_wear)
	racer.car.effects.marks = skid_marks
	racer.car.effects.smoke = tyre_smoke
	racer.laps = LapTracker.new(track)
	racer.shortcuts = ShortcutCheck.new(rules)
	racer.pit_stop = PitStop.new(pit_lane, rules, racers.size())
	racer.laps.line_crossed.connect(racer.car.kers.refill)
	racer.car.kers.locked = true
	racer.laps.lap_completed.connect(_on_lap_completed.bind(racer))
	if mode == Mode.RACE:
		var place := RaceStart.grid_slot(track, rules, slot)
		racer.car.place(place.x, place.y)
	else:
		racer.car.place(track.length - START_BEHIND_LINE, 0.0)
	racers.append(racer)
	return racer


## With tyre wear the bots (and the player's BP boards) need a profile per grip step: all now.
func _warm_up_profiles() -> void:
	if not tyre_wear:
		return
	var corners: Array[float] = [1.0]
	for racer in racers:
		if racer.bot and not corners.has(minf(racer.bot.pace * racer.bot.pace, 1.0)):
			corners.append(minf(racer.bot.pace * racer.bot.pace, 1.0))
	racing_line.warm_up(tuning, corners, 1.0 - tuning.tyre_loss_dead)


func _physics_process(delta: float) -> void:
	if online:
		online.before_tick(delta)
	if online == null or online.lights_started:
		race_time += delta  # online the race clock starts with the lights, like the start clock
	if start and (online == null or online.lights_started):
		var was_out := start.lights_out()
		start.update(delta)
		if start.lights_out() and not was_out:
			for racer in racers:
				racer.laps.start_from_grid(start.go_time)
				racer.ghost_until = start.go_time + rules.start_ghost_time
	for racer in racers:
		if racer.remote:
			_tick_remote(racer, delta)
			continue
		var input: CarInput
		if racer.finished or racer.retired:
			input = CarInput.new()  # cool-down: the car rolls out after the flag
		elif racer.bot:
			input = racer.bot.drive(racer, start, total_laps - racer.laps.laps - 1, racers, race_time)
		else:
			input = CarInput.from_keyboard()
		_tick(racer, input, delta)
	_resolve_contacts()
	judge.update(race_time)
	_update_kers_release()
	if online:
		online.after_tick(delta)


func _update_kers_release() -> void:
	if kers_released:
		return
	var trackers: Array[LapTracker] = []
	for racer in racers:
		trackers.append(racer.laps)
	if not Kers.release_due(trackers):
		return
	kers_released = true
	for racer in racers:
		racer.car.kers.locked = false
	hud.show_message(tr("KERS_RELEASED"), Color(0.35, 0.75, 1.0))


func _tick(racer: Racer, input: CarInput, delta: float) -> void:
	var car := racer.car
	if start and start.update_entry(racer.start_entry, input.clutch):
		car.hold()
		return
	var pit := racer.pit_stop
	var was_in_pit := pit.active()
	if pit.update(car, input.clutch, delta):
		if not was_in_pit and racer.is_player:
			hud.show_message(tr("PIT_LIMITER"), Color(1.0, 0.85, 0.2))
		racer.laps.update(car.query.distance, race_time, delta)
		racer.record_progress(race_time)
		return
	if was_in_pit:
		racer.shortcuts.reset_position()
	car.simulate(input, delta, _other_states(racer))
	_after_move(racer, delta)


## A car driven by the network (online): shown where its owner says, judged like any other.
func _tick_remote(racer: Racer, delta: float) -> void:
	var net := online.remote_state(racers.find(racer))
	if net == null or racer.retired:
		return
	var car := racer.car
	var was_in_pit := racer.net_in_pit
	car.state.position = net.position
	car.state.heading = net.heading
	car.state.velocity = net.velocity
	car.state.steer = net.steer
	car.last_input.brake = net.has(CarCodec.FLAG_BRAKE)
	car.last_input.throttle = net.has(CarCodec.FLAG_THROTTLE)
	racer.net_in_pit = net.has(CarCodec.FLAG_IN_PIT)
	racer.start_entry.held = net.has(CarCodec.FLAG_ON_GRID)
	car.after_external_move()
	if was_in_pit and not racer.net_in_pit:
		racer.shortcuts.reset_position()
	_after_move(racer, delta)


func _after_move(racer: Racer, delta: float) -> void:
	var car := racer.car
	racer.laps.update(car.query.distance, race_time, delta)
	racer.record_progress(race_time)
	if racer.finished or racer.net_in_pit or (online and not online.is_host):
		return  # online clients get every penalty (and its message) from the host
	if racer.shortcuts.update(track, car.query, tuning.width, car.state.velocity.length() * delta) and racer.is_player:
		hud.show_shortcut(rules, mode == Mode.RACE)


## Soft contact between all cars that are not ghosts; judged by the incident judge (offline and
## on the host). Online, remote cars are put back where their owner says on the next tick.
func _resolve_contacts() -> void:
	var touching: Array[Racer] = []
	var states: Array[CarState] = []
	for racer in racers:
		if not racer.is_ghost(race_time) and not racer.start_entry.held:
			touching.append(racer)
			states.append(racer.car.state)
	for contact in CarCollision.resolve(states, tuning, rules):
		var a := touching[contact.a]
		var b := touching[contact.b]
		a.car.after_external_move()
		b.car.after_external_move()
		if online == null or online.is_host:
			judge.report(contact, a, b, race_time)


func _on_penalised(striker: Racer, _victim: Racer, ghost: bool) -> void:
	if online:
		online.announce_penalty(striker, ghost)
	else:
		show_penalty_message(striker, ghost)


func show_penalty_message(striker: Racer, ghost: bool) -> void:
	var text := tr("INCIDENT_PENALTY").format({"name": striker.name, "seconds": "%d" % roundi(rules.incident_penalty)})
	if ghost:
		text += " " + tr("INCIDENT_GHOST").format({"seconds": "%d" % roundi(rules.repeat_ghost_time)})
	hud.show_message(text, Color(1, 0.35, 0.3) if striker.is_player else Color(1, 0.75, 0.3))


func _other_states(racer: Racer) -> Array[CarState]:
	var states: Array[CarState] = []
	for other in racers:
		if other != racer and not other.pit_stop.active() and not other.net_in_pit:
			states.append(other.car.state)
	return states


func _on_lap_completed(lap_time: float, racer: Racer) -> void:
	if racer.is_player:
		hud.show_lap_completed(lap_time, RaceRanking.lap_kind(lap_time, racer, racers))
	if mode != Mode.RACE or racer.finished or (online and not online.is_host):
		return  # online clients learn the finish from the host
	if racer.laps.laps >= total_laps or leader_finished:
		racer.finished = true
		racer.finish_time = racer.laps.last_crossing
		leader_finished = true
		if racer.is_player:
			hud.show_message(tr("FINISH_TITLE"), Color.WHITE, RESULTS_DELAY)


func _process(delta: float) -> void:
	RaceHudFeed.update(self, delta)


func _on_restart() -> void:
	if online:
		Session.return_to_lobby()
	else:
		get_tree().reload_current_scene()


func _leave() -> void:
	if online:
		Session.leave()
	else:
		get_tree().change_scene_to_file(MENU_PATH)


## Esc twice within LEAVE_CONFIRM_TIME leaves (one stray press must not end a race, online
## the host's Esc would end it for everyone).
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		hud.toggle_stats()
		return
	if not event.is_action_pressed(&"ui_cancel"):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _escape_time < LEAVE_CONFIRM_TIME:
		_leave()
		return
	_escape_time = now
	var key := "LEAVE_CONFIRM_HOST" if online and online.is_host else "LEAVE_CONFIRM"
	hud.show_message(tr(key), Color(1, 0.85, 0.2), LEAVE_CONFIRM_TIME)
