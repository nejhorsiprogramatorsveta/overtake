class_name Minimap
extends Control
## Small north-up map of the whole track with a dot per car (HUD corner).

const TRACK_COLOR := Color(0.85, 0.86, 0.9, 0.9)
const START_COLOR := Color(1, 1, 1)
const PADDING := 10.0

var track: TrackData
## Positions (m) and colours of the cars to show; set by the race every frame.
var car_positions := PackedVector2Array()
var car_colors := PackedColorArray()
var _outline := PackedVector2Array()
var _min := Vector2.ZERO
var _scale := 1.0


func setup(track_data: TrackData) -> void:
	track = track_data
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_rebuild)
	_rebuild()


func show_cars(positions: PackedVector2Array, colors: PackedColorArray) -> void:
	car_positions = positions
	car_colors = colors
	queue_redraw()


func _rebuild() -> void:
	if track == null:
		return
	var min_p := track.points[0]
	var max_p := track.points[0]
	for p in track.points:
		min_p = min_p.min(p)
		max_p = max_p.max(p)
	var extent := max_p - min_p
	var area := size - Vector2(PADDING, PADDING) * 2.0
	_scale = minf(area.x / maxf(extent.x, 1.0), area.y / maxf(extent.y, 1.0))
	_min = min_p - (area / _scale - extent) * 0.5
	_outline = PackedVector2Array()
	for i in range(0, track.point_count(), 2):
		_outline.append(_to_map(track.points[i]))
	_outline.append(_outline[0])
	queue_redraw()


func _to_map(world: Vector2) -> Vector2:
	return (world - _min) * _scale + Vector2(PADDING, PADDING)


func _draw() -> void:
	if _outline.size() < 2:
		return
	draw_polyline(_outline, TRACK_COLOR, 3.0, true)
	var start := _to_map(track.points[0])
	var across := track.normal(0) * 7.0
	draw_line(start - across, start + across, START_COLOR, 2.0)
	for i in car_positions.size():
		var color := car_colors[i] if i < car_colors.size() else Color.WHITE
		draw_circle(_to_map(car_positions[i]), 5.0, Color.BLACK)
		draw_circle(_to_map(car_positions[i]), 3.8, color)
