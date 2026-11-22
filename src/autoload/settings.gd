extends Node
## AUTOLOAD "Settings": user preferences saved in user://settings.cfg
## (a per-user folder that Godot resolves correctly on Windows, macOS and Linux).

const FILE_PATH := "user://settings.cfg"

var player_name := ""
## Track for practice and the host's first lobby track; empty = default.
var practice_track := ""
## Tyre wear in offline sessions (the host chooses it for online races, M4).
var tyre_wear := false
## Car colour (CarColors index) and laps of an offline race.
var car_color := 0
var race_laps := 5
## Offline race: number of bots, their difficulty (BotDriver.Difficulty) and the player's
## grid slot (0 = back, 1 = random, 2 = pole).
var bot_count := 5
var bot_difficulty := 1
var grid_start := 0


func _ready() -> void:
	KeyBindings.capture_defaults()
	var config := ConfigFile.new()
	if config.load(FILE_PATH) != OK:
		return
	player_name = str(config.get_value("player", "name", ""))
	practice_track = str(config.get_value("practice", "track", ""))
	tyre_wear = bool(config.get_value("practice", "tyre_wear", false))
	car_color = clampi(int(config.get_value("player", "car_color", 0)), 0, CarColors.COLORS.size() - 1)
	race_laps = clampi(int(config.get_value("practice", "race_laps", 5)), 1, 30)
	bot_count = clampi(int(config.get_value("practice", "bot_count", 5)), 0, 11)
	bot_difficulty = clampi(int(config.get_value("practice", "bot_difficulty", 1)), 0, 3)
	grid_start = clampi(int(config.get_value("practice", "grid_start", 0)), 0, 2)
	# Rebound controls (settings screen); unknown or broken values keep the defaults.
	var controls := {}
	if config.has_section("controls"):
		for action in config.get_section_keys("controls"):
			controls[action] = config.get_value("controls", action, PackedStringArray())
	KeyBindings.apply(controls)


func save() -> void:
	var config := ConfigFile.new()
	config.set_value("player", "name", player_name)
	config.set_value("practice", "track", practice_track)
	config.set_value("practice", "tyre_wear", tyre_wear)
	config.set_value("practice", "race_laps", race_laps)
	config.set_value("practice", "bot_count", bot_count)
	config.set_value("practice", "bot_difficulty", bot_difficulty)
	config.set_value("practice", "grid_start", grid_start)
	config.set_value("player", "car_color", car_color)
	config.set_value("meta", "controls_version", KeyBindings.VERSION)
	var controls := KeyBindings.serialize()
	for action: String in controls:
		config.set_value("controls", action, controls[action])
	config.save(FILE_PATH)
