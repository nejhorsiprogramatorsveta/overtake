class_name MeshBuilder
extends RefCounted
## Collects coloured triangles (vertex colours, alpha allowed) into one ArrayMesh, so a whole
## layer of the scenery is drawn with a single draw_mesh call. Units are metres.
## Track helpers place quads between two lateral offsets of a centre-line segment.

var _vertices := PackedVector2Array()
var _colors := PackedColorArray()


func is_empty() -> bool:
	return _vertices.is_empty()


func triangle_count() -> int:
	return _vertices.size() / 3


func triangle(a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	_vertices.append_array([a, b, c])
	_colors.append_array([color, color, color])


## Quad a-b-c-d (in order around the edge) with one colour per corner.
func quad_colors(a: Vector2, b: Vector2, c: Vector2, d: Vector2, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	_vertices.append_array([a, b, c, a, c, d])
	_colors.append_array([ca, cb, cc, ca, cc, cd])


func quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, color: Color) -> void:
	quad_colors(a, b, c, d, color, color, color, color)


## Rectangle from `base` spanned by the two edge vectors.
func rect(base: Vector2, along: Vector2, across: Vector2, color: Color) -> void:
	quad(base, base + along, base + along + across, base + across, color)


## Rectangle centred at `centre`, `size.x` along `direction`.
func box(centre: Vector2, direction: Vector2, size: Vector2, color: Color) -> void:
	var along := direction * size.x
	var across := Vector2(-direction.y, direction.x) * size.y
	rect(centre - along * 0.5 - across * 0.5, along, across, color)


func circle(centre: Vector2, radius: float, color: Color, segments: int = 10) -> void:
	var previous := centre + Vector2(radius, 0.0)
	for i in range(1, segments + 1):
		var next := centre + Vector2.from_angle(TAU * i / segments) * radius
		triangle(centre, previous, next, color)
		previous = next


## Quad of track segment index -> index + 1 between two lateral offsets (right = +).
func track_quad(track: TrackData, index: int, from_lateral: float, to_lateral: float, color: Color) -> void:
	track_quad_colors(track, index, from_lateral, to_lateral, color, color, color, color)


## As track_quad with a colour per corner: (start, from), (start, to), (end, to), (end, from).
func track_quad_colors(track: TrackData, index: int, from_lateral: float, to_lateral: float,
		c_from: Color, c_to: Color, c_next_to: Color, c_next_from: Color) -> void:
	var j := track.next_index(index)
	quad_colors(offset(track, index, from_lateral), offset(track, index, to_lateral),
			offset(track, j, to_lateral), offset(track, j, from_lateral), c_from, c_to, c_next_to, c_next_from)


## Point at a lateral offset of a centre-line point. On the inside of a corner an offset larger
## than the radius would fold over itself: it stops just short of the corner's centre.
static func offset(track: TrackData, index: int, lateral: float) -> Vector2:
	var k := track.curvatures[index]
	if lateral * k > 0.0:
		var limit := 0.9 / absf(k)
		lateral = clampf(lateral, -limit, limit)
	return track.points[index] + track.normal(index) * lateral


func mesh() -> ArrayMesh:
	if _vertices.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_COLOR] = _colors
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result
