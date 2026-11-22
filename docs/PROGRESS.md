# Stav projektu Overtake

## Kde jsme skončili
**Úprava KERS (Claude, 2026-11-22): KERS je po startu zamčený a zapne se všem najednou, až všechna auta projedou
cílovou čárou (nejpozději když první auto dokončí kolo, aby auto stojící na roštu nic neblokovalo). HUD ukazuje
zamčená políčka jen obrysem, při uvolnění hláška „KERS uvolněn“. Smoke závod 11 aut: uvolnění 4,1 s po zhasnutí.**

**M3 krok 2 – kontakt aut, předjíždění, ochrana proti úmyslným kolizím: HOTOVO (Claude, 2026-11-22), lokálně
commitnuto. Nic není publikované. Tím je M3 (boti) hotové.**
- Předtím úpravy podle uživatele (commit `aa73104`): pit minihra hned při vjezdu do uličky, živé pořadí s odstupy vlevo,
  rychlejší Těžká/Expert (Expert 43,2 s), slipstream −12 % a širší, bez efektů a bez řádku v HUD.
- **Kontakt aut:** auta se opřou a odtlačí, náraz zezadu ubere rychlost hlavně narážejícímu, boční postrčení omezené.
- **Rozhodčí:** tvrdší kontakt (nad 5 m/s), po kterém oběť do 1 s ztratí čtvrtinu rychlosti nebo vyjede = +5 s viníkovi;
  druhý trest v jednom kole = 5 s průhledný. Hláška „Kolize: jméno +5 s“. Penalizace jsou ve výsledcích.
- **Průhledná auta (ghost):** v boxech, 3 s po startu, při opakovaném narážení, po dojetí do cíle.
- **Boti v provozu:** vždy ubrzdí auto ve své stopě, pomalejší předjedou tam, kde je víc místa, vedle auta drží odstup.
  Závod s mixem obtížností (rychlí zezadu): Expert ze 6. místa vyhrál, pořadí podle rychlosti, 0 trestů.

## Další krok
**M3G – arkádová grafika** (PLAN.md B „Arkádový vzhled“ a F): vyježděná stopa po ideální stopě, detailnější asfalt,
obrubníky, kačírek, bariéry z pneumatik, tribuny/stromy/boxy, stíny, monoposty ve stylu formulí 2026 (bez livrejí),
výraznější HUD. Ověřit screenshoty krátkými scénami. Potom M4 online.

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
- [x] Úpravy: pit minihra hned při vjezdu, živé pořadí s odstupy, rychlejší boti, slabší a širší slipstream bez efektů.
- [x] M3 krok 2 – kontakt aut, rozhodčí kolizí, ghost, předjíždění botů. **M3 hotové.**
- [x] Úprava: KERS se zapne, až všechna auta po startu projedou cílovou čárou.

## Čeká nás (milníky z PLAN.md F)
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

## Stav testů (2026-11-22, po M3)
- `tests/run_tests.gd`: 82 testů, 0 chyb (nově: zamčený KERS a jeho uvolnění; náraz zezadu zpomalí narážejícího a oběť jen postrčí, boční kontakt
  omezený, rozhodčí trestá jen tvrdý náraz s následky, opakování = ghost, Expert předjede Lehkého bez trestu do 90 s).
  Lokalizace: 0 chybí.
- Smoke závod 4 kola, 6 aut (pomalí vpředu, rychlí vzadu): rychlí předjeli, pořadí v cíli podle rychlosti, 0 trestů,
  0 traťových limitů. (Před opravou: 4 tresty – náraz do dojíždějícího auta po cíli a pozdní brzdění za pomalejším botem.)
- **Netestováno ručně:** souboje s boty v rukou člověka (je kontakt přirozený? nejsou boti moc opatrní/agresivní?).

## Rozhodnutí
- 2026-11-22: KERS zamčený do průjezdu cílem všech aut po startu (v tréninku po prvním průjezdu cílem).
- 2026-11-22: kamera pevná sever-nahoru; měkký kontakt aut (ghost v boxech a ~3 s po startu); pitstop vždy
  dobrovolný; čistý vektorový styl.
- 2026-11-22: zůstáváme u Godotu; velikost stahování desítky MB je v pořádku, nesmí se blížit 1 GB.
- 2026-11-22: kontakt aut + rozhodčí podle PLAN.md B; auta po dojetí jsou ghost.
- 2026-11-22: pit minihra při vjezdu do uličky; slipstream −12 %, bez efektů; Expert 111 % tempa s větším gripem.
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
