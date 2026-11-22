# Stav projektu Overtake

## Kde jsme skončili
**M0 – Kostra projektu: HOTOVO (Claude, 2026-11-22), lokálně commitnuto. GitHub repozitář zatím neexistuje,
nic není publikované** (první publikace až na pokyn uživatele, M6).
- Projekt ve složce `/Users/home/overtake`, verze `0.1.0`, Godot 4.7.2 v `.tools/` (zkopírován z Gun game).
- Převzato z Gun game a upraveno: nástroje (`tools/`), CI (`build.yml` + `publish_release.sh` s tagem `release`
  a podporou prvního vydání), testy, build info, changelog, auto-update (URL repozitáře Overtake), ovládání,
  nastavení, lokalizace. Vektorové UI téma a pozadí menu.
- Dokumenty: `CLAUDE.md`, `AGENTS.md`, `codex.md`, `docs/PLAN.md`, `docs/ARCHITECTURE.md`, `README.md`, `CREDITS.md`.

## Další krok
**M1 krok 1 – převod tratě Rakousko:** napsat `tools/tracks/build_track.py` (stáhnout GeoJSON z bacinger/f1-circuits
do `tools/tracks/src/`, převod lon/lat → metry, vyhlazení, převzorkování, šířka, start/cíl, sektory, boxová ulička)
a vygenerovat `data/tracks/austria.json`; pak `src/track/track_data.gd` + `track_query.gd` s testy.

## Hotovo
- [x] Plán schválen (2026-11-22), rozhodnutí uživatele viz níže.
- [x] M0 – kostra projektu (menu, nastavení ovládání, changelog, auto-update, CI, testy, dokumenty).

## Čeká nás (milníky z PLAN.md F)
- [ ] M1 – Jízda po trati offline (Rakousko, model auta, kamera, HUD, kola)
- [ ] M2 – Závodní mechaniky (BP, start se spojkou, KERS, slipstream, pneumatiky, pitstop, traťové limity, výsledky)
- [ ] M3 – Boti s obtížnostmi + kontakt aut a ochrana proti úmyslným kolizím
- [ ] M4 – Online (lobby, Tailscale/LAN, síť)
- [ ] M5 – Tratě Austrálie a Čína
- [ ] M6 – Publikace na GitHub (až na pokyn)
- [ ] M7 – Polish (zvuk, menší buildy, …), volitelné

## Mimo plán
- (zatím nic)

## Známé problémy
- První `--import` po čistém klonu vypíše neškodné chyby „Cannot open file translations.cs.translation“ (stejně jako Gun game).
- Testy na Windows odloženy na konec projektu (jako u Gun game).

## Stav testů (2026-11-22)
- `tests/run_tests.gd`: 25 testů, 0 chyb. Kontrola lokalizace: 64 klíčů, 0 chybí.
- `test_release_workflow.py`: 9 testů OK.
- Lokální export všech 3 platforem OK: Windows `overtake.exe` 109 MB, macOS `overtake.zip` 60 MB,
  Linux binárka 74 MB (ZIP 28 MB). Exportovaná macOS aplikace naběhne (headless). Menu a Nastavení ověřeny screenshotem.
- Netestováno: auto-update (bez GitHub vydání nejde), Windows a Linux spuštění.

## Rozhodnutí
- 2026-11-22: kamera pevná sever-nahoru; měkký kontakt aut (ghost v boxech a ~3 s po startu); pitstop vždy
  dobrovolný; čistý vektorový styl.
- 2026-11-22: zůstáváme u Godotu; velikost stahování desítky MB je v pořádku, nesmí se blížit 1 GB.
- 2026-11-22: do plánu přidány traťové limity (M2) a úmyslné kolize (M3, online posuzuje host v M4), PLAN.md B.
- 2026-11-22: projekt se vyvíjí ve složce `/Users/home/overtake`; Gun game se nemění.
- Vlastní auto simuluje jeho majitel, host validuje a rozhoduje pravidla závodu (PLAN.md C).
- GitHub: repo `nejhorsiprogramatorsveta/Overtake`, jedno vydání s tagem `release`; push jen na pokyn.
