class_name RaceRanking
## Race order (PLAN.md B): finished cars by total time incl. penalties, then the others by
## distance raced (completed laps + distance into the current lap). Also the kind of a finished
## lap for the HUD colours.

enum LapKind { FASTEST, PERSONAL_BEST, SLOWER }


static func order(racers: Array[Racer], start: RaceStart) -> Array[Racer]:
	var sorted := racers.duplicate()
	sorted.sort_custom(func(a: Racer, b: Racer) -> bool: return _ahead(a, b, start))
	return sorted


## 1-based position of `racer`.
static func position_of(racer: Racer, racers: Array[Racer], start: RaceStart) -> int:
	return order(racers, start).find(racer) + 1


## A finished lap: the fastest of everybody so far, the driver's own best, or slower.
static func lap_kind(lap_time: float, racer: Racer, everyone: Array[Racer]) -> LapKind:
	var fastest := INF
	for other in everyone:
		if other.laps.best_lap > 0.0:
			fastest = minf(fastest, other.laps.best_lap)
	if lap_time <= fastest + 0.0005:
		return LapKind.FASTEST
	if lap_time <= racer.laps.best_lap + 0.0005:
		return LapKind.PERSONAL_BEST
	return LapKind.SLOWER


static func _ahead(a: Racer, b: Racer, start: RaceStart) -> bool:
	if a.retired != b.retired:
		return b.retired
	if a.finished != b.finished:
		return a.finished
	if a.finished:
		return a.total_time(start) < b.total_time(start)
	return a.progress() > b.progress()
