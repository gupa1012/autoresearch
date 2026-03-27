# AutoResearch Skills für VS Code Copilot

## Was ist das?

Dieses Verzeichnis enthält **Skills** (Anweisungsdateien), die den autonomen Optimierungsansatz von AutoResearch für **beliebige Softwareprojekte** verallgemeinern. Anstatt ein spezielles Framework zu installieren, nutzt du einfach **VS Code Copilot** (Agent Mode) mit diesen Skill-Dateien als Kontext.

### Das Prinzip

AutoResearch zeigt: Man braucht kein komplexes Agent-Framework. Die gesamte Orchestrierung läuft über **gut strukturierte Markdown-Anweisungen** + **Shell-Zugang** + **Git-basierte Versionierung**. Dieses Muster lässt sich auf jedes Softwareprojekt übertragen.

## Verfügbare Skills

| Skill | Datei | Beschreibung |
|-------|-------|--------------|
| 🔄 **Autonome Optimierung** | [`autonomous-optimization.md`](autonomous-optimization.md) | Der Kern-Loop: Messen → Ändern → Testen → Behalten/Verwerfen. Funktioniert für jedes Projekt. |
| 🧠 **ML-Training** | [`ml-training-optimization.md`](ml-training-optimization.md) | Optimierung von ML-Trainingscode (Architektur, Hyperparameter, Optimizer). |
| 🌐 **Web-Performance** | [`web-performance.md`](web-performance.md) | Ladezeiten, Bundle-Größe, Core Web Vitals, Rendering-Performance. |
| 🏗️ **Code-Qualität** | [`code-quality.md`](code-quality.md) | Refactoring, Komplexitätsreduktion, Testabdeckung, Wartbarkeit. |
| ⚡ **API-Performance** | [`api-performance.md`](api-performance.md) | Antwortzeiten, Durchsatz, Datenbankabfragen, Caching. |
| 🔧 **Build-Pipeline** | [`build-pipeline.md`](build-pipeline.md) | Build-Zeiten, CI/CD-Dauer, Dependency-Management. |

## Schnellstart

### Voraussetzungen

- **VS Code** mit **GitHub Copilot** (Agent Mode / Chat)
- **Git** (für Versionierung der Experimente)
- Dein Projekt mit existierenden Tests/Benchmarks

### Schritt 1: Skill-Datei auswählen

Wähle den passenden Skill für dein Optimierungsziel. Du kannst auch mehrere kombinieren.

### Schritt 2: Copilot Chat öffnen

Öffne den Copilot Chat in VS Code (`Ctrl+Shift+I` oder über das Copilot-Icon).

### Schritt 3: Skill-Datei als Kontext einfügen

Nutze eine der folgenden Methoden:

**Methode A — Datei als Kontext anhängen:**
1. Öffne den Copilot Chat
2. Klicke auf das `+` Symbol oder nutze `#file`
3. Wähle die Skill-Datei aus (z.B. `skills/web-performance.md`)
4. Schreibe: *"Führe den Optimierungs-Loop aus dieser Skill-Datei durch"*

**Methode B — In Copilot-Instructions einbinden:**
1. Erstelle/bearbeite `.github/copilot-instructions.md` in deinem Projekt
2. Kopiere den Inhalt des gewünschten Skills hinein
3. Copilot nutzt diese Anweisungen automatisch bei jeder Interaktion

**Methode C — Prompt Datei (.prompt.md) erstellen:**
1. Erstelle eine `.prompt.md` Datei (z.B. `optimize.prompt.md`)
2. Referenziere den Skill und dein Projekt darin:
```markdown
---
mode: agent
description: "Autonome Performance-Optimierung"
tools: ["terminal", "editFiles"]
---

Lies die Datei `skills/web-performance.md` und führe den darin beschriebenen
Optimierungs-Loop für dieses Projekt durch.

Kontext:
- Hauptmetrik: Lighthouse Performance Score
- Testkommando: `npm run lighthouse`
- Zu optimierende Dateien: `src/` Verzeichnis
```

### Schritt 4: Copilot arbeiten lassen

Copilot wird:
1. Die Baseline messen
2. Änderungen vorschlagen und umsetzen
3. Ergebnisse messen
4. Behalten oder verwerfen
5. Zum nächsten Experiment weitergehen

## Tipps

### Git-Workflow nutzen

Erstelle immer einen eigenen Branch für Optimierungsexperimente:
```bash
git checkout -b optimize/<datum>-<ziel>
```

### Ergebnisse tracken

Jeder Skill nutzt eine `results.tsv` Datei zum Tracking. Füge sie zu `.gitignore` hinzu:
```bash
echo "results.tsv" >> .gitignore
```

### Mehrere Skills kombinieren

Du kannst Skills kombinieren, indem du mehrere Dateien als Kontext anhängst:
```
#file:skills/autonomous-optimization.md
#file:skills/web-performance.md

Optimiere die Web-Performance meiner React-App. Nutze den autonomen Loop.
```

### Eigene Skills erstellen

Nutze `autonomous-optimization.md` als Template und passe es an:
1. Definiere deine **Metrik** (was wird gemessen?)
2. Definiere dein **Messkommando** (wie wird gemessen?)
3. Definiere den **Scope** (welche Dateien dürfen geändert werden?)
4. Definiere **Constraints** (was darf nicht geändert werden?)

## FAQ

**Q: Brauche ich zusätzliche Software?**
A: Nein. Nur VS Code + GitHub Copilot + Git + deine existierenden Projekt-Tools.

**Q: Funktioniert das nur für ML-Projekte?**
A: Nein. Das Muster funktioniert für jedes Projekt, das eine messbare Metrik hat: Performance-Benchmarks, Test-Coverage, Bundle-Größe, Build-Zeiten, Codequalitäts-Scores, etc.

**Q: Wie lange kann Copilot autonom arbeiten?**
A: In Agent Mode kann Copilot iterativ arbeiten. Bei langen Sessions kann es sein, dass du gelegentlich "Weiter" bestätigen musst. Der Skill ist so geschrieben, dass Copilot nach jeder Pause nahtlos weitermachen kann.

**Q: Was ist der Vorteil gegenüber dem Original-AutoResearch?**
A: Das Original braucht eine GPU und `uv` als Package-Manager. Die Skills hier funktionieren mit jedem Projekt, jedem Tech-Stack, und brauchen nur VS Code + Copilot. Das Prinzip ist dasselbe — nur verallgemeinert.

**Q: Warum sind die Skills auf Deutsch?**
A: Die Skills sind auf Deutsch verfasst, da sie für deutschsprachige Nutzer erstellt wurden. Die Befehle und Code-Beispiele sind universell (Englisch). Copilot versteht die Anweisungen in jeder Sprache — du kannst die Skills bei Bedarf übersetzen oder Copilot bitten, sie in einer anderen Sprache zu interpretieren.
