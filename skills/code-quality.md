# Code-Qualität Optimierung

> **Skill für alle Projekte** — Verbessert Wartbarkeit, Lesbarkeit, Testabdeckung und reduziert Komplexität.
> Keine zusätzliche Software nötig. Nutzt existierende Linter, Formatter und Test-Tools.

## Voraussetzungen

- Softwareprojekt mit existierendem Codebase
- Mindestens ein vorhandenes Qualitätstool (Linter, Tests, Type-Checker)
- Git-Versionierung

## Setup

1. **Vorhandene Tools identifizieren**:
   ```bash
   # JavaScript/TypeScript
   cat package.json | grep -E "eslint|prettier|jest|vitest|mocha|tsc"

   # Python
   cat pyproject.toml | grep -E "ruff|pylint|mypy|pytest|black|flake8"
   ls setup.cfg tox.ini .flake8 .pylintrc 2>/dev/null

   # Go
   ls go.mod && echo "go vet, go test verfügbar"

   # Rust
   ls Cargo.toml && echo "cargo clippy, cargo test verfügbar"

   # Generisch
   ls .editorconfig .pre-commit-config.yaml Makefile 2>/dev/null
   ```

2. **Metriken wählen** (eine oder mehrere):

   | Metrik | Messkommando (Beispiel) | Ziel |
   |--------|------------------------|------|
   | Lint-Fehler | `npx eslint src/ --format json 2>&1 \| grep errorCount` | → 0 |
   | Type-Fehler | `npx tsc --noEmit 2>&1 \| grep "error TS" \| wc -l` | → 0 |
   | Test-Coverage | `npm test -- --coverage 2>&1 \| grep "All files"` | Höher |
   | Zyklomatische Komplexität | `npx complexity-report src/ 2>&1` | Niedriger |
   | Duplizierter Code | `npx jscpd src/ 2>&1 \| grep "Total"` | Weniger |
   | Python Lint | `ruff check . 2>&1 \| tail -1` | → 0 |
   | Python Types | `mypy . 2>&1 \| grep "error" \| wc -l` | → 0 |
   | Go Vet | `go vet ./... 2>&1 \| wc -l` | → 0 |
   | Rust Clippy | `cargo clippy 2>&1 \| grep "warning" \| wc -l` | → 0 |

3. **Branch und Tracking**:
   ```bash
   git checkout -b optimize/code-quality-<datum>
   ```
   Erstelle `results.tsv`:
   ```
   commit	metrik	metrik_name	status	beschreibung
   ```

## Experiment-Strategie

### Phase 1: Bestandsaufnahme (Experiment 1-3)
1. **Baseline erfassen**: Alle verfügbaren Qualitätstools laufen lassen
2. **Hotspots identifizieren**: Welche Dateien haben die meisten Probleme?
   ```bash
   # Größte Dateien (oft problematisch)
   find src -name "*.ts" -o -name "*.py" -o -name "*.go" | xargs wc -l | sort -n -r | head -20

   # Dateien mit meisten Lint-Fehlern
   npx eslint src/ --format json 2>&1 | python3 -c "
   import json,sys
   data=json.load(sys.stdin)
   for f in sorted(data, key=lambda x: x['errorCount'], reverse=True)[:10]:
       if f['errorCount']>0: print(f'{f[\"errorCount\"]:4d} {f[\"filePath\"]}')"
   ```
3. **Tests prüfen**: Welche Bereiche haben keine Tests?

### Phase 2: Automatisierbare Fixes (Experiment 4-10)

#### Linter-Fehler beheben
```bash
# ESLint Auto-Fix
npx eslint src/ --fix

# Prettier
npx prettier --write src/

# Ruff (Python)
ruff check . --fix

# Go
gofmt -w .

# Rust
cargo fmt
```

**Pro Experiment**: Einen Fehlertyp auf einmal fixen, committen, Metrik messen.

