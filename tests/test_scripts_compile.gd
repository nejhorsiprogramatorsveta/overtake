extends TestCase
## Every game script must compile (a parse error in a script no test uses would otherwise only
## show up when that screen is opened).


func test_every_script_in_src_compiles() -> void:
	var pending: PackedStringArray = ["res://src"]
	var count := 0
	while not pending.is_empty():
		var dir := pending[pending.size() - 1]
		pending.remove_at(pending.size() - 1)
		for sub in DirAccess.get_directories_at(dir):
			pending.append(dir.path_join(sub))
		for file_name in DirAccess.get_files_at(dir):
			if file_name.get_extension() != "gd":
				continue
			var script := load(dir.path_join(file_name)) as GDScript
			check(script != null and script.can_instantiate(), "compiles: " + dir.path_join(file_name))
			count += 1
	check(count > 30, "found the game scripts (%d)" % count)
