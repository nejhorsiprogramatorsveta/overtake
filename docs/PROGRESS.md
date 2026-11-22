# Stav projektu Overtake

## Kde jsme skončili
**M2 krok 3 – traťové limity: HOTOVO (Claude, 2026-11-22), lokálně commitnuto. Nic není publikované.**
- Před tím úprava KERS podle uživatele („zkrať dobu, oddělej boost za autem, může být silnější, na polovinu“):
  1,25 s (z 2,5 s), +4 m/s² (z +2,5), modrá záře za autem odstraněna (commit `00d36bb`).
- **Traťové limity (`TrackLimits`):** obrubník je trať; porušení = celé auto za obrubníkem; jeden výjezd = jedno porušení.
  Závod: hláška „Traťové limity 1/3“ až „3/3“, od 4. porušení „penalizace +5 s“; zkrácení trati (zisk > 25 m po trati
  oproti ujeté dráze, např. přes vnitřek zatáčky) = +5 s ihned. Výjezd ven ze zatáčky není zkratka.
  Penalizace se zobrazuje pod časy a přičítá k výsledku (spolu s předčasným startem). Trénink: jen informační hláška.

## Další krok
**M2 krok 4 – opotřebení pneumatik + posun BP:** volba „Opotřebení pneumatik“ (zatím v menu u závodu, v M4 v lobby),
`src/car/tyre_model.gd`: grip a brzdy klesají s ujetou vzdáleností (~−12 % po ~6 kolech, strmější pod 30 %), HUD stav %,
tabule BP vlastního hráče se posouvají dřív podle aktuálního gripu (přepočet profilu po krocích, ne každý tick); testy.
Potom krok 5: boxová ulička, pit minihra, ghost v boxech.

## Hotovo
- [x] Plán schválen (2026-11-22), rozhodnutí uživatele viz níže.
- [x] M0 – kostra projektu (menu, nastavení ovládání, changelog, auto-update, CI, testy, dokumenty).
- [x] M1 – jízda po trati offline (Rakousko, fyzika auta, vektorová grafika, kamera, HUD, minimapa, kola).
- [x] M2 krok 1 – tabule BP, start se světly a spojkou, sólo závod s cílem, trať 24 m.
- [x] M2 krok 2 – KERS (K, 3× za kolo) a slipstream (1,5 s, plynulé odeznění), HUD ukazatel; KERS zkrácen na 1,25 s a zesílen.
- [x] M2 krok 3 – traťové limity (3 varování, pak +5 s; zkratka +5 s), hlášky v HUD, penalizace ve výsledku.

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

## Stav testů (2026-11-22, po M2 krok 3)
- `tests/run_tests.gd`: 58 testů, 0 chyb (nově: obrubník je trať, celé auto venku, 3 varování → 2× +5 s, zkratka přes
  vnitřek nejostřejší zatáčky, výjezd ven není zkratka; KERS 1,25 s / +4). Lokalizace: 0 chybí.
- Smoke test závodu se schválným výjezdem: hláška „Traťové limity 1/3“ (screenshot), 1 porušení, bez trestu, čas 53,0 s.
- **Netestováno ručně:** traťové limity v rukou člověka (nejsou příliš přísné/mírné?), pocit z kratšího KERS.

## Rozhodnutí
- 2026-11-22: kamera pevná sever-nahoru; měkký kontakt aut (ghost v boxech a ~3 s po startu); pitstop vždy
  dobrovolný; čistý vektorový styl.
- 2026-11-22: zůstáváme u Godotu; velikost stahování desítky MB je v pořádku, nesmí se blížit 1 GB.
- 2026-11-22: KERS 1,25 s a +4 m/s², bez efektu za autem. Traťové limity v tréninku jen informativně.
- 2026-11-22: trať 24 m; monoposty podle formulí 2026 (M3G); předčasný start = auto stojí do zhasnutí + 5 s, nedržená spojka = +0,6 s.
- 2026-11-22: řízení – zmírněný kruh adheze (0,5) a víc gripu v nízké rychlosti; vyježděná stopa (M3) a arkádová grafika (M3G) v plánu.
- 2026-11-22: trať Rakousko měřítko 0.62 (cíl ~45 s po ideální stopě), šířka 20 m.
- 2026-11-22: do plánu přidány traťové limity (M2) a úmyslné kolize (M3, online posuzuje host v M4), PLAN.md B.
- 2026-11-22: projekt se vyvíjí ve složce `/Users/home/overtake`; Gun game se nemění.
- Vlastní auto simuluje jeho majitel, host validuje a rozhoduje pravidla závodu (PLAN.md C).
- GitHub: repo `nejhorsiprogramatorsveta/Overtake`, jedno vydání s tagem `release`; push jen na pokyn.
