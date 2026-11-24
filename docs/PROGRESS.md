# Stav projektu Overtake

## Kde jsme skončili
**2026-11-24: hotové všechny body zprávy uživatele z 2026-11-23. Nic není pushnuté (uživatel: pushnout až řekne).**
- FPS: statické meshe trati rozdělené na dlaždice 160 m (Godot kreslí jen viditelné, 25–75 tis. trojúhelníků místo
  ~290 tis.), profily botů předpočítané při startu, minimapa a kouř šetrnější (`0552e13`). Čína: 210–270 FPS bez vsync.
- F3 (na Macu fn+F3) ukazuje FPS, časy snímku, draw cally, trojúhelníky a online ping (`StatsOverlay`).
- BP: změřené posuny tabulí (bot brzdí co nejpozději a ještě zatočí) v `bp_offsets` tratí – Čína o 15–35 m později
  (`4499a3e`). Dynamické BP při opotřebení: ano, každý hráč má tabule podle svého gripu (krok 1 %), ověřeno
  (při stavu pneumatik 10 % se tabule v Číně posunou o 8–24 m dřív).
- Livreje: `CarLivery` – 11 schémat s barevnými zónami a mírně odlišným tvarem podle F1 2025/2026 (`f83b0b8`).
- **2026-11-24 (11): PUBLIKOVÁNO v0.1.1, build 45** (push `5f116f5`, CI prošlo): Jak hrát, logy, AVUS, BP.
  Před dalším pushem herních souborů: changelog 0.1.1 archivovat pod build 45 a zvýšit verzi na 0.1.2.
- **2026-11-24 (10):** trať **AVUS** (Německo) – v bacinger/f1-circuits není, vlastní kresba
  `tools/tracks/make_avus.py` (uspořádání 1951–67, rovinky oddělené 156 m kvůli 24m trati), 4226 m, Expert ~54 s,
  2 brzdné zóny (Nordkurve +16 m, vlásenka +11 m, měřeno s rychlým nájezdem a reakcí), boxy u západní rovinky.
  Smoke 12 aut × 3 kola: všichni dojeli, 1 kolize, 0 zkratek/boxů, slipstream 34 % času. FPS jako jinde (207–253).
- **2026-11-24 (9):** logy – `DiagFileLogger` + `DiagLog` +
  `ConnectionLog` z Gun game, nově `RaceLog` (každých 5 s FPS, pauzy fyziky, ENet RTT/ztráty, mezery ve snímcích,
  odmítnuté skoky, zpoždění interpolace; okamžitý řádek při výpadku > 250 ms); `user://logs/last_game.log` = poslední
  hra (online od hostování/připojení, offline závod). Nastavení: „Otevřít složku s logy“ + vysvětlení. Hlavní menu:
  „Jak hrát“ (`help_screen.gd`, `help_shot.gd`): 4 karty s výřezy Rakouska (sdílený World2D) – ovládání, BP,
  KERS, boxy. Changelog: 0.1.0 archivováno pod build 42, verze zvýšena na 0.1.1.
- **2026-11-24 (8): PUBLIKOVÁNO.** Push `063fb98`, CI prošlo; vydání `release` = Overtake v0.1.0, build 42
  (Windows .exe 110 MB, macOS .zip 61 MB, Linux .zip 29 MB, version.json se SHA-256). Další push herních souborů
  = další verze (zvýšit `application/config/version`).
- **2026-11-24 (6):** uživatel pushnul na GitHub; CI padalo v kroku „Update existing release“ – skript
  (z Gun game) vydání `release` nikdy nezakládal a na GitHubu žádné nebylo. Teď ho při první publikaci založí
  jako koncept na aktuálním commitu a na konci zveřejní (test s mockem gh).
- **2026-11-24 (7):** BP poslední zatáčky Vegas byla při 320 km/h hodně pozdě. `tools/bp_offsets.gd` teď měří
  s rychlejším nájezdem (až +5 % u nejrychlejších rovinek: slipstream/KERS) a s rezervou 0,15 s reakce; tabule
  smí stát i před čistým profilem. Vegas poslední zatáčka +15 → −4 m (o 19 m dřív); ostatní tabule o 0–15 m dřív
  (Čína dál později než čistý profil: +6 až +25 m).
- **2026-11-24 (5):** Vegas: místo kruhových reflektorů a kuželů lamp je celá trať a pruh vedle ní osvětlený
  rovnoměrně (mimo trať plynule slábne); lampy zůstaly jako sloupy.
- **2026-11-24 (4):** pruh pod rychloměrem = RPM monitor (`EngineRevs`: virtuální 8stupňová převodovka, řazení
  na omezovači, F1 řadicí světla zelená/červená/modrá, číslo stupně vlevo); na roštu volné vytáčení.
- **2026-11-24 (3):** Vegas mnohem víc osvětlený (světlejší noc, lampy po 18 m na obou stranách i v zatáčkách,
  reflektory nad každou zatáčkou, víc neonů). Na roštu pruh rychloměru ukazuje otáčky: s plynem na maximu
  (poslední segment bliká jako omezovač) při 0 km/h, po startu zase rychlost.
- **2026-11-24 (2):** boti v Las Vegas zajížděli do boxů (vjezd ležel na vrcholu zatáčky, kudy vede ideální
  stopa) – vjezd přesunut za vrchol, test pro všechny tratě. Chytřejší boti (`BotTactics`): na rovince se zavěsí
  do slipstreamu, před brzdnou zónou vyjedou na vnitřek zatáčky. Las Vegas = noční městský okruh (`CityScenery`).
