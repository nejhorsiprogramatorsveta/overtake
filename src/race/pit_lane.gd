class_name PitLane
extends RefCounted
## Geometry of the pit lane (PLAN.md B): leaves the track at TrackData.pit_entry and rejoins it at
## pit_exit (like the real circuit; Austria: entry between T9 and T10, lane along the main
## straight, exit inside T1), always on the inside of the lap.
## Entry and exit are smooth curves through the infield (not along the corner), the middle runs
## beside the main straight. Without entry/exit data the lane uses the straight around the line.
## The path is a polyline in metres; garages stand along the main straight around the line.

## A curve sharper than this radius ends the straight.
const STRAIGHT_RADIUS := 500.0
const STEP := 2.0
## Path starts/ends this far inside the asphalt edge (the car turns in from the track).
const EDGE_INSET := 3.0
## The garages stand along the main straight from this far before the line to this far after.
const GARAGES_BEFORE_LINE := 150.0
## Garages: one per car of a full grid (LobbyValidator.MAX_CARS).
const GARAGES := 12
## The straight lane part stops this far before the corners at either end of the straight.
const STRAIGHT_MARGIN := 15.0
## Shortest entry/exit curve between the track edge and the straight lane part (m).
const MIN_CURVE := 60.0

var track: TrackData
var rules: RaceRules
## +1 = right of the driving direction, -1 = left.
var side := 1.0
## Track distances where the pit entry starts and the exit ends.
var entry_distance := 0.0
var exit_distance := 0.0
var points := PackedVector2Array()
var distances := PackedFloat32Array()
var length := 0.0
## Lateral offset (from the centre line, towards `side`) at each path point.
var laterals := PackedFloat32Array()
var _box_start := 0.0
var _box_end := 0.0


static func build(track_data: TrackData, race_rules: RaceRules) -> PitLane:
	var lane := PitLane.new()
	lane.track = track_data
	lane.rules = race_rules
	lane._build()
	return lane


## Track lateral offset of the pit lane centre.
func lane_lateral() -> float:
	return side * (track.half_width() + rules.pit_offset)


func box_distance(slot: int) -> float:
	return clampf(_box_start + rules.pit_box_spacing * 0.5 + slot * rules.pit_box_spacing, 0.0, length)


func box_count() -> int:
	return maxi(int((_box_end - _box_start) / rules.pit_box_spacing), 1)


## True where the lane runs at its full distance from the track (pit wall, limiter lines).
func is_full_offset(s: float) -> bool:
	var i := _index_at(s)
	return laterals[i] >= track.half_width() + rules.pit_offset - 0.5


func position_at(s: float) -> Vector2:
	var i := _index_at(s)
	var seg := distances[i + 1] - distances[i]
	return points[i].lerp(points[i + 1], (s - distances[i]) / seg if seg > 0.0 else 0.0)


func direction_at(s: float) -> Vector2:
	var i := _index_at(s)
	return (points[i + 1] - points[i]).normalized()


