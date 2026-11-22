class_name TyreModel
extends RefCounted
## Tyre wear (PLAN.md B, optional per race): the condition drops from 100 % with the distance
## driven; grip and brakes fall slowly at first (tyre_loss_at_cliff at the cliff) and faster
## below it (tyre_loss_dead at 0 %). The car then has to brake earlier - its own BP boards
## move (BrakingPoints from a profile with grip_factor()). A pit stop puts on new tyres.

var tuning: CarTuning
var enabled := false
## 1 = new, 0 = dead.
var condition := 1.0


func _init(car_tuning: CarTuning, wear_enabled: bool) -> void:
	tuning = car_tuning
	enabled = wear_enabled


## Call every tick with the metres driven; sets the car's grip multiplier.
func update(state: CarState, travelled: float) -> void:
	if enabled:
		condition = maxf(condition - travelled / tuning.tyre_life, 0.0)
	state.grip_multiplier = grip_factor()


func fit_new() -> void:
	condition = 1.0


## Grip/brake multiplier for the current condition.
func grip_factor() -> float:
	return 1.0 - loss_at(condition)


func loss_at(value: float) -> float:
	var cliff := tuning.tyre_cliff
	if value >= cliff:
		return tuning.tyre_loss_at_cliff * (1.0 - value) / (1.0 - cliff)
	return lerpf(tuning.tyre_loss_dead, tuning.tyre_loss_at_cliff, value / cliff)
