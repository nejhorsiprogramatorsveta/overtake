extends TestCase
## RaceStart: lights sequence, reaction time, jump start, bogged start; BrakingPoints.

const DT := 1.0 / 60.0

var rules: RaceRules = load("res://data/race/race_rules.tres")


## Runs the start until `until_time` with the clutch given by clutch_at(time); returns the entry.
func _run(start: RaceStart, entry: RaceStart.Entry, until_time: float, clutch_at: Callable) -> void:
	while start.time < until_time:
		start.update(DT)
		start.update_entry(entry, clutch_at.call(start.time))


func test_lights_come_on_one_by_one_then_go_out() -> void:
	var start := RaceStart.new(rules, 7)
	var seen: Array[int] = []
	while not start.lights_out():
		start.update(DT)
		if seen.is_empty() or seen[-1] != start.lights_on():
			seen.append(start.lights_on())
	check_eq(seen, [0, 1, 2, 3, 4, 5, 0] as Array[int], "0, then 1..5 red lights, then out")
	var expected := rules.grid_time + rules.light_interval * 4.0 + start.hold_time
	check(absf(start.go_time - expected) < 0.0001, "lights out a random hold after the fifth light")
	check(start.hold_time >= rules.hold_min and start.hold_time <= rules.hold_max, "hold within the range")
	check_eq(RaceStart.new(rules, 7).hold_time, start.hold_time, "same seed, same hold (host decides, M4)")


func test_reaction_time_from_lights_out_to_clutch_release() -> void:
	var start := RaceStart.new(rules, 3)
	var entry := RaceStart.Entry.new()
	var go_estimate := rules.grid_time + rules.light_interval * 4.0 + start.hold_time
	_run(start, entry, go_estimate + 1.0, func(t: float) -> bool: return t < go_estimate + 0.25)
	check(not entry.held, "car leaves after the clutch is released")
	check(not entry.jump_start, "no penalty")
	check(absf(entry.reaction - 0.25) < 0.03, "reaction ~0.25 s (got %.3f)" % entry.reaction)
	check_eq(start.penalty(entry), 0.0, "no penalty")


func test_releasing_during_the_lights_is_a_jump_start() -> void:
	var start := RaceStart.new(rules, 3)
	var entry := RaceStart.Entry.new()
	_run(start, entry, rules.grid_time + 2.5, func(_t: float) -> bool: return true)
	var held_until := start.time
	_run(start, entry, start.time + 0.2, func(_t: float) -> bool: return false)
	check(entry.jump_start and entry.held, "jump start noticed, car still held until lights out")
	check(held_until < rules.grid_time + rules.light_interval * 5.0, "released while lights were on")
	_run(start, entry, start.go_time + 0.1 if start.go_time > 0 else 20.0, func(_t: float) -> bool: return true)
	_run(start, entry, 20.0, func(_t: float) -> bool: return true)
	check(not entry.held and entry.reaction == 0.0, "leaves at once when lights go out")
	check_eq(start.penalty(entry), rules.jump_start_penalty, "+5 s")


func test_no_clutch_is_a_slow_start_and_grid_release_is_not_punished() -> void:
	var start := RaceStart.new(rules, 11)
	var entry := RaceStart.Entry.new()
	# Pressed and released on the grid before the lights, never again.
	_run(start, entry, 20.0, func(t: float) -> bool: return t < 1.0)
	check(not entry.jump_start, "letting go before the lights is not a jump start")
	check(absf(entry.reaction - rules.no_clutch_delay) < 0.03, "bogged start: leaves no_clutch_delay late (%.3f)" % entry.reaction)


func test_braking_points_before_every_big_corner() -> void:
	var track := TrackCatalog.get_track("austria")
	var tuning: CarTuning = load("res://data/car/car_tuning.tres")
	var points := BrakingPoints.find(track, SpeedProfile.compute(track, tuning), rules.bp_min_speed_drop)
	check(points.count() >= 6 and points.count() <= 12, "Austria has 6-12 braking zones (got %d)" % points.count())
	for i in points.count():
		check(points.entry_speeds[i] - points.corner_speeds[i] >= rules.bp_min_speed_drop, "real braking zone %d" % i)
		check(points.sides[i] == -1 or points.sides[i] == 1, "board side %d" % i)
	var worn := BrakingPoints.find(track, SpeedProfile.compute(track, tuning, 0.85), rules.bp_min_speed_drop)
	var earlier := 0
	for i in mini(points.count(), worn.count()):
		var diff := fposmod(points.distances[i] - worn.distances[i], track.length)
		if diff > 0.5 and diff < 200.0:
			earlier += 1
	check(earlier >= points.count() / 2, "with less grip most BPs move earlier (%d of %d)" % [earlier, points.count()])


func test_lights_out_time_varies_widely() -> void:
	# User 2026-11-22: the lights must not go out in the same rhythm every time.
	var shortest := INF
	var longest := 0.0
	for seed_value in 40:
		var hold := RaceStart.new(rules, seed_value * 7919 + 13).hold_time
		shortest = minf(shortest, hold)
		longest = maxf(longest, hold)
	check(shortest < 0.8 and longest > 3.2, "holds from %.2f to %.2f s after the fifth light" % [shortest, longest])
