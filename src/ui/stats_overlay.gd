class_name StatsOverlay
extends Label
## F3 overlay (top centre, under the lights): FPS, frame and physics time, what the GPU draws and,
## online, the round trip to the host / each client. Updated twice a second.

const INTERVAL := 0.5

var _left := 0.0


func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_font_override("font", HudStyle.bold())
	add_theme_font_size_override("font_size", 16)
	add_theme_color_override("font_color", Color(0.85, 1.0, 0.85))
	add_theme_constant_override("outline_size", 6)
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	_left -= delta
	if _left > 0.0:
		return
	_left = INTERVAL
	var lines := [
		"FPS %d · %.1f ms" % [Engine.get_frames_per_second(), 1000.0 / maxf(Engine.get_frames_per_second(), 1.0)],
		"process %.1f ms · physics %.1f ms" % [Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
				Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0],
		"draw calls %d · triangles %d k" % [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0)],
	]
	if Session.is_online():
		lines.append(_network_line())
	text = "\n".join(lines)


func _network_line() -> String:
	var parts: PackedStringArray = []
	for peer_id: int in Session.players:
		if peer_id == Session.my_id():
			continue
		if not Session.is_host() and peer_id != 1:
			continue
		var stats := EnetDirectConnector.peer_stats(multiplayer.multiplayer_peer, peer_id)
		if not stats.is_empty():
			parts.append("%s %d ms" % [str(Session.players[peer_id].name).left(10), stats.rtt])
	return "ping: " + (", ".join(parts) if not parts.is_empty() else "-")
