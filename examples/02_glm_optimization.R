# ============================================================================
# Beispiel 2: Generalisiertes Lineares Modell (GLM) optimieren
# ============================================================================
# Optimiert ein GLM für binäre Klassifikation (logistische Regression)
# mit verschiedenen Link-Funktionen und Feature-Sets.
# ============================================================================

# Paket laden
for (f in list.files("R", full.names = TRUE, pattern = "\\.R$")) source(f)

# --- Daten vorbereiten -------------------------------------------------------
data(mtcars)
# Binäres Ziel: Automatik (am=1) vs. Schaltung (am=0)
cat("Ziel: Vorhersage von Getriebetyp (am) in mtcars\n")
cat("Automatik:", sum(mtcars$am == 1), " | Manuell:", sum(mtcars$am == 0), "\n\n")

# --- Parameter-Raum ---------------------------------------------------------
space <- create_param_space(
  param_categorical("features", c(
    "am ~ wt + hp",
    "am ~ wt + hp + qsec",
    "am ~ wt + hp + disp + qsec",
    "am ~ mpg + wt + hp",
    "am ~ ."
  )),
  param_categorical("link", c("logit", "probit", "cauchit"))
)

# --- Zielfunktion: Log-Loss minimieren ---------------------------------------
log_loss <- function(actual, predicted) {
  predicted <- pmin(pmax(predicted, 1e-15), 1 - 1e-15)
  -mean(actual * log(predicted) + (1 - actual) * log(1 - predicted))
}

objective <- function(params) {
  evaluate_model(
    data   = mtcars,
    target = "am",
    build_model = function(train, tgt) {
      glm(as.formula(params$features),
          data = train, family = binomial(link = params$link))
    },
    score_fn = function(mod, test, tgt) {
      preds <- predict(mod, test, type = "response")
      log_loss(test[[tgt]], preds)
    },
    n_folds = 5
  )
}

# --- Optimierung durchführen -------------------------------------------------
cat("=== Grid Search: GLM-Optimierung ===\n")
result <- optimize_params(
  objective = objective,
  space     = space,
  method    = "grid",
  minimize  = TRUE,
  verbose   = TRUE
)

# --- Ergebnisse --------------------------------------------------------------
cat("\n--- Bestes Ergebnis ---\n")
cat("Features:", result$best_params$features, "\n")
cat("Link:    ", result$best_params$link, "\n")
cat("Log-Loss:", round(result$best_score, 4), "\n")

# --- Finales Modell ----------------------------------------------------------
cat("\n--- Finales Modell ---\n")
final <- glm(as.formula(result$best_params$features),
             data = mtcars, family = binomial(link = result$best_params$link))
print(summary(final))
cat("\nModell-Metriken:\n")
print(capture_metrics(final))

# --- Confusion Matrix --------------------------------------------------------
cat("\n--- Klassifikation auf Gesamtdaten ---\n")
preds <- ifelse(predict(final, mtcars, type = "response") > 0.5, 1, 0)
cat("Confusion Matrix:\n")
print(table(Predicted = preds, Actual = mtcars$am))
cat("Genauigkeit:", round(mean(preds == mtcars$am), 3), "\n")
