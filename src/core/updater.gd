class_name Updater
extends Node
## In-game auto-update (PLAN.md I.8): checks version.json on GitHub, downloads the new
## build next to the running game, verifies its SHA-256, swaps it in and restarts.
## Security (PLAN.md section S): only files from this repository's GitHub releases over
## HTTPS are accepted, and nothing is replaced unless the checksum matches; on any
## failure the running version stays untouched.

signal update_available(info: Dictionary)
signal download_progress(fraction: float)
## Translated reason; the menu then offers the manual download page.
signal failed(message: String)

const REPO_URL := "https://github.com/nejhorsiprogramatorsveta/Overtake"
const MANIFEST_URL := REPO_URL + "/releases/latest/download/version.json"
const ALLOWED_URL_PREFIX := REPO_URL + "/releases/download/"
const DOWNLOADS_PAGE_URL := REPO_URL + "/releases"
const MAX_MANIFEST_BYTES := 16 * 1024
const DOWNLOAD_ATTEMPTS := 2
const RETRY_DELAY := 5.0

var _http := HTTPRequest.new()
## Debug builds only: `-- --update-test=http://127.0.0.1:8000/version.json` checks a local
## manifest (any URL allowed) and installs without asking, for end-to-end testing.
var _test_url := ""
var _info := {}
var _attempt := 0


func _ready() -> void:
	add_child(_http)
	if OS.is_debug_build():
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--update-test="):
				_test_url = arg.get_slice("=", 1)


## Only exported builds made by CI can update themselves (not editor/dev runs).
func is_supported() -> bool:
	if not _test_url.is_empty():
		return true
	return not OS.has_feature("editor") and BuildInfo.build > 0


func check() -> void:
	if is_supported():
		_request_manifest(_on_manifest_received)


func _request_manifest(callback: Callable) -> Error:
	var url := _test_url if not _test_url.is_empty() else MANIFEST_URL
	_http.download_file = ""
	_http.body_size_limit = MAX_MANIFEST_BYTES
	_http.request_completed.connect(callback, CONNECT_ONE_SHOT)
	var error := _http.request(url)
	if error != OK:
		_http.request_completed.disconnect(callback)
	return error


func _on_manifest_received(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var info := newer_build(result, code, body)
	if info.is_empty():
		return  # offline, no manifest yet or up to date: just play the current version
	_info = info
	if _test_url.is_empty():
		update_available.emit(info)
	else:
		download_and_install()


## The manifest response as {version, build, url, sha256} if it offers a newer build, else {}.
func newer_build(result: int, code: int, body: PackedByteArray) -> Dictionary:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return {}
	var info := parse_manifest(body.get_string_from_utf8(), UpdateInstaller.platform_key(), _test_url.is_empty())
	if info.is_empty() or info.build <= BuildInfo.build:
		return {}
	return info


## Returns {version, build, url, sha256} for `platform`, or {} if the manifest is invalid
## or points anywhere else than this repository's releases.
static func parse_manifest(text: String, platform: String, strict_urls: bool = true) -> Dictionary:
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary or not data.get("files") is Dictionary:
		return {}
	var file: Variant = data.files.get(platform)
	if not file is Dictionary:
		return {}
	var url := str(file.get("url", ""))
	var sha := str(file.get("sha256", "")).to_lower()
	var build: Variant = data.get("build")
	if not (build is float or build is int) or sha.length() != 64 or not sha.is_valid_hex_number():
		return {}
	if strict_urls and not url.begins_with(ALLOWED_URL_PREFIX):
		return {}
	return {"version": str(data.get("version", "?")), "build": int(build), "url": url, "sha256": sha}


## Reads the manifest again right before downloading: a release published after the game
## started replaces the files, so the checksum known since start-up would no longer match
## (seen in Gun game on 2026-11-17). A failed download is retried once.
func download_and_install() -> void:
	_attempt = 0
	_start_attempt()


func _start_attempt() -> void:
	_attempt += 1
	if _request_manifest(_on_fresh_manifest) != OK:
		_retry_or_fail("UPDATE_FAILED_DOWNLOAD")


func _on_fresh_manifest(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var info := newer_build(result, code, body)
	if info.is_empty():
		_retry_or_fail("UPDATE_FAILED_DOWNLOAD")
		return
	_info = info
	var target_dir := download_directory()
	if not DirAccess.dir_exists_absolute(target_dir):
		failed.emit(tr("UPDATE_FAILED_INSTALL"))
		return
	var download_path := target_dir.path_join(UpdateInstaller.DOWNLOAD_NAME)
	_http.download_file = download_path
	_http.body_size_limit = -1
	var callback := _on_download_finished.bind(download_path)
	_http.request_completed.connect(callback, CONNECT_ONE_SHOT)
	if _http.request(_info.url) != OK:
		_http.request_completed.disconnect(callback)
		_retry_or_fail("UPDATE_FAILED_DOWNLOAD")
		return
	set_process(true)


## While CI publishes, files are briefly missing or newer than the manifest: wait, then retry.
func _retry_or_fail(message_key: String) -> void:
	if _attempt < DOWNLOAD_ATTEMPTS:
		get_tree().create_timer(RETRY_DELAY).timeout.connect(_start_attempt, CONNECT_ONE_SHOT)
	else:
		failed.emit(tr(message_key))


## Where the update is downloaded: next to the game, so the final swap is a rename.
func download_directory() -> String:
	return UpdateInstaller.install_directory()


func _process(_delta: float) -> void:
	var total := _http.get_body_size()
	if total > 0:
		download_progress.emit(float(_http.get_downloaded_bytes()) / total)


func _on_download_finished(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray, download_path: String) -> void:
	set_process(false)
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		DirAccess.remove_absolute(download_path)
		_retry_or_fail("UPDATE_FAILED_DOWNLOAD")
		return
	if FileAccess.get_sha256(download_path) != _info.sha256:
		DirAccess.remove_absolute(download_path)
		_retry_or_fail("UPDATE_FAILED_VERIFY")
		return
	_install_and_restart(download_path)


func _install_and_restart(download_path: String) -> void:
	# Remember the path first: after the swap the OS reports the moved-aside old copy
	# as the running executable.
	var target := UpdateInstaller.install_target()
	var error := UpdateInstaller.install(download_path, UpdateInstaller.platform_key(), target)
	DirAccess.remove_absolute(download_path)
	if error != OK:
		failed.emit(tr("UPDATE_FAILED_INSTALL"))
		return
	_restart(target)


func _restart(target: String) -> void:
	if UpdateInstaller.platform_key() == "macos":
		OS.create_process("open", ["-n", target])
	else:
		OS.create_process(target, [])
	get_tree().quit()
