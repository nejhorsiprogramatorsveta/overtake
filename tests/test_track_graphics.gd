extends TestCase
## Track graphics (M3G): keep-out map, gravel zones without thin gaps, scenery never on the track
## or the pit lane, rubber darker before corners, and the meshes stay small.

var track := TrackCatalog.get_track("austria")
var rules: RaceRules = load("res://data/race/race_rules.tres")


func test_keep_out_map_blocks_circles() -> void:
	var map := KeepOutMap.new(Rect2(0, 0, 200, 200))
	map.block_circle(Vector2(100, 100), 20.0)
	check(not map.is_clear(Vector2(100, 100)), "centre blocked")
	check(not map.is_clear(Vector2(118, 100)), "inside the radius blocked")
	check(map.is_clear(Vector2(150, 100)), "far away free")
	check(not map.is_clear(Vector2(135, 100), 12.0), "a big object reaching into the circle is refused")
	check(not map.is_clear(Vector2(-5, 50)), "outside the map counts as blocked")


func test_gravel_zones_have_no_thin_gaps() -> void:
	var mask := TrackView.corner_mask(track)
	var n := mask.size()
	var has_corner := false
	for i in n:
		has_corner = has_corner or mask[i]
		if mask[i] and not mask[(i + 1) % n]:
			var gap := 1
			while not mask[(i + 1 + gap) % n] and gap < n:
				gap += 1
			check(gap > TrackView.GRAVEL_GAP_POINTS, "gap after point %d is %d points" % [i, gap])
	check(has_corner, "the track has corner zones")


func test_scenery_stays_off_the_track_and_the_pit_lane() -> void:
	var lane := PitLane.build(track, rules)
	var scenery := TrackScenery.new()
	scenery.setup(track, lane)
	var wall := track.half_width() + TrackData.RUNOFF_WIDTH
	check(scenery.trees.size() > 200, "woods were planted (%d trees)" % scenery.trees.size())
	check(scenery.stands.size() >= 3, "grandstands placed (%d)" % scenery.stands.size())
	var worst_track := INF
	for p in scenery.trees:
		for q in track.points:
			worst_track = minf(worst_track, p.distance_to(q))
	check(worst_track > wall + 2.0, "trees stand behind the barrier (closest %.1f m)" % worst_track)
	var worst_lane := INF
	for p in scenery.trees:
		for q in lane.points:
			worst_lane = minf(worst_lane, p.distance_to(q))
	check(worst_lane > TrackScenery.LANE_CLEARANCE, "no tree on the pit lane (closest %.1f m)" % worst_lane)
	for centre in scenery.stands:
		var closest := INF
		for q in track.points:
			closest = minf(closest, centre.distance_to(q))
		check(closest > wall + TrackScenery.STAND_DEPTH * 0.5, "stand behind the barrier (%.1f m)" % closest)
	check(scenery.triangle_count() < 250000, "scenery mesh is small (%d triangles)" % scenery.triangle_count())
	scenery.free()


func test_rubber_is_darker_before_corners_than_on_straights() -> void:
	var line := RacingLine.for_track(track)
	var wear := TrackSurface._wear(line, track.point_count())
	var apex: int = TrackSurface._apexes(line)[0]
	check(wear[apex - 5] > 0.6, "braking zone well rubbered (%.2f)" % wear[apex - 5])
	var straightest := 0
	for i in track.point_count():
		if absf(line.curvatures[i]) < absf(line.curvatures[straightest]):
			straightest = i
	check(wear[apex - 5] > wear[straightest] + 0.2, "straights lighter than braking zones")


func test_ground_mesh_is_small() -> void:
	var view := TrackView.new()
	var grid: Array[Vector2] = [Vector2(track.length - 10.0, -4.5)]
	view.setup(track, grid)
	check(view.triangle_count() > 1000 and view.triangle_count() < 300000, "ground mesh %d triangles" % view.triangle_count())
	view.free()
