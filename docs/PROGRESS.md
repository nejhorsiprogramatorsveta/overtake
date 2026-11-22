# Stav projektu Overtake

## Kde jsme skončili
**M1 – Jízda po trati offline: HOTOVO (Claude, 2026-11-22), lokálně commitnuto. GitHub repozitář zatím neexistuje,
nic není publikované.**
- Trať **Rakousko** ze skutečného tvaru (bacinger/f1-circuits, MIT): `tools/tracks/build_track.py` → `data/tracks/austria.json`
  (měřítko 0.62, šířka 20 m, délka 2655 m, po směru hodinových ručiček jako ve skutečnosti).
- Fyzika auta `CarMotor` (výkon/rychlost, odpor vzduchu, **kruh adheze** – plné brzdění v zatáčce = podtáčení,
  kačírek zpomalí, bariéra na okraji únikové zóny, couvání), laditelná v `data/car/car_tuning.tres`.
- Vektorová trať (tráva, kačírek v zatáčkách, asfalt, obrubníky, čáry, start/cíl), vektorové auto, kamera sever-nahoru
  s pohledem dopředu a oddálením podle rychlosti, HUD (kolo, čas, poslední/nejlepší, rychlost, **minimapa** – přesunuto z M5).
- Počítání kol se sektory (nejde zkrátit ani couvnout přes cíl), čas průjezdu cílem interpolovaný v ticku.
- Menu: tlačítko **Trénink** + výběr trati. Rychlostní profil trati (`SpeedProfile`, základ BP a botů) hotový už teď.
- Čas kola: ideální jízda po středové čáře 51,5 s, automatický řidič (smoke test) 51,3–52,4 s. Po ideální stopě
  bude kolem 46 s → finální kalibrace na 45 s v M3 s boty.

## Další krok
**M2 krok 1 – brzdné body a start:** z `SpeedProfile` najít brzdné zóny a nakreslit bílé tabule „BP“ (`src/track/bp_markers.gd`),
pak start se světly a spojkou (`src/race/start_lights.gd`: 5 světel, náhodná pauza, W + Mezerník, předčasný start +5 s) s testy.

## Hotovo
- [x] Plán schválen (2026-11-22), rozhodnutí uživatele viz níže.
- [x] M0 – kostra projektu (menu, nastavení ovládání, changelog, auto-update, CI, testy, dokumenty).
- [x] M1 – jízda po trati offline (Rakousko, fyzika auta, vektorová grafika, kamera, HUD, minimapa, kola).

## Čeká nás (milníky z PLAN.md F)
- [ ] M2 – Závodní mechaniky (BP, start se spojkou, KERS, slipstream, pneumatiky, pitstop, traťové limity, výsledky)
- [ ] M3 – Boti s obtížnostmi + kontakt aut a ochrana proti úmyslným kolizím
- [ ] M4 – Online (lobby, Tailscale/LAN, síť)
- [ ] M5 – Tratě Austrálie a Čína (zdrojová data už stažená v `tools/tracks/src/`)
- [ ] M6 – Publikace na GitHub (až na pokyn)
- [ ] M7 – Polish (zvuk, menší buildy, …), volitelné

## Mimo plán
- Minimapa udělaná už v M1 (plán ji měl v M5). Rychlostní profil (plán M2) hotový v M1 kvůli kalibraci trati.
- Nápad: dvě vnitřní bariéry u vracečky Remus končí ostře, vizuální doladění trati v M7.
- Nápad: renderer Compatibility nemá vyhlazování hran (MSAA/FXAA). Pokud budou hrany vadit, zvážit renderer Mobile.

## Známé problémy
- První `--import` po čistém klonu vypíše neškodné chyby „Cannot open file translations.cs.translation“ (stejně jako Gun game).
- Testy na Windows odloženy na konec projektu (jako u Gun game).

## Stav testů (2026-11-22, po M1)
- `tests/run_tests.gd`: 41 testů, 0 chyb (fyzika auta, trať, rychlostní profil, kola, ovládání, changelog, updater).
  Kontrola lokalizace: 0 chybí. `test_release_workflow.py`: 9 OK (beze změny).
- Smoke test (automatický řidič přes simulované klávesy, okno se screenshoty): 2 platná kola za 51,3 s, zůstal na trati.
- Export macOS OK, data trati jsou v balíčku. M0 velikosti: Windows 109 MB, macOS 60 MB, Linux 28 MB (ZIP).
- **Netestováno ručně:** jízda na klávesnici člověkem (pocit z řízení, brzdění, velikost auta na obrazovce) – prosím vyzkoušet
  `tools/godot --path .` → Trénink. Windows/Linux spuštění, auto-update.

## Rozhodnutí
- 2026-11-22: kamera pevná sever-nahoru; měkký kontakt aut (ghost v boxech a ~3 s po startu); pitstop vždy
  dobrovolný; čistý vektorový styl.
- 2026-11-22: zůstáváme u Godotu; velikost stahování desítky MB je v pořádku, nesmí se blížit 1 GB.
- 2026-11-22: trať Rakousko měřítko 0.62 (cíl ~45 s po ideální stopě), šířka 20 m.
- 2026-11-22: do plánu přidány traťové limity (M2) a úmyslné kolize (M3, online posuzuje host v M4), PLAN.md B.
- 2026-11-22: projekt se vyvíjí ve složce `/Users/home/overtake`; Gun game se nemění.
- Vlastní auto simuluje jeho majitel, host validuje a rozhoduje pravidla závodu (PLAN.md C).
- GitHub: repo `nejhorsiprogramatorsveta/Overtake`, jedno vydání s tagem `release`; push jen na pokyn.
