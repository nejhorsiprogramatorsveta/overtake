class_name CarView
extends Node2D
## Vector drawing of an original open-wheel race car seen from above (no bitmaps), shaped like
## the 2026 cars in an arcade way (PLAN.md B, user 2026-11-22): 3.4 m wheelbase, narrow front
## tyres, a front wing narrower than the car, slim sidepods over a wide floor, halo, mirrors,
## and active aero - the flaps of both wings open on the straights (visual only). The front
## wheels turn with the steering, the shadow falls away from the sun (top left) whatever the
## heading. Painted by a CarLivery (colour zones and shape inspired by the 2025/2026 grid,
## user 2026-11-23) - no team names, logos or sponsors.
## Local units are metres, the nose points to +x.

const TYRE := Color(0.07, 0.07, 0.08)
const SIDEWALL := Color(0.22, 0.22, 0.24)
const CARBON := Color(0.12, 0.12, 0.14)
const HALO := Color(0.2, 0.2, 0.22)
const BRAKE_LIGHT := Color(1.0, 0.15, 0.1)
const SHADOW := Color(0.0, 0.0, 0.0, 0.24)
## Shadow offset in world metres (sun at the top left).
const SHADOW_OFFSET := Vector2(0.22, 0.3)
const WHEELBASE := 3.4
const FRONT_AXLE := 1.55
const TYRE_LENGTH := 0.72
const FRONT_TYRE_WIDTH := 0.3
const REAR_TYRE_WIDTH := 0.4
## Seconds for the wing flaps to open or close.
const AERO_TIME := 0.25

var body_color := Color(0.86, 0.13, 0.15)
var helmet_color := Color(0.98, 0.85, 0.2)
var accent_color := Color(0.96, 0.96, 0.97)
## Colour zones and shape (null: plain body_color + accent_color).
var livery: CarLivery
var tuning: CarTuning
var braking := false:
	set(value):
		if value != braking:
			braking = value
			queue_redraw()
## Front wheel angle (radians, + = right).
var steer_angle := 0.0
## Straight-line mode: the wing flaps open (low drag look).
var aero_open := false
var _aero := 0.0
var _drawn_rotation := 0.0
var _drawn_steer := 0.0


func _process(delta: float) -> void:
	var target := 1.0 if aero_open else 0.0
	var aero := move_toward(_aero, target, delta / AERO_TIME)
	var rotation_now := global_rotation
	if aero != _aero or absf(angle_difference(rotation_now, _drawn_rotation)) > 0.01 \
			or absf(steer_angle - _drawn_steer) > 0.01:
		_aero = aero
		queue_redraw()


func _draw() -> void:
	_drawn_rotation = global_rotation
	_drawn_steer = steer_angle
	var half_l := (tuning.length if tuning else 5.2) * 0.5
	var half_w := (tuning.width if tuning else 1.9) * 0.5
	var rear_axle := FRONT_AXLE - WHEELBASE
	var l := livery if livery else CarLivery.plain(body_color, accent_color)
	_draw_shadow(half_l, half_w)
	# Floor (wider than the sidepods, dark) and suspension arms.
	_poly(_mirrored([Vector2(0.75, 0.42), Vector2(0.35, 0.74), Vector2(-1.2, 0.76), Vector2(-1.35, 0.62),
			Vector2(-1.95, 0.55), Vector2(-2.15, 0.3)]), CARBON)
	for x: float in [FRONT_AXLE, rear_axle]:
		for side: float in [-1.0, 1.0]:
			draw_line(Vector2(x + 0.15, side * 0.16), Vector2(x, side * (half_w - 0.2)), CARBON, 0.07)
			draw_line(Vector2(x - 0.2, side * 0.2), Vector2(x, side * (half_w - 0.2)), CARBON, 0.07)
	# Tyres: narrow at the front (turning with the steering), wide at the back.
	for side: float in [-1.0, 1.0]:
		_tyre(Vector2(rear_axle, side * (half_w - REAR_TYRE_WIDTH * 0.5)), REAR_TYRE_WIDTH, 0.0)
		_tyre(Vector2(FRONT_AXLE, side * (half_w - FRONT_TYRE_WIDTH * 0.5 - 0.02)), FRONT_TYRE_WIDTH, steer_angle)
	_draw_front_wing(half_l, l)
	_draw_rear_wing(half_l, l)
	_draw_body(half_l, l)
	if braking:
		draw_rect(Rect2(-half_l + 0.12, -0.07, 0.12, 0.14), BRAKE_LIGHT)
		draw_circle(Vector2(-half_l + 0.18, 0.0), 0.22, Color(BRAKE_LIGHT, 0.25))


