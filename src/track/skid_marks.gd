class_name SkidMarks
extends Node2D
## Tyre marks the cars leave while racing (M3G): short dark segments from scrubbing tyres and
## wheelspin, kept in a ring buffer (the oldest disappear first) and drawn between the track and
## the cars. The buffer is split into chunks (child nodes), so a new mark redraws only its chunk.
## Look only. Units are metres.

const CHUNKS := 20
const CHUNK_SIZE := 300
const MAX_SEGMENTS := CHUNKS * CHUNK_SIZE
const WIDTH := 0.3
const COLOR := Color(0.06, 0.06, 0.07)
## Darkest mark (alpha): barely visible on purpose (user 2026-11-22: trails were distracting).
const STRENGTH := 0.12

var _chunks: Array[Chunk] = []
var _next := 0


func _init() -> void:
	for i in CHUNKS:
		var chunk := Chunk.new()
		_chunks.append(chunk)
		add_child(chunk)


## One mark segment; strength 0..1 sets how dark it is.
func add(from: Vector2, to: Vector2, strength: float) -> void:
	if from.distance_squared_to(to) < 0.0025 or from.distance_squared_to(to) > 9.0:
		return
	_chunks[_next / CHUNK_SIZE].set_segment(_next % CHUNK_SIZE, from, to, Color(COLOR, clampf(strength, 0.0, 1.0) * STRENGTH))
	_next = (_next + 1) % MAX_SEGMENTS


func count() -> int:
	var visible_marks := 0
	for chunk in _chunks:
		visible_marks += chunk.used
	return visible_marks


## A slice of the ring buffer with its own drawing.
class Chunk:
	extends Node2D

	var used := 0
	var _points := PackedVector2Array()
	var _colors := PackedColorArray()
	var _dirty := false

	func _init() -> void:
		_points.resize(CHUNK_SIZE * 2)
		_colors.resize(CHUNK_SIZE)
		_colors.fill(Color(COLOR, 0.0))

	func set_segment(index: int, from: Vector2, to: Vector2, color: Color) -> void:
		if _colors[index].a <= 0.0:
			used += 1
		_points[index * 2] = from
		_points[index * 2 + 1] = to
		_colors[index] = color
		_dirty = true

	func _process(_delta: float) -> void:
		if _dirty:
			_dirty = false
			queue_redraw()

	func _draw() -> void:
		if used > 0:
			draw_multiline_colors(_points, _colors, WIDTH)
