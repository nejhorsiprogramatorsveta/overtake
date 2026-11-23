class_name TrackScenery
extends Node2D
## Everything around a track (M3G, PLAN.md B): tyre barriers made of single tyres with a belt on
## the track side, the catch fence with posts, grandstands with a crowd and a roof, and woods of
## trees, all with soft shadows (sun from the top left). The pit side has no barrier along the
## pit lane (the pit building closes it). Placement is deterministic per track and uses a
## KeepOutMap, so nothing stands on the track, the pit lane or another object.
## Built once into meshes. Units are metres.

const SHADOW := Color(0.0, 0.03, 0.0, 0.28)
const SHADOW_OFFSET := Vector2(1.0, 1.0)
const BARRIER_BASE := Color(0.08, 0.08, 0.09)
const TYRE := Color(0.17, 0.17, 0.19)
const TYRE_HOLE := Color(0.05, 0.05, 0.06)
const BELT_A := Color(0.14, 0.32, 0.7)
const BELT_B := Color(0.92, 0.93, 0.95)
const FENCE := Color(0.8, 0.82, 0.86, 0.85)
const POST := Color(0.3, 0.31, 0.34)
const TREES: Array[Color] = [Color(0.15, 0.36, 0.16), Color(0.19, 0.42, 0.18), Color(0.12, 0.31, 0.15), Color(0.24, 0.45, 0.2)]
const STAND_BASE := Color(0.56, 0.57, 0.6)
const SEATS := Color(0.2, 0.3, 0.55)
const ROOF := Color(0.9, 0.91, 0.93)
const CROWD: Array[Color] = [Color(0.9, 0.9, 0.9), Color(0.85, 0.2, 0.2), Color(0.95, 0.8, 0.2), Color(0.2, 0.25, 0.3),
		Color(0.3, 0.6, 0.9), Color(0.95, 0.55, 0.2), Color(0.55, 0.8, 0.4), Color(0.7, 0.5, 0.4)]
const TYRE_RADIUS := 0.55
const BARRIER_DEPTH := 1.2
## Trees grow up to this far from the barrier (m).
const WOODS_DEPTH := 140.0
const TREE_STEP := 7.0
## Keep-out radius around the pit lane path, and along the garages (lane + garages + building).
const LANE_CLEARANCE := 8.0
const PIT_BUILDING_CLEARANCE := 34.0
const STAND_DEPTH := 16.0
## Free space between the barrier and the front of a stand (m).
const STAND_GAP := 12.0
## Centre-line points either side checked when testing whether a wall folds.
const FOLD_WINDOW := 40

var track: TrackData
var lane: PitLane
## Placed objects (centres), for checks and tests.
var trees := PackedVector2Array()
var stands := PackedVector2Array()
var _triangles := 0
var _shadows := MeshBuilder.new()
var _objects := MeshBuilder.new()
var _map: KeepOutMap
var _lane_map: KeepOutMap
## Gravel traps of all corners: no barrier runs through another corner's gravel.
var _gravel_map: KeepOutMap
var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()


func setup(track_data: TrackData, pit_lane: PitLane) -> void:
	track = track_data
	lane = pit_lane
	_rng.seed = hash(track.id + "scenery")
	_noise.seed = hash(track.id + "woods")
	_build()
	queue_redraw()


func triangle_count() -> int:
	return _triangles


func _wall() -> float:
	return track.half_width() + TrackData.RUNOFF_WIDTH


