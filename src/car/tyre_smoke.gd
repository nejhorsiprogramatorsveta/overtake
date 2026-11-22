class_name TyreSmoke
extends Node2D
## Smoke and dust puffs of all cars (M3G, look only): each puff drifts, slows down, grows and
## fades. A fixed pool (the oldest puff is reused when full), drawn as soft round sprites made
## in code. Units are metres.

const MAX_PUFFS := 600
const DAMPING := 2.5

var _position := PackedVector2Array()
var _velocity := PackedVector2Array()
var _age := PackedFloat32Array()
var _life := PackedFloat32Array()
var _size := PackedFloat32Array()
var _color := PackedColorArray()
var _next := 0
var _texture: GradientTexture2D
var _drawn_any := false


func _init() -> void:
	_position.resize(MAX_PUFFS)
	_velocity.resize(MAX_PUFFS)
	_age.resize(MAX_PUFFS)
	_life.resize(MAX_PUFFS)
	_size.resize(MAX_PUFFS)
	_color.resize(MAX_PUFFS)
	_age.fill(1.0)
	_life.fill(0.0)
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1, 1, 1, 0))
	_texture = GradientTexture2D.new()
	_texture.gradient = gradient
	_texture.fill = GradientTexture2D.FILL_RADIAL
	_texture.fill_from = Vector2(0.5, 0.5)
	_texture.fill_to = Vector2(1.0, 0.5)


## A new puff at `at` (world metres) drifting with `velocity`, `size` = start radius.
func puff(at: Vector2, velocity: Vector2, color: Color, size: float, life: float) -> void:
	_position[_next] = at
	_velocity[_next] = velocity
	_age[_next] = 0.0
	_life[_next] = life
	_size[_next] = size
	_color[_next] = color
	_next = (_next + 1) % MAX_PUFFS


func alive_count() -> int:
	var count := 0
	for i in MAX_PUFFS:
		if _age[i] < _life[i]:
			count += 1
	return count


func _process(delta: float) -> void:
	var any := false
	var slow := exp(-DAMPING * delta)
	for i in MAX_PUFFS:
		if _age[i] >= _life[i]:
			continue
		any = true
		_age[i] += delta
		_position[i] += _velocity[i] * delta
		_velocity[i] *= slow
	if any or _drawn_any:
		queue_redraw()



func _draw() -> void:
	_drawn_any = false
	for i in MAX_PUFFS:
		if _age[i] >= _life[i]:
			continue
		_drawn_any = true
		var t := _age[i] / _life[i]
		var radius := _size[i] * (0.6 + 1.4 * t)
		var color := _color[i]
		color.a *= 1.0 - t
		draw_texture_rect(_texture, Rect2(_position[i] - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, color)
