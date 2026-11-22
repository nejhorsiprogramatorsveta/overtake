extends TestCase
## TrackLimits: kerb counts as track, one excursion = one violation, 3 warnings then +5 s,
## cutting a corner = +5 s at once, running wide on the outside is not a shortcut.

var rules: RaceRules = load("res://data/race/race_rules.tres")
var track := TrackCatalog.get_track("austria")
const CAR_WIDTH := 1.9


## Drives along the lap from `from` to `to` at a lateral offset; returns the events seen.
func _drive(limits: TrackLimits, query: TrackQuery, from: float, to: float, lateral: float) -> Array[int]:
	var events: Array[int] = []
	var previous := track.position_at(from, lateral)
	var d := from
	while d < to:
		d += 1.0
		var position := track.position_at(d, lateral)
		query.update(track, position)
		var event := limits.update(track, query, CAR_WIDTH, position.distance_to(previous))
		previous = position
		if event != TrackLimits.Event.NONE:
			events.append(event)
	return events


func test_kerb_is_track_and_the_whole_car_must_be_out() -> void:
	var limits := TrackLimits.new(rules)
	var query := TrackQuery.new()
	var kerb_edge := track.half_width() + TrackData.KERB_WIDTH
	check(_drive(limits, query, 100.0, 300.0, kerb_edge).is_empty(), "car centre on the kerb edge: fine")
	check(_drive(limits, query, 300.0, 400.0, kerb_edge + CAR_WIDTH * 0.4).is_empty(), "half the car still over the kerb: fine")
	check_eq(_drive(limits, query, 400.0, 500.0, kerb_edge + CAR_WIDTH), [TrackLimits.Event.WARNING] as Array[int], "whole car out: one warning")


func test_three_warnings_then_penalties() -> void:
	var limits := TrackLimits.new(rules)
	var query := TrackQuery.new()
	var out := track.half_width() + TrackData.KERB_WIDTH + CAR_WIDTH
	var events: Array[int] = []
	var d := 100.0
	for excursion in 5:
		events.append_array(_drive(limits, query, d, d + 20.0, 0.0))
		events.append_array(_drive(limits, query, d + 20.0, d + 40.0, -out))
		d += 40.0
	var W := TrackLimits.Event.WARNING
	var P := TrackLimits.Event.PENALTY
	check_eq(events, [W, W, W, P, P] as Array[int], "warnings 1-3, then a penalty each time")
	check_eq(limits.violations, 5, "five violations")
	check_eq(limits.penalty, rules.track_limit_penalty * 2.0, "+5 s twice")


func test_cutting_a_corner_is_a_shortcut() -> void:
	# The sharpest corner: drive straight across its inside instead of around it.
	var sharpest := 0
	for i in track.point_count():
		if absf(track.curvatures[i]) > absf(track.curvatures[sharpest]):
			sharpest = i
	var corner := track.distances[sharpest]
	var a := track.position_at(corner - 70.0, 0.0)
	var b := track.position_at(corner + 70.0, 0.0)
	var limits := TrackLimits.new(rules)
	var query := TrackQuery.new()
	_drive(limits, query, corner - 120.0, corner - 70.0, 0.0)
	var events: Array[int] = []
	var steps := int(a.distance_to(b))
	var previous := a
	for step in steps + 1:
		var position := a.lerp(b, float(step) / steps)
		query.update(track, position)
		var event := limits.update(track, query, CAR_WIDTH, position.distance_to(previous))
		previous = position
		if event != TrackLimits.Event.NONE:
			events.append(event)
	check(events.has(TrackLimits.Event.SHORTCUT), "straight across the inside of the corner: shortcut %s" % [events])
	check(limits.penalty >= rules.shortcut_penalty, "shortcut costs +5 s")


func test_running_wide_is_only_a_violation() -> void:
	var limits := TrackLimits.new(rules)
	var query := TrackQuery.new()
	var sharpest := 0
	for i in track.point_count():
		if absf(track.curvatures[i]) > absf(track.curvatures[sharpest]):
			sharpest = i
	var outside := -signf(track.curvatures[sharpest]) * (track.half_width() + TrackData.KERB_WIDTH + 6.0)
	var corner := track.distances[sharpest]
	_drive(limits, query, corner - 120.0, corner - 60.0, 0.0)
	var events := _drive(limits, query, corner - 60.0, corner + 60.0, outside)
	check_eq(events, [TrackLimits.Event.WARNING] as Array[int], "running wide on the outside is no shortcut")
