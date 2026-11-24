class_name HelpShot
extends Control
## One picture of the help screen (user 2026-11-24): a cut-out of a real track - the shared
## world of HelpScreen seen from `centre` at `zoom` pixels per metre - with arrows along the
## track, key caps and labels drawn on top. Positions are world metres.

const SIZE := Vector2i(430, 220)
const OUTLINE := Color(0, 0, 0, 0.85)

var viewport := SubViewport.new()
var centre := Vector2.ZERO
var zoom := 3.0
## Drawn on top: [kind, ...] (see path(), label(), key()); `extra` draws screen-space extras.
var _marks: Array = []
var extra := Callable()
var _overlay := Control.new()


func _init() -> void:
	custom_minimum_size = Vector2(SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var container := SubViewportContainer.new()
	container.stretch = true
	container.custom_minimum_size = Vector2(SIZE)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	viewport.size = SIZE
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	container.add_child(viewport)
	_overlay.custom_minimum_size = Vector2(SIZE)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_marks)
	add_child(_overlay)


## Looks at the box around `points` (world metres) with `margin` metres around it.
func frame(points: PackedVector2Array, margin: float) -> void:
	var box := Rect2(points[0], Vector2.ZERO)
	for p in points:
		box = box.expand(p)
	box = box.grow(margin)
	centre = box.get_center()
	zoom = minf(SIZE.x / box.size.x, SIZE.y / box.size.y)
	viewport.canvas_transform = Transform2D(0.0, Vector2(zoom, zoom), 0.0, Vector2(SIZE) * 0.5 - centre * zoom)


func mark_count() -> int:
	return _marks.size()


func to_screen(world: Vector2) -> Vector2:
	return (world - centre) * zoom + Vector2(SIZE) * 0.5


## An arrow along `points` (world) with `text` at its end.
func path(points: PackedVector2Array, color: Color, text: String = "") -> void:
	_marks.append(["path", points, color, text])


## Which side of an arrow its label goes (+1 / -1, screen left of the direction = -1).
var label_side := 1.0


func label(world: Vector2, text: String, color: Color = Color.WHITE) -> void:
	_marks.append(["label", world, text, color])


## A key cap ("W") at a world position.
func key(world: Vector2, text: String) -> void:
	_marks.append(["key", world, text])


func _draw_marks() -> void:
	for mark: Array in _marks:
		match mark[0]:
			"path":
				_draw_path(mark[1], mark[2], mark[3])
			"label":
				text_at(_overlay, to_screen(mark[1]), mark[2], mark[3], 17)
			"key":
				key_cap(_overlay, to_screen(mark[1]), mark[2])
	if extra.is_valid():
		extra.call(_overlay)


func _draw_path(points: PackedVector2Array, color: Color, text: String) -> void:
	var screen := PackedVector2Array()
	for p in points:
		screen.append(to_screen(p))
	_overlay.draw_polyline(screen, OUTLINE, 8.0, true)
	_overlay.draw_polyline(screen, color, 4.5, true)
	var tip := screen[-1]
	var direction := (tip - screen[maxi(screen.size() - 3, 0)]).normalized()
	var side := Vector2(-direction.y, direction.x)
	var head := PackedVector2Array([tip + direction * 9.0, tip - direction * 6.0 + side * 8.0, tip - direction * 6.0 - side * 8.0])
	_overlay.draw_colored_polygon(head, color)
	_overlay.draw_polyline(head + PackedVector2Array([head[0]]), OUTLINE, 1.5, true)
	if not text.is_empty():  # beside the middle of the arrow (the next arrow may start at its tip)
		var middle := screen.size() / 2
		var along := (screen[mini(middle + 1, screen.size() - 1)] - screen[maxi(middle - 1, 0)]).normalized()
		var normal := Vector2(-along.y, along.x) * label_side
		text_at(_overlay, screen[middle] + normal * 20.0, text, color, 17)


## Bold text with a dark outline, centred at `at`.
static func text_at(canvas: CanvasItem, at: Vector2, text: String, color: Color, font_size: int) -> void:
	var font := HudStyle.bold()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var origin := at + Vector2(-width * 0.5, font_size * 0.35)
	canvas.draw_string_outline(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, OUTLINE)
	canvas.draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## A keyboard key with its label, centred at `at`.
static func key_cap(canvas: CanvasItem, at: Vector2, text: String) -> void:
	var font := HudStyle.bold()
	var width := maxf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 14.0, 30.0)
	var rect := Rect2(at - Vector2(width * 0.5, 15.0), Vector2(width, 30.0))
	canvas.draw_rect(rect.grow(2.0), OUTLINE)
	canvas.draw_rect(rect, Color(0.93, 0.93, 0.95))
	canvas.draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - 5.0), Vector2(rect.size.x, 5.0)), Color(0.7, 0.7, 0.74))
	canvas.draw_string(font, Vector2(rect.position.x + (width - font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x) * 0.5,
			rect.position.y + 20.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.1, 0.1, 0.12))