## Soft shadow of the whole car, offset in world space.
func _draw_shadow(half_l: float, half_w: float) -> void:
	var offset := SHADOW_OFFSET.rotated(-global_rotation)
	var hull := PackedVector2Array([Vector2(half_l - 0.05, -0.7), Vector2(half_l - 0.05, 0.7), Vector2(1.9, half_w - 0.08),
			Vector2(-2.15, half_w - 0.08), Vector2(-half_l + 0.05, 0.5), Vector2(-half_l + 0.05, -0.5),
			Vector2(-2.15, -half_w + 0.08), Vector2(1.9, -half_w + 0.08)])
	for i in hull.size():
		hull[i] += offset
	draw_colored_polygon(hull, SHADOW)


func _tyre(centre: Vector2, tyre_width: float, angle: float) -> void:
	draw_set_transform(centre, angle)
	var rect := Rect2(-TYRE_LENGTH * 0.5, -tyre_width * 0.5, TYRE_LENGTH, tyre_width)
	draw_rect(rect, TYRE)
	draw_rect(rect.grow_individual(-0.08, -tyre_width * 0.42, -0.08, -tyre_width * 0.42), SIDEWALL)
	draw_set_transform(Vector2.ZERO)


## Front wing narrower than the car: main plane, flap (opens on the straights), endplates.
func _draw_front_wing(half_l: float, l: CarLivery) -> void:
	var span := 0.74
	draw_rect(Rect2(half_l - 0.26, -span, 0.22, span * 2.0), CARBON)
	var flap := lerpf(0.22, 0.08, _aero)
	var flap_x := half_l - 0.3 - flap - lerpf(0.0, 0.08, _aero)
	draw_rect(Rect2(flap_x, -span + 0.06, flap, span * 2.0 - 0.12), l.front_flap)
	for side: float in [-1.0, 1.0]:
		draw_rect(Rect2(flap_x, side * (span - 0.1) - 0.04, flap, 0.08), l.nose_tip)
		draw_rect(Rect2(half_l - 0.6, side * span - 0.035, 0.58, 0.07), CARBON)


## Rear wing between the rear tyres: main plane and upper flap (opens), endplates.
func _draw_rear_wing(half_l: float, l: CarLivery) -> void:
	var span := 0.52
	draw_rect(Rect2(-half_l + 0.02, -span, 0.2, span * 2.0), CARBON)
	var flap := lerpf(0.2, 0.07, _aero)
	var x := -half_l + 0.24 + lerpf(0.0, 0.1, _aero)
	draw_rect(Rect2(x, -span + 0.04, flap, span * 2.0 - 0.08), l.rear_flap)
	if l.spine.a > 0.0:
		draw_rect(Rect2(x, -0.08, flap, 0.16), l.spine)
	for side: float in [-1.0, 1.0]:
		draw_rect(Rect2(-half_l, side * span - 0.04, 0.55, 0.08), CARBON)


