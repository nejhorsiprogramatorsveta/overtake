class_name MenuBackground
extends Control
## Vector menu backdrop: asphalt, a red-white kerb along the bottom and a chequered strip
## along the top. Drawn in code (no bitmaps), scales to any window size.

const ASPHALT := Color(0.12, 0.13, 0.16)
const KERB_RED := Color(0.86, 0.13, 0.15)
const KERB_WHITE := Color(0.93, 0.93, 0.95)
const KERB_HEIGHT := 26.0
const KERB_STEP := 52.0
const CHECKER := 14.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), ASPHALT)
	# Faint racing line across the screen.
	draw_line(Vector2(-40, size.y * 0.78), Vector2(size.x + 40, size.y * 0.32), Color(0.09, 0.1, 0.12), 90.0)
	var y := size.y - KERB_HEIGHT
	var x := -KERB_STEP
	var index := 0
	while x < size.x + KERB_STEP:
		var shape := PackedVector2Array([Vector2(x, size.y), Vector2(x + KERB_STEP * 0.5, y),
				Vector2(x + KERB_STEP * 1.5, y), Vector2(x + KERB_STEP, size.y)])
		draw_colored_polygon(shape, KERB_RED if index % 2 == 0 else KERB_WHITE)
		x += KERB_STEP
		index += 1
	for row in 2:
		var column := 0
		while column * CHECKER < size.x:
			if (column + row) % 2 == 0:
				draw_rect(Rect2(column * CHECKER, row * CHECKER, CHECKER, CHECKER), KERB_WHITE)
			column += 1
