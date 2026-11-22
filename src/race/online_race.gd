class_name OnlineRace
extends Node
## Glue between the race scene and the network (PLAN.md C), child of RaceController in an online
## race. Every peer runs the same race with all cars:
## - its own car (and on the host the bots) is simulated locally, with no input delay;
## - every other car is "remote": shown from received states on the sender's timeline
##   (SnapshotTimeline + StateBuffer, interpolated, short gaps extrapolated).
## Clients send their car every tick; the host sends a snapshot of all cars every tick and, a few
## times per second, the race info it decides: finish, penalties (jump start, shortcuts,
## collisions), pit stops, retirements. The lights start when every player has loaded.

## Race info this often (s).
const INFO_INTERVAL := 0.2
## The host starts the lights at the latest this long after loading, even if someone is missing.
const LOAD_TIMEOUT := 6.0
## Host: a client state further than this from its previous one is dropped (teleport).
const MAX_JUMP := 40.0

var race: RaceController
var is_host := false
var lights_started := false
## Racer index of every peer's car.
var index_of_peer: Dictionary[int, int] = {}
var _peer_of_index: Dictionary[int, int] = {}
var _loaded: Dictionary[int, bool] = {}
var _load_wait := 0.0
var _seq := 0
var _tick := 0
var _info_left := 0.0
var _start_reported := false
## Client: one timeline (host ticks) for all cars. Host: one timeline per client.
var _timelines: Dictionary[int, SnapshotTimeline] = {}
var _buffers: Dictionary[int, StateBuffer] = {}


func _init(race_controller: RaceController) -> void:
	race = race_controller
	is_host = Session.is_host()
	name = "OnlineRace"


func _ready() -> void:
	var net := Session.race_net
	net.state_received.connect(_on_state)
	net.snapshot_received.connect(_on_snapshot)
	net.info_received.connect(_on_info)
	net.client_event_received.connect(_on_client_event)
	net.host_event_received.connect(_on_host_event)
	Session.player_left.connect(_on_player_left)
	net.send_client_event(RaceNet.ClientEvent.LOADED)


## The racers of the setup, in its order (the same index on every peer).
func build_racers(setup: Dictionary) -> void:
	var my_id := Session.my_id()
	var difficulty: int = setup.settings.difficulty
	for car: Dictionary in setup.cars:
		var peer: int = car.peer
		var racer := race.add_racer(car.name, CarColors.color(car.color), peer == my_id, car.slot)
		var index := race.racers.size() - 1
		if peer == 0 and is_host:
			racer.bot = BotDriver.new(race.racing_line, race.tuning, difficulty as BotDriver.Difficulty, setup.seed + index)
		elif peer != my_id:
			racer.remote = true
			_buffers[index] = StateBuffer.new()
		if peer != 0:
			index_of_peer[peer] = index
			_peer_of_index[index] = peer
		if racer.is_player:
			race.me = racer
	if is_host:
		for peer: int in index_of_peer:
			if peer != my_id:
				_timelines[peer] = SnapshotTimeline.new()
	else:
		_timelines[0] = SnapshotTimeline.new()


## Before the cars move: time the lights (host) and the playback of remote cars.
func before_tick(delta: float) -> void:
	for timeline: SnapshotTimeline in _timelines.values():
		timeline.update(delta)
	if is_host and not lights_started:
		_load_wait += delta
		if _loaded.size() >= index_of_peer.size() or _load_wait >= LOAD_TIMEOUT:
			Session.race_net.send_host_event(RaceNet.HostEvent.LIGHTS)


## The state a remote car shows this tick (null before anything arrived).
func remote_state(index: int) -> CarCodec.NetCar:
	var buffer: StateBuffer = _buffers.get(index)
	if buffer == null or buffer.is_empty():
		return null
	var timeline: SnapshotTimeline = _timelines.get(0 if not is_host else _peer_of_index.get(index, -1))
	if timeline == null:
		return buffer.newest()  # host: a bot never is remote; safety
	return buffer.sample(timeline.render_time(Time.get_ticks_msec()))


## After the cars moved: send the own car (client) or all cars and the race info (host).
func after_tick(delta: float) -> void:
	var me := race.me
	if not _start_reported and not me.start_entry.held:
		_start_reported = true
		Session.race_net.send_client_event(RaceNet.ClientEvent.START_RESULT, me.start_entry.reaction)
		if me.start_entry.jump_start:
			Session.race_net.send_client_event(RaceNet.ClientEvent.JUMP_START)
	if not is_host:
		_seq += 1
		Session.race_net.send_state(_seq, CarCodec.NetCar.from_car(me.car, _flags(me)))
		return
	_tick += 1
	var cars := {}
	for i in race.racers.size():
		cars[i] = CarCodec.NetCar.from_car(race.racers[i].car, _flags(race.racers[i]))
	Session.race_net.send_snapshot(CarCodec.encode_snapshot(_tick, cars))
	_info_left -= delta
	if _info_left <= 0.0:
		_info_left = INFO_INTERVAL
		Session.race_net.send_info(_info_rows())


