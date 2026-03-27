# GitHub Copilot Instructions — AutoResearch Skills

Dieses Repository enthält **Skills** (Anweisungsdateien) für den autonomen Optimierungs-Loop.

## Skills-Verzeichnis

Die Skills befinden sich in `skills/`. Jeder Skill ist eine eigenständige Anweisungsdatei, die den Copilot-Agenten instruiert, autonom Experimente durchzuführen.

### Verfügbare Skills

- `skills/autonomous-optimization.md` — **Kern-Skill**: Der universelle Optimierungs-Loop (Messen → Ändern → Testen → Behalten/Verwerfen). Wird von allen anderen Skills als Basis verwendet.
- `skills/ml-training-optimization.md` — ML-Modell-Training optimieren (Architektur, Hyperparameter, Optimizer)
- `skills/web-performance.md` — Web-App-Performance optimieren (Bundle-Größe, Ladezeiten, Core Web Vitals)
- `skills/code-quality.md` — Code-Qualität verbessern (Lint-Fehler, Typen, Testabdeckung, Komplexität)
- `skills/api-performance.md` — API-/Backend-Performance optimieren (Antwortzeiten, Durchsatz, DB-Queries)
- `skills/build-pipeline.md` — Build- und CI/CD-Pipeline beschleunigen (Build-Zeiten, Test-Laufzeiten)

### Wie du die Skills nutzt

1. Öffne den Copilot Chat in VS Code
2. Referenziere einen Skill als Kontext: `#file:skills/web-performance.md`
3. Gib den Auftrag: *"Führe den Optimierungs-Loop aus diesem Skill für mein Projekt durch"*

Alternativ: Erstelle eine `.prompt.md`-Datei mit dem Skill als Referenz.

### Konventionen

- **Experiment-Branch**: Immer auf einem dedizierten Branch arbeiten (`optimize/<ziel>`)
- **Results-Tracking**: Ergebnisse in `results.tsv` loggen (Tab-getrennt, nicht committen)
- **Git-basiert**: Jedes Experiment = ein Commit. Behalten oder zurücksetzen.
- **Autonom**: Nach dem Setup arbeitet der Agent eigenständig weiter bis er gestoppt wird.
