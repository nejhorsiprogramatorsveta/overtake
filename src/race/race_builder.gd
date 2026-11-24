class_name RaceBuilder
## Builds the race scene for RaceController: the track scenery, the pit lane and the BP boards,
## the cars (Racer) and the offline field. In qualifying only the people drive; the bots are
## entered with estimated lap times (Qualifying). After qualifying the grid follows its result.

## The practice car starts this far before the line, so the first crossing starts lap 1.
const START_BEHIND_LINE := 40.0
## Painted grid boxes (the most cars in a race).
const GRID_SLOTS := LobbyValidator.MAX_CARS
## In qualifying nobody touches anybody.
const ALWAYS := 1.0e12


static func scenery(race: RaceController) -> void:
	var track := race.track
	var track_view := TrackView.new()
	race.add_child(track_view)
	var grid: Array[Vector2] = []
	for slot in GRID_SLOTS:
		grid.append(RaceStart.grid_slot(track, race.rules, slot))
	track_view.setup(track, grid)
	race.pit_lane = PitLane.build(track, race.rules)
	race.pit_view = PitLaneView.new()
	race.add_child(race.pit_view)
	var track_scenery := TrackScenery.for_track(track)
	race.add_child(track_scenery)
	track_scenery.setup(track, race.pit_lane)
	if track.style == TrackData.STYLE_CITY_NIGHT:
		var night := CanvasModulate.new()  # darkens the world, not the HUD (own canvas layer)
		night.color = CityScenery.NIGHT
		race.add_child(night)
	race.add_child(race.skid_marks)
	race.add_child(race.tyre_smoke)
	race.racing_line = RacingLine.for_track(track)
	race.braking_points = BrakingPoints.find(track, race.racing_line.profile(race.tuning), race.rules.bp_min_speed_drop, race.pit_lane)
	race.add_child(race.bp_markers)
	race.bp_markers.show_points(track, race.braking_points)


## Offline: the player and Settings.bot_count bots (none in practice). Entrant 0 is the player,
## 1.. the bots; `grid` = entrant indices in grid order after qualifying (empty: the player's
## slot from Settings.grid_start).
static func offline_racers(race: RaceController, grid: Array[int]) -> void:
	var player_name: String = Settings.player_name if not Settings.player_name.is_empty() else TranslationServer.translate("PLAYER_DEFAULT_NAME")
	var bots := Settings.bot_count if race.mode != RaceController.Mode.PRACTICE else 0
	var slots := offline_slots(bots + 1, grid, Settings.grid_start)
	var colors := CarColors.COLORS.duplicate()
	colors.remove_at(clampi(Settings.car_color, 0, colors.size() - 1))
	race.me = add_racer(race, player_name, CarColors.color(Settings.car_color), true, slots[0])
	if race.qualifying:
		race.qualifying.add_human(race.me)
	for b in bots:
		var bot_name := RaceSetup.BOT_NAMES[b % RaceSetup.BOT_NAMES.size()]
		var color: Color = colors[b % colors.size()]
		var driver := BotDriver.new(race.racing_line, race.tuning, Settings.bot_difficulty as BotDriver.Difficulty, randi())
		if race.qualifying:
			race.qualifying.add_bot(bot_name, color, driver.lap_estimate(), randi())
			continue
		add_racer(race, bot_name, color, false, slots[b + 1]).bot = driver


## Grid slot of every entrant (0 = the player): from the qualifying `grid` when it fits, else
## the player at the back (grid_start 0), random (1) or on pole (2) and the bots in order.
static func offline_slots(count: int, grid: Array[int], grid_start: int) -> Array[int]:
	var slots: Array[int] = []
	if grid.size() == count:
		for entrant in count:
			slots.append(grid.find(entrant))
		if not slots.has(-1):
			return slots
		slots.clear()
	var player_slot := count - 1
	match grid_start:
		1:
			player_slot = randi() % count
		2:
			player_slot = 0
	slots.append(player_slot)
	for slot in count:
		if slot != player_slot:
			slots.append(slot)
	return slots


static func add_racer(race: RaceController, racer_name: String, color: Color, is_player: bool, slot: int) -> Racer:
	var track := race.track
	var racer := Racer.new(racer_name, color, is_player)
	racer.car = Car.new()
	race.add_child(racer.car)
	racer.car.setup(track, race.tuning, color, race.tyre_wear)
	racer.car.effects.marks = race.skid_marks
	racer.car.effects.smoke = race.tyre_smoke
	racer.laps = LapTracker.new(track)
	racer.shortcuts = ShortcutCheck.new(race.rules)
	racer.pit_stop = PitStop.new(race.pit_lane, race.rules, race.racers.size())
	racer.laps.line_crossed.connect(racer.car.kers.refill)
	racer.car.kers.locked = race.mode != RaceController.Mode.QUALIFYING
	racer.laps.lap_completed.connect(race.on_lap_completed.bind(racer))
	var place := RaceStart.grid_slot(track, race.rules, slot)
	match race.mode:
		RaceController.Mode.RACE:
			racer.car.place(place.x, place.y)
		RaceController.Mode.QUALIFYING:
			racer.car.place(fposmod(place.x - race.rules.quali_run_up, track.length), place.y)
			racer.ghost_until = ALWAYS
		_:
			racer.car.place(track.length - START_BEHIND_LINE, 0.0)
	race.racers.append(racer)
	return racer


## With tyre wear the bots (and the player's BP boards) need a profile per grip step: all now.
static func warm_up_profiles(race: RaceController) -> void:
	if not race.tyre_wear:
		return
	var corners: Array[float] = [1.0]
	for racer in race.racers:
		if racer.bot and not corners.has(minf(racer.bot.pace * racer.bot.pace, 1.0)):
			corners.append(minf(racer.bot.pace * racer.bot.pace, 1.0))
	race.racing_line.warm_up(race.tuning, corners, 1.0 - race.tuning.tyre_loss_dead)
