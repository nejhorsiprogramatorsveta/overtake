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
| `src/car/car_effects.gd`, `src/car/tyre_smoke.gd`, `src/track/skid_marks.gd` | Jen vzhled: `CarEffects` podle `CarState.slide`/`wheelspin` (z `CarMotor`) kreslí stopy pneumatik do `SkidMarks` (kruhová paměť 6000 segmentů v 20 blocích) a obláčky kouře/prachu do `TyreSmoke` (600 obláčků). |
| `src/car/car_livery.gd` | `CarLivery`: barevné zóny auta (tělo, nos, bočnice, motor, pruhy, křídla, halo, dělení napůl) a tvar (bočnice, nos) pro 11 schémat podle F1 2025/2026. |
| `src/car/car_colors.gd` | `CarColors`: 11 barevných kombinací (hlavní + doplňková) podle monopostů F1 2026, obecné názvy, bez jmen týmů a log. |
| `src/ui/main_menu.{gd,tscn}` | Hlavní menu (jméno, Trénink, Závod, nastavení, co je nového, konec, verze, aktualizace). |
| `src/ui/session_setup.{gd,tscn}` | Nastavení tréninku/závodu: trať, barva auta s náhledem, opotřebení pneumatik, počet kol (v M3 boti). |
| `src/ui/settings_screen.{gd,tscn}` | Nastavení ovládání. |
| `src/ui/menu_background.gd` | Vektorové pozadí menu (asfalt, obrubník, šachovnice). |
| `assets/ui/theme.tres` | Globální vektorové UI téma (StyleBoxFlat), výchozí font Godotu. |

