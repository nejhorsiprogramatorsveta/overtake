class_name Racer
extends RefCounted
## Everything the race keeps about one driver: the car and its lap counter, track limits,
## start entry and pit stop, plus the result. The player and (M3) every bot are Racers.

var name := ""
var color := Color.WHITE
var is_player := false
var car: Car
var laps: LapTracker
var limits: TrackLimits
var pit_stop: PitStop
var start_entry := RaceStart.Entry.new()
## Computer driver, null for a human.
var bot: BotDriver
var finished := false
## Race clock when crossing the finish line, -1 while racing.
var finish_time := -1.0


func _init(racer_name: String, racer_color: Color, player: bool) -> void:
	name = racer_name
	color = racer_color
	is_player = player


## Seconds added to the race time (jump start + track limits).
func penalty(start: RaceStart) -> float:
	return (start.penalty(start_entry) if start else 0.0) + limits.penalty


## Race time incl. penalties once finished, else -1.
func total_time(start: RaceStart) -> float:
	if not finished or start == null:
		return -1.0
	return finish_time - start.go_time + penalty(start)


## Metres raced so far (laps and distance), for the live order.
func progress() -> float:
	return laps.progress(car.query.distance)
