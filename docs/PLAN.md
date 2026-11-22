# Plán projektu: Overtake – 2D závodní hra shora (Godot 4.7.2 + GDScript)

## Kontext
Druhá hra po Gun game (Dojo Knockout). Online závodní arkádovka F1 stylu z horního pohledu (inspirace Formula Racing 2D,
originální vzhled), hraná s kamarády přes Tailscale / stejnou Wi-Fi, s boty, stahovatelná pro Windows/macOS/Linux
z GitHubu. Technologie, buildy, multiplayer, auto-update a pracovní protokoly přebíráme z `/Users/home/Gun_game`
(ten se NEMĚNÍ, jen se z něj kopírují a upravují soubory). Nová hra: `/Users/home/overtake`.

**Rozhodnutí uživatele (2026-11-22):** kamera pevná sever-nahoru · měkký kontakt aut (ghost v boxech a ~3 s po startu)
· pitstop vždy dobrovolný · čistý vektorový styl (vše kreslené kódem, žádné bitmapy aut/trati).

## A. Technologie a infrastruktura (převzato z Gun_game)
- Godot **4.7.2-stable** (non-.NET), GDScript se statickým typováním, Compatibility renderer, fyzika 60 Hz.
- Lokální engine v `.tools/` přes `tools/setup_env.sh` + `tools/godot` (kopie z Gun_game, beze změny logiky).
- Testy `tests/run_tests.gd` + `tests/test_case.gd` (kopie), lokalizace `localization/translations.csv` + `tools/check_localization.gd`.
- Build info / verze: `src/core/build_info.gd`, `tools/write_build_info.gd`, verze jen v `project.godot` (start **0.1.0**).
- Changelog „Co je nového“ + release notes: `src/core/changelog.gd`, `data/changelog.tres`, `tools/write_release_notes.gd`.
- Auto-update: `src/core/updater.gd`, `src/core/update_installer.gd` (URL → nový repozitář).
- CI: `.github/workflows/build.yml` + `tools/publish_release.sh` + `tests/test_release_workflow.py` – stejný tok
  (push main → testy → export 3 platforem → `version.json` se SHA-256 → aktualizace JEDNOHO vydání; soubory hry před manifestem).
  Úpravy: `GAME_NAME=overtake`, `GAME_TITLE=Overtake`, odstranit legacy `v0.1.0`, bootstrap prvního vydání (když ještě není `version.json`).
- Výstupy: `overtake-windows.exe` (PCK uvnitř), `overtake-macos.zip` (universal .app, ad-hoc podpis), `overtake-linux.zip`.
- Licence PolyForm Noncommercial 1.0.0 (jako Gun game), `CREDITS.md`.
- Velikost: standardní šablony Godotu ≈ 70–100 MB/platforma (hra sama < 2 MB, vše vektorově). Volitelně v M7
  vlastní šablony bez 3D → ~30–40 MB.
- Síť a bezpečnost: kopie `src/autoload/session.gd`, `src/net/{session_auth,handshake,lobby_validator,connection_log,diag_log,
  net_stats,lag_simulator,snapshot_timeline,jitter_clock}.gd`, `src/net/connectors/{connector,enet_direct_connector}.gd`,
  `src/core/{diag_file_logger,key_bindings}.gd`, `src/autoload/settings.gd` – odstranit postavy/zbraně/týmy, ponechat:
  kód místnosti, LAN + Tailscale adresy, žádné UPnP, `server_relay=false`, žádné dekódování objektů, validace a limity (PLAN S).
- GitHub: nový repozitář `nejhorsiprogramatorsveta/Overtake` (veřejný). **Nic se nepushuje, dokud uživatel neřekne**
  (první publikace na pokyn; pak každý push jen po „pushni“, stejně jako u Gun game).

## B. Herní design
**Ovládání (přebindovatelné, `KeyBindings`):** W plyn · S brzda · A/D zatáčení · Mezerník spojka (start) / tlačítko
v pit-popupu · K = KERS · Esc menu · F3 síťové statistiky.

