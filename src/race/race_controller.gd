class_name RaceController
extends Node2D
## A session on one track. Offline: PRACTICE = rolling start and endless timed laps; RACE = grid,
## start lights with the clutch, the chosen number of laps, results, with bots (BotDriver);
## QUALIFYING (before a race when chosen) = timed laps alone (Qualifying), then the scene is
## loaded again as the RACE with the grid of the result. RaceBuilder builds the scene.
## Online (Session IN_RACE, M4): the race of Session.race_setup; OnlineRace moves the remote cars
## and talks to the network, the host decides finish, penalties and results (PLAN.md C).
## Every driver is a Racer. BP boards, KERS, slipstream, shortcut check, tyre wear and the pit
## lane (autopilot + Space minigame) as in PLAN.md B. KERS unlocks once every car has crossed
## the line after the start. Physics runs at 60 Hz in _physics_process; drawing is smoothed by
## physics interpolation. The HUD is fed by RaceHudFeed.

enum Mode { PRACTICE, RACE, QUALIFYING }

const MENU_PATH := "res://src/ui/main_menu.tscn"
const TUNING_PATH := "res://data/car/car_tuning.tres"
const RULES_PATH := "res://data/race/race_rules.tres"
## Results appear this long after the player crosses the line.
const RESULTS_DELAY := 2.0
## A second Esc within this many seconds leaves the race.
const LEAVE_CONFIRM_TIME := 2.0

## Set by the menu before opening the scene (offline).
static var next_mode := Mode.PRACTICE
## Offline: entrant indices in grid order after qualifying, used once by the next race scene.
static var next_grid: Array[int] = []

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
## The qualifying session (null in practice and in the race).
var qualifying: Qualifying
var _quali_result_left := 0.0
var _escape_time := -100.0


func _ready() -> void:
	var setup := Session.race_setup if Session.phase == Session.Phase.IN_RACE else {}
	var grid := next_grid
	next_grid = []
	if setup.is_empty():
		mode = Mode.QUALIFYING if next_mode == Mode.RACE and Settings.qualifying and grid.is_empty() else next_mode
	else:
		mode = Mode.QUALIFYING if setup.settings.qualifying and not setup.has("grid_order") else Mode.RACE
	track = TrackCatalog.get_track(setup.settings.track if not setup.is_empty() else Settings.practice_track)
	tuning = load(TUNING_PATH)
	rules = load(RULES_PATH)
	total_laps = setup.settings.laps if not setup.is_empty() else Settings.race_laps
	tyre_wear = setup.settings.tyre_wear if not setup.is_empty() else Settings.tyre_wear
	judge = IncidentJudge.new(rules)
	judge.penalised.connect(_on_penalised)
	RaceBuilder.scenery(self)
	if mode == Mode.RACE:
		start = RaceStart.new(rules, setup.seed if not setup.is_empty() else randi())
	elif mode == Mode.QUALIFYING:
		qualifying = Qualifying.new(rules)
		kers_released = true
	if setup.is_empty():
		RaceBuilder.offline_racers(self, grid)
	else:
		online = OnlineRace.new(self)
		online.build_racers(setup)
		add_child(online)  # after the racers: its "loaded" message needs them
	player = me.car
	RaceBuilder.warm_up_profiles(self)
	pit_view.setup(pit_lane, me.pit_stop.box_slot, me.color)  # the player's own garage
	add_child(camera)
	camera.target = player
	camera.make_current()
	camera.snap()
	add_child(hud)
	hud.setup(track, mode == Mode.RACE, mode != Mode.PRACTICE)
	hud.results.set_online(online != null, Session.is_host())
	hud.results.restart_pressed.connect(_on_restart)
	hud.results.menu_pressed.connect(_leave)


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
			online.tick_remote(racer, delta)
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
	if qualifying:
		_update_qualifying(delta)
	if online:
		online.after_tick(delta)


## Offline / host: ends the session when it is over (online the grid goes to everybody and comes
## back through finish_qualifying); then shows the result and loads the race with that grid.
func _update_qualifying(delta: float) -> void:
	qualifying.update(race_time)
	if not qualifying.finished:
		if (online == null or online.is_host) and qualifying.should_end(race_time):
			if online:
				online.send_grid(qualifying.final_order())
			else:
				finish_qualifying(qualifying.final_order())
		return
	_quali_result_left -= delta
	if _quali_result_left <= 0.0:
		next_grid = qualifying.grid
		get_tree().reload_current_scene()  # online: Session.race_setup has the grid now


func finish_qualifying(grid: Array[int]) -> void:
	qualifying.finish(grid)
	_quali_result_left = rules.quali_result_time
	var place := grid.find(qualifying.entrants.find(qualifying.entrant_of(me))) + 1
	hud.show_message(tr("QUALI_RESULT").format({"position": place}), HudStyle.GOLD, rules.quali_result_time)


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
	if (start and start.update_entry(racer.start_entry, input.clutch)) or (qualifying and online and not online.lights_started):
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
	after_move(racer, delta)


func after_move(racer: Racer, delta: float) -> void:
	var car := racer.car
	racer.laps.update(car.query.distance, race_time, delta)
	racer.record_progress(race_time)
	if racer.finished or racer.net_in_pit or (online and not online.is_host):
		return  # online clients get every penalty (and its message) from the host
	if racer.shortcuts.update(track, car.query, tuning.width, car.state.velocity.length() * delta) and racer.is_player:
		hud.show_shortcut(rules, mode)


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


func on_lap_completed(lap_time: float, racer: Racer) -> void:
	if qualifying:
		var counted := qualifying.lap_completed(racer, lap_time)
		if racer.is_player:
			hud.show_lap_completed(lap_time, RaceRanking.lap_kind(lap_time, racer, racers) if counted else RaceRanking.LapKind.SLOWER)
		return
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
