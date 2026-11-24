class_name TrackView
extends Node2D
## Vector drawing of the ground of a track (PLAN.md B, M3G arcade look): mown grass with soft
## patches, gravel traps with grain at the corners, the asphalt with its rubbered-in racing line
## and skid marks (TrackSurface), shaded red-white kerbs, white edge lines, the chequered line and
## the painted grid boxes. Built once into a few triangle meshes, so drawing costs almost nothing.
## Barriers, trees and stands are TrackScenery. A city track (TrackData.STYLE_CITY_NIGHT) has dark
## pavement instead of grass and asphalt run-off instead of gravel (its scenery: CityScenery).
## Units are metres.

const GRASS := Color(0.27, 0.5, 0.23)
const GRASS_STRIPE := Color(0.3, 0.55, 0.25)
const GRAVEL := Color(0.84, 0.75, 0.56)
const GRAVEL_DARK := Color(0.66, 0.58, 0.42)
const GRAVEL_LIGHT := Color(0.93, 0.87, 0.71)
const LINE := Color(0.96, 0.96, 0.96)
const DARK := Color(0.1, 0.1, 0.12)
const KERB_RED := Color(0.88, 0.14, 0.15)
const KERB_WHITE := Color(0.95, 0.95, 0.95)
## Corners sharper than this radius (m) get kerbs and gravel (with some margin around them).
const CORNER_RADIUS := 160.0
const CORNER_MARGIN_POINTS := 10
## Gaps shorter than this (points) between two gravel traps are filled (no thin grass strips).
const GRAVEL_GAP_POINTS := 24
## Gravel traps grow to full depth over this many points at their ends.
const GRAVEL_TAPER_POINTS := 10
const GRASS_CELL := 8.0
## Mown stripes are this many grass cells wide.
const STRIPE_CELLS := 2
const GROUND_MARGIN := 300.0
## City at night: pavement and asphalt run-off.
const PAVEMENT := Color(0.2, 0.2, 0.23)
const RUNOFF := Color(0.25, 0.25, 0.28)

var track: TrackData
var _triangles := 0
var _bounds := Rect2()
var _noise := FastNoiseLite.new()
var _city := false


## grid = painted grid boxes as Vector2(distance along the lap, lateral) of each slot.
func setup(track_data: TrackData, grid: Array[Vector2] = []) -> void:
	track = track_data
	_city = track.style == TrackData.STYLE_CITY_NIGHT
	_noise.seed = hash(track.id)
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_build(grid)
	queue_redraw()


func _draw() -> void:
	if track == null:
		return
	draw_rect(_bounds.grow(2000.0), PAVEMENT if _city else GRASS)  # the layers are tiled child nodes (drawn on top)


func triangle_count() -> int:
	return _triangles


## Corner zones (kerbs and gravel) as a mask over the centre-line points.
static func corner_mask(track: TrackData) -> Array[bool]:
	var n := track.point_count()
	var mask: Array[bool] = []
	mask.resize(n)
	mask.fill(false)
	for i in n:
		if absf(track.curvatures[i]) > 1.0 / CORNER_RADIUS:
			for k in range(-CORNER_MARGIN_POINTS, CORNER_MARGIN_POINTS + 1):
				mask[posmod(i + k, n)] = true
	# Close short gaps between two zones.
	for i in n:
		if mask[i] and not mask[(i + 1) % n]:
			var gap := 1
			while gap <= GRAVEL_GAP_POINTS and not mask[(i + 1 + gap) % n]:
				gap += 1
			if gap <= GRAVEL_GAP_POINTS:
				for k in range(1, gap + 1):
					mask[(i + k) % n] = true
	return mask


func _build(grid: Array[Vector2]) -> void:
	var min_p := track.points[0]
	var max_p := track.points[0]
	for p in track.points:
		min_p = min_p.min(p)
		max_p = max_p.max(p)
	_bounds = Rect2(min_p, max_p - min_p).grow(track.half_width() + TrackData.RUNOFF_WIDTH + GROUND_MARGIN)
	var corner := corner_mask(track)
	var layers: Array[MeshBuilder] = [_grass(), _gravel(corner), TrackSurface.build(track, _noise), _kerbs(corner), _lines(grid)]
	for layer in layers:
		var node := Node2D.new()
		add_child(node)
		_triangles += layer.add_tiles_to(node)


## Grass: a grid with soft light/dark patches and mown stripes.
func _grass() -> MeshBuilder:
	var builder := MeshBuilder.new()
	var columns := ceili(_bounds.size.x / GRASS_CELL)
	var rows := ceili(_bounds.size.y / GRASS_CELL)
	var shade := PackedFloat32Array()
	shade.resize((columns + 1) * (rows + 1))
	for y in rows + 1:
		for x in columns + 1:
			var p := _bounds.position + Vector2(x, y) * GRASS_CELL
			shade[y * (columns + 1) + x] = _noise.get_noise_2d(p.x * 0.6, p.y * 0.6) * 0.06 \
					+ _noise.get_noise_2d(p.x * 4.0, p.y * 4.0) * 0.025
	for y in rows:
		var base := GRASS_STRIPE if (y / STRIPE_CELLS) % 2 == 0 else GRASS
		if _city:
			base = PAVEMENT
		for x in columns:
			var p := _bounds.position + Vector2(x, y) * GRASS_CELL
			var s := GRASS_CELL
			builder.quad_colors(p, p + Vector2(s, 0), p + Vector2(s, s), p + Vector2(0, s),
					_shaded(base, shade[y * (columns + 1) + x]), _shaded(base, shade[y * (columns + 1) + x + 1]),
					_shaded(base, shade[(y + 1) * (columns + 1) + x + 1]), _shaded(base, shade[(y + 1) * (columns + 1) + x]))
	return builder


