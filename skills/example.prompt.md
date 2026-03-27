---
mode: agent
description: "Autonome Projekt-Optimierung mit Skills"
tools: ["terminal", "editFiles"]
---

# Beispiel: So nutzt du die Skills mit VS Code Copilot

> **ANLEITUNG**: Kopiere diese Datei in dein Projekt und passe sie an.
> Dann öffne sie in VS Code und starte den Copilot Agent Mode.

## Anpassbare Felder

Ersetze die Platzhalter unten mit deinen Projekt-Details:

- **Ziel-Metrik**: [z.B. "Bundle-Größe in KB (gzip)", "Antwortzeit in ms", "val_bpb"]
- **Messkommando**: [z.B. "npm run build 2>&1 | grep gzip", "curl -w '%{time_total}' ..."]
- **Scope**: [z.B. "src/ Verzeichnis", "train.py", "api/ Verzeichnis"]
- **Tabu**: [z.B. "Tests nicht ändern", "prepare.py nicht ändern", "package.json nicht ändern"]
- **Skill**: [Wähle: autonomous-optimization, ml-training-optimization, web-performance, code-quality, api-performance, build-pipeline]

---

## Auftrag

Lies die Datei `skills/autonomous-optimization.md` und den spezialisierten Skill `skills/[DEIN-SKILL].md`.

Führe dann den darin beschriebenen autonomen Optimierungs-Loop durch:

1. Erstelle einen Branch `optimize/[DEIN-ZIEL]`
2. Messe die Baseline
3. Starte den Experiment-Loop
4. Dokumentiere alle Ergebnisse in `results.tsv`

### Projekt-spezifischer Kontext

[Beschreibe hier dein Projekt, was optimiert werden soll, und was besonders wichtig ist.]
