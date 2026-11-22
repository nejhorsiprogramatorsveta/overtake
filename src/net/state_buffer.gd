class_name StateBuffer
extends RefCounted
## Recent states of one remote car on its sender's timeline (ms), sampled at the render time of
## a SnapshotTimeline: interpolated between the two states around it, extrapolated from the
## newest one for a short gap (packet loss), never further than MAX_EXTRAPOLATION_MS.

const MAX_STATES := 32
const MAX_EXTRAPOLATION_MS := 120.0

var _times: Array[float] = []
var _states: Array[CarCodec.NetCar] = []


func push(time_ms: float, state: CarCodec.NetCar) -> void:
	if not _times.is_empty() and time_ms <= _times[-1]:
		return  # old or duplicate (unreliable_ordered still guards this)
	_times.append(time_ms)
	_states.append(state)
	if _times.size() > MAX_STATES:
		_times.pop_front()
		_states.pop_front()


func is_empty() -> bool:
	return _states.is_empty()


func newest() -> CarCodec.NetCar:
	return _states[-1] if not _states.is_empty() else null


## The state to show at `time_ms` on the sender's timeline (null before the first state).
func sample(time_ms: float) -> CarCodec.NetCar:
	if _states.is_empty():
		return null
	if time_ms <= _times[0]:
		return _states[0]
	for i in range(_times.size() - 1, 0, -1):
		if _times[i - 1] <= time_ms and time_ms <= _times[i]:
			var t := (time_ms - _times[i - 1]) / maxf(_times[i] - _times[i - 1], 0.001)
			return _blend(_states[i - 1], _states[i], t)
	var ahead := minf(time_ms - _times[-1], MAX_EXTRAPOLATION_MS) / 1000.0
	var newest_state := _states[-1]
	var result := CarCodec.NetCar.new()
	result.position = newest_state.position + newest_state.velocity * ahead
	result.heading = newest_state.heading
	result.velocity = newest_state.velocity
	result.steer = newest_state.steer
	result.flags = newest_state.flags
	return result


static func _blend(a: CarCodec.NetCar, b: CarCodec.NetCar, t: float) -> CarCodec.NetCar:
	var result := CarCodec.NetCar.new()
	result.position = a.position.lerp(b.position, t)
	result.heading = lerp_angle(a.heading, b.heading, t)
	result.velocity = a.velocity.lerp(b.velocity, t)
	result.steer = lerpf(a.steer, b.steer, t)
	result.flags = b.flags if t >= 0.5 else a.flags
	return result