- **2026-11-24:** názvy týmů u výběru auta (skutečné, rozhodnutí uživatele) a nová trať **Las Vegas** (3764 m,
  Expert ~57 s, start uprostřed rovinky Harmon, boxy vedle ní, změřené posuny BP).
- **Kvalifikace** (offline závod i online): volba v nastavení závodu a v lobby; výjezd + 2 měřená kola, lidé sami
  (ghost), boti s odhadnutým časem; po konci 6 s výsledek a závod s roštem podle nejlepších kol.
- M6 publikace: hotovo 2026-11-24 (v0.1.0, build 42).

## Další krok
**Playtest uživatelem** (0.1.1: AVUS, Jak hrát, logy po hře přes Tailscale – pošli last_game.log), pak **playtest kvalifikace a závodu** (offline i online) – podle připomínek doladit délku kvalifikace
(teď výjezd + 2 kola, max. 4 min) a zobrazení. Před dalším pushem herních souborů archivovat changelog pod build 45 a zvýšit verzi (0.1.2).

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
- [x] Úpravy 2026-11-23: FPS (dlaždice meshů), F3 statistiky, změřené posuny BP, livreje podle F1 2025/2026.
- [x] Názvy týmů u výběru auta a v lobby; trať Las Vegas.
- [x] Víc světla ve Vegas, otáčky motoru v pruhu rychloměru na roštu; pruh jako RPM monitor se stupněm.
- [x] Oprava boxů ve Vegas, boti se slipstreamem a vyjetím před zatáčkou, Las Vegas jako noční městský okruh.
- [x] Kvalifikace pro rozřazení (offline i online): `Qualifying`, `RaceBuilder`, `RaceInfo`, rošt přes `RaceNet`.

## Čeká nás (milníky z PLAN.md F)
- [x] M3G – Arkádová grafika (vyježděná stopa, detailnější trať, okolí, auta, HUD, efekty)
- [x] M4 – Online (lobby, Tailscale/LAN, síť)
- [x] M5 – Tratě Brazílie a Čína
- [x] M6 – Publikace na GitHub (2026-11-24: v0.1.0, build 42)
- [ ] M7 – Polish (zvuk, menší buildy, …), volitelné

## Mimo plán
- Kvalifikace (plán ji měl až v M7 jako volitelnou) – na přání uživatele 2026-11-22/23.
- `tools/bp_offsets.gd` – nástroj, který fyzikou změří, o kolik později jde u každé BP brzdit.
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
- Městský okruh: zdi a lampy chybí tam, kde by se křížily s únikovou zónou jiné zatáčky (jako u bariér); fyzika je stejná jako na okruhu (žádné zdi, mimo trať jen pomalejší povrch).
- Výsledková tabulka a pit popup ještě nemají nový styl HUD (funkční, jen starší vzhled).
- Boti: občas (cca 1 z 2 závodů s 11 auty) kolize při předjíždění – bot se vrací do stopy těsně před pomalejšího.
- První `--import` po čistém klonu vypíše neškodné chyby „Cannot open file translations.cs.translation“ (stejně jako Gun game).
- Testy na Windows odloženy na konec projektu (jako u Gun game).

## Stav testů (2026-11-24, po kvalifikaci)
- `tests/run_tests.gd`: 142 testů, 0 chyb (nově: RPM monitor – omezovač na roštu, 8 stupňů s řazením nahoru i dolů, barvy řadicích světel; ideální stopa daleko od vjezdu do boxů a Expert nezajede do boxů
  na žádné trati, bot se na rovince zavěsí za auto a před zatáčkou vyjede na vnitřek, městská scenérie Vegas
  se Sphere na skutečném místě). Smoke závody 12 aut × 3 kola (Vegas, Rakousko): všichni dojeli, 0 kolizí, 0 zkratek,
  0 vjezdů do boxů, auta ve slipstreamu ~29 % času. Vegas 200–255 FPS s 12 auty (vsync vyp., oblast startu). (Las Vegas prošel testy všech tratí: boxy, stopa, čisté kolo Experta, BP; nově: kvalifikace – pořadí podle nejlepšího platného kola, zkratka a třetí
  kolo se nepočítají, konec po dojetí všech / po čase, časy botů postupně a stejné na všech počítačích, výsledek
  započítá i druhé kolo bota, offline rošt podle výsledku, kontrola online pořadí a volby v nastavení; odhad času bota
  do 1 % od skutečně ujetého kola; posuny BP v Číně a dřívější BP s opotřebenými pneumatikami; každá livrej jiná).
  Lokalizace: 0 chybí.
- Smoke offline (Čína, 3 boti): kvalifikace → výsledek → závod s roštem podle výsledku, start se světly.
- Smoke online (2 instance, Rakousko, 2 boti): obě instance stejné časy a stejný rošt, po 6 s závod s tímto roštem,
  světla na obou.
- **Netestováno:** kvalifikace ručně (vzhled HUD/pořadí během jízdy), online přes Wi-Fi/Tailscale, odpojení hráče
  během kvalifikace (ošetřeno v kódu: v závodě je odstoupený), FPS na počítači uživatele.

## Rozhodnutí
- 2026-11-24: u výběru auta skutečné názvy týmů F1 (uživatel vědomě, i přes riziko ochranných známek ve veřejné hře); dál bez log a sponzorů.
- 2026-11-23: livreje (rozvržení barev a mírně odlišný tvar) podle monopostů F1 2025/2026; dál žádné názvy týmů, loga ani sponzoři.
- 2026-11-23: kvalifikace volitelná před offline i online závodem; boti v ní nejezdí, dostanou odhadnutý čas.
- 2026-11-22: barvy aut podle týmů F1 2026 (hlavní + doplňková) – rozšířeno 2026-11-23 o livreje.
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
