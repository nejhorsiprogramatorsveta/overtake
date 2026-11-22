class_name RacingLine
extends RefCounted
## The racing line of a track (made by tools/tracks/build_track.py: minimum curvature within
## the track edges - outside, apex, outside). One point per centre-line point, so the track
## index of a car is also its racing-line index. Speed profiles along it (fresh and worn tyres)
## drive the BP boards and the bots, and later the rubbered-in line on the asphalt (M3G).

const PROFILE_STEP := 0.02

var track: TrackData
var points := PackedVector2Array()
var curvatures := PackedFloat32Array()
var _profiles: Dictionary = {}

static var _cache: Dictionary = {}


static func for_track(track_data: TrackData) -> RacingLine:
	if not _cache.has(track_data.id):
		var line := RacingLine.new()
		line.track = track_data
		for i in track_data.point_count():
			line.points.append(track_data.points[i] + track_data.normal(i) * track_data.racing_line[i])
		line.curvatures = TrackData.curvatures_of(line.points)
		_cache[track_data.id] = line
	return _cache[track_data.id]


func lateral(index: int) -> float:
	return track.racing_line[posmod(index, track.point_count())]


## Speed profile along the line for a grip factor (cached in 2 % steps). corner_factor < 1
## plans slower corners with the same braking (slower bots, see BotDriver).
func profile(tuning: CarTuning, grip_factor: float = 1.0, corner_factor: float = 1.0) -> SpeedProfile:
	var grip := snappedf(grip_factor, PROFILE_STEP)
	var corner := snappedf(corner_factor, PROFILE_STEP * 0.5)
	var key := Vector2(grip, corner)
	if not _profiles.has(key):
		_profiles[key] = SpeedProfile.compute_path(points, curvatures, tuning, grip, corner)
	return _profiles[key]
