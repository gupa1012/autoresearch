# autoresearch – Lern-Handbuch

> Ein R-Paket, mit dem du **alles Mögliche** an R-Programmen, Skripten, Modellen
> und Simulationen automatisch optimieren kannst – von einfachem Grid Search bis
> zu intelligenter Bayesian Optimization und einem adaptiven Research Agent.

---

## Inhaltsverzeichnis

1. [Was ist autoresearch?](#1-was-ist-autoresearch)
2. [Das Grundprinzip in 2 Minuten](#2-das-grundprinzip-in-2-minuten)
3. [Installation](#3-installation)
4. [Schritt für Schritt: Dein erstes Optimierungsproblem](#4-schritt-für-schritt-dein-erstes-optimierungsproblem)
5. [Die drei Parameter-Typen](#5-die-drei-parameter-typen)
6. [Drei Suchstrategien: Grid, Random und Bayesian](#6-drei-suchstrategien-grid-random-und-bayesian)
7. [Intelligente Suche: Bayesian Optimization](#7-intelligente-suche-bayesian-optimization)
8. [Der Research Agent](#8-der-research-agent)
9. [Modelle optimieren mit evaluate_model](#9-modelle-optimieren-mit-evaluate_model)
10. [Beliebige Skripte optimieren mit evaluate_script](#10-beliebige-skripte-optimieren-mit-evaluate_script)
11. [Was kann ich alles mit Custom Scripts optimieren?](#11-was-kann-ich-alles-mit-custom-scripts-optimieren)
12. [Ergebnisse verwalten und visualisieren](#12-ergebnisse-verwalten-und-visualisieren)
13. [Beispiel-Übersicht](#13-beispiel-übersicht)
14. [Architektur des Pakets](#14-architektur-des-pakets)
15. [Tests & Voraussetzungen](#15-tests--voraussetzungen)

---

## 1. Was ist autoresearch?

Stell dir vor, du hast ein R-Skript – zum Beispiel eine Simulation, ein
Vorhersagemodell, oder eine Datenverarbeitungs-Pipeline – und du willst
herausfinden, welche Einstellungen das beste Ergebnis liefern.

**Bisher** hast du das wahrscheinlich so gemacht:
```r
# Manuell ausprobieren...
ergebnis1 <- mein_modell(alpha = 0.1, beta = 5)   # RMSE = 3.2
ergebnis2 <- mein_modell(alpha = 0.5, beta = 10)  # RMSE = 2.8
ergebnis3 <- mein_modell(alpha = 0.3, beta = 7)   # RMSE = 2.5  ← bisher bestes
# ... und so weiter, bis die Geduld ausgeht
```

**Mit autoresearch** sagst du dem Paket:
- Welche Parameter es gibt (z.B. `alpha` zwischen 0.01 und 1.0)
- Was „gut" bedeutet (z.B. niedriger RMSE)
- Wie lange gesucht werden soll

Und es probiert **automatisch hunderte Kombinationen** aus – und das nicht nur
blind, sondern mit **intelligenten Strategien**:

- **Grid Search** – Systematisches Abtasten aller Rasterpunkte
- **Random Search** – Zufällige Stichproben (skaliert gut mit vielen Parametern)
- **Bayesian Optimization** – Lernt aus bisherigen Ergebnissen und konzentriert
  sich auf vielversprechende Regionen (mit Gaussian-Process-Surrogate und
  Expected Improvement)
- **Research Agent** – Führt mehrere Runden durch, engt den Suchraum adaptiv
  ein und wechselt automatisch zwischen Exploration und Exploitation

---

## 2. Das Grundprinzip in 2 Minuten

Jedes Optimierungsproblem in autoresearch hat **drei Teile**:

```
┌─────────────────────┐
│  1. PARAMETER-RAUM  │   ← Was kann verändert werden?
│  (Stellschrauben)   │      z.B. alpha: 0.01–1.0, methode: "lm" oder "glm"
└────────┬────────────┘
         │
         ▼
┌─────────────────────┐
│  2. ZIELFUNKTION    │   ← Wie gut ist eine Kombination?
│  (Score berechnen)  │      Nimmt Parameter, gibt EINE Zahl zurück
└────────┬────────────┘
         │
         ▼
┌──────────────────────────────────┐
│  3. SUCHSTRATEGIE                │   ← Wie werden Kombinationen ausprobiert?
│  (Grid / Random / Bayesian /     │      Grid = alle Punkte; Random = zufällig;
│   Research Agent)                │      Bayesian = lernend; Agent = adaptiv
└──────────────────────────────────┘
```

**Das war's.** Wenn du diese drei Teile definieren kannst, kann autoresearch
dein Problem optimieren.

---

## 3. Installation

```r
# Variante A: Direkt von GitHub
# install.packages("devtools")
devtools::install_github("gupa1012/autoresearch")
```

```bash
# Variante B: Lokal klonen und installieren
git clone https://github.com/gupa1012/autoresearch.git
cd autoresearch
R -e 'devtools::install(".")'
```

```r
# Variante C: Ohne Installation – einfach Quellcode laden
# (funktioniert direkt aus dem Repository-Verzeichnis)
for (f in list.files("R", full.names = TRUE, pattern = "\\.R$")) source(f)
```

---

## 4. Schritt für Schritt: Dein erstes Optimierungsproblem

Ziel: Finde die Werte `x` und `y`, die den Ausdruck `(x - 3)² + (y + 1)²`
minimieren (Antwort: x=3, y=-1).

```r
# Quellcode laden
for (f in list.files("R", full.names = TRUE, pattern = "\\.R$")) source(f)

# --- Schritt 1: Parameter-Raum definieren ---
# "x soll zwischen -10 und 10 liegen, y auch"
space <- create_param_space(
  param_numeric("x", -10, 10),
  param_numeric("y", -10, 10)
)

# --- Schritt 2: Zielfunktion definieren ---
# Bekommt eine Liste mit x und y, gibt eine Zahl zurück.
# autoresearch MINIMIERT diesen Wert (niedrig = gut).
objective <- function(params) {
  (params$x - 3)^2 + (params$y + 1)^2
}

# --- Schritt 3: Optimierung starten ---
result <- optimize_params(
  objective = objective,
  space     = space,
  method    = "random",   # 200 zufällige Kombinationen testen
  n_iter    = 200,
  minimize  = TRUE,
  seed      = 42          # Für Reproduzierbarkeit
)

# --- Schritt 4: Ergebnis ansehen ---
cat("Bester Score:", result$best_score, "\n")
cat("Bestes x:", result$best_params$x, "\n")
cat("Bestes y:", result$best_params$y, "\n")
# → x ≈ 3, y ≈ -1, Score ≈ 0
```

**Merke:** Die Zielfunktion bekommt immer `params` (eine benannte Liste)
und muss immer **eine einzige Zahl** zurückgeben.

---

## 5. Die drei Parameter-Typen

autoresearch kennt drei Arten von Parametern:

### Kontinuierlich (numeric)
Für Dezimalzahlen – z.B. Lernraten, Gewichte, Schwellenwerte.
```r
param_numeric("learning_rate", 0.001, 0.1)
# → Samplet Werte wie 0.0234, 0.0891, 0.0512, ...
```

### Ganzzahlig (integer)
Für ganze Zahlen – z.B. Anzahl Bäume, Schichten, Iterationen.
```r
param_integer("n_trees", 50, 500)
# → Samplet Werte wie 127, 342, 89, 455, ...
```

### Kategoriell (categorical)
Für Auswahlmöglichkeiten – z.B. Algorithmus, Aktivierungsfunktion.
```r
param_categorical("methode", c("lm", "glm", "ridge"))
# → Wählt zufällig "lm", "glm" oder "ridge"
```

### Kombinieren
```r
space <- create_param_space(
  param_numeric("alpha", 0.01, 1.0),
  param_integer("max_iter", 100, 1000),
  param_categorical("solver", c("Newton", "BFGS", "CG"))
)
# → Jede Kombination aus alpha × max_iter × solver ist möglich
```

---

## 6. Drei Suchstrategien: Grid, Random und Bayesian

### Grid Search – Systematisch alle Punkte abtasten

```r
result <- optimize_params(
  objective = objective,
  space     = space,
  method    = "grid",
  n_grid    = 10    # 10 Punkte pro numerischer Achse
)
```

**Vorteile:** Lückenlos, findet garantiert das Optimum im Raster.
**Nachteile:** Explodiert bei vielen Parametern (3 Parameter × 10 Stufen = 1.000 Kombinationen, 5 Parameter × 10 = 100.000).

**Wann verwenden?** Bei wenigen Parametern (1–3) und/oder kategoriellen Parametern.

### Random Search – Zufällig Punkte ausprobieren

```r
result <- optimize_params(
  objective = objective,
  space     = space,
  method    = "random",
  n_iter    = 200   # 200 zufällige Versuche
)
```

**Vorteile:** Skaliert gut mit vielen Parametern, findet oft schnell gute Lösungen.
**Nachteile:** Kann Glück oder Pech haben.

**Wann verwenden?** Bei vielen Parametern (3+) oder wenn die Evaluierung teuer ist.

### Bayesian Optimization – Intelligent suchen

```r
result <- optimize_params(
  objective = objective,
  space     = space,
  method    = "bayesian",
  n_iter    = 50,       # Gesamtzahl Evaluierungen
  n_initial = 8,        # Davon: initiale Zufallspunkte
  kappa     = 2.0       # Exploration-Exploitation-Balance
)
```

**Vorteile:** Lernt aus bisherigen Ergebnissen, konzentriert sich auf vielversprechende Bereiche.
**Nachteile:** Höherer Overhead pro Iteration durch Surrogate-Modell.

**Wann verwenden?** Wenn die Evaluierung teuer ist und du wenige Iterationen hast.

### Zeitbudget – Suche automatisch begrenzen

```r
result <- optimize_params(
  objective   = objective,
  space       = space,
  method      = "random",
  n_iter      = 10000,     # Viele Iterationen anfordern...
  time_budget = 60         # ...aber nach 60 Sekunden aufhören
)
```

---

## 7. Intelligente Suche: Bayesian Optimization

### Was ist Bayesian Optimization?

Während Grid Search und Random Search jeden Punkt unabhängig voneinander
evaluieren, **lernt** Bayesian Optimization aus den bisherigen Ergebnissen und
entscheidet intelligent, wo als nächstes gesucht werden soll.

```
Iteration 1:  Zufälliger Punkt    → Score 4.2
Iteration 2:  Zufälliger Punkt    → Score 7.1
Iteration 3:  Zufälliger Punkt    → Score 2.3
                                        │
                        GP-Surrogate lernt:  "Region A sieht gut aus"
                                        │
                                        ▼
Iteration 4:  EI wählt nächsten   → Score 1.1  ✓ Besser!
Iteration 5:  EI verfeinert       → Score 0.3  ✓ Noch besser!
```

### Wie funktioniert es intern?

autoresearch verwendet ein **Gaussian Process (GP) Surrogate-Modell** mit
RBF-Kernel (Radial Basis Function):

1. **Initiale Punkte**: `n_initial` zufällige Evaluierungen (wie Random Search)
2. **Surrogate-Fit**: Ein GP wird auf alle bisherigen Beobachtungen gefittet
3. **Acquisition Function**: Expected Improvement (EI) bestimmt den nächsten
   vielversprechendsten Punkt: `EI(x) = E[max(0, f_best - f(x))]`
4. **Evaluierung**: Der ausgewählte Punkt wird evaluiert
5. **Wiederholung** ab Schritt 2 bis `n_iter` erreicht

```r
# Bayesian Optimization direkt
result <- optimize_params(
  objective = function(params) (params$x - 3)^2,
  space     = create_param_space(param_numeric("x", -10, 10)),
  method    = "bayesian",
  n_iter    = 30,
  n_initial = 5,      # Erstmal 5 Zufallspunkte
  kappa     = 2.0,    # Hoch = mehr Exploration; Niedrig = mehr Exploitation
  seed      = 42
)
```

### Wann ist Bayesian Optimization besonders nützlich?

| Situation | Empfehlung |
|-----------|-----------|
| Evaluierung dauert Sekunden bis Minuten | ✅ Bayesian |
| Viele Parameter (5+) | ⚠️ Eher Random Search |
| Budget von nur 20–100 Evaluierungen | ✅ Bayesian |
| Schnelle Evaluierung (<0.1s), 1000+ iter | ⚠️ Eher Random/Grid |
| Mehrere lokale Minima bekannt | ✅ Bayesian mit hohem kappa |

---

## 8. Der Research Agent

### Warum ein Research Agent?

Manchmal reicht eine einzige Suchrunde nicht. Der **Research Agent** führt
mehrere Runden durch und **engt den Suchraum adaptiv ein**:

```
Runde 1 (Random Search):
  Suchraum: x ∈ [-10, 10]  ───────────────────────────────────────
  Ergebnis: Vielversprechende Region bei x ≈ 3

Runde 2 (Bayesian Optimization):
  Suchraum: x ∈ [1.5, 4.5]  ─────────────────
  Ergebnis: Noch besser bei x ≈ 3.1

Runde 3 (Bayesian Optimization):
  Suchraum: x ∈ [2.5, 3.7]  ──────────
  Ergebnis: x ≈ 3.02  ✓ Fast perfekt!
```

Bei **Stagnation** (kein Fortschritt über mehrere Runden) erweitert der Agent
den Suchraum wieder auf das Original – um lokale Minima zu entkommen.

### Verwendung

```r
agent_result <- research_agent(
  objective        = meine_funktion,
  space            = mein_parameterraum,
  n_rounds         = 5,                          # Anzahl Runden
  strategies       = c("random", "bayesian"),    # Abwechselnd verwenden
  n_iter_per_round = 50,                         # Iterationen pro Runde
  top_fraction     = 0.10,                       # Top 10% für Zoom-In
  shrink_factor    = 0.5,                        # Suchraum halbieren
  stagnation_rounds = 2,                         # Reset nach 2 schlechten Runden
  minimize         = TRUE,
  seed             = 42,
  verbose          = TRUE
)

# Ergebnisse abrufen
agent_result$best_params          # Beste gefundene Parameter
agent_result$best_score           # Bester Score
agent_result$strategy_log         # Welche Strategie in welcher Runde?
agent_result$improvement_history  # Score-Entwicklung über Runden
agent_result$search_space_history # Wie hat sich der Suchraum verändert?
```

### Parameterraum-Einengung mit narrow_param_space

Du kannst den Zoom-In-Mechanismus auch manuell verwenden:

```r
# Bestes 10% der Ergebnisse extrahieren
df <- summarize_results(result$results)
top10 <- df[order(df$score)[1:ceiling(nrow(df) * 0.1)], ]

# Suchraum einengen
narrow_space <- narrow_param_space(
  space         = original_space,
  best_results  = top10,
  shrink_factor = 0.5   # Neuer Bereich = 50% des alten
)
```

**Für numeric/integer**: Neuer Bereich = Mittelwert der Top-Ergebnisse ±
`shrink_factor × (alter Bereich / 2)`.

**Für categorical**: Nur die Kategorien, die in den Top-Ergebnissen vorkamen,
werden behalten (mindestens 2).

---

## 9. Modelle optimieren mit evaluate_model

Für R-Modelle (`lm`, `glm`, `randomForest`, `nnet`, ...) gibt es eine
Komfortfunktion, die automatisch **Cross-Validation** macht:

```r
# Beispiel: Welche Formel ist die beste für ein lineares Modell?
space <- create_param_space(
  param_categorical("formel", c(
    "mpg ~ wt",
    "mpg ~ wt + hp",
    "mpg ~ wt + hp + qsec",
    "mpg ~ ."
  ))
)

objective <- function(params) {
  evaluate_model(
    data   = mtcars,
    target = "mpg",

    # Diese Funktion baut das Modell:
    build_model = function(train_data, target_name) {
      lm(as.formula(params$formel), data = train_data)
    },

    # Diese Funktion bewertet das Modell:
    score_fn = function(model, test_data, target_name) {
      vorhersagen <- predict(model, test_data)
      sqrt(mean((test_data[[target_name]] - vorhersagen)^2))  # RMSE
    },

    n_folds = 5  # 5-fache Kreuzvalidierung
  )
}

result <- optimize_params(objective, space, method = "grid")
```

### Was passiert bei evaluate_model intern?

```
Daten (z.B. 32 Zeilen mtcars)
    │
    ├── Fold 1: Zeilen 1-6 = Test,  Rest = Training  → Score₁
    ├── Fold 2: Zeilen 7-13 = Test, Rest = Training  → Score₂
    ├── Fold 3: Zeilen 14-19 = Test, Rest = Training → Score₃
    ├── Fold 4: Zeilen 20-26 = Test, Rest = Training → Score₄
    └── Fold 5: Zeilen 27-32 = Test, Rest = Training → Score₅
                                                         │
                                              Ergebnis = Mittelwert(Score₁...₅)
```

---

## 10. Beliebige Skripte optimieren mit evaluate_script

**Das ist die mächtigste Funktion.** Du kannst damit **jedes** R-Skript
optimieren – es muss nicht einmal ein statistisches Modell sein.

### Wie funktioniert es?

1. Du schreibst ein R-Skript, das Parameter als Variablen erwartet
2. Am Ende des Skripts weist du das Ergebnis an `.result` zu
3. `evaluate_script()` injiziert die Parameter und liest `.result` aus

```
┌───────────────────────────────┐
│  evaluate_script(             │
│    "mein_skript.R",           │
│    params = list(             │
│      alpha = 0.5,       ──────┼──→  Im Skript existiert Variable `alpha`
│      beta  = 2.0        ──────┼──→  Im Skript existiert Variable `beta`
│    ),                         │
│    time_budget = 30           │     (Timeout nach 30 Sekunden)
│  )                            │
│                               │
│  Rückgabe: Wert von .result ◄─┼──── .result <- alpha^2 + beta
└───────────────────────────────┘
```

### Minimalbeispiel

**Skript** (`optimiere_mich.R`):
```r
# Diese Variablen werden von autoresearch injiziert:
# - temperatur (numeric)
# - druck     (numeric)

# Berechnung
ertrag <- 100 * exp(-((temperatur - 75)^2) / 500) *
          exp(-((druck - 2.5)^2) / 2)

# Ergebnis zuweisen (PFLICHT!)
.result <- -ertrag   # Negativ, weil wir minimieren und hohen Ertrag wollen
```

**Optimierung:**
```r
for (f in list.files("R", full.names = TRUE, pattern = "\\.R$")) source(f)

space <- create_param_space(
  param_numeric("temperatur", 20, 120),
  param_numeric("druck", 0.5, 5.0)
)

result <- optimize_params(
  objective = function(params) {
    evaluate_script("optimiere_mich.R", params = params)
  },
  space  = space,
  method = "random",
  n_iter = 300
)
```

---

## 11. Was kann ich alles mit Custom Scripts optimieren?

Die Skript-Optimierung ist extrem flexibel. Hier ein Überblick, **was alles
möglich ist** – jedes dieser Szenarien funktioniert:

### A) Simulationsparameter

```r
# Monte-Carlo-Simulation: Finde die besten Parameter für eine Fabrikplanung
# Parameter: n_maschinen, puffer_groesse, schichtlaenge
# .result <- mittlere_durchlaufzeit
```

### B) Datenverarbeitungs-Pipelines

```r
# Finde die besten Vorverarbeitungsschritte:
# Parameter: impute_method ("mean"/"median"/"knn"), scale (TRUE/FALSE),
#            pca_components (2-20), outlier_threshold (1.5-4.0)
# .result <- vorhersagefehler_nach_pipeline
```

### C) Algorithmen-Parameter

```r
# Optimiere einen eigenen Algorithmus:
# Parameter: step_size, momentum, epsilon, max_iterations
# .result <- konvergenzmass
```

### D) Datenanpassung und Kurvenfit

```r
# Finde die besten Parameter für eine Kurvenanpassung:
# Parameter: a, b, c (Koeffizienten einer Funktion f(x) = a*exp(b*x) + c)
# .result <- sum((y_beobachtet - f(x))^2)  ← Summe der Abweichungen
```

### E) Scheduling und Planung

```r
# Optimale Schichtplanung:
# Parameter: schicht1_start, pause_dauer, team_groesse
# .result <- gesamtkosten
```

### F) Finanzmodelle

```r
# Portfolio-Optimierung, Risikobewertung:
# Parameter: gewicht_aktien, gewicht_anleihen, rebalance_frequenz
# .result <- -sharpe_ratio
```

### G) Biologische / Physikalische Modelle

```r
# Parameter einer Differentialgleichung fitten:
# Parameter: wachstumsrate, kapazitaet, anfangswert
# .result <- abweichung_von_messdaten
```

### H) Machine-Learning-Pipelines

```r
# Komplette ML-Pipeline als Skript:
# Parameter: feature_selection_method, n_features, model_type, regularization
# .result <- cross_validated_error
```

### Die Regel

> **Wenn du es in ein R-Skript schreiben kannst und am Ende EINE Zahl
> herauskommt, kann autoresearch es optimieren.**

Detaillierte, lauffähige Beispiele findest du in:
- [`examples/04_custom_script.R`](examples/04_custom_script.R) – Portfolio-Optimierung
- [`examples/06_custom_script_advanced.R`](examples/06_custom_script_advanced.R) – Kurvenfit, Simulation, Pipeline

---

## 12. Ergebnisse verwalten und visualisieren

### Ergebnisse protokollieren

```r
# Automatisch – optimize_params gibt alles zurück:
result <- optimize_params(objective, space, method = "random", n_iter = 100)

result$best_params  # Beste Parameter
result$best_score   # Bester Score
result$results      # Vollständiges Protokoll aller Versuche
```

### Als Tabelle ansehen

```r
df <- summarize_results(result$results)
#   x          y          score      timestamp
# 1 2.945      -1.123     0.023      2025-...
# 2 -3.210     5.670      42.130     2025-...
# ...
```

### Speichern und Laden

```r
save_results(result$results, "meine_ergebnisse.tsv")

# Später:
df <- load_results("meine_ergebnisse.tsv")
```

### Optimierungsverlauf visualisieren

```r
plot_optimization(result$results)
# Zeigt: Punkte = alle Scores, blaue Linie = bester Score bis dahin
```

### Modell-Metriken extrahieren

```r
mod <- lm(mpg ~ wt + hp, data = mtcars)
capture_metrics(mod)
# $r_squared     = 0.8268
# $adj_r_squared = 0.8148
# $sigma         = 2.593
# $aic           = 156.65
# $bic           = 162.84
```

---

## 13. Beispiel-Übersicht

| Nr | Datei | Was wird optimiert? | Suchstrategie |
|----|-------|----|----|
| 01 | [`examples/01_linear_model.R`](examples/01_linear_model.R) | Welche Features und Transformationen für `lm()` | Grid Search |
| 02 | [`examples/02_glm_optimization.R`](examples/02_glm_optimization.R) | Link-Funktion und Features für logistische Regression | Grid Search |
| 03 | [`examples/03_random_forest.R`](examples/03_random_forest.R) | `ntree`, `mtry`, `nodesize` für Random Forest | Random Search |
| 04 | [`examples/04_custom_script.R`](examples/04_custom_script.R) | Beliebiges Skript: Portfolio-Allokation | Random Search |
| 05 | [`examples/05_neural_network.R`](examples/05_neural_network.R) | `size`, `decay`, `maxit` für neuronales Netz mit Zeitbudget | Random Search |
| 06 | [`examples/06_custom_script_advanced.R`](examples/06_custom_script_advanced.R) | Drei Szenarien: Kurvenfit, Simulation, ML-Pipeline | Random Search |
| 07 | [`examples/07_research_agent.R`](examples/07_research_agent.R) | Ackley-Funktion (mehrere lokale Minima) – Agent vs. Random/Bayesian | Research Agent |

Beispiel ausführen:

```bash
cd autoresearch
Rscript examples/01_linear_model.R
```

---

## 14. Architektur des Pakets

```
autoresearch/
│
├── R/                          ← Kern-Code (5 Dateien)
│   ├── optimizer.R             ← Parameterraum + Grid/Random/Bayesian Search
│   │   ├── param_numeric()        Kontinuierliche Parameter definieren
│   │   ├── param_integer()        Ganzzahlige Parameter definieren
│   │   ├── param_categorical()    Kategorielle Parameter definieren
│   │   ├── create_param_space()   Parameter zu einem Raum kombinieren
│   │   ├── optimize_params()      ★ Hauptfunktion: Optimierung starten
│   │   ├── grid_search()          Alle Rasterpunkte durchgehen
│   │   ├── random_search()        Zufällige Punkte ausprobieren
│   │   ├── bayesian_search()      GP-Surrogate + Expected Improvement
│   │   └── narrow_param_space()   Suchraum auf beste Region einengen
│   │
│   ├── agent.R                 ← Research Agent
│   │   └── research_agent()       Adaptiver multi-Runden-Agent
│   │
│   ├── evaluate.R              ← Evaluation (Modelle & Skripte)
│   │   ├── evaluate_model()       Modell mit Cross-Validation bewerten
│   │   └── evaluate_script()      Beliebiges R-Skript ausführen & Score lesen
│   │
│   ├── results.R               ← Ergebnis-Verwaltung
│   │   ├── new_results_log()      Neues Protokoll erstellen
│   │   ├── add_result()           Ergebnis hinzufügen
│   │   ├── best_result()          Bestes Ergebnis finden
│   │   ├── summarize_results()    Alle Ergebnisse als Tabelle
│   │   ├── save_results()         In TSV-Datei speichern
│   │   ├── load_results()         Aus TSV-Datei laden
│   │   └── plot_optimization()    Verlauf visualisieren
│   │
│   └── utils.R                 ← Hilfsfunktionen
│       ├── with_time_budget()     Ausdruck mit Zeitlimit ausführen
│       ├── set_seed_safely()      Seed setzen (akzeptiert NULL)
│       └── capture_metrics()      R²,AIC,BIC aus Modellobjekten extrahieren
│
├── examples/                   ← 7 vollständige, lauffähige Beispiele
├── tests/test_all.R            ← Automatisierte Tests (65 Tests)
├── DESCRIPTION                 ← Paket-Metadaten
├── NAMESPACE                   ← Exportierte Funktionen
└── LICENSE                     ← MIT-Lizenz
```

### Datenfluss bei einer Optimierung

```
Parameter-Raum ──→ Suchstrategie ──→ Zielfunktion ──→ Score
      │                  │                 │              │
      │      (Grid/Random/Bayesian/Agent) (dein Code!)  (eine Zahl)
      │                  │                 │              │
      │                  ▼                 │              ▼
      │           params = list(           │        results_log
      │             alpha = 0.3,           │         ├── Versuch 1: score = 4.2
      │             beta  = 7             │         ├── Versuch 2: score = 2.1
      │           )                        │         ├── Versuch 3: score = 5.7
      │                  │                 │         └── ...
      │                  └────→ Score ←────┘
      │                                               │
      └──────────────── Nächster Versuch ◄─────────────┘
```

---

## 15. Tests & Voraussetzungen

### Voraussetzungen

- **R >= 4.0.0**
- Empfohlen: `randomForest`, `nnet` (für Beispiele 3, 5 und 6)

### Tests ausführen

```bash
cd autoresearch
Rscript tests/test_all.R
```

Die Tests prüfen:
- Parameter-Definitionen und Kombinationen
- Grid-Aufbau und Random-Sampling
- Ergebnis-Protokollierung und Speichern/Laden
- Cross-Validation und Skript-Evaluation
- Zeitbudgets und Fehlerbehandlung
- End-to-End-Optimierung mit allen drei Suchstrategien (Grid, Random, Bayesian)
- `narrow_param_space()`: Parameterraum-Einengung
- `research_agent()`: Adaptiver multi-Runden-Agent mit Stagnationserkennung

---

## Lizenz

MIT – siehe [LICENSE](LICENSE)
