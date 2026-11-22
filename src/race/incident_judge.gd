class_name IncidentJudge
extends RefCounted
## Judges contacts between cars (PLAN.md B, user 2026-11-22): a contact closing faster than
## incident_min_speed where one car drove into the other is checked incident_check_time later -
## if the victim lost incident_victim_loss of its speed or left the track, the striker gets
## +incident_penalty seconds. A second such penalty in the same lap makes the striker a ghost for
## repeat_ghost_time. Light touches and side-by-side contacts are not penalised. In M4 the host
## judges.

signal penalised(striker: Racer, victim: Racer, ghost: bool)

class Pending:
	extends RefCounted
	var striker: Racer
	var victim: Racer
	var victim_speed := 0.0
	var due := 0.0

var rules: RaceRules
var _pending: Array[Pending] = []
## Racer -> lap of its last contact penalty.
var _last_penalty_lap: Dictionary = {}


func _init(race_rules: RaceRules) -> void:
	rules = race_rules


func report(contact: CarCollision.Contact, a: Racer, b: Racer, time: float) -> void:
	if contact.striker < 0 or contact.closing_speed < rules.incident_min_speed:
		return
	var item := Pending.new()
	item.striker = a if contact.striker == 0 else b
	item.victim = b if contact.striker == 0 else a
	item.victim_speed = item.victim.car.state.velocity.length()
	item.due = time + rules.incident_check_time
	for other in _pending:
		if other.striker == item.striker and other.victim == item.victim:
			return  # the same incident is already being judged
	_pending.append(item)


## Call every tick.
func update(time: float) -> void:
	var still: Array[Pending] = []
	for item in _pending:
		if time < item.due:
			still.append(item)
			continue
		var victim_car := item.victim.car
		var lost := 1.0 - victim_car.state.velocity.length() / maxf(item.victim_speed, 0.1)
		if lost >= rules.incident_victim_loss or not victim_car.state.on_track:
			_penalise(item.striker, item.victim, time)
	_pending = still


func _penalise(striker: Racer, victim: Racer, time: float) -> void:
	striker.incident_penalty += rules.incident_penalty
	striker.incidents += 1
	var lap := striker.laps.laps
	var repeat: bool = _last_penalty_lap.get(striker, -1) == lap
	_last_penalty_lap[striker] = lap
	if repeat:
		striker.ghost_until = maxf(striker.ghost_until, time + rules.repeat_ghost_time)
	penalised.emit(striker, victim, repeat)
