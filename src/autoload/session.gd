extends Node
## AUTOLOAD "Session": the online session (PLAN.md C and S), alive across scene changes:
## hosting and joining (SessionAuth: version + room code), the lobby (players with their car
## colour, the race settings) and the race flow (start, back to the lobby). Host-authoritative:
## only the host (peer 1) changes players/settings and broadcasts them; everything received is
## checked by LobbyValidator. Race traffic goes through the child RaceNet.

signal phase_changed(phase: Phase)
signal players_changed
signal settings_changed
## The session is over (failed, rejected, connection lost or left; message translated, may be empty).
signal ended(message: String)
## Host: a player left during the race.
signal player_left(peer_id: int)

enum Phase { OFFLINE, CONNECTING, LOBBY, IN_RACE }

const MAX_PLAYERS := LobbyValidator.MAX_PLAYERS
const MIN_PLAYERS_TO_START := 2
const CONNECT_TIMEOUT := 10.0
const LOBBY_SCENE := "res://src/ui/lobby.tscn"
const RACE_SCENE := "res://src/race/race.tscn"
const MENU_SCENE := "res://src/ui/main_menu.tscn"

var phase := Phase.OFFLINE
## peer_id -> {"name": String, "color": int}; identical on all peers (host broadcasts it).
var players: Dictionary[int, Dictionary] = {}
## Race settings of the lobby (LobbyValidator.settings).
var settings: Dictionary = {}
## The running race (LobbyValidator.race_setup), read by RaceController.
var race_setup: Dictionary = {}
var room_code := ""
var host_port := EnetDirectConnector.DEFAULT_PORT
## Why the last session ended (translated), shown by the main menu.
var last_end_message := ""
var race_net := RaceNet.new()

var _connector: Connector = EnetDirectConnector.new()
var _join_address := ""
var _auth := SessionAuth.new()


func _ready() -> void:
	var api := multiplayer as SceneMultiplayer
	api.server_relay = false  # clients only talk to the host (PLAN.md S)
	api.allow_object_decoding = false
	add_child(_auth)
	race_net.name = "RaceNet"
	add_child(race_net)
	add_child(ConnectionLog.new())  # diagnostics in the game log (user://logs/last_game.log)
	api.peer_authentication_failed.connect(_on_peer_authentication_failed)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connection_failed.connect(_on_connection_lost)
	multiplayer.server_disconnected.connect(_on_connection_lost)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		leave()


func is_online() -> bool:
	return phase == Phase.LOBBY or phase == Phase.IN_RACE


func is_host() -> bool:
	return phase != Phase.OFFLINE and multiplayer.is_server()


func my_id() -> int:
	return multiplayer.get_unique_id()


func can_start_race() -> bool:
	return is_host() and phase == Phase.LOBBY and players.size() >= MIN_PLAYERS_TO_START


func host_game(player_name: String, color: int, port: int = EnetDirectConnector.DEFAULT_PORT) -> void:
	leave()
	DiagLog.begin_game()
	var peer := _connector.host(port)
	if peer == null:
		_emit_ended(tr("ERROR_HOST_FAILED").format({"port": port}))
		return
	multiplayer.multiplayer_peer = peer
	host_port = port
	room_code = Handshake.generate_room_code()
	players = {1: {"name": LobbyValidator.clean_name(player_name, 1), "color": clampi(color, 0, CarColors.COLORS.size() - 1)}}
	settings = LobbyValidator.settings({"track": TrackCatalog.id_or_default(Settings.practice_track), "laps": Settings.race_laps,
			"tyre_wear": Settings.tyre_wear, "bots": Settings.bot_count, "difficulty": Settings.bot_difficulty,
			"grid": Settings.grid_start, "qualifying": Settings.qualifying}, 1)
	_set_phase(Phase.LOBBY)
	players_changed.emit()
	get_tree().change_scene_to_file(LOBBY_SCENE)


## join_text is what the host shared: "address#CODE".
func join_game(join_text: String, player_name: String) -> void:
	leave()
	var parts := Handshake.split_join_text(join_text)
	if parts[1].is_empty():
		_emit_ended(tr("ERROR_MISSING_CODE"))
		return
	DiagLog.begin_game()
	DiagLog.event("conn", "joining %s" % DiagLog.describe_join(parts[0]))
	var peer := _connector.join(parts[0])
	if peer == null:
		_emit_ended(tr("ERROR_INVALID_ADDRESS"))
		return
	_auth.prepare_join(parts[1], player_name)
	_join_address = parts[0]
	multiplayer.multiplayer_peer = peer
	_set_phase(Phase.CONNECTING)
	get_tree().create_timer(CONNECT_TIMEOUT).timeout.connect(_on_connect_timeout.bind(peer))


