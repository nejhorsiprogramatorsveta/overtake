# Stav projektu Overtake

## Kde jsme skončili
**M2 krok 5 – boxová ulička a pitstop: HOTOVO (Claude, 2026-11-22), lokálně commitnuto. Nic není publikované.**
- Boxová ulička vedle cílové rovinky na vnitřní straně (Rakousko 329 m, 8 garáží, tvůj box v barvě auta, zídka,
  žluté čáry omezovače, značky zastavení, žlutá tabule „PIT“ u vjezdu).
- Vjezd: najeď k pravému okraji trati u tabule PIT → autopilot převezme auto, zabrzdí na 80 km/h a zastaví v boxu.
- Minihra (popup ve spodní části obrazovky): po 0,4 s běží ukazatel 1,4 s; čím později Mezerník, tím kratší zastávka
  (4,5 → 2,0 s), nestihnutí = zmatek 7,5 s. Držení Mezerníku z dřívějška se nepočítá. Nové pneumatiky, autopilot vyveze
  auto na konec uličky a vrátí řízení. Celou dobu je auto ghost (průhledné) a neposuzují se traťové limity.
- Celková ztráta zastávky ~13 s (laditelné v `race_rules.tres`).

## Další krok
**M2 krok 6 – pořadí a výsledky:** obrazovka výsledků po závodě (pořadí, celkový čas, ztráta, penalizace, nejlepší kolo,
reakce na startu, počet zastávek) místo cílového panelu, `src/race/race_ranking.gd` (pořadí podle kola a vzdálenosti, pro
více aut připravené pro M3), HUD pozice „P1/1“. Tím se M2 uzavře; dál M3 boti.

## Hotovo
- [x] Plán schválen (2026-11-22), rozhodnutí uživatele viz níže.
- [x] M0 – kostra projektu (menu, nastavení ovládání, changelog, auto-update, CI, testy, dokumenty).
- [x] M1 – jízda po trati offline (Rakousko, fyzika auta, vektorová grafika, kamera, HUD, minimapa, kola).
- [x] M2 krok 1 – tabule BP, start se světly a spojkou, sólo závod s cílem, trať 24 m.
- [x] M2 krok 2 – KERS (K, 3× za kolo) a slipstream (1,5 s, plynulé odeznění), HUD ukazatel; KERS zkrácen na 1,25 s a zesílen.
- [x] M2 krok 3 – traťové limity (3 varování, pak +5 s; zkratka +5 s), hlášky v HUD, penalizace ve výsledku.
- [x] M2 krok 4 – volitelné opotřebení pneumatik, HUD stav %, posun BP podle gripu.
- [x] M2 krok 5 – boxová ulička, autopilot, pit minihra, nové pneumatiky, ghost.

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

## Stav testů (2026-11-22, po M2 krok 5)
- `tests/run_tests.gd`: 65 testů, 0 chyb (nově: ulička na vnitřní straně rovinky, pozdní stisk ~2 s / brzký pomalý /
  nestihnutí +3 s, držený Mezerník se nepočítá, autopilot: omezovač, ~2 s v boxu, nové pneumatiky, návrat na trať).
  Test překladů zachytil čárku v neuzavřeném textu (opraveno). Lokalizace: 0 chybí.
- Smoke test: automatický řidič odjel kolo, najel do boxů ve 173 km/h, stiskl Mezerník na 92 % → zastávka 2,21 s,
  vyjel 80 km/h s novými pneumatikami zpět na trať. Screenshoty uličky a minihry OK (krátká scéna).
- **Netestováno ručně:** je vjezd do boxů dost jasný a snadný? Nevjede se omylem při jízdě u okraje rovinky?

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
