class_name PitLaneView
extends Node2D
## Vector drawing of the pit lane: asphalt, white edges, the pit wall towards the track,
## yellow speed-limit lines, garages with the player's box in its colour and the stop marks,
## and a "PIT" board at the entry. Built once into a mesh (metres).

const ASPHALT := Color(0.27, 0.28, 0.31)
const LINE := Color(0.95, 0.95, 0.95)
const WALL := Color(0.62, 0.63, 0.66)
const LIMIT := Color(1.0, 0.85, 0.2)
const GARAGE := Color(0.16, 0.17, 0.2)
const GARAGE_ROOF := Color(0.3, 0.31, 0.35)
const HALF_WIDTH := 5.0

var lane: PitLane
var player_box := 0
var player_color := Color.RED
var _mesh: ArrayMesh
var _vertices := PackedVector2Array()
var _colors := PackedColorArray()


func setup(pit_lane: PitLane, box: int, color: Color) -> void:
	lane = pit_lane
	player_box = box
	player_color = color
	_build()
	queue_redraw()


func _draw() -> void:
	if _mesh:
		draw_mesh(_mesh, null)
	if lane == null:
		return
	var font := ThemeDB.fallback_font
	var board := lane.track.position_at(lane.entry_distance + 15.0, lane.side * (lane.track.half_width() + 9.0))
	draw_rect(Rect2(board - Vector2(5.5, 3.0), Vector2(11.0, 6.0)).grow(0.35), Color(0.08, 0.08, 0.1))
	draw_rect(Rect2(board - Vector2(5.5, 3.0), Vector2(11.0, 6.0)), LIMIT)
	draw_set_transform(board, 0.0, Vector2.ONE * 0.05)
	var text := tr("PIT_BOARD")
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 64)
	draw_string(font, Vector2(-size.x * 0.5, font.get_ascent(64) * 0.5 - font.get_descent(64) * 0.25), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 64, Color(0.08, 0.08, 0.1))
	draw_set_transform(Vector2.ZERO)


func _build() -> void:
	for i in lane.points.size() - 1:
		_quad_along(i, -HALF_WIDTH - 0.3, HALF_WIDTH + 0.3, ASPHALT)
		_quad_along(i, HALF_WIDTH - 0.4, HALF_WIDTH, LINE)
		_quad_along(i, -HALF_WIDTH, -HALF_WIDTH + 0.4, LINE)
		if lane.is_full_offset(lane.distances[i]) and lane.is_full_offset(lane.distances[i + 1]):
			_quad_along(i, -HALF_WIDTH - 2.2, -HALF_WIDTH - 1.2, WALL)
	# Speed limit lines where the lane reaches / leaves its full offset.
	var first := -1.0
	var last := -1.0
	for i in lane.points.size():
		if lane.is_full_offset(lane.distances[i]):
			if first < 0.0:
				first = lane.distances[i]
			last = lane.distances[i]
	for s: float in [first, last]:
		if s >= 0.0:
			_rect_at(s, -HALF_WIDTH, HALF_WIDTH, 0.6, LIMIT)
	for box in lane.box_count():
		var s := lane.box_distance(box)
		var colour := player_color if box == player_box else GARAGE
		_rect_at(s, HALF_WIDTH + 1.0, HALF_WIDTH + 9.0, 12.0, GARAGE_ROOF)
		_rect_at(s, HALF_WIDTH + 1.0, HALF_WIDTH + 2.0, 12.0, colour)
		_rect_at(s, -1.0, 1.0, 0.4, LIMIT)  # stop mark
		_rect_at(s - 2.5, -0.2, 0.2, 5.0, LIMIT)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_COLOR] = _colors
	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


## Offsets are measured outwards from the track (positive = away from the track).
func _outward(i: int) -> Vector2:
	var direction := (lane.points[mini(i + 1, lane.points.size() - 1)] - lane.points[maxi(i - 1, 0)]).normalized()
	return Vector2(-direction.y, direction.x) * lane.side


func _quad_along(i: int, from: float, to: float, color: Color) -> void:
	var a := lane.points[i]
	var b := lane.points[i + 1]
	var na := _outward(i)
	var nb := _outward(i + 1)
	_triangle(a + na * from, a + na * to, b + nb * to, color)
	_triangle(a + na * from, b + nb * to, b + nb * from, color)


func _rect_at(s: float, from: float, to: float, along: float, color: Color) -> void:
	var centre := lane.position_at(s)
	var direction := lane.direction_at(s)
	var out := Vector2(-direction.y, direction.x) * lane.side
	var a := centre - direction * along * 0.5
	var b := centre + direction * along * 0.5
	_triangle(a + out * from, a + out * to, b + out * to, color)
	_triangle(a + out * from, b + out * to, b + out * from, color)


func _triangle(a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	_vertices.append_array([a, b, c])
	_colors.append_array([color, color, color])
