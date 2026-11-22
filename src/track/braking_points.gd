class_name BrakingPoints
extends RefCounted
## Recommended braking points (BP boards, PLAN.md B): where the fastest possible lap
## (SpeedProfile) starts braking for a corner. With worn tyres the profile is computed with
## less grip, so the same corner gets an earlier BP for that player (M2 tyre wear).
## Only braking zones that start on a straight-ish part get a board (not a second braking inside
## a corner, user 2026-11-22: boards in China were "completely off"), and a board never stands
## next to another part of the lap.

## Distance along the lap where braking starts.
var distances := PackedFloat32Array()
## Side of the track for the board: -1 left, 1 right (the outside of the coming corner, or the
## other side when the outside is too close to another part of the lap).
var sides := PackedInt32Array()
## False where neither side has room for the board (only the white block on the asphalt).
var boards: Array[bool] = []
## Speed before braking and the slowest speed of the corner (m/s), for bots and tests.
var entry_speeds := PackedFloat32Array()
var corner_speeds := PackedFloat32Array()


## Braking zones starting where the racing line is tighter than this (m) are inside a corner.
const MIN_START_RADIUS := 60.0
## A board must be nearer to its own part of the lap than this (m along the lap) - else it would
## stand beside another part of the track.
const OWN_PART := 40.0
## A board keeps this far from the pit lane centre (m): lane half width + board + wall.
const PIT_CLEARANCE := 14.0


## lane (optional): boards also keep off the pit lane.
static func find(track: TrackData, profile: SpeedProfile, min_speed_drop: float, lane: PitLane = null) -> BrakingPoints:
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
		if v[start] - v[end] >= min_speed_drop and _starts_straight(track, start):
			var outside := -1 if _corner_direction(track, end) > 0.0 else 1
			var side := outside if _board_fits(track, start, outside, lane) else -outside
			result.distances.append(track.distances[start])
			result.sides.append(side)
			result.boards.append(_board_fits(track, start, side, lane))
			result.entry_speeds.append(v[start])
			result.corner_speeds.append(v[end])
		raw += length + 1
	return result


func count() -> int:
	return distances.size()


## True if the racing line is not yet in a corner where the braking starts.
static func _starts_straight(track: TrackData, index: int) -> bool:
	var line := RacingLine.for_track(track)
	var n := track.point_count()
	for k in range(-3, 4):
		if absf(line.curvatures[posmod(index + k, n)]) > 1.0 / MIN_START_RADIUS:
			return false
	return true


## True if a board on `side` at this point is closest to this part of the lap.
static func _board_fits(track: TrackData, index: int, side: int, lane: PitLane = null) -> bool:
	var reach := track.half_width() + TrackData.KERB_WIDTH + BpMarkers.BOARD_OFFSET + BpMarkers.BOARD_SIZE.x * 0.5
	var board := track.points[index] + track.normal(index) * side * reach
	if lane:
		for point in lane.points:
			if point.distance_to(board) < PIT_CLEARANCE:
				return false
	var query := TrackQuery.new()
	query.update(track, board)
	var along := absf(query.distance - track.distances[index])
	return minf(along, track.length - along) < OWN_PART


## Sum of curvature around the slowest point: > 0 = right-hand corner.
static func _corner_direction(track: TrackData, index: int) -> float:
	var n := track.point_count()
	var total := 0.0
	for k in range(-8, 9):
		total += track.curvatures[posmod(index + k, n)]
	return total
