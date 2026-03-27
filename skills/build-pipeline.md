# Build-Pipeline Optimierung

> **Skill für alle Projekte** — Optimiert Build-Zeiten, CI/CD-Dauer und Developer Experience.
> Keine zusätzliche Software nötig. Nutzt existierende Build-Tools und Konfigurationen.

## Voraussetzungen

- Softwareprojekt mit Build-Prozess (`npm run build`, `cargo build`, `go build`, `mvn package`, etc.)
- Versionierung mit Git
- Optional: CI/CD-Pipeline (GitHub Actions, GitLab CI, etc.)

## Setup

1. **Build-System identifizieren**:
   ```bash
   # Was wird zum Builden genutzt?
   ls Makefile CMakeLists.txt build.gradle pom.xml Cargo.toml go.mod \
      package.json pyproject.toml webpack.config.* vite.config.* \
      tsconfig.json 2>/dev/null

   # Build-Kommandos finden
   grep -E "\"build|\"compile|\"start" package.json 2>/dev/null
   grep -E "build:|test:|lint:" Makefile 2>/dev/null
   ```

2. **Metriken wählen**:

   | Metrik | Messkommando | Ziel |
   |--------|-------------|------|
   | Build-Zeit | `time npm run build 2>&1` | Kürzer |
   | Incremental Build | `time npm run build 2>&1` (nach kleiner Änderung) | Kürzer |
   | Test-Laufzeit | `time npm test 2>&1` | Kürzer |
   | CI-Pipeline-Dauer | GitHub Actions / GitLab CI Logs | Kürzer |
   | Cold Build (clean) | `rm -rf dist && time npm run build 2>&1` | Kürzer |
   | Install-Zeit | `rm -rf node_modules && time npm install 2>&1` | Kürzer |

3. **Branch und Tracking**:
   ```bash
   git checkout -b optimize/build-<datum>
   ```
   Erstelle `results.tsv`:
   ```
   commit	zeit_sek	metrik_name	status	beschreibung
   ```

## Experiment-Strategie

### Phase 1: Diagnose (Experiment 1-3)
1. **Baseline messen**: Mehrfach messen (3x) und Durchschnitt nehmen
   ```bash
   for i in 1 2 3; do
     rm -rf dist .next .cache
     { time npm run build; } 2>&1 | grep real
   done
   ```
2. **Build-Phasen identifizieren**: Wo verbringt der Build die meiste Zeit?
   ```bash
   # Webpack mit Timing
   npx webpack --profile --json > stats.json

   # TypeScript Timing
   npx tsc --diagnostics

   # Go Timing
   go build -x ./... 2>&1 | head -50
   ```
3. **Abhängigkeitsbaum analysieren**:
   ```bash
   npm ls --depth=0 | wc -l    # Anzahl top-level Dependencies
   du -sh node_modules          # Gesamtgröße
   ```

### Phase 2: Quick Wins (Experiment 4-10)

#### Caching aktivieren
```javascript
// webpack.config.js — Filesystem Cache
module.exports = {
  cache: {
    type: 'filesystem',
    buildDependencies: {
      config: [__filename],
    },
  },
};
```

```javascript
// vite.config.ts — Dep Optimization Cache
export default defineConfig({
  optimizeDeps: {
    force: false, // Cache nutzen
  },
});
```

```toml
# Cargo.toml — Incremental Compilation
[profile.dev]
incremental = true
```

#### Parallele Verarbeitung
```javascript
// webpack — Thread-Loader für teure Loaders
{
  test: /\.tsx?$/,
  use: ['thread-loader', 'ts-loader'],
}

// Oder: esbuild-loader statt ts-loader (10-100x schneller)
{
  test: /\.tsx?$/,
  loader: 'esbuild-loader',
  options: { target: 'es2020' },
}
```

#### TypeScript-Kompilierung beschleunigen
```json
// tsconfig.json
{
  "compilerOptions": {
    "incremental": true,
    "tsBuildInfoFile": ".tsbuildinfo",
    "skipLibCheck": true,
    "isolatedModules": true
  }
}
```

#### Unnötige Build-Schritte eliminieren
- Source Maps nur in Development
- Type-Checking vom Build trennen (parallel laufen lassen)
- Unnötige PostCSS/Autoprefixer-Plugins entfernen wenn nicht benötigt
- Polyfills für alte Browser entfernen wenn nicht benötigt

