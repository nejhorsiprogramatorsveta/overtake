class_name CarView
extends Node2D
## Vector drawing of an original open-wheel race car seen from above (no bitmaps).
## Local units are metres, the nose points to +x. Not a copy of any real team's car or livery.

const TYRE := Color(0.08, 0.08, 0.09)
const CARBON := Color(0.14, 0.14, 0.16)
const HALO := Color(0.55, 0.56, 0.6)
const BRAKE_LIGHT := Color(1.0, 0.15, 0.1)
const KERS_GLOW := Color(0.35, 0.75, 1.0, 0.55)
const STREAK := Color(1, 1, 1, 0.5)

var body_color := Color(0.86, 0.13, 0.15)
var helmet_color := Color(0.98, 0.85, 0.2)
var tuning: CarTuning
var braking := false:
	set(value):
		if value != braking:
			braking = value
			queue_redraw()
## KERS burst: blue glow behind the car.
var boosting := false:
	set(value):
		if value != boosting:
			boosting = value
			queue_redraw()
## Slipstream 0..1: faint air streaks along the car.
var tow := 0.0:
	set(value):
		if absf(value - tow) > 0.05 or (value == 0.0 and tow != 0.0):
			tow = value
			queue_redraw()


func _draw() -> void:
	var half_l := (tuning.length if tuning else 5.2) * 0.5
	var half_w := (tuning.width if tuning else 1.9) * 0.5
	if boosting:
		draw_colored_polygon(PackedVector2Array([Vector2(-half_l, -0.35), Vector2(-half_l - 2.6, 0.0),
				Vector2(-half_l, 0.35)]), KERS_GLOW)
		draw_circle(Vector2(-half_l - 0.3, 0.0), 0.45, KERS_GLOW)
	if tow > 0.05:
		var streak := STREAK * Color(1, 1, 1, tow)
		for side: float in [-1.0, 1.0]:
			draw_line(Vector2(half_l + 1.0, side * (half_w + 0.5)), Vector2(-half_l - 1.5, side * (half_w + 0.3)), streak, 0.12)
			draw_line(Vector2(half_l * 0.3, side * (half_w + 1.1)), Vector2(-half_l - 3.0, side * (half_w + 0.8)), streak, 0.08)
	# Tyres (rear slightly wider).
	for x: float in [half_l * 0.6, -half_l * 0.6]:
		var tyre_w := 0.42 if x > 0 else 0.52
		for side: float in [-1.0, 1.0]:
			draw_rect(Rect2(x - 0.38, side * (half_w - tyre_w * 0.5) - tyre_w * 0.5, 0.76, tyre_w), TYRE)
	# Wings.
	draw_rect(Rect2(half_l - 0.45, -half_w, 0.45, half_w * 2.0), CARBON)
	draw_rect(Rect2(half_l - 0.4, -half_w + 0.05, 0.3, half_w * 2.0 - 0.1), body_color.darkened(0.2))
	draw_rect(Rect2(-half_l, -half_w * 0.85, 0.5, half_w * 1.7), CARBON)
	draw_rect(Rect2(-half_l + 0.08, -half_w * 0.8, 0.3, half_w * 1.6), body_color)
	# Body: narrow nose, wide sidepods, tapered engine cover.
	var body := PackedVector2Array([
		Vector2(half_l - 0.1, -0.12), Vector2(half_l - 0.1, 0.12), Vector2(0.9, 0.32), Vector2(0.25, 0.62),
		Vector2(-1.5, 0.62), Vector2(-2.1, 0.32), Vector2(-2.3, 0.0), Vector2(-2.1, -0.32),
		Vector2(-1.5, -0.62), Vector2(0.25, -0.62), Vector2(0.9, -0.32)])
	draw_colored_polygon(body, body_color)
	draw_line(Vector2(half_l - 0.2, 0.0), Vector2(-2.2, 0.0), body_color.lightened(0.35), 0.12)
	# Cockpit, helmet, halo.
	draw_circle(Vector2(-0.25, 0.0), 0.36, CARBON)
	draw_circle(Vector2(-0.3, 0.0), 0.2, helmet_color)
	draw_arc(Vector2(-0.25, 0.0), 0.42, -PI * 0.55, PI * 0.55, 10, HALO, 0.09)
	draw_line(Vector2(0.17, 0.0), Vector2(0.45, 0.0), HALO, 0.09)
	if braking:
		draw_rect(Rect2(-half_l - 0.08, -0.16, 0.12, 0.32), BRAKE_LIGHT)
