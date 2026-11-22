class_name CarCodec
## Binary car states for the race netcode (PLAN.md C, section S): fixed-size records, no Variant
## or object decoding, every value range-checked; anything malformed is dropped as a whole.
##   Client -> host (every tick): seq u16 + record (22 B)            = 24 B
##   Host -> clients (every tick): tick u32 + count u8 + count × (index u8 + record)
## Record: x, y, heading, vx, vy (f32), steer (s8, ±127), flags (u8, FLAG_*).

const FLAG_BRAKE := 1
const FLAG_THROTTLE := 2
const FLAG_IN_PIT := 4
const FLAG_KERS := 8
const FLAG_ON_GRID := 16
const RECORD_BYTES := 22
const CLIENT_BYTES := 2 + RECORD_BYTES
const MAX_COORD := 100000.0
const MAX_SPEED := 150.0


## One car as sent over the network.
class NetCar:
	extends RefCounted
	var position := Vector2.ZERO
	var heading := 0.0
	var velocity := Vector2.ZERO
	var steer := 0.0
	var flags := 0

	static func from_car(car: Car, extra_flags: int) -> NetCar:
		var net := NetCar.new()
		net.position = car.state.position
		net.heading = car.state.heading
		net.velocity = car.state.velocity
		net.steer = car.state.steer
		net.flags = extra_flags
		if car.last_input.brake:
			net.flags |= FLAG_BRAKE
		if car.last_input.throttle:
			net.flags |= FLAG_THROTTLE
		if car.kers.is_active():
			net.flags |= FLAG_KERS
		return net

	func has(flag: int) -> bool:
		return flags & flag != 0


static func encode_client(seq: int, car: NetCar) -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	buffer.put_u16(seq & 0xFFFF)
	_write(buffer, car)
	return buffer.data_array


## Returns [seq, NetCar] or [] if the packet is malformed.
static func decode_client(data: PackedByteArray) -> Array:
	if data.size() != CLIENT_BYTES:
		return []
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = data
	var seq := buffer.get_u16()
	var car := _read(buffer)
	return [seq, car] if car else []


## cars: index -> NetCar (index = position in the race's car list).
static func encode_snapshot(tick: int, cars: Dictionary) -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	buffer.put_u32(tick & 0xFFFFFFFF)
	buffer.put_u8(cars.size())
	for index: int in cars:
		buffer.put_u8(index)
		_write(buffer, cars[index])
	return buffer.data_array


## Returns [tick, {index: NetCar}] or [] if malformed (also: index >= car_count, duplicates).
static func decode_snapshot(data: PackedByteArray, car_count: int) -> Array:
	if data.size() < 5:
		return []
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = data
	var tick := buffer.get_u32()
	var count := buffer.get_u8()
	if count > car_count or data.size() != 5 + count * (1 + RECORD_BYTES):
		return []
	var cars := {}
	for i in count:
		var index := buffer.get_u8()
		var car := _read(buffer)
		if car == null or index >= car_count or cars.has(index):
			return []
		cars[index] = car
	return [tick, cars]


static func _write(buffer: StreamPeerBuffer, car: NetCar) -> void:
	buffer.put_float(car.position.x)
	buffer.put_float(car.position.y)
	buffer.put_float(car.heading)
	buffer.put_float(car.velocity.x)
	buffer.put_float(car.velocity.y)
	buffer.put_8(clampi(roundi(car.steer * 127.0), -127, 127))
	buffer.put_u8(car.flags & 0xFF)


static func _read(buffer: StreamPeerBuffer) -> NetCar:
	var car := NetCar.new()
	car.position = Vector2(buffer.get_float(), buffer.get_float())
	car.heading = buffer.get_float()
	car.velocity = Vector2(buffer.get_float(), buffer.get_float())
	car.steer = buffer.get_8() / 127.0
	car.flags = buffer.get_u8()
	if not (car.position.is_finite() and car.velocity.is_finite() and is_finite(car.heading)) \
			or absf(car.position.x) > MAX_COORD or absf(car.position.y) > MAX_COORD \
			or car.velocity.length() > MAX_SPEED or absf(car.heading) > TAU:
		return null
	return car
