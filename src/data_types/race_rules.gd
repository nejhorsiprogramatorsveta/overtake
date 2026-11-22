class_name RaceRules
extends Resource
## Race rules and their numbers (data/race/race_rules.tres, PLAN.md B). Times in seconds.

@export_group("Race")
## Default number of laps (the host will choose it in the lobby, M4).
@export var laps := 5

@export_group("Start")
## Time on the grid before the first light comes on.
@export var grid_time := 2.0
## One more red light every light_interval seconds (5 lights).
@export var light_interval := 1.0
## All five lights stay on for a random time in this range, then go out.
@export var hold_min := 0.2
@export var hold_max := 3.0
## Letting the clutch go before the lights are out.
@export var jump_start_penalty := 5.0
## Not holding the clutch when the lights go out: the car leaves this much later (bogged start).
@export var no_clutch_delay := 0.6

@export_group("Track limits")
## Leaving the track completely (the whole car beyond the kerb) this many times only warns...
@export var track_limit_warnings := 3
## ...every further time costs this many seconds.
@export var track_limit_penalty := 5.0
## Cutting the track: gaining more than this many metres while off it is penalised at once.
@export var shortcut_min_gain := 25.0
@export var shortcut_penalty := 5.0

@export_group("Pit lane")
## Pit lane centre this far outside the asphalt edge (m), on the inside of the lap.
@export var pit_offset := 15.0
## Length of the entry/exit curve between the track and the pit lane (m).
@export var pit_blend := 70.0
## Speed limit in the pit lane (m/s; 22.2 = 80 km/h) and the autopilot's braking/acceleration.
@export var pit_speed := 22.2
@export var pit_decel := 30.0
@export var pit_accel := 8.0
## Garage boxes along the pit lane: first one this far after the pit lane start, then spacing.
@export var pit_first_box := 50.0
@export var pit_box_spacing := 16.0

@export_group("Pit stop")
## After stopping: short wait, then the bar runs from 0 to 100 % in pit_bar_time.
@export var pit_prepare := 0.4
@export var pit_bar_time := 1.4
## Stop time when Space is pressed at the very end of the bar (best) / at its start (worst).
@export var pit_best := 2.0
@export var pit_worst := 4.5
## The green zone is only the end of the bar (user 2026-11-22): from pit_green_from (0..1) the
## stop gets from pit_good down to pit_best; before it from pit_worst to pit_good.
@export var pit_green_from := 0.85
@export var pit_good := 2.6
## Not pressed before the bar ends: a fumble, pit_worst + pit_fumble seconds.
@export var pit_fumble := 3.0

@export_group("Grid")
## First grid slot: metres behind the start line; next slots this far apart, alternating sides.
@export var grid_first := 10.0
@export var grid_spacing := 8.0
@export var grid_lateral := 4.5

@export_group("Braking points")
## A braking zone gets a BP board only if the car loses at least this much speed (m/s).
@export var bp_min_speed_drop := 8.0
