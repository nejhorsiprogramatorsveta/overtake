class_name TrackQuery
extends RefCounted
## Where a car is relative to the track: nearest centre-line segment, distance along the lap,
## lateral offset (right = positive) and surface. A search hint (the last index) keeps it
## cheap and stops a car from "jumping" to a nearby, different part of the lap - unless the car
## left the asphalt and is now on the asphalt of that other part (then it really is there).

enum Surface { TRACK, RUNOFF, BARRIER }

## Segments searched around the hint (behind, ahead); a car moves < 2 segments per tick.
const SEARCH_BEHIND := 6
const SEARCH_AHEAD := 12

var index := -1
## 0..1 position on the segment index -> index + 1.
var t := 0.0
var distance := 0.0
var lateral := 0.0
var surface := Surface.TRACK


## Updates this query for `position`; uses the previous result as the search hint.
func update(track: TrackData, position: Vector2) -> void:
	var n := track.point_count()
	var best := INF
	if index >= 0:
		best = _search(track, position, index - SEARCH_BEHIND, index + SEARCH_AHEAD)
	# Lost (first call, teleport, far off the track): search the whole lap.
	if index < 0 or best > track.width + TrackData.RUNOFF_WIDTH * 2.0:
		_search(track, position, 0, n - 1)
	elif absf(lateral) > track.half_width() + TrackData.KERB_WIDTH:
		# Off the asphalt of this part: maybe on the asphalt of another, close part of the lap
		# (narrow infield gaps in Brazil and China) - then the car is there, not in this run-off.
		var kept := [index, t, distance, lateral]
		_search(track, position, 0, n - 1)
		if absf(lateral) > track.half_width() + TrackData.KERB_WIDTH:
			index = kept[0]
			t = kept[1]
			distance = kept[2]
			lateral = kept[3]
	var edge := absf(lateral) - track.half_width()
	if edge <= TrackData.KERB_WIDTH:
		surface = Surface.TRACK
	elif edge <= TrackData.RUNOFF_WIDTH:
		surface = Surface.RUNOFF
	else:
		surface = Surface.BARRIER


## Squared distance of the best segment in [from, to] (indices wrap); stores the result.
func _search(track: TrackData, position: Vector2, from: int, to: int) -> float:
	var n := track.point_count()
	var best := INF
	for raw in range(from, to + 1):
		var i := posmod(raw, n)
		var a := track.points[i]
		var b := track.points[(i + 1) % n]
		var ab := b - a
		var seg_t := clampf((position - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var closest := a + ab * seg_t
		var dist := position.distance_squared_to(closest)
		if dist < best:
			best = dist
			index = i
			t = seg_t
			var dir := ab.normalized()
			lateral = (position - closest).dot(Vector2(-dir.y, dir.x))
			distance = fposmod(track.distances[i] + ab.length() * seg_t, track.length)
	return sqrt(best)
