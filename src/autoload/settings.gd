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
## The last address typed to join an online game ("ip:port#CODE").
var last_join := ""
## Qualifying before an offline race (session setting).
var qualifying := false


func _ready() -> void:
	KeyBindings.capture_defaults()
	var config := ConfigFile.new()
	if config.load(FILE_PATH) != OK:
		return
	# Typed reads: a hand-edited or broken file falls back to the defaults value by value.
	player_name = _text(config, "player", "name", "").left(16)
	practice_track = _text(config, "practice", "track", "")
	tyre_wear = _flag(config, "practice", "tyre_wear", false)
	car_color = clampi(_number(config, "player", "car_color", 0), 0, CarColors.COLORS.size() - 1)
	race_laps = clampi(_number(config, "practice", "race_laps", 5), 1, 30)
	bot_count = clampi(_number(config, "practice", "bot_count", 5), 0, 11)
	bot_difficulty = clampi(_number(config, "practice", "bot_difficulty", 1), 0, 3)
	grid_start = clampi(_number(config, "practice", "grid_start", 0), 0, 2)
	qualifying = _flag(config, "practice", "qualifying", false)
	last_join = _text(config, "online", "last_join", "").left(120)
	# Rebound controls (settings screen); unknown or broken values keep the defaults.
	var controls := {}
	if config.has_section("controls"):
		for action in config.get_section_keys("controls"):
			controls[action] = config.get_value("controls", action, PackedStringArray())
	KeyBindings.apply(controls)


static func _number(config: ConfigFile, section: String, key: String, default: int) -> int:
	var value: Variant = config.get_value(section, key, default)
	return int(value) if typeof(value) in [TYPE_INT, TYPE_FLOAT] else default


static func _flag(config: ConfigFile, section: String, key: String, default: bool) -> bool:
	var value: Variant = config.get_value(section, key, default)
	return value if typeof(value) == TYPE_BOOL else default


static func _text(config: ConfigFile, section: String, key: String, default: String) -> String:
	var value: Variant = config.get_value(section, key, default)
	return value if typeof(value) == TYPE_STRING else default


func save() -> void:
	var config := ConfigFile.new()
	config.set_value("player", "name", player_name)
	config.set_value("practice", "track", practice_track)
	config.set_value("practice", "tyre_wear", tyre_wear)
	config.set_value("practice", "race_laps", race_laps)
	config.set_value("practice", "bot_count", bot_count)
	config.set_value("practice", "bot_difficulty", bot_difficulty)
	config.set_value("practice", "grid_start", grid_start)
	config.set_value("practice", "qualifying", qualifying)
	config.set_value("player", "car_color", car_color)
	config.set_value("online", "last_join", last_join)
	config.set_value("meta", "controls_version", KeyBindings.VERSION)
	var controls := KeyBindings.serialize()
	for action: String in controls:
		config.set_value("controls", action, controls[action])
	config.save(FILE_PATH)
