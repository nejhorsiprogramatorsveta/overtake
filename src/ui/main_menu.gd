extends Control
## Main menu: practice or a solo race with a standing start on a chosen track, settings, "Co je nového", quit, version and the
## in-game updater. Host/join comes with M4.

const SETTINGS_PATH := "res://src/ui/settings_screen.tscn"
const RACE_PATH := "res://src/race/race.tscn"

@onready var _name_edit: LineEdit = %NameEdit
@onready var _practice_button: Button = %PracticeButton
@onready var _race_button: Button = %RaceButton
@onready var _track_option: OptionButton = %TrackOption
@onready var _tyre_wear_check: CheckButton = %TyreWearCheck
@onready var _changelog_button: Button = %ChangelogButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton
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
	_fill_track_option()
	_tyre_wear_check.button_pressed = Settings.tyre_wear
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
	_practice_button.grab_focus()
	_setup_updater()


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
	_update_label.text = tr("UPDATE_DOWNLOADING")
	_updater.download_and_install()


func _on_update_failed(message: String) -> void:
	_manual_download = true
	_update_progress.hide()
	_update_label.text = message
	_update_button.text = "UPDATE_MANUAL"
	_update_button.disabled = false
	_update_later_button.disabled = false
	_update_panel.show()


func _open_race(mode: RaceController.Mode) -> void:
	_remember_inputs()
	RaceController.next_mode = mode
	get_tree().change_scene_to_file(RACE_PATH)


func _fill_track_option() -> void:
	var chosen := TrackCatalog.id_or_default(Settings.practice_track)
	for id in TrackCatalog.ids():
		_track_option.add_item(tr(TrackCatalog.NAME_KEYS[id]))
		_track_option.set_item_metadata(_track_option.item_count - 1, id)
		if id == chosen:
			_track_option.select(_track_option.item_count - 1)


func _remember_inputs() -> void:
	Settings.player_name = _name_edit.text.strip_edges()
	Settings.tyre_wear = _tyre_wear_check.button_pressed
	if _track_option.selected >= 0:
		Settings.practice_track = str(_track_option.get_item_metadata(_track_option.selected))
	Settings.save()
