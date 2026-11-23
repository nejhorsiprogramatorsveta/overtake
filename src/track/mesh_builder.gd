class_name MeshBuilder
extends RefCounted
## Collects coloured triangles (vertex colours, alpha allowed) into meshes, so a whole layer of
## the scenery is drawn with a few draw_mesh calls. Units are metres. add_tiles_to() splits a
## layer into square tiles, each drawn by its own node: Godot skips the tiles outside the screen
## (one big mesh would always be drawn whole - FPS, user 2026-11-23).
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


## Side of a tile (m): the camera shows up to ~150 x 95 m, so 2-6 tiles per layer are drawn.
const TILE := 160.0


## Adds one MeshTile child per non-empty tile to `parent`; returns the number of triangles.
func add_tiles_to(parent: Node, tile: float = TILE) -> int:
	var triangles: Dictionary = {}  # tile -> Array of first-vertex indices (Arrays are not copied)
	for i in range(0, _vertices.size(), 3):
		var centre := (_vertices[i] + _vertices[i + 1] + _vertices[i + 2]) / 3.0
		var key := Vector2i(floori(centre.x / tile), floori(centre.y / tile))
		if not triangles.has(key):
			triangles[key] = []
		triangles[key].append(i)
	for key: Vector2i in triangles:
		var indices: Array = triangles[key]
		var vertices := PackedVector2Array()
		var colors := PackedColorArray()
		vertices.resize(indices.size() * 3)
		colors.resize(indices.size() * 3)
		var k := 0
		for i: int in indices:
			for j in 3:
				vertices[k] = _vertices[i + j]
				colors[k] = _colors[i + j]
				k += 1
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_COLOR] = colors
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var node := MeshTile.new()
		node.mesh = mesh
		parent.add_child(node)
	return triangle_count()


## One tile of a layer.
class MeshTile:
	extends Node2D

	var mesh: ArrayMesh

	func _draw() -> void:
		draw_mesh(mesh, null)
