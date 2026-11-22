class_name PitLane
extends RefCounted
## Geometry of the pit lane (PLAN.md B): a lane parallel to the start/finish straight on the
## inside of the lap, joined to the track edge by an entry and an exit curve. Built from the
## track at run time: the straight around the line is found from the curvature. The path is
## a polyline in metres with distances; garages (boxes) are at fixed distances along it.

## A curve sharper than this radius ends the straight.
const STRAIGHT_RADIUS := 500.0
const STEP := 2.0
## Path starts/ends this far inside the asphalt edge (the car turns in from the track).
const EDGE_INSET := 3.0

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
	return clampf(rules.pit_blend + rules.pit_first_box + slot * rules.pit_box_spacing, 0.0, length - rules.pit_blend)


func box_count() -> int:
	return int((length - 2.0 * rules.pit_blend - rules.pit_first_box) / rules.pit_box_spacing)


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
	# Inside of the lap: clockwise laps turn right overall.
	var total := 0.0
	for k in track.curvatures:
		total += k
	side = 1.0 if total > 0.0 else -1.0
	var before := _straight_extent(-1)
	var after := _straight_extent(1)
	entry_distance = fposmod(-before, track.length)
	exit_distance = after
	var span := before + after
	var inset := side * (track.half_width() - EDGE_INSET)
	var d := 0.0
	while d <= span:
		var blend := 1.0
		if d < rules.pit_blend:
			blend = smoothstep(0.0, rules.pit_blend, d)
		elif d > span - rules.pit_blend:
			blend = smoothstep(0.0, rules.pit_blend, span - d)
		points.append(track.position_at(entry_distance + d, lerpf(inset, lane_lateral(), blend)))
		d += STEP
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
		if absf(track.curvatures[index]) > 1.0 / STRAIGHT_RADIUS:
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
