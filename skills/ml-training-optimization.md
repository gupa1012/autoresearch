# ML-Training Optimierung

> **Skill für ML/Deep-Learning-Projekte** — Optimiert Modellarchitektur, Hyperparameter und Trainingscode.
> Basiert auf dem AutoResearch-Pattern von Andrej Karpathy.

## Voraussetzungen

- Python-Projekt mit existierendem Trainingsskript
- GPU oder CPU für Training verfügbar
- Messbare Metrik (Loss, Accuracy, val_bpb, F1, etc.)

## Setup

1. **Projekt-Dateien lesen**: Lies alle relevanten Dateien:
   - Trainings-Skript (z.B. `train.py`)
   - Modell-Definition (z.B. `model.py`)
   - Konfiguration (z.B. `config.yaml`, `pyproject.toml`)
   - Daten-Pipeline (z.B. `data.py`, `dataset.py`)
   - README für Kontext

2. **Scope definieren**:
   - **Editierbar**: Modell-Architektur, Optimizer, Hyperparameter, Trainings-Loop, Batch-Größe, Scheduling
   - **Nicht editierbar**: Daten-Pipeline, Evaluierungs-Metrik, Datenformat

3. **Messkommando festlegen**: Beispiele:
   ```bash
   # PyTorch Training mit fixer Dauer
   python train.py > run.log 2>&1
   grep "val_loss:" run.log

   # Kurztraining für schnelle Iteration
   python train.py --epochs 5 --quick > run.log 2>&1
   grep "best_val" run.log

   # Mit uv (wie AutoResearch)
   uv run train.py > run.log 2>&1
   grep "^val_bpb:" run.log
   ```

4. **Branch und Tracking**:
   ```bash
   git checkout -b optimize/ml-<datum>
   ```
   Erstelle `results.tsv`:
   ```
   commit	metrik	vram_gb	status	beschreibung
   ```

## Experiment-Strategie

### Phase 1: Baseline und Diagnose (Experiment 1-3)
1. **Baseline messen**: Trainingsskript unverändert laufen lassen
2. **Profiling**: Falls verfügbar, GPU-Auslastung und Bottlenecks identifizieren
3. **Sanity Check**: Sind offensichtliche Probleme sichtbar? (zu kleine Batch-Size, schlechter LR, etc.)

### Phase 2: Quick Wins (Experiment 4-10)
Versuche zuerst Änderungen mit hoher Erfolgswahrscheinlichkeit:
- **Learning Rate Tuning**: ±2x, ±5x vom aktuellen Wert
- **Batch Size anpassen**: Größere Batches wenn VRAM es erlaubt
- **Weight Decay anpassen**: 0.01 → 0.1 oder umgekehrt
- **LR Schedule**: Cosine Annealing falls noch nicht genutzt
- **Warmup** hinzufügen/anpassen
- **Gradient Clipping** aktivieren/deaktivieren
- **Mixed Precision** (bfloat16/float16) falls noch nicht aktiv

### Phase 3: Architektur (Experiment 11-20)
- **Modell-Größe skalieren**: Breite vs. Tiefe
- **Normalisierung**: LayerNorm → RMSNorm, Pre-Norm vs. Post-Norm
- **Aktivierungsfunktionen**: ReLU → GELU → SwiGLU → ReLU²
- **Attention-Varianten**: Standard → Flash Attention, Multi-Head → Multi-Query/Grouped-Query
- **Positional Encoding**: Sinusoidal → Rotary (RoPE) → ALiBi
- **Residual Connections**: Standard → Gated Residuals
- **Dropout**: Hinzufügen, entfernen, oder anpassen

### Phase 4: Fortgeschritten (Experiment 21+)
- **Optimizer wechseln**: Adam → AdamW → Muon → SOAP → Lion
- **Gradient Accumulation** für effektive größere Batches
- **Token Packing** für effizientere Sequenz-Nutzung
- **Kompilierung**: `torch.compile()` für Speedup
- **Architektur-Fusion**: Ideen aus verschiedenen Papers kombinieren
- **Regularisierung**: Label Smoothing, Stochastic Depth, Mixup

## Was du bei jedem Experiment beachten musst

### Vor dem Run:
- Ist die Änderung fokussiert? (Eine Hypothese pro Experiment)
- Compiled der Code? Kurzer Syntax-Check: `python -c "import train"` (oder ähnlich)

### Nach dem Run:
- **Metrik extrahieren**: `grep "<pattern>" run.log`
- **VRAM prüfen**: `grep "peak_vram\|memory" run.log`
- **Auf Warnungen achten**: Gibt es NaN-Werte? Gradient Explosions?
- **Trainings-Stabilität**: Ist die Loss-Kurve stabil oder oszilliert sie?

### Entscheidung:
- **Metrik verbessert** + **stabil**: → `keep`
- **Metrik verbessert** + **instabil/hoher VRAM**: → mit Vorsicht behalten, im nächsten Experiment stabilisieren
- **Metrik gleich/schlechter**: → `discard` (git reset)
- **Crash/NaN**: → analysieren, eventuell LR zu hoch oder numerisches Problem

## Logging-Format

```
commit	metrik	vram_gb	status	beschreibung
a1b2c3d	0.9979	44.0	keep	baseline
b2c3d4e	0.9932	44.2	keep	LR von 0.03 auf 0.04 erhöht
c3d4e5f	1.0050	44.0	discard	GeLU statt ReLU²
d4e5f6g	0.0000	0.0	crash	Modellbreite verdoppelt (OOM)
```

## Hinweise

- **VRAM ist ein Soft-Constraint**: Etwas mehr VRAM ist ok für deutliche Metrik-Verbesserung
- **Trainingszeit ist fix**: Wenn ein fixes Zeitbudget definiert ist, nutze es optimal (größeres Modell = weniger Steps, aber bessere Qualität pro Step — finde die Balance)
- **Einfachheit zählt**: Weniger Code bei gleicher Performance ist ein Gewinn
- **Numerische Stabilität**: Bei float16/bfloat16 auf Overflow/Underflow achten

---

*Dieser Skill basiert auf dem [autonomous-optimization.md](autonomous-optimization.md) Kern-Loop. Lies diesen zuerst für das grundlegende Experiment-Protokoll.*
