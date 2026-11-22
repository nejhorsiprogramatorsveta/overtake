extends TestCase
## Rebindable controls (KeyBindings); every test restores the defaults.


func _key(physical: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = physical
	event.pressed = true
	return event


func test_codes_roundtrip_and_reject_garbage() -> void:
	check_eq(KeyBindings.encode(KeyBindings.decode("key:65")), "key:65", "key code")
	check_eq(KeyBindings.encode(KeyBindings.decode("mouse:2")), "mouse:2", "mouse button")
	for bad in ["", "key", "key:abc", "mouse:99", "pad:1", "key:%d" % KEY_ESCAPE, "key:-5"]:
		check(KeyBindings.decode(bad) == null, "rejected: " + bad)


func test_defaults_are_wasd_space_and_k() -> void:
	KeyBindings.reset_to_defaults()
	var saved := KeyBindings.serialize()
	check_eq(saved["throttle"], PackedStringArray(["key:%d" % KEY_W]), "throttle: W")
	check_eq(saved["brake"], PackedStringArray(["key:%d" % KEY_S]), "brake: S")
	check_eq(saved["steer_left"], PackedStringArray(["key:%d" % KEY_A]), "left: A")
	check_eq(saved["steer_right"], PackedStringArray(["key:%d" % KEY_D]), "right: D")
	check_eq(saved["clutch"], PackedStringArray(["key:%d" % KEY_SPACE]), "clutch: Space")
	check_eq(saved["kers"], PackedStringArray(["key:%d" % KEY_K]), "KERS: K")


func test_bind_moves_a_key_away_from_other_actions() -> void:
	KeyBindings.reset_to_defaults()
	KeyBindings.bind(&"kers", 1, _key(KEY_W))
	check(KeyBindings.events(&"throttle").is_empty(), "W no longer accelerates")
	check_eq(KeyBindings.serialize()["kers"], PackedStringArray(["key:%d" % KEY_K, "key:%d" % KEY_W]), "KERS on K and W")
	KeyBindings.reset_to_defaults()


func test_saved_bindings_apply_and_broken_ones_keep_defaults() -> void:
	KeyBindings.reset_to_defaults()
	var defaults := KeyBindings.serialize()
	KeyBindings.apply({"kers": PackedStringArray(["key:%d" % KEY_L]), "throttle": PackedStringArray(["garbage"]), "brake": 5})
	check_eq(KeyBindings.serialize()["kers"], PackedStringArray(["key:%d" % KEY_L]), "saved key applied")
	check_eq(KeyBindings.serialize()["throttle"], defaults["throttle"], "broken entry keeps the default")
	check_eq(KeyBindings.serialize()["brake"], defaults["brake"], "wrong type ignored")
	KeyBindings.reset_to_defaults()
	check_eq(KeyBindings.serialize(), defaults, "reset restores everything")


func test_default_does_not_steal_a_used_key() -> void:
	KeyBindings.reset_to_defaults()
	KeyBindings.apply({"brake": PackedStringArray(["key:%d" % KEY_K])})
	check_eq(KeyBindings.serialize()["brake"], PackedStringArray(["key:%d" % KEY_K]), "the player's K stays on the brake")
	check(KeyBindings.events(&"kers").is_empty(), "KERS (not in the save) stays unbound instead of sharing K")
	KeyBindings.reset_to_defaults()


func test_reserved_keys_and_labels() -> void:
	check(not KeyBindings.is_bindable(_key(KEY_ESCAPE)), "Esc stays reserved")
	check(not KeyBindings.is_bindable(_key(KEY_F3)), "F3 stays reserved")
	check(KeyBindings.is_bindable(_key(KEY_Q)), "normal key")
	check_eq(KeyBindings.display(_key(KEY_SPACE)), tr("KEY_SPACE"), "space label translated")
	for action in KeyBindings.ACTIONS:
		check(not KeyBindings.action_text(action).is_empty(), "help text for " + action)
