# ============================================================================
# Beispiel 6: Erweiterte Skript-Optimierung - Drei Szenarien
# ============================================================================
#
# LERNZIEL:
# Dieses Beispiel zeigt DREI verschiedene Anwendungsfaelle fuer
# evaluate_script(), um zu demonstrieren wie vielseitig die
# Skript-Optimierung ist.
#
# SZENARIO A: Kurvenfit (Funktionsparameter an Daten anpassen)
# SZENARIO B: Simulation (Produktionslinie optimieren)
# SZENARIO C: Daten-Pipeline (Vorverarbeitungsschritte tunen)
#
# ============================================================================

# Paket laden
for (f in list.files("R", full.names = TRUE, pattern = "\\.R$")) source(f)

cat(paste(rep("=", 70), collapse = ""), "\n")
cat("  BEISPIEL 6: Drei Szenarien fuer Skript-Optimierung\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")


# #########################################################################
# SZENARIO A: Kurvenfit
# #########################################################################
#
# Situation: Du hast Messdaten und eine theoretische Funktion mit
# unbekannten Parametern. autoresearch findet die Parameter, die
# am besten zu den Daten passen.
#
# Hier: f(x) = amplitude * sin(freq * x + phase) + offset
# #########################################################################

cat("\n", paste(rep("-", 60), collapse = ""), "\n")
cat("  SZENARIO A: Kurvenfit - Sinusfunktion an Messdaten anpassen\n")
cat(paste(rep("-", 60), collapse = ""), "\n\n")

# Erstelle das Kurvenfit-Skript
kurvenfit_script <- tempfile(fileext = ".R")
writeLines(c(
  '# Kurvenfit-Skript',
  '# Parameter: amplitude, freq, phase, offset',
  '# Ziel: Summe der quadrierten Abweichungen minimieren',
  '',
  '# "Echte" Messdaten (in der Praxis: aus einer Datei laden)',
  'x_mess <- seq(0, 10, length.out = 50)',
  'y_mess <- 3.2 * sin(1.5 * x_mess + 0.8) + 2.1 + rnorm(50, sd = 0.3)',
  '',
  '# Theoretische Vorhersage mit aktuellen Parametern',
  'y_pred <- amplitude * sin(freq * x_mess + phase) + offset',
  '',
  '# Abweichung zwischen Theorie und Messung',
  '.result <- sum((y_mess - y_pred)^2)'
), kurvenfit_script)

# Parameter-Raum
space_a <- create_param_space(
  param_numeric("amplitude", 0.5, 6.0),
  param_numeric("freq", 0.5, 3.0),
  param_numeric("phase", 0.0, 6.28),  # 0 bis 2*pi
  param_numeric("offset", -5.0, 5.0)
)

# Optimieren
cat("Optimiere Kurvenfit-Parameter (300 Iterationen)...\n")
result_a <- optimize_params(
  objective = function(params) {
    evaluate_script(kurvenfit_script, params = params, time_budget = 5)
  },
  space    = space_a,
  method   = "random",
  n_iter   = 300,
  minimize = TRUE,
  seed     = 42,
  verbose  = FALSE
)

cat("\nErgebnis Kurvenfit:\n")
cat("  Amplitude:", round(result_a$best_params$amplitude, 3),
    "(echt: 3.2)\n")
cat("  Frequenz: ", round(result_a$best_params$freq, 3),
    "(echt: 1.5)\n")
cat("  Phase:    ", round(result_a$best_params$phase, 3),
    "(echt: 0.8)\n")
cat("  Offset:   ", round(result_a$best_params$offset, 3),
    "(echt: 2.1)\n")
cat("  Residualsumme:", round(result_a$best_score, 2), "\n")

unlink(kurvenfit_script)


# #########################################################################
# SZENARIO B: Produktionssimulation
# #########################################################################
#
# Situation: Eine Fabrik hat Maschinen und Puffer. Du willst die
# Konfiguration finden, die den Durchsatz maximiert bei
# minimalen Kosten.
#
# Parameter: n_maschinen, puffer_groesse, wartungsintervall
# #########################################################################