**Model auta (`src/car/car_motor.gd`, deterministický krok, sdílený hráčem, botem i predikcí):**
- Rychlost podél směru + boční složka; tah (klesá s rychlostí), odpor vzduchu, brzdná síla.
- **Kruh adheze (friction circle):** brzdění a zatáčení sdílejí stejný grip → plné brzdění + plné zatočení nejde naráz,
  auto podtáčí. Vede to k brzdění rovně u BP a zatáčení až potom (realistický brzdný bod, ne arkádové „brzdi a toč“).
- Grip všude stejný (i mimo ideální stopu). Mimo asfalt (kačírek/tráva): silný odpor, max ~40 % rychlosti, menší grip.
- Max. úhel natočení klesá s rychlostí (stabilita na rovinkách).
- Všechny konstanty v `data/car/car_tuning.tres` (editovatelné, popsané v `docs/EDITING_GUIDE.md`).

**Brzdné body (BP):** nástroj spočítá rychlostní profil trati (průjezdní rychlost z křivosti a gripu, zpětný průchod
s brzdnou deceleraci). Kde začíná brzdění před zatáčkou → bílá tabule „BP“ u kraje trati. Tabule se kreslí lokálně
u každého hráče, takže při opotřebení pneumatik se **posouvá dřív pro konkrétního hráče** (vzdálenost přepočtená
z jeho aktuálního gripu/brzd). Volitelně slabší tabule „100“ před BP – až podle playtestu.

**Start:** rozestavení na roštu → 5 červených světel postupně → náhodná pauza 0,2–3 s → zhasnutí.
Hráč drží W + Mezerník (spojka). Puštění spojky po zhasnutí = start; čím rychlejší reakce, tím lepší rozjezd
(reakce se zobrazí v ms). Bez plynu = pomalý rozjezd. Puštění před zhasnutím = **předčasný start → +5 s** v cíli
(host rozhoduje). Prvních ~3 s ghost mezi auty.

**KERS (K):** 3 použití na kolo, každé ~2,5 s extra tahu (+~12 %), obnova při průjezdu cílem. HUD: 3 políčka.

**Slipstream:** auto do **1,5 s** za autem před sebou (vzdálenost < rychlost_předního × 1,5 s) a v úzkém kuželu za
ním → menší odpor (síla roste s blízkostí). Po vyjetí z kuželu bonus plynule odezní (~0,8 s) → auto „pomalu zpomalí“.
Počítá se lokálně z viditelných pozic aut.

**Tratě:** reálné tvary z `bacinger/f1-circuits` (GeoJSON, MIT licence – do CREDITS, bez ochranných známek F1;
v menu jen „Rakousko“, „Austrálie“, „Čína“). Python nástroj `tools/tracks/build_track.py` (stáhne GeoJSON jednou,
převede lon/lat na metry, vyhladí Catmull-Rom, přeorientuje sever-nahoru, převzorkuje po ~4 m) vygeneruje
`data/tracks/<id>.json`: středová čára, šířka (široká ≈ 5–6 šířek auta), obrubníky, kačírkové zóny na výjezdech
zatáček, start/cíl, rošt, 3 sektory/checkpointy, BP, boxová ulička (paralelně s cílovou rovinkou, vjezd/výjezd
z konfigurace trati). Měřítko trati se ladí, aby referenční kolo bota „Expert“ odpovídalo cíli:
herní čas ≈ 45 s + (reálný − 65 s) × 15/35 → **Rakousko ~45 s, Austrálie ~51 s, Čína ~57 s**.

**Kreslení (`src/track/track_view.gd`, `src/car/car_view.gd`):** tráva, kačírek, asfalt (Polygon2D z offsetů
středové čáry), červeno-bílé obrubníky, bílé okraje, startovní rošt a šachovnice, boxy s garážemi v barvách hráčů,
BP tabule s textem. Auta = vektorová monoposti (originální tvar, barva hráče, brzdová světla, efekt KERS, stopy
smyku). Kamera sever-nahoru, plynulé sledování + mírný odzoom podle rychlosti, minimapa v rohu.

