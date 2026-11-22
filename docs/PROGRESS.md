# Stav projektu Overtake

## Kde jsme skončili
**M2 krok 4 – opotřebení pneumatik + posun BP: HOTOVO (Claude, 2026-11-22), lokálně commitnuto. Nic není publikované.**
- Přepínač **Opotřebení pneumatik** v menu (platí pro trénink i závod, ukládá se; online ho v M4 zvolí host v lobby).
- `TyreModel`: stav klesá s ujetou vzdáleností (15 km ze 100 % na 0 %); grip i brzdy −12 % při 30 % (~4 kola Rakouska),
  pod 30 % strměji až −30 %. HUD řádek „Pneumatiky xx %“ (zelená → žlutá → červená).
- Tabule BP hráče se posouvají dřív podle gripu (přepočet profilu po 1 %): s 85 % gripem o 8–12 m dřív, kolo
  automatického řidiče 53,2 s místo 50,7 s.

## Další krok
**M2 krok 5 – boxová ulička a pitstop:** boxová ulička paralelně s cílovou rovinkou (vjezd/výjezd v datech trati,
kreslení, garáže), vjezd → autopilot s omezovačem rychlosti ke garáži → popup minihra (ukazatel 0→100 % za ~1,6 s,
čím později Mezerník, tím rychlejší zastávka 2,0–4,5 s, nestihneš = +3 s) → nové pneumatiky → autopilot k výjezdu,
ghost v celé uličce; testy. Pitstop je dobrovolný.

## Hotovo
- [x] Plán schválen (2026-11-22), rozhodnutí uživatele viz níže.
- [x] M0 – kostra projektu (menu, nastavení ovládání, changelog, auto-update, CI, testy, dokumenty).
- [x] M1 – jízda po trati offline (Rakousko, fyzika auta, vektorová grafika, kamera, HUD, minimapa, kola).
- [x] M2 krok 1 – tabule BP, start se světly a spojkou, sólo závod s cílem, trať 24 m.
- [x] M2 krok 2 – KERS (K, 3× za kolo) a slipstream (1,5 s, plynulé odeznění), HUD ukazatel; KERS zkrácen na 1,25 s a zesílen.
- [x] M2 krok 3 – traťové limity (3 varování, pak +5 s; zkratka +5 s), hlášky v HUD, penalizace ve výsledku.
- [x] M2 krok 4 – volitelné opotřebení pneumatik, HUD stav %, posun BP podle gripu.

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

## Stav testů (2026-11-22, po M2 krok 4)
- `tests/run_tests.gd`: 61 testů, 0 chyb (nově: opotřebení jen se zapnutou volbou, nové pneumatiky, pomalá/strmá ztráta,
  útes po 3–6 kolech, delší brzdná dráha s ojetými pneumatikami). Lokalizace: 0 chybí.
- Smoke test s ojetými pneumatikami (25 %): BP o 8–12 m dřív, za kolo 25 → 7 %, kolo 53,2 s, HUD „Pneumatiky 24 %“
  (screenshot), přepínač v menu (screenshot).
- **Netestováno ručně:** jak rychle opotřebení přichází v rukou člověka (rychlost lze ladit `tyre_life`).

## Rozhodnutí
- 2026-11-22: kamera pevná sever-nahoru; měkký kontakt aut (ghost v boxech a ~3 s po startu); pitstop vždy
  dobrovolný; čistý vektorový styl.
- 2026-11-22: zůstáváme u Godotu; velikost stahování desítky MB je v pořádku, nesmí se blížit 1 GB.
- 2026-11-22: opotřebení pneumatik −12 % na 30 % (~4 kola), pak až −30 %; volba v menu pro trénink i závod.
- 2026-11-22: KERS 1,25 s a +4 m/s², bez efektu za autem. Traťové limity v tréninku jen informativně.
- 2026-11-22: trať 24 m; monoposty podle formulí 2026 (M3G); předčasný start = auto stojí do zhasnutí + 5 s, nedržená spojka = +0,6 s.
- 2026-11-22: řízení – zmírněný kruh adheze (0,5) a víc gripu v nízké rychlosti; vyježděná stopa (M3) a arkádová grafika (M3G) v plánu.
- 2026-11-22: trať Rakousko měřítko 0.62 (cíl ~45 s po ideální stopě), šířka 20 m.
- 2026-11-22: do plánu přidány traťové limity (M2) a úmyslné kolize (M3, online posuzuje host v M4), PLAN.md B.
- 2026-11-22: projekt se vyvíjí ve složce `/Users/home/overtake`; Gun game se nemění.
- Vlastní auto simuluje jeho majitel, host validuje a rozhoduje pravidla závodu (PLAN.md C).
- GitHub: repo `nejhorsiprogramatorsveta/Overtake`, jedno vydání s tagem `release`; push jen na pokyn.
