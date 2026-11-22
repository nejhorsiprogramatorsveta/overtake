class_name RaceController
extends Node2D
## M1 practice session: one player car on the chosen track, endless timed laps.
## (M2 adds the start procedure and race rules, M3 bots, M4 the network.)
## Physics runs at 60 Hz in _physics_process; drawing is smoothed by physics interpolation.

const MENU_PATH := "res://src/ui/main_menu.tscn"
const TUNING_PATH := "res://data/car/car_tuning.tres"
const PLAYER_COLOR := Color(0.86, 0.13, 0.15)
## The practice car starts this far before the line, so the first crossing starts lap 1.
const START_BEHIND_LINE := 40.0

var track: TrackData
var tuning: CarTuning
var player: Car
var laps: LapTracker
var camera := RaceCamera.new()
var hud := RaceHud.new()
## Race clock in seconds, advanced by the physics ticks (deterministic).
var race_time := 0.0


func _ready() -> void:
	track = TrackCatalog.get_track(Settings.practice_track)
	tuning = load(TUNING_PATH)
	var track_view := TrackView.new()
	add_child(track_view)
	track_view.setup(track)
	player = Car.new()
	add_child(player)
	player.setup(track, tuning, PLAYER_COLOR)
	player.place(track.length - START_BEHIND_LINE, 0.0)
	laps = LapTracker.new(track)
	add_child(camera)
	camera.target = player
	camera.make_current()
	camera.snap()
	add_child(hud)
	hud.setup(track)


func _physics_process(delta: float) -> void:
	race_time += delta
	player.simulate(CarInput.from_keyboard(), delta)
	laps.update(player.query.distance, race_time, delta)


func _process(_delta: float) -> void:
	hud.show_speed(player.speed_kmh())
	hud.show_laps(laps.laps + 1, laps.current_lap_time(race_time), laps.last_lap, laps.best_lap)
	hud.minimap.show_cars(PackedVector2Array([player.state.position]), PackedColorArray([PLAYER_COLOR]))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_tree().change_scene_to_file(MENU_PATH)
