class_name BrakingPoints
extends RefCounted
## Recommended braking points (BP boards, PLAN.md B): where the fastest possible lap
## (SpeedProfile) starts braking for a corner. With worn tyres the profile is computed with
## less grip, so the same corner gets an earlier BP for that player (M2 tyre wear).

## Distance along the lap where braking starts.
var distances := PackedFloat32Array()
## Side of the track for the board: -1 left, 1 right (the outside of the coming corner).
var sides := PackedInt32Array()
## Speed before braking and the slowest speed of the corner (m/s), for bots and tests.
var entry_speeds := PackedFloat32Array()
var corner_speeds := PackedFloat32Array()


static func find(track: TrackData, profile: SpeedProfile, min_speed_drop: float) -> BrakingPoints:
	var result := BrakingPoints.new()
	var v := profile.speeds
	var n := v.size()
	# Start scanning where the car is not braking, so no zone is split by the wrap.
	var origin := 0
	while origin < n and v[(origin + 1) % n] < v[origin] - 0.01:
		origin += 1
	var raw := 0
	while raw < n:
		var i := (origin + raw) % n
		if v[(i + 1) % n] >= v[i] - 0.01:
			raw += 1
			continue
		var start := i
		var length := 0
		while length < n and v[(start + length + 1) % n] < v[(start + length) % n] - 0.01:
			length += 1
		var end := (start + length) % n
		if v[start] - v[end] >= min_speed_drop:
			result.distances.append(track.distances[start])
			result.sides.append(-1 if _corner_direction(track, end) > 0.0 else 1)
			result.entry_speeds.append(v[start])
			result.corner_speeds.append(v[end])
		raw += length + 1
	return result


func count() -> int:
	return distances.size()


## Sum of curvature around the slowest point: > 0 = right-hand corner.
static func _corner_direction(track: TrackData, index: int) -> float:
	var n := track.point_count()
	var total := 0.0
	for k in range(-8, 9):
		total += track.curvatures[posmod(index + k, n)]
	return total