### Phase 3: Tool-Wechsel (Experiment 11-20)

#### Schnellere Alternativen evaluieren
| Vorher | Nachher | Typischer Speedup |
|--------|---------|--------------------|
| webpack | Vite / esbuild / Turbopack | 10-100x |
| ts-loader | esbuild-loader / swc-loader | 10-50x |
| babel | SWC | 20-70x |
| Jest | Vitest | 2-10x |
| terser | esbuild minify | 10-100x |
| node-sass | sass (dart-sass) | 2-5x |
| tsc (type check) | @biomejs/biome | 2-5x |

**Wichtig**: Tool-Wechsel sind große Änderungen. Sorgfältig testen!

#### Monorepo-Optimierungen
```bash
# Nur geänderte Packages bauen
npx turbo run build --filter=...[HEAD^1]

# Oder mit nx
npx nx affected --target=build
```

### Phase 4: CI/CD-Optimierung (Experiment 21+)

#### GitHub Actions optimieren
```yaml
# Caching für node_modules
- uses: actions/cache@v4
  with:
    path: ~/.npm
    key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}

# Oder noch besser: nur geänderte Tests laufen lassen
- run: npx jest --changedSince=origin/main
```

#### Parallele CI-Jobs
```yaml
# Tests aufteilen
strategy:
  matrix:
    shard: [1, 2, 3, 4]
steps:
  - run: npx jest --shard=${{ matrix.shard }}/4
```

#### Docker-Build-Optimierung
```dockerfile
# Multi-Stage Build mit Cache
FROM node:20 AS deps
WORKDIR /app
COPY package*.json ./
RUN --mount=type=cache,target=/root/.npm npm ci

FROM deps AS builder
COPY . .
RUN npm run build

FROM node:20-slim AS runner
COPY --from=builder /app/dist ./dist
```

#### Dependency-Optimierung
```bash
# Ungenutzte Dependencies finden
npx depcheck

# Doppelte Dependencies finden
npm ls --all 2>&1 | grep "deduped" | wc -l

# Lock-File aufräumen
rm -rf node_modules package-lock.json
npm install
```

## Messprotokoll

### Build-Zeit zuverlässig messen:
```bash
# Clean Build (konsistent)
rm -rf dist .next .cache node_modules/.cache .tsbuildinfo
sync  # Filesystem-Caches flushen

# 3x messen und Durchschnitt nehmen
total=0
for i in 1 2 3; do
  t=$( { time npm run build > /dev/null 2>&1; } 2>&1 | grep real | awk '{print $2}' )
  echo "Run $i: $t"
  # Sekunden extrahieren
  secs=$(echo "$t" | sed 's/m/*60+/;s/s//' | bc)
  total=$(echo "$total + $secs" | bc)
done
avg=$(echo "$total / 3" | bc -l)
printf "Durchschnitt: %.1f Sekunden\n" "$avg"
```

### Nach jeder Änderung prüfen:
```bash
# 1. Build erfolgreich?
npm run build > run.log 2>&1
echo "Exit: $?"

# 2. Tests bestehen?
npm test > test.log 2>&1
echo "Exit: $?"

# 3. Output korrekt? (Stichprobe)
ls -la dist/
```

## Logging-Format

```
commit	zeit_sek	metrik_name	status	beschreibung
a1b2c3d	45.2	clean_build	keep	baseline
b2c3d4e	38.7	clean_build	keep	filesystem cache aktiviert
c3d4e5f	12.3	clean_build	keep	esbuild-loader statt ts-loader
d4e5f6g	0.0	clean_build	crash	vite migration unvollständig
```

## Hinweise

- **Konsistenz beim Messen**: Immer gleiche Bedingungen (clean build vs. incremental)
- **Caches leeren**: `rm -rf dist node_modules/.cache .tsbuildinfo` vor jeder Messung
- **Mehrfach messen**: Build-Zeiten variieren — mindestens 3x messen
- **Trade-offs beachten**: Schnellerer Build kann größere Bundles produzieren
- **CI vs. Lokal**: CI-Zeiten können sich anders verhalten als lokale Builds

---

*Dieser Skill basiert auf dem [autonomous-optimization.md](autonomous-optimization.md) Kern-Loop. Lies diesen zuerst für das grundlegende Experiment-Protokoll.*
