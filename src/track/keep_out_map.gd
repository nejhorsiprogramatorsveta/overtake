class_name KeepOutMap
extends RefCounted
## Occupancy bitmap of a rectangle (cells of CELL metres): track, pit lane, buildings and trees
## block their area, and scenery is only placed where the map is still free.

const CELL := 4.0

var bounds := Rect2()
var _columns := 0
var _rows := 0
var _blocked := PackedByteArray()


func _init(area: Rect2) -> void:
	bounds = area
	_columns = ceili(area.size.x / CELL)
	_rows = ceili(area.size.y / CELL)
	_blocked.resize(_columns * _rows)
	_blocked.fill(0)


## Blocks every cell that a circle of `radius` around `point` touches.
func block_circle(point: Vector2, radius: float) -> void:
	var reach := radius + CELL * 0.71
	var from := _cell(point - Vector2(reach, reach))
	var to := _cell(point + Vector2(reach, reach))
	for y in range(maxi(from.y, 0), mini(to.y, _rows - 1) + 1):
		for x in range(maxi(from.x, 0), mini(to.x, _columns - 1) + 1):
			var centre := bounds.position + (Vector2(x, y) + Vector2(0.5, 0.5)) * CELL
			if centre.distance_squared_to(point) <= reach * reach:
				_blocked[y * _columns + x] = 1


## True if no cell within `radius` of `point` is blocked (outside the map counts as blocked).
func is_clear(point: Vector2, radius: float = 0.0) -> bool:
	var from := _cell(point - Vector2(radius, radius))
	var to := _cell(point + Vector2(radius, radius))
	if from.x < 0 or from.y < 0 or to.x >= _columns or to.y >= _rows:
		return false
	for y in range(from.y, to.y + 1):
		for x in range(from.x, to.x + 1):
			if _blocked[y * _columns + x] != 0:
				return false
	return true


func _cell(point: Vector2) -> Vector2i:
	var local := (point - bounds.position) / CELL
	return Vector2i(floori(local.x), floori(local.y))
