class_name TrackSurface
extends RefCounted
## The asphalt of a track (M3G, PLAN.md B): fine shading from noise, the dark rubbered-in racing
## line (stronger where the cars brake and turn) and skid marks in the braking zones and out of
## the slow corners. Built into one mesh by TrackView.

const ASPHALT := Color(0.29, 0.3, 0.33)
const RUBBER := Color(0.15, 0.15, 0.17)
const SKID := Color(0.08, 0.08, 0.09)
## Lateral spacing of the asphalt vertices (m): fine enough for a smooth rubber band.
const STRIP := 0.6
## Half width (m) of the rubber band around the racing line.
const RUBBER_WIDTH := 2.1
## How far ahead (points) a corner already darkens the line (braking zone).
const BRAKING_POINTS := 14
## Corners of the racing line sharper than this radius (m) get skid marks.
const SKID_RADIUS := 70.0
## Lateral distance of the two wheels of a skid mark from its centre (m).
const WHEEL_OFFSET := 0.8


static func build(track: TrackData, noise: FastNoiseLite) -> MeshBuilder:
	var builder := MeshBuilder.new()
	var n := track.point_count()
	var line := RacingLine.for_track(track)
	var wear := _wear(line, n)
	var hw := track.half_width() + 0.2
	var strips := ceili(hw * 2.0 / STRIP)
	var previous := PackedColorArray()
	var previous_points := PackedVector2Array()
	for i in n + 1:
		var index := i % n
		var colors := PackedColorArray()
		var points := PackedVector2Array()
		for s in strips + 1:
			var lateral := -hw + hw * 2.0 * s / strips
			var p := MeshBuilder.offset(track, index, lateral)
			points.append(p)
			var shade := noise.get_noise_2d(p.x * 3.0, p.y * 3.0) * 0.05 + noise.get_noise_2d(p.x * 20.0, p.y * 20.0) * 0.035
			var color := TrackView._shaded(ASPHALT, shade)
			var d := (lateral - track.racing_line[index]) / RUBBER_WIDTH
			var rubber := exp(-d * d) * wear[index] + 0.12 * exp(-d * d * 0.15)
			colors.append(color.lerp(RUBBER, clampf(rubber, 0.0, 1.0)))
		if i > 0:
			for s in strips:
				builder.quad_colors(previous_points[s], previous_points[s + 1], points[s + 1], points[s],
						previous[s], previous[s + 1], colors[s + 1], colors[s])
		previous = colors
		previous_points = points
	_skid_marks(builder, track, line)
	return builder


## How dark the line is at each point (0.25 on straights, up to 0.8 before and in corners).
static func _wear(line: RacingLine, n: int) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	result.resize(n)
	for i in n:
		var sharpest := 0.0
		for k in range(-3, BRAKING_POINTS):
			sharpest = maxf(sharpest, absf(line.curvatures[(i + k + n) % n]))
		result[i] = lerpf(0.25, 0.8, clampf(sharpest * 40.0, 0.0, 1.0))
	return result


## Dark tyre streaks: several pairs before every sharp corner (braking) and a few after the
## slowest ones (wheelspin), following the racing line with some spread.
static func _skid_marks(builder: MeshBuilder, track: TrackData, line: RacingLine) -> void:
	var n := track.point_count()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(track.id + "skids")
	for apex in _apexes(line):
		var sharpness := clampf(absf(line.curvatures[apex]) * SKID_RADIUS, 1.0, 3.0)
		var zone := int(8 + 10 * sharpness)
		for mark in int(3 + 3 * sharpness):
			var start := apex - rng.randi_range(4, zone)
			_streak(builder, track, start, rng.randi_range(3, 9), rng.randf_range(-1.4, 1.4), rng.randf_range(0.2, 0.45))
		if sharpness > 1.6:
			for mark in 3:
				var start := apex + rng.randi_range(0, 4)
				_streak(builder, track, start, rng.randi_range(4, 8), rng.randf_range(-1.0, 1.0), rng.randf_range(0.2, 0.4))


## Points where the racing line is sharpest within ±20 points and tighter than SKID_RADIUS.
static func _apexes(line: RacingLine) -> PackedInt32Array:
	var n := line.points.size()
	var result := PackedInt32Array()
	for i in n:
		var k := absf(line.curvatures[i])
		if k < 1.0 / SKID_RADIUS:
			continue
		var is_max := true
		for d in range(-20, 21):
			if d != 0 and absf(line.curvatures[(i + d + n) % n]) > k:
				is_max = false
				break
		if is_max:
			result.append(i)
	return result


## One pair of streaks from point `start` over `count` points, fading in and out.
static func _streak(builder: MeshBuilder, track: TrackData, start: int, count: int, spread: float, alpha: float) -> void:
	var n := track.point_count()
	for k in count:
		var i := posmod(start + k, n)
		var j := (i + 1) % n
		var fade_a := alpha * sin(PI * float(k) / count)
		var fade_b := alpha * sin(PI * float(k + 1) / count)
		var ca := Color(SKID, fade_a)
		var cb := Color(SKID, fade_b)
		for wheel: float in [-WHEEL_OFFSET, WHEEL_OFFSET]:
			var la := track.racing_line[i] + spread + wheel
			var lb := track.racing_line[j] + spread + wheel
			builder.quad_colors(MeshBuilder.offset(track, i, la - 0.14), MeshBuilder.offset(track, i, la + 0.14),
					MeshBuilder.offset(track, j, lb + 0.14), MeshBuilder.offset(track, j, lb - 0.14), ca, ca, cb, cb)
