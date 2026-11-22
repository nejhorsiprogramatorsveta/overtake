class_name RaceNet
extends Node
## The only place for race RPCs (child "RaceNet" of the Session autoload, so the node path is
## the same on every peer). Raw messages are checked here (sender, size, types, rate) and passed
## on as signals; OnlineRace turns them into the race. PLAN.md C (netcode) and S (security).
##   client -> host: own car state every tick (unreliable, ordered), start result, "loaded";
##   host -> clients: snapshot of all cars every tick, race info a few times per second,
##   events (lights start, penalty message).

signal state_received(peer_id: int, seq: int, car: CarCodec.NetCar)
signal snapshot_received(data: PackedByteArray)
signal info_received(rows: Array)
signal client_event_received(peer_id: int, kind: int, value: float)
signal host_event_received(kind: int, index: int, value: float)

enum ClientEvent { LOADED, START_RESULT, JUMP_START }
enum HostEvent { LIGHTS, PENALTY, PENALTY_GHOST }

## A client sends one state per physics tick (60/s); more than this per second is dropped.
const MAX_STATES_PER_SECOND := 90
const MAX_SNAPSHOT_BYTES := 5 + LobbyValidator.MAX_CARS * (1 + CarCodec.RECORD_BYTES)
## Race info: one row per car with INFO_FIELDS values.
const INFO_FIELDS := 10
const STATE_CHANNEL := 1

var _rate: Dictionary[int, int] = {}
var _rate_second := 0


func send_state(seq: int, car: CarCodec.NetCar) -> void:
	_client_state.rpc_id(1, CarCodec.encode_client(seq, car))


@rpc("any_peer", "call_remote", "unreliable_ordered", STATE_CHANNEL)
func _client_state(data: Variant) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not multiplayer.is_server() or not Session.players.has(sender) or typeof(data) != TYPE_PACKED_BYTE_ARRAY:
		return
	if not _within_rate(sender):
		return
	var decoded := CarCodec.decode_client(data)
	if not decoded.is_empty():
		state_received.emit(sender, decoded[0], decoded[1])


func send_snapshot(data: PackedByteArray) -> void:
	_snapshot.rpc(data)


@rpc("authority", "call_remote", "unreliable_ordered", STATE_CHANNEL)
func _snapshot(data: Variant) -> void:
	if typeof(data) == TYPE_PACKED_BYTE_ARRAY and data.size() <= MAX_SNAPSHOT_BYTES:
		snapshot_received.emit(data)


## rows: one Array of INFO_FIELDS numbers/bools per car (see OnlineRace).
func send_info(rows: Array) -> void:
	_info.rpc(rows)


@rpc("authority", "call_remote", "reliable")
func _info(rows: Variant) -> void:
	if typeof(rows) != TYPE_ARRAY or rows.size() > LobbyValidator.MAX_CARS:
		return
	for row: Variant in rows:
		if typeof(row) != TYPE_ARRAY or row.size() != INFO_FIELDS:
			return
		for value: Variant in row:
			if typeof(value) not in [TYPE_INT, TYPE_FLOAT, TYPE_BOOL]:
				return
	info_received.emit(rows)


func send_client_event(kind: ClientEvent, value: float = 0.0) -> void:
	if multiplayer.is_server():
		client_event_received.emit(1, kind, value)
	else:
		_client_event.rpc_id(1, kind, value)


@rpc("any_peer", "call_remote", "reliable")
func _client_event(kind: Variant, value: Variant) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not multiplayer.is_server() or not Session.players.has(sender) or typeof(kind) != TYPE_INT \
			or typeof(value) != TYPE_FLOAT or kind < 0 or kind >= ClientEvent.size() or not is_finite(value):
		return
	client_event_received.emit(sender, kind, value)


func send_host_event(kind: HostEvent, index: int = 0, value: float = 0.0) -> void:
	_host_event.rpc(kind, index, value)
	host_event_received.emit(kind, index, value)


@rpc("authority", "call_remote", "reliable")
func _host_event(kind: Variant, index: Variant, value: Variant) -> void:
	if typeof(kind) != TYPE_INT or typeof(index) != TYPE_INT or typeof(value) != TYPE_FLOAT \
			or kind < 0 or kind >= HostEvent.size() or index < 0 or index >= LobbyValidator.MAX_CARS or not is_finite(value):
		return
	host_event_received.emit(kind, index, value)


func _within_rate(peer_id: int) -> bool:
	var second := Time.get_ticks_msec() / 1000
	if second != _rate_second:
		_rate_second = second
		_rate.clear()
	_rate[peer_id] = _rate.get(peer_id, 0) + 1
	return _rate[peer_id] <= MAX_STATES_PER_SECOND
