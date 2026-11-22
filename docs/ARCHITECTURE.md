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

## Auto, trať a trénink (M1)
| Soubor | Odpovědnost |
|---|---|
| `src/data_types/car_tuning.gd`, `data/car/car_tuning.tres` | `CarTuning`: všechna čísla fyziky auta (výkon, brzdy, grip, řízení, rozměry). |
| `src/car/car_state.gd`, `src/car/car_input.gd` | Stav auta (pozice, směr, rychlost, řízení, multiplikátory výkonu/odporu) a vstup jednoho ticku. |
| `src/car/car_motor.gd` | `CarMotor.step`: deterministická fyzika (výkon/rychlost, odpor vzduchu, kruh adheze, kačírek, couvání). Sdílí hráč, boti i síť. |
| `src/car/car.gd`, `src/car/car_view.gd` | Uzel auta (simulace za tick, poloha na trati, bariéra) a jeho vektorová kresba. |
| `src/track/track_data.gd` | `TrackData`: načtení `data/tracks/<id>.json`, vzdálenosti, tečny, křivost, pozice podle vzdálenosti. |
| `src/track/track_query.gd` | `TrackQuery`: nejbližší místo na středové čáře (s nápovědou), boční odsazení, povrch trať/kačírek/bariéra. |
| `src/track/track_catalog.gd` | Seznam tratí (id → soubor, název) a cache načtených dat. |
| `src/track/speed_profile.gd` | Nejvyšší možná rychlost v každém bodě (zatáčky, brzdění) → kalibrace času kola, později BP a boti. |
| `src/track/track_view.gd` | Vektorová trať: tráva, bariéry, kačírek v zatáčkách, asfalt, obrubníky, čáry, start/cíl (meshe). |
| `src/track/minimap.gd` | Minimapa trati s tečkami aut. |
| `src/race/lap_tracker.gd` | Počítání kol a časů (sektory v pořadí, interpolace průjezdu cílem). |
| `src/race/race_camera.gd` | Kamera sever-nahoru, pohled dopředu, oddálení podle rychlosti. |
| `src/race/race_controller.gd`, `src/race/race.tscn` | Trénink (letmý start, nekonečná kola) a sólo závod (rošt, světla, N kol, cíl); Esc = menu. |
| `src/ui/race_hud.gd` | HUD: kolo, časy, minimapa, rychlost, startovní světla, cílový panel. |
| `src/data_types/race_rules.gd`, `data/race/race_rules.tres` | `RaceRules`: počet kol, start (světla, pauza, penalizace), rošt, práh BP. |
| `src/track/braking_points.gd`, `src/track/bp_markers.gd` | Brzdné body z rychlostního profilu a jejich bílé tabule „BP“ (na vnější straně zatáčky). |
| `src/race/race_start.gd` | `RaceStart`: rošt → 5 světel → náhodná pauza → zhasnutí; spojka, reakce, předčasný/pomalý start. |
| `src/ui/start_lights_view.gd` | Startovní světla nahoře uprostřed + nápověda, reakce, penalizace. |
| `tools/tracks/build_track.py`, `tools/tracks/tracks.json`, `tools/tracks/src/*.geojson` | Převod reálných tvarů tratí (bacinger/f1-circuits, MIT) na `data/tracks/*.json` (měřítko, šířka, vyhlazení). |

Jednotky ve světě hry jsou metry (kamera zoomuje), rychlosti m/s (HUD × 3,6 = km/h). Fyzika běží 60 Hz,
vykreslování je vyhlazené zapnutou physics interpolation.

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