cat("\n", paste(rep("-", 60), collapse = ""), "\n")
cat("  SZENARIO B: Produktionslinie simulieren und optimieren\n")
cat(paste(rep("-", 60), collapse = ""), "\n\n")

produktion_script <- tempfile(fileext = ".R")
writeLines(c(
  '# Produktionssimulation',
  '# Parameter: n_maschinen, puffer_groesse, wartungsintervall',
  '',
  'set.seed(123)',
  'n_tage <- 30',
  '',
  '# Kosten',
  'kosten_maschine <- 1000  # pro Maschine pro Tag',
  'kosten_puffer   <- 50    # pro Pufferplatz pro Tag',
  '',
  '# Simulation: Jede Maschine produziert mit zufaelligen Ausfaellen',
  'total_output <- 0',
  'for (tag in 1:n_tage) {',
  '  tages_output <- 0',
  '  for (m in 1:n_maschinen) {',
  '    # Maschine faellt aus wenn seit letzter Wartung zu viele Tage',
  '    ausfallwahrscheinlichkeit <- (tag %% wartungsintervall) / (wartungsintervall * 2)',
  '    if (runif(1) > ausfallwahrscheinlichkeit) {',
  '      tages_output <- tages_output + rpois(1, lambda = 100)',
  '    }',
  '  }',
  '  # Puffer begrenzt den Output pro Tag',
  '  tages_output <- min(tages_output, puffer_groesse * 50)',
  '  total_output <- total_output + tages_output',
  '}',
  '',
  '# Gesamtkosten',
  'fixkosten <- n_tage * (n_maschinen * kosten_maschine + puffer_groesse * kosten_puffer)',
  '',
  '# Score: Kosten pro produzierter Einheit (niedriger = besser)',
  'if (total_output > 0) {',
  '  .result <- fixkosten / total_output',
  '} else {',
  '  .result <- Inf',
  '}'
), produktion_script)

space_b <- create_param_space(
  param_integer("n_maschinen", 2, 15),
  param_integer("puffer_groesse", 5, 50),
  param_integer("wartungsintervall", 3, 14)
)

cat("Optimiere Produktionslinie (200 Iterationen)...\n")
result_b <- optimize_params(
  objective = function(params) {
    evaluate_script(produktion_script, params = params, time_budget = 10)
  },
  space    = space_b,
  method   = "random",
  n_iter   = 200,
  minimize = TRUE,
  seed     = 99,
  verbose  = FALSE
)

cat("\nErgebnis Produktionslinie:\n")
cat("  Maschinen:         ", result_b$best_params$n_maschinen, "\n")
cat("  Puffergroesse:     ", result_b$best_params$puffer_groesse, "\n")
cat("  Wartungsintervall: ", result_b$best_params$wartungsintervall, "Tage\n")
cat("  Kosten pro Einheit:", round(result_b$best_score, 2), "\n")

cat("\n  Top 5 Konfigurationen:\n")
df_b <- summarize_results(result_b$results)
df_b <- df_b[is.finite(df_b$score), ]
df_b <- df_b[order(df_b$score), ]
print(head(df_b[, c("n_maschinen", "puffer_groesse",
                     "wartungsintervall", "score")], 5))

unlink(produktion_script)


# #########################################################################
# SZENARIO C: Daten-Pipeline optimieren
# #########################################################################
#
# Situation: Du hast einen Datensatz und willst die beste Kombination
# von Vorverarbeitungsschritten finden (Skalierung, Ausreisser-
# Behandlung, Feature-Auswahl).
#
# Das ist ein sehr haeufiger Anwendungsfall in der Praxis!
# #########################################################################

cat("\n", paste(rep("-", 60), collapse = ""), "\n")
cat("  SZENARIO C: Daten-Pipeline optimieren (Vorverarbeitung + Modell)\n")
cat(paste(rep("-", 60), collapse = ""), "\n\n")

