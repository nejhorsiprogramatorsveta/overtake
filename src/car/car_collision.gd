class_name CarCollision
## Soft contact between cars (PLAN.md B, user 2026-11-22: protection against intentional
## collisions). A car is a capsule (rounded rectangle). Overlapping cars are pushed apart and
## their speeds along the contact exchanged with little bounce, but:
## - in a hit from behind the HITTING car takes most of the speed change (rear_striker_share), the
##   car in front is barely nudged and keeps its line;
## - the sideways speed a contact can give is limited (max_side_push), so shoving someone off
##   the track is hard.
## Deterministic, no scene access; the race passes the cars that may touch (no ghosts).

## Result of one contact, for the incident judge.
class Contact:
	extends RefCounted
	var a: int
	var b: int
	## Closing speed along the contact normal (m/s, > 0 = approaching).
	var closing_speed := 0.0
	## Index of the car that drove into the other (-1 = side by side, nobody to blame).
	var striker := -1


## Resolves all overlapping pairs once; returns the contacts that happened.
static func resolve(states: Array[CarState], tuning: CarTuning, rules: RaceRules) -> Array[Contact]:
	var contacts: Array[Contact] = []
	for i in states.size():
		for j in range(i + 1, states.size()):
			var contact := _resolve_pair(states[i], states[j], tuning, rules)
			if contact:
				contact.a = i
				contact.b = j
				contacts.append(contact)
	return contacts


static func _resolve_pair(a: CarState, b: CarState, tuning: CarTuning, rules: RaceRules) -> Contact:
	var radius := tuning.width * 0.5
	var reach := tuning.length * 0.5 - radius
	if a.position.distance_squared_to(b.position) > pow(tuning.length + 0.5, 2.0):
		return null
	var a0 := a.position - a.forward() * reach
	var a1 := a.position + a.forward() * reach
	var b0 := b.position - b.forward() * reach
	var b1 := b.position + b.forward() * reach
	var closest := Geometry2D.get_closest_points_between_segments(a0, a1, b0, b1)
	var delta: Vector2 = closest[1] - closest[0]
	var distance := delta.length()
	if distance >= radius * 2.0:
		return null
	var normal := delta / distance if distance > 0.0001 else (b.position - a.position).normalized()
	# Push apart.
	var overlap := radius * 2.0 - distance
	a.position -= normal * overlap * 0.5
	b.position += normal * overlap * 0.5
	var contact := Contact.new()
	var approach_a := a.velocity.dot(normal)
	var approach_b := -b.velocity.dot(normal)
	contact.closing_speed = approach_a + approach_b
	if contact.closing_speed <= 0.0:
		return contact  # already separating
	# Who drove into whom: a car whose nose points at the other and closes much faster.
	var share_a := 0.5
	if approach_a > approach_b + 2.0 and a.forward().dot(normal) > 0.5:
		contact.striker = 0
		share_a = rules.rear_striker_share
	elif approach_b > approach_a + 2.0 and b.forward().dot(-normal) > 0.5:
		contact.striker = 1
		share_a = 1.0 - rules.rear_striker_share
	var impulse := contact.closing_speed * (1.0 + rules.contact_restitution)
	a.velocity -= _limit_side(a, normal * impulse * share_a, rules)
	b.velocity += _limit_side(b, normal * impulse * (1.0 - share_a), rules)
	return contact


## Caps the part of a speed change that is sideways to the car.
static func _limit_side(state: CarState, change: Vector2, rules: RaceRules) -> Vector2:
	var forward := state.forward()
	var along := forward * change.dot(forward)
	var side := (change - along).limit_length(rules.max_side_push)
	return along + side
