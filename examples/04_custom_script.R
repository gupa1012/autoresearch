# ============================================================================
# Beispiel 4: Beliebiges R-Skript optimieren
# ============================================================================
#
# LERNZIEL:
# Dieses Beispiel zeigt, wie du ein BELIEBIGES R-Skript automatisch
# optimieren kannst - nicht nur statistische Modelle, sondern wirklich
# alles, was in R ausfuehrbar ist.
#
# WAS WIRD HIER OPTIMIERT?
# -> Eine Portfolio-Simulation: Wie soll Geld auf Aktien, Anleihen und
#   Cash verteilt werden, um die beste risikoadjustierte Rendite
#   (Sharpe Ratio) zu erzielen?
#
# WIE FUNKTIONIERT evaluate_script()?
# 1. Du schreibst ein R-Skript, das Parameter als Variablen verwendet
# 2. autoresearch INJIZIERT die Parameter (sie erscheinen als Variablen)
# 3. Dein Skript berechnet etwas und speichert das Ergebnis in .result
# 4. autoresearch liest .result aus und verwendet es als Score
#
#   +--- autoresearch setzt -------------------------+
#   |   weight_stocks = 0.6     (wird zur Variable)  |
#   |   weight_bonds  = 0.3     (wird zur Variable)  |
#   +-----------------------+-------------------------+
#                           |
#                           v
#   +--- Dein Skript ------------------------------------+
#   |   ... benutzt weight_stocks und weight_bonds ...   |
#   |   ... berechnet Sharpe Ratio ...                   |
#   |   .result <- -sharpe  <- PFLICHT: Ergebnis hier    |
#   +-----------------------+----------------------------+
#                           |
#                           v
#   +--- autoresearch liest -------------------------+
#   |   Score = .result = -0.85                      |
#   |   (niedrig = gut, weil wir minimieren)         |
#   +------------------------------------------------+
#
# ANDERE DINGE DIE DU SO OPTIMIEREN KOENNTEST:
# - Simulationsparameter (Monte Carlo, Fabrikplanung, ...)
# - Datenverarbeitungs-Pipelines (Imputation, Skalierung, Feature-Auswahl)
# - Kurvenanpassung (nichtlineare Fits)
# - Scheduling-Probleme (Schichtplanung, Ressourcenzuweisung)
# - Physikalische / biologische Modellparameter
# - Jedes Skript, das eine Zahl berechnet!
#
# ============================================================================

# Paket laden (alle R-Dateien aus dem R/ Verzeichnis)
for (f in list.files("R", full.names = TRUE, pattern = "\\.R$")) source(f)

# =============================================================================
# SCHRITT 1: Das R-Skript erstellen, das optimiert werden soll
# =============================================================================
# In der Praxis existiert dein Skript bereits als Datei.
# Hier erstellen wir es programmatisch als Demonstration.
#
# WICHTIG: Das Skript muss am Ende .result <- <wert> setzen!
# Das ist die einzige Regel.

script_path <- tempfile(fileext = ".R")

