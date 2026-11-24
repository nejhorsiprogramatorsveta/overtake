class_name RaceHudFeed
## Feeds the race HUD every frame from the RaceController (speed, KERS, laps and times, minimap,
## lights, position, standings, results, pit popup, tyres; in qualifying the session clock and the
## best laps) and keeps the player's BP boards in step with the tyre grip (dynamic BP, PLAN.md B).

static var _bp_grip := 1.0


static func update(race: RaceController, delta: float) -> void:
	var hud := race.hud
	var me := race.me
	var player := race.player
	var laps := me.laps
	hud.show_speed(player.speed_kmh())
	hud.revs.update(player.speed_kmh(), Input.is_action_pressed(&"throttle"), me.start_entry.held and race.start != null, delta)
	hud.speed_gauge.show_revs(hud.revs.share(), hud.revs.gear)
	hud.kers_gauge.show_state(player.kers.uses_left, race.tuning.kers_uses, player.kers.active_left / race.tuning.kers_duration, player.kers.locked)
	var racing := race.mode == RaceController.Mode.RACE
	var quali := race.qualifying
	var total := race.total_laps if racing else (race.rules.quali_laps if quali else 0)
	var status := ""
	if race.start and not race.start.lights_out():
		status = TranslationServer.translate("HUD_ON_GRID")
	elif me.finished:
		status = TranslationServer.translate("FINISH_TITLE")
	elif quali:
		status = _quali_status(race)
	hud.show_laps(mini(laps.laps + 1, total) if total > 0 else laps.laps + 1, total,
			laps.current_lap_time(race.race_time), laps.last_lap, laps.best_lap, status)
	var positions := PackedVector2Array()
	var colors := PackedColorArray()
	for racer in race.racers:
		positions.append(racer.car.state.position)
		colors.append(racer.color)
		racer.car.set_ghost(racer.is_ghost(race.race_time) and not (quali and racer == me))  # alone in qualifying
	hud.minimap.show_cars(positions, colors)
	if race.start:
		hud.start_lights.show_start(race.start, me.start_entry, race.race_time)
	if racing:
		hud.show_penalty(me.penalty(race.start))
		var order := RaceRanking.order(race.racers, race.start)
		hud.show_position(order.find(me) + 1, race.racers.size())
		hud.standings.show_order(order, race.start, race.race_time, race.track.length, delta)
		if me.finished and race.race_time - me.finish_time >= RaceController.RESULTS_DELAY:
			hud.results.show_results(order, race.start, race.track)
	if quali:
		_show_qualifying(race, delta)
	hud.pit_popup.show_stop(me.pit_stop)
	hud.kers_gauge.show_tyres(player.tyres.condition if player.tyres.enabled else -1.0)
	_update_braking_points(race)


static func _quali_status(race: RaceController) -> String:
	var quali := race.qualifying
	if quali.finished:
		return TranslationServer.translate("QUALI_OVER")
	if race.online and not race.online.lights_started:
		return TranslationServer.translate("QUALI_WAITING")
	if quali.entrant_of(race.me).timed_laps >= race.rules.quali_laps:
		return TranslationServer.translate("QUALI_DONE")
	return ""


## Qualifying: position by best lap, time left, every car with its best lap.
static func _show_qualifying(race: RaceController, delta: float) -> void:
	var quali := race.qualifying
	var order := quali.grid if quali.finished else quali.order()
	var mine := quali.entrants.find(quali.entrant_of(race.me))
	race.hud.show_position(order.find(mine) + 1, order.size())
	race.hud.show_clock(quali.time_left(race.race_time) if not quali.finished else 0.0)
	var rows := []
	for index in order:
		var entrant := quali.entrants[index]
		rows.append([entrant.name, entrant.color, index == mine, RaceHud.format_time(entrant.best)])
	race.hud.standings.show_rows(rows, delta)


## The player's BP boards follow the tyre grip in steps of 1 %.
static func _update_braking_points(race: RaceController) -> void:
	var grip := snappedf(race.player.tyres.grip_factor(), 0.01)
	if is_equal_approx(grip, _bp_grip) and race.bp_markers.points == race.braking_points:
		return
	_bp_grip = grip
	race.braking_points = BrakingPoints.find(race.track, race.racing_line.profile(race.tuning, grip), race.rules.bp_min_speed_drop, race.pit_lane)
	race.bp_markers.show_points(race.track, race.braking_points)
