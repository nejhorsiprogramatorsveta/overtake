class_name RaceHudFeed
## Feeds the race HUD every frame from the RaceController (speed, KERS, laps and times, minimap,
## lights, position, standings, results, pit popup, tyres) and keeps the player's BP boards in
## step with the tyre grip (dynamic BP, PLAN.md B).

static var _bp_grip := 1.0


static func update(race: RaceController, delta: float) -> void:
	var hud := race.hud
	var me := race.me
	var player := race.player
	var laps := me.laps
	hud.show_speed(player.speed_kmh(), player.kers.is_active())
	hud.kers_gauge.show_state(player.kers.uses_left, race.tuning.kers_uses, player.kers.active_left / race.tuning.kers_duration, player.kers.locked)
	var racing := race.mode == RaceController.Mode.RACE
	var total := race.total_laps if racing else 0
	var status := ""
	if race.start and not race.start.lights_out():
		status = TranslationServer.translate("HUD_ON_GRID")
	elif me.finished:
		status = TranslationServer.translate("FINISH_TITLE")
	hud.show_laps(mini(laps.laps + 1, total) if total > 0 else laps.laps + 1, total,
			laps.current_lap_time(race.race_time), laps.last_lap, laps.best_lap, status)
	var positions := PackedVector2Array()
	var colors := PackedColorArray()
	for racer in race.racers:
		positions.append(racer.car.state.position)
		colors.append(racer.color)
		racer.car.set_ghost(racer.is_ghost(race.race_time))
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
	hud.pit_popup.show_stop(me.pit_stop)
	hud.kers_gauge.show_tyres(player.tyres.condition if player.tyres.enabled else -1.0)
	_update_braking_points(race)


## The player's BP boards follow the tyre grip in steps of 1 %.
static func _update_braking_points(race: RaceController) -> void:
	var grip := snappedf(race.player.tyres.grip_factor(), 0.01)
	if is_equal_approx(grip, _bp_grip) and race.bp_markers.points == race.braking_points:
		return
	_bp_grip = grip
	race.braking_points = BrakingPoints.find(race.track, race.racing_line.profile(race.tuning, grip), race.rules.bp_min_speed_drop, race.pit_lane)
	race.bp_markers.show_points(race.track, race.braking_points)
