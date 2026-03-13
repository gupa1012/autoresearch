# autoresearch

**Autonomes Optimierungs-Framework für R Programme, Skripte und Modelle**

`autoresearch` ist ein flexibles R-Paket, mit dem beliebige R-Programme, Skripte
und statistische Modelle automatisch optimiert werden können. Es unterstützt
Hyperparameter-Tuning, Modellauswahl und benutzerdefinierte Zielfunktionen – mit
vollständiger Ergebnis-Protokollierung.

## Features

- **Grid Search** und **Random Search** über beliebige Parameter-Räume
- Optimierung von **linearen Modellen, GLMs, Random Forests, neuronalen Netzen** und jedem anderen R-Modell
- **Externe Skript-Optimierung** – beliebige `.R`-Skripte parametrisch tunen
- **Cross-Validation** eingebaut
- **Zeitbudget** – Suche automatisch begrenzen
- **Ergebnis-Tracking** mit Speichern, Laden und Visualisierung
- Saubere, nachvollziehbare **Beispiele** für jeden Anwendungsfall

## Installation

```r
# Aus dem Repository installieren
# install.packages("devtools")
devtools::install_github("gupa1012/autoresearch")
```

Oder lokal:

```bash
git clone https://github.com/gupa1012/autoresearch.git
cd autoresearch
R -e 'devtools::install(".")'
```

## Schnellstart

```r
library(autoresearch)

# 1. Parameter-Raum definieren
space <- create_param_space(
  param_numeric("learning_rate", 0.001, 0.1),
  param_integer("n_trees", 50, 500),
  param_categorical("method", c("lm", "glm"))
)

# 2. Zielfunktion definieren (Score = niedrig ist besser)
objective <- function(params) {
  # ... Modell trainieren, evaluieren ...
  # Gibt einen numerischen Score zurück
  score
}

# 3. Optimierung starten
result <- optimize_params(
  objective = objective,
  space     = space,
  method    = "random",  # oder "grid"
  n_iter    = 100,
  minimize  = TRUE
)

# 4. Ergebnisse ansehen
cat("Bester Score:", result$best_score, "\n")
cat("Beste Parameter:", "\n")
str(result$best_params)
```

## Beispiele

| Beispiel | Datei | Beschreibung |
|----------|-------|--------------|
| Lineares Modell | [`examples/01_linear_model.R`](examples/01_linear_model.R) | Feature-Auswahl und Transformation für `lm()` |
| GLM Optimierung | [`examples/02_glm_optimization.R`](examples/02_glm_optimization.R) | Link-Funktion und Features für logistische Regression |
| Random Forest | [`examples/03_random_forest.R`](examples/03_random_forest.R) | `ntree`, `mtry`, `nodesize` Tuning |
| Skript-Optimierung | [`examples/04_custom_script.R`](examples/04_custom_script.R) | Beliebiges R-Skript parametrisch optimieren |
| Neuronales Netz | [`examples/05_neural_network.R`](examples/05_neural_network.R) | `nnet` Hyperparameter mit Zeitbudget |

Beispiel ausführen:

```bash
cd autoresearch
Rscript examples/01_linear_model.R
```

## Kernfunktionen

### Parameter-Definition

```r
param_numeric("lr", 0.001, 0.1)       # Kontinuierlich
param_integer("epochs", 10, 100)       # Ganzzahlig
param_categorical("act", c("relu", "tanh"))  # Kategoriell
```

### Optimierung

```r
optimize_params(objective, space, method = "random", n_iter = 100)
optimize_params(objective, space, method = "grid", n_grid = 10)
```

### Modell-Evaluation mit Cross-Validation

```r
evaluate_model(
  data = mtcars, target = "mpg",
  build_model = function(train, tgt) lm(mpg ~ ., train),
  score_fn = function(mod, test, tgt) sqrt(mean((test$mpg - predict(mod, test))^2))
)
```

### Skript-Optimierung

```r
# Skript enthält .result <- <berechnung mit injizierten Parametern>
evaluate_script("mein_skript.R", params = list(alpha = 0.5, beta = 2))
```

### Ergebnis-Verwaltung

```r
log <- new_results_log()
log <- add_result(log, params = list(x = 1), score = 0.5)
save_results(log, "ergebnisse.tsv")
plot_optimization(log)
```

## Architektur

```
autoresearch/
├── R/
│   ├── optimizer.R    # Kern-Optimierer (Grid Search, Random Search)
│   ├── evaluate.R     # Modell- und Skript-Evaluation
│   ├── results.R      # Ergebnis-Tracking und Visualisierung
│   └── utils.R        # Hilfsfunktionen (Zeitbudget, Metriken)
├── examples/          # 5 vollständige Beispiele
├── tests/             # Automatisierte Tests
├── DESCRIPTION        # Paket-Metadaten
└── NAMESPACE          # Exportierte Funktionen
```

## Voraussetzungen

- **R >= 4.0.0**
- Empfohlen: `randomForest`, `nnet` (für die Beispiele 3 und 5)

## Tests ausführen

```bash
cd autoresearch
Rscript tests/test_all.R
```

## Lizenz

MIT – siehe [LICENSE](LICENSE)
