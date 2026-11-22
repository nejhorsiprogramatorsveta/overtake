class_name UpdateInstaller
extends RefCounted
## Swaps a downloaded, already verified update in place of the running game (PLAN.md I.8).
## Static, so it can be tested on temporary folders. Updater does the download and checksum.

const DOWNLOAD_NAME := "overtake.update"
const OLD_SUFFIX := ".old"
## rwxr-xr-x (octal 755): the new game binary must stay executable on macOS/Linux.
const EXECUTABLE_PERMISSIONS := 493


static func platform_key() -> String:
	match OS.get_name():
		"Windows": return "windows"
		"macOS": return "macos"
		_: return "linux"


## The running game: the .exe/binary, or the .app bundle on macOS.
static func install_target() -> String:
	var executable := OS.get_executable_path()
	if platform_key() == "macos":
		return executable.get_base_dir().get_base_dir().get_base_dir()  # .../X.app
	return executable


static func install_directory() -> String:
	return install_target().get_base_dir()


static func install(download_path: String, platform: String, target: String = install_target()) -> Error:
	match platform:
		"windows":
			return replace_file(download_path, target)
		"linux":
			var binary := download_path + ".bin"
			var error := extract_single_file(download_path, target.get_file(), binary)
			if error == OK:
				error = replace_file(binary, target)
			DirAccess.remove_absolute(binary)
			return error
		_:
			return replace_macos_app(download_path, target)


## Swaps `new_file` into `target`. A running executable cannot be overwritten, but it can
## be renamed, so the old one is moved aside and deleted on the next start.
static func replace_file(new_file: String, target: String) -> Error:
	var old := target + OLD_SUFFIX
	DirAccess.remove_absolute(old)
	var error := DirAccess.rename_absolute(target, old)
	if error != OK:
		return error
	error = DirAccess.rename_absolute(new_file, target)
	if error != OK:
		DirAccess.rename_absolute(old, target)  # put the working version back
		return error
	FileAccess.set_unix_permissions(target, EXECUTABLE_PERMISSIONS)
	return OK


static func extract_single_file(zip_path: String, file_name: String, destination: String) -> Error:
	var zip := ZIPReader.new()
	if zip.open(zip_path) != OK:
		return ERR_FILE_CANT_OPEN
	var error := ERR_FILE_NOT_FOUND
	for entry in zip.get_files():
		if entry.get_file() == file_name:
			var out := FileAccess.open(destination, FileAccess.WRITE)
			if out:
				out.store_buffer(zip.read_file(entry))
				out.close()
				error = OK
			else:
				error = ERR_FILE_CANT_WRITE
	zip.close()
	return error


## Unpacks the new .app next to the running one, then swaps the bundles.
static func replace_macos_app(zip_path: String, app_path: String) -> Error:
	var staging := app_path.get_base_dir().path_join("overtake.update.staging")
	remove_tree(staging)
	var zip := ZIPReader.new()
	if zip.open(zip_path) != OK:
		return ERR_FILE_CANT_OPEN
	var new_app := ""
	for entry in zip.get_files():
		# Never write outside the staging folder, whatever the archive contains.
		if entry.contains("..") or entry.begins_with("/"):
			continue
		var path := staging.path_join(entry)
		if entry.ends_with("/"):
			DirAccess.make_dir_recursive_absolute(path)
			continue
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var out := FileAccess.open(path, FileAccess.WRITE)
		if out == null:
			zip.close()
			remove_tree(staging)
			return ERR_FILE_CANT_WRITE
		out.store_buffer(zip.read_file(entry))
		out.close()
		if entry.contains(".app/Contents/MacOS/"):
			FileAccess.set_unix_permissions(path, EXECUTABLE_PERMISSIONS)
		if new_app.is_empty() and entry.contains(".app/"):
			new_app = staging.path_join(entry.substr(0, entry.find(".app/") + 4))
	zip.close()
	var error := ERR_FILE_NOT_FOUND
	if not new_app.is_empty():
		error = replace_file(new_app, app_path)
	remove_tree(staging)
	return error


## Removes leftovers of a previous update: the old version moved aside, and a partial
## download or staging folder if the game was closed during an update.
static func cleanup_old_files() -> void:
	var directory := install_directory()
	for leftover in [install_target() + OLD_SUFFIX, directory.path_join(DOWNLOAD_NAME),
			directory.path_join(DOWNLOAD_NAME + ".bin"), directory.path_join("overtake.update.staging")]:
		remove_tree(leftover)


static func remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.remove_absolute(path)
		return
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	for dir in DirAccess.get_directories_at(path):
		remove_tree(path.path_join(dir))
	DirAccess.remove_absolute(path)