## Host: a collision penalty, shown to everybody.
func announce_penalty(striker: Racer, ghost: bool) -> void:
	var kind := RaceNet.HostEvent.PENALTY_GHOST if ghost else RaceNet.HostEvent.PENALTY
	Session.race_net.send_host_event(kind, race.racers.find(striker))


func _flags(racer: Racer) -> int:
	var flags := 0
	if racer.pit_stop.active() or racer.net_in_pit:
		flags |= CarCodec.FLAG_IN_PIT
	if racer.start_entry.held:
		flags |= CarCodec.FLAG_ON_GRID
	return flags


## [finished, race seconds, shortcut penalty, incident penalty, incidents, jump start, reaction,
##  pit stops, retired, ghost seconds left] per car (RaceNet.INFO_FIELDS).
func _info_rows() -> Array:
	var rows := []
	var go := race.start.go_time if race.start else 0.0
	for racer in race.racers:
		rows.append([racer.finished, racer.finish_time - go if racer.finished else -1.0, racer.shortcuts.penalty,
				racer.incident_penalty, racer.incidents, racer.start_entry.jump_start, racer.start_entry.reaction,
				racer.pit_stop.stops, racer.retired, maxf(racer.ghost_until - race.race_time, 0.0)])
	return rows


func _on_state(peer_id: int, seq: int, car: CarCodec.NetCar) -> void:
	var index: int = index_of_peer.get(peer_id, -1)
	var timeline: SnapshotTimeline = _timelines.get(peer_id)
	if index < 0 or timeline == null or race.racers[index].retired:
		return
	var buffer := _buffers[index]
	var newest := buffer.newest()
	if newest and newest.position.distance_to(car.position) > MAX_JUMP:
		return
	var time := timeline.seq_ms(seq)
	timeline.observe_ms(time, Time.get_ticks_msec())
	buffer.push(time, car)


func _on_snapshot(data: PackedByteArray) -> void:
	if is_host:
		return
	var decoded := CarCodec.decode_snapshot(data, race.racers.size())
	if decoded.is_empty():
		return
	var time := SnapshotTimeline.tick_ms(decoded[0])
	_timelines[0].observe_ms(time, Time.get_ticks_msec())
	var cars: Dictionary = decoded[1]
	for index: int in cars:
		if _buffers.has(index):
			_buffers[index].push(time, cars[index])


func _on_info(rows: Array) -> void:
	if is_host or rows.size() != race.racers.size():
		return
	var go := race.start.go_time if race.start else 0.0
	for i in rows.size():
		var row: Array = rows[i]
		var racer := race.racers[i]
		var was_finished := racer.finished
		racer.finished = bool(row[0])
		if racer.finished and not was_finished:
			racer.finish_time = float(row[1]) + go
			if racer.is_player:
				race.hud.show_message(tr("FINISH_TITLE"), Color.WHITE, RaceController.RESULTS_DELAY)
		racer.shortcuts.penalty = clampf(float(row[2]), 0.0, 999.0)
		racer.incident_penalty = clampf(float(row[3]), 0.0, 999.0)
		racer.incidents = clampi(int(row[4]), 0, 999)
		racer.start_entry.jump_start = bool(row[5])
		if racer.remote:
			racer.start_entry.reaction = float(row[6])
			racer.pit_stop.stops = clampi(int(row[7]), 0, 99)
		racer.retired = bool(row[8])
		racer.ghost_until = race.race_time + clampf(float(row[9]), 0.0, 30.0)


func _on_client_event(peer_id: int, kind: int, value: float) -> void:
	var index: int = index_of_peer.get(peer_id, -1)
	if index < 0:
		return
	var racer := race.racers[index]
	match kind:
		RaceNet.ClientEvent.LOADED:
			_loaded[peer_id] = true
		RaceNet.ClientEvent.START_RESULT:
			if racer.remote:
				racer.start_entry.reaction = clampf(value, -1.0, 10.0)
		RaceNet.ClientEvent.JUMP_START:
			if racer.remote:
				racer.start_entry.jump_start = true


func _on_host_event(kind: int, index: int, _value: float) -> void:
	match kind:
		RaceNet.HostEvent.LIGHTS:
			lights_started = true
		RaceNet.HostEvent.PENALTY, RaceNet.HostEvent.PENALTY_GHOST:
			if index < race.racers.size():
				race.show_penalty_message(race.racers[index], kind == RaceNet.HostEvent.PENALTY_GHOST)


func _on_player_left(peer_id: int) -> void:
	var index: int = index_of_peer.get(peer_id, -1)
	if index >= 0:
		race.racers[index].retired = true
