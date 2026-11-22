# Stav projektu Overtake

## Kde jsme skončili
**Přerušeno uživatelem (2026-11-22) uprostřed kvalifikace. Nic není pushnuté (uživatel: pushnout až řekne).**
- Hotovo a commitnuto: oprava pořadí (dostižená auta za vedoucím kolem, `b9b47f2`), BP boards jen před zatáčkami
  a ne u jiné části trati / u boxů, Austrálie nahrazena Brazílií (boxy vně rovinky, `pit_outside`,
  `pit_straight_radius`), validace (3 revize subagentů: závod/online, tratě/boxy/boti, UI) – všechny nálezy opraveny
  (`420dee3`), nové závodní hlavní menu s animovaným okruhem a auty. Testy 131/131, lokalizace OK.
- Ověřeno: plné závody 12 aut × 4 kola s opotřebením na všech 3 tratích (všichni dojeli, boti v boxech, 0 zkratek),
  online 2 instance (výsledky shodné, lobby, odchod klienta/hostitele).
- **Rozpracováno (necommitnuto):** jen `Settings.qualifying` + typované čtení nastavení jsou v commitu; samotná
  kvalifikace NEZAČATA v kódu (soubor `src/race/race_builder.gd` nevytvořen).
- M6 publikace stále čeká na uživatele (založení repa / gh).

## Další krok
**Kvalifikace pro rozřazení (offline závod i online)** – plán:
1. Zmenšit `race_controller.gd` (341 řádků): přesunout stavbu scény/aut do `src/race/race_builder.gd`
   (scenery, offline_racers, add_racer, for_qualifying, grid_after_qualifying), `_on_lap_completed`/`_on_penalised`
   zveřejnit, `Racer.is_bot_car` + `Racer.reset_for_race()`.
2. `src/race/qualifying.gd`: RaceRules `quali_laps` 2, `quali_time` 180 s, `quali_run_up` 150 m, `quali_result_time` 6 s;
   lidé jezdí sami (ghost, bez kontaktu, KERS volný), boti skrytí s odhadnutým časem = ideální kolo × [1.183, 1.124,
   1.08, 1.054][obtížnost] + 0–0,5 s (seed); pořadí podle nejlepšího kola; konec = všichni lidé 2 měřená kola nebo čas.
3. Online: volba `qualifying` v lobby (LobbyValidator.settings), hostitel rozhodne konec a pošle pořadí (nové RPC
   v RaceNet, kontrola permutace), všichni po 6 s postaví auta na rošt a startují (race_time od 0, `_start_reported` reset).
4. HUD: místo pozice „Kvalifikace m:ss“, živé pořadí s nejlepšími časy; volba v session_setup a lobby; testy.

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
- [x] M3G krok 1 – grafika trati (vyježděná stopa, smyky, kačírek, obrubníky, rošt) a okolí (bariéry, lesy, tribuny, boxy).
- [x] Úpravy: traťové limity zrušeny (zůstala zkratka), ideální stopa K1999, tempo botů jen v zatáčkách.
- [x] M3G krok 2 – monoposty ve stylu formulí 2026 (aktivní aerodynamika vizuálně, natáčení kol, stín, helmy).
- [x] Úprava: barvy aut podle monopostů F1 2026 (11 kombinací hlavní + doplňková, bez jmen týmů a log).
- [x] Úprava: startovní světla zhasínají náhodně 0,2–4 s po pátém světle.
- [x] M5 – tratě Brazílie (nahradila Austrálii) a Čína (boxy, ideální stopa, BP, okolí, kalibrace).
- [x] M4 – online hra (lobby, kód místnosti, barvy, nastavení od hostitele, síťový závod, výsledky, odpojení).
- [x] M3G krok 3 – HUD v herním stylu (barevné časy kol, bliknutí pozice, rychloměr), stopy pneumatik, kouř, prach. **M3G hotové.**

## Čeká nás (milníky z PLAN.md F)
- [x] M3G – Arkádová grafika (vyježděná stopa, detailnější trať, okolí, auta, HUD, efekty)
- [x] M4 – Online (lobby, Tailscale/LAN, síť)
- [x] M5 – Tratě Brazílie a Čína
- [ ] M6 – Publikace na GitHub (až na pokyn)
- [ ] M7 – Polish (zvuk, menší buildy, …), volitelné