**Pneumatiky a pitstop:**
- V lobby přepínač **Opotřebení pneumatik** (zap/vyp). Zapnuto: grip a brzdy klesají lineárně s ujetou vzdáleností
  (cca −12 % po ~6 kolech, strmější pod 30 %); HUD ukazuje stav %, BP hráče se posouvá.
- Pitstop **dobrovolný**. Vjezd do boxové uličky → autopilot (omezovač rychlosti) dojede ke garáži → popup:
  ukazatel běží 0→100 % (~1,6 s); **čím později zmáčkneš Mezerník (ale před koncem), tím rychlejší zastávka**
  (2,0 s nejlépe … 4,5 s), nestihneš = zmatek +3 s. Pak nové pneumatiky, autopilot k výjezdu, ovládání vrácené
  na konci uličky. Během celé boxové uličky ghost (průhledné auto), žádné kolize.

**Závod:** počet kol volí host (výchozí 5), pořadí podle (kolo, vzdálenost na trati), časy kol a nejrychlejší kolo,
cíl → výsledky (pořadí, celkový čas, penalizace, nejlepší kolo, reakce na startu) → zpět do lobby.
Mimo plán MVP (případně později): kvalifikace, počasí, poškození, šampionát.

**Boti (`src/ai/bot_driver.gd`):** jedou po ideální stopě (vyhlazená středová čára posunutá k vnitřku zatáček),
brzdí podle rychlostního profilu, předjíždějí posunem stopy, když je auto před nimi pomalejší, používají KERS
na rovinkách, reakce na startu. Obtížnost (Lehká / Střední / Těžká / Expert) = násobek cílové rychlosti v zatáčkách,
přesnost brzdění, reakce na startu, občasné chyby. Simuluje je host.

## C. Multiplayer (cíl: minimální odezva a žádné záseky u ostatních)
- **Hostovaný ENet listen server, max 8 lidí, celkem až 12 aut s boty.** Lobby: trať, kola, opotřebení, počet a
  obtížnost botů, barva auta. Spojení stejně jako Gun game (LAN adresa / Tailscale `100.x` + `#kód`).
- **Vlastní auto simuluje jeho majitel** (nulové zpoždění ovládání, žádné přehrávání/rubber-banding, které u Gun game
  způsobovalo cukání). Klient posílá stav auta 60 Hz (`unreliable_ordered`, ~24 B: seq, pozice, směr, rychlost,
  příznaky KERS/brzda/mimo trať/pit, opotřebení). **Host validuje** (velikost, rozsah, max. rychlost a teleporty,
  pořadí checkpointů) a je autoritou pro: světla a start, předčasný start, počítání kol a cíl, KERS kredity, pořadí,
  pitstop časy, boty, výsledky.
- Host rozesílá jeden snapshot všech aut 60 Hz (~12 × 20 B). Cizí auta: `SnapshotTimeline` s adaptivním zpožděním
  + krátká extrapolace podle rychlosti (závodní pohyb je plynulý, extrapolace funguje dobře).
- **Měkký kontakt:** každý klient řeší kolizi jen pro své auto proti zobrazeným (extrapolovaným) pozicím ostatních →
  obě strany se odtlačí symetricky; host totéž pro boty. Kolize kruh/ovál, omezený impulz, bez poškození.
- Slipstream i BP se počítají lokálně → žádný síťový provoz navíc.
- Diagnostika: `user://logs/last_game.log` + `[net]` souhrny po 5 s (kopie z Gun game), `--fake-lag/--fake-loss`.

