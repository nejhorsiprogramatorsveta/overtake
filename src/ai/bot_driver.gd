class_name BotDriver
extends RefCounted
## A computer driver (PLAN.md B, M3): follows the racing line, brakes by the racing-line speed
## profile (the same physics as the player, no cheating), reacts to the start lights, uses KERS
## out of slow corners, pits for new tyres when they are worn and plays the pit minigame.
## The difficulty sets the pace in corners, the precision of the line, the start reaction and
## the pit stop timing. Produces one CarInput per tick; the host runs bots (M4).

enum Difficulty { EASY, MEDIUM, HARD, EXPERT }

## Per difficulty: share of the ideal corner speed, line wobble (m), start reaction (s),
## where on the pit bar Space is pressed.
const SKILLS := {
	Difficulty.EASY: {"pace": 0.88, "wobble": 1.6, "reaction": 0.45, "pit_press": 0.78},
	Difficulty.MEDIUM: {"pace": 0.93, "wobble": 1.0, "reaction": 0.33, "pit_press": 0.88},
	Difficulty.HARD: {"pace": 0.97, "wobble": 0.5, "reaction": 0.26, "pit_press": 0.93},
	Difficulty.EXPERT: {"pace": 1.0, "wobble": 0.2, "reaction": 0.2, "pit_press": 0.97},
}
## Pit for new tyres below this condition (only with tyre wear), if at least one lap is left.
const PIT_BELOW := 0.3
const STEER_GAIN := 2.6

var line: RacingLine
var tuning: CarTuning
var pace := 1.0
var wobble := 0.0
var pit_press := 0.9
var rng := RandomNumberGenerator.new()
var reaction := 0.3
var wants_pit := false
var _kers_held := false
var _wobble_phase := 0.0


func _init(racing_line: RacingLine, car_tuning: CarTuning, difficulty: Difficulty, seed_value: int) -> void:
	line = racing_line
	tuning = car_tuning
	var skill: Dictionary = SKILLS[difficulty]
	pace = skill.pace
	wobble = skill.wobble
	pit_press = skill.pit_press
	rng.seed = seed_value
	reaction = float(skill.reaction) + rng.randf_range(-0.06, 0.12)
	_wobble_phase = rng.randf() * TAU


## The input for this tick. laps_left = laps still to start after this one (for pit decisions).
func drive(racer: Racer, start: RaceStart, laps_left: int) -> CarInput:
	var input := CarInput.new()
	var car := racer.car
	var state := car.state
	# Start: hold throttle + clutch, let go `reaction` after the lights go out.
	if start and racer.start_entry.held:
		input.throttle = true
		input.clutch = not start.lights_out() or start.time - start.go_time < reaction
		return input
	# In the pit box: press Space at the chosen moment of the bar.
	var pit := racer.pit_stop
	if pit.active():
		wants_pit = false
		if pit.phase == PitStop.Phase.STOPPED:
			input.clutch = pit.minigame.bar() >= pit_press
		return input
	if car.tyres.enabled and car.tyres.condition < PIT_BELOW and laps_left >= 1:
		wants_pit = true
	var index := car.query.index
	var speed := state.velocity.length()
	var lookahead := 2 + int((8.0 + speed * 0.32) / 4.0)
	var target_index := index + lookahead
	var lateral := line.lateral(target_index)
	_wobble_phase += 0.013
	lateral += sin(_wobble_phase) * wobble
	var going_to_pit := wants_pit and _near_pit_entry(racer)
	if going_to_pit:
		lateral = pit.lane.side * (line.track.half_width() - 1.5)
	var target := line.track.points[posmod(target_index, line.track.point_count())] \
			+ line.track.normal(posmod(target_index, line.track.point_count())) * lateral
	var angle := wrapf((target - state.position).angle() - state.heading, -PI, PI)
	input.steer = clampf(angle * STEER_GAIN, -1.0, 1.0)
	var profile := line.profile(tuning, car.tyres.grip_factor())
	var n := line.track.point_count()
	var wanted: float = profile.speeds[(index + 1) % n] * pace
	if going_to_pit:
		wanted = minf(wanted, 40.0)
	var forward := state.forward_speed()
	input.brake = forward > wanted + 1.0
	input.throttle = not input.brake and forward < wanted - 0.2
	# KERS out of slow corners when the road ahead is fast and straight.
	var ahead: float = profile.speeds[(index + 12) % n] * pace
	var want_kers: bool = car.kers.uses_left > 0 and input.throttle and absf(input.steer) < 0.25 \
			and ahead > forward + 15.0 and not car.kers.is_active()
	input.kers = want_kers and not _kers_held
	_kers_held = input.kers
	return input


func _near_pit_entry(racer: Racer) -> bool:
	var lane := racer.pit_stop.lane
	var to_entry := fposmod(lane.entry_distance - racer.car.query.distance, line.track.length)
	return to_entry < 160.0
