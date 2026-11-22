class_name TrackLimits
extends RefCounted
## Track limits of one car (PLAN.md B, user 2026-11-22). The white line at the asphalt edge
## is the limit, the kerb still counts as track; a VIOLATION = the whole car beyond the kerb.
## One excursion = one violation (counted again only after coming back). The first
## RaceRules.track_limit_warnings violations are warnings, every further one costs
## track_limit_penalty seconds. Gaining more than shortcut_min_gain metres along the lap while
## off the track (cutting a corner) costs shortcut_penalty at once. In M4 the host runs this.

enum Event { NONE, WARNING, PENALTY, SHORTCUT }

var rules: RaceRules
var violations := 0
## Seconds added to the race time.
var penalty := 0.0
var _outside := false
var _gain := 0.0
var _shortcut_given := false
var _last_distance := -1.0


func _init(race_rules: RaceRules) -> void:
	rules = race_rules


## Call every tick after the car moved. travelled = metres the car actually drove this tick.
func update(track: TrackData, query: TrackQuery, car_width: float, travelled: float) -> Event:
	var progress := 0.0
	if _last_distance >= 0.0:
		progress = query.distance - _last_distance
		if progress > track.length * 0.5:
			progress -= track.length
		elif progress < -track.length * 0.5:
			progress += track.length
	_last_distance = query.distance
	var beyond := absf(query.lateral) - (track.half_width() + TrackData.KERB_WIDTH)
	var event := Event.NONE
	if not _outside and beyond > car_width * 0.5:
		_outside = true
		_gain = 0.0
		_shortcut_given = false
		violations += 1
		if violations > rules.track_limit_warnings:
			penalty += rules.track_limit_penalty
			event = Event.PENALTY
		else:
			event = Event.WARNING
	elif _outside and beyond <= 0.0:
		_outside = false  # back on the track (kerb included): the next excursion counts again
	if _outside:
		_gain += progress - travelled
		if not _shortcut_given and _gain > rules.shortcut_min_gain:
			_shortcut_given = true
			penalty += rules.shortcut_penalty
			event = Event.SHORTCUT
	return event


func is_outside() -> bool:
	return _outside