## D. Struktura projektu (`/Users/home/overtake`)
```
project.godot, export_presets.cfg, LICENSE, README.md, CREDITS.md, CLAUDE.md, AGENTS.md, codex.md
docs/{PLAN,PROGRESS,ARCHITECTURE,EDITING_GUIDE,PLAYTEST}.md
src/autoload/{session,settings}.gd
src/core/      build_info, changelog, content_db, key_bindings, updater, update_installer, diag_file_logger
src/car/       car_motor, car_input, car_state, car_view, car_collision, slipstream, kers, tyre_model
src/track/     track_data (load JSON), track_view, track_query (projekce na čáru, mimo trať, sektor), bp_markers, minimap
src/race/      race_controller, start_lights, lap_tracker, race_ranking, pit_lane, pit_stop_minigame, race_rules
src/ai/        bot_driver, racing_line
src/net/       session_auth, handshake, lobby_validator, car_codec, race_net (jediné místo pro RPC zápasu), …
src/net/connectors/{connector,enet_direct_connector}.gd
src/ui/        main_menu, lobby, settings_screen, race_hud, pit_popup, results, theme
data/          car/car_tuning.tres, tracks/*.json + track_info .tres, changelog.tres
tools/         setup_env.sh, godot, write_build_info.gd, write_release_notes.gd, check_localization.gd,
               publish_release.sh, tracks/build_track.py (+ zdrojové GeoJSON v tools/tracks/src/)
tests/         run_tests.gd, test_case.gd, test_*.gd, test_release_workflow.py
.github/workflows/build.yml
```
Pravidla jako u Gun game: skripty < ~300 řádků, jedna odpovědnost, RPC jen v session/src/net/race_net, texty jen
přes `tr()`, `res://`/`user://` pouze, žádné nové autoloady/addony bez schválení, commit `*.gd.uid`.

## E. Projektová paměť a dokumenty (vytvoří se v M0)
- `CLAUDE.md` – podle Gun game: start session (PROGRESS + git + publikovaná verze z GitHubu), resume protokol,
  end-of-task protokol (PROGRESS → lokální commit → push jen po „pushni“ → kontrola CI → český přehled → stop),
  příkazy, architektura, pravidla, bezpečnost.
- `AGENTS.md` – odkaz pro Codex na `codex.md` + `CLAUDE.md`.
- `codex.md` – kopie pravidel Gun game upravená pro Overtake: Codex **nikdy nepushuje** ani neupravuje vydání,
  GitHub `version.json` je zdroj pravdy, každý push herních souborů = přesně další verze, archivace changelogu,
  testy + loc check před předáním, návrh commit zprávy a věta „Po pushnutí vyjde nová verze X.Y.Z“ / „Jen dokumentace“.
- `docs/PROGRESS.md` – sekce: Kde jsme skončili · Další krok · Hotovo · Čeká nás (milníky) · **Mimo plán**
  (věci navíc / nápady) · Známé problémy · Stav testů · Rozhodnutí.
- `docs/PLAN.md` – tento plán (česky, rozšířený o detaily).

## F. Milníky (každý krok končí testy, PROGRESS, lokálním commitem a přehledem; pak stop)
- **M0 – Kostra projektu:** složka, `git init`, převzaté nástroje/CI/testy/lokalizace/build info, `project.godot`
  (Overtake 0.1.0), export presety, dokumenty z E, prázdné menu. Ověřit `setup_env`, import, testy, lokální export.
- **M1 – Jízda po trati (offline):** `build_track.py` + Rakousko, `track_data/track_query/track_view`, `car_motor`
  s kruhem adheze, mimo trať, kamera, HUD (rychlost, kolo, časy), checkpointy/kola. Trénink v menu.
- **M2 – Závodní mechaniky:** rychlostní profil + BP tabule, start se světly a spojkou (+ předčasný start),
  KERS, slipstream, opotřebení + dynamické BP, boxová ulička + pit minihra + ghost, pořadí, cíl, výsledky.
- **M3 – Boti:** ideální stopa, brzdění, předjíždění, obtížnosti; offline závod hráč vs. boti; ladění měřítka tratě
  na cílové časy kola.
- **M4 – Online:** lobby (nastavení závodu), `car_codec`, `race_net`, stav vlastního auta → host → snapshoty,
  interpolace/extrapolace, měkký kontakt, host-autoritativní pravidla, odpojení, logy. Test 2 instance na 127.0.0.1,
  pak LAN/Tailscale playtest.
- **M5 – Austrálie a Čína:** import, boxové uličky, BP, kalibrace časů kola, minimapa.
- **M6 – Publikace:** README (stažení, macOS/Windows postup, Tailscale návod), `version.json` + updater na nový repo,
  `gh repo create`, první vydání **až na pokyn uživatele**.