func _build() -> void:
	var min_p := track.points[0]
	var max_p := track.points[0]
	for p in track.points:
		min_p = min_p.min(p)
		max_p = max_p.max(p)
	var area := Rect2(min_p, max_p - min_p).grow(_wall() + WOODS_DEPTH + 20.0)
	_map = KeepOutMap.new(area)
	_lane_map = KeepOutMap.new(area)
	_gravel_map = KeepOutMap.new(area)
	var corner := TrackView.corner_mask(track)
	for i in track.point_count():
		if corner[i]:
			_gravel_map.block_circle(track.points[i], _wall() - 7.0)
	for i in range(0, track.point_count(), 2):
		_map.block_circle(track.points[i], _wall() + 3.0)
	if lane:
		for i in range(0, lane.points.size(), 2):
			var radius := PIT_BUILDING_CLEARANCE if lane.is_full_offset(lane.distances[i]) else LANE_CLEARANCE
			_map.block_circle(lane.points[i], radius)
			_lane_map.block_circle(lane.points[i], radius - 14.0 if radius > LANE_CLEARANCE else LANE_CLEARANCE)
	for side: float in [1.0, -1.0]:
		_barrier(side)
	_stands()
	_trees()
	for builder: MeshBuilder in [_shadows, _objects]:
		var node := Node2D.new()
		add_child(node)
		_triangles += builder.add_tiles_to(node)


## Tyre wall at the end of the run-off on one side; none where it would fold on the inside of a
## bend or cross the pit lane.
func _barrier(side: float) -> void:
	var wall := _wall()
	var n := track.point_count()
	var carry := 0.0
	for i in n:
		var j := (i + 1) % n
		var a := MeshBuilder.offset(track, i, side * (wall + 0.6))
		var b := MeshBuilder.offset(track, j, side * (wall + 0.6))
		var blocked := not _gravel_map.is_clear(a) or not _gravel_map.is_clear(b) \
				or not _lane_map.is_clear(a) or not _lane_map.is_clear(b)
		if blocked or not _wall_fits(i, side * (wall + BARRIER_DEPTH)) or not _wall_fits(j, side * (wall + BARRIER_DEPTH)):
			carry = 0.0
			continue
		var belt := BELT_A if (i / 2) % 2 == 0 else BELT_B
		_objects.track_quad(track, i, side * (wall - 0.15), side * wall, belt)
		_objects.track_quad(track, i, side * wall, side * (wall + BARRIER_DEPTH), BARRIER_BASE)
		_objects.track_quad(track, i, side * (wall + 1.75), side * (wall + 1.87), FENCE)
		_shadows.track_quad(track, i, side * (wall + BARRIER_DEPTH), side * (wall + BARRIER_DEPTH + 0.7), SHADOW)
		var segment := a.distance_to(b)
		while carry < segment:
			var p := a.lerp(b, carry / segment)
			_objects.circle(p, TYRE_RADIUS, TYRE, 7)
			_objects.circle(p, TYRE_RADIUS * 0.45, TYRE_HOLE, 6)
			carry += TYRE_RADIUS * 2.05
		carry -= segment
		if i % 3 == 0:
			var post := MeshBuilder.offset(track, i, side * (wall + 1.81))
			_objects.box(post, track.tangents[i], Vector2(0.4, 0.4), POST)


## False where the wall would come closer to the centre line than its own offset: on the inside
## of a bend the offset curve folds into a loop that would cross the track.
func _wall_fits(index: int, lateral: float) -> bool:
	var n := track.point_count()
	var p := MeshBuilder.offset(track, index, lateral)
	var limit := (absf(lateral) - 1.5) * (absf(lateral) - 1.5)
	for k in range(-FOLD_WINDOW, FOLD_WINDOW + 1):
		if track.points[posmod(index + k, n)].distance_squared_to(p) < limit:
			return false
	return true


## Grandstands: along the main straight opposite the pits and outside the sharpest corners.
func _stands() -> void:
	var n := track.point_count()
	var main_side := -lane.side if lane else -1.0
	_try_stand(posmod(-int(40.0 / 4.0), n), main_side, 110.0)
	var corners := TrackSurface._apexes(RacingLine.for_track(track))
	var by_sharpness := Array(corners)
	by_sharpness.sort_custom(func(a: int, b: int) -> bool: return absf(track.curvatures[a]) > absf(track.curvatures[b]))
	var placed := 0
	for apex: int in by_sharpness:
		if placed >= 4:
			break
		var outside := -signf(track.curvatures[apex])
		if _try_stand(apex, outside, 70.0):
			placed += 1


