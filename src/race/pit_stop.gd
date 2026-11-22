class_name PitStop
extends RefCounted
## One car's trip through the pit lane (PLAN.md B): turning into the pit entry hands the car to
## an autopilot that slows it to the speed limit, drives it along the lane and stops it at its
## box; the minigame decides the stop time; new tyres go on; the autopilot accelerates to the
## lane exit and gives the car back. The whole time the car is a ghost (no contact, M3).
## The driver only presses Space in the box (user requirement).

enum Phase { NONE, IN_LANE, STOPPED, LEAVING }

var lane: PitLane
var rules: RaceRules
var box_slot := 0
var phase := Phase.NONE
## Distance along the pit path and speed along it.
var s := 0.0
var speed := 0.0
var minigame: PitMinigame
## Completed stops (for the results).
var stops := 0
## Visual offset from the car's real position to the path when it turned in, fading out.
var _offset := Vector2.ZERO
var _was_pressed := true


func _init(pit_lane: PitLane, race_rules: RaceRules, slot: int) -> void:
	lane = pit_lane
	rules = race_rules
	box_slot = slot % maxi(lane.box_count(), 1)


func active() -> bool:
	return phase != Phase.NONE


## Call every tick before the car's own physics. Returns true while the pit stop drives the car.
func update(car: Car, clutch: bool, dt: float) -> bool:
	match phase:
		Phase.NONE:
			if not lane.is_at_entry(car.query):
				return false
			phase = Phase.IN_LANE
			s = lane.project(car.state.position)
			speed = car.state.velocity.length()
			_offset = car.state.position - lane.position_at(s)
			_was_pressed = true
		Phase.IN_LANE:
			var to_box := lane.box_distance(box_slot) - s
			var wanted := minf(rules.pit_speed, sqrt(maxf(2.0 * rules.pit_decel * to_box, 0.0)))
			speed = move_toward(speed, wanted, rules.pit_decel * dt)
			s = minf(s + speed * dt, lane.box_distance(box_slot))
			if to_box <= 0.05:
				phase = Phase.STOPPED
				speed = 0.0
				minigame = PitMinigame.new(rules)
		Phase.STOPPED:
			minigame.update(dt, clutch and not _was_pressed)
			if minigame.finished():
				car.tyres.fit_new()
				stops += 1
				phase = Phase.LEAVING
		Phase.LEAVING:
			speed = move_toward(speed, rules.pit_speed, rules.pit_accel * dt)
			s += speed * dt
			if s >= lane.length:
				_release(car)
				return false
	_was_pressed = clutch
	_offset = _offset.move_toward(Vector2.ZERO, 6.0 * dt)
	_place(car)
	return true


func _place(car: Car) -> void:
	var direction := lane.direction_at(s)
	car.state.position = lane.position_at(s) + _offset
	car.state.heading = direction.angle()
	car.state.velocity = direction * speed
	car.state.steer = 0.0
	car.state.tow = 0.0
	car.state.drag_multiplier = 1.0
	car.state.boost_accel = 0.0
	car.after_external_move()


func _release(car: Car) -> void:
	phase = Phase.NONE
	minigame = null
	s = lane.length
	_place(car)