func leave() -> void:
	_close("")


## Addresses the host can share ("ip:port#CODE"), Tailscale first; never the public IP.
func share_addresses() -> Array[Dictionary]:
	if not is_host():
		return []
	var entries := _connector.share_addresses(host_port)
	for entry in entries:
		entry.address += "#" + room_code
	return entries


# --- Lobby -----------------------------------------------------------------

## Any player: asks for a car colour (the host gives it if it is free).
func request_color(color: int) -> void:
	if is_host():
		_set_color(1, color)
	elif phase == Phase.LOBBY:
		_request_color.rpc_id(1, color)


@rpc("any_peer", "call_remote", "reliable")
func _request_color(color: Variant) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if is_host() and phase == Phase.LOBBY and players.has(sender) and typeof(color) == TYPE_INT:
		_set_color(sender, color)


func _set_color(peer_id: int, color: int) -> void:
	players[peer_id].color = LobbyValidator.free_color(players, color, peer_id)
	broadcast_players()


## Host: new race settings (checked, then sent to everyone).
func set_settings(new_settings: Dictionary) -> void:
	if not is_host() or phase != Phase.LOBBY:
		return
	var checked := LobbyValidator.settings(new_settings, players.size())
	if checked.is_empty():
		return
	settings = checked
	_receive_settings.rpc(settings)
	settings_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _receive_settings(new_settings: Dictionary) -> void:
	var checked := LobbyValidator.settings(new_settings, players.size())
	if not checked.is_empty():
		settings = checked
		settings_changed.emit()


func broadcast_players() -> void:
	_receive_players.rpc(players)
	players_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _receive_players(new_players: Dictionary) -> void:
	var checked := LobbyValidator.players(new_players)
	if not checked.is_empty():
		players = checked
		players_changed.emit()


# --- Race flow -------------------------------------------------------------

## Host: everybody in the lobby races now.
func start_race() -> void:
	if not can_start_race():
		return
	settings = LobbyValidator.settings(settings, players.size())
	_begin_race.rpc(RaceSetup.build(players, settings, randi()))


@rpc("authority", "call_local", "reliable")
func _begin_race(setup: Dictionary) -> void:
	var checked := LobbyValidator.race_setup(setup, players)
	if phase != Phase.LOBBY or checked.is_empty():
		return
	race_setup = checked
	_set_phase(Phase.IN_RACE)
	get_tree().change_scene_to_file(RACE_SCENE)


## Host: everyone back to the same lobby (the session and room code stay).
func return_to_lobby() -> void:
	if is_host() and phase == Phase.IN_RACE:
		_return_to_lobby.rpc()


@rpc("authority", "call_local", "reliable")
func _return_to_lobby() -> void:
	if phase != Phase.IN_RACE:
		return
	race_setup = {}
	_set_phase(Phase.LOBBY)
	get_tree().change_scene_to_file(LOBBY_SCENE)


# --- Connection events -----------------------------------------------------

func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		players[id] = {"name": LobbyValidator.clean_name(_auth.take_requested_name(id), players.size() + 1),
				"color": LobbyValidator.free_color(players, -1)}
		broadcast_players()
		_receive_settings.rpc_id(id, settings)
	elif id == 1:
		_set_phase(Phase.LOBBY)
		request_color(Settings.car_color)
		get_tree().change_scene_to_file(LOBBY_SCENE)


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	if players.erase(id):
		broadcast_players()
		player_left.emit(id)


func _on_peer_authentication_failed(id: int) -> void:
	if not multiplayer.is_server() and id == 1:
		_on_connection_lost()


func _on_connection_lost() -> void:
	if not _auth.rejection_message.is_empty():
		_close(_auth.rejection_message)
	elif phase == Phase.CONNECTING:
		_close(tr("ERROR_CONNECTION_FAILED").format({"address": _join_address}))
	else:
		_close(tr("ERROR_HOST_LEFT"))


func _on_connect_timeout(peer: MultiplayerPeer) -> void:
	if phase == Phase.CONNECTING and multiplayer.multiplayer_peer == peer:
		_on_connection_lost()


func _close(message: String) -> void:
	if phase == Phase.OFFLINE:
		return
	var was_online := phase != Phase.CONNECTING
	_set_phase(Phase.OFFLINE)
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_connector.close()
	room_code = ""
	players.clear()
	race_setup = {}
	_auth.reset()
	players_changed.emit()
	_emit_ended(message)
	if was_online or not message.is_empty():
		get_tree().change_scene_to_file(MENU_SCENE)


func _emit_ended(message: String) -> void:
	last_end_message = message
	ended.emit(message)


func _set_phase(new_phase: Phase) -> void:
	phase = new_phase
	phase_changed.emit(phase)
