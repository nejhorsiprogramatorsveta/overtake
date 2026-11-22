# Architektura (co v projektu skutečně existuje)

Cílová struktura je v [PLAN.md](PLAN.md) sekce D. Tento soubor popisuje jen to, co už je hotové.

## Jádro (M0)
| Soubor | Odpovědnost |
|---|---|
| `src/autoload/settings.gd` | Autoload `Settings`: jméno hráče, trať pro trénink, přebindované klávesy (`user://settings.cfg`). |
| `src/core/build_info.gd` | `BuildInfo`: verze z `project.godot`, build/commit z `build_info.json` (generuje CI), `PROTOCOL_VERSION`. |
| `src/core/changelog.gd`, `src/data_types/changelog_data.gd`, `data/changelog.tres` | „Co je nového“ a poznámky k vydání (3 nejnovější verze, sekce Balanc/Nové/Ostatní). |
| `src/core/updater.gd`, `src/core/update_installer.gd` | Automatická aktualizace z GitHub vydání (SHA-256, výměna exe/.app/binárky). |
| `src/core/key_bindings.gd` | Přebindovatelné ovládání: plyn, brzda, zatáčení, spojka, KERS (2 klávesy na akci). |
| `src/ui/main_menu.{gd,tscn}` | Hlavní menu (jméno, nastavení, co je nového, konec, verze, aktualizace). |
| `src/ui/settings_screen.{gd,tscn}` | Nastavení ovládání. |
| `src/ui/menu_background.gd` | Vektorové pozadí menu (asfalt, obrubník, šachovnice). |
| `assets/ui/theme.tres` | Globální vektorové UI téma (StyleBoxFlat), výchozí font Godotu. |

## Nástroje a CI
| Soubor | Odpovědnost |
|---|---|
| `tools/setup_env.sh`, `tools/godot` | Stažení a spuštění připnutého Godotu 4.7.2 z `.tools/`. |
| `tools/write_build_info.gd` | CI: `build_info.json` + verze do macOS presetu. |
| `tools/write_release_notes.gd` | CI: poznámky k vydání ze changelogu. |
| `tools/check_localization.gd` | Kontrola, že každý použitý klíč má český text. |
| `tools/publish_release.sh` | CI: aktualizace jediného vydání `release` (soubory hry → `version.json` → titulek/latest). |
| `.github/workflows/build.yml` | CI: testy, export 3 platforem, manifest, publikace. |
| `tests/run_tests.gd`, `tests/test_case.gd`, `tests/test_*.gd` | Unit testy (bez addonu). |
| `tests/test_release_workflow.py` | Testy publikačního skriptu s falešným `gh`. |
