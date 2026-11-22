# Overtake

Závody formulí shora pro kamarády a boty. Brzdi u tabulí **BP**, chytni se do slipstreamu, použij **KERS**
a předjížděj na širokých tratích podle skutečných okruhů (Rakousko, Austrálie, Čína). Hraje se přes stejnou
Wi-Fi nebo přes [Tailscale](https://tailscale.com).

> **Stav vývoje:** hra se teprve staví (milník M0: kostra projektu, menu, nastavení ovládání a automatické
> aktualizace). Ke stažení zatím není. Plán najdeš v [docs/PLAN.md](docs/PLAN.md), aktuální stav v [docs/PROGRESS.md](docs/PROGRESS.md).

## Ovládání (výchozí, dá se změnit v Nastavení)

| Akce | Klávesa |
|---|---|
| Plyn | W |
| Brzda | S |
| Zatáčení | A / D |
| Spojka na startu (drž W + Mezerník, po zhasnutí světel pusť Mezerník) / pitstop | Mezerník |
| KERS (3× za kolo) | K |
| Menu | Esc |

## Vývoj

Potřebuješ jen git a bash (macOS nebo Linux). Godot se stáhne do projektu, nic se neinstaluje do systému.

```bash
tools/setup_env.sh                                        # jednou: stáhne Godot 4.7.2 do .tools/
tools/godot --headless --path . --import                  # import (po čistém klonu)
tools/godot --path .                                      # spustit hru
tools/godot --path . --editor                             # otevřít editor
tools/godot --headless --path . -s tests/run_tests.gd     # unit testy
tools/godot --headless --path . -s tools/check_localization.gd   # kontrola překladů
```

- Plán: [docs/PLAN.md](docs/PLAN.md) · Architektura: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) · Průběh: [docs/PROGRESS.md](docs/PROGRESS.md)
- Buildy pro Windows, macOS a Linux vytváří GitHub Actions ([.github/workflows/build.yml](.github/workflows/build.yml)).

## Licence

- **Hra a kód:** [PolyForm Noncommercial 1.0.0](LICENSE) – zdarma ke hraní, úpravám a sdílení, ale jen nekomerčně.
- Cizí části mají vlastní licence, viz [CREDITS.md](CREDITS.md).
