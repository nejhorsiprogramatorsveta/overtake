class_name SpeedProfile
extends RefCounted
## The fastest possible speed at every centre-line point for a car (PLAN.md B):
## corner speed from the curvature and the grip, then a forward pass (acceleration) and a
## backward pass (braking). Used for the BP boards (M2), bots (M3) and to calibrate the track
## scale so a lap takes the target time. Driving the centre line is slower than a real racing
## line, so this is a conservative estimate.

const MAX_SPEED := 120.0

var speeds := PackedFloat32Array()
var lap_time := 0.0


static func compute(track: TrackData, tuning: CarTuning, grip_factor: float = 1.0) -> SpeedProfile:
	var profile := SpeedProfile.new()
	var n := track.point_count()
	var grip := tuning.grip * grip_factor
	var brake := minf(tuning.brake_decel, grip)
	var v := PackedFloat32Array()
	v.resize(n)
	for i in n:
		var k := absf(track.curvatures[i])
		v[i] = minf(sqrt(grip / k) if k > 1e-6 else MAX_SPEED, MAX_SPEED)
	# Two laps of each pass so the start/finish wrap converges.
	for _pass in 2:
		for raw in n * 2:
			var i := raw % n
			var j := (i + 1) % n
			var ds := track.points[i].distance_to(track.points[j])
			var accel := minf(tuning.traction, tuning.power / maxf(v[i], 1.0)) - tuning.drag * v[i] * v[i]
			v[j] = minf(v[j], sqrt(maxf(v[i] * v[i] + 2.0 * accel * ds, 0.0)))
		for raw in range(n * 2, 0, -1):
			var j := raw % n
			var i := (j - 1 + n) % n
			var ds := track.points[i].distance_to(track.points[j])
			var decel := brake + tuning.drag * v[j] * v[j]
			v[i] = minf(v[i], sqrt(v[j] * v[j] + 2.0 * decel * ds))
	var time := 0.0
	for i in n:
		var j := (i + 1) % n
		time += track.points[i].distance_to(track.points[j]) / maxf((v[i] + v[j]) * 0.5, 0.1)
	profile.speeds = v
	profile.lap_time = time
	return profile
