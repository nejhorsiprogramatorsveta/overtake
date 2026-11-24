class_name CityScenery
extends TrackScenery
## Surroundings of a street circuit at night (user 2026-11-24, Las Vegas): concrete walls with a
## catch fence and glowing light panels at the end of the run-off, a pavement strip behind them,
## city blocks with dark roofs, lit edges and neon outlines, street lights whose light falls on
## the track, grandstands and a giant glowing sphere where the real one stands
## (TrackData.landmarks "sphere"). Same placement rules as TrackScenery (KeepOutMap). The scene
## is darkened by NIGHT (RaceBuilder); the light layer is drawn additively on top of the ground.
## User 2026-11-24: brightly lit - dense street lights on both sides (also in the corners where
## there is no wall) and floodlights over every corner.

const NIGHT := Color(0.74, 0.74, 0.88)
const WALL := Color(0.6, 0.61, 0.64)
const WALL_TOP := Color(0.8, 0.81, 0.84)
const CITY_FENCE := Color(0.7, 0.72, 0.8, 0.7)
const NEON: Array[Color] = [Color(1.0, 0.25, 0.75), Color(0.2, 0.85, 1.0), Color(0.65, 0.35, 1.0), Color(1.0, 0.8, 0.25)]
const SIDEWALK := Color(0.33, 0.33, 0.36)
const ROOFS: Array[Color] = [Color(0.17, 0.17, 0.2), Color(0.22, 0.21, 0.25), Color(0.14, 0.15, 0.18), Color(0.25, 0.23, 0.22)]
const WINDOW := Color(1.0, 0.85, 0.5)
const LAMP := Color(1.0, 0.9, 0.7)
const LIGHT_POOL := Color(1.0, 0.84, 0.6, 0.3)
## Floodlight over the apex of every corner.
const FLOOD := Color(0.85, 0.9, 1.0, 0.24)
const FLOOD_RADIUS := 46.0
const CITY_SHADOW := Color(0.0, 0.0, 0.02, 0.45)
const WALL_DEPTH := 0.9
const PAVEMENT_DEPTH := 7.0
## A street light every this many metres on each side (staggered).
const LAMP_STEP := 18.0
const LIGHT_RADIUS := 21.0
## Buildings stand up to this far from the wall (m).
const BLOCK_DEPTH := 170.0
const BLOCK_STEP := 16.0
const SPHERE_RADIUS := 30.0

## Placed buildings (centres), for checks and tests.
var buildings := PackedVector2Array()
var sphere := Vector2.INF
var _lights := MeshBuilder.new()


func _dress() -> void:
	for side: float in [1.0, -1.0]:
		_walls(side)
		_street_lights(side)
	_floodlights()
	_sphere()  # first: its real place wins over stands and buildings
	_stands()
	_buildings()


func _after_layers() -> void:
	var node := Node2D.new()
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	node.material = material
	add_child(node)
	_triangles += _lights.add_tiles_to(node)
	for tile in node.get_children():
		(tile as CanvasItem).use_parent_material = true


## Concrete wall with a light top, fence, light panels and a pavement behind it; street lights
## on it every LAMP_STEP metres. None where it would fold or cross the pit lane / another corner.
func _walls(side: float) -> void:
	var wall := _wall()
	var n := track.point_count()
	for i in n:
		var j := (i + 1) % n
		var a := MeshBuilder.offset(track, i, side * (wall + 0.5))
		var b := MeshBuilder.offset(track, j, side * (wall + 0.5))
		var blocked := not _gravel_map.is_clear(a) or not _gravel_map.is_clear(b) \
				or not _lane_map.is_clear(a) or not _lane_map.is_clear(b)
		if blocked or not _wall_fits(i, side * (wall + PAVEMENT_DEPTH)) or not _wall_fits(j, side * (wall + PAVEMENT_DEPTH)):
			continue
		_objects.track_quad(track, i, side * (wall + WALL_DEPTH), side * (wall + PAVEMENT_DEPTH), SIDEWALK)
		_objects.track_quad(track, i, side * wall, side * (wall + WALL_DEPTH), WALL)
		_objects.track_quad(track, i, side * (wall + 0.25), side * (wall + 0.55), WALL_TOP)
		if (i / 3) % 4 == 0:  # glowing panel on the track side of the wall
			_objects.track_quad(track, i, side * (wall - 0.12), side * wall, NEON[(i / 12) % NEON.size()])
		_objects.track_quad(track, i, side * (wall + 1.4), side * (wall + 1.5), CITY_FENCE)
		_shadows.track_quad(track, i, side * (wall + WALL_DEPTH), side * (wall + WALL_DEPTH + 0.8), CITY_SHADOW)