## Auto, trať a trénink (M1)
| Soubor | Odpovědnost |
|---|---|
| `src/data_types/car_tuning.gd`, `data/car/car_tuning.tres` | `CarTuning`: všechna čísla fyziky auta (výkon, brzdy, grip, řízení, rozměry). |
| `src/car/car_state.gd`, `src/car/car_input.gd` | Stav auta (pozice, směr, rychlost, řízení, KERS zrychlení, závěs/odpor) a vstup jednoho ticku. |
| `src/car/car_motor.gd` | `CarMotor.step`: deterministická fyzika (výkon/rychlost, odpor vzduchu, kruh adheze, kačírek, couvání). Sdílí hráč, boti i síť. |
| `src/car/car.gd`, `src/car/car_view.gd` | Uzel auta (simulace za tick, poloha na trati, bariéra) a jeho vektorová kresba ve stylu formulí 2026: rozvor 3,4 m, užší přední pneumatiky a křídlo, halo, bočnice, podlaha, aktivní aerodynamika (klapky se otevřou na rovince – jen vzhled, `Car._straight_mode`), natáčení kol, stín podle slunce, doplňková barva (`CarColors.accent_for`) a kontrastní helma (`CarColors.helmet_for`). |
| `src/track/track_data.gd` | `TrackData`: načtení `data/tracks/<id>.json`, vzdálenosti, tečny, křivost, pozice podle vzdálenosti. |
| `src/track/track_query.gd` | `TrackQuery`: nejbližší místo na středové čáře (s nápovědou), boční odsazení, povrch trať/kačírek/bariéra. |
| `src/track/track_catalog.gd` | Seznam tratí (Rakousko, Brazílie, Čína: id → soubor, název) a cache načtených dat. |
| `src/track/speed_profile.gd` | Nejvyšší možná rychlost v každém bodě (zatáčky, brzdění) → kalibrace času kola, později BP a boti. |
| `src/track/track_view.gd` | Povrch trati (meshe s barvami vrcholů): tráva s pruhy a skvrnami, kačírek se zrnitostí a zúženými konci, obrubníky se stínováním, čáry, start/cíl, namalovaný rošt; `corner_mask` = zatáčkové zóny. |
| `src/track/track_surface.gd` | `TrackSurface`: asfalt s jemným šumem, vyježděná stopa po ideální stopě (tmavší před zatáčkami a v nich), stopy smyků v brzdných zónách a na výjezdu z pomalých zatáček. |
| `src/track/track_scenery.gd` | `TrackScenery`: bariéry z pneumatik s pásem a plotem (ne přes boxovou uličku, kačírek jiné zatáčky ani uvnitř ohybu), tribuny s diváky, lesy, stíny (slunce zleva shora). |
| `src/track/mesh_builder.gd`, `src/track/keep_out_map.gd` | `MeshBuilder`: barevné trojúhelníky → jeden ArrayMesh (pomocné quad/box/kruh/úsek trati); `KeepOutMap`: bitmapa zakázaných míst pro rozmístění okolí. |
| `src/track/minimap.gd` | Minimapa trati s tečkami aut. |
| `src/race/lap_tracker.gd` | Počítání kol a časů (sektory v pořadí, interpolace průjezdu cílem). |
| `src/race/race_camera.gd` | Kamera sever-nahoru, pohled dopředu, oddálení podle rychlosti. |
| `src/race/race_controller.gd`, `src/race/race.tscn` | Trénink (letmý start, nekonečná kola) a závod (rošt, světla, N kol, výsledky); každý jezdec = `Racer`; Esc = menu. |
| `src/ai/racing_line.gd` | `RacingLine`: ideální stopa z dat trati (boční posun v každém bodě, K1999 z `build_track.py`), rychlostní profily po ní (cache po 2 % gripu a podle tempa v zatáčkách). |
| `src/ai/bot_driver.gd` | `BotDriver`: sledování ideální stopy, brzdění podle profilu, provoz (předjíždění, odstup, brzdění za autem s odhadem jeho zpomalení `CarState.accel`), start, KERS, boxy, minihra; 4 obtížnosti. |
| `src/autoload/session.gd` | Autoload `Session`: hostování/připojení (`SessionAuth`, `Handshake`: verze + kód místnosti), lobby (hráči s barvou, nastavení závodu od hostitele), start závodu (`RaceSetup`), návrat do lobby, odpojení. |
| `src/net/connectors/*.gd`, `src/net/{handshake,session_auth,jitter_clock,snapshot_timeline}.gd` | Převzato z Gun game: ENet přes LAN/Tailscale (port 24650, jen LAN/Tailscale adresy), handshake, časová osa vzdálených stavů. |
| `src/net/lobby_validator.gd`, `src/net/race_setup.gd` | Kontrola dat lobby a závodu (typy, rozsahy, unikátní barvy a místa na roštu); hostitel staví rošt (lidé zezadu/náhodně/vpředu, boti). |
| `src/net/car_codec.gd`, `src/net/state_buffer.gd`, `src/net/race_net.gd` | Binární stav auta (24 B, kontrola rozsahů), vyrovnávací paměť s interpolací/extrapolací, `RaceNet` = jediné místo pro RPC závodu (odesílatel, velikost, typy, limit 90 stavů/s). |
| `src/race/online_race.gd` | Online závod: vlastní auto simuluje majitel, ostatní jsou „remote“ (z přijatých stavů); klient posílá auto, hostitel snímek všech aut 60×/s a 5×/s stav závodu (cíl, tresty, boxy, odstoupení); světla až po načtení všech. |
| `src/race/race_hud_feed.gd` | Plnění HUD z `RaceController` každý snímek + dynamické BP. |
| `src/ui/lobby.gd`, `src/ui/lobby.tscn` | Lobby: adresy ke sdílení s kódem, hráči, výběr barvy, nastavení závodu (hostitel), Spustit / Odejít. |
| `src/race/racer.gd` | `Racer`: auto + kola + limity + start + pitstop + výsledek jednoho jezdce (hráč, v M3 boti). |
| `src/race/race_ranking.gd` | Pořadí: dojetí podle celkového času s penalizacemi, ostatní podle ujeté vzdálenosti. |
| `src/ui/standings_view.gd` | Živé pořadí vlevo: pozice, barva, jezdec, odstup od vedoucího (`Racer.gap_to`: čas, kdy vedoucí projel stejné místo). |
| `src/ui/results_view.gd` | Tabulka výsledků (pozice, jezdec, čas/ztráta, penalizace, nejlepší kolo, reakce, zastávky), Znovu / Menu. |
| `src/ui/hud_style.gd`, `src/ui/speed_gauge.gd` | `HudStyle`: společný vzhled HUD (šikmé panely s barevným okrajem, tučné písmo s číslicemi stejné šířky, barvy časů jako v TV, `pop`); `SpeedGauge`: km/h + segmentový ukazatel (modrý při KERS). |
| `src/ui/race_hud.gd` | HUD: pozice (bliknutí při změně), kolo, časy (dokončené kolo fialově/zeleně/žlutě podle `RaceRanking.lap_kind`), penalizace, minimapa, rychlost, startovní světla, hlášky, pit popup, výsledky. |
| `src/data_types/race_rules.gd`, `data/race/race_rules.tres` | `RaceRules`: počet kol, start (světla, pauza, penalizace), rošt, práh BP. |
| `src/track/braking_points.gd`, `src/track/bp_markers.gd` | Brzdné body z rychlostního profilu a jejich bílé tabule „BP“ (na vnější straně zatáčky). |
| `src/race/race_start.gd` | `RaceStart`: rošt → 5 světel → náhodná pauza → zhasnutí; spojka, reakce, předčasný/pomalý start. |
| `src/ui/start_lights_view.gd` | Startovní světla nahoře uprostřed + nápověda, reakce, penalizace. |
| `src/car/kers.gd` | `Kers`: 3 použití za kolo (doplní se při průjezdu cílem, signál `LapTracker.line_crossed`), přídavné zrychlení při plynu; `locked` do uvolnění (`Kers.release_due`: všechna auta projela cílem po startu, nebo první dokončilo kolo). |
| `src/car/slipstream.gd` | `Slipstream`: síla závěsu podle odstupu (≤ 1,5 s) a kuželu za autem, plynulý náběh/odeznění, menší odpor vzduchu. |
| `src/ui/kers_gauge.gd` | HUD: políčka KERS a stav pneumatik nad rychlostí (slipstream se nezobrazuje). |
| `src/car/tyre_model.gd` | `TyreModel`: stav pneumatik podle ujeté vzdálenosti → `CarState.grip_multiplier` (grip i brzdy); nové pneumatiky v boxech. |
| `src/race/pit_lane.gd`, `src/race/pit_lane_view.gd` | `PitLane`: geometrie boxové uličky (z rovinky kolem cíle, vnitřní strana), garáže, vjezd; vykreslení (garáže, budova boxů, zídka, omezovač, tabule PIT). |
| `src/race/pit_stop.gd`, `src/race/pit_minigame.gd`, `src/ui/pit_popup.gd` | `PitStop`: autopilot uličkou (zpomalení, zastavení v boxu, výjezd), ghost; `PitMinigame`: čím později Mezerník, tím kratší zastávka; popup. |
| `src/car/car_collision.gd` | `CarCollision`: měkký kontakt aut (kapsle), náraz zezadu ubere hlavně narážejícímu, omezené boční postrčení. |
| `src/race/incident_judge.gd` | `IncidentJudge`: posouzení kontaktu (viník, následky po 1 s), +5 s, opakování v kole = 5 s ghost. |
| `src/race/shortcut_check.gd` | `ShortcutCheck`: zkrácení trati (celé auto za obrubníkem a zisk > 25 m) +5 s; traťové limity zrušeny. |
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
