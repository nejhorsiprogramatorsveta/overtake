class_name LapTracker
extends RefCounted
## Counts laps and lap times of one car from its distance along the lap (TrackQuery).
## A lap only counts if the car passed both sector boundaries in order since the last
## crossing of the line (no reversing over the line, no skipping the lap). The crossing time
## is interpolated inside the tick, so lap times do not depend on the 60 Hz grid.

signal lap_completed(lap_time: float)
## Every forward crossing of the line (also the out lap): KERS refills here.
signal line_crossed

var track: TrackData
## Completed laps.
var laps := 0
## Sector boundary the car must pass next: 0, 1, then 2 = may finish the lap; -1 = the
## current lap is not valid (out lap or the car went backwards over the line).
var next_sector := -1
var lap_start_time := -1.0
var last_lap := -1.0
var best_lap := -1.0
## Time of the last valid line crossing (the finish time after the last lap).
var last_crossing := -1.0
var _last_distance := -1.0
## Standing start: the car crosses the line just after leaving the grid; that crossing
## must not restart lap 1, which is timed from the lights going out.
var _skip_grid_crossing := false


func _init(track_data: TrackData) -> void:
	track = track_data


## Call after every physics tick with the car's distance along the lap and the race time.
func update(distance: float, time: float, dt: float) -> void:
	if _last_distance < 0.0:
		_last_distance = distance
		return
	var previous := _last_distance
	_last_distance = distance
	var half := track.length * 0.5
	var moved := distance - previous
	if moved < -half:  # crossed the line forwards (distance wrapped to 0)
		var travelled := moved + track.length
		var fraction := (track.length - previous) / travelled if travelled > 0.0 else 1.0
		_cross_line(time - dt + dt * fraction)
		return
	if moved > half:  # crossed the line backwards
		next_sector = -1
		return
	if next_sector >= 0 and next_sector < track.sectors.size():
		var boundary := track.distances[track.sectors[next_sector]]
		if previous < boundary and distance >= boundary:
			next_sector += 1


## Standing start from the grid behind the line: lap 1 runs from the lights going out.
func start_from_grid(go_time: float) -> void:
	lap_start_time = go_time
	next_sector = 0
	_skip_grid_crossing = true


## Running time of the current lap (seconds), or -1 before the first crossing.
func current_lap_time(time: float) -> float:
	return time - lap_start_time if lap_start_time >= 0.0 else -1.0


func _cross_line(cross_time: float) -> void:
	line_crossed.emit()
	if _skip_grid_crossing:
		_skip_grid_crossing = false
		return
	if next_sector >= track.sectors.size() and lap_start_time >= 0.0:
		laps += 1
		last_lap = cross_time - lap_start_time
		if best_lap < 0.0 or last_lap < best_lap:
			best_lap = last_lap
		last_crossing = cross_time
		lap_completed.emit(last_lap)
	lap_start_time = cross_time
	next_sector = 0
