class_name RaceInfo
## The race info the host decides and sends a few times per second (OnlineRace, RaceNet._info):
## one row of RaceNet.INFO_FIELDS values per car; clients apply it (clamped, PLAN.md S).

## [finished, race seconds, shortcut penalty, incident penalty, incidents, jump start, reaction,
##  pit stops, retired, ghost seconds left] per car (RaceNet.INFO_FIELDS). Qualifying: the race
## seconds are the best lap and the incidents the timed laps.
static func rows(race: RaceController) -> Array:
	var result := []
	if race.qualifying:
		for racer in race.racers:
			var entrant := race.qualifying.entrant_of(racer)
			result.append([false, entrant.best, racer.shortcuts.penalty, 0.0, entrant.timed_laps, false, -1.0,
					racer.pit_stop.stops, racer.retired, 0.0])
		return result
	var go := race.start.go_time if race.start else 0.0
	for racer in race.racers:
		result.append([racer.finished, racer.finish_time - go if racer.finished else -1.0, racer.shortcuts.penalty,
				racer.incident_penalty, racer.incidents, racer.start_entry.jump_start, racer.start_entry.reaction,
				racer.pit_stop.stops, racer.retired, maxf(racer.ghost_until - race.race_time, 0.0)])
	return result


static func apply(race: RaceController, rows: Array) -> void:
	if rows.size() != race.racers.size():
		return
	if race.qualifying:
		_apply_qualifying(race, rows)
		return
	var go := race.start.go_time if race.start else 0.0
	for i in rows.size():
		var row: Array = rows[i]
		var racer := race.racers[i]
		var was_finished := racer.finished
		racer.finished = bool(row[0])
		if racer.finished and not was_finished:
			racer.finish_time = float(row[1]) + go
			if racer.is_player:
				race.hud.show_message(TranslationServer.translate("FINISH_TITLE"), Color.WHITE, RaceController.RESULTS_DELAY)
		var shortcut_penalty := clampf(float(row[2]), 0.0, 999.0)
		if racer.is_player and shortcut_penalty > racer.shortcuts.penalty:
			race.hud.show_shortcut(race.rules, race.mode)
		racer.shortcuts.penalty = shortcut_penalty
		racer.incident_penalty = clampf(float(row[3]), 0.0, 999.0)
		racer.incidents = clampi(int(row[4]), 0, 999)
		racer.start_entry.jump_start = bool(row[5])
		if racer.remote:
			racer.start_entry.reaction = clampf(float(row[6]), -1.0, 10.0)
			racer.pit_stop.stops = clampi(int(row[7]), 0, 99)
		racer.retired = bool(row[8])
		racer.ghost_until = race.race_time + clampf(float(row[9]), 0.0, 30.0)


static func _apply_qualifying(race: RaceController, rows: Array) -> void:
	for i in rows.size():
		var row: Array = rows[i]
		var racer := race.racers[i]
		race.qualifying.apply_best(racer, clampf(float(row[1]), -1.0, 3600.0))
		var shortcut_penalty := clampf(float(row[2]), 0.0, 999.0)
		if racer.is_player and shortcut_penalty > racer.shortcuts.penalty:
			race.hud.show_shortcut(race.rules, race.mode)
		racer.shortcuts.penalty = shortcut_penalty
		racer.retired = bool(row[8])
