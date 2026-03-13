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

# ---- Summary ----------------------------------------------------------------
cat("\n", paste(rep("=", 50), collapse = ""), "\n")
cat(sprintf("Tests passed: %d / %d\n", tests_passed, tests_passed + tests_failed))
if (tests_failed > 0) {
  cat(sprintf("Tests FAILED: %d\n", tests_failed))
  quit(status = 1)
} else {
  cat("All tests passed!\n")
}
