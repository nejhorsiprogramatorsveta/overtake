class_name MenuBackground
extends Control
## Vector menu backdrop (user 2026-11-22: "more racing and nicer"): dark asphalt with speed
## streaks, a chequered strip along the top, a red-white kerb along the bottom and, on the right,
## a stylised circuit with kerbs where a few cars in the grid's colours race and overtake each
## other (CarView: flaps open on the straights, wheels turn in the corners). Drawn in code (no
## bitmaps), scales to any window size; the cars are the only things that move.

const ASPHALT := Color(0.09, 0.1, 0.12)
const TRACK := Color(0.19, 0.2, 0.23)
const TRACK_EDGE := Color(0.9, 0.9, 0.92)
const STREAK := Color(1, 1, 1, 0.025)
const KERB_RED := Color(0.86, 0.13, 0.15)
const KERB_WHITE := Color(0.93, 0.93, 0.95)
const KERB_HEIGHT := 26.0
const KERB_STEP := 52.0
const CHECKER := 14.0
## Circuit shape in screen shares (x, y), closed, driven clockwise.
const SHAPE: Array[Vector2] = [Vector2(0.63, 0.24), Vector2(0.84, 0.21), Vector2(0.94, 0.31), Vector2(0.91, 0.47),
		Vector2(0.80, 0.55), Vector2(0.85, 0.68), Vector2(0.93, 0.78), Vector2(0.83, 0.89), Vector2(0.66, 0.86),
		Vector2(0.60, 0.72), Vector2(0.68, 0.60), Vector2(0.60, 0.46), Vector2(0.58, 0.32)]
const CARS := 5

## False on screens where the circuit would sit behind a big panel.
@export var show_circuit := false
var _path := PackedVector2Array()
var _lengths := PackedFloat32Array()
var _total := 0.0
var _cars: Array[CarView] = []
var _distance := PackedFloat32Array()
var _speed := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_rebuild)
	_rng.randomize()
	if show_circuit:
		var tuning: CarTuning = load("res://data/car/car_tuning.tres")
		for i in CARS:
			var car := CarView.new()
			car.tuning = tuning
			var color := CarColors.COLORS[(i * 3 + 1) % CarColors.COLORS.size()]
			car.body_color = color
			car.accent_color = CarColors.accent_for(color)
			car.helmet_color = CarColors.helmet_for(color)
			car.livery = CarLivery.for_color(color)
			add_child(car)
			_cars.append(car)
			_distance.append(0.0)
			_speed.append(0.0)
	_rebuild()


func _rebuild() -> void:
	_path = PackedVector2Array()
	if show_circuit and size.x > 0.0:
		var curve := Curve2D.new()
		var n := SHAPE.size()
		for i in n:
			var p := SHAPE[i] * size
			var tangent := (SHAPE[(i + 1) % n] - SHAPE[(i - 1 + n) % n]) * size * 0.2
			curve.add_point(p, -tangent, tangent)
		curve.add_point(SHAPE[0] * size, -(SHAPE[1] - SHAPE[n - 1]) * size * 0.2, Vector2.ZERO)
		curve.bake_interval = 6.0
		_path = curve.get_baked_points()
	_lengths = PackedFloat32Array()
	_total = 0.0
	for i in _path.size():
		_lengths.append(_total)
		_total += _path[i].distance_to(_path[(i + 1) % _path.size()])
	for i in _cars.size():
		_distance[i] = _total * float(i) / _cars.size() * 0.35
		_speed[i] = _rng.randf_range(0.9, 1.1)
		_cars[i].scale = Vector2.ONE * _car_scale()
	queue_redraw()


func _car_scale() -> float:
	return clampf(size.y / 90.0, 6.0, 20.0)


func _process(delta: float) -> void:
	if _path.size() < 3:
		return
	var base := size.y * 0.42
	for i in _cars.size():
		# Small speed changes so the cars keep swapping places.
		_speed[i] = clampf(_speed[i] + _rng.randf_range(-0.4, 0.4) * delta, 0.85, 1.15)
		_distance[i] = fposmod(_distance[i] + base * _speed[i] * delta, _total)
		var lane := (float(i % 3) - 1.0) * _car_scale() * 1.7
		var index := _index_at(_distance[i])
		var a := _path[index]
		var b := _path[(index + 1) % _path.size()]
		var c := _path[(index + 6) % _path.size()]
		var direction := (b - a).normalized()
		var turn := direction.angle_to((c - b).normalized())
		_cars[i].position = a + Vector2(-direction.y, direction.x) * lane
		_cars[i].rotation = direction.angle()
		_cars[i].steer_angle = clampf(turn * 3.0, -0.4, 0.4)
		_cars[i].aero_open = absf(turn) < 0.05


func _index_at(distance: float) -> int:
	var low := 0
	var high := _lengths.size() - 1
	while low < high:
		var mid := (low + high + 1) / 2
		if _lengths[mid] <= distance:
			low = mid
		else:
			high = mid - 1
	return low


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), ASPHALT)
	# Speed streaks across the screen.
	for i in 9:
		var y := size.y * (0.1 + i * 0.1)
		draw_line(Vector2(-40, y + size.x * 0.2), Vector2(size.x + 40, y - size.x * 0.12), STREAK, 18.0 + (i % 3) * 14.0)
	if _path.size() > 2:
		var width := _car_scale() * 6.2
		var closed := _path.duplicate()
		closed.append(_path[0])
		draw_polyline(closed, TRACK_EDGE, width + 8.0, true)
		draw_polyline(closed, TRACK, width, true)
		_draw_kerbs(width)
	_draw_kerb_strip()
	for row in 2:
		var column := 0
		while column * CHECKER < size.x:
			if (column + row) % 2 == 0:
				draw_rect(Rect2(column * CHECKER, row * CHECKER, CHECKER, CHECKER), KERB_WHITE)
			column += 1


## Red-white kerbs on the outside of the bends of the circuit.
func _draw_kerbs(width: float) -> void:
	var n := _path.size()
	for i in range(0, n, 2):
		var a := _path[i]
		var b := _path[(i + 2) % n]
		var c := _path[(i + 8) % n]
		var turn := (b - a).normalized().angle_to((c - b).normalized())
		if absf(turn) < 0.12:
			continue
		var direction := (b - a).normalized()
		var outside := Vector2(-direction.y, direction.x) * (-signf(turn)) * (width * 0.5 + 2.0)
		var color := KERB_RED if (i / 2) % 2 == 0 else KERB_WHITE
		draw_line(a + outside, b + outside, color, 7.0)


func _draw_kerb_strip() -> void:
	var y := size.y - KERB_HEIGHT
	var x := -KERB_STEP
	var index := 0
	while x < size.x + KERB_STEP:
		var shape := PackedVector2Array([Vector2(x, size.y), Vector2(x + KERB_STEP * 0.5, y),
				Vector2(x + KERB_STEP * 1.5, y), Vector2(x + KERB_STEP, size.y)])
		draw_colored_polygon(shape, KERB_RED if index % 2 == 0 else KERB_WHITE)
		x += KERB_STEP
		index += 1