writeLines(c(
  '# =============================================',
  '# Portfolio-Simulationsskript',
  '# =============================================',
  '# Parameter die von autoresearch injiziert werden:',
  '#   weight_stocks  - Anteil Aktien (0 bis 1)',
  '#   weight_bonds   - Anteil Anleihen (0 bis 1)',
  '# Rest = Cash',
  '',
  'set.seed(42)  # Reproduzierbare Simulation',
  'n_days <- 252 # Ein Handelsjahr (252 Boersentage)',
  '',
  '# Simuliere taegliche Renditen fuer jede Anlageklasse',
  '# Aktien: hoehere Rendite, hoeheres Risiko',
  'stock_returns <- rnorm(n_days, mean = 0.0005, sd = 0.02)',
  '# Anleihen: niedrigere Rendite, niedrigeres Risiko',
  'bond_returns  <- rnorm(n_days, mean = 0.0002, sd = 0.005)',
  '# Cash: stabile, minimale Rendite',
  'cash_returns  <- rep(0.0001, n_days)',
  '',
  '# Portfolio-Rendite = gewichtete Summe der Anlageklassen',
  'weight_cash <- max(0, 1 - weight_stocks - weight_bonds)',
  'portfolio <- weight_stocks * stock_returns +',
  '            weight_bonds * bond_returns +',
  '            weight_cash * cash_returns',
  '',
  '# Sharpe Ratio = Rendite / Risiko (annualisiert)',
  '# Hoehere Sharpe Ratio = besseres Risiko-Rendite-Verhaeltnis',
  'sharpe <- mean(portfolio) / sd(portfolio) * sqrt(252)',
  '',
  '# PFLICHT: Ergebnis in .result speichern',
  '# Negativ, weil optimize_params MINIMIERT (niedrig = gut)',
  '# Wir wollen aber HOHE Sharpe Ratio -> negieren',
  '.result <- -sharpe'
), script_path)

cat("=== Das Skript das optimiert wird ===\n\n")
cat(readLines(script_path), sep = "\n")
cat("\n\n")

# =============================================================================
# SCHRITT 2: Parameter-Raum definieren
# =============================================================================
# Welche Stellschrauben soll autoresearch drehen?
# Hier: Aktien-Anteil und Anleihen-Anteil (jeweils 0% bis 100%)

space <- create_param_space(
  param_numeric("weight_stocks", 0.0, 1.0),
  param_numeric("weight_bonds", 0.0, 1.0)
)

# =============================================================================
# SCHRITT 3: Zielfunktion definieren
# =============================================================================
# Die Zielfunktion ruft das Skript auf und gibt den Score zurueck.
# TIPP: Hier kannst du auch Nebenbedingungen (Constraints) einbauen.

objective <- function(params) {
  # Constraint: Summe der Gewichte darf nicht > 100% sein
  if (params$weight_stocks + params$weight_bonds > 1.0) {
    return(Inf)  # Ungueltig -> wird ignoriert
  }
  # Skript ausfuehren mit den aktuellen Parametern
  evaluate_script(script_path, params = params, time_budget = 10)
}

# =============================================================================
# SCHRITT 4: Optimierung starten
# =============================================================================
cat("=== Random Search: Portfolio-Optimierung (200 Iterationen) ===\n\n")

result <- optimize_params(
  objective = objective,
  space     = space,
  method    = "random",   # Zufaellige Kombinationen testen
  n_iter    = 200,        # 200 verschiedene Portfolios ausprobieren
  minimize  = TRUE,       # Niedrigster Score = bestes Portfolio
  seed      = 7,          # Reproduzierbar
  verbose   = TRUE        # Fortschritt anzeigen
)

# =============================================================================
# SCHRITT 5: Ergebnisse auswerten
# =============================================================================
cat("\n=== Bestes Portfolio ===\n")
cat("Aktien-Anteil: ", round(result$best_params$weight_stocks * 100, 1), "%\n")
cat("Anleihen-Anteil:", round(result$best_params$weight_bonds * 100, 1), "%\n")
cash <- max(0, 1 - result$best_params$weight_stocks - result$best_params$weight_bonds)
cat("Cash-Anteil:    ", round(cash * 100, 1), "%\n")
cat("Sharpe Ratio:   ", round(-result$best_score, 4), "\n")

cat("\n=== Top 10 Portfolios ===\n")
df <- summarize_results(result$results)
df <- df[is.finite(df$score), ]
df <- df[order(df$score), ]
df$sharpe <- round(-df$score, 4)
df$aktien_pct <- round(df$weight_stocks * 100, 1)
df$anleihen_pct <- round(df$weight_bonds * 100, 1)
print(head(df[, c("aktien_pct", "anleihen_pct", "sharpe")], 10))

# Aufraeumen
unlink(script_path)