## Street lights every LAMP_STEP metres along one side (staggered with the other side), behind
## the wall or at the edge of the run-off; not on the pit lane or folded inside a tight bend.
func _street_lights(side: float) -> void:
	var travelled := LAMP_STEP * (0.5 if side > 0.0 else 0.0)
	for i in track.point_count():
		travelled += track.distances[1] - track.distances[0]
		if travelled < LAMP_STEP:
			continue
		var pole := MeshBuilder.offset(track, i, side * (_wall() + 2.2))
		if not _lane_map.is_clear(pole) or not _wall_fits(i, side * (_wall() + 2.2)):
			continue
		travelled = 0.0
		_lamp(i, side)


## A bright floodlight over the apex of every corner.
func _floodlights() -> void:
	for apex in TrackSurface._apexes(RacingLine.for_track(track)):
		_glow(_lights, track.points[apex], FLOOD_RADIUS, FLOOD)


## A street light behind the wall with its pool of light on the track.
func _lamp(index: int, side: float) -> void:
	var pole := MeshBuilder.offset(track, index, side * (_wall() + 2.2))
	_objects.circle(pole, 0.45, Color(0.25, 0.25, 0.28), 6)
	_objects.box(MeshBuilder.offset(track, index, side * (_wall() + 1.0)), track.normal(index), Vector2(2.4, 0.5), Color(0.3, 0.3, 0.33))
	_objects.circle(MeshBuilder.offset(track, index, side * (_wall() - 0.2)), 0.6, LAMP, 6)
	var centre := MeshBuilder.offset(track, index, side * track.half_width() * 0.35)
	_glow(_lights, centre, LIGHT_RADIUS, LIGHT_POOL)


## The giant glowing sphere at its real place, moved outwards until it is clear of the track.
func _sphere() -> void:
	if not track.landmarks.has("sphere"):
		return
	var at: Vector2 = track.landmarks["sphere"]
	var nearest := track.points[0]
	for p in track.points:
		if p.distance_squared_to(at) < nearest.distance_squared_to(at):
			nearest = p
	var away := (at - nearest).normalized()
	for step in 30:
		if _map.is_clear(at, SPHERE_RADIUS):
			break
		at += away * 4.0
	if not _map.is_clear(at, SPHERE_RADIUS):
		return
	sphere = at
	_map.block_circle(at, SPHERE_RADIUS + 6.0)
	_shadows.circle(at + Vector2(3.0, 3.0), SPHERE_RADIUS + 1.0, CITY_SHADOW, 40)
	_objects.circle(at, SPHERE_RADIUS + 0.8, Color(0.1, 0.1, 0.14), 40)
	# A big screen of LED rings: colour bands from the outside in, a bright eye in the middle.
	var rings: Array[Color] = [Color(0.15, 0.3, 0.9), Color(0.3, 0.55, 1.0), Color(0.95, 0.85, 0.4), Color(1.0, 0.6, 0.25), Color(1.0, 0.95, 0.85)]
	for r in rings.size():
		_objects.circle(at, SPHERE_RADIUS * (1.0 - r * 0.18), rings[r], 40)
	_glow(_lights, at, SPHERE_RADIUS * 1.8, Color(0.4, 0.55, 1.0, 0.22))


