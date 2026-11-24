# Overtake – project guide for Claude Code

## Session start (mandatory)
1. Read this file and docs/PROGRESS.md (docs/PLAN.md = approved plan, read the relevant sections).
2. `git status` + `git log --oneline -10`. Once the GitHub repo exists: `git fetch` and read the published version/build from
   https://github.com/nejhorsiprogramatorsveta/Overtake/releases/latest/download/version.json - GitHub is the source of truth
   (Codex's work is pushed by the user, so PROGRESS.md may still call a published version "unpublished").
3. Briefly confirm the current state in Czech (milestone, last finished task, next step).

## Resume protocol ("přečti si progress a pokračuj")
If the user only says to read progress and continue: do the session start, then execute exactly the task in
PROGRESS.md "Další krok" – nothing more. If "Další krok" is unclear, blocked, or needs a user decision, ask instead of guessing.
If PROGRESS.md and git disagree (e.g. uncommitted changes, task half-done), report it first.

## End-of-task protocol (mandatory after EVERY task, also when interrupted or unfinished)
Codex has its own rules in codex.md (loaded via AGENTS.md): it must NEVER push; the user pushes its work.
1. Update docs/PROGRESS.md: "Kde jsme skončili", "Další krok" (one concrete task), "Hotovo", "Mimo plán" (extra work and
   ideas outside the plan), "Stav testů", "Známé problémy". Keep docs/ARCHITECTURE.md and the Architecture section below in sync.
2. Run tests + loc check (+ release workflow tests if release files changed).
3. Commit locally (Conventional Commits, English). Push to origin main ONLY after the user says so ("pushni");
   the FIRST publication of the game happens only when the user explicitly asks for it. After a push, check that
   the GitHub Actions run succeeded.
4. Give the user a Czech overview: which plan step was completed, what remains in the milestone, changed files,
   how to test, what was NOT tested, commit hash (+ CI result after a push).
5. Stop. Do not start the next step on your own.
If the user says "ulož progress", do step 1 immediately.

## Communication
Respond to the user in Czech. Code, identifiers, commits in English (Conventional Commits).
Player-facing text only via tr() keys in localization/translations.csv (Czech column `cs`).

## Purpose
"Overtake": online 2D top-down F1-style racing game (original look, genre reference Formula Racing 2D) for friends
over Tailscale / the same Wi-Fi, with bots. Downloads for Windows (.exe), macOS (.app in .zip), Linux (.zip) from
GitHub Releases, in-game auto-update. Infrastructure and working rules are taken over from Gun game
(`/Users/home/Gun_game` – NEVER modify that folder; copy and adapt files from it instead).

## Stack
Godot 4.7.2-stable (non-.NET), GDScript (static typing), Compatibility renderer, physics 60 Hz.
User decision 2026-11-22: stay with Godot; download size of ~30–110 MB per platform is fine (must never approach 1 GB).
Vector style: everything is drawn in code (draw_* / Polygon2D), no bitmap sprites; UI theme assets/ui/theme.tres (StyleBoxFlat),
Godot's default font (supports Czech).

## Commands (pinned Godot lives in .tools/, never use a system-wide godot)
- Setup dev env (once): `tools/setup_env.sh` (add `--with-templates` for local exports).
- Import (after clean clone or new assets; the 1st run logs harmless translation errors): `tools/godot --headless --path . --import`
- Run game: `tools/godot --path .`   Editor: `tools/godot --path . --editor`
- Tests: `tools/godot --headless --path . -s tests/run_tests.gd` (exit 1 on failure)
- Loc check: `tools/godot --headless --path . -s tools/check_localization.gd` (exit 1 on a missing key)
- Release workflow tests (gh is mocked): `python3 -B -m unittest discover -s tests -p 'test_release_workflow.py'`
- Release notes preview: `tools/godot --headless --path . -s tools/write_release_notes.gd -- --output=res://.tools/notes.md`
- Export: `tools/godot --headless --path . --export-release "<Windows Desktop|macOS|Linux>" build/<os>/<file>`
- Smoke tests / screenshots: throwaway `extends SceneTree` script in the scratchpad (outside the repo), run with
  `tools/godot --path . -s <script>` (no `--headless` for screenshots); `Input.action_press()` simulates keys.
- CI: .github/workflows/build.yml (push main -> tests -> 3 exports -> update the ONE release with tag `release`).
- Public version comes ONLY from `application/config/version` in project.godot (0.1.0 build 42 published 2026-11-24;
  source 0.1.1, not pushed yet). Every push of game files = exactly the next version; archive the changelog first.

## Architecture (see docs/ARCHITECTURE.md for what exists, docs/PLAN.md section D for the target)
- `src/autoload/settings.gd` (autoload Settings: player name, practice track, rebound controls in user://settings.cfg).
- `src/core/build_info.gd` (BuildInfo: version/build/commit, PROTOCOL_VERSION 1), `src/core/changelog.gd` +
  `data/changelog.tres` (ChangelogData, `src/data_types/changelog_data.gd`; sections balance_keys/new_keys/other_keys,
  3 newest versions), `src/core/updater.gd` + `src/core/update_installer.gd` (auto-update from this repo's release),
  `src/core/key_bindings.gd` (actions throttle, brake, steer_left, steer_right, clutch, kers; 2 slots each; Esc/F3 reserved).
- `src/ui/main_menu.{gd,tscn}` (name, Trénink/Závod -> `src/ui/session_setup.{gd,tscn}` with track, car colour
  (`src/car/car_colors.gd`, team names), tyre wear, laps; settings, changelog, quit, version, update panel),
  `src/ui/settings_screen.{gd,tscn}` (rebinding), `src/ui/menu_background.gd` (MenuBackground: vector backdrop).
- M1 (practice): `src/car/{car_state,car_input,car_motor,car,car_view}.gd` (CarMotor = deterministic physics with a
  friction circle; `data/car/car_tuning.tres` = CarTuning), `src/track/{track_data,track_query,track_catalog,
  speed_profile,track_view,minimap}.gd`, `src/race/{lap_tracker,race_camera,race_controller}.gd` + `race.tscn`,
  `src/ui/race_hud.gd`. M2: `src/race/race_start.gd` (lights + clutch), `src/track/{braking_points,bp_markers}.gd`,
  `src/ui/start_lights_view.gd`, `data/race/race_rules.tres` (RaceRules); `src/car/{kers,slipstream}.gd` +
  `src/ui/kers_gauge.gd` (Car.simulate(input, dt, others) runs KERS, slipstream, then CarMotor);
  `src/race/shortcut_check.gd` (no track limits since 2026-11-22, only cutting the track +5 s; Racer.penalty sums start + shortcuts + incidents);
  `src/car/tyre_model.gd` (optional wear -> CarState.grip_multiplier; player's BP boards recomputed per 1 % grip;
  offline toggle Settings.tyre_wear in the menu). Note: autoload Settings._ready runs after a -s script's _initialize.
  Pit: `src/race/{pit_lane,pit_stop,pit_minigame,pit_lane_view}.gd`, `src/ui/pit_popup.gd` (PitStop.update drives the car
  kinematically while active; Car.after_external_move / set_ghost). Long smoke runs: the macOS window may be covered and
  screenshots go stale - use short scenes that place the car where needed.
  Racers: `src/race/{racer,race_ranking}.gd`, `src/ui/results_view.gd`; RaceController._tick(racer, input, dt) runs one
  driver (start hold, pit autopilot, physics with other cars for the tow, laps, limits); me = the player's Racer.
  Bots: `src/ai/{racing_line,bot_driver,bot_tactics}.gd` (tow on straights, pull out before braking) (racing line offsets in the track JSON from build_track.py; Racer.bot).
  Contact: `src/car/car_collision.gd` + `src/race/incident_judge.gd`, resolved after all racers ticked
  (RaceController._resolve_contacts); Racer.is_ghost (pit, start, penalty, finished).
  Qualifying (optional, offline + online): `src/race/{race_builder,qualifying,race_info}.gd`; RaceController.Mode
  QUALIFYING, then the scene reloads as RACE with the grid (offline RaceController.next_grid, online
  Session.race_setup.grid_order via RaceNet.send_grid). RaceNet.client_seq/host_tick persist across scenes.
  Logs (from Gun game): `src/core/diag_file_logger.gd`, `src/net/{diag_log,connection_log}.gd`, `src/race/race_log.gd`
  -> user://logs/last_game.log (last game; never IPs or names); Settings button opens the folder.
  Help: `src/ui/{help_screen,help_shot}.gd` ("Jak hrát": track cut-outs in SubViewports sharing one World2D).
  `tests/test_scripts_compile.gd` loads every src script (catches parse errors in untested scripts). RaceController.Mode PRACTICE/RACE
  (menu sets RaceController.next_mode). Screenshots of a covered game window can be stale - check the values
  printed alongside. World units are metres; physics 60 Hz with physics interpolation on.
  Renderer Compatibility has no 2D MSAA/FXAA (warnings) - do not enable them.
  M3G graphics: `src/track/{track_view,track_surface,track_scenery,city_scenery,mesh_builder,keep_out_map}.gd`
  (TrackData.style "city_night" = Las Vegas: CityScenery + CanvasModulate night, TrackData.landmarks) - everything is built
  once into vertex-coloured meshes (MeshBuilder), deterministic per track id; scenery placement via KeepOutMap.
  Cars: `src/car/car_view.gd` (2026-style drawing), effects `src/car/{car_effects,tyre_smoke}.gd` + `src/track/skid_marks.gd`
  (look only, driven by CarState.slide/wheelspin); HUD look `src/ui/{hud_style,speed_gauge}.gd` (RPM monitor from `src/car/engine_revs.gd`).
  Online (M4): autoload `Session` (`src/autoload/session.gd`) + `src/net/` (connectors, handshake, session_auth,
  lobby_validator, race_setup, car_codec, state_buffer, jitter_clock, snapshot_timeline, race_net = the only race RPCs)
  + `src/race/online_race.gd`. Own car simulated by its owner; other cars are Racer.remote (from network states on the
  sender's timeline); host decides finish, penalties, results (race info 5×/s). Port 24650. Two-instance test: run one
  instance that hosts and one that joins 127.0.0.1:24650#CODE (scratchpad smoke scripts, headless works).
- Tracks: `python3 -I tools/tracks/build_track.py [id] [--preview DIR]` turns `tools/tracks/src/*.geojson`
  (bacinger/f1-circuits, MIT) into `data/tracks/<id>.json` using `tools/tracks/tracks.json` (scale, width).
  Register a new track in `TrackCatalog` (FILES, NAME_KEYS) and add `TRACK_*_NAME` to the CSV. Tracks: austria,
  brazil, china, las_vegas, avus (AVUS is not in bacinger: own drawing by tools/tracks/make_avus.py;
  tests/test_all_tracks.gd checks pit lane, racing line and Expert lap on every track).
- tools/: setup_env.sh, godot, write_build_info.gd, write_release_notes.gd, check_localization.gd, publish_release.sh.

## Rules
SECURITY: every network change must follow docs/PLAN.md section S (no object decoding, server_relay off, validate and
size-limit all input, room code to join, NO UPnP/port opening, never show the public IP; internet play = Tailscale).
Code must run on Windows, macOS and Linux: Godot APIs and res:// / user:// only in game code; shell scripts are dev-only.
Netcode (PLAN.md C): each player's own car is simulated by its owner; the host validates and decides race rules,
bots, lap counting, results. RPC only in session.gd / src/net/. Connection only via src/net/connectors/.
Scripts < ~300 lines, one responsibility. No new autoloads/addons/assets without approval. Record assets in CREDITS.md.
Track shapes come from bacinger/f1-circuits (MIT, see CREDITS.md); no F1 logos or sponsors in the game; car colour layouts (CarLivery: zones + shape) are inspired by the 2025/2026 grid (user 2026-11-23) and the car choice shows the real team names (CarColors.NAME_KEYS, user 2026-11-24).
Commit *.gd.uid and *.import files; *.translation, .godot/, build/, build_info.json are generated (gitignored).
Add or update tests for every logic change. Never claim something works unless tested.
