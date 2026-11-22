class_name Car
extends Node2D
## One car in the race scene: its physical state, its place on the track and its drawing.
## simulate() runs once per physics tick (60 Hz); physics interpolation smooths the drawing.

var state := CarState.new()
var query := TrackQuery.new()
var tuning: CarTuning
var track: TrackData
var view: CarView
var kers: Kers
var tyres: TyreModel
## Last input, kept for the drawing (brake lights).
var last_input := CarInput.new()


func setup(car_track: TrackData, car_tuning: CarTuning, color: Color, tyre_wear: bool = false) -> void:
	track = car_track
	tuning = car_tuning
	kers = Kers.new(tuning)
	tyres = TyreModel.new(tuning, tyre_wear)
	view = CarView.new()
	view.body_color = color
	view.tuning = tuning
	add_child(view)


## Places the car `distance` metres along the lap, `lateral` metres right of the centre line.
func place(distance: float, lateral: float) -> void:
	state.position = track.position_at(distance, lateral)
	state.heading = track.heading_at(distance)
	state.velocity = Vector2.ZERO
	state.steer = 0.0
	query.index = -1
	query.update(track, state.position)
	_sync_node()
	reset_physics_interpolation()


## One physics tick. `others` = the other cars as this car sees them (for the slipstream).
func simulate(input: CarInput, dt: float, others: Array[CarState] = []) -> void:
	last_input = input
	state.on_track = query.surface == TrackQuery.Surface.TRACK
	kers.update(state, input.kers, input.throttle, dt)
	Slipstream.update(state, others, tuning, dt)
	CarMotor.step(state, input, tuning, dt)
	tyres.update(state, state.velocity.length() * dt)
	query.update(track, state.position)
	if query.surface == TrackQuery.Surface.BARRIER:
		_hit_barrier()
	_sync_node()


## After something else moved the car (pit lane autopilot): update the track position and drawing.
func after_external_move() -> void:
	query.update(track, state.position)
	_sync_node()


## Ghost: no contact with other cars (pit lane, start), drawn see-through.
func set_ghost(ghost: bool) -> void:
	if view:
		view.modulate.a = 0.45 if ghost else 1.0


## Kept in place (grid before the start): no movement, steering resets.
func hold() -> void:
	state.velocity = Vector2.ZERO
	state.steer = 0.0
	last_input = CarInput.new()
	_sync_node()


func speed_kmh() -> float:
	return state.velocity.length() * 3.6


## The tyre wall at the edge of the runoff: push the car back, kill the speed into the wall.
func _hit_barrier() -> void:
	var limit := track.half_width() + TrackData.RUNOFF_WIDTH
	var side := signf(query.lateral)
	var normal := track.normal(query.index) * side
	state.position -= normal * (absf(query.lateral) - limit)
	var into_wall := state.velocity.dot(normal)
	if into_wall > 0.0:
		state.velocity -= normal * into_wall
	state.velocity *= 0.6
	query.update(track, state.position)


func _sync_node() -> void:
	position = state.position
	rotation = state.heading
	if view:
		view.braking = last_input.brake and state.forward_speed() > 1.0
