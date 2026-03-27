# Web-Performance Optimierung

> **Skill für Web-Projekte** — Optimiert Ladezeiten, Bundle-Größe, Core Web Vitals und Rendering-Performance.
> Keine zusätzliche Software nötig. Nutzt existierende Projekt-Tools.

## Voraussetzungen

- Web-Projekt (React, Vue, Angular, Next.js, Svelte, oder Vanilla JS/TS)
- Existierender Build-Prozess (`npm run build`, `vite build`, etc.)
- Mindestens eine messbare Metrik (Bundle-Größe, Lighthouse-Score, etc.)

## Setup

1. **Projekt-Dateien lesen**: Lies die wichtigsten Dateien:
   - `package.json` — Dependencies und Scripts
   - Build-Konfiguration (`vite.config.ts`, `webpack.config.js`, `next.config.js`, etc.)
   - Haupt-Einstiegspunkt (`src/main.ts`, `src/App.tsx`, `pages/_app.tsx`, etc.)
   - Größte Komponenten (sortiert nach Dateigröße)

2. **Metriken identifizieren** (wähle mindestens eine):

   | Metrik | Messkommando | Ziel |
   |--------|-------------|------|
   | Bundle-Größe | `npm run build 2>&1 \| grep -i "size\|gzip\|chunk"` | Kleiner |
   | Build-Zeit | `time npm run build 2>&1` | Kürzer |
   | Lighthouse Score | `npx lighthouse <url> --output json --quiet` | Höher |
   | First Contentful Paint | Lighthouse JSON → `.audits.first-contentful-paint` | Kürzer |
   | Total Blocking Time | Lighthouse JSON → `.audits.total-blocking-time` | Kürzer |
   | Largest Contentful Paint | Lighthouse JSON → `.audits.largest-contentful-paint` | Kürzer |

3. **Branch und Tracking**:
   ```bash
   git checkout -b optimize/web-perf-<datum>
   ```
   Erstelle `results.tsv`:
   ```
   commit	metrik	metrik_name	status	beschreibung
   ```

## Experiment-Strategie

### Phase 1: Analyse (Experiment 1-3)
1. **Baseline messen**: Build unverändert laufen lassen, alle Metriken erfassen
2. **Bundle analysieren**:
   ```bash
   # Webpack
   npx webpack-bundle-analyzer dist/stats.json

   # Vite/Rollup — visualisieren
   npx vite-bundle-visualizer

   # Generisch — größte Dateien finden
   find dist -type f -name "*.js" -exec ls -lh {} \; | sort -k5 -h -r | head -20
   ```
3. **Größte Dependencies identifizieren**:
   ```bash
   npx depcheck
   du -sh node_modules/* | sort -h -r | head -20
   ```

### Phase 2: Quick Wins (Experiment 4-10)

#### Import-Optimierung
- **Tree Shaking prüfen**: Named Imports statt Default-Imports für große Libraries
  ```typescript
  // Vorher: importiert alles
  import _ from 'lodash';
  // Nachher: nur was gebraucht wird
  import { debounce } from 'lodash-es';
  ```
- **Dynamic Imports**: Große Komponenten lazy laden
  ```typescript
  const HeavyComponent = lazy(() => import('./HeavyComponent'));
  ```
- **Barrel-Exports eliminieren**: `index.ts` Re-Exports können Tree Shaking verhindern

#### Build-Konfiguration
- **Compression aktivieren**: gzip/brotli falls noch nicht aktiv
- **Code Splitting**: Vendor-Chunks, Route-basiertes Splitting
- **Minification prüfen**: terser/esbuild/swc korrekt konfiguriert?
- **Source Maps**: Nur in Dev, nicht in Prod-Bundle

#### Asset-Optimierung
- **Bilder**: WebP/AVIF statt PNG/JPG, richtige Größen, lazy loading
- **Fonts**: `font-display: swap`, nur benötigte Glyphen, Preload
- **CSS**: Unbenutztes CSS entfernen (PurgeCSS/Tailwind Purge)

### Phase 3: Code-Level (Experiment 11-20)

#### Rendering-Performance
- **Unnötige Re-Renders** vermeiden:
  ```typescript
  // React: useMemo, useCallback, React.memo
  const MemoizedComponent = React.memo(ExpensiveComponent);
  const memoizedValue = useMemo(() => computeExpensiveValue(a, b), [a, b]);
  ```
- **Virtualisierung** für lange Listen (react-window, @tanstack/virtual)
- **Debounce/Throttle** für häufige Events (Scroll, Resize, Input)

#### Netzwerk-Optimierung
- **Prefetch/Preload**: Kritische Ressourcen vorladen
- **Service Worker / Caching-Strategie** prüfen
- **API-Calls optimieren**: Batching, Deduplizierung, SWR/React-Query
- **HTTP/2 Server Push** oder `<link rel="preload">`

#### JavaScript-Optimierung
- **Große Bibliotheken ersetzen**: moment.js → date-fns/dayjs, lodash → native JS
- **Polyfills reduzieren**: Browserslist aktualisieren, unnötige Polyfills entfernen
- **Web Workers** für CPU-intensive Berechnungen

### Phase 4: Fortgeschritten (Experiment 21+)
- **SSR/SSG**: Server-Side Rendering oder Static Generation für bessere FCP
- **Edge Computing**: API-Routen an die Edge verschieben
- **Bundle-Splitting-Strategie** komplett überarbeiten
- **Micro-Frontends**: Große Apps in kleinere Module aufteilen
- **Streaming SSR**: Progressive Rendering für bessere TTFB

## Messprotokoll

### Bundle-Größe messen:
```bash
npm run build > run.log 2>&1
# Gesamtgröße aller JS-Dateien
find dist -name "*.js" -exec cat {} + | wc -c | awk '{printf "%.1f KB\n", $1/1024}'
# Oder gzip-Größe
find dist -name "*.js" -exec gzip -c {} + | wc -c | awk '{printf "%.1f KB gzip\n", $1/1024}'
```

### Nach jeder Änderung prüfen:
```bash
# Build erfolgreich?
npm run build > run.log 2>&1
echo "Exit code: $?"

# Tests bestehen noch?
npm test > test.log 2>&1
echo "Exit code: $?"

# Metrik extrahieren
grep "<pattern>" run.log
```

## Logging-Format

```
commit	metrik	metrik_name	status	beschreibung
a1b2c3d	245.3	bundle_kb_gzip	keep	baseline
b2c3d4e	198.7	bundle_kb_gzip	keep	lodash durch native JS ersetzt
c3d4e5f	195.2	bundle_kb_gzip	keep	dynamic import für Dashboard
d4e5f6g	0.0	bundle_kb_gzip	crash	build bricht ab nach CSS-Änderung
```

## Hinweise

- **Funktionalität geht vor Performance**: Niemals Features brechen für kleinere Bundles
- **Messbar bleiben**: Nur Änderungen behalten, die die Metrik nachweislich verbessern
- **Caching beachten**: `rm -rf dist node_modules/.cache` vor dem Messen falls nötig
- **Verschiedene Metriken können konfligieren**: Größeres Code-Splitting = mehr HTTP-Requests

---

*Dieser Skill basiert auf dem [autonomous-optimization.md](autonomous-optimization.md) Kern-Loop. Lies diesen zuerst für das grundlegende Experiment-Protokoll.*
