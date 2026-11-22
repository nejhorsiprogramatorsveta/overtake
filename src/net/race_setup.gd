class_name RaceSetup
## The host builds the starting grid of an online race (PLAN.md C): the people of the lobby and
## the bots, each with a name, a colour and a grid slot. Grid order of the people: at the back
## (default), random or at the front (host's grid setting), shuffled among themselves.

## Names of the computer drivers (invented).
const BOT_NAMES: Array[String] = ["Novák", "Rossi", "Müller", "Dubois", "Kowalski", "Hansen", "Silva",
		"Tanaka", "García", "Larsen", "Horvat"]


## settings = LobbyValidator.settings(...); returns the race setup dictionary sent to everyone.
static func build(lobby_players: Dictionary, settings: Dictionary, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var people: Array = lobby_players.keys()
	people.sort()
	_shuffle(people, rng)
	var bots: int = settings.bots
	var count := people.size() + bots
	var slots: Array = range(count)
	match int(settings.grid):
		0:  # people at the back
			slots = range(bots, count) + range(bots)
		1:
			_shuffle(slots, rng)
	var used_colors: Dictionary[int, bool] = {}
	var cars: Array[Dictionary] = []
	for i in people.size():
		var peer: int = people[i]
		var color: int = lobby_players[peer].color
		used_colors[color] = true
		cars.append({"peer": peer, "name": lobby_players[peer].name, "color": color, "slot": slots[i]})
	var free: Array[int] = []
	for c in CarColors.COLORS.size():
		if not used_colors.has(c):
			free.append(c)
	for b in bots:
		var color := free[b % free.size()] if not free.is_empty() else b % CarColors.COLORS.size()
		cars.append({"peer": 0, "name": BOT_NAMES[b % BOT_NAMES.size()], "color": color, "slot": slots[people.size() + b]})
	return {"settings": settings, "seed": seed_value, "cars": cars}


static func _shuffle(values: Array, rng: RandomNumberGenerator) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: Variant = values[i]
		values[i] = values[j]
		values[j] = swap
