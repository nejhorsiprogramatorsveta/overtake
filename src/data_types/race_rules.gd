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

@export_group("Grid")
## First grid slot: metres behind the start line; next slots this far apart, alternating sides.
@export var grid_first := 10.0
@export var grid_spacing := 8.0
@export var grid_lateral := 4.5

@export_group("Braking points")
## A braking zone gets a BP board only if the car loses at least this much speed (m/s).
@export var bp_min_speed_drop := 8.0
