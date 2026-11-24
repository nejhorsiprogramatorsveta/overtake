class_name Qualifying
extends RefCounted
## Qualifying before a race sets the grid by the best lap (user 2026-11-23, offline and online).
## The people drive alone (ghosts, no contact, KERS free) from behind the grid: an out lap, then
## RaceRules.quali_laps timed laps; a lap with a shortcut does not count. The bots do not drive:
## each gets lap times from its own speed profile (BotDriver.lap_estimate), shown when the bot
## would have set them. The session ends when every person has driven the timed laps (or left)
## or after quali_time. Offline and on the host this class decides; online clients get the best
## laps in the race info and the grid from the host (OnlineRace).

## One car of the session (index = entrant index: offline 0 = player, 1.. = bots; online = the
## index of the car in the race setup).
class Entrant:
	var name := ""
	var color := Color.WHITE
	## null = a bot.
	var racer: Racer
	## Best valid lap (s), -1 = none yet.
	var best := -1.0
	## Timed laps driven (valid or not).
	var timed_laps := 0
	## Bot: planned lap times and the session time each one appears.
	var plan_laps := PackedFloat64Array()
	var plan_shown := PackedFloat64Array()
	## Shortcut count of the racer at the start of the current and of the previous lap.
	var shortcuts_at_start := 0
	var shortcuts_before := 0

var rules: RaceRules
var entrants: Array[Entrant] = []
var finished := false
## Entrant indices in grid order, set by finish().
var grid: Array[int] = []
## False on online clients: the host's best laps come in apply_best().
var decides := true


func _init(race_rules: RaceRules) -> void:
	rules = race_rules


func add_human(racer: Racer) -> void:
	var entrant := Entrant.new()
	entrant.name = racer.name
	entrant.color = racer.color
	entrant.racer = racer
	entrants.append(entrant)
	racer.laps.line_crossed.connect(_on_line_crossed.bind(entrant))


## A bot with its estimated flying lap: out lap, then a slower first and a better second lap.
func add_bot(bot_name: String, color: Color, estimate: float, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var entrant := Entrant.new()
	entrant.name = bot_name
	entrant.color = color
	var shown := rng.randf_range(10.0, 30.0)
	for lap: float in [estimate + rng.randf_range(0.3, 1.2), estimate + rng.randf_range(0.0, 0.4)]:
		shown += lap
		entrant.plan_laps.append(lap)
		entrant.plan_shown.append(shown)
	entrants.append(entrant)


func entrant_of(racer: Racer) -> Entrant:
	for entrant in entrants:
		if entrant.racer == racer:
			return entrant
	return null


## A person finished a lap. Returns true if it counts (one of the timed laps, no shortcut).
func lap_completed(racer: Racer, lap_time: float) -> bool:
	var entrant := entrant_of(racer)
	if entrant == null or finished or entrant.timed_laps >= rules.quali_laps:
		return false
	entrant.timed_laps += 1
	if racer.shortcuts.count != entrant.shortcuts_before:
		return false
	if decides and (entrant.best < 0.0 or lap_time < entrant.best):
		entrant.best = lap_time
	return true


## Every tick: the bots' laps appear when their time has come.
func update(time: float) -> void:
	for entrant in entrants:
		if entrant.racer:
			continue
		for i in entrant.plan_laps.size():
			if (finished or time >= entrant.plan_shown[i]) and (entrant.best < 0.0 or entrant.plan_laps[i] < entrant.best):
				entrant.best = entrant.plan_laps[i]


## Offline / host: time is up, or every person still here has driven the timed laps.
func should_end(time: float) -> bool:
	if finished:
		return false
	if time >= rules.quali_time:
		return true
	for entrant in entrants:
		if entrant.racer and not entrant.racer.retired and entrant.timed_laps < rules.quali_laps:
			return false
	return true


func time_left(time: float) -> float:
	return maxf(rules.quali_time - time, 0.0)


## Entrant indices by best lap; without a time behind them, in entry order.
func order() -> Array[int]:
	var timed: Array[int] = []
	var untimed: Array[int] = []
	for i in entrants.size():
		if entrants[i].best >= 0.0:
			timed.append(i)
		else:
			untimed.append(i)
	timed.sort_custom(func(a: int, b: int) -> bool:
		return entrants[a].best < entrants[b].best or (entrants[a].best == entrants[b].best and a < b))
	timed.append_array(untimed)
	return timed


## Offline / host when the session ends: every bot shows all its laps, then the order.
func final_order() -> Array[int]:
	for entrant in entrants:
		if entrant.racer == null:
			for lap in entrant.plan_laps:
				entrant.best = lap if entrant.best < 0.0 else minf(entrant.best, lap)
	return order()


## The session is over: every bot shows all its laps, `final_grid` (entrant indices) is the grid.
func finish(final_grid: Array[int]) -> void:
	finished = true
	update(INF)
	grid = final_grid


## Online client: the best lap the host decided for a person.
func apply_best(racer: Racer, best: float) -> void:
	var entrant := entrant_of(racer)
	if entrant and not finished:
		entrant.best = best if best > 0.0 else -1.0


func _on_line_crossed(entrant: Entrant) -> void:
	entrant.shortcuts_before = entrant.shortcuts_at_start
	entrant.shortcuts_at_start = entrant.racer.shortcuts.count
