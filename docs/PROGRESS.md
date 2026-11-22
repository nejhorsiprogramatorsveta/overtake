# Stav projektu Overtake

## Kde jsme skončili
**M2 krok 1 – brzdné body a start: HOTOVO (Claude, 2026-11-22), lokálně commitnuto. Nic není publikované.**
- Uživatel: „ovládání je cajk, trať o trochu širší, monoposty arkádově jako letošní (potom), pokračuj“.
- Trať Rakousko **24 m** široká (předtím 20 m); nejostřejší zatáčky otevřeny na poloměr ≥ 17 m (vnitřní okraj se
  nepřekládá), vracečka ~93 km/h, ideální kolo po středové čáře 50,1 s. Vzhled monopostů podle formulí 2026 zapsán do M3G.
- **Tabule BP:** z rychlostního profilu (`BrakingPoints`) – bílá tabule „BP“ na vnější straně zatáčky + bílý blok na
  okraji asfaltu, kde začíná brzdění; na Rakousku 6–12 zón. Připraveno pro posun při opotřebení (profil s menším gripem).
- **Start (`RaceStart`):** rošt 2 s → 5 červených světel po 1 s → náhodná pauza 0,2–3 s → zhasnutí. Drž W + Mezerník,
  po zhasnutí pusť Mezerník: zobrazí se reakce. Puštění během světel = předčasný start +5 s (auto stojí do zhasnutí),
  nedržená spojka = pomalý start (+0,6 s). Nápověda s klávesami podle nastavení.
- **Menu „Závod“:** sólo závod z roštu na 5 kol (`RaceRules.laps`), kolo 1 se měří od zhasnutí světel, cílový panel
  s celkovým časem, penalizací a nejlepším kolem. „Trénink“ zůstává s letmým startem.

## Další krok
**M2 krok 2 – KERS a slipstream:** K = KERS (3× za kolo, ~2,5 s, +12 % výkonu přes `CarState.power_multiplier`, HUD
3 políčka, obnova v cíli) a slipstream (`src/car/slipstream.gd`: do 1,5 s za autem v kuželu menší odpor, plynulé
odeznění ~0,8 s) s testy. Slipstream se ověří testem a s botem/duchem až v M3 (v sólo závodu není auto před tebou).

## Hotovo
- [x] Plán schválen (2026-11-22), rozhodnutí uživatele viz níže.
- [x] M0 – kostra projektu (menu, nastavení ovládání, changelog, auto-update, CI, testy, dokumenty).
- [x] M1 – jízda po trati offline (Rakousko, fyzika auta, vektorová grafika, kamera, HUD, minimapa, kola).
- [x] M2 krok 1 – tabule BP, start se světly a spojkou, sólo závod s cílem, trať 24 m.

## Čeká nás (milníky z PLAN.md F)
- [ ] M2 – Závodní mechaniky (BP, start se spojkou, KERS, slipstream, pneumatiky, pitstop, traťové limity, výsledky)
- [ ] M3 – Boti s obtížnostmi + kontakt aut a ochrana proti úmyslným kolizím
- [ ] M3G – Arkádová grafika (vyježděná stopa, detailnější trať, okolí, auta, HUD, efekty)
- [ ] M4 – Online (lobby, Tailscale/LAN, síť)
- [ ] M5 – Tratě Austrálie a Čína (zdrojová data už stažená v `tools/tracks/src/`)
- [ ] M6 – Publikace na GitHub (až na pokyn)
- [ ] M7 – Polish (zvuk, menší buildy, …), volitelné

## Mimo plán
- Minimapa udělaná už v M1 (plán ji měl v M5). Rychlostní profil (plán M2) hotový v M1 kvůli kalibraci trati.
- Do M3G: vnitřní bariéry u vraceček končí ostře, mezi kačírkovými zónami jsou úzké pruhy trávy, ve vrcholu vracečky drobné zelené špičky (přeložení obrubníku).
- Nápad: renderer Compatibility nemá vyhlazování hran (MSAA/FXAA). Pokud budou hrany vadit, zvážit renderer Mobile.

## Známé problémy
- První `--import` po čistém klonu vypíše neškodné chyby „Cannot open file translations.cs.translation“ (stejně jako Gun game).
- Testy na Windows odloženy na konec projektu (jako u Gun game).

## Stav testů (2026-11-22, po M2 krok 1)
- `tests/run_tests.gd`: 48 testů, 0 chyb (nově start: světla, reakce, předčasný/pomalý start, stejný seed; BP zóny a
  jejich posun při menším gripu; kolo 1 od zhasnutí). Lokalizace: 0 chybí. `test_release_workflow.py` beze změny.
- Smoke test závodu (automatický řidič drží W + Mezerník, pustí 0,2 s po zhasnutí): reakce 0,222 s, 1 kolo z roštu 53,0 s,
  bez penalizace; screenshoty světel, tabule BP a cílového panelu OK.
- **Netestováno ručně:** start a BP v rukou člověka (je tabule BP vidět včas? sedí místo brzdění?). Windows/Linux, auto-update.

## Rozhodnutí
- 2026-11-22: kamera pevná sever-nahoru; měkký kontakt aut (ghost v boxech a ~3 s po startu); pitstop vždy
  dobrovolný; čistý vektorový styl.
- 2026-11-22: zůstáváme u Godotu; velikost stahování desítky MB je v pořádku, nesmí se blížit 1 GB.
- 2026-11-22: trať 24 m; monoposty podle formulí 2026 (M3G); předčasný start = auto stojí do zhasnutí + 5 s, nedržená spojka = +0,6 s.
- 2026-11-22: řízení – zmírněný kruh adheze (0,5) a víc gripu v nízké rychlosti; vyježděná stopa (M3) a arkádová grafika (M3G) v plánu.
- 2026-11-22: trať Rakousko měřítko 0.62 (cíl ~45 s po ideální stopě), šířka 20 m.
- 2026-11-22: do plánu přidány traťové limity (M2) a úmyslné kolize (M3, online posuzuje host v M4), PLAN.md B.
- 2026-11-22: projekt se vyvíjí ve složce `/Users/home/overtake`; Gun game se nemění.
- Vlastní auto simuluje jeho majitel, host validuje a rozhoduje pravidla závodu (PLAN.md C).
- GitHub: repo `nejhorsiprogramatorsveta/Overtake`, jedno vydání s tagem `release`; push jen na pokyn.
