# ============================================================================
# Tests for autoresearch R package
# ============================================================================

# Source all R files
for (f in list.files("R", full.names = TRUE, pattern = "\\.R$")) source(f)

# Track test results
tests_passed <- 0
tests_failed <- 0

assert <- function(desc, expr) {
  ok <- tryCatch(isTRUE(expr), error = function(e) FALSE)
  if (ok) {
    tests_passed <<- tests_passed + 1
    cat("  PASS:", desc, "\n")
  } else {
    tests_failed <<- tests_failed + 1
    cat("  FAIL:", desc, "\n")
  }
}

# ---- Parameter Space --------------------------------------------------------
cat("\n=== Parameter Space ===\n")

p1 <- param_numeric("lr", 0.001, 0.1)
assert("param_numeric type",   p1$type == "numeric")
assert("param_numeric name",   p1$name == "lr")
assert("param_numeric bounds", p1$lower == 0.001 && p1$upper == 0.1)

p2 <- param_integer("n", 1, 100)
assert("param_integer type", p2$type == "integer")
assert("param_integer is integer", is.integer(p2$lower))

p3 <- param_categorical("method", c("a", "b", "c"))
assert("param_categorical choices", length(p3$choices) == 3)

space <- create_param_space(p1, p2, p3)
assert("param_space class", inherits(space, "param_space"))
assert("param_space length", length(space) == 3)

# ---- Sampling ---------------------------------------------------------------
cat("\n=== Sampling ===\n")

set.seed(1)
config <- sample_params(space)
assert("sample has all params", all(c("lr", "n", "method") %in% names(config)))
assert("lr in range", config$lr >= 0.001 && config$lr <= 0.1)
assert("n in range", config$n >= 1 && config$n <= 100)
assert("method valid", config$method %in% c("a", "b", "c"))

# ---- Grid -------------------------------------------------------------------
cat("\n=== Grid ===\n")

grid <- build_grid(space, n_per_numeric = 3)
assert("grid is data.frame", is.data.frame(grid))
assert("grid has rows", nrow(grid) > 0)
assert("grid columns", all(c("lr", "n", "method") %in% names(grid)))

# ---- Results Log ------------------------------------------------------------
cat("\n=== Results Log ===\n")

log <- new_results_log()
assert("empty log", length(log$entries) == 0)

log <- add_result(log, params = list(x = 1), score = 0.5)
log <- add_result(log, params = list(x = 2), score = 0.3)
log <- add_result(log, params = list(x = 3), score = 0.7)
assert("log has 3 entries", length(log$entries) == 3)

best <- best_result(log, minimize = TRUE)
assert("best minimizes", best$score == 0.3)
assert("best index", best$index == 2)

best_max <- best_result(log, minimize = FALSE)
assert("best maximizes", best_max$score == 0.7)

df <- summarize_results(log)
assert("summarize returns df", is.data.frame(df) && nrow(df) == 3)

# ---- Save/Load Results ------------------------------------------------------
cat("\n=== Save/Load Results ===\n")

tmp <- tempfile(fileext = ".tsv")
save_results(log, path = tmp)
assert("file exists", file.exists(tmp))
loaded <- load_results(tmp)
assert("loaded df", is.data.frame(loaded) && nrow(loaded) == 3)
unlink(tmp)

# ---- Evaluate Model ---------------------------------------------------------
cat("\n=== Evaluate Model ===\n")

rmse <- evaluate_model(
  data   = mtcars,
  target = "mpg",
  build_model = function(train, tgt) lm(as.formula(paste(tgt, "~ wt + hp")), train),
  score_fn = function(mod, test, tgt) {
    preds <- predict(mod, test)
    sqrt(mean((test[[tgt]] - preds)^2))
  }
)
assert("evaluate_model returns numeric", is.numeric(rmse))
assert("RMSE is positive", rmse > 0)
assert("RMSE is reasonable", rmse < 10)

# ---- Evaluate Script --------------------------------------------------------
cat("\n=== Evaluate Script ===\n")

script <- tempfile(fileext = ".R")
writeLines(".result <- (x - 5)^2", script)
score <- evaluate_script(script, params = list(x = 4))
assert("script returns numeric", is.numeric(score))
assert("script returns 1", abs(score - 1) < 1e-10)
unlink(script)

# ---- Time Budget ------------------------------------------------------------
cat("\n=== Time Budget ===\n")

res <- with_time_budget(2, { 1 + 1 })
assert("time budget fast expr", res == 2)

# ---- Capture Metrics --------------------------------------------------------
cat("\n=== Capture Metrics ===\n")

mod <- lm(mpg ~ wt + hp, data = mtcars)
m <- capture_metrics(mod)
assert("has r_squared", !is.null(m$r_squared))
assert("has aic", !is.null(m$aic))
assert("r_squared in range", m$r_squared > 0 && m$r_squared < 1)

# ---- Optimizer End-to-End ---------------------------------------------------
cat("\n=== Optimizer (Random Search) ===\n")

obj <- function(params) (params$x - 3)^2 + (params$y + 1)^2
sp <- create_param_space(
  param_numeric("x", -10, 10),
  param_numeric("y", -10, 10)
)
res <- optimize_params(obj, sp, method = "random", n_iter = 200,
                       minimize = TRUE, seed = 42, verbose = FALSE)
assert("optimizer found good x", abs(res$best_params$x - 3) < 2)
assert("optimizer found good y", abs(res$best_params$y + 1) < 2)
assert("optimizer score near 0", res$best_score < 2)

cat("\n=== Grid Search ===\n")
res2 <- optimize_params(obj, sp, method = "grid", n_grid = 10,
                        minimize = TRUE, verbose = FALSE)
