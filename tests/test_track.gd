extends TestCase
## TrackData (loading the generated files), TrackQuery and SpeedProfile on the real tracks.

var tuning: CarTuning = load("res://data/car/car_tuning.tres")


func test_every_catalog_track_loads_as_a_wide_closed_loop() -> void:
	for id in TrackCatalog.ids():
		var track := TrackCatalog.get_track(id)
		check(track != null, id + " loads")
		if track == null:
			continue
		check(track.width >= 18.0, id + " is wide (overtaking)")
		check(track.length > 2000.0 and track.length < 4000.0, id + " has a sensible length: %.0f" % track.length)
		check(track.points[0].distance_to(track.points[track.point_count() - 1]) < 6.0, id + " is closed")
		check(track.sectors.size() == 2 and track.sectors[0] < track.sectors[1], id + " has two ordered sector lines")
		check(not tr(track.name_key).is_empty() and tr(track.name_key) != track.name_key, id + " has a Czech name")
		check_eq(track.name_key, TrackCatalog.NAME_KEYS[id], id + " name key matches the catalog")


func test_query_finds_distance_and_side() -> void:
	var track := TrackCatalog.get_track("austria")
	var query := TrackQuery.new()
	for distance: float in [10.0, 700.0, 1500.0, track.length - 5.0]:
		for lateral: float in [-6.0, 0.0, 6.0]:
			query.index = -1
			query.update(track, track.position_at(distance, lateral))
			var diff := absf(query.distance - distance)
			check(minf(diff, track.length - diff) < 1.0, "distance %.0f found (got %.1f)" % [distance, query.distance])
			check(absf(query.lateral - lateral) < 0.5, "lateral %.0f found (got %.2f)" % [lateral, query.lateral])


func test_surfaces_kerb_gravel_and_barrier() -> void:
	var track := TrackCatalog.get_track("austria")
	var query := TrackQuery.new()
	var cases := [[0.0, TrackQuery.Surface.TRACK], [track.half_width() + 1.0, TrackQuery.Surface.TRACK],
			[-(track.half_width() + 10.0), TrackQuery.Surface.RUNOFF], [track.half_width() + TrackData.RUNOFF_WIDTH + 3.0, TrackQuery.Surface.BARRIER]]
	for case: Array in cases:
		query.index = -1
		query.update(track, track.position_at(300.0, case[0]))
		check_eq(query.surface, case[1], "surface at lateral %.1f" % case[0])


func test_query_follows_the_lap_with_a_hint() -> void:
	var track := TrackCatalog.get_track("austria")
	var query := TrackQuery.new()
	var distance := 0.0
	var ok := true
	while distance < track.length * 2.0:
		query.update(track, track.position_at(distance, 3.0))
		var diff := absf(query.distance - fposmod(distance, track.length))
		if minf(diff, track.length - diff) > 1.0:  # 0 and the lap length are the same place
			ok = false
			break
		distance += 1.4  # 300 km/h at 60 Hz
	check(ok, "the hinted search never jumps to another part of the lap (stopped at %.0f)" % distance)


func test_speed_profile_brakes_before_corners() -> void:
	var track := TrackCatalog.get_track("austria")
	var profile := SpeedProfile.compute(track, tuning)
	check(profile.lap_time > 40.0 and profile.lap_time < 60.0, "centre-line lap 40-60 s (got %.1f)" % profile.lap_time)
	var n := track.point_count()
	var braking_points := 0
	for i in n:
		var j := (i + 1) % n
		var v0 := profile.speeds[i]
		var v1 := profile.speeds[j]
		if v1 < v0:
			braking_points += 1
			var ds := track.points[i].distance_to(track.points[j])
			check(v0 * v0 - v1 * v1 <= 2.0 * (tuning.brake_decel + tuning.drag * v1 * v1) * ds + 0.5, "braking stays within the brakes at %d" % i)
	check(braking_points > 20, "there are braking zones")
	var worn := SpeedProfile.compute(track, tuning, 0.85)
	check(worn.lap_time > profile.lap_time, "less grip (worn tyres) is slower")
