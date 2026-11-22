extends TestCase
## Updater (manifest validation) and UpdateInstaller (file swapping, on a temporary folder).

const SHA := "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

var dir := OS.get_user_data_dir().path_join("test_updater")


func _fresh_dir() -> void:
	UpdateInstaller.remove_tree(dir)
	DirAccess.make_dir_recursive_absolute(dir)


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	FileAccess.open(path, FileAccess.WRITE).store_string(text)


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _manifest(url: String, sha: String = SHA, build: Variant = 30) -> String:
	return JSON.stringify({"version": "0.2.0", "build": build, "files": {"windows": {"url": url, "sha256": sha}}})


func test_manifest_accepts_only_this_repository() -> void:
	var good := Updater.ALLOWED_URL_PREFIX + "release/overtake-windows.exe"
	var info := Updater.parse_manifest(_manifest(good), "windows")
	check_eq([info.get("version"), info.get("build"), info.get("url")], ["0.2.0", 30, good], "valid manifest")
	check(Updater.parse_manifest(_manifest("https://evil.example/game.exe"), "windows").is_empty(), "foreign URL rejected")
	check(Updater.parse_manifest(_manifest(good, "abc"), "windows").is_empty(), "bad checksum rejected")
	check(Updater.parse_manifest(_manifest(good, SHA, "30"), "windows").is_empty(), "build must be a number")
	check(Updater.parse_manifest(_manifest(good), "macos").is_empty(), "missing platform")
	check(Updater.parse_manifest("not json", "windows").is_empty(), "garbage")


func test_only_a_newer_build_from_a_successful_response_is_offered() -> void:
	var updater := Updater.new()
	var platform := UpdateInstaller.platform_key()
	var url := Updater.ALLOWED_URL_PREFIX + "release/overtake-" + platform
	var manifest := func(build: int) -> PackedByteArray:
		return JSON.stringify({"version": "9.9.9", "build": build, "files": {platform: {"url": url, "sha256": SHA}}}).to_utf8_buffer()
	var newer: PackedByteArray = manifest.call(BuildInfo.build + 1)
	check_eq(updater.newer_build(HTTPRequest.RESULT_SUCCESS, 200, newer).get("build"), BuildInfo.build + 1, "newer build offered")
	check(updater.newer_build(HTTPRequest.RESULT_SUCCESS, 200, manifest.call(BuildInfo.build)).is_empty(), "same build ignored")
	check(updater.newer_build(HTTPRequest.RESULT_SUCCESS, 404, newer).is_empty(), "missing manifest ignored")
	check(updater.newer_build(HTTPRequest.RESULT_CANT_CONNECT, 0, newer).is_empty(), "offline ignored")
	updater._http.free()  # only becomes a child in _ready
	updater.free()


func test_replace_file_keeps_old_version_aside() -> void:
	_fresh_dir()
	_write(dir.path_join("game.exe"), "old")
	_write(dir.path_join("download"), "new")
	check_eq(UpdateInstaller.replace_file(dir.path_join("download"), dir.path_join("game.exe")), OK, "swap succeeds")
	check_eq(_read(dir.path_join("game.exe")), "new", "new version in place")
	check_eq(_read(dir.path_join("game.exe.old")), "old", "old version moved aside")


func test_failed_swap_restores_the_working_version() -> void:
	_fresh_dir()
	_write(dir.path_join("game.exe"), "old")
	var error := UpdateInstaller.replace_file(dir.path_join("missing_download"), dir.path_join("game.exe"))
	check(error != OK, "missing download fails")
	check_eq(_read(dir.path_join("game.exe")), "old", "game still there")


func test_linux_extracts_binary_from_zip() -> void:
	_fresh_dir()
	var zip := ZIPPacker.new()
	zip.open(dir.path_join("linux.zip"))
	zip.start_file("overtake.x86_64")
	zip.write_file("binary".to_utf8_buffer())
	zip.close_file()
	zip.close()
	_write(dir.path_join("overtake.x86_64"), "old binary")
	check_eq(UpdateInstaller.install(dir.path_join("linux.zip"), "linux", dir.path_join("overtake.x86_64")), OK, "install succeeds")
	check_eq(_read(dir.path_join("overtake.x86_64")), "binary", "binary replaced")


func test_macos_swaps_app_bundle_and_ignores_escaping_paths() -> void:
	_fresh_dir()
	_write(dir.path_join("overtake.app/Contents/MacOS/overtake"), "old app")
	var zip := ZIPPacker.new()
	zip.open(dir.path_join("macos.zip"))
	for entry: String in ["overtake.app/Contents/MacOS/overtake", "overtake.app/Contents/Info.plist", "../evil.txt"]:
		zip.start_file(entry)
		zip.write_file(("new " + entry).to_utf8_buffer())
		zip.close_file()
	zip.close()
	check_eq(UpdateInstaller.install(dir.path_join("macos.zip"), "macos", dir.path_join("overtake.app")), OK, "install succeeds")
	check_eq(_read(dir.path_join("overtake.app/Contents/MacOS/overtake")), "new overtake.app/Contents/MacOS/overtake", "new bundle in place")
	check(FileAccess.file_exists(dir.path_join("overtake.app/Contents/Info.plist")), "whole bundle extracted")
	check_eq(_read(dir.path_join("overtake.app.old/Contents/MacOS/overtake")), "old app", "old bundle moved aside")
	check(not FileAccess.file_exists(dir.get_base_dir().path_join("evil.txt")), "zip entry with .. is not written")
	check(not DirAccess.dir_exists_absolute(dir.path_join("overtake.update.staging")), "staging folder cleaned up")
	UpdateInstaller.remove_tree(dir)
