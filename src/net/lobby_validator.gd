class_name LobbyValidator
## Checks lobby and race-setup data before Session uses it (PLAN.md section S, defense in depth).
## Clients only accept these messages from the host, but a buggy or modified host must still not
## be able to break the game with huge or malformed data. Invalid input -> empty result.

## Up to 8 people (PLAN.md C), together with the bots at most 12 cars.
const MAX_PLAYERS := 8
const MAX_CARS := 12
const MAX_NAME_LENGTH := 16
const MAX_LAPS := 30


## Trims a requested player name; empty names become "Hráč N".
static func clean_name(raw_name: String, number: int) -> String:
	var cleaned := raw_name.strip_edges().left(MAX_NAME_LENGTH)
	if cleaned.is_empty():
		cleaned = TranslationServer.translate("LOBBY_DEFAULT_NAME").format({"number": number})
	return cleaned


## peer_id -> {"name": String, "color": int (CarColors index, unique)}; must contain the host.
static func players(raw: Dictionary) -> Dictionary[int, Dictionary]:
	var result: Dictionary[int, Dictionary] = {}
	if raw.size() < 1 or raw.size() > MAX_PLAYERS or not raw.has(1):
		return result
	var used: Dictionary[int, bool] = {}
	for peer_id: Variant in raw:
		var entry: Variant = raw[peer_id]
		if typeof(peer_id) != TYPE_INT or peer_id <= 0 or typeof(entry) != TYPE_DICTIONARY:
			return {}
		var player_name: Variant = entry.get("name")
		if typeof(player_name) != TYPE_STRING or player_name.strip_edges().is_empty() or player_name.length() > MAX_NAME_LENGTH:
			return {}
		var color: Variant = entry.get("color")
		if typeof(color) != TYPE_INT or color < 0 or color >= CarColors.COLORS.size() or used.has(color):
			return {}
		used[color] = true
		result[peer_id] = {"name": player_name, "color": color}
	return result


## A free car colour: the preferred one if nobody has it, else the first free one.
static func free_color(lobby_players: Dictionary, preferred: int, except_peer: int = -1) -> int:
	var used: Dictionary[int, bool] = {}
	for peer_id: int in lobby_players:
		if peer_id != except_peer:
			used[int(lobby_players[peer_id].color)] = true
	if preferred >= 0 and preferred < CarColors.COLORS.size() and not used.has(preferred):
		return preferred
	for i in CarColors.COLORS.size():
		if not used.has(i):
			return i
	return 0


## Race settings chosen by the host: {"track": String, "laps": int, "tyre_wear": bool,
## "bots": int, "difficulty": int, "grid": int, "qualifying": bool (optional, default off)}. Bots are cut so the grid has at most MAX_CARS.
static func settings(raw: Dictionary, human_count: int) -> Dictionary:
	var track: Variant = raw.get("track")
	var laps: Variant = raw.get("laps")
	var wear: Variant = raw.get("tyre_wear")
	var bots: Variant = raw.get("bots")
	var difficulty: Variant = raw.get("difficulty")
	var grid: Variant = raw.get("grid")
	var qualifying: Variant = raw.get("qualifying", false)
	if typeof(qualifying) != TYPE_BOOL:
		return {}
	if typeof(track) != TYPE_STRING or not TrackCatalog.has(track) or typeof(laps) != TYPE_INT \
			or typeof(wear) != TYPE_BOOL or typeof(bots) != TYPE_INT or typeof(difficulty) != TYPE_INT \
			or typeof(grid) != TYPE_INT:
		return {}
	return {"track": track, "laps": clampi(laps, 1, MAX_LAPS), "tyre_wear": wear,
			"bots": clampi(bots, 0, maxi(MAX_CARS - human_count, 0)), "difficulty": clampi(difficulty, 0, 3),
			"grid": clampi(grid, 0, 2), "qualifying": qualifying}


## Grid after qualifying: a PackedByteArray with every car index 0..count-1 exactly once
## (pole first). Anything else -> [].
static func grid_order(raw: Variant, count: int) -> Array[int]:
	var order: Array[int] = []
	if typeof(raw) != TYPE_PACKED_BYTE_ARRAY or raw.size() != count or count > MAX_CARS:
		return order
	for value: int in raw:
		if value >= count or order.has(value):
			order.clear()
			return order
		order.append(value)
	return order


## The race the host started: {"settings": settings, "seed": int, "cars": [{"peer": int (0 = bot),
## "name": String, "color": int, "slot": int}]}. Every human of the lobby exactly once, slots unique.
static func race_setup(raw: Dictionary, lobby_players: Dictionary) -> Dictionary:
	var settings_raw: Variant = raw.get("settings")
	var seed_value: Variant = raw.get("seed")
	var cars: Variant = raw.get("cars")
	if typeof(settings_raw) != TYPE_DICTIONARY or typeof(seed_value) != TYPE_INT or typeof(cars) != TYPE_ARRAY:
		return {}
	var checked_settings := settings(settings_raw, lobby_players.size())
	if checked_settings.is_empty() or cars.size() < 1 or cars.size() > MAX_CARS:
		return {}
	var result_cars: Array[Dictionary] = []
	var slots: Dictionary[int, bool] = {}
	var humans: Dictionary[int, bool] = {}
	for car: Variant in cars:
		if typeof(car) != TYPE_DICTIONARY:
			return {}
		var peer: Variant = car.get("peer")
		var car_name: Variant = car.get("name")
		var color: Variant = car.get("color")
		var slot: Variant = car.get("slot")
		if typeof(peer) != TYPE_INT or typeof(car_name) != TYPE_STRING or typeof(color) != TYPE_INT \
				or typeof(slot) != TYPE_INT or car_name.length() > MAX_NAME_LENGTH or car_name.is_empty() \
				or color < 0 or color >= CarColors.COLORS.size() or slot < 0 or slot >= MAX_CARS or slots.has(slot):
			return {}
		if peer != 0 and (not lobby_players.has(peer) or humans.has(peer)):
			return {}
		slots[slot] = true
		if peer != 0:
			humans[peer] = true
		result_cars.append({"peer": peer, "name": car_name, "color": color, "slot": slot})
	if humans.size() != lobby_players.size():
		return {}
	return {"settings": checked_settings, "seed": seed_value, "cars": result_cars}
