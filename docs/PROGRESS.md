# Stav projektu Overtake

## Kde jsme skončili
**M3 krok 1 – ideální stopa a boti: HOTOVO (Claude, 2026-11-22), lokálně commitnuto. Nic není publikované.**
- Před tím úpravy podle uživatele: obrazovka nastavení po kliknutí na Trénink/Závod (trať, barva auta s náhledem,
  opotřebení, počet kol), grip 34 → 37, boxy jako na skutečném Red Bull Ringu (vjezd mezi T9 a T10, výjezd vnitřkem T1),
  v minihře zelená jen na konci ukazatele (commity `0a98fa3`, `0b16cdc`).
- **Ideální stopa** (minimální zakřivení: vnější okraj – vrchol – vnější okraj) v datech trati; BP z ní. Ideální kolo 45,4 s.
- **Boti** (`BotDriver`): jezdí po stopě, brzdí podle profilu, start s reakcí, KERS z pomalých zatáček, při opotřebení
  boxy pod 30 %, minihra; obtížnosti Lehká/Střední/Těžká/Expert: 51,2 / 48,5 / 46,5 / 45,1 s, bez vyjetí.
- Nastavení závodu: počet botů 0–11 (výchozí 5), obtížnost (výchozí Střední), startovní pozice (zezadu/náhodně/pole).
- **Zatím chybí kontakt aut** – boti i hráč projíždějí skrz sebe a nepředjíždějí se aktivně (další krok).
- Nový test kompiluje všechny skripty (zachytil chybu v botovi, kterou ostatní testy neviděly).

## Další krok
**M3 krok 2 – kontakt aut, předjíždění a ochrana proti úmyslným kolizím** (PLAN.md B „Úmyslné kolize“):
`src/car/car_collision.gd` (měkký kontakt, náraz zezadu ubere hlavně narážejícímu, omezený boční impulz, ghost v boxech a
~3 s po startu), `src/race/incident_judge.gd` (+5 s viníkovi, opakování = 5 s ghost), boti: pomalejší auto před sebou →
přejet na jinou stopu a předjet / brzdit, nenarážet; testy.

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
- [x] Úpravy: obrazovka nastavení relace, grip 37, boxy podle Red Bull Ringu, zelená na konci minihry.
- [x] M3 krok 1 – ideální stopa, boti se 4 obtížnostmi, nastavení botů a startovní pozice.

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

## Stav testů (2026-11-22, po M3 krok 1)
- `tests/run_tests.gd`: 75 testů, 0 chyb (nově: boti jedou čistá kola, Expert rychlejší než Lehká a blízko 45 s,
  reakce na startu bez předčasného startu, boti jdou do boxů pro nové pneumatiky; ulička mimo asfalt kromě napojení;
  zelená jen na konci; všechny skripty se zkompilují). Lokalizace: 0 chybí.
- Smoke test závodu s 5 boty + autem hráče řízeným botem (2 kola): všichni dojeli, všichni použili KERS, výsledky
  seřazené; screenshoty roštu a startu OK.
- **Netestováno ručně:** závod proti botům v rukou člověka; obrazovka nastavení s novými volbami (screenshot jen před
  přidáním botů).

## Rozhodnutí
- 2026-11-22: kamera pevná sever-nahoru; měkký kontakt aut (ghost v boxech a ~3 s po startu); pitstop vždy
  dobrovolný; čistý vektorový styl.
- 2026-11-22: zůstáváme u Godotu; velikost stahování desítky MB je v pořádku, nesmí se blížit 1 GB.
- 2026-11-22: boti – Střední výchozí, hráč startuje zezadu (volitelně); ideální stopa = minimální zakřivení.
- 2026-11-22: boxy jako na Red Bull Ringu (vjezd T9–T10, výjezd vnitřkem T1); grip 37; nastavení relace na vlastní obrazovce.
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
