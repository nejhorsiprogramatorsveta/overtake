# Stav projektu Overtake

## Kde jsme skončili
**M2 – Závodní mechaniky: HOTOVO (krok 6 pořadí a výsledky, Claude, 2026-11-22), lokálně commitnuto. Nic není publikované.**
- Kód přestavěn na jezdce (`Racer`: auto, kola, limity, start, pitstop, výsledek) → řadič závodu umí víc aut (pro M3 boty).
- Pořadí (`RaceRanking`): dojetí podle celkového času s penalizacemi, ostatní podle ujeté vzdálenosti; HUD „P1/1“.
- Výsledky po dojetí (2 s po cíli): pozice, jezdec, čas vítěze / ztráta, penalizace, nejlepší kolo, reakce na startu
  (nebo „předčasný start“), počet zastávek; tlačítka **Znovu** a **Menu**. Po dojetí vítěze ostatní končí na konci kola.
- Po cíli auto hráče dojíždí bez plynu. Jméno z menu (prázdné = „Hráč“).

## Další krok
**M3 krok 1 – ideální stopa a bot:** `src/ai/racing_line.gd` (vyhlazená ideální stopa využívající šířku trati: vnější →
vrchol uvnitř → vnější, rychlostní profil po ní), `src/ai/bot_driver.gd` (sledování stopy, brzdění podle profilu, KERS na
rovinkách, start s reakcí) a obtížnosti; boti jako `Racer` v závodě (rošt za hráčem) a počet botů + obtížnost v menu.
Kalibrace měřítka tratě na ~45 s po ideální stopě. Pak krok 2: kontakt aut + ochrana proti úmyslným kolizím, předjíždění.

## Hotovo
- [x] Plán schválen (2026-11-22), rozhodnutí uživatele viz níže.
- [x] M0 – kostra projektu (menu, nastavení ovládání, changelog, auto-update, CI, testy, dokumenty).
- [x] M1 – jízda po trati offline (Rakousko, fyzika auta, vektorová grafika, kamera, HUD, minimapa, kola).
- [x] M2 krok 1 – tabule BP, start se světly a spojkou, sólo závod s cílem, trať 24 m.
- [x] M2 krok 2 – KERS (K, 3× za kolo) a slipstream (1,5 s, plynulé odeznění), HUD ukazatel; KERS zkrácen na 1,25 s a zesílen.
- [x] M2 krok 3 – traťové limity (3 varování, pak +5 s; zkratka +5 s), hlášky v HUD, penalizace ve výsledku.
- [x] M2 krok 4 – volitelné opotřebení pneumatik, HUD stav %, posun BP podle gripu.
- [x] M2 krok 5 – boxová ulička, autopilot, pit minihra, nové pneumatiky, ghost.
- [x] M2 krok 6 – jezdci (Racer), pořadí, HUD pozice, výsledky se Znovu/Menu. **M2 hotové.**

## Čeká nás (milníky z PLAN.md F)
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

## Stav testů (2026-11-22, po M2)
- `tests/run_tests.gd`: 68 testů, 0 chyb (nově pořadí: kola/vzdálenost, dojetí podle času s penalizací, rošt před čarou).
  Lokalizace: 0 chybí.
- Smoke test závodu (1 kolo): dojetí P1, 53,0 s, reakce 0,219 s, výsledky se zobrazí; screenshot tabulky výsledků OK.
- **Netestováno ručně:** celý závod v rukou člověka (start → boxy → cíl → výsledky → Znovu).

## Rozhodnutí
- 2026-11-22: kamera pevná sever-nahoru; měkký kontakt aut (ghost v boxech a ~3 s po startu); pitstop vždy
  dobrovolný; čistý vektorový styl.
- 2026-11-22: zůstáváme u Godotu; velikost stahování desítky MB je v pořádku, nesmí se blížit 1 GB.
- 2026-11-22: pitstop – vjezd najetím k okraji u tabule PIT, zastávka 2–4,5 s, nestihnutí 7,5 s, ztráta ~13 s.
- 2026-11-22: opotřebení pneumatik −12 % na 30 % (~4 kola), pak až −30 %; volba v menu pro trénink i závod.
- 2026-11-22: KERS 1,25 s a +4 m/s², bez efektu za autem. Traťové limity v tréninku jen informativně.
- 2026-11-22: trať 24 m; monoposty podle formulí 2026 (M3G); předčasný start = auto stojí do zhasnutí + 5 s, nedržená spojka = +0,6 s.
- 2026-11-22: řízení – zmírněný kruh adheze (0,5) a víc gripu v nízké rychlosti; vyježděná stopa (M3) a arkádová grafika (M3G) v plánu.
- 2026-11-22: trať Rakousko měřítko 0.62 (cíl ~45 s po ideální stopě), šířka 20 m.
- 2026-11-22: do plánu přidány traťové limity (M2) a úmyslné kolize (M3, online posuzuje host v M4), PLAN.md B.
- 2026-11-22: projekt se vyvíjí ve složce `/Users/home/overtake`; Gun game se nemění.
- Vlastní auto simuluje jeho majitel, host validuje a rozhoduje pravidla závodu (PLAN.md C).
- GitHub: repo `nejhorsiprogramatorsveta/Overtake`, jedno vydání s tagem `release`; push jen na pokyn.