#### Type-Fehler beheben
- `any`-Types durch konkrete Types ersetzen
- Fehlende Type-Annotations hinzufügen
- Null-Checks hinzufügen wo TypeScript/mypy warnt
- Generics korrekt typisieren

### Phase 3: Strukturelle Verbesserungen (Experiment 11-20)

#### Komplexität reduzieren
- **Lange Funktionen aufteilen**: Funktionen > 50 Zeilen in kleinere Teile zerlegen
- **Tiefe Verschachtelungen eliminieren**: Early Returns, Guard Clauses
  ```typescript
  // Vorher
  function process(data) {
    if (data) {
      if (data.valid) {
        if (data.items.length > 0) {
          // ... deep logic
        }
      }
    }
  }

  // Nachher
  function process(data) {
    if (!data?.valid) return;
    if (data.items.length === 0) return;
    // ... flat logic
  }
  ```
- **Switch/If-Ketten** durch Maps, Polymorphie oder Strategy-Pattern ersetzen
- **God-Objects auflösen**: Große Klassen in fokussierte Module aufteilen

#### Duplikation entfernen
- Gemeinsame Logik in Hilfsfunktionen extrahieren
- Ähnliche Komponenten abstrahieren
- Konfiguration zentralisieren statt kopieren

#### Testabdeckung erhöhen
- **Ungetestete Pfade identifizieren**:
  ```bash
  npm test -- --coverage 2>&1 | grep -E "^[^|]*\|[^|]*\|[^|]*\|[^|]*[0-9]" | sort -t'|' -k4 -n | head -20
  ```
- **Tests für kritische Pfade** schreiben (Business-Logik, Error-Handling)
- **Edge Cases** abdecken (leere Eingaben, Null-Werte, Grenzwerte)
- **Keine trivialen Tests**: Kein `expect(1+1).toBe(2)` — teste echte Logik

### Phase 4: Architektur (Experiment 21+)
- **Dependency Injection** für bessere Testbarkeit
- **Interface-Segregation**: Große Interfaces aufteilen
- **Circular Dependencies** auflösen
- **Error Handling** vereinheitlichen
- **Logging** konsistent machen
- **Magic Numbers/Strings** in Konstanten umwandeln

## Qualitäts-Checkliste pro Experiment

Vor dem Commit jedes Experiments:
```bash
# 1. Alle Tests bestehen noch?
npm test 2>&1 | tail -5

# 2. Lint-Fehler nicht erhöht?
npx eslint src/ --format json 2>&1 | grep errorCount

# 3. Build funktioniert noch?
npm run build 2>&1 | tail -5

# 4. Type-Check besteht?
npx tsc --noEmit 2>&1 | tail -5
```

**Goldene Regel**: Nur committen, wenn alle bestehenden Checks weiterhin bestehen.

## Logging-Format

```
commit	metrik	metrik_name	status	beschreibung
a1b2c3d	47	eslint_errors	keep	baseline: 47 ESLint-Fehler
b2c3d4e	32	eslint_errors	keep	no-unused-vars auto-fix
c3d4e5f	28	eslint_errors	keep	any-Types in api.ts ersetzt
d4e5f6g	28	eslint_errors	discard	Refactoring von utils.ts bricht Tests
```

## Hinweise

- **Keine Verhaltensänderungen**: Code-Qualität verbessern ohne die Funktionalität zu ändern
- **Incremental vorgehen**: Ein Commit pro logische Änderung, nicht alles auf einmal
- **Auto-Fix zuerst**: Automatisierbare Fixes vor manuellen Änderungen
- **Tests schützen**: Wenn du Tests hinzufügst, stelle sicher, dass sie echten Wert haben
- **Review-freundlich**: Kleine, fokussierte Commits sind leichter zu reviewen

---

*Dieser Skill basiert auf dem [autonomous-optimization.md](autonomous-optimization.md) Kern-Loop. Lies diesen zuerst für das grundlegende Experiment-Protokoll.*
