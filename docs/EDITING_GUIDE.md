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
| `grip` | přilnavost pneumatik (m/s²) – rychlost v zatáčkách a limit brzd | 34 |
| `combined_grip` | kolik brzdění ubírá zatáčení: 1 = hodně (brzdi jen rovně), 0 = vůbec | 0.5 |
| `low_speed_grip_bonus`, `low_speed_grip_speed` | čím pomaleji, tím víc auto zatočí: +35 % přilnavosti v zatáčce na místě, mizí do 45 m/s (162 km/h) | 0.35, 45 |
| `runoff_grip` | násobek přilnavosti mimo trať | 0.6 |
| `runoff_drag`, `runoff_drag_max` | jak moc kačírek brzdí | 0.85, 22 |
| `wheelbase`, `max_steer_angle`, `steer_falloff_speed` | ostrost zatáčení (při rychlosti se zmenšuje) | 3.6, 0.5, 20 |
| `steer_speed` | jak rychle se natočí kola po stisku A/D | 6 |
| `reverse_accel`, `reverse_speed` | couvání (drž S na místě) | 6, 10 |
| `length`, `width` | rozměry auta (m) | 5.2, 1.9 |

## Tratě – `tools/tracks/tracks.json`
Tratě se generují ze skutečných tvarů okruhů: `python3 -I tools/tracks/build_track.py` (přepíše `data/tracks/*.json`).
- `scale` – zmenšení skutečné trati; menší = kratší kolo (cíl: Rakousko ~45 s, Austrálie ~51 s, Čína ~57 s).
- `width` – šířka asfaltu v metrech (široká kvůli předjíždění).
- `reverse` – obrátí směr jízdy, `start_shift` – posune start/cíl o metry podél trati.
Náhled: `python3 -I tools/tracks/build_track.py austria --preview /cesta/ke/slozce` uloží obrázek trati.
