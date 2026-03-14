# ============================================================================
# Beispiel 07: Research Agent – Intelligente Optimierung mit adaptivem Suchraum
# ============================================================================
#
# Dieses Beispiel zeigt, wie der Research Agent eine Funktion mit mehreren
# lokalen Minima (Ackley-Funktion) optimiert und dabei intelligenter vorgeht
# als eine einfache Random Search.
#
# Ausfuehren:
#   cd autoresearch
#   Rscript examples/07_research_agent.R
# ============================================================================

# Quellcode laden
for (f in list.files("R", full.names = TRUE, pattern = "\\.R$")) source(f)

cat("============================================================\n")
cat("  autoresearch – Beispiel 07: Research Agent\n")
cat("============================================================\n\n")

# ---- Zielfunktion: Ackley-Funktion -----------------------------------------
# Die Ackley-Funktion hat viele lokale Minima und ein globales Minimum bei
# (x=0, y=0) mit f(0,0) = 0.  Sie ist ein klassischer Benchmark fuer
# Optimierungsalgorithmen.
ackley <- function(params) {
  x <- params$x
  y <- params$y
  -20 * exp(-0.2 * sqrt(0.5 * (x^2 + y^2))) -
    exp(0.5 * (cos(2 * pi * x) + cos(2 * pi * y))) + exp(1) + 20
}

space <- create_param_space(
  param_numeric("x", -5, 5),
  param_numeric("y", -5, 5)
)

cat("Zielfunktion: Ackley-Funktion\n")
cat("Globales Minimum: f(0, 0) = 0\n")
cat("Suchraum: x in [-5, 5], y in [-5, 5]\n\n")

# ---- Vergleich: Random Search -----------------------------------------------
cat("--- Vergleich: Random Search (100 Iterationen) ---\n")
set.seed(42)
res_random <- optimize_params(ackley, space,
                              method  = "random",
                              n_iter  = 100,
                              seed    = 42,
                              verbose = FALSE)
cat(sprintf("Bester Score: %.6f\n", res_random$best_score))
cat(sprintf("Beste Parameter: x = %.4f, y = %.4f\n\n",
            res_random$best_params$x, res_random$best_params$y))

# ---- Bayesian Optimization --------------------------------------------------
cat("--- Bayesian Optimierung (50 Iterationen) ---\n")
res_bayes <- optimize_params(ackley, space,
                             method    = "bayesian",
                             n_iter    = 50,
                             n_initial = 8,
                             seed      = 42,
                             verbose   = FALSE)
cat(sprintf("Bester Score: %.6f\n", res_bayes$best_score))
cat(sprintf("Beste Parameter: x = %.4f, y = %.4f\n\n",
            res_bayes$best_params$x, res_bayes$best_params$y))

# ---- Research Agent ---------------------------------------------------------
cat("--- Research Agent (3 Runden x 30 Iterationen) ---\n")
agent_result <- research_agent(
  objective        = ackley,
  space            = space,
  n_rounds         = 3,
  strategies       = c("random", "bayesian"),
  n_iter_per_round = 30,
  top_fraction     = 0.15,
  shrink_factor    = 0.4,
  minimize         = TRUE,
  seed             = 42,
  verbose          = TRUE
)

cat("\n============================================================\n")
cat("  Ergebniszusammenfassung\n")
cat("============================================================\n\n")

cat(sprintf("Random Search (100 iter):     Score = %.6f\n", res_random$best_score))
cat(sprintf("Bayesian Optim. (50 iter):    Score = %.6f\n", res_bayes$best_score))
cat(sprintf("Research Agent (3x30 iter):   Score = %.6f\n", agent_result$best_score))

cat("\n--- Strategy-Log des Agents ---\n")
for (i in seq_along(agent_result$strategy_log)) {
  cat(sprintf("  Runde %d: %s  (Best nach Runde: %.6f)\n",
              i,
              agent_result$strategy_log[i],
              agent_result$improvement_history[i]))
}

cat("\n--- Suchraum-Entwicklung des Agents ---\n")
for (i in seq_along(agent_result$search_space_history)) {
  sp <- agent_result$search_space_history[[i]]
  bounds <- vapply(sp, function(p) {
    if (p$type == "categorical") {
      sprintf("%s: {%s}", p$name, paste(p$choices, collapse = ", "))
    } else {
      sprintf("%s: [%.3f, %.3f]", p$name, p$lower, p$upper)
    }
  }, character(1))
  cat(sprintf("  Runde %d: %s\n", i, paste(bounds, collapse = "  |  ")))
}

cat("\n--- Verbesserungshistorie ---\n")
cat("  Runde:  ", paste(sprintf("%8d", seq_along(agent_result$improvement_history)),
                        collapse = " "), "\n")
cat("  Score:  ", paste(sprintf("%8.4f", agent_result$improvement_history),
                        collapse = " "), "\n")

cat("\n--- Beste Parameter des Agents ---\n")
cat(sprintf("  x = %.6f\n  y = %.6f\n",
            agent_result$best_params$x,
            agent_result$best_params$y))
cat(sprintf("  Score = %.6f (Optimum waere 0)\n", agent_result$best_score))

cat("\n")
cat("Tipp: Je mehr Runden und Iterationen, desto naeher kommt der\n")
cat("Agent an das globale Optimum heran.\n")
