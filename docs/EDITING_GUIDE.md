# Jak upravit herní data (bez programování)

Po každé úpravě spusť testy: `tools/godot --headless --path . -s tests/run_tests.gd`.

## Auto – `data/car/car_tuning.tres`
Textový soubor, čísla jde měnit v libovolném editoru (nebo v Godot editoru po dvojkliku). Jednotky: metry, sekundy.
Rychlost v m/s × 3,6 = km/h.

| Hodnota | Co dělá | Nyní |
|---|---|---|
| `power` | výkon motoru; s `drag` určuje maximální rychlost (power / drag)^(1/3) | 1090 (≈ 317 km/h) |
| `traction` | nejvyšší zrychlení při rozjezdu (m/s²) | 13 |
| `drag` | odpor vzduchu; víc = nižší maximálka | 0.0016 |
| `engine_brake` | zpomalení bez plynu i brzdy (m/s²) | 2.5 |
| `brake_decel` | síla brzd (m/s²); víc = kratší brzdná dráha | 30 |
| `grip` | přilnavost pneumatik (m/s²) – rychlost v zatáčkách a limit brzd | 37 |
| `combined_grip` | kolik brzdění ubírá zatáčení: 1 = hodně (brzdi jen rovně), 0 = vůbec | 0.5 |
| `low_speed_grip_bonus`, `low_speed_grip_speed` | čím pomaleji, tím víc auto zatočí: +35 % přilnavosti v zatáčce na místě, mizí do 45 m/s (162 km/h) | 0.35, 45 |
| `runoff_grip` | násobek přilnavosti mimo trať | 0.6 |
| `runoff_drag`, `runoff_drag_max` | jak moc kačírek brzdí | 0.85, 22 |
| `wheelbase`, `max_steer_angle`, `steer_falloff_speed` | ostrost zatáčení (při rychlosti se zmenšuje) | 3.6, 0.5, 20 |
| `steer_speed` | jak rychle se natočí kola po stisku A/D | 6 |
| `reverse_accel`, `reverse_speed` | couvání (drž S na místě) | 6, 10 |
| `kers_uses`, `kers_duration`, `kers_accel` | KERS: použití za kolo, délka dávky (s), zrychlení navíc (m/s²) | 3, 1.25, 4 |
| `slip_time` | jak daleko za autem ještě funguje slipstream (s) | 1.5 |
| `slip_drag_reduction` | o kolik méně odporu vzduchu v závěsu (podíl) | 0.12 |
| `slip_half_width`, `slip_widening` | šířka „kuželu“ za autem (m) a jeho rozšiřování na metr | 3.2, 0.04 |
| `slip_rise`, `slip_decay` | jak rychle závěs naběhne a jak pomalu odezní po vyjetí (za s) | 3, 1.25 |
| `slip_min_speed` | pod touto rychlostí (m/s) slipstream nefunguje | 20 |
| `tyre_life` | při zapnutém opotřebení: metry z nových (100 %) na sjeté (0 %) pneumatiky | 15000 |
| `tyre_loss_at_cliff`, `tyre_cliff`, `tyre_loss_dead` | ztráta gripu a brzd: −12 % při 30 % stavu, pak strměji až −30 % na 0 % | 0.12, 0.3, 0.3 |
| `length`, `width` | rozměry auta (m) | 5.2, 1.9 |

## Tratě – `tools/tracks/tracks.json`
Tratě se generují ze skutečných tvarů okruhů: `python3 -I tools/tracks/build_track.py` (přepíše `data/tracks/*.json`).
- `scale` – zmenšení skutečné trati; menší = kratší kolo (cíl: Rakousko ~45 s, Austrálie ~51 s, Čína ~57 s).
- `width` – šířka asfaltu v metrech (24 m, široká kvůli předjíždění).
- `reverse` – obrátí směr jízdy, `start_shift` – posune start/cíl o metry podél trati.
- `pit_entry`, `pit_exit` – kde boxová ulička opouští a znovu napojuje trať (podíl kola od startu 0–1, jako na skutečném okruhu).
Náhled: `python3 -I tools/tracks/build_track.py austria --preview /cesta/ke/slozce` uloží obrázek trati.

## Pravidla závodu – `data/race/race_rules.tres`
| Hodnota | Co dělá | Nyní |
|---|---|---|
| `laps` | počet kol závodu | 5 |
| `grid_time`, `light_interval` | čekání na roštu, pak každou sekundu další červené světlo | 2, 1 |
| `hold_min`, `hold_max` | náhodná pauza se všemi světly, než zhasnou (s) | 0.2, 3 |
| `jump_start_penalty` | trest za předčasné puštění spojky (s) | 5 |
| `no_clutch_delay` | o kolik později vyrazí auto, když spojku při zhasnutí nedrží (s) | 0.6 |
| `track_limit_warnings`, `track_limit_penalty` | traťové limity: kolik varování, pak trest za každé další porušení (s) | 3, 5 |
| `shortcut_min_gain`, `shortcut_penalty` | zkrácení trati: zisk mimo trať nad tolik metrů = trest (s) | 25, 5 |
| `pit_offset`, `pit_blend` | boxová ulička: vzdálenost od okraje trati, délka nájezdu/výjezdu (m) | 15, 70 |
| `pit_speed`, `pit_decel`, `pit_accel` | omezovač v boxech (m/s, 22,2 = 80 km/h), brzdění a rozjezd autopilota | 22.2, 30, 8 |
| `pit_first_box`, `pit_box_spacing` | garáže: první od začátku uličky, rozestup (m) | 50, 16 |
| `pit_prepare`, `pit_bar_time` | minihra: čekání po zastavení, doba běhu ukazatele (s) | 0.4, 1.4 |
| `pit_best`, `pit_worst`, `pit_fumble` | zastávka při stisku na konci / na začátku ukazatele, trest za nestihnutí (s) | 2, 4.5, 3 |
| `pit_green_from`, `pit_good` | kde začíná zelená zóna ukazatele (0–1) a zastávka na jejím začátku (s) | 0.85, 2.6 |
| `grid_first`, `grid_spacing`, `grid_lateral` | rošt: první místo za čarou, rozestup, posun do stran (m) | 10, 8, 4.5 |
| `bp_min_speed_drop` | tabule BP jen u zatáček, kde se zpomalí aspoň o tolik m/s | 8 |

## Boti – `src/ai/bot_driver.gd` (konstanta `SKILLS`)
Pro každou obtížnost: `pace` (podíl ideální rychlosti v zatáčkách; nad 1 dostane bot úměrně víc gripu), `wobble` (kolísání stopy v m), `reaction` (reakce
na startu v s), `pit_press` (kde na ukazateli v boxech zmáčkne Mezerník, 0–1). Ideální stopu přepočítá
`python3 -I tools/tracks/build_track.py` (je uložená v `data/tracks/*.json`).
