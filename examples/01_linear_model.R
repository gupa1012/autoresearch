# ============================================================================
# Beispiel 1: Lineares Modell optimieren
# ============================================================================
# Findet die beste Kombination von Prädiktoren für ein lineares Modell
# auf dem mtcars-Datensatz.
# ============================================================================

# Paket laden (alle R-Dateien aus dem R/ Verzeichnis)
for (f in list.files("R", full.names = TRUE, pattern = "\\.R$")) source(f)

# --- Daten vorbereiten -------------------------------------------------------
data(mtcars)
cat("Datensatz: mtcars (", nrow(mtcars), "Beobachtungen )\n")

# --- Ziel: RMSE minimieren über Feature-Auswahl -----------------------------

# Wir definieren verschiedene Feature-Kombinationen als Parameter
space <- create_param_space(
  param_categorical("formula", c(
    "mpg ~ wt",
    "mpg ~ wt + hp",
    "mpg ~ wt + hp + qsec",
    "mpg ~ wt + hp + disp",
    "mpg ~ wt + hp + qsec + am",
    "mpg ~ wt + hp + disp + qsec + am",
    "mpg ~ ."
  )),
  param_categorical("transform_y", c("none", "log"))
)

# Zielfunktion: Cross-validated RMSE
objective <- function(params) {
  evaluate_model(
    data   = mtcars,
    target = "mpg",
    build_model = function(train, tgt) {
      if (params$transform_y == "log") {
        train$mpg <- log(train$mpg)
      }
      lm(as.formula(params$formula), data = train)
    },
    score_fn = function(mod, test, tgt) {
      preds <- predict(mod, test)
      if (params$transform_y == "log") preds <- exp(preds)
      sqrt(mean((test[[tgt]] - preds)^2))
    },
    n_folds = 5
  )
}

# --- Grid Search über alle Kombinationen ------------------------------------
cat("\n=== Grid Search ===\n")
result <- optimize_params(
  objective = objective,
  space     = space,
  method    = "grid",
  minimize  = TRUE,
  verbose   = TRUE
)

cat("\n--- Bestes Ergebnis ---\n")
cat("Formel:        ", result$best_params$formula, "\n")
cat("Transformation:", result$best_params$transform_y, "\n")
cat("RMSE:          ", round(result$best_score, 4), "\n")

# --- Alle Ergebnisse --------------------------------------------------------
cat("\n--- Alle Ergebnisse ---\n")
df <- summarize_results(result$results)
df <- df[order(df$score), ]
print(df[, c("formula", "transform_y", "score")])

# --- Finales Modell mit besten Parametern fitten ----------------------------
cat("\n--- Finales Modell ---\n")
final_model <- lm(as.formula(result$best_params$formula), data = mtcars)
print(summary(final_model))
cat("\nModell-Metriken:\n")
print(capture_metrics(final_model))
