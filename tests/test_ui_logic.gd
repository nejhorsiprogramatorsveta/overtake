extends TestCase
## Small UI logic (validation 2026-11-22): Czech plural of laps behind, broken settings values.

const SettingsScript := preload("res://src/autoload/settings.gd")


func test_laps_behind_plural() -> void:
	check_eq(RaceHud.laps_behind(1), "+1 kolo", "one lap")
	check_eq(RaceHud.laps_behind(3), "+3 kola", "two to four laps")
	check_eq(RaceHud.laps_behind(7), "+7 kol", "five and more")


func test_broken_settings_values_fall_back_to_defaults() -> void:
	var config := ConfigFile.new()
	config.set_value("practice", "race_laps", "abc")
	config.set_value("practice", "tyre_wear", [1, 2])
	config.set_value("player", "name", 42)
	config.set_value("practice", "bot_count", 7.0)
	check_eq(SettingsScript._number(config, "practice", "race_laps", 5), 5, "text instead of a number")
	check_eq(SettingsScript._flag(config, "practice", "tyre_wear", false), false, "array instead of a bool")
	check_eq(SettingsScript._text(config, "player", "name", ""), "", "number instead of a name")
	check_eq(SettingsScript._number(config, "practice", "bot_count", 5), 7, "a float still counts")