assert("grid search works", !is.na(res2$best_score))
assert("grid search near optimum", res2$best_score < 5)

# ---- Bayesian Optimization --------------------------------------------------
cat("\n=== Bayesian Optimization ===\n")

# Einfache quadratische Funktion – globales Minimum bei (3, -1)
obj_quad <- function(params) (params$x - 3)^2 + (params$y + 1)^2
sp_quad <- create_param_space(
  param_numeric("x", -10, 10),
  param_numeric("y", -10, 10)
)

res_bayes <- optimize_params(obj_quad, sp_quad, method = "bayesian",
                             n_iter = 30, n_initial = 6,
                             minimize = TRUE, seed = 99, verbose = FALSE)
assert("bayesian returns best_params", is.list(res_bayes$best_params))
assert("bayesian returns best_score",  is.numeric(res_bayes$best_score))
assert("bayesian score is finite",     is.finite(res_bayes$best_score))
assert("bayesian score is positive",   res_bayes$best_score >= 0)
assert("bayesian result near optimum", res_bayes$best_score < 10)

# Direkte Funktion bayesian_search
log_b <- bayesian_search(obj_quad, sp_quad, n_iter = 20, n_initial = 5,
                         minimize = TRUE, verbose = FALSE)
assert("bayesian_search returns log",   inherits(log_b, "results_log"))
assert("bayesian_search has entries",   length(log_b$entries) > 0)

# ---- narrow_param_space -----------------------------------------------------
cat("\n=== narrow_param_space ===\n")

sp_full <- create_param_space(
  param_numeric("a",  0, 10),
  param_integer("b",  1, 20),
  param_categorical("c", c("x", "y", "z"))
)

# Simuliere Top-Ergebnisse nahe a=3, b=5, c="x" oder "y" (nie "z")
top_df <- data.frame(a = c(2.8, 3.1, 3.0, 3.2), b = c(5L, 5L, 6L, 5L),
                     c = c("x", "x", "x", "y"), stringsAsFactors = FALSE)

sp_narrow <- narrow_param_space(sp_full, top_df, shrink_factor = 0.5)

assert("narrow returns param_space",   inherits(sp_narrow, "param_space"))
assert("narrow has same length",       length(sp_narrow) == length(sp_full))

# Numerisch: neuer Bereich soll enger sein
a_orig <- sp_full[[1]]
a_new  <- sp_narrow[[1]]
assert("numeric lower increased",  a_new$lower >= a_orig$lower)
assert("numeric upper decreased",  a_new$upper <= a_orig$upper)
assert("numeric range is smaller", (a_new$upper - a_new$lower) <
                                   (a_orig$upper - a_orig$lower))

# Integer analog
b_orig <- sp_full[[2]]
b_new  <- sp_narrow[[2]]
assert("integer range is smaller", (b_new$upper - b_new$lower) <
                                   (b_orig$upper - b_orig$lower))

# Kategoriell: nur noch "x"
c_new <- sp_narrow[[3]]
assert("categorical reduced",  length(c_new$choices) < 3)
assert("categorical kept used", "x" %in% c_new$choices)
assert("categorical removed unused",  !("z" %in% c_new$choices))

# ---- Research Agent ---------------------------------------------------------
cat("\n=== Research Agent ===\n")

ackley <- function(params) {
  x <- params$x; y <- params$y
  -20 * exp(-0.2 * sqrt(0.5 * (x^2 + y^2))) -
    exp(0.5 * (cos(2 * pi * x) + cos(2 * pi * y))) + exp(1) + 20
}
sp_ackley <- create_param_space(
  param_numeric("x", -5, 5),
  param_numeric("y", -5, 5)
)

agent_res <- research_agent(ackley, sp_ackley,
                            n_rounds         = 3,
                            strategies       = c("random", "bayesian"),
                            n_iter_per_round = 20,
                            top_fraction     = 0.15,
                            minimize         = TRUE,
                            seed             = 7,
                            verbose          = FALSE)

assert("agent returns best_params",          is.list(agent_res$best_params))
assert("agent returns best_score",           is.numeric(agent_res$best_score))
assert("agent best_score is finite",         is.finite(agent_res$best_score))
assert("agent rounds list correct length",   length(agent_res$rounds) == 3)
assert("agent strategy_log correct length",  length(agent_res$strategy_log) == 3)
assert("agent round1 is random",             agent_res$strategy_log[1] == "random")
assert("agent improvement_history length",   length(agent_res$improvement_history) == 3)
assert("agent space_history length",         length(agent_res$search_space_history) == 3)
assert("agent rounds are results_log",
       all(vapply(agent_res$rounds, function(r) inherits(r, "results_log"), logical(1))))
assert("agent improvement monotone",
       all(diff(agent_res$improvement_history) <= 1e-10))   # minimization: never worse

# Stagnation-Pruefung: Agent soll ohne Fehler durchlaufen, auch wenn er stagniert
agent_stag <- research_agent(ackley, sp_ackley,
                             n_rounds          = 4,
                             strategies        = "random",
                             n_iter_per_round  = 5,
                             stagnation_rounds = 1,
                             minimize          = TRUE,
                             seed              = 1,
                             verbose           = FALSE)
assert("agent stagnation does not crash", is.list(agent_stag))
assert("agent stagnation has best_score", is.finite(agent_stag$best_score))

# ---- Summary ----------------------------------------------------------------
cat("\n", paste(rep("=", 50), collapse = ""), "\n")
cat(sprintf("Tests passed: %d / %d\n", tests_passed, tests_passed + tests_failed))
if (tests_failed > 0) {
  cat(sprintf("Tests FAILED: %d\n", tests_failed))
  quit(status = 1)
} else {
  cat("All tests passed!\n")
}
