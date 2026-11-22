extends TestCase
## Online building blocks (M4, PLAN.md C and S): lobby data checks, the host's grid, the binary
## car states (malformed data is dropped as a whole).


func _players() -> Dictionary:
	return {1: {"name": "Host", "color": 0}, 7: {"name": "Pepa", "color": 3}}


func test_players_are_checked() -> void:
	check_eq(LobbyValidator.players(_players()).size(), 2, "valid lobby")
	check(LobbyValidator.players({7: {"name": "Pepa", "color": 3}}).is_empty(), "the host must be there")
	check(LobbyValidator.players({1: {"name": "A", "color": 2}, 5: {"name": "B", "color": 2}}).is_empty(), "colours are unique")
	check(LobbyValidator.players({1: {"name": "A", "color": 99}}).is_empty(), "colour index in range")
	check(LobbyValidator.players({1: {"name": "x".repeat(40), "color": 0}}).is_empty(), "name length limited")
	check(LobbyValidator.players({1: {"name": "A", "color": "0"}}).is_empty(), "wrong types rejected")
	var many := {}
	for i in LobbyValidator.MAX_PLAYERS + 1:
		many[i + 1] = {"name": "P%d" % i, "color": i % CarColors.COLORS.size()}
	check(LobbyValidator.players(many).is_empty(), "at most MAX_PLAYERS")


func test_free_colour() -> void:
	var lobby := _players()
	check_eq(LobbyValidator.free_color(lobby, 5), 5, "a free colour is given")
	check_eq(LobbyValidator.free_color(lobby, 3), 1, "a taken colour -> the first free one")
	check_eq(LobbyValidator.free_color(lobby, 3, 7), 3, "keeping the own colour is fine")


func test_settings_are_clamped() -> void:
	var settings := LobbyValidator.settings({"track": "china", "laps": 99, "tyre_wear": true, "bots": 20,
			"difficulty": 9, "grid": 1}, 3)
	check_eq(settings.laps, LobbyValidator.MAX_LAPS, "laps clamped")
	check_eq(settings.bots, LobbyValidator.MAX_CARS - 3, "at most 12 cars with the people")
	check_eq(settings.difficulty, 3, "difficulty clamped")
	check(LobbyValidator.settings({"track": "mars", "laps": 3, "tyre_wear": false, "bots": 0, "difficulty": 0, "grid": 0}, 1).is_empty(), "unknown track")
	check(LobbyValidator.settings({"track": "china"}, 1).is_empty(), "missing fields")


func test_host_grid_and_its_check() -> void:
	var lobby := _players()
	var settings := LobbyValidator.settings({"track": "austria", "laps": 3, "tyre_wear": false, "bots": 4, "difficulty": 1, "grid": 0}, 2)
	var setup := RaceSetup.build(lobby, settings, 1234)
	var checked := LobbyValidator.race_setup(setup, lobby)
	check_eq(checked.cars.size(), 6, "2 people + 4 bots")
	var slots := {}
	var colors := {}
	for car: Dictionary in checked.cars:
		slots[car.slot] = true
		colors[car.color] = true
		if car.peer != 0:
			check(car.slot >= 4, "people start at the back (slot %d)" % car.slot)
	check_eq(slots.size(), 6, "unique grid slots")
	check_eq(colors.size(), 6, "every car its own colour")
	check_eq(RaceSetup.build(lobby, settings, 1234), setup, "same seed, same grid")
	var missing := setup.duplicate(true)
	missing.cars.remove_at(0)
	check(LobbyValidator.race_setup(missing, lobby).is_empty(), "every person must be in the race")
	var doubled := setup.duplicate(true)
	doubled.cars[1].slot = doubled.cars[0].slot
	check(LobbyValidator.race_setup(doubled, lobby).is_empty(), "no shared slot")


func _net_car() -> CarCodec.NetCar:
	var car := CarCodec.NetCar.new()
	car.position = Vector2(123.5, -456.25)
	car.heading = 1.25
	car.velocity = Vector2(40.0, -3.0)
	car.steer = -0.5
	car.flags = CarCodec.FLAG_BRAKE | CarCodec.FLAG_IN_PIT
	return car


func test_client_state_round_trip() -> void:
	var data := CarCodec.encode_client(65535 + 7, _net_car())
	check_eq(data.size(), CarCodec.CLIENT_BYTES, "fixed size")
	var decoded := CarCodec.decode_client(data)
	check_eq(decoded[0], 6, "sequence wraps at 16 bits")
	var car: CarCodec.NetCar = decoded[1]
	check(car.position.is_equal_approx(Vector2(123.5, -456.25)) and is_equal_approx(car.heading, 1.25), "position and heading")
	check(absf(car.steer + 0.5) < 0.01 and car.has(CarCodec.FLAG_IN_PIT) and not car.has(CarCodec.FLAG_KERS), "steer and flags")


func test_snapshot_round_trip_and_bad_data() -> void:
	var data := CarCodec.encode_snapshot(42, {0: _net_car(), 3: _net_car()})
	var decoded := CarCodec.decode_snapshot(data, 4)
	check_eq(decoded[0], 42, "tick")
	check_eq((decoded[1] as Dictionary).size(), 2, "two cars")
	check(CarCodec.decode_snapshot(data, 3).is_empty(), "car index beyond the race")
	check(CarCodec.decode_snapshot(data.slice(0, data.size() - 1), 4).is_empty(), "truncated")
	check(CarCodec.decode_client(PackedByteArray([1, 2, 3])).is_empty(), "garbage")
	var fast := _net_car()
	fast.velocity = Vector2(1000.0, 0.0)
	check(CarCodec.decode_client(CarCodec.encode_client(1, fast)).is_empty(), "impossible speed")
	var nan := _net_car()
	nan.position = Vector2(NAN, 0.0)
	check(CarCodec.decode_client(CarCodec.encode_client(1, nan)).is_empty(), "not a number")
