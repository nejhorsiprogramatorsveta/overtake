class_name ConnectionLog
extends Node
## Diagnostics (taken over from Gun game): writes connection and session events to the game log
## (DiagLog), so a session where someone could not join, lagged or got disconnected can be
## analysed afterwards. Child of the Session autoload; only listens to signals, plus an ENet
## link line every LOBBY_STATS_MS in the lobby (RaceLog covers races). Logs peer ids, phases,
## durations, reasons and the race settings - never IP addresses or player names.

const PHASE_NAMES := ["offline", "connecting", "lobby", "in_race"]
const LOBBY_STATS_MS := 10000

var _phase_start_ms := 0
var _previous_phase := 0
var _last_stats_ms := 0
## peer_id -> connect time (msec)
var _peer_since: Dictionary[int, int] = {}


func _init() -> void:
	name = "ConnectionLog"


func _ready() -> void:
	DiagLog.install()
	DiagLog.event("sys", "game started build=%s" % BuildInfo.build_id())
	Session.phase_changed.connect(_on_phase_changed)
	Session.ended.connect(func(message: String) -> void:
		DiagLog.event("conn", "session ended: %s" % (message if not message.is_empty() else "left on purpose")))
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connection_failed.connect(func() -> void:
		DiagLog.event("conn", "connection failed after %dms (no answer from the host: wrong address, host's firewall, Tailscale off, different network?)" % (Time.get_ticks_msec() - _phase_start_ms)))
	multiplayer.server_disconnected.connect(func() -> void:
		DiagLog.event("conn", "host disconnected after %ds in %s" % [_seconds_in_phase(), PHASE_NAMES[Session.phase]]))
	var api := multiplayer as SceneMultiplayer
	api.peer_authenticating.connect(func(id: int) -> void: DiagLog.event("conn", "peer %d: handshake started" % id))
	api.peer_authentication_failed.connect(func(id: int) -> void: DiagLog.event("conn", "peer %d: handshake failed or timed out" % id))


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			if Session.phase != Session.Phase.OFFLINE:
				DiagLog.event("sys", "window lost focus (in %s)" % PHASE_NAMES[Session.phase])
		NOTIFICATION_WM_CLOSE_REQUEST:
			DiagLog.event("sys", "game window closed")
			DiagLog.flush()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_stats_ms < LOBBY_STATS_MS:
		return
	_last_stats_ms = now
	if Session.phase != Session.Phase.LOBBY:
		return
	var link := link_text(multiplayer)
	if not link.is_empty():
		DiagLog.event("conn", "lobby link: %s" % link)


## "peer 2 rtt=34ms var=5ms loss=0.0% | ..." for every peer this computer talks to.
static func link_text(api: MultiplayerAPI) -> String:
	var parts: PackedStringArray = []
	var peers: Array = api.get_peers() if api.is_server() else [1]
	for peer_id: int in peers:
		var stats := EnetDirectConnector.peer_stats(api.multiplayer_peer, peer_id)
		if not stats.is_empty():
			parts.append("peer %d rtt=%dms var=%dms loss=%.1f%%" % [peer_id, stats.rtt, stats.rtt_var, stats.loss])
	return " | ".join(parts)


func _on_phase_changed(phase: int) -> void:
	var text := "phase %s -> %s after %ds" % [PHASE_NAMES[_previous_phase], PHASE_NAMES[phase], _seconds_in_phase()]
	if _previous_phase == Session.Phase.CONNECTING and phase == Session.Phase.LOBBY:
		text += " (connected in %dms)" % (Time.get_ticks_msec() - _phase_start_ms)
	if phase == Session.Phase.LOBBY and _previous_phase == Session.Phase.OFFLINE and Session.is_host():
		var kinds: PackedStringArray = []
		for entry in Session.share_addresses():
			kinds.append(String(entry.kind))
		text += " hosting port=%d shareable=%s" % [Session.host_port, ",".join(kinds) if not kinds.is_empty() else "none"]
	if phase == Session.Phase.IN_RACE:
		text += " " + race_text(Session.race_setup)
	DiagLog.event("conn", text)
	_previous_phase = phase
	_phase_start_ms = Time.get_ticks_msec()


## The race settings and grid for the log: "track=austria laps=5 ... cars=6 people=2 me=slot3".
static func race_text(setup: Dictionary) -> String:
	if setup.is_empty():
		return "no setup"
	var settings: Dictionary = setup.settings
	var people := 0
	var mine := -1
	for car: Dictionary in setup.cars:
		if int(car.peer) != 0:
			people += 1
		if int(car.peer) == Session.my_id():
			mine = int(car.slot)
	return "track=%s laps=%d wear=%s bots=%d difficulty=%d qualifying=%s cars=%d people=%d me=slot%d" % [
		settings.track, settings.laps, settings.tyre_wear, settings.bots, settings.difficulty,
		settings.get("qualifying", false), setup.cars.size(), people, mine]


func _on_peer_connected(id: int) -> void:
	_peer_since[id] = Time.get_ticks_msec()
	DiagLog.event("conn", "peer %d connected (%d in lobby)" % [id, Session.players.size()])


func _on_peer_disconnected(id: int) -> void:
	var seconds: int = (Time.get_ticks_msec() - _peer_since.get(id, Time.get_ticks_msec())) / 1000
	_peer_since.erase(id)
	DiagLog.event("conn", "peer %d disconnected after %ds during %s" % [id, seconds, PHASE_NAMES[Session.phase]])


func _seconds_in_phase() -> int:
	return (Time.get_ticks_msec() - _phase_start_ms) / 1000
