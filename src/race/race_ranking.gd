class_name RaceRanking
## Race order (PLAN.md B): finished cars by total time incl. penalties, then the others by
## distance raced (completed laps + distance into the current lap).


static func order(racers: Array[Racer], start: RaceStart) -> Array[Racer]:
	var sorted := racers.duplicate()
	sorted.sort_custom(func(a: Racer, b: Racer) -> bool: return _ahead(a, b, start))
	return sorted


## 1-based position of `racer`.
static func position_of(racer: Racer, racers: Array[Racer], start: RaceStart) -> int:
	return order(racers, start).find(racer) + 1


static func _ahead(a: Racer, b: Racer, start: RaceStart) -> bool:
	if a.finished != b.finished:
		return a.finished
	if a.finished:
		return a.total_time(start) < b.total_time(start)
	return a.progress() > b.progress()
