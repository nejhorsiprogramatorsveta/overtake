extends TestCase
## Look-only effects and HUD logic (M3G): scrub/wheelspin values from the physics, skid marks
## (merged segments, ring buffer, no mark across a jump), lap colours, speed bar colours.

const DT := 1.0 / 60.0

var tuning: CarTuning = load("res://data/car/car_tuning.tres")
var rules: RaceRules = load("res://data/race/race_rules.tres")
var track := TrackCatalog.get_track("austria")


func _moving(speed: float) -> CarState:
	var state := CarState.new()
	state.velocity = Vector2(speed, 0.0)
	return state


func test_scrub_only_when_asking_more_than_the_grip() -> void:
	var gentle := _moving(50.0)
	var input := CarInput.new()
	input.throttle = true
	input.steer = 0.05
	for i in 30:
		CarMotor.step(gentle, input, tuning, DT)
	check(gentle.slide < 0.05, "gentle steering: no scrub (%.2f)" % gentle.slide)
	var hard := _moving(50.0)
	input.steer = 1.0
	for i in 30:
		CarMotor.step(hard, input, tuning, DT)
	check(hard.slide > 0.3, "full lock at speed: tyres scrub (%.2f)" % hard.slide)


func test_wheelspin_at_launch_only() -> void:
	var state := CarState.new()
	var input := CarInput.new()
	input.throttle = true
	CarMotor.step(state, input, tuning, DT)
	check(state.wheelspin > 0.9, "standing start: wheelspin")
	state.velocity = Vector2(40.0, 0.0)
	CarMotor.step(state, input, tuning, DT)
	check_eq(state.wheelspin, 0.0, "at speed: none")


func test_marks_are_merged_and_stop_at_a_jump() -> void:
	var marks := SkidMarks.new()
	var effects := CarEffects.new()
	effects.marks = marks
	var state := _moving(30.0)
	state.slide = 0.8
	for i in 60:  # 1 s at 30 m/s
		state.position += state.velocity * DT
		effects.update(state, true)
	var rough := 4 * 30.0 / CarEffects.MARK_STEP
	# Segments are at least MARK_STEP long (whole ticks: 0.5 m each here, so every 1.0 m).
	check(marks.count() > rough * 0.6 and marks.count() <= rough, "segments of at least %.1f m (%d)" % [CarEffects.MARK_STEP, marks.count()])
	var before := marks.count()
	effects.reset()
	state.position += Vector2(50.0, 0.0)
	effects.update(state, true)
	check_eq(marks.count(), before, "no mark across the jump")
	state.slide = 0.0
	state.position += Vector2(5.0, 0.0)
	effects.update(state, true)
	check_eq(marks.count(), before, "no mark without scrub")
	effects.update(state, false)
	marks.free()


func test_marks_ring_buffer_keeps_the_newest() -> void:
	var marks := SkidMarks.new()
	for i in SkidMarks.MAX_SEGMENTS + 50:
		marks.add(Vector2(i, 0.0), Vector2(i + 1, 0.0), 1.0)
	check_eq(marks.count(), SkidMarks.MAX_SEGMENTS, "never more than the limit")
	marks.free()


func test_lap_colours() -> void:
	var a := Racer.new("A", Color.RED, true)
	var b := Racer.new("B", Color.BLUE, false)
	a.laps = LapTracker.new(track)
	b.laps = LapTracker.new(track)
	var everyone: Array[Racer] = [a, b]
	b.laps.best_lap = 44.0
	a.laps.best_lap = 43.5
	check_eq(RaceRanking.lap_kind(43.5, a, everyone), RaceRanking.LapKind.FASTEST, "fastest of all: purple")
	a.laps.best_lap = 44.5
	check_eq(RaceRanking.lap_kind(44.5, a, everyone), RaceRanking.LapKind.PERSONAL_BEST, "own best: green")
	check_eq(RaceRanking.lap_kind(45.2, a, everyone), RaceRanking.LapKind.SLOWER, "slower: yellow")


func test_speed_bar_colours() -> void:
	check_eq(SpeedGauge.segment_color(0.2), HudStyle.GREEN, "low: green")
	check_eq(SpeedGauge.segment_color(0.7), HudStyle.YELLOW, "high: yellow")
	check_eq(SpeedGauge.segment_color(0.95), HudStyle.LOSS, "near the top: red")


func test_grid_slots_are_staggered_behind_the_line() -> void:
	var first := RaceStart.grid_slot(track, rules, 0)
	var second := RaceStart.grid_slot(track, rules, 1)
	check(first.x > second.x and first.x < track.length, "pole ahead, both behind the line")
	check(signf(first.y) != signf(second.y), "alternating sides")


## User 2026-11-24: on the grid the bar shows the revs (full with the throttle at 0 km/h), after
## the start the speed again.
func test_speed_bar_shows_revs_on_the_grid() -> void:
	var gauge := SpeedGauge.new()
	gauge.show_speed(0.0, false)
	gauge.show_revs(true, false)
	gauge._process(1.0)
	check(gauge.lit_segments() > 0 and gauge.lit_segments() < SpeedGauge.SEGMENTS / 3, "idle revs (%d)" % gauge.lit_segments())
	gauge.show_revs(true, true)
	gauge._process(1.0)
	check(gauge.lit_segments() >= SpeedGauge.SEGMENTS - 1, "throttle on the grid: at the limiter (%d)" % gauge.lit_segments())
	gauge.show_revs(false, true)
	gauge.show_speed(170.0, false)
	gauge._process(0.016)
	check_eq(gauge.lit_segments(), SpeedGauge.SEGMENTS / 2, "after the start: the speed")
	gauge.free()
