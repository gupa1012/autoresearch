# ============================================================================
# Beispiel 3: Random Forest Hyperparameter-Tuning
# ============================================================================
# Optimiert ntree, mtry und nodesize eines Random Forest auf dem
# iris-Datensatz mit Random Search.
# ============================================================================

# Paket laden
for (f in list.files("R", full.names = TRUE, pattern = "\\.R$")) source(f)

# Prüfe ob randomForest installiert ist
if (!requireNamespace("randomForest", quietly = TRUE)) {
  message("Installiere randomForest ...")
  install.packages("randomForest", repos = "https://cloud.r-project.org")
}
library(randomForest)

# --- Daten -------------------------------------------------------------------
data(iris)
cat("Datensatz: iris (", nrow(iris), "Beobachtungen, 3 Klassen)\n\n")

# --- Parameter-Raum ---------------------------------------------------------
space <- create_param_space(
  param_integer("ntree", 50, 500),
  param_integer("mtry", 1, 4),
  param_integer("nodesize", 1, 20)
)

# --- Zielfunktion: Klassifikationsfehler minimieren --------------------------
objective <- function(params) {
  evaluate_model(
    data   = iris,
    target = "Species",
    build_model = function(train, tgt) {
      randomForest(
        x       = train[, names(train) != tgt],
        y       = train[[tgt]],
        ntree   = params$ntree,
        mtry    = params$mtry,
        nodesize = params$nodesize
      )
    },
    score_fn = function(mod, test, tgt) {
      preds <- predict(mod, test[, names(test) != tgt])
      1 - mean(preds == test[[tgt]])   # Fehlerrate
    },
    n_folds = 5
  )
}

# --- Random Search -----------------------------------------------------------
cat("=== Random Search: Random Forest Tuning (100 Iterationen) ===\n")
result <- optimize_params(
  objective = objective,
  space     = space,
  method    = "random",
  n_iter    = 100,
  minimize  = TRUE,
  seed      = 123,
  verbose   = TRUE
)

cat("\n--- Bestes Ergebnis ---\n")
cat("ntree:    ", result$best_params$ntree, "\n")
cat("mtry:     ", result$best_params$mtry, "\n")
cat("nodesize: ", result$best_params$nodesize, "\n")
cat("Fehlerrate:", round(result$best_score, 4), "\n")

# --- Ergebnisse visualisieren ------------------------------------------------
cat("\n--- Top 10 Konfigurationen ---\n")
df <- summarize_results(result$results)
df <- df[order(df$score), ]
print(head(df[, c("ntree", "mtry", "nodesize", "score")], 10))

# --- Plot --------------------------------------------------------------------
if (interactive()) {
  plot_optimization(result$results, minimize = TRUE,
                    main = "Random Forest Hyperparameter-Tuning")
}

# --- Finales Modell ----------------------------------------------------------
cat("\n--- Finales Modell ---\n")
final <- randomForest(
  x        = iris[, 1:4],
  y        = iris$Species,
  ntree    = result$best_params$ntree,
  mtry     = result$best_params$mtry,
  nodesize = result$best_params$nodesize
)
print(final)
