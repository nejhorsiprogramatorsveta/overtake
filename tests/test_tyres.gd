extends TestCase
## TyreModel: wear with distance, slow then steep loss, off = no wear; worn tyres brake later.

const DT := 1.0 / 60.0

var tuning: CarTuning = load("res://data/car/car_tuning.tres")


func test_condition_drops_with_distance_only_when_enabled() -> void:
	var state := CarState.new()
	var off := TyreModel.new(tuning, false)
	off.update(state, 5000.0)
	check_eq(off.condition, 1.0, "wear off: tyres stay new")
	check_eq(state.grip_multiplier, 1.0, "full grip")
	var on := TyreModel.new(tuning, true)
	on.update(state, tuning.tyre_life * 0.5)
	check(absf(on.condition - 0.5) < 0.001, "half the life driven: 50 %")
	check(state.grip_multiplier < 1.0, "grip already lower")
	on.fit_new()
	on.update(state, 0.0)
	check_eq(state.grip_multiplier, 1.0, "new tyres (pit stop): full grip")


func test_loss_is_slow_then_steep() -> void:
	var tyres := TyreModel.new(tuning, true)
	check_eq(tyres.loss_at(1.0), 0.0, "new: no loss")
	check(absf(tyres.loss_at(tuning.tyre_cliff) - tuning.tyre_loss_at_cliff) < 0.0001, "cliff: -12 %")
	check(absf(tyres.loss_at(0.0) - tuning.tyre_loss_dead) < 0.0001, "dead: -30 %")
	var before_cliff := tyres.loss_at(0.6) - tyres.loss_at(0.7)
	var after_cliff := tyres.loss_at(0.1) - tyres.loss_at(0.2)
	check(after_cliff > before_cliff * 2.0, "below the cliff the tyres go off much faster")
	var track := TrackCatalog.get_track("austria")
	var laps_to_cliff := tuning.tyre_life * (1.0 - tuning.tyre_cliff) / track.length
	check(laps_to_cliff > 3.0 and laps_to_cliff < 6.0, "cliff after 3-6 laps of Austria (%.1f)" % laps_to_cliff)


func test_worn_tyres_need_a_longer_braking_distance() -> void:
	var distances: Array[float] = []
	for grip: float in [1.0, 0.85]:
		var state := CarState.new()
		state.velocity = Vector2(80.0, 0.0)
		state.grip_multiplier = grip
		var input := CarInput.new()
		input.brake = true
		while state.velocity.x > 0.0:
			CarMotor.step(state, input, tuning, DT)
		distances.append(state.position.x)
	check(distances[1] > distances[0] * 1.1, "worn tyres brake >10 %% later (%.1f vs %.1f m)" % [distances[1], distances[0]])
