# ============================================================================
# Beispiel 4: Beliebiges R-Skript optimieren
# ============================================================================
# Zeigt wie ein externes R-Skript parametrisch optimiert werden kann.
# Das Skript bekommt Parameter injiziert und gibt .result zurück.
# ============================================================================

# Paket laden
for (f in list.files("R", full.names = TRUE, pattern = "\\.R$")) source(f)

# --- Schritt 1: Skript erstellen ---------------------------------------------
# In der Praxis liegt das Skript bereits vor. Hier erstellen wir ein
# Beispiel-Skript das eine Simulationsaufgabe löst.

script_path <- tempfile(fileext = ".R")

writeLines(c(
  '# Simulationsskript: Optimale Portfolio-Allokation',
  '# Parameter: weight_stocks, weight_bonds (injiziert von autoresearch)',
  '',
  'set.seed(42)',
  'n_days <- 252   # Ein Handelsjahr',
  '',
  '# Simuliere tägliche Renditen',
  'stock_returns <- rnorm(n_days, mean = 0.0005, sd = 0.02)',
  'bond_returns  <- rnorm(n_days, mean = 0.0002, sd = 0.005)',
  'cash_returns  <- rep(0.0001, n_days)',
  '',
  '# Portfolio-Rendite',
  'weight_cash <- max(0, 1 - weight_stocks - weight_bonds)',
  'portfolio <- weight_stocks * stock_returns +',
  '            weight_bonds * bond_returns +',
  '            weight_cash * cash_returns',
  '',
  '# Sharpe Ratio (negativ, da wir minimieren)',
  'sharpe <- mean(portfolio) / sd(portfolio) * sqrt(252)',
  '.result <- -sharpe   # Negativ weil optimize_params minimiert'
), script_path)

cat("Skript erstellt:", script_path, "\n")
cat("Inhalt:\n")
cat(readLines(script_path), sep = "\n")

# --- Schritt 2: Parameter-Raum definieren ------------------------------------
space <- create_param_space(
  param_numeric("weight_stocks", 0.0, 1.0),
  param_numeric("weight_bonds", 0.0, 1.0)
)

# --- Schritt 3: Zielfunktion via evaluate_script -----------------------------
objective <- function(params) {
  # Ungültige Kombinationen abfangen
  if (params$weight_stocks + params$weight_bonds > 1.0) {
    return(Inf)
  }
  evaluate_script(script_path, params = params, time_budget = 10)
}

# --- Schritt 4: Optimierung -------------------------------------------------
cat("\n\n=== Random Search: Portfolio-Optimierung (200 Iterationen) ===\n")
result <- optimize_params(
  objective = objective,
  space     = space,
  method    = "random",
  n_iter    = 200,
  minimize  = TRUE,
  seed      = 7,
  verbose   = TRUE
)

# --- Ergebnisse --------------------------------------------------------------
cat("\n--- Bestes Ergebnis ---\n")
cat("Aktien-Anteil:", round(result$best_params$weight_stocks, 3), "\n")
cat("Anleihen-Anteil:", round(result$best_params$weight_bonds, 3), "\n")
cash <- max(0, 1 - result$best_params$weight_stocks - result$best_params$weight_bonds)
cat("Cash-Anteil:   ", round(cash, 3), "\n")
cat("Sharpe Ratio:  ", round(-result$best_score, 4), "\n")

# --- Top-10 ---
cat("\n--- Top 10 Portfolios ---\n")
df <- summarize_results(result$results)
df <- df[is.finite(df$score), ]
df <- df[order(df$score), ]
df$sharpe <- round(-df$score, 4)
print(head(df[, c("weight_stocks", "weight_bonds", "sharpe")], 10))

# Aufräumen
unlink(script_path)