## City blocks along both sides: buildings aligned with the street, where the map is free.
func _buildings() -> void:
	var n := track.point_count()
	var start := _wall() + PAVEMENT_DEPTH + 4.0
	for i in range(0, n, 4):
		for side: float in [1.0, -1.0]:
			var distance := start
			while distance < start + BLOCK_DEPTH:
				var size := Vector2(_rng.randf_range(16.0, 46.0), _rng.randf_range(14.0, 34.0))
				var along := track.tangents[i]
				var centre := track.points[i] + track.normal(i) * side * (distance + size.y * 0.5)
				distance += size.y + _rng.randf_range(4.0, 10.0)
				if _free(centre, along, size):
					_block(centre, along, size)
					_building(centre, along, size)


## True if the whole rectangle is free (checked every 6 m).
func _free(centre: Vector2, along: Vector2, size: Vector2) -> bool:
	var across := Vector2(-along.y, along.x)
	var x := -size.x * 0.5
	while x <= size.x * 0.5 + 0.1:
		var y := -size.y * 0.5
		while y <= size.y * 0.5 + 0.1:
			if not _map.is_clear(centre + along * x + across * y):
				return false
			y += 6.0
		x += 6.0
	return true


func _block(centre: Vector2, along: Vector2, size: Vector2) -> void:
	var across := Vector2(-along.y, along.x)
	var x := -size.x * 0.5
	while x <= size.x * 0.5 + 0.1:
		var y := -size.y * 0.5
		while y <= size.y * 0.5 + 0.1:
			_map.block_circle(centre + along * x + across * y, 5.0)
			y += 6.0
		x += 6.0


## Top view of a building: shadow, roof with a lit edge (windows), rooftop units, sometimes a
## neon outline.
func _building(centre: Vector2, along: Vector2, size: Vector2) -> void:
	buildings.append(centre)
	var across := Vector2(-along.y, along.x)
	var roof := ROOFS[_rng.randi() % ROOFS.size()]
	_shadows.box(centre + Vector2(4.0, 4.0), along, size, CITY_SHADOW)
	_objects.box(centre, along, size, roof.darkened(0.35))
	_objects.box(centre, along, size - Vector2(2.0, 2.0), roof)
	# Lit windows along the long edges.
	var x := -size.x * 0.5 + 2.0
	while x < size.x * 0.5 - 2.0:
		for edge: float in [-1.0, 1.0]:
			if _rng.randf() < 0.55:
				var p := centre + along * x + across * edge * (size.y * 0.5 - 0.5)
				_objects.box(p, along, Vector2(1.6, 0.6), WINDOW.darkened(_rng.randf_range(0.0, 0.4)))
		x += 2.6
	for unit in _rng.randi_range(1, 4):
		var p := centre + along * _rng.randf_range(-size.x * 0.3, size.x * 0.3) + across * _rng.randf_range(-size.y * 0.3, size.y * 0.3)
		_objects.box(p, along, Vector2(_rng.randf_range(2.5, 6.0), _rng.randf_range(2.0, 4.0)), roof.lightened(0.18))
	if _rng.randf() < 0.5:
		var neon := NEON[_rng.randi() % NEON.size()]
		for edge: float in [-1.0, 1.0]:
			_objects.box(centre + across * edge * (size.y * 0.5 - 1.5), along, Vector2(size.x - 3.0, 0.4), neon)
			_objects.box(centre + along * edge * (size.x * 0.5 - 1.5), across, Vector2(size.y - 3.0, 0.4), neon)
		_glow(_lights, centre, maxf(size.x, size.y) * 0.8, Color(neon.r, neon.g, neon.b, 0.2))


## A soft round light: `color` in the middle fading to nothing at `radius`.
static func _glow(builder: MeshBuilder, centre: Vector2, radius: float, color: Color) -> void:
	var rim := Color(color.r, color.g, color.b, 0.0)
	var segments := 20
	var previous := centre + Vector2(radius, 0.0)
	for k in range(1, segments + 1):
		var next := centre + Vector2.from_angle(TAU * k / segments) * radius
		builder.quad_colors(centre, previous, next, centre, color, rim, rim, color)
		previous = next
