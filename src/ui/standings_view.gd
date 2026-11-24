class_name StandingsView
extends PanelContainer
## Live race order on the left (user 2026-11-22): position, colour, driver and the gap to the
## leader (finished cars: their final gap; a lap or more behind: "+1 kolo"). Qualifying shows
## the best laps through show_rows().

const ROW_FONT := 16
const DIM := HudStyle.DIM
const HIGHLIGHT := HudStyle.GOLD

var _grid := GridContainer.new()
var _refresh_left := 0.0
## Reused rows: [position Label, swatch ColorRect, name Label, gap Label].
var _rows: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", HudStyle.panel())
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 2)
	add_child(_grid)


## Called every frame; updates the rows a few times per second (the row nodes are reused).
func show_order(order: Array[Racer], start: RaceStart, time: float, lap_length: float, delta: float) -> void:
	if not _due(delta):
		return
	var rows := []
	for racer in order:
		rows.append([racer.name, racer.color, racer.is_player, _gap_text(racer, order[0], start, time, lap_length)])
	_fill(rows)


## Rows of [name, colour, is the player, right column] in order (qualifying: best laps).
func show_rows(rows: Array, delta: float) -> void:
	if _due(delta):
		_fill(rows)


## The rows are refreshed a few times per second.
func _due(delta: float) -> bool:
	_refresh_left -= delta
	if _refresh_left > 0.0:
		return false
	_refresh_left = 0.25
	return true


func _fill(rows: Array) -> void:
	while _rows.size() < rows.size():
		_add_row()
	for i in rows.size():
		var entry: Array = rows[i]
		var row: Array = _rows[i]
		var color := HIGHLIGHT if entry[2] else Color.WHITE
		_set_label(row[0], str(i + 1), color)
		(row[1] as ColorRect).color = entry[1]
		_set_label(row[2], entry[0], color)
		_set_label(row[3], entry[3], color if entry[2] else DIM)


func _gap_text(racer: Racer, leader: Racer, start: RaceStart, time: float, lap_length: float) -> String:
	if racer == leader:
		return tr("STANDINGS_LEADER")
	if racer.finished and leader.finished:
		if racer.laps.laps < leader.laps.laps:
			return RaceHud.laps_behind(leader.laps.laps - racer.laps.laps)
		return "+%.1f" % (racer.total_time(start) - leader.total_time(start))
	var laps_behind := int((leader.progress() - racer.progress()) / lap_length)
	if laps_behind >= 1:
		return RaceHud.laps_behind(laps_behind)
	var gap := racer.gap_to(leader, time)
	return "+%.1f" % gap if gap >= 0.0 else "–"


## One row: position, colour swatch, name, gap.
func _add_row() -> void:
	var row := []
	for column in 4:
		if column == 1:
			var swatch := ColorRect.new()
			swatch.custom_minimum_size = Vector2(6, 16)
			row.append(swatch)
			_grid.add_child(swatch)
		else:
			var label := HudStyle.label(ROW_FONT)
			row.append(label)
			_grid.add_child(label)
	_rows.append(row)


## Text and colour, touching the label only when something changed (no relayout every time).
static func _set_label(label: Label, text: String, color: Color) -> void:
	label.text = text
	HudStyle.set_color(label, color)
