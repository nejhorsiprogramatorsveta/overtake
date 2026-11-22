extends Control
## Main menu: practice or race (each opens the session settings screen), online play (host, or
## join with the address the host shared: "ip:port#CODE"), settings, "Co je nového", quit,
## version and the in-game updater.

const SETTINGS_PATH := "res://src/ui/settings_screen.tscn"
const SETUP_PATH := "res://src/ui/session_setup.tscn"

@onready var _name_edit: LineEdit = %NameEdit
@onready var _practice_button: Button = %PracticeButton
@onready var _race_button: Button = %RaceButton
@onready var _changelog_button: Button = %ChangelogButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton
@onready var _host_button: Button = %HostButton
@onready var _join_edit: LineEdit = %JoinEdit
@onready var _join_button: Button = %JoinButton
@onready var _session_message: Label = %SessionMessage
@onready var _changelog_dialog: AcceptDialog = %ChangelogDialog
@onready var _changelog_text: RichTextLabel = %ChangelogText
@onready var _version_label: Label = %VersionLabel
@onready var _update_panel: PanelContainer = %UpdatePanel
@onready var _update_label: Label = %UpdateLabel
@onready var _update_progress: ProgressBar = %UpdateProgress
@onready var _update_button: Button = %UpdateButton
@onready var _update_later_button: Button = %UpdateLaterButton

var _updater := Updater.new()
## After a failed update the button opens the download page instead.
var _manual_download := false


func _ready() -> void:
	get_window().title = tr("GAME_TITLE")
	_version_label.text = tr("MENU_VERSION").format({"version": BuildInfo.display_string()})
	_name_edit.max_length = 16
	_name_edit.text = Settings.player_name
	_practice_button.pressed.connect(_open_race.bind(RaceController.Mode.PRACTICE))
	_race_button.pressed.connect(_open_race.bind(RaceController.Mode.RACE))
	_changelog_button.pressed.connect(_on_changelog_pressed)
	_settings_button.pressed.connect(func() -> void:
		_remember_inputs()
		get_tree().change_scene_to_file(SETTINGS_PATH))
	_changelog_dialog.visibility_changed.connect(_on_changelog_visibility_changed)
	_quit_button.pressed.connect(func() -> void:
		_remember_inputs()
		get_tree().quit())
	_host_button.pressed.connect(func() -> void:
		_remember_inputs()
		Session.host_game(Settings.player_name, Settings.car_color))
	_join_edit.text = Settings.last_join
	_join_edit.text_submitted.connect(func(_text: String) -> void: _join())
	_join_button.pressed.connect(_join)
	Session.ended.connect(_show_session_message)
	Session.phase_changed.connect(_on_session_phase)
	_show_session_message(Session.last_end_message)
	Session.last_end_message = ""
	for primary: Button in [_practice_button, _race_button]:
		_make_primary(primary)
	_practice_button.grab_focus()
	_setup_updater()


## The main actions stand out: red buttons (the rest keep the dark theme style).
func _make_primary(button: Button) -> void:
	for state: String in ["normal", "hover", "pressed"]:
		var style := (get_theme_stylebox(state, "Button") as StyleBoxFlat).duplicate() as StyleBoxFlat
		style.bg_color = Color(0.78, 0.1, 0.13) if state == "normal" else (Color(0.9, 0.16, 0.18) if state == "hover" else Color(0.6, 0.06, 0.09))
		style.border_color = Color(1, 1, 1, 0.9)
		button.add_theme_stylebox_override(state, style)
	button.add_theme_font_override("font", HudStyle.bold())
	button.add_theme_font_size_override("font_size", 24)


func _join() -> void:
	_remember_inputs()
	Settings.last_join = _join_edit.text.strip_edges().left(120)
	Settings.save()
	_show_session_message("")
	_join_button.disabled = true
	_join_button.text = tr("MENU_JOINING")
	Session.join_game(_join_edit.text, Settings.player_name)


func _show_session_message(message: String) -> void:
	_session_message.text = message
	_session_message.visible = not message.is_empty()
	_set_navigation(true)
	_join_button.text = tr("MENU_JOIN")


func _on_session_phase(phase: Session.Phase) -> void:
	_set_navigation(phase != Session.Phase.CONNECTING)
	if phase == Session.Phase.OFFLINE:
		_join_button.disabled = false
		_join_button.text = tr("MENU_JOIN")


## While connecting or downloading an update, leaving the menu would break it: buttons off.
func _set_navigation(enabled: bool) -> void:
	for button: Button in [_practice_button, _race_button, _host_button, _settings_button, _join_button]:
		button.disabled = not enabled


func _on_changelog_pressed() -> void:
	var text := Changelog.format_recent()
	_changelog_dialog.title = tr("CHANGELOG_TITLE")
	_changelog_text.text = text if not text.is_empty() else tr("CHANGELOG_EMPTY")
	_changelog_text.scroll_to_line(0)
	# Scrolling text does not contribute a useful minimum size to AcceptDialog.
	var available_size := Vector2i(Vector2(get_window().size) * 0.9)
	_changelog_dialog.min_size = Vector2i(clampi(available_size.x, 280, 840), clampi(available_size.y, 180, 560))
	_changelog_dialog.popup_centered_clamped(_changelog_dialog.min_size, 0.9)
	_changelog_text.grab_focus()


func _on_changelog_visibility_changed() -> void:
	if not _changelog_dialog.visible:
		_changelog_button.grab_focus.call_deferred()


func _setup_updater() -> void:
	add_child(_updater)
	if not _updater.is_supported():
		return
	UpdateInstaller.cleanup_old_files()
	_updater.update_available.connect(_on_update_available)
	_updater.download_progress.connect(func(fraction: float) -> void: _update_progress.value = fraction)
	_updater.failed.connect(_on_update_failed)
	_update_button.pressed.connect(_on_update_pressed)
	_update_later_button.pressed.connect(_update_panel.hide)
	_updater.check()


func _on_update_available(info: Dictionary) -> void:
	_update_label.text = tr("UPDATE_AVAILABLE").format({"version": "%s (%s)" % [info.version, tr("UPDATE_BUILD").format({"build": info.build})]})
	_update_panel.show()


func _on_update_pressed() -> void:
	if _manual_download:
		OS.shell_open(Updater.DOWNLOADS_PAGE_URL)
		return
	_update_button.disabled = true
	_update_later_button.disabled = true
	_update_progress.show()
	_set_navigation(false)
	_update_label.text = tr("UPDATE_DOWNLOADING")
	_updater.download_and_install()


func _on_update_failed(message: String) -> void:
	_manual_download = true
	_set_navigation(true)
	_update_progress.hide()
	_update_label.text = message
	_update_button.text = "UPDATE_MANUAL"
	_update_button.disabled = false
	_update_later_button.disabled = false
	_update_panel.show()


## Trénink / Závod open the session settings (user 2026-11-22: a separate screen).
func _open_race(mode: RaceController.Mode) -> void:
	_remember_inputs()
	RaceController.next_mode = mode
	get_tree().change_scene_to_file(SETUP_PATH)


func _remember_inputs() -> void:
	Settings.player_name = _name_edit.text.strip_edges()
	Settings.save()