## Distance along the pit path closest to `position` (searched over the whole path).
func project(position: Vector2) -> float:
	var best := INF
	var best_s := 0.0
	for i in points.size() - 1:
		var ab := points[i + 1] - points[i]
		var t := clampf((position - points[i]).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var d := position.distance_squared_to(points[i] + ab * t)
		if d < best:
			best = d
			best_s = distances[i] + ab.length() * t
	return best_s


## True if a car at this track position is turning into the pit entry.
func is_at_entry(query: TrackQuery) -> bool:
	var into := fposmod(query.distance - entry_distance + 20.0, track.length)
	return into < 35.0 and query.lateral * side > track.half_width() - 4.0


func _build() -> void:
	# Inside of the lap (clockwise laps turn right overall), unless the track data says otherwise.
	var total := 0.0
	for k in track.curvatures:
		total += k
	side = 1.0 if total > 0.0 else -1.0
	if track.pit_outside:
		side = -side
	# The straight lane part runs beside the main straight around the line.
	var lane_from := -_straight_extent(-1) + STRAIGHT_MARGIN
	var lane_to := _straight_extent(1) - STRAIGHT_MARGIN
	if track.pit_entry >= 0.0 and track.pit_exit >= 0.0:
		entry_distance = track.pit_entry * track.length
		exit_distance = track.pit_exit * track.length
		# A short straight (exit just before T1): the lane's straight part ends early enough for
		# the curve back to the track edge, likewise after the entry.
		lane_to = minf(lane_to, exit_distance - MIN_CURVE)
		var entry_from_line := entry_distance - track.length if entry_distance > track.length * 0.5 else entry_distance
		lane_from = maxf(lane_from, entry_from_line + MIN_CURVE)
	else:
		entry_distance = fposmod(lane_from - rules.pit_blend, track.length)
		exit_distance = lane_to + rules.pit_blend
	var inset := side * (track.half_width() - EDGE_INSET)
	var full := lane_lateral()
	var dense := PackedVector2Array()
	# Entry: a smooth curve through the infield from the track edge to the straight lane.
	_curve(dense, track.position_at(entry_distance, inset), track.tangents[track._index_at(fposmod(entry_distance, track.length))],
			track.position_at(lane_from, full), track.tangents[track._index_at(fposmod(lane_from, track.length))])
	var d := lane_from + 1.0
	while d < lane_to:
		dense.append(track.position_at(d, full))
		d += 1.0
	# Exit: a smooth curve through the infield back to the track edge after the corner.
	_curve(dense, track.position_at(lane_to, full), track.tangents[track._index_at(fposmod(lane_to, track.length))],
			track.position_at(exit_distance, inset), track.tangents[track._index_at(fposmod(exit_distance, track.length))])
	_resample(dense)
	var query := TrackQuery.new()
	for point in points:
		query.update(track, point)
		laterals.append(query.lateral * side)
	# Garages along the straight lane part around the start/finish line, room for every car.
	var need := GARAGES * rules.pit_box_spacing + 2.0
	var from := maxf(-GARAGES_BEFORE_LINE, lane_from + 4.0)
	var to := from + need
	if to > lane_to - 4.0:
		to = lane_to - 4.0
		from = maxf(lane_from + 4.0, to - need)
	_box_start = project(track.position_at(from, full))
	# Measured along the lane itself (it is longer/shorter than the track beside a bend).
	var lane_end := project(track.position_at(lane_to - 4.0, full))
	_box_end = minf(_box_start + need, lane_end)
	if _box_end - _box_start < need:
		_box_start = maxf(project(track.position_at(lane_from + 4.0, full)), _box_end - need)


## Cubic Bezier from a (heading da) to b (heading db), appended in ~1 m steps.
func _curve(target: PackedVector2Array, a: Vector2, da: Vector2, b: Vector2, db: Vector2) -> void:
	var reach := a.distance_to(b) * 0.4
	var c1 := a + da * reach
	var c2 := b - db * reach
	var steps := maxi(int(a.distance_to(b) * 1.5), 8)
	for i in steps + 1:
		var t := float(i) / steps
		var u := 1.0 - t
		target.append(a * u * u * u + c1 * 3.0 * u * u * t + c2 * 3.0 * u * t * t + b * t * t * t)


## Points every STEP metres along a dense polyline.
func _resample(dense: PackedVector2Array) -> void:
	points.append(dense[0])
	var carried := 0.0
	for i in range(1, dense.size()):
		var a := dense[i - 1]
		var b := dense[i]
		var seg := a.distance_to(b)
		var pos := STEP - carried
		while pos <= seg:
			points.append(a.lerp(b, pos / seg))
			pos += STEP
		carried = seg - (pos - STEP)
	if points[points.size() - 1].distance_to(dense[dense.size() - 1]) > 0.1:
		points.append(dense[dense.size() - 1])
	distances.resize(points.size())
	var total_length := 0.0
	for i in points.size():
		if i > 0:
			total_length += points[i].distance_to(points[i - 1])
		distances[i] = total_length
	length = total_length


## Metres of straight from the line backwards (-1) or forwards (1), minus a safety margin.
func _straight_extent(direction: int) -> float:
	var d := 0.0
	while d < track.length * 0.4:
		var index := track._index_at(fposmod(d * direction, track.length))
		if absf(track.curvatures[index]) > 1.0 / (track.pit_straight_radius if track.pit_straight_radius > 0.0 else STRAIGHT_RADIUS):
			break
		d += STEP
	return maxf(d - 20.0, rules.pit_blend + 10.0)


func _index_at(s: float) -> int:
	s = clampf(s, 0.0, length)
	var low := 0
	var high := distances.size() - 2
	while low < high:
		var mid := (low + high + 1) / 2
		if distances[mid] <= s:
			low = mid
		else:
			high = mid - 1
	return low
