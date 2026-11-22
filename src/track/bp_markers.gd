class_name BpMarkers
extends Node2D
## White "BP" boards beside the track at the recommended braking points (PLAN.md B), plus a
## short white block on the asphalt edge. Drawn locally for the own player, so worn tyres can
## move that player's boards earlier (M2 tyre wear). Text stays upright (north-up camera).

const BOARD_SIZE := Vector2(9.0, 5.0)
const BOARD_COLOR := Color(0.97, 0.97, 0.97)
const TEXT_COLOR := Color(0.08, 0.08, 0.1)
const POST_COLOR := Color(0.2, 0.2, 0.22)
const BLOCK_COLOR := Color(1, 1, 1, 0.85)
## Board centre distance from the asphalt edge (m), beyond the kerb.
const BOARD_OFFSET := 7.0
## Text is drawn this many times bigger and scaled down, so it stays sharp when zoomed.
const TEXT_SCALE := 0.05
const FONT_SIZE := 64

var track: TrackData
var points: BrakingPoints


func show_points(track_data: TrackData, braking_points: BrakingPoints) -> void:
	track = track_data
	points = braking_points
	queue_redraw()


func _draw() -> void:
	if points == null:
		return
	var font := ThemeDB.fallback_font
	for i in points.count():
		var distance := points.distances[i]
		var side := float(points.sides[i])
		var edge := track.half_width() + TrackData.KERB_WIDTH
		# White block across the edge of the asphalt where braking starts.
		var a := track.position_at(distance, side * (track.half_width() - 3.0))
		var b := track.position_at(distance, side * track.half_width())
		draw_line(a, b, BLOCK_COLOR, 1.6)
		var centre := track.position_at(distance, side * (edge + BOARD_OFFSET))
		draw_line(track.position_at(distance, side * edge), centre, POST_COLOR, 0.4)
		var rect := Rect2(centre - BOARD_SIZE * 0.5, BOARD_SIZE)
		draw_rect(rect.grow(0.35), TEXT_COLOR)
		draw_rect(rect, BOARD_COLOR)
		draw_set_transform(centre, 0.0, Vector2.ONE * TEXT_SCALE)
		var text_size := font.get_string_size("BP", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
		var baseline := Vector2(-text_size.x * 0.5, font.get_ascent(FONT_SIZE) * 0.5 - font.get_descent(FONT_SIZE) * 0.25)
		draw_string(font, baseline, "BP", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, TEXT_COLOR)
		draw_set_transform(Vector2.ZERO)
