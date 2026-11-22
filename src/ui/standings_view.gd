class_name StandingsView
extends PanelContainer
## Live race order on the left (user 2026-11-22): position, colour, driver and the gap to the
## leader (finished cars: their final gap; a lap or more behind: "+1 kolo").

const ROW_FONT := 16
const DIM := Color(0.75, 0.77, 0.83)
const HIGHLIGHT := Color(1.0, 0.85, 0.2)

var _grid := GridContainer.new()
var _refresh_left := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.09, 0.72)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	add_theme_stylebox_override("panel", style)
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 2)
	add_child(_grid)


## Called every frame; rebuilds the rows a few times per second.
func show_order(order: Array[Racer], start: RaceStart, time: float, lap_length: float, delta: float) -> void:
	_refresh_left -= delta
	if _refresh_left > 0.0:
		return
	_refresh_left = 0.25
	for child in _grid.get_children():
		child.free()
	var leader := order[0]
	for i in order.size():
		var racer := order[i]
		var color := HIGHLIGHT if racer.is_player else Color.WHITE
		_add_label(str(i + 1), color)
		var swatch := ColorRect.new()
		swatch.color = racer.color
		swatch.custom_minimum_size = Vector2(6, 16)
		_grid.add_child(swatch)
		_add_label(racer.name, color)
		_add_label(_gap_text(racer, leader, start, time, lap_length), DIM if not racer.is_player else color)


func _gap_text(racer: Racer, leader: Racer, start: RaceStart, time: float, lap_length: float) -> String:
	if racer == leader:
		return tr("STANDINGS_LEADER")
	if racer.finished and leader.finished:
		return "+%.1f" % (racer.total_time(start) - leader.total_time(start))
	var laps_behind := int((leader.progress() - racer.progress()) / lap_length)
	if laps_behind >= 1:
		return tr("STANDINGS_LAPS").format({"laps": laps_behind})
	var gap := racer.gap_to(leader, time)
	return "+%.1f" % gap if gap >= 0.0 else "–"


func _add_label(text: String, color: Color) -> void:
	var label := Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = text
	label.add_theme_font_size_override("font_size", ROW_FONT)
	label.add_theme_color_override("font_color", color)
	_grid.add_child(label)
