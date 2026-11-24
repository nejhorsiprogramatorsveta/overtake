class_name BotTactics
## Racecraft of the bots on the straights (user 2026-11-24: "not always the racing line"). A bot
## behind another car on a straight moves into its slipstream (the tow makes it faster) and
## pulls out shortly before the braking zone - to the inside of the coming corner - to pass
## under braking. Pure helpers; BotDriver._traffic applies them.

## Look this many track points ahead (4 m each) for the next braking zone.
const SCAN_POINTS := 150
## A braking zone slows the racing-line speed by at least this much (m/s); a lift in a fast
## kink does not count.
const MIN_DROP := 8.0
## Tuck in only while the next braking zone is at least this far ahead (s at the current speed).
const STRAIGHT_TIME := 2.2
## Pull out this long before the braking zone (s at the current speed).
const PULL_OUT_TIME := 1.5
## ... or when this close behind the car ahead (m + PULL_OUT_SPEED_GAP s of own speed).
const PULL_OUT_GAP := 9.0
const PULL_OUT_SPEED_GAP := 0.12
## ... or when it would reach that gap within this time (closing in fast).
const CLOSING_TIME := 1.2


## Vector2(metres to the next braking zone, side of the corner after it: +1 = right of the
## centre line, -1 = left), or Vector2(INF, 0) when no braking zone is near.
static func next_corner(line: RacingLine, profile: SpeedProfile, index: int) -> Vector2:
	var track := line.track
	var n := profile.speeds.size()
	var k := 1
	while k < SCAN_POINTS:
		var i := (index + k) % n
		var before := profile.speeds[(i - 1 + n) % n]
		if profile.speeds[i] >= before:
			k += 1
			continue
		# Speed falls from here: follow it to the slowest point of this corner.
		var slowest := i
		var j := k
		while j < SCAN_POINTS + 80 and profile.speeds[(index + j + 1) % n] <= profile.speeds[slowest]:
			j += 1
			slowest = (index + j) % n
		if before - profile.speeds[slowest] >= MIN_DROP:
			var metres := fposmod(track.distances[(i - 1 + n) % n] - track.distances[index], track.length)
			var side := signf(line.lateral(slowest))
			return Vector2(metres, side if side != 0.0 else 1.0)
		k = j + 1
	return Vector2(INF, 0.0)


## True while a car `gap` metres ahead at `other_speed` gives a tow worth following: on a
## straight, inside the slipstream time, not yet close enough to pull out and not closing in so
## fast that the bot would have to lift (then it pulls out at once).
static func should_tuck(gap: float, my_speed: float, other_speed: float, corner: Vector2, tuning: CarTuning) -> bool:
	if my_speed < tuning.slip_min_speed or other_speed < tuning.slip_min_speed:
		return false
	var closing := my_speed - other_speed
	if closing > 0.0 and (gap - pull_out_gap(my_speed)) / closing < CLOSING_TIME:
		return false
	return gap > pull_out_gap(my_speed) and gap < other_speed * tuning.slip_time \
			and corner.x > my_speed * STRAIGHT_TIME


## Time to leave the tow and go for the pass: the braking zone is near or the gap is small.
static func should_pull_out(gap: float, my_speed: float, corner: Vector2) -> bool:
	return gap <= pull_out_gap(my_speed) or corner.x < my_speed * PULL_OUT_TIME


static func pull_out_gap(my_speed: float) -> float:
	return PULL_OUT_GAP + my_speed * PULL_OUT_SPEED_GAP
