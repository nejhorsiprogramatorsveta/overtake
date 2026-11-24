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


## User 2026-11-24: "Jak hrát" cut-outs - framing puts the chosen world points inside the
## picture (the whole screen is checked by a smoke run: tests run before the tree is ready).
func test_help_shot_frames_its_points() -> void:
	var shot := HelpShot.new()
	var points := PackedVector2Array([Vector2(100, 200), Vector2(260, 240), Vector2(180, 150)])
	shot.frame(points, 10.0)
	for p in points:
		var screen := shot.to_screen(p)
		check(screen.x >= 0.0 and screen.y >= 0.0 and screen.x <= HelpShot.SIZE.x and screen.y <= HelpShot.SIZE.y, "point %s inside (%s)" % [p, screen])
	check(shot.to_screen(shot.centre).is_equal_approx(Vector2(HelpShot.SIZE) * 0.5), "centre in the middle")
	shot.free()
