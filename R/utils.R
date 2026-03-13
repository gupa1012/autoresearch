# ============================================================================
# autoresearch - Utility Functions
# ============================================================================

#' Run an Expression with a Time Budget
#'
#' Evaluates \code{expr} and stops if it exceeds \code{seconds}.
#'
#' @param seconds Maximum wall-clock seconds.
#' @param expr Expression to evaluate.
#' @return Result of \code{expr}, or \code{NA} on timeout.
#' @export
with_time_budget <- function(seconds, expr) {
  setTimeLimit(elapsed = seconds, transient = TRUE)
  on.exit(setTimeLimit(elapsed = Inf), add = TRUE)
  tryCatch(expr, error = function(e) {
    if (grepl("time limit", conditionMessage(e), ignore.case = TRUE)) {
      warning("Time budget of ", seconds, "s exceeded")
    } else {
      warning("Error: ", conditionMessage(e))
    }
    NA
  })
}

#' Set a Seed Safely
#'
#' Wrapper around \code{set.seed} that accepts \code{NULL}.
#'
#' @param seed Integer seed or \code{NULL}.
#' @export
set_seed_safely <- function(seed) {
  if (!is.null(seed)) set.seed(seed)
}

#' Capture Metrics from a Model Object
#'
#' Extracts common goodness-of-fit metrics from standard R model objects.
#'
#' @param model A fitted model (e.g., \code{lm}, \code{glm}).
#' @return A named list of metrics.
#' @export
#' @examples
#' mod <- lm(mpg ~ wt + hp, data = mtcars)
#' capture_metrics(mod)
capture_metrics <- function(model) {
  metrics <- list()

  if (inherits(model, "lm")) {
    s <- summary(model)
    metrics$r_squared     <- s$r.squared
    metrics$adj_r_squared <- s$adj.r.squared
    metrics$sigma         <- s$sigma
    metrics$aic           <- AIC(model)
    metrics$bic           <- BIC(model)
  }

  if (inherits(model, "glm")) {
    metrics$deviance      <- model$deviance
    metrics$null_deviance <- model$null.deviance
  }

  metrics$n_obs <- if (!is.null(model$residuals)) {
    length(model$residuals)
  } else {
    NA_integer_
  }

  metrics
}
