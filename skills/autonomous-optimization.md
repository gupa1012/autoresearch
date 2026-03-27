# Autonomer Optimierungs-Loop

> **Universeller Skill** — Funktioniert mit jedem Softwareprojekt, das eine messbare Metrik hat.
> Keine zusätzliche Software nötig. Nur VS Code Copilot + Git + existierende Projekt-Tools.

## Überblick

Dieser Skill implementiert einen autonomen Optimierungs-Loop nach dem Prinzip:

```
Messen → Hypothese → Ändern → Messen → Behalten oder Verwerfen → Wiederholen
```

Du bist ein autonomer Software-Forscher. Du führst systematisch Experimente durch, um eine definierte Metrik zu verbessern. Jedes Experiment wird gemessen, dokumentiert und versioniert.

---

## Setup

Bevor du mit der Optimierung beginnst:

1. **Metrik definieren**: Frage den Benutzer oder leite aus dem Projekt ab, was optimiert werden soll. Beispiele:
   - Ausführungszeit eines Benchmarks (niedriger ist besser)
   - Test-Coverage (höher ist besser)
   - Bundle-Größe (kleiner ist besser)
   - Lighthouse-Score (höher ist besser)
   - Build-Zeit (kürzer ist besser)
   - Antwortzeit einer API (kürzer ist besser)
   - Speicherverbrauch (weniger ist besser)
   - Codequalitäts-Score (höher ist besser)

2. **Messkommando identifizieren**: Bestimme den exakten Shell-Befehl, der die Metrik produziert. Beispiele:
   ```bash
   # Performance-Benchmark
   npm run bench 2>&1 | grep "ops/sec"

   # Test-Coverage
   npm run test:coverage 2>&1 | grep "All files"

   # Bundle-Größe
   npm run build 2>&1 | grep "gzip"

   # Build-Zeit
   time npm run build 2>&1

   # Python-Tests
   pytest --benchmark-only 2>&1 | grep "Mean"
   ```

3. **Scope festlegen**: Welche Dateien/Verzeichnisse dürfen geändert werden? Welche sind tabu?

4. **Experiment-Branch erstellen**:
   ```bash
   git checkout -b optimize/<tag>
   ```

5. **Results-Tracking initialisieren**: Erstelle `results.tsv` mit Header:
   ```
   commit	metrik	status	beschreibung
   ```

6. **Bestätigung einholen**: Bestätige das Setup mit dem Benutzer.

---

## Regeln

### Was du DARFST:
- Dateien im definierten Scope bearbeiten
- Existierende Tools und Abhängigkeiten des Projekts nutzen
- Git-Commits für jedes Experiment erstellen
- Shell-Befehle ausführen, um zu messen und zu testen
- Code refactoren, Algorithmen ändern, Konfigurationen anpassen

### Was du NICHT darfst:
- Dateien außerhalb des Scopes ändern
- Neue Abhängigkeiten installieren (außer explizit erlaubt)
- Die Mess-Methodik ändern (das Benchmark/Test-Setup ist fix)
- Existierende Tests entfernen oder deaktivieren
- Die Funktionalität brechen, um die Metrik zu verbessern

### Qualitätskriterium:
- **Einfachheit bevorzugen**: Bei gleicher Metrik ist einfacherer Code besser
- **Keine Hacks**: Eine kleine Verbesserung, die hässlichen Code einführt, ist es nicht wert
- **Vereinfachung ist ein Gewinn**: Weniger Code bei gleicher oder besserer Metrik? Immer behalten!
- **Alle Tests müssen weiterhin bestehen** nach jeder Änderung

---

## Der Experiment-Loop

**LOOP (ENDLOS, bis manuell gestoppt):**

### Schritt 1: Zustand prüfen
```bash
git log --oneline -5
cat results.tsv
```
Prüfe den aktuellen Branch, letzten Commit und bisherige Ergebnisse.

### Schritt 2: Hypothese formulieren
Überlege eine konkrete Änderung, die die Metrik verbessern könnte. Nutze dazu:
- Bisherige Ergebnisse in `results.tsv` (was hat funktioniert, was nicht?)
- Code-Analyse (Bottlenecks, Ineffizienzen, bekannte Patterns)
- Best Practices für den jeweiligen Tech-Stack

### Schritt 3: Änderung implementieren
Bearbeite die Dateien im Scope. Halte Änderungen **fokussiert** — ein Experiment testet eine Hypothese.

### Schritt 4: Git-Commit
```bash
git add -A
git commit -m "experiment: <kurze beschreibung>"
```

### Schritt 5: Messen
Führe das Messkommando aus und leite die Ausgabe in eine Log-Datei:
```bash
<messkommando> > run.log 2>&1
```

Extrahiere die Metrik:
```bash
grep "<metrik-pattern>" run.log
```

### Schritt 6: Ergebnis bewerten

**Falls die Messung fehlschlägt (Crash/Error):**
```bash
tail -n 50 run.log
```
- Wenn es ein einfacher Fehler ist (Typo, fehlender Import): behebe ihn und messe erneut
- Wenn die Idee fundamental kaputt ist: logge als `crash` und gehe weiter

**Falls die Metrik sich verbessert hat:**
- Behalte den Commit (Branch ist jetzt weiter fortgeschritten)
- Logge als `keep` in `results.tsv`

**Falls die Metrik gleich oder schlechter ist:**
- Setze den Commit zurück:
  ```bash
  git reset --hard HEAD~1
  ```
- Logge als `discard` in `results.tsv`

### Schritt 7: Ergebnisse loggen
Füge eine Zeile zu `results.tsv` hinzu (Tab-getrennt):
```
<commit-hash>	<metrik-wert>	<keep|discard|crash>	<was wurde getestet>
```

### Schritt 8: Weiter zu Schritt 1

---

## Strategie-Leitfaden

### Wenn du nicht weiterweißt:
1. **Rückblick**: Analysiere `results.tsv` — welche Richtungen waren vielversprechend?
2. **Kombination**: Versuche, zwei erfolgreiche Änderungen zu kombinieren
3. **Gegenteil**: Probiere das Gegenteil einer gescheiterten Änderung
4. **Radikaler Ansatz**: Manchmal braucht es einen grundlegend anderen Ansatz
5. **Literatur**: Lies Kommentare und Dokumentation im Code für Hinweise
6. **Profiling**: Wenn verfügbar, nutze Profiling-Tools, um Bottlenecks zu finden

### Priorisierung von Experimenten:
1. **Low-Hanging Fruit** zuerst — offensichtliche Ineffizienzen, bekannte Anti-Patterns
2. **Algorithmische Verbesserungen** — bessere Datenstrukturen, effizientere Algorithmen
3. **Konfigurations-Tuning** — Parameter, Cache-Größen, Batch-Sizes
4. **Architektur-Änderungen** — größere Umbauten, andere Patterns

### Timeout:
- Wenn ein Experiment länger als **das Doppelte der normalen Laufzeit** dauert: abbrechen und als Fehlschlag werten
- Wenn nach **5+ Experimenten** keine Verbesserung: Strategie überdenken, radikaleren Ansatz wählen

---

## WICHTIG

**NIEMALS STOPPEN**: Sobald der Loop begonnen hat, pausiere NICHT, um zu fragen, ob du weitermachen sollst. Der Benutzer erwartet, dass du autonom weiterarbeitest, bis du manuell gestoppt wirst. Wenn dir die Ideen ausgehen, denke härter nach — lies den Code erneut, probiere Kombinationen, versuche radikalere Ansätze. Der Loop läuft, bis der Benutzer dich unterbricht.
