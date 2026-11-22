# Stav projektu Overtake

## Kde jsme skončili
**M2 krok 2 – KERS a slipstream: HOTOVO (Claude, 2026-11-22), lokálně commitnuto. Nic není publikované.**
- **KERS (K):** 3 použití za kolo, jedno stisknutí = jedno použití (držení klávesy nespotřebuje další), 2,5 s přídavné
  zrychlení +2,5 m/s² jen při plynu, obnova při každém průjezdu cílem. Modrá záře za autem. (Auto má trakcí omezené
  zrychlení skoro do maximálky, proto KERS není „+12 % výkonu“, které by skoro nic nedělalo; maximálka s KERS ~+9 %.)
- **Slipstream:** do 1,5 s za autem v úzkém kuželu za ním až o 30 % menší odpor vzduchu (čím blíž, tím víc); po vyjetí
  z kuželu efekt plynule odeznívá ~0,8 s → auto „pomalu zpomalí“. Počítá každé auto samo (v online hře bez provozu navíc).
  Bílé proudnice kolem auta. **V sólo závodu se zatím neuplatní** (není auto před tebou) – ověřeno testy, naostro v M3 s boty.
- HUD: panel „KERS“ (3 políčka + modrý pruh běžící dávky) a „Slipstream“ (pruh) nad rychlostí.
- Opraven únik paměti při odchodu z tréninku (nepoužitý ukazatel startovních světel).

## Další krok
**M2 krok 3 – traťové limity:** `src/race/track_limits.gd` + pravidla v `RaceRules` (PLAN.md B „Traťové limity“):
porušení = celé auto za bílou čárou (obrubník je trať), varování 1–3 v HUD, od 4. porušení +5 s, zkratka (zisk > ~25 m
mimo trať) okamžitě +5 s; penalizace sečíst do výsledku závodu; testy.

## Hotovo
- [x] Plán schválen (2026-11-22), rozhodnutí uživatele viz níže.
- [x] M0 – kostra projektu (menu, nastavení ovládání, changelog, auto-update, CI, testy, dokumenty).
- [x] M1 – jízda po trati offline (Rakousko, fyzika auta, vektorová grafika, kamera, HUD, minimapa, kola).
- [x] M2 krok 1 – tabule BP, start se světly a spojkou, sólo závod s cílem, trať 24 m.
- [x] M2 krok 2 – KERS (K, 3× za kolo) a slipstream (1,5 s, plynulé odeznění), HUD ukazatel.

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

## Stav testů (2026-11-22, po M2 krok 2)
- `tests/run_tests.gd`: 53 testů, 0 chyb (nově KERS: 3 použití, držení klávesy, doplnění, jen s plynem, vyšší maximálka;
  slipstream: okno 1,5 s, kužel, auto vpředu nic, nízká rychlost nic, postupné odeznění, rychlejší auto v závěsu).
  Lokalizace: 0 chybí.
- Smoke test: automatický řidič stiskl K na rovince → 2 použití zbývají, boost aktivní, platné kolo 50,7 s.
  Screenshot HUD ukazatele OK. Odchod z tréninku i závodu bez úniků paměti.
- **Netestováno ručně:** pocit z KERS; slipstream naostro (až s boty v M3).

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
