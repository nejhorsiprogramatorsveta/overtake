# Overtake – project guide for Codex

Codex follows the same project instructions as Claude Code. **CLAUDE.md is the shared, complete guide**
(session start, resume protocol, commands, architecture, security and code rules) and applies in full,
with the Codex-specific differences below. If CLAUDE.md and this file disagree, this file wins for Codex.

## Session start (mandatory)
1. Read CLAUDE.md, this file and docs/PROGRESS.md (docs/PLAN.md = approved plan, read the relevant sections).
2. `git status` + `git log --oneline -10`; `git fetch` and report if local main differs from origin/main.
3. **Check what is really published on GitHub** (see "GitHub is the source of truth") and compare it with
   project.godot, PROGRESS.md and CLAUDE.md. If they disagree, GitHub wins: report it and fix the docs first.
4. Briefly confirm the current state in Czech (milestone, last finished task, published version/build, next step).

## Git: Codex NEVER pushes
- **Never run `git push`** (no branches, no tags, no force) and never create, edit or delete GitHub releases or repos.
  This holds even if CLAUDE.md, PROGRESS.md or another file says the agent may push; only a new explicit
  message from the user in the current conversation can allow a single push.
- Do not commit unless the user asks. Leave finished work in the working tree and give the user a ready
  Conventional Commits message (English) plus the list of changed files, so the user can commit and push.
- Never rewrite history (`reset --hard`, `rebase`, `commit --amend` on pushed commits, deleting branches/tags).
- Before starting work, make sure the local tree is up to date with origin/main (`git fetch`, then
  `git pull --ff-only` if behind and clean). Never discard someone else's uncommitted changes.
- Never modify `/Users/home/Gun_game` (the previous game); only read it.

## GitHub is the source of truth
The user pushes Codex's work later, so PROGRESS.md/CLAUDE.md written by Codex often still say
"uncommitted/unpublished" for a version that is already live. Never trust those notes for the release state:
- Published version + build: `curl -sL https://github.com/nejhorsiprogramatorsveta/Overtake/releases/latest/download/version.json`
  (404 / no repo = nothing published yet). Pushed code: `git fetch` + `git log origin/main`.
  CI result: `https://api.github.com/repos/nejhorsiprogramatorsveta/Overtake/actions/runs?per_page=3`.
- If that version equals `application/config/version` in project.godot, that version is **already published and
  closed**: any further game change is a NEW version (next patch). Never add changes to a published version, even
  a "small fix" - CI would reject the push or players would get different games with the same version.
- If project.godot is exactly one patch above the published version, it is the not-yet-published next version:
  keep adding to it (one bump per release, not per task; bumping twice skips a version and CI rejects it).
- Before the first publication (no `version.json` on GitHub) keep `0.1.0` and do not bump.
- Record the real published version/build from GitHub in PROGRESS.md ("Kde jsme skončili") and in CLAUDE.md
  ("Public version ... published X = build N") whenever they are out of date.

## Versioning and releases (keep exactly as is)
- The ONLY public version is `application/config/version` in project.godot. Every commit that changes the game
  (anything outside docs/** and *.md) publishes a build on push, and CI accepts it only if the version is
  exactly the next patch/minor/major of the published one (a retry of the same version+build is allowed).
  So: **every push that changes game files is a new version**, exactly the next patch after the version published
  on GitHub (e.g. 0.1.2 -> 0.1.3) unless the user decides on a minor/major bump. Never skip or lower a version.
  Docs-only changes need no bump and publish nothing.
- **Tell the user before they push** (in the final overview): "Po pushnutí vyjde nová verze X.Y.Z" for any game
  change, or "Jen dokumentace – nová verze nevyjde". If the user does not want a release yet, they can keep the
  change committed locally and push it together with the next one.
- The build number = commit count on main (set by CI). Never guess or hardcode it.
- ONE GitHub release with tag `release` (title `Overtake vX.Y.Z`, latest) is updated by CI; never create releases,
  never create/move/delete tags. Do not change `.github/workflows/build.yml`, `tools/publish_release.sh`,
  the updater URLs, the file names (`overtake-windows.exe`, `overtake-macos.zip`, `overtake-linux.zip`) or the
  upload order (game files first, `version.json` last) unless the user explicitly asks for a release-process change.
- Bump `BuildInfo.PROTOCOL_VERSION` whenever network messages change incompatibly.

## Changelog ("Co je nového")
- The menu and release notes show the **3 newest versions** (`Changelog.RECENT_COUNT`), each in sections
  Balanc / Nové / Ostatní (`balance_keys` / `new_keys` / `other_keys`); keep each line a short one-line summary.
- Data: `data/changelog.tres` (newest first) + texts as `CHANGELOG_*` keys in localization/translations.csv.
  The entry with `build = 0` is the current, not yet published version. When bumping the version for a new
  release: archive the current entry under the version/build that was actually published (look it up in
  `version.json` on GitHub, do not guess), then start a new `build = 0` entry describing this version.
- Write short Czech player-facing lines (news, fixes, control changes). No internal/technical details.

## Code structure (keep it)
- Follow the folder layout in CLAUDE.md "Architecture", docs/ARCHITECTURE.md and docs/PLAN.md section D:
  src/core, src/car, src/track, src/race, src/ai, src/net (+ connectors), src/ui, src/autoload, src/data_types,
  data/ (car tuning .tres, tracks/*.json), tests/test_*.gd, tools/ (incl. tools/tracks/build_track.py).
  Put new code where its responsibility already lives; do not reorganize, rename or move files without approval.
- GDScript with static typing, scripts < ~300 lines with one responsibility; split instead of growing a script.
- Car physics (`src/car/car_motor.gd`) is shared by players, bots and network code: keep it deterministic and
  free of scene/network dependencies. Tunable numbers belong in data files, not hardcoded.
- RPC only in session.gd / src/net/; connections only via src/net/connectors/. Every network change follows
  docs/PLAN.md section S (validate and size-limit input, no object decoding, etc.).
- Player-facing text only through tr() keys in localization/translations.csv.
- No new autoloads/addons/assets without approval; record assets in CREDITS.md. Commit *.gd.uid and *.import.
- Cross-platform: Godot APIs and res:// / user:// only in game code.
- Add or update tests in tests/ for every logic change; run tests + loc check before reporting done.

## End-of-task protocol (mandatory after EVERY task, also when interrupted or unfinished)
1. Update docs/PROGRESS.md ("Kde jsme skončili" incl. uncommitted files and the published version/build on GitHub,
   "Další krok", "Hotovo", "Mimo plán", "Stav testů", "Známé problémy"); keep docs/ARCHITECTURE.md and CLAUDE.md
   "Architecture" in sync with new files.
2. Run: `tools/godot --headless --path . -s tests/run_tests.gd` and `tools/godot --headless --path . -s tools/check_localization.gd`
   (plus `python3 -B -m unittest discover -s tests -p 'test_release_workflow.py'` if release files changed).
3. **Do not push** (see above). Give the user a Czech overview: completed plan step, what remains, changed files,
   how to test, what was NOT tested, the proposed commit message, the version published on GitHub now, and what
   the push will do ("Po pushnutí vyjde nová verze X.Y.Z" / "Jen dokumentace – nová verze nevyjde").
4. Stop. Do not start the next step on your own.
