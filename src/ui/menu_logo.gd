class_name MenuLogo
extends Control
## The game's logo in the main menu: "OVERTAKE" in a bold slanted face with a red outline, red
## speed lines in front of it and a small chequered flag; drawn in code.

const TEXT := "OVERTAKE"
const FONT_SIZE := 92
const SLANT := -0.22
const RED := Color(0.88, 0.12, 0.15)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(560, 130)


func _draw() -> void:
	var font := HudStyle.bold()
	var baseline := Vector2(70, 100)
	# Speed lines.
	for i in 3:
		var y := 52.0 + i * 18.0
		var length := 54.0 - i * 12.0
		draw_line(Vector2(56 - length, y), Vector2(56, y), RED, 7.0 - i * 1.5)
	draw_set_transform_matrix(Transform2D(Vector2(1, 0), Vector2(SLANT, 1), baseline))
	draw_string_outline(font, Vector2.ZERO, TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 14, RED)
	draw_string(font, Vector2.ZERO, TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color.WHITE)
	var width := font.get_string_size(TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	draw_set_transform(Vector2.ZERO)
	# Chequered flag after the word.
	var flag := Vector2(baseline.x + width + 22.0, 34.0)
	var cell := 9.0
	for row in 4:
		for column in 5:
			var color := Color.WHITE if (row + column) % 2 == 0 else Color(0.08, 0.08, 0.1)
			draw_rect(Rect2(flag + Vector2(column * cell + row * 2.0, row * cell), Vector2(cell, cell)), color)
	draw_line(flag + Vector2(0, 0), flag + Vector2(8, 66), Color(0.75, 0.76, 0.8), 3.0)
