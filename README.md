# Overtake

Závody formulí shora pro kamarády a boty. Brzdi u tabulí **BP**, chytni se do slipstreamu, použij **KERS**
a předjížděj na širokých tratích podle skutečných okruhů (**Rakousko, Austrálie, Čína**). Hraje se sám proti
botům nebo s kamarády přes stejnou Wi-Fi či přes [Tailscale](https://tailscale.com) (až 8 hráčů a boti, celkem 12 aut).

> **Stav vývoje (verze 0.1.0):** trénink a závod proti botům (4 obtížnosti), start se světly a spojkou, KERS,
> slipstream, volitelné opotřebení pneumatik a pitstop, tresty za kolize a zkrácení trati, živé pořadí,
> online hra s lobby, 3 tratě, automatické aktualizace. Aktuální verzi najdeš na
> [stránce vydání](https://github.com/nejhorsiprogramatorsveta/Overtake/releases/latest), stav práce v
> [docs/PROGRESS.md](docs/PROGRESS.md).

## Stažení (hotová hra, bez instalace)

| Systém | Nejnovější verze |
|---|---|
| **Windows 10/11** | [overtake-windows.exe](https://github.com/nejhorsiprogramatorsveta/Overtake/releases/latest/download/overtake-windows.exe) (asi 110 MB) |
| macOS (Apple Silicon i Intel) | [overtake-macos.zip](https://github.com/nejhorsiprogramatorsveta/Overtake/releases/latest/download/overtake-macos.zip) (asi 60 MB) |
| Linux | [overtake-linux.zip](https://github.com/nejhorsiprogramatorsveta/Overtake/releases/latest/download/overtake-linux.zip) (asi 75 MB) |

- **Automatické aktualizace:** když vyjde nová verze, hra ji po spuštění sama nabídne v menu (*Aktualizovat*),
  stáhne a restartuje se.
- Číslo verze je vlevo dole v menu hry.

> ⚠️ **Nestahuj** zelené tlačítko *Code → Download ZIP* ani *Source code (zip)*. To jsou zdrojové kódy a bez
> Godotu je nespustíš. Stahuj soubor `overtake-windows.exe` (Windows) nebo `overtake-macos.zip` / `overtake-linux.zip`.

### Windows
1. Stáhni `overtake-windows.exe` a spusť ho. Nic se neinstaluje ani nerozbaluje.
2. Pokud prohlížeč napíše, že soubor „není běžně stahován“, zvol *Zachovat*.
3. Pokud se objeví modré okno **„Systém Windows ochránil váš počítač“** (SmartScreen), klikni na *Další informace*
   a pak na *Přesto spustit*. Hra není podepsaná placeným certifikátem, proto ji Windows nezná.
4. Pokud se Windows zeptá na **bránu firewall**, klikni na *Povolit přístup*. Bez toho se k tobě kamarádi nepřipojí.

### macOS
Hra není ověřená u Applu (to stojí 99 USD ročně), proto ji macOS napoprvé zablokuje:
1. Rozbal ZIP a přesuň `overtake.app` třeba do složky Aplikace.
2. Dvakrát na hru klikni. Objeví se hláška, že ji Apple nemůže ověřit. Klikni na **Hotovo**.
3. Otevři **Nastavení systému → Soukromí a zabezpečení**, sjeď dolů a u hlášky o `overtake` klikni na
   **Přesto otevřít**. Potvrď heslem.
4. Pokud tlačítko chybí, spusť v Terminálu `xattr -dr com.apple.quarantine /Applications/overtake.app` a hru otevři znovu.

### Linux
Rozbal ZIP a spusť `overtake.x86_64` (případně nejdřív `chmod +x overtake.x86_64`).

## Ovládání (výchozí, dá se změnit v Nastavení)

| Akce | Klávesa |
|---|---|
| Plyn | W |
| Brzda | S |
| Zatáčení | A / D |
| Start: drž W + Mezerník, po zhasnutí světel pusť Mezerník | Mezerník |
| Pitstop: v boxové uličce zmáčkni Mezerník, když je ukazatel v zelené | Mezerník |
| KERS (3× za kolo, zapne se, až všichni po startu projedou cílem) | K |
| Menu / odejít | Esc |

**Tipy:** brzdi u bílých tabulí **BP** (s opotřebenými pneumatikami se posouvají dřív). Do 1,5 s za autem se
chytneš do slipstreamu. Do boxů zajeď najetím k okraji u tabule **PIT**. Vyjetí z trati se netrestá, jen tě
zpomalí kačírek. Zkrácení trati přes trávu a úmyslné naražení do soupeře stojí +5 s.

## Jak hrát s kamarády

**Průběh:** jeden hráč klikne na **Hostovat online** → v lobby nastaví trať, kola, boty a pneumatiky → ostatní se
připojí a vyberou si barvu auta → hostitel klikne **Spustit závod** → start se světly → výsledky → hostitel vrátí
všechny do **stejného lobby** a můžete jet znovu.

### Na stejné Wi-Fi
1. Všichni si stáhnete **stejnou verzi** hry (číslo vlevo dole v menu).
2. Jeden klikne na **Hostovat online** a v lobby klikne na **Kopírovat** u adresy „Stejná Wi-Fi / síť“.
3. Ostatní adresu vloží do pole v menu (celou, i s částí za `#`) a kliknou na **Připojit**.

### Přes internet (Tailscale)
[Tailscale](https://tailscale.com) je bezplatná aplikace pro Windows, Mac i Linux. Spojí vaše počítače do soukromé
sítě, jako byste byli na stejné Wi-Fi. Nemusíte nic nastavovat v routeru a nikdo neuvidí tvoji skutečnou IP adresu.

**Jednou na začátku:**
1. **Všichni:** stáhněte a nainstalujte Tailscale z [tailscale.com/download](https://tailscale.com/download)
   a přihlaste se (stačí Google, Microsoft nebo Apple účet).
2. **Hostitel:** otevři v prohlížeči [login.tailscale.com/admin/machines](https://login.tailscale.com/admin/machines).
   U svého počítače klikni na **⋯ → Share…** a pošli kamarádům odkaz. Kamarádi tak uvidí jen tento jeden počítač,
   ne tvoje ostatní zařízení.
3. **Kamarádi:** otevřou odkaz a přijmou sdílení.

**Pokaždé, když chcete hrát:**
1. Všichni mají Tailscale zapnutý (stav *Connected*).
2. Hostitel klikne na **Hostovat online** a v lobby na **Kopírovat** u adresy „Přes internet (Tailscale)“.
   Adresa začíná `100.` a obsahuje kód hry za `#` (např. `100.101.102.103:24650#K7Q2MX`).
3. Kamarádi adresu vloží a kliknou na **Připojit**.

**Když to nejde:**
- Zkontroluj, že **všichni mají zapnutý Tailscale** a kamarád v aplikaci Tailscale vidí tvůj počítač.
- **Windows:** po kliknutí na *Hostovat online* povol hru v bráně firewall (zaškrtni i *Veřejné sítě*, Tailscale
  síť bývá veřejná). Pokud jsi dotaz zamítl: *Nastavení → Zabezpečení Windows → Brána firewall → Povolit aplikaci* → `overtake`.
- **Všichni musí mít stejnou verzi hry.** Hra jinak sama napíše, že se verze liší.
- **Kód hry se mění při každém hostování.** Pošli vždy novou adresu.

## Vývoj

Potřebuješ jen git a bash (macOS nebo Linux). Godot se stáhne do projektu, nic se neinstaluje do systému.

```bash
tools/setup_env.sh                                        # jednou: stáhne Godot 4.7.2 do .tools/
tools/godot --headless --path . --import                  # import (po čistém klonu)
tools/godot --path .                                      # spustit hru
tools/godot --path . --editor                             # otevřít editor
tools/godot --headless --path . -s tests/run_tests.gd     # unit testy
tools/godot --headless --path . -s tools/check_localization.gd   # kontrola překladů
python3 -I tools/tracks/build_track.py --preview /tmp/tracks     # přegenerovat tratě (+ náhledy)
```

- Plán: [docs/PLAN.md](docs/PLAN.md) · Architektura: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) ·
  Průběh: [docs/PROGRESS.md](docs/PROGRESS.md) · Co se dá ladit v datech: [docs/EDITING_GUIDE.md](docs/EDITING_GUIDE.md)
- Buildy pro Windows, macOS a Linux vytváří GitHub Actions ([.github/workflows/build.yml](.github/workflows/build.yml))
  po každém pushi na `main` a aktualizují jediné vydání s tagem `release`. Každý push herních souborů musí mít
  v `project.godot` přesně další verzi (pravidla v [codex.md](codex.md)).

## Licence

- **Hra a kód:** [PolyForm Noncommercial 1.0.0](LICENSE). Hru i kód smíš zdarma stahovat, hrát, upravovat a sdílet,
  ale **jen nekomerčně**.
- Tvary tratí jsou odvozené z [bacinger/f1-circuits](https://github.com/bacinger/f1-circuits) (MIT), engine Godot (MIT),
  viz [CREDITS.md](CREDITS.md). Hra nepoužívá ochranné známky F1, jména týmů ani jejich loga.
