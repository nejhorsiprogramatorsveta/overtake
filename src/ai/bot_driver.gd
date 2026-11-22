class_name BotDriver
extends RefCounted
## A computer driver (PLAN.md B, M3): follows the racing line, brakes by the racing-line speed
## profile (the same physics as the player, no cheating), reacts to the start lights, uses KERS
## out of slow corners, pits for new tyres when they are worn and plays the pit minigame.
## The difficulty sets the pace in corners, the precision of the line, the start reaction and
## the pit stop timing. In traffic it passes slower cars where there is room, follows when there
## is none and keeps space beside cars (no ramming). Produces one CarInput per tick; the host runs
## bots (M4).

enum Difficulty { EASY, MEDIUM, HARD, EXPERT }

## Per difficulty: pace = share of the ideal corner speed. It scales the cornering grip the bot
## plans with (pace²) - never the speed on the straights or the braking, so a slow bot brakes as
## hard as the player and does not lift or brake in odd places (user 2026-11-22). Above 1 the car also gets
## pace² real grip, so it can corner that fast (user 2026-11-22: Expert was too easy).
## Then line wobble (m), start reaction (s), where on the pit bar Space is pressed.
const SKILLS := {
	Difficulty.EASY: {"pace": 0.72, "wobble": 1.4, "reaction": 0.42, "pit_press": 0.78},
	Difficulty.MEDIUM: {"pace": 0.79, "wobble": 0.9, "reaction": 0.32, "pit_press": 0.88},
	Difficulty.HARD: {"pace": 0.85, "wobble": 0.5, "reaction": 0.25, "pit_press": 0.93},
	Difficulty.EXPERT: {"pace": 0.895, "wobble": 0.2, "reaction": 0.2, "pit_press": 0.97},
}
## Pit for new tyres below this condition (only with tyre wear), if at least one lap is left.
const PIT_BELOW := 0.3
const STEER_GAIN := 2.6
## Sideways room the bot keeps to other cars (m).
const CLEARANCE := 3.4
## A braking car ahead is expected to keep braking this long (s).
const BRAKE_HORIZON := 0.6

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


## The input for this tick. laps_left = laps still to start after this one (for pit decisions);
## others = all racers (traffic: overtake slower cars, keep space beside cars, never ram).
func drive(racer: Racer, start: RaceStart, laps_left: int, others: Array[Racer] = [], time: float = 0.0) -> CarInput:
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
		if pit.minigame and not pit.minigame.decided():
			input.clutch = pit.minigame.bar() >= pit_press
		return input
	car.tyres.bonus = maxf(pace * pace, 1.0)
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
	var traffic_speed := INF
	if going_to_pit:
		lateral = pit.lane.side * (line.track.half_width() - 1.5)
	else:
		var traffic := _traffic(racer, others, lateral, time)
		lateral = traffic.x
		traffic_speed = traffic.y
	var target := line.track.points[posmod(target_index, line.track.point_count())] \
			+ line.track.normal(posmod(target_index, line.track.point_count())) * lateral
	var angle := wrapf((target - state.position).angle() - state.heading, -PI, PI)
	input.steer = clampf(angle * STEER_GAIN, -1.0, 1.0)
	var profile := line.profile(tuning, car.tyres.grip_factor(), minf(pace * pace, 1.0))
	var n := line.track.point_count()
	var wanted: float = profile.speeds[(index + 1) % n]
	if going_to_pit:
		wanted = minf(wanted, 40.0)
	wanted = minf(wanted, traffic_speed)
	var forward := state.forward_speed()
	input.brake = forward > wanted + 1.0
	input.throttle = not input.brake and forward < wanted - 0.2
	# KERS out of slow corners when the road ahead is fast and straight.
	var ahead: float = profile.speeds[(index + 12) % n]
	var want_kers: bool = car.kers.available() and input.throttle and absf(input.steer) < 0.25 \
			and ahead > forward + 15.0 and not car.kers.is_active()
	input.kers = want_kers and not _kers_held
	_kers_held = input.kers
	return input


## Traffic around the bot: returns Vector2(lateral to aim for, speed limit). A slower car ahead
## close to the bot's line: pass it on the side with more room; no room: follow at its speed.
## A car alongside: keep CLEARANCE metres sideways. Ghosts are ignored.
func _traffic(racer: Racer, others: Array[Racer], wanted_lateral: float, time: float) -> Vector2:
	var me := racer.car
	var track := line.track
	var limit := track.half_width() - 1.8
	var my_lateral := me.query.lateral
	var my_speed := me.state.velocity.length()
	var lateral := wanted_lateral
	var speed_limit := INF
	if racer.is_ghost(time):
		return Vector2(lateral, speed_limit)
	for other in others:
		if other == racer or other.is_ghost(time):
			continue
		var gap := other.car.query.distance - me.query.distance
		if gap > track.length * 0.5:
			gap -= track.length
		elif gap < -track.length * 0.5:
			gap += track.length
		var other_lateral := other.car.query.lateral
		var other_speed := other.car.state.velocity.length()
		var look := 25.0 + my_speed * 0.6
		# Whatever we plan: never run into a car that is in our lane right now - brake in time.
		# A car that is braking will be slower soon: plan with its speed BRAKE_HORIZON ahead.
		var other_soon := maxf(other_speed + minf(other.car.state.accel, 0.0) * BRAKE_HORIZON, 0.0)
		if gap > 0.0 and absf(other_lateral - my_lateral) < tuning.width + 0.6 and my_speed > other_soon:
			var room := maxf(gap - tuning.length - 2.0, 0.5)
			var needed := (my_speed * my_speed - other_soon * other_soon) / (2.0 * room)
			if needed > tuning.brake_decel * 0.4:
				speed_limit = minf(speed_limit, other_soon)
		if gap > 0.0 and gap < look and absf(other_lateral - lateral) < CLEARANCE:
			# In the way: pass where there is more room, if faster; otherwise follow.
			var left := other_lateral - CLEARANCE
			var right := other_lateral + CLEARANCE
			var pass_left := absf(left) <= limit and (absf(right) > limit or absf(left - my_lateral) <= absf(right - my_lateral))
			var pass_lateral := left if pass_left else right
			if absf(pass_lateral) <= limit and my_speed > other_speed - 1.0:
				lateral = pass_lateral
			elif gap < 14.0 + my_speed * 0.3:
				speed_limit = minf(speed_limit, other_speed - 0.5)
		elif absf(gap) <= tuning.length + 2.0 and absf(other_lateral - lateral) < CLEARANCE:
			# Alongside: hold the gap on our side, never steer into the other car.
			lateral = other_lateral + (CLEARANCE if my_lateral >= other_lateral else -CLEARANCE)
	return Vector2(clampf(lateral, -limit, limit), speed_limit)


func _near_pit_entry(racer: Racer) -> bool:
	var lane := racer.pit_stop.lane
	var to_entry := fposmod(lane.entry_distance - racer.car.query.distance, line.track.length)
	return to_entry < 160.0
