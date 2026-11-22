extends TestCase
## RaceRanking: finished cars by total time incl. penalties, then the rest by distance raced.

var rules: RaceRules = load("res://data/race/race_rules.tres")
var tuning: CarTuning = load("res://data/car/car_tuning.tres")
var track := TrackCatalog.get_track("austria")


func _racer(racer_name: String, laps_done: int, distance: float) -> Racer:
	var racer := Racer.new(racer_name, Color.WHITE, false)
	racer.car = Car.new()
	racer.car.setup(track, tuning, Color.WHITE)
	racer.car.place(distance, 0.0)
	racer.laps = LapTracker.new(track)
	racer.laps.laps = laps_done
	racer.shortcuts = ShortcutCheck.new(rules)
	racer.pit_stop = PitStop.new(PitLane.build(track, rules), rules, 0)
	return racer


func _free(racers: Array[Racer]) -> void:
	for racer in racers:
		racer.car.free()


func test_unfinished_cars_by_laps_then_distance() -> void:
	var a := _racer("A", 2, 100.0)
	var b := _racer("B", 2, 900.0)
	var c := _racer("C", 3, 50.0)
	var racers: Array[Racer] = [a, b, c]
	var order := RaceRanking.order(racers, null)
	check_eq(order.map(func(r: Racer) -> String: return r.name), ["C", "B", "A"], "more laps first, then further into the lap")
	check_eq(RaceRanking.position_of(a, racers, null), 3, "A is third")
	_free(racers)


func test_finished_cars_by_time_with_penalties_and_ahead_of_the_rest() -> void:
	var start := RaceStart.new(rules, 1)
	start.go_time = 10.0
	var fast := _racer("Fast", 5, 10.0)
	var slow := _racer("Slow", 5, 10.0)
	var running := _racer("Running", 4, 2000.0)
	for racer: Racer in [fast, slow]:
		racer.finished = true
	fast.finish_time = 250.0
	slow.finish_time = 253.0
	fast.shortcuts.penalty = 5.0  # 240 s + 5 s = 245 s, slower than 243 s
	var racers: Array[Racer] = [running, fast, slow]
	var order := RaceRanking.order(racers, start)
	check_eq(order.map(func(r: Racer) -> String: return r.name), ["Slow", "Fast", "Running"], "penalty drops Fast behind Slow; finished before running")
	check_eq(fast.total_time(start), 245.0, "total = finish - lights out + penalties")
	_free(racers)


func test_grid_progress_counts_as_negative_until_the_line() -> void:
	var laps := LapTracker.new(track)
	laps.start_from_grid(0.0)
	check(laps.progress(track.length - 10.0) < 0.0, "behind the line on the grid: before the start")
	check(laps.progress(track.length - 10.0) > laps.progress(track.length - 30.0), "further up the grid is ahead")


func test_gap_is_the_time_since_the_leader_was_here() -> void:
	var leader := _racer("Leader", 0, 100.0)
	var chaser := _racer("Chaser", 0, 50.0)
	# The leader reached 0..100 m at 1 s per 10 m; the chaser is at 50 m at time 12 s.
	for i in 11:
		leader.progress_times.append(float(i))
	check_eq(chaser.gap_to(leader, 12.0), 7.0, "the leader was at 50 m at 5 s: 7 s behind")
	check_eq(leader.gap_to(leader, 12.0), 0.0, "leader: no gap")
	var racers: Array[Racer] = [leader, chaser]
	_free(racers)