## Nose, sidepods, engine cover (colour zones of the livery), cockpit with driver and halo.
func _draw_body(half_l: float, l: CarLivery) -> void:
	var w := l.pod_width
	var half: Array[Vector2] = [Vector2(half_l - 0.08, 0.0), Vector2(half_l - 0.2, l.nose_width * 0.55),
			Vector2(1.8, l.nose_width), Vector2(1.1, l.nose_width * 1.45), Vector2(0.65, 0.3), Vector2(0.3, w - 0.04),
			Vector2(-0.2, w), Vector2(l.pod_end, w - 0.07), Vector2(-1.5, 0.36), Vector2(-2.05, 0.18), Vector2(-2.3, 0.1)]
	var outline := PackedVector2Array(_mirrored(half))
	draw_colored_polygon(outline, l.body)
	# Colour zones: nose to the cockpit, sidepod tops, engine cover.
	_poly(_mirrored([Vector2(half_l - 0.08, 0.0), Vector2(half_l - 0.2, l.nose_width * 0.55), Vector2(1.8, l.nose_width),
			Vector2(1.1, l.nose_width * 1.45), Vector2(0.65, 0.3), Vector2(0.6, 0.0)]), l.nose)
	for side: float in [-1.0, 1.0]:
		_poly([Vector2(0.28, side * (w - 0.06)), Vector2(-0.2, side * (w - 0.02)), Vector2(l.pod_end, side * (w - 0.09)),
				Vector2(-1.45, side * 0.35), Vector2(-0.95, side * 0.29), Vector2(0.2, side * 0.31)], l.pods)
	_poly(_mirrored([Vector2(-0.42, 0.27), Vector2(-0.95, 0.29), Vector2(-1.5, 0.34), Vector2(-2.05, 0.17), Vector2(-2.3, 0.09)]), l.engine)
	if l.split_left.a > 0.0:
		var left := PackedVector2Array()
		for point in half:
			left.append(Vector2(point.x, -point.y))
		left.append(Vector2(-2.3, 0.0))
		draw_colored_polygon(left, l.split_left)
	var closed := outline.duplicate()
	closed.append(outline[0])
	draw_polyline(closed, l.body.darkened(0.45), 0.05)
	# Highlights (light from the top left) on the sidepods and the nose.
	for side: float in [-1.0, 1.0]:
		_poly([Vector2(0.2, side * (w - 0.15)), Vector2(-0.85, side * (w - 0.14)), Vector2(-1.3, side * 0.3), Vector2(-0.6, side * 0.3)],
				Color(1, 1, 1, 0.12))
	_poly([Vector2(half_l - 0.3, 0.03), Vector2(1.2, 0.09), Vector2(1.2, -0.09), Vector2(half_l - 0.3, -0.03)], Color(1, 1, 1, 0.16))
	# Nose tip, stripes along the sidepods, the engine cover spine.
	_poly(_mirrored([Vector2(half_l - 0.08, 0.0), Vector2(half_l - 0.2, l.nose_width * 0.55), Vector2(2.05, l.nose_width * 0.85)]), l.nose_tip)
	for side: float in [-1.0, 1.0]:
		if l.stripe.a > 0.0:
			draw_line(Vector2(0.15, side * (w - 0.08)), Vector2(l.pod_end - 0.15, side * (w - 0.14)), l.stripe, 0.12)
		# Sidepod inlet and mirror.
		_poly([Vector2(0.32, side * (w - 0.03)), Vector2(0.12, side * w), Vector2(0.1, side * 0.4), Vector2(0.3, side * 0.36)], CARBON)
		draw_rect(Rect2(0.38, side * 0.47 - 0.06, 0.12, 0.12), CARBON)
		draw_line(Vector2(0.44, side * 0.3), Vector2(0.44, side * 0.42), CARBON, 0.04)
	if l.spine.a > 0.0:
		draw_line(Vector2(-0.45, 0.0), Vector2(-2.15, 0.0), l.spine, 0.1)
	draw_rect(Rect2(-0.42, -0.1, 0.16, 0.2), CARBON)
	# Cockpit, driver, halo.
	_poly([Vector2(0.58, 0.0), Vector2(0.48, 0.2), Vector2(-0.1, 0.24), Vector2(-0.22, 0.16), Vector2(-0.22, -0.16),
			Vector2(-0.1, -0.24), Vector2(0.48, -0.2)], CARBON)
	draw_circle(Vector2(0.08, 0.0), 0.17, helmet_color)
	draw_rect(Rect2(0.16, -0.08, 0.06, 0.16), Color(0.1, 0.1, 0.12))
	draw_polyline(PackedVector2Array([Vector2(-0.12, 0.22), Vector2(0.38, 0.26), Vector2(0.62, 0.0),
			Vector2(0.38, -0.26), Vector2(-0.12, -0.22)]), l.halo, 0.08)


## Closed outline from one side (y >= 0, nose to tail) plus its mirror image.
func _mirrored(side: Array[Vector2]) -> Array[Vector2]:
	var result := side.duplicate()
	for i in range(side.size() - 1, -1, -1):
		result.append(Vector2(side[i].x, -side[i].y))
	return result


func _poly(points: Array[Vector2], color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), color)
