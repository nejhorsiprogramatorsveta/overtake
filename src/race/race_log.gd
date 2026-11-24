class_name RaceLog
extends RefCounted
## Measurements of a race in the game log (DiagLog, user 2026-11-24: the game stuttered on
## eduroam + Tailscale - the log shows whether it was the network or the computer). One line
## every INTERVAL_MS, plus an immediate line for each long network gap:
##   all:    FPS (now / lowest), longest pause between physics ticks and hitches (> HITCH_MS),
##           draw calls
##   client: ENet link to the host (RTT, variance, loss), snapshots received, largest gap and
##           gaps > GAP_MS, interpolation delay and jitter, traffic
##   host:   per client: ENet link, car states received, largest gap, rejected jumps
## Plus race events (start, laps, pit stops, finish). Never addresses or names. Not translated.

const INTERVAL_MS := 5000
const GAP_MS := 100
## A gap longer than this is logged at once (at most MAX_SPIKE_LINES per interval).
const SPIKE_MS := 250
const MAX_SPIKE_LINES := 5
const HITCH_MS := 50

var _window_start_ms := -1
var _fps_min := -1.0
var _last_tick_ms := -1
var _tick_gap_max := 0
var _hitches := 0
var _spike_lines := 0
## peer (0 = the host's snapshots on a client) -> received, gap max, gaps, last arrival, rejects
var _received: Dictionary[int, int] = {}
var _gap_max: Dictionary[int, int] = {}
var _gaps: Dictionary[int, int] = {}
var _last_ms: Dictionary[int, int] = {}
var _rejects: Dictionary[int, int] = {}


## A network message with a car state arrived (client: a snapshot from the host = peer 0).
func record_arrival(peer: int, now_ms: int) -> void:
	_received[peer] = _received.get(peer, 0) + 1
	if _last_ms.has(peer):
		var gap := now_ms - _last_ms[peer]
		_gap_max[peer] = maxi(_gap_max.get(peer, 0), gap)
		if gap > GAP_MS:
			_gaps[peer] = _gaps.get(peer, 0) + 1
		if gap > SPIKE_MS and _spike_lines < MAX_SPIKE_LINES:
			_spike_lines += 1
			DiagLog.event("net", "spike: nothing from %s for %dms" % [_who(peer), gap])
	_last_ms[peer] = now_ms


## Host: a client's state was dropped as an impossible jump.
func record_reject(peer: int) -> void:
	_rejects[peer] = _rejects.get(peer, 0) + 1


## Every physics tick. `link` -> ENet link text (ConnectionLog.link_text), `extra` -> more info
## (timelines); only called when a line is written (online only). Returns the line once per
## interval (already written to the log), else "".
func tick(now_ms: int, fps: float, online: bool, link := Callable(), extra := Callable()) -> String:
	if _window_start_ms < 0:
		_window_start_ms = now_ms
	if _last_tick_ms >= 0:
		var pause := now_ms - _last_tick_ms
		_tick_gap_max = maxi(_tick_gap_max, pause)
		if pause > HITCH_MS:
			_hitches += 1
	_last_tick_ms = now_ms
	_fps_min = fps if _fps_min < 0.0 else minf(_fps_min, fps)
	if now_ms - _window_start_ms < INTERVAL_MS:
		return ""
	var text := "fps=%d min=%d tick_gap_max=%dms hitches>%dms=%d draws=%d" % [fps, _fps_min, _tick_gap_max, HITCH_MS,
			_hitches, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]
	if online:
		var link_text: String = link.call() if link.is_valid() else ""
		text += " | link %s" % (link_text if not link_text.is_empty() else "n/a")
		var peers: PackedStringArray = []
		for peer: int in _received:
			peers.append("%s received=%d gap_max=%dms gaps>%dms=%d rejected=%d" % [_who(peer), _received[peer],
					_gap_max.get(peer, 0), GAP_MS, _gaps.get(peer, 0), _rejects.get(peer, 0)])
		text += " | " + (" | ".join(peers) if not peers.is_empty() else "nothing received")
		var extra_text: String = extra.call() if extra.is_valid() else ""
		if not extra_text.is_empty():
			text += " | " + extra_text
	DiagLog.event("perf" if not online else "net", text)
	_reset(now_ms)
	return text


func _reset(now_ms: int) -> void:
	_window_start_ms = now_ms
	_fps_min = -1.0
	_tick_gap_max = 0
	_hitches = 0
	_spike_lines = 0
	_received.clear()
	_gap_max.clear()
	_gaps.clear()
	_rejects.clear()


static func _who(peer: int) -> String:
	return "host snapshots" if peer == 0 else "peer %d" % peer