pipeline_script <- tempfile(fileext = ".R")
writeLines(c(
  '# Daten-Pipeline-Skript',
  '# Parameter: scale_method, outlier_threshold, n_features, model_type',
  '',
  'data(mtcars)',
  'set.seed(42)',
  'df <- mtcars',
  '',
  '# Schritt 1: Skalierung',
  'if (scale_method == "standard") {',
  '  df[, -1] <- scale(df[, -1])',
  '} else if (scale_method == "minmax") {',
  '  for (col in names(df)[-1]) {',
  '    rng <- range(df[[col]])',
  '    if (rng[2] > rng[1]) df[[col]] <- (df[[col]] - rng[1]) / (rng[2] - rng[1])',
  '  }',
  '} # else: "none" - keine Skalierung',
  '',
  '# Schritt 2: Ausreisser entfernen (basierend auf Schwellenwert)',
  'keep <- rep(TRUE, nrow(df))',
  'for (col in names(df)[-1]) {',
  '  z <- abs(scale(df[[col]]))',
  '  keep <- keep & (z < outlier_threshold)',
  '}',
  'df <- df[keep, ]',
  '',
  '# Schritt 3: Feature-Auswahl (Top N nach Korrelation mit mpg)',
  'cors <- abs(cor(df[, -1], df$mpg))',
  'top_features <- names(sort(cors[,1], decreasing = TRUE))[1:min(n_features, ncol(df)-1)]',
  '',
  '# Schritt 4: Modell fitten und Cross-Validation-RMSE berechnen',
  'n_folds <- 5',
  'folds <- sample(rep(1:n_folds, length.out = nrow(df)))',
  'scores <- numeric(n_folds)',
  '',
  'for (k in 1:n_folds) {',
  '  train <- df[folds != k, c("mpg", top_features)]',
  '  test  <- df[folds == k, c("mpg", top_features)]',
  '  if (nrow(train) < 5 || nrow(test) < 2) { scores[k] <- NA; next }',
  '',
  '  if (model_type == "lm") {',
  '    mod <- lm(mpg ~ ., data = train)',
  '  } else {',
  '    mod <- lm(mpg ~ . + I(.^2), data = train)  # Quadratische Terme',
  '  }',
  '',
  '  preds <- predict(mod, test)',
  '  scores[k] <- sqrt(mean((test$mpg - preds)^2))',
  '}',
  '',
  '.result <- mean(scores, na.rm = TRUE)'
), pipeline_script)

space_c <- create_param_space(
  param_categorical("scale_method", c("none", "standard", "minmax")),
  param_numeric("outlier_threshold", 1.5, 4.0),
  param_integer("n_features", 2, 10),
  param_categorical("model_type", c("lm", "quadratic"))
)

cat("Optimiere Daten-Pipeline (150 Iterationen)...\n")
result_c <- optimize_params(
  objective = function(params) {
    evaluate_script(pipeline_script, params = params, time_budget = 10)
  },
  space    = space_c,
  method   = "random",
  n_iter   = 150,
  minimize = TRUE,
  seed     = 55,
  verbose  = FALSE
)

cat("\nErgebnis Pipeline:\n")
cat("  Skalierung:         ", result_c$best_params$scale_method, "\n")
cat("  Ausreisser-Schwelle:", round(result_c$best_params$outlier_threshold, 2), "\n")
cat("  Anzahl Features:    ", result_c$best_params$n_features, "\n")
cat("  Modelltyp:          ", result_c$best_params$model_type, "\n")
cat("  RMSE:               ", round(result_c$best_score, 4), "\n")

cat("\n  Top 5 Pipelines:\n")
df_c <- summarize_results(result_c$results)
df_c <- df_c[is.finite(df_c$score), ]
df_c <- df_c[order(df_c$score), ]
print(head(df_c[, c("scale_method", "outlier_threshold",
                     "n_features", "model_type", "score")], 5))

unlink(pipeline_script)


# =============================================================================
# ZUSAMMENFASSUNG
# =============================================================================
cat("\n", paste(rep("=", 70), collapse = ""), "\n")
cat("  ZUSAMMENFASSUNG\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")
cat("Drei voellig verschiedene Probleme - alle mit dem gleichen Muster:\n\n")
cat("  1. Schreibe ein R-Skript mit Parametern als Variablen\n")
cat("  2. Setze .result <- <dein Score> am Ende\n")
cat("  3. Definiere den Parameter-Raum\n")
cat("  4. Starte optimize_params() mit evaluate_script()\n\n")
cat("Das funktioniert mit JEDEM R-Skript, das eine Zahl berechnet!\n")