## A stand at a centre-line point on one side if its whole area is free.
func _try_stand(index: int, side: float, length: float) -> bool:
	var along := track.tangents[index]
	var out := track.normal(index) * side
	var centre := track.points[index] + out * (_wall() + STAND_GAP + STAND_DEPTH * 0.5)
	var x := -length * 0.5
	while x <= length * 0.5:
		var y := -STAND_DEPTH * 0.5
		while y <= STAND_DEPTH * 0.5:
			if not _map.is_clear(centre + along * x + out * y):
				return false
			y += 4.0
		x += 4.0
	_map.block_circle(centre, 4.0)
	x = -length * 0.5
	while x <= length * 0.5:
		_map.block_circle(centre + along * x, STAND_DEPTH * 0.7)
		x += 8.0
	stands.append(centre)
	_draw_stand(centre, along, out, length)
	return true


## Top view of a stand: concrete base, seat rows with the crowd (towards the track), roof at the back.
func _draw_stand(centre: Vector2, along: Vector2, out: Vector2, length: float) -> void:
	_shadows.box(centre + SHADOW_OFFSET * 3.0, along, Vector2(length, STAND_DEPTH), SHADOW)
	_objects.box(centre, along, Vector2(length + 1.0, STAND_DEPTH + 1.0), STAND_BASE)
	var front := centre - out * STAND_DEPTH * 0.5
	var rows := 9
	for row in rows:
		var row_centre := front + out * (0.9 + row * 1.2)
		_objects.box(row_centre, along, Vector2(length - 1.0, 1.0), SEATS.lightened(0.04 * (row % 2)))
		var x := -length * 0.5 + 1.2
		while x < length * 0.5 - 1.0:
			if _rng.randf() < 0.75:
				_objects.box(row_centre + along * (x + _rng.randf_range(-0.1, 0.1)), along, Vector2(0.55, 0.6), CROWD[_rng.randi() % CROWD.size()])
			x += 0.8
	var roof_centre := centre + out * STAND_DEPTH * 0.32
	_objects.box(roof_centre, along, Vector2(length + 1.0, STAND_DEPTH * 0.36), ROOF)
	var x2 := -length * 0.5 + 5.0
	while x2 < length * 0.5:
		_objects.box(roof_centre + along * x2, out, Vector2(STAND_DEPTH * 0.36, 0.25), ROOF.darkened(0.15))
		x2 += 6.0


## Woods: candidate spots in bands along both sides, planted where the noise says "wood" (some
## single trees elsewhere) and the spot is free.
func _trees() -> void:
	var n := track.point_count()
	var start := _wall() + 7.0
	for i in range(0, n, 2):
		for side: float in [1.0, -1.0]:
			var distance := start
			while distance < start + WOODS_DEPTH:
				var p := track.points[i] + track.normal(i) * side * distance \
						+ Vector2(_rng.randf_range(-3.0, 3.0), _rng.randf_range(-3.0, 3.0))
				distance += TREE_STEP
				var wood := _noise.get_noise_2d(p.x, p.y)
				if wood < 0.05 and _rng.randf() > 0.04:
					continue
				var radius := _rng.randf_range(2.6, 4.6)
				if not _map.is_clear(p, radius):
					continue
				_map.block_circle(p, radius * 0.75)
				_tree(p, radius)


func _tree(p: Vector2, radius: float) -> void:
	trees.append(p)
	var color := TREES[_rng.randi() % TREES.size()]
	_shadows.circle(p + SHADOW_OFFSET * radius * 0.6, radius, SHADOW, 9)
	_objects.circle(p, radius, color.darkened(0.25), 9)
	_objects.circle(p, radius * 0.86, color, 9)
	_objects.circle(p - Vector2(radius, radius) * 0.22, radius * 0.5, color.lightened(0.12), 7)
