extends TestCase
## ShortcutCheck: no track limits (user 2026-11-22) - leaving the track is never penalised by
## itself; cutting a corner = +5 s at once; running wide on the outside is no shortcut.

var rules: RaceRules = load("res://data/race/race_rules.tres")
var track := TrackCatalog.get_track("austria")
const CAR_WIDTH := 1.9


## Drives along the lap from `from` to `to` at a lateral offset; returns how many penalties came.
func _drive(check_: ShortcutCheck, query: TrackQuery, from: float, to: float, lateral: float) -> int:
	var penalties := 0
	var previous := track.position_at(from, lateral)
	var d := from
	while d < to:
		d += 1.0
		var position := track.position_at(d, lateral)
		query.update(track, position)
		if check_.update(track, query, CAR_WIDTH, position.distance_to(previous)):
			penalties += 1
		previous = position
	return penalties


func _sharpest() -> int:
	var sharpest := 0
	for i in track.point_count():
		if absf(track.curvatures[i]) > absf(track.curvatures[sharpest]):
			sharpest = i
	return sharpest


func test_leaving_the_track_is_not_penalised() -> void:
	var shortcut := ShortcutCheck.new(rules)
	var query := TrackQuery.new()
	var out := track.half_width() + TrackData.KERB_WIDTH + CAR_WIDTH
	var d := 100.0
	for excursion in 5:
		_drive(shortcut, query, d, d + 20.0, 0.0)
		check_eq(_drive(shortcut, query, d + 20.0, d + 40.0, -out), 0, "excursion %d: no penalty" % (excursion + 1))
		d += 40.0
	check_eq(shortcut.penalty, 0.0, "no time added")


func test_cutting_a_corner_is_a_shortcut() -> void:
	# The sharpest corner: drive straight across its inside instead of around it.
	var corner := track.distances[_sharpest()]
	var a := track.position_at(corner - 70.0, 0.0)
	var b := track.position_at(corner + 70.0, 0.0)
	var shortcut := ShortcutCheck.new(rules)
	var query := TrackQuery.new()
	_drive(shortcut, query, corner - 120.0, corner - 70.0, 0.0)
	var penalties := 0
	var steps := int(a.distance_to(b))
	var previous := a
	for step in steps + 1:
		var position := a.lerp(b, float(step) / steps)
		query.update(track, position)
		if shortcut.update(track, query, CAR_WIDTH, position.distance_to(previous)):
			penalties += 1
		previous = position
	check_eq(penalties, 1, "straight across the inside of the corner: one shortcut")
	check_eq(shortcut.penalty, rules.shortcut_penalty, "shortcut costs +5 s")


func test_running_wide_is_no_shortcut() -> void:
	var shortcut := ShortcutCheck.new(rules)
	var query := TrackQuery.new()
	var sharpest := _sharpest()
	var outside := -signf(track.curvatures[sharpest]) * (track.half_width() + TrackData.KERB_WIDTH + 6.0)
	var corner := track.distances[sharpest]
	_drive(shortcut, query, corner - 120.0, corner - 60.0, 0.0)
	check_eq(_drive(shortcut, query, corner - 60.0, corner + 60.0, outside), 0, "running wide on the outside is no shortcut")
