# Credits a licence assetů

Každý cizí asset musí mít v tomto souboru uvedený zdroj a licenci. Vlastní kód a grafika projektu jsou pod licencí
PolyForm Noncommercial 1.0.0 (soubor `LICENSE`): jen nekomerční použití.

| Asset | Soubor | Autor / zdroj | Licence |
|---|---|---|---|
| Herní engine Godot (včetně výchozího písma) | (součást každého buildu) | Juan Linietsky, Ariel Manzur a přispěvatelé Godotu, https://godotengine.org | MIT, https://godotengine.org/license |
| Grafika aut, tratí a UI | kód v `src/` (kresleno za běhu), `assets/ui/theme.tres` | vlastní tvorba projektu | PolyForm Noncommercial 1.0.0 |
| Tvary tratí (středové čáry skutečných okruhů) | zdroj `tools/tracks/src/*.geojson`, upravené `data/tracks/*.json` | Tomislav Bacinger, https://github.com/bacinger/f1-circuits | MIT (`tools/tracks/src/LICENSE.md`, ve hře `data/tracks/TRACKS_LICENSE.txt`) |
| Tvar trati AVUS (Berlín, uspořádání 1951–1967) | `tools/tracks/make_avus.py` → `tools/tracks/src/avus-1959.geojson`, `data/tracks/avus.json` | vlastní kresba projektu podle obecně známého tvaru (dvě rovinky, Nordkurve, Südkurve); není v bacinger/f1-circuits | PolyForm Noncommercial 1.0.0 |

Tvary tratí jsou upravené (zmenšené, vyhlazené, rozšířené pro předjíždění). Data nejsou oficiální a nejsou
schválena Formula One Licensing B.V.; hra nepoužívá loga ani ochranné známky F1 a sponzory. U výběru auta jsou
názvy skutečných týmů (rozhodnutí uživatele 2026-11-24, jen popisky barevných schémat). Tratě se jmenují podle
zemí nebo míst.
