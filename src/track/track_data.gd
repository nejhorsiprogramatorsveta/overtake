class_name TrackData
extends RefCounted
## One circuit loaded from data/tracks/<id>.json (made by tools/tracks/build_track.py):
## a closed centre line in metres (x east, y south), point 0 = start/finish line, plus
## per-point helpers. Lateral offsets are positive on the RIGHT of the driving direction.

## Kerbs extend the track beyond the white line; they count as track (PLAN.md B).
const KERB_WIDTH := 1.5
const STYLE_CIRCUIT := "circuit"
const STYLE_CITY_NIGHT := "city_night"
## Gravel/grass up to here, then the barrier (metres from the asphalt edge).
const RUNOFF_WIDTH := 30.0

var id := ""
var name_key := ""
var width := 20.0
var length := 0.0
var points := PackedVector2Array()
## Distance along the lap at each point.
var distances := PackedFloat32Array()
## Unit driving direction at each point (smoothed over the neighbours).
var tangents := PackedVector2Array()
## Signed curvature (1/m) at each point: positive = right-hand corner.
var curvatures := PackedFloat32Array()
## Point indices of the sector 1/2 and 2/3 boundaries.
var sectors := PackedInt32Array()
## Where the pit lane leaves and rejoins the track, as a share of the lap (-1 = not set:
## PitLane then uses the straight around the line).
var pit_entry := -1.0
var pit_exit := -1.0
## The pit lane runs on the outside of the lap (no room inside, e.g. Brazil).
var pit_outside := false
## Look of the surroundings: STYLE_CIRCUIT (grass, gravel, woods) or STYLE_CITY_NIGHT (street
## circuit at night: buildings, walls, street lights - user 2026-11-24, Las Vegas).
var style := STYLE_CIRCUIT
## Real places near the track drawn by the scenery: name -> position (m), e.g. "sphere".
var landmarks: Dictionary[String, Vector2] = {}
## Bends gentler than this radius (m) still count as the main straight for the pit lane (0 = default).
var pit_straight_radius := 0.0
## Measured by tools/bp_offsets.gd: Vector2(distance of a BP, metres it may move later).
var bp_offsets: Array[Vector2] = []
## Racing line: lateral offset (right = +) at every centre-line point (zeros if missing).
var racing_line := PackedFloat32Array()


static func load_file(path: String) -> TrackData:
	var text := FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary:
		push_error("Track file is not valid JSON: " + path)
		return null
	return from_dictionary(data)


static func from_dictionary(data: Dictionary) -> TrackData:
	var track := TrackData.new()
	track.id = str(data.get("id", ""))
	track.name_key = str(data.get("name_key", ""))
	track.width = float(data.get("width", 20.0))
	for point: Variant in data.get("points", []):
		if point is Array and point.size() == 2:
			track.points.append(Vector2(float(point[0]), float(point[1])))
	track.pit_entry = float(data.get("pit_entry", -1.0))
	track.pit_exit = float(data.get("pit_exit", -1.0))
	track.pit_outside = bool(data.get("pit_outside", false))
	track.style = str(data.get("style", STYLE_CIRCUIT))
	if track.style not in [STYLE_CIRCUIT, STYLE_CITY_NIGHT]:
		track.style = STYLE_CIRCUIT
	var marks: Variant = data.get("landmarks", {})
	if marks is Dictionary:
		for name: Variant in marks:
			var at: Variant = marks[name]
			if at is Array and at.size() == 2:
				track.landmarks[str(name)] = Vector2(float(at[0]), float(at[1]))
	track.pit_straight_radius = float(data.get("pit_straight_radius", 0.0))
	for entry: Variant in data.get("bp_offsets", []):
		if entry is Array and entry.size() == 2:
			track.bp_offsets.append(Vector2(float(entry[0]), clampf(float(entry[1]), 0.0, 80.0)))
	for offset: Variant in data.get("racing_line", []):
		track.racing_line.append(float(offset))
	for sector: Variant in data.get("sectors", []):
		track.sectors.append(int(sector))
	if track.points.size() < 8:
		push_error("Track %s has too few points" % track.id)
		return null
	track._prepare()
	return track


func point_count() -> int:
	return points.size()


func half_width() -> float:
	return width * 0.5


func next_index(index: int) -> int:
	return (index + 1) % points.size()


## Unit vector to the right of the driving direction at a point.
func normal(index: int) -> Vector2:
	var t := tangents[index]
	return Vector2(-t.y, t.x)


## Position at a distance along the lap (wraps) with a lateral offset (right = positive).
func position_at(distance: float, lateral: float = 0.0) -> Vector2:
	var d := fposmod(distance, length)
	var index := _index_at(d)
	var a := points[index]
	var b := points[next_index(index)]
	var seg := distances[index + 1] - distances[index] if index + 1 < distances.size() else length - distances[index]
	var t := (d - distances[index]) / seg if seg > 0.0 else 0.0
	var dir := (b - a).normalized()
	return a.lerp(b, t) + Vector2(-dir.y, dir.x) * lateral


## Driving direction (angle) at a distance along the lap.
func heading_at(distance: float) -> float:
	var index := _index_at(fposmod(distance, length))
	return (points[next_index(index)] - points[index]).angle()


func _index_at(d: float) -> int:
	var low := 0
	var high := distances.size() - 1
	while low < high:
		var mid := (low + high + 1) / 2
		if distances[mid] <= d:
			low = mid
		else:
			high = mid - 1
	return low


func _prepare() -> void:
	var n := points.size()
	distances.resize(n)
	tangents.resize(n)
	curvatures.resize(n)
	var total := 0.0
	for i in n:
		distances[i] = total
		total += points[i].distance_to(points[(i + 1) % n])
	length = total
	for i in n:
		tangents[i] = (points[(i + 1) % n] - points[(i - 1 + n) % n]).normalized()
	curvatures = curvatures_of(points)
	if racing_line.size() != n:
		racing_line.resize(n)
		racing_line.fill(0.0)


## How much later than the ideal profile a BP near `distance` may stand (measured, 0 if none
## within 40 m: the same corner with worn tyres has its BP a little earlier).
func bp_offset_at(distance: float) -> float:
	for entry in bp_offsets:
		var apart := absf(entry.x - distance)
		if minf(apart, length - apart) < 40.0:
			return entry.y
	return 0.0


## Signed curvature of a closed polyline: the circle through points two steps either side
## (smooth, ~16 m chord with 4 m spacing); positive = right-hand corner.
static func curvatures_of(path: PackedVector2Array) -> PackedFloat32Array:
	var n := path.size()
	var result := PackedFloat32Array()
	result.resize(n)
	for i in n:
		var a := path[(i - 2 + n) % n]
		var b := path[i]
		var c := path[(i + 2) % n]
		var cross := (b - a).cross(c - a)
		var product := a.distance_to(b) * b.distance_to(c) * c.distance_to(a)
		result[i] = 2.0 * cross / product if product > 0.0 else 0.0
	return result