## Gravel traps in the corner zones, tapered at their ends, with patches and loose stones.
func _gravel(corner: Array[bool]) -> MeshBuilder:
	var builder := MeshBuilder.new()
	var n := track.point_count()
	var wall := track.half_width() + TrackData.RUNOFF_WIDTH
	var depth := PackedFloat32Array()
	depth.resize(n)
	for i in n:
		if not corner[i]:
			continue
		var to_end := GRAVEL_TAPER_POINTS
		for k in range(1, GRAVEL_TAPER_POINTS):
			if not corner[posmod(i - k, n)] or not corner[(i + k) % n]:
				to_end = k
				break
		depth[i] = lerpf(0.06, 1.0, smoothstep(0.0, 1.0, float(to_end) / GRAVEL_TAPER_POINTS))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(track.id + "gravel")
	for i in n:
		var j := (i + 1) % n
		if not corner[i] or not corner[j]:
			continue
		for side: float in [1.0, -1.0]:
			var steps := 6
			for s in steps:
				var la := _gravel_lateral(side, float(s) / steps, depth[i], wall)
				var lb := _gravel_lateral(side, float(s + 1) / steps, depth[i], wall)
				var la2 := _gravel_lateral(side, float(s) / steps, depth[j], wall)
				var lb2 := _gravel_lateral(side, float(s + 1) / steps, depth[j], wall)
				var a := MeshBuilder.offset(track, i, la)
				var b := MeshBuilder.offset(track, i, lb)
				var c := MeshBuilder.offset(track, j, lb2)
				var d := MeshBuilder.offset(track, j, la2)
				builder.quad_colors(a, b, c, d, _gravel_color(a), _gravel_color(b), _gravel_color(c), _gravel_color(d))
			# Loose stones (gravel only).
			for stone in 0 if _city else 14:
				var p := MeshBuilder.offset(track, i, side * rng.randf_range(track.half_width() + 1.0, track.half_width() + depth[i] * TrackData.RUNOFF_WIDTH))
				p += track.tangents[i] * rng.randf_range(0.0, 4.0)
				var color := GRAVEL_DARK if rng.randf() < 0.6 else GRAVEL_LIGHT
				builder.box(p, Vector2.from_angle(rng.randf() * TAU), Vector2(0.35, 0.3), color)
	return builder


func _gravel_lateral(side: float, t: float, depth: float, wall: float) -> float:
	var inner := track.half_width()
	return side * lerpf(inner, inner + (wall - inner) * depth, t)


func _gravel_color(p: Vector2) -> Color:
	return _shaded(RUNOFF if _city else GRAVEL, _noise.get_noise_2d(p.x * 2.5, p.y * 2.5) * 0.06 + _noise.get_noise_2d(p.x * 12.0, p.y * 12.0) * 0.03)


## Red-white kerbs with a light top edge and a dark outer lip.
func _kerbs(corner: Array[bool]) -> MeshBuilder:
	var builder := MeshBuilder.new()
	var hw := track.half_width()
	var kerb := TrackData.KERB_WIDTH
	for i in track.point_count():
		if not corner[i]:
			continue
		var color := KERB_RED if i % 2 == 0 else KERB_WHITE
		for side: float in [1.0, -1.0]:
			builder.track_quad(track, i, side * hw, side * (hw + 0.25), color.lightened(0.18))
			builder.track_quad(track, i, side * (hw + 0.25), side * (hw + kerb - 0.3), color)
			builder.track_quad(track, i, side * (hw + kerb - 0.3), side * (hw + kerb), color.darkened(0.3))
	return builder


## White edge lines, the chequered start/finish line and the grid boxes.
func _lines(grid: Array[Vector2]) -> MeshBuilder:
	var builder := MeshBuilder.new()
	var hw := track.half_width()
	for i in track.point_count():
		builder.track_quad(track, i, hw - 0.5, hw - 0.12, LINE)
		builder.track_quad(track, i, -hw + 0.12, -hw + 0.5, LINE)
	var origin := track.points[0]
	var forward := track.tangents[0]
	var right := track.normal(0)
	var square := 1.0
	for row in 2:
		for column in int(track.width / square):
			var color := LINE if (row + column) % 2 == 0 else DARK
			builder.rect(origin + right * (-hw + column * square) + forward * ((row - 1) * square), forward * square, right * square, color)
	for slot in grid:
		var centre := track.position_at(slot.x, slot.y)
		var ahead := Vector2.from_angle(track.heading_at(slot.x))
		var side := Vector2(-ahead.y, ahead.x)
		var front := centre + ahead * 3.4
		builder.box(front, side, Vector2(3.2, 0.3), LINE)
		builder.box(front - ahead * 0.9 + side * 1.5, ahead, Vector2(1.8, 0.25), LINE)
		builder.box(front - ahead * 0.9 - side * 1.5, ahead, Vector2(1.8, 0.25), LINE)
	return builder


static func _shaded(color: Color, amount: float) -> Color:
	return color.lightened(amount) if amount > 0.0 else color.darkened(-amount)
