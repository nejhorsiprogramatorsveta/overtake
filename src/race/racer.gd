class_name Racer
extends RefCounted
## Everything the race keeps about one driver: the car and its lap counter, shortcut check,
## start entry and pit stop, plus the result. The player and (M3) every bot are Racers.

var name := ""
var color := Color.WHITE
var is_player := false
var car: Car
var laps: LapTracker
var shortcuts: ShortcutCheck
var pit_stop: PitStop
var start_entry := RaceStart.Entry.new()
## Computer driver, null for a human.
var bot: BotDriver
## Online: the car is driven by the network (another player, or a bot on a client).
var remote := false
## Online: the remote car is in the pit lane (ghost), from its owner's state.
var net_in_pit := false
## Online: the player left the race (car stops, ghost, ranked last).
var retired := false
var finished := false
## Race clock when crossing the finish line, -1 while racing.
var finish_time := -1.0
## Seconds of penalties for causing collisions, and how many.
var incident_penalty := 0.0
var incidents := 0
## No contact with other cars until this race time (start, repeated ramming).
var ghost_until := -1.0
## Race clock when this car first reached each PROGRESS_STEP metres of race distance (gaps).
var progress_times := PackedFloat64Array()

const PROGRESS_STEP := 10.0


func _init(racer_name: String, racer_color: Color, player: bool) -> void:
	name = racer_name
	color = racer_color
	is_player = player


## Seconds added to the race time (jump start + shortcuts + collisions).
func penalty(start: RaceStart) -> float:
	return (start.penalty(start_entry) if start else 0.0) + shortcuts.penalty + incident_penalty


## True if the car must not touch others now (pit lane, start, ghost penalty, cool-down lap
## after the flag).
func is_ghost(time: float) -> bool:
	return finished or retired or pit_stop.active() or net_in_pit or time < ghost_until


## Race time incl. penalties once finished, else -1.
func total_time(start: RaceStart) -> float:
	if not finished or retired or start == null:
		return -1.0
	return finish_time - start.go_time + penalty(start)


## Metres raced so far (laps and distance), for the live order.
func progress() -> float:
	return laps.progress(car.query.distance)


## Call every tick: remembers when each PROGRESS_STEP of race distance was first reached.
func record_progress(time: float) -> void:
	var reached := int(progress() / PROGRESS_STEP)
	while progress_times.size() <= reached and reached >= 0:
		progress_times.append(time)


## Seconds behind `leader` (time since the leader was where this car is now), or -1 if unknown.
func gap_to(leader: Racer, time: float) -> float:
	if leader == self:
		return 0.0
	var index := int(progress() / PROGRESS_STEP)
	if index < 0 or index >= leader.progress_times.size():
		return -1.0
	return time - leader.progress_times[index]
