# API-Performance Optimierung

> **Skill für Backend-Projekte** — Optimiert Antwortzeiten, Durchsatz, Datenbankabfragen und Ressourcenverbrauch.
> Keine zusätzliche Software nötig. Nutzt existierende Projekt-Tools und eingebaute Benchmarks.

## Voraussetzungen

- Backend-Projekt (Node.js/Express, Python/FastAPI/Django, Go, Rust, Java/Spring, etc.)
- Möglichkeit, den Server lokal zu starten
- Mindestens eine messbare Metrik (Antwortzeit, Requests/Sekunde, etc.)

## Setup

1. **Projekt-Dateien lesen**: Lies die wichtigsten Dateien:
   - Entry-Point (`server.ts`, `app.py`, `main.go`, etc.)
   - Route-Definitionen
   - Datenbank-Konfiguration und Modelle/Schemas
   - Middleware-Stack

2. **Metriken identifizieren**:

   | Metrik | Messkommando | Ziel |
   |--------|-------------|------|
   | Antwortzeit | `curl -w "%{time_total}" -o /dev/null -s http://localhost:3000/api/endpoint` | Kürzer |
   | Requests/Sek | Eingebauter Benchmark oder einfacher Loop (siehe unten) | Mehr |
   | DB-Abfragen | Query-Logging aktivieren und zählen | Weniger |
   | Speicher | `ps -o rss= -p <PID>` während Last | Weniger |
   | Startup-Zeit | `time node server.js &; sleep 2; curl localhost:3000/health` | Kürzer |

3. **Einfacher Benchmark** (ohne externe Tools):
   ```bash
   # Einfacher Durchsatz-Test mit curl
   start=$(date +%s%N)
   for i in $(seq 1 100); do
     curl -s -o /dev/null http://localhost:3000/api/endpoint
   done
   end=$(date +%s%N)
   echo "100 Requests in $(( (end - start) / 1000000 )) ms"

   # Oder mit xargs für Parallelität
   seq 100 | xargs -P 10 -I {} curl -s -o /dev/null -w "%{time_total}\n" http://localhost:3000/api/endpoint | awk '{sum+=$1} END {printf "Avg: %.3fs, Total: %.1fs\n", sum/NR, sum}'
   ```

4. **Branch und Tracking**:
   ```bash
   git checkout -b optimize/api-perf-<datum>
   ```
   Erstelle `results.tsv`:
   ```
   commit	avg_ms	rps	status	beschreibung
   ```

## Experiment-Strategie

### Phase 1: Diagnose (Experiment 1-3)
1. **Baseline messen**: Server starten, Benchmark laufen lassen
2. **Langsame Endpunkte identifizieren**: Alle Hauptendpunkte messen und nach Antwortzeit sortieren
3. **Datenbankabfragen loggen**: Query-Logging aktivieren und N+1-Probleme suchen
   ```python
   # Django
   LOGGING = {'loggers': {'django.db.backends': {'level': 'DEBUG'}}}

   # SQLAlchemy
   engine = create_engine(url, echo=True)
   ```

### Phase 2: Quick Wins (Experiment 4-10)

#### N+1-Queries eliminieren
```python
# Vorher: N+1 Problem
users = User.query.all()
for user in users:
    orders = user.orders  # Jeder Zugriff = 1 Query

# Nachher: Eager Loading
users = User.query.options(joinedload(User.orders)).all()
```

```javascript
// Vorher: N+1 in einer Schleife
const users = await User.findAll();
for (const user of users) {
    user.orders = await Order.findAll({ where: { userId: user.id } });
}

// Nachher: Ein Query mit JOIN
const users = await User.findAll({ include: [Order] });
```

#### Response-Caching
```python
# Einfacher In-Memory Cache
from functools import lru_cache

@lru_cache(maxsize=128)
def get_expensive_data(key):
    return db.query(...)
```

```javascript
// Einfacher Cache mit Map
const cache = new Map();
function getCached(key, ttlMs = 60000) {
    const entry = cache.get(key);
    if (entry && Date.now() - entry.time < ttlMs) return entry.data;
    const data = computeExpensive(key);
    cache.set(key, { data, time: Date.now() });
    return data;
}
```

