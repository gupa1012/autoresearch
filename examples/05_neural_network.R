# ============================================================================
# Beispiel 5: Neuronales Netz optimieren mit nnet
# ============================================================================
# Optimiert size (Anzahl Hidden Units) und decay (Regularisierung) eines
# einfachen neuronalen Netzes für Regression.
# ============================================================================

# Paket laden
for (f in list.files("R", full.names = TRUE, pattern = "\\.R$")) source(f)

# Prüfe ob nnet installiert ist
if (!requireNamespace("nnet", quietly = TRUE)) {
  message("Installiere nnet ...")
  install.packages("nnet", repos = "https://cloud.r-project.org")
}
library(nnet)

# --- Daten -------------------------------------------------------------------
data(Boston, package = "MASS")
if (!exists("Boston")) {
  # Falls MASS nicht verfügbar, verwende mtcars als Fallback
  cat("MASS::Boston nicht verfügbar, verwende mtcars\n")
  dataset <- mtcars
  target  <- "mpg"
} else {
  dataset <- Boston
  target  <- "medv"
}
cat("Datensatz:", nrow(dataset), "Beobachtungen\n")
cat("Ziel:     ", target, "\n\n")

# --- Daten normalisieren (wichtig für nnet) ----------------------------------
normalize <- function(x) {
  rng <- range(x, na.rm = TRUE)
  if (rng[1] == rng[2]) return(rep(0, length(x)))
  (x - rng[1]) / (rng[2] - rng[1])
}

num_cols <- names(dataset)[vapply(dataset, is.numeric, logical(1))]
dataset_norm <- as.data.frame(lapply(dataset[num_cols], normalize))

# --- Parameter-Raum ---------------------------------------------------------
space <- create_param_space(
  param_integer("size", 2, 30),
  param_numeric("decay", 0.0001, 0.5),
  param_integer("maxit", 100, 1000)
)

# --- Zielfunktion: RMSE minimieren -------------------------------------------
objective <- function(params) {
  evaluate_model(
    data   = dataset_norm,
    target = target,
    build_model = function(train, tgt) {
      formula <- as.formula(paste(tgt, "~ ."))
      nnet(formula, data = train,
           size    = params$size,
           decay   = params$decay,
           maxit   = params$maxit,
           linout  = TRUE,       # Regression
           trace   = FALSE)
    },
    score_fn = function(mod, test, tgt) {
      preds <- as.numeric(predict(mod, test))
      sqrt(mean((test[[tgt]] - preds)^2))
    },
    n_folds = 5
  )
}

# --- Random Search mit Zeitbudget --------------------------------------------
cat("=== Random Search: Neuronales Netz Tuning ===\n")
cat("(Zeitbudget: 60 Sekunden)\n\n")

result <- optimize_params(
  objective   = objective,
  space       = space,
  method      = "random",
  n_iter      = 500,      # Viele Iterationen, aber begrenzt durch Zeit
  minimize    = TRUE,
  time_budget = 60,
  seed        = 42,
  verbose     = TRUE
)

# --- Ergebnisse --------------------------------------------------------------
cat("\n--- Bestes Ergebnis ---\n")
cat("Hidden Units:", result$best_params$size, "\n")
cat("Decay:       ", round(result$best_params$decay, 6), "\n")
cat("Max. Iter.:  ", result$best_params$maxit, "\n")
cat("RMSE:        ", round(result$best_score, 6), "\n")

# --- Top-10 ---
cat("\n--- Top 10 Konfigurationen ---\n")
df <- summarize_results(result$results)
df <- df[order(df$score), ]
print(head(df[, c("size", "decay", "maxit", "score")], 10))

# --- Ergebnisse speichern ----------------------------------------------------
save_results(result$results, path = tempfile("nnet_results_", fileext = ".tsv"))

# --- Plot (wenn interaktiv) --------------------------------------------------
if (interactive()) {
  plot_optimization(result$results, minimize = TRUE,
                    main = "Neuronales Netz: Hyperparameter-Tuning")
}
