class_name TrackView
extends Node2D
## Vector drawing of a track (PLAN.md B): grass, tyre barrier, gravel at the corners, asphalt,
## red-white kerbs, white edge lines and the chequered start/finish line. Built once into
## triangle meshes, so drawing costs almost nothing. Units are metres.

const GRASS := Color(0.2, 0.42, 0.2)
const GRASS_STRIPE := Color(0.22, 0.45, 0.22)
const GRAVEL := Color(0.78, 0.7, 0.52)
const BARRIER := Color(0.12, 0.12, 0.14)
const ASPHALT := Color(0.25, 0.26, 0.29)
const LINE := Color(0.95, 0.95, 0.95)
const KERB_RED := Color(0.86, 0.13, 0.15)
const KERB_WHITE := Color(0.95, 0.95, 0.95)
## Corners sharper than this radius (m) get kerbs and gravel (with some margin around them).
const CORNER_RADIUS := 160.0
const CORNER_MARGIN_POINTS := 10

var track: TrackData
var _meshes: Array[ArrayMesh] = []
var _bounds := Rect2()


func setup(track_data: TrackData) -> void:
	track = track_data
	_build()
	queue_redraw()


func _draw() -> void:
	if track == null:
		return
	draw_rect(_bounds, GRASS)
	var stripe := 40.0
	var y := _bounds.position.y
	while y < _bounds.end.y:
		draw_rect(Rect2(_bounds.position.x, y, _bounds.size.x, stripe * 0.5), GRASS_STRIPE)
		y += stripe
	for mesh in _meshes:
		draw_mesh(mesh, null)


func _build() -> void:
	var n := track.point_count()
	var min_p := track.points[0]
	var max_p := track.points[0]
	for p in track.points:
		min_p = min_p.min(p)
		max_p = max_p.max(p)
	var margin := track.half_width() + TrackData.RUNOFF_WIDTH + 400.0
	_bounds = Rect2(min_p - Vector2(margin, margin), max_p - min_p + Vector2(margin, margin) * 2.0)
	var corner := _corner_mask()
	var hw := track.half_width()
	var wall := hw + TrackData.RUNOFF_WIDTH
	var gravel := Ribbons.new(track)
	var barrier := Ribbons.new(track)
	var asphalt := Ribbons.new(track)
	var kerbs := Ribbons.new(track)
	var lines := Ribbons.new(track)
	for i in n:
		# No tyre wall on the inside of bends where it would converge into a spike.
		for side: float in [1.0, -1.0]:
			if not _wall_folds(i, side * (wall + 1.2)):
				barrier.quad(i, minf(side * wall, side * (wall + 1.2)), maxf(side * wall, side * (wall + 1.2)), BARRIER)
		if corner[i]:
			gravel.quad(i, -wall, wall, GRAVEL)
		asphalt.quad(i, -hw - 0.2, hw + 0.2, ASPHALT)
		if corner[i]:
			var kerb_color := KERB_RED if i % 2 == 0 else KERB_WHITE
			kerbs.quad(i, hw, hw + TrackData.KERB_WIDTH, kerb_color)
			kerbs.quad(i, -hw - TrackData.KERB_WIDTH, -hw, kerb_color)
		lines.quad(i, hw - 0.45, hw - 0.1, LINE)
		lines.quad(i, -hw + 0.1, -hw + 0.45, LINE)
	_add_start_line(lines)
	for ribbon in [barrier, gravel, asphalt, kerbs, lines]:
		var mesh: ArrayMesh = ribbon.mesh()
		if mesh:
			_meshes.append(mesh)


## Chequered start/finish line across the track at point 0.
func _add_start_line(target: Ribbons) -> void:
	var origin := track.points[0]
	var forward := track.tangents[0]
	var right := track.normal(0)
	var square := 1.0
	var columns := int(track.width / square)
	for row in 2:
		for column in columns:
			var color := LINE if (row + column) % 2 == 0 else BARRIER
			var base := origin + right * (-track.half_width() + column * square) + forward * ((row - 1) * square)
			target.rect(base, forward * square, right * square, color)


## True if `lateral` lies beyond the centre of the bend at this segment or the next one.
func _wall_folds(index: int, lateral: float) -> bool:
	for i in [index, track.next_index(index)]:
		var k := track.curvatures[i]
		if lateral * k > 0.0 and absf(lateral) * absf(k) > 0.9:
			return true
	return false


func _corner_mask() -> Array[bool]:
	var n := track.point_count()
	var sharp: Array[bool] = []
	for i in n:
		sharp.append(absf(track.curvatures[i]) > 1.0 / CORNER_RADIUS)
	var mask: Array[bool] = []
	for i in n:
		var near := false
		for k in range(-CORNER_MARGIN_POINTS, CORNER_MARGIN_POINTS + 1):
			if sharp[posmod(i + k, n)]:
				near = true
				break
		mask.append(near)
	return mask


## Collects coloured quads between two lateral offsets of a segment into one mesh.
class Ribbons:
	var _track: TrackData
	var _vertices := PackedVector2Array()
	var _colors := PackedColorArray()

	func _init(track_data: TrackData) -> void:
		_track = track_data

	func quad(index: int, from_lateral: float, to_lateral: float, color: Color) -> void:
		var j := _track.next_index(index)
		var a := _track.points[index]
		var b := _track.points[j]
		var na := _track.normal(index)
		var nb := _track.normal(j)
		_triangle(a + na * _clamp(index, from_lateral), a + na * _clamp(index, to_lateral), b + nb * _clamp(j, to_lateral), color)
		_triangle(a + na * _clamp(index, from_lateral), b + nb * _clamp(j, to_lateral), b + nb * _clamp(j, from_lateral), color)

	## On the inside of a corner an offset larger than the radius would fold over itself:
	## stop just short of the corner's centre.
	func _clamp(index: int, lateral: float) -> float:
		var k := _track.curvatures[index]
		if lateral * k <= 0.0:
			return lateral
		var limit := 0.9 / absf(k)
		return clampf(lateral, -limit, limit)

	func rect(base: Vector2, along: Vector2, across: Vector2, color: Color) -> void:
		_triangle(base, base + along, base + along + across, color)
		_triangle(base, base + along + across, base + across, color)

	func _triangle(a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
		_vertices.append_array([a, b, c])
		_colors.append_array([color, color, color])

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
