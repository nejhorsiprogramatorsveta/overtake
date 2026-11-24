extends TestCase
## Qualifying (user 2026-11-23): best valid lap sets the order, shortcut laps and extra laps do
## not count, the bots' estimated laps appear over time, the session ends when everyone is done
## or the time is up; the grid after it (offline slots, online grid order check).

var rules: RaceRules = load("res://data/race/race_rules.tres")
var track := TrackCatalog.get_track("austria")


func _human(racer_name: String) -> Racer:
	var racer := Racer.new(racer_name, Color.RED, false)
	racer.laps = LapTracker.new(track)
	racer.shortcuts = ShortcutCheck.new(rules)
	return racer


## One timed lap: the line crossing (as LapTracker emits it) and the lap.
func _lap(quali: Qualifying, racer: Racer, time: float) -> bool:
	racer.laps.line_crossed.emit()
	return quali.lap_completed(racer, time)


func test_best_valid_lap_sets_the_order() -> void:
	var quali := Qualifying.new(rules)
	var a := _human("A")
	var b := _human("B")
	var c := _human("C")
	for racer in [a, b, c]:
		quali.add_human(racer)
		racer.laps.line_crossed.emit()  # out lap ends
	check(_lap(quali, a, 50.0), "A's first lap counts")
	check(_lap(quali, b, 49.0), "B's lap counts")
	b.shortcuts.count += 1  # B cuts the track during the next lap
	check(not _lap(quali, b, 45.0), "a lap with a shortcut does not count")
	check(_lap(quali, a, 48.5), "A's second lap counts")
	check(not _lap(quali, a, 40.0), "a third lap is not timed")
	check_eq(quali.entrants[0].best, 48.5, "A's best is the better timed lap")
	check_eq(quali.entrants[1].best, 49.0, "B keeps the valid lap")
	check_eq(quali.order(), [0, 1, 2] as Array[int], "A, B, then C without a time")


func test_session_ends_when_everyone_is_done_or_time_is_up() -> void:
	var quali := Qualifying.new(rules)
	var a := _human("A")
	var b := _human("B")
	quali.add_human(a)
	quali.add_human(b)
	check(not quali.should_end(10.0), "running")
	check(quali.should_end(rules.quali_time), "time up")
	for i in rules.quali_laps + 1:
		a.laps.line_crossed.emit()
		quali.lap_completed(a, 50.0)
	check(not quali.should_end(100.0), "B still driving")
	b.retired = true
	check(quali.should_end(100.0), "everyone still here is done")
	quali.finish(quali.order())
	check(not quali.should_end(100.0), "ends once")


func test_bots_show_their_laps_over_time() -> void:
	var quali := Qualifying.new(rules)
	quali.add_bot("Bot", Color.BLUE, 45.0, 3)
	var bot := quali.entrants[0]
	quali.update(5.0)
	check_eq(bot.best, -1.0, "no time during the out lap")
	quali.update(bot.plan_shown[0])
	check(bot.best >= 45.3 and bot.best <= 46.2, "first lap a bit slower (%.2f)" % bot.best)
	var fast := _human("Fast")
	quali.add_human(fast)
	fast.laps.line_crossed.emit()
	_lap(quali, fast, bot.best - 0.05)  # faster than the bot's first lap, slower than its second
	check_eq(quali.order(), [1, 0] as Array[int], "for now the person is ahead")
	check_eq(quali.final_order(), [0, 1] as Array[int], "the result counts the bot's second lap")
	quali.finish(quali.final_order())
	check(bot.best >= 45.0 and bot.best <= 45.4, "at the end its best lap (%.2f)" % bot.best)
	var same := Qualifying.new(rules)
	same.add_bot("Bot", Color.BLUE, 45.0, 3)
	same.finish([0] as Array[int])
	check_eq(same.entrants[0].best, bot.best, "the same seed gives the same laps on every peer")


func test_offline_grid_after_qualifying() -> void:
	var grid: Array[int] = [2, 0, 1]  # bot 2 (entrant 2) on pole, the player second
	check_eq(RaceBuilder.offline_slots(3, grid, 0), [1, 2, 0] as Array[int], "slot of every entrant")
	check_eq(RaceBuilder.offline_slots(3, [] as Array[int], 0), [2, 0, 1] as Array[int], "no qualifying: player at the back")
	check_eq(RaceBuilder.offline_slots(3, [] as Array[int], 2), [0, 1, 2] as Array[int], "player on pole")
	check_eq(RaceBuilder.offline_slots(3, [0, 0, 1] as Array[int], 2), [0, 1, 2] as Array[int], "broken grid ignored")


func test_online_grid_order_is_checked() -> void:
	check_eq(LobbyValidator.grid_order(PackedByteArray([1, 0, 2]), 3), [1, 0, 2] as Array[int], "valid permutation")
	check(LobbyValidator.grid_order(PackedByteArray([1, 1, 2]), 3).is_empty(), "duplicate rejected")
	check(LobbyValidator.grid_order(PackedByteArray([0, 1]), 3).is_empty(), "wrong size rejected")
	check(LobbyValidator.grid_order(PackedByteArray([0, 1, 3]), 3).is_empty(), "out of range rejected")
	check(LobbyValidator.grid_order([0, 1, 2], 3).is_empty(), "only bytes")
	var base := {"track": "austria", "laps": 3, "tyre_wear": false, "bots": 2, "difficulty": 1, "grid": 0}
	check_eq(LobbyValidator.settings(base, 2).qualifying, false, "qualifying off by default")
	base["qualifying"] = true
	check_eq(LobbyValidator.settings(base, 2).qualifying, true, "qualifying on")
	base["qualifying"] = 1
	check(LobbyValidator.settings(base, 2).is_empty(), "qualifying must be a bool")