## Mimo plán
- Minimapa udělaná už v M1 (plán ji měl v M5). Rychlostní profil (plán M2) hotový v M1 kvůli kalibraci trati.
- M3G krok 1 vyřešil úzké pruhy trávy mezi kačírky a ostré vnitřní bariéry. Zbývá: ve vrcholu nejostřejších vraceček
  drobná špička obrubníku (přeložení vnitřního okraje).
- Nápad: travnaté pruhy jsou vodorovné přes celou mapu (arkádové); případně je natočit podle trati.
- Nápad: renderer Compatibility nemá vyhlazování hran (MSAA/FXAA). Pokud budou hrany vadit, zvážit renderer Mobile.

## Známé problémy
- Online netestováno přes skutečnou Wi-Fi/Tailscale ani s lidmi (jen 2 instance na jednom počítači). Chybí diagnostické
  logy a falešné zpoždění z Gun game – převzít, pokud se při playtestu objeví cukání.
- Online: kontakt aut se počítá na zobrazených (o ~40–100 ms zpožděných) pozicích; při těsném souboji se může lišit.
- Čína: šnek T1–T2 je těsný (poloměr 13,4 m, části trati 28 m od sebe) – vnitřní okraj se kreslí s malým zkrácením.
- Výsledková tabulka a pit popup ještě nemají nový styl HUD (funkční, jen starší vzhled).
- Boti: občas (cca 1 z 2 závodů s 11 auty) kolize při předjíždění – bot se vrací do stopy těsně před pomalejšího.
- První `--import` po čistém klonu vypíše neškodné chyby „Cannot open file translations.cs.translation“ (stejně jako Gun game).
- Testy na Windows odloženy na konec projektu (jako u Gun game).

## Stav testů (2026-11-22, po M3G)
- `tests/run_tests.gd`: 126 testů, 0 chyb (nově: online – kontrola lobby, nastavení, roštu, binární stavy aut a poškozená data, handshake, adresy, časová osa a vyrovnávací paměť; všechny tratě – boxy mimo asfalt, hladká stopa, čistá kola Experta v očekávaném čase, okolí; široký rozptyl zhasnutí světel; drhnutí jen nad gripem, protáčení jen při rozjezdu, stopy slučované a přerušené skokem, kruhová paměť stop, barvy časů kol a rychloměru, rošt; paleta barev aut; helma kontrastní ke každé barvě, klapky otevřené jen na rovince, kola podle řízení; bot brzdí za brzdícím autem, stopa bez zlomů a širší než středová čára, pomalý bot nebrzdí na rovince, vyjetí z trati bez trestu; grafika trati – bitmapa zákazů, kačírek bez mezer, stromy/tribuny mimo trať a boxy, vyježděná stopa, velikost meshů; zamčený KERS a jeho uvolnění; náraz zezadu zpomalí narážejícího a oběť jen postrčí, boční kontakt
  omezený, rozhodčí trestá jen tvrdý náraz s následky, opakování = ghost, Expert předjede Lehkého bez trestu do 90 s).
  Lokalizace: 0 chybí.
- Smoke závod 4 kola, 11 aut (pomalí vpředu, rychlí vzadu), 3 semínka startu: pořadí v cíli podle rychlosti,
  0 / 1 / 1 trest za kolizi, 0 zkratek.
- **Netestováno ručně:** souboje s boty v rukou člověka (je kontakt přirozený? nejsou boti moc opatrní/agresivní?).

## Rozhodnutí
- 2026-11-22: barvy aut podle týmů F1 2026 (hlavní + doplňková); dál žádné názvy týmů, loga, sponzoři ani grafika livrejí.
- 2026-11-22: traťové limity zrušeny (zůstává trest za zkrácení trati); ideální stopa K1999; obtížnost botů = jen rychlost v zatáčkách.
- 2026-11-22: KERS zamčený do průjezdu cílem všech aut po startu (v tréninku po prvním průjezdu cílem).
- 2026-11-22: kamera pevná sever-nahoru; měkký kontakt aut (ghost v boxech a ~3 s po startu); pitstop vždy
  dobrovolný; čistý vektorový styl.
- 2026-11-22: zůstáváme u Godotu; velikost stahování desítky MB je v pořádku, nesmí se blížit 1 GB.
- 2026-11-22: kontakt aut + rozhodčí podle PLAN.md B; auta po dojetí jsou ghost.
- 2026-11-22: pit minihra při vjezdu do uličky; slipstream −12 %, bez efektů; Expert 111 % tempa s větším gripem.
- 2026-11-22: boti – Střední výchozí, hráč startuje zezadu (volitelně); ideální stopa = minimální zakřivení (nahrazeno K1999).
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