#### Datenbank-Indizes
```sql
-- Langsame Queries identifizieren und Indizes erstellen
EXPLAIN ANALYZE SELECT * FROM orders WHERE user_id = 123;
-- Falls Seq Scan → Index fehlt
CREATE INDEX idx_orders_user_id ON orders(user_id);
```

#### JSON-Serialisierung optimieren
- Nur benötigte Felder zurückgeben (kein `SELECT *`)
- Pagination für große Listen
- Felder-Selektion ermöglichen (`?fields=id,name,email`)

### Phase 3: Middleware und I/O (Experiment 11-20)

#### Middleware-Stack optimieren
- **Unnötige Middleware entfernen**: Jede Middleware kostet Zeit pro Request
- **Reihenfolge optimieren**: Häufig abgelehnte Requests früh filtern (Auth, Rate-Limiting zuerst)
- **Compression aktivieren**: gzip/brotli für Responses > 1KB

#### Connection Pooling
```python
# SQLAlchemy
engine = create_engine(url, pool_size=20, max_overflow=10, pool_recycle=3600)
```

```javascript
// Node.js PostgreSQL
const pool = new Pool({ max: 20, idleTimeoutMillis: 30000 });
```

#### Async/Parallel Operations
```python
# Vorher: Sequentiell
data_a = await fetch_a()
data_b = await fetch_b()

# Nachher: Parallel
data_a, data_b = await asyncio.gather(fetch_a(), fetch_b())
```

```javascript
// Vorher: Sequentiell
const a = await fetchA();
const b = await fetchB();

// Nachher: Parallel
const [a, b] = await Promise.all([fetchA(), fetchB()]);
```

### Phase 4: Fortgeschritten (Experiment 21+)

#### Query-Optimierung
- Komplexe JOINs durch Denormalisierung ersetzen (Trade-off!)
- Materialized Views für häufige Aggregationen
- Prepared Statements für wiederkehrende Queries
- Batch-Inserts statt einzelner INSERTs

#### Algorithmus-Optimierung
- Lineare Suchen durch Hash-Lookups ersetzen
- Unnötige Berechnungen cachen oder vorberechnen
- Pagination serverseitig statt clientseitig
- Streaming für große Responses statt alles in Speicher laden

#### Architektur
- Response-Komprimierung
- ETags / Conditional Requests (304 Not Modified)
- Lazy Loading von Relationen
- CQRS-Pattern für read-heavy Endpunkte

## Messprotokoll

### Server starten und messen:
```bash
# Server im Hintergrund starten
npm start > server.log 2>&1 &
SERVER_PID=$!
sleep 3  # Warten bis Server bereit

# Benchmark laufen lassen
seq 100 | xargs -P 10 -I {} curl -s -o /dev/null -w "%{time_total}\n" \
  http://localhost:3000/api/endpoint > bench.log 2>&1

# Ergebnis extrahieren
awk '{sum+=$1; count++} END {printf "Avg: %.0fms, Count: %d\n", (sum/count)*1000, count}' bench.log

# Server stoppen
kill $SERVER_PID
```

### Nach jeder Änderung prüfen:
1. Kompiliert/startet der Server noch?
2. Bestehen alle Tests?
3. Gibt der Endpunkt korrekte Daten zurück? (`curl ... | head -c 200`)
4. Hat sich die Metrik verbessert?

## Logging-Format

```
commit	avg_ms	rps	status	beschreibung
a1b2c3d	145	68	keep	baseline
b2c3d4e	89	112	keep	N+1 Query in /users eliminiert
c3d4e5f	45	220	keep	Response-Cache für /products
d4e5f6g	0	0	crash	Connection Pool zu aggressiv konfiguriert
```

## Hinweise

- **Korrektheit vor Speed**: Schnellere Antworten bringen nichts, wenn die Daten falsch sind
- **Realistische Last**: Messe mit mehreren parallelen Requests, nicht nur einzeln
- **Cold Start beachten**: Erste Requests nach Serverstart sind immer langsamer
- **Cache-Invalidierung**: Cache ist nur gut, wenn er korrekt invalidiert wird
- **Datenbank-Migrationen**: Neue Indizes können bei großen Tabellen lange dauern

---

*Dieser Skill basiert auf dem [autonomous-optimization.md](autonomous-optimization.md) Kern-Loop. Lies diesen zuerst für das grundlegende Experiment-Protokoll.*
