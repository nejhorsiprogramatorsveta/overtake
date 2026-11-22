class_name ShortcutCheck
## Cutting the track (PLAN.md B). There are no track limits (user 2026-11-22: removed) - running
## wide over the kerb costs only time in the gravel. But while the whole car is beyond the kerb,
## the metres gained along the lap minus the metres actually driven are summed, and gaining more
## than RaceRules.shortcut_min_gain (cutting a corner) costs shortcut_penalty seconds at once,
## once per excursion. In M4 the host runs this.
extends RefCounted

var rules: RaceRules
## Seconds added to the race time.
var penalty := 0.0
## Shortcuts penalised so far.
var count := 0
var _outside := false
var _gain := 0.0
var _given := false
var _last_distance := -1.0


func _init(race_rules: RaceRules) -> void:
	rules = race_rules


## Call every tick after the car moved. travelled = metres the car actually drove this tick.
## Returns true on the tick a shortcut penalty is given.
func update(track: TrackData, query: TrackQuery, car_width: float, travelled: float) -> bool:
	var progress := 0.0
	if _last_distance >= 0.0:
		progress = query.distance - _last_distance
		if progress > track.length * 0.5:
			progress -= track.length
		elif progress < -track.length * 0.5:
			progress += track.length
	_last_distance = query.distance
	var beyond := absf(query.lateral) - (track.half_width() + TrackData.KERB_WIDTH)
	if not _outside and beyond > car_width * 0.5:
		_outside = true
		_gain = 0.0
		_given = false
	if not _outside:
		return false
	# Counted before coming back: the tick that lands on another part of the lap counts too.
	_gain += progress - travelled
	if beyond <= 0.0:
		_outside = false
	if _given or _gain <= rules.shortcut_min_gain:
		return false
	_given = true
	count += 1
	penalty += rules.shortcut_penalty
	return true


## After the pit lane (not judged): start measuring again from where the car is now.
func reset_position() -> void:
	_last_distance = -1.0
	_outside = false


func is_outside() -> bool:
	return _outside
