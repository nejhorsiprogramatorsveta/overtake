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
## Qualifying: only the people's cars exist; the info carries each best lap, and the host sends
## the grid (RaceNet.send_grid -> Session.race_setup.grid_order), then every peer loads the race.

## Race info this often (s).
const INFO_INTERVAL := 0.2
## The host starts the lights at the latest this long after loading, even if someone is missing.
const LOAD_TIMEOUT := 6.0
## Host: a client state further than possible since its previous one is dropped (teleport):
## MAX_SPEED per elapsed second plus a margin; after a few rejects in a row it is taken anyway
## (resync, e.g. after a long Wi-Fi stall).
const MAX_SPEED := 120.0
const JUMP_MARGIN := 15.0
const MAX_REJECTS := 5

var race: RaceController
var is_host := false
var lights_started := false
## Racer index of every peer's car.
var index_of_peer: Dictionary[int, int] = {}
var _peer_of_index: Dictionary[int, int] = {}
var _loaded: Dictionary[int, bool] = {}
var _load_wait := 0.0
var _info_left := 0.0
var _start_reported := false
## The race setup (grid_order arrives in it after qualifying).
var _setup: Dictionary = {}
## Host: consecutive rejected states per client (MAX_JUMP check), last accepted time.
var _rejects: Dictionary[int, int] = {}
var _accepted_ms: Dictionary[int, float] = {}
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
	_setup = setup
	var my_id := Session.my_id()
	var difficulty := int(setup.settings.difficulty) as BotDriver.Difficulty
	var quali := race.qualifying
	if quali:
		quali.decides = is_host
	for entry in setup.cars.size():
		var car: Dictionary = setup.cars[entry]
		var peer: int = car.peer
		if quali and peer == 0:  # bots do not drive in qualifying: estimated laps, same on every peer
			var driver := BotDriver.new(race.racing_line, race.tuning, difficulty, setup.seed + entry)
			quali.add_bot(car.name, CarColors.color(car.color), driver.lap_estimate(), setup.seed + entry)
			continue
		var grid: Array = setup.get("grid_order", [])
		var slot: int = grid.find(entry) if grid.size() == setup.cars.size() else car.slot
		var racer := RaceBuilder.add_racer(race, car.name, CarColors.color(car.color), peer == my_id, slot)
		var index := race.racers.size() - 1
		if peer == 0 and is_host:
			racer.bot = BotDriver.new(race.racing_line, race.tuning, difficulty, setup.seed + index)
		elif peer != my_id:
			racer.remote = true
			_buffers[index] = StateBuffer.new()
		if peer != 0:
			index_of_peer[peer] = index
			_peer_of_index[index] = peer
			racer.retired = not Session.players.has(peer)  # left during qualifying
		if quali:
			quali.add_human(racer)
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
	var quali := race.qualifying
	if quali and not quali.finished and _setup.has("grid_order"):
		race.finish_qualifying(_grid_entrants(_setup.grid_order))
	if is_host and not lights_started:
		_load_wait += delta
		if _loaded.size() >= index_of_peer.size() or _load_wait >= LOAD_TIMEOUT:
			Session.race_net.send_host_event(RaceNet.HostEvent.LIGHTS)


## Host: the qualifying result (entrant indices = race setup indices) to everybody.
func send_grid(order: Array[int]) -> void:
	Session.race_net.send_grid(order)


## The grid order of the setup as an Array[int] (entrant indices of Qualifying = setup indices).
static func _grid_entrants(order: Array) -> Array[int]:
	var result: Array[int] = []
	for entry: int in order:
		result.append(entry)
	return result


## A car driven by the network: shown where its owner says, judged like any other.
func tick_remote(racer: Racer, delta: float) -> void:
	var net := remote_state(race.racers.find(racer))
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
	race.after_move(racer, delta)


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
	var net := Session.race_net
	if not is_host:
		# The counters live in RaceNet: they keep growing from qualifying into the race, so
		# late packets of the old scene never look newer than the new ones.
		net.client_seq += 1
		net.send_state(net.client_seq, CarCodec.NetCar.from_car(me.car, _flags(me)))
		return
	net.host_tick += 1
	var cars := {}
	for i in race.racers.size():
		cars[i] = CarCodec.NetCar.from_car(race.racers[i].car, _flags(race.racers[i]))
	net.send_snapshot(CarCodec.encode_snapshot(net.host_tick, cars))
	_info_left -= delta
	if _info_left <= 0.0:
		_info_left = INFO_INTERVAL
		Session.race_net.send_info(RaceInfo.rows(race))


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


func _on_state(peer_id: int, seq: int, car: CarCodec.NetCar) -> void:
	var index: int = index_of_peer.get(peer_id, -1)
	var timeline: SnapshotTimeline = _timelines.get(peer_id)
	if index < 0 or timeline == null or race.racers[index].retired:
		return
	var buffer := _buffers[index]
	var newest := buffer.newest()
	var time := timeline.seq_ms(seq)
	if newest and _accepted_ms.has(peer_id):
		var seconds := maxf(time - _accepted_ms[peer_id], 0.0) / 1000.0
		if newest.position.distance_to(car.position) > MAX_SPEED * seconds + JUMP_MARGIN \
				and _rejects.get(peer_id, 0) < MAX_REJECTS:
			_rejects[peer_id] = _rejects.get(peer_id, 0) + 1
			return
	_rejects[peer_id] = 0
	_accepted_ms[peer_id] = time
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
	if not is_host:
		RaceInfo.apply(race, rows)


func _on_client_event(peer_id: int, kind: int, value: float) -> void:
	var index: int = index_of_peer.get(peer_id, -1)
	if index < 0:
		return
	var racer := race.racers[index]
	match kind:
		RaceNet.ClientEvent.LOADED:
			_loaded[peer_id] = true
			var quali_over := race.qualifying != null and race.qualifying.finished
			if lights_started and peer_id != Session.my_id() and not quali_over:
				# Loaded late: tell it how far the start already is.
				Session.race_net.send_host_event(RaceNet.HostEvent.LIGHTS, 0, race.race_time)
		RaceNet.ClientEvent.START_RESULT:
			if racer.remote:
				racer.start_entry.reaction = clampf(value, -1.0, 10.0)
		RaceNet.ClientEvent.JUMP_START:
			if racer.remote:
				racer.start_entry.jump_start = true


func _on_host_event(kind: int, index: int, value: float) -> void:
	match kind:
		RaceNet.HostEvent.LIGHTS:
			if lights_started:
				return
			lights_started = true
			if value > 0.0 and race.start:  # joined the start late: catch up
				race.race_time = value
				race.start.update(value)
		RaceNet.HostEvent.PENALTY, RaceNet.HostEvent.PENALTY_GHOST:
			if index < race.racers.size():
				race.show_penalty_message(race.racers[index], kind == RaceNet.HostEvent.PENALTY_GHOST)


func _on_player_left(peer_id: int) -> void:
	var index: int = index_of_peer.get(peer_id, -1)
	if index >= 0 and not race.racers[index].finished:
		race.racers[index].retired = true  # a finished player keeps the result