- **M7 – Polish (volitelné):** procedurální zvuk motoru, nastavení zvuku, menší exportní šablony, kvalifikace, gamepad.

## G. Ověření
- Unit testy (`tools/godot --headless --path . -s tests/run_tests.gd`): car_motor (brzdná dráha, kruh adheze,
  mimo trať), track_query, lap_tracker/checkpointy, slipstream (1,5 s okno, odeznění), KERS (3×/kolo), start
  (reakce, předčasný start), pit minihra (časování), tyre_model + posun BP, car_codec (limity, poškozená data),
  lobby_validator, bot dojede kolo bez vyjetí; `test_release_workflow.py`.
- Loc check, lokální exporty všech 3 presetů (velikost souborů zapsat do PROGRESS).
- Smoke testy přes throwaway SceneTree skripty (simulace kláves, screenshoty bez `--headless`), měření času kola
  bota Expert vs. cíl (45/51/57 s ±3 s).
- Síť: 2–3 instance lokálně s `--fake-lag=100 --fake-loss=5`, pak skutečný playtest LAN + Tailscale (logy).
- Windows testy na konci projektu (jako u Gun game), uvedené v PROGRESS.

## S. Bezpečnost online hry (převzato z Gun game, platí pro každou síťovou změnu)
Cíl: přes hru se nikdo nesmí jednoduše dostat do počítače hráče ani do jeho domácí sítě.
- Připojení přes internet = **Tailscale** (sdílení jednoho zařízení přes *Share*), jinak stejná Wi-Fi/LAN.
- Hra **neotevírá porty v routeru (žádné UPnP)** a **nikde nezobrazuje veřejnou IP** (jen LAN a Tailscale `100.x` adresy).
- `SceneMultiplayer.allow_object_decoding = false`, `server_relay = false`. Handshake přes `auth_callback` s limitem velikosti.
- Ze sítě se nikdy nespouští kód ani nenačítají soubory/cesty.
- Host validuje vše od klienta: identita z `get_remote_sender_id()`, typy, rozsahy, velikosti zpráv, rate-limit;
  u stavu auta navíc max. rychlost, skoky pozice a pořadí checkpointů. Neplatné zprávy se zahodí.
- Kód místnosti (6 znaků, kryptograficky bezpečný generátor) je součástí adresy `adresa:port#KÓD`.
- Hra nikdy nepotřebuje práva správce, ukládá jen do `user://`. Buildy jen z GitHub Actions.

## I. Publikace a vydání (převzato z Gun game)
- Jediné GitHub vydání s pevným tagem **`release`** (repo `nejhorsiprogramatorsveta/Overtake`). CI ho po každém pushi
  herních souborů na `main` aktualizuje: nahraje `overtake-windows.exe`, `overtake-macos.zip`, `overtake-linux.zip`,
  POTOM `version.json` (verze, build, SHA-256), přejmenuje vydání na `Overtake vX.Y.Z` a označí jako latest.
- Verze je jen `application/config/version` v `project.godot`. Každý push herních souborů = přesně další
  patch/minor/major (CI jinak odmítne). Build = počet commitů na main (určí CI). Dokumentace (`docs/**`, `*.md`) nic nevydává.
- První publikace (až na pokyn uživatele): `gh repo create`, ruční `gh release create release` (jednou), pak push.
  `tools/publish_release.sh` pozná první vydání podle chybějícího `version.json`.
- Auto-update ve hře čte `https://github.com/nejhorsiprogramatorsveta/Overtake/releases/latest/download/version.json`.
- Changelog „Co je nového“: `data/changelog.tres` (záznam `build = 0` = aktuální nevydaná verze) + `CHANGELOG_*` klíče v CSV.

## Zdroje
- Formula Racing 2D (reference žánru): https://www.mobygames.com/game/109848/formula-racing-2d/
- Tvary tratí: https://github.com/bacinger/f1-circuits (MIT)
- Gun game (zdroj infrastruktury): `/Users/home/Gun_game` – needitovat.
