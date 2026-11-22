extends TestCase
## LapTracker: valid laps, interpolated lap times, no laps from reversing or skipping.

const DT := 1.0 / 60.0


## Drives forward until `to`; returns Vector2(time, distance) where it stopped.
func _drive(laps: LapTracker, from: float, to: float, speed: float, start_time: float) -> Vector2:
	var time := start_time
	var distance := from
	while distance < to:
		distance += speed * DT
		time += DT
		laps.update(fposmod(distance, laps.track.length), time, DT)
	return Vector2(time, distance)


func test_out_lap_then_timed_laps() -> void:
	var track := TrackCatalog.get_track("austria")
	var laps := LapTracker.new(track)
	var start := track.length - 40.0
	laps.update(start, 0.0, DT)
	var at := _drive(laps, start, track.length + 1.0, 50.0, 0.0)
	check_eq(laps.laps, 0, "crossing the line after the out lap starts lap 1")
	check(absf(laps.lap_start_time - 0.8) < 0.001, "lap start is interpolated inside the tick (got %.4f)" % laps.lap_start_time)
	_drive(laps, at.y, track.length * 2.0 + 1.0, 50.0, at.x)
	check_eq(laps.laps, 1, "one full lap counts")
	check(absf(laps.last_lap - track.length / 50.0) < 0.002, "lap time = length / speed (got %.4f)" % laps.last_lap)
	check_eq(laps.best_lap, laps.last_lap, "best lap recorded")


func test_reversing_over_the_line_invalidates_the_lap() -> void:
	var track := TrackCatalog.get_track("austria")
	var laps := LapTracker.new(track)
	laps.update(track.length - 10.0, 0.0, DT)
	var time := _drive(laps, track.length - 10.0, track.length + 30.0, 40.0, 0.0).x
	# Back over the line, then forwards again.
	laps.update(track.length - 5.0, time + DT, DT)
	_drive(laps, track.length - 5.0, track.length + 20.0, 40.0, time + DT)
	check_eq(laps.laps, 0, "no lap from going back and forth over the line")


func test_skipping_most_of_the_lap_does_not_count() -> void:
	var track := TrackCatalog.get_track("austria")
	var laps := LapTracker.new(track)
	laps.update(track.length - 10.0, 0.0, DT)
	var time := _drive(laps, track.length - 10.0, track.length + 100.0, 40.0, 0.0).x
	laps.update(track.length - 30.0, time + DT, DT)  # teleport/shortcut to just before the line
	_drive(laps, track.length - 30.0, track.length + 10.0, 40.0, time + DT)
	check_eq(laps.laps, 0, "a lap without both sectors is not counted")


func test_standing_start_times_lap_one_from_lights_out() -> void:
	var track := TrackCatalog.get_track("austria")
	var laps := LapTracker.new(track)
	laps.start_from_grid(5.0)
	laps.update(track.length - 10.0, 5.0, DT)
	var at := _drive(laps, track.length - 10.0, track.length + 5.0, 20.0, 5.0)
	check_eq(laps.lap_start_time, 5.0, "leaving the grid over the line does not restart lap 1")
	_drive(laps, at.y, track.length * 2.0 + 5.0, 50.0, at.x)
	check_eq(laps.laps, 1, "lap 1 completed")
	check(laps.last_lap > track.length / 50.0, "lap 1 includes the run from the grid")
	check(absf(laps.last_crossing - (5.0 + laps.last_lap)) < 0.0001, "finish time recorded")


func test_format_time() -> void:
	check_eq(RaceHud.format_time(65.4321), "1:05.432", "minutes, seconds, milliseconds")
	check_eq(RaceHud.format_time(-1.0), "–", "no time yet")
