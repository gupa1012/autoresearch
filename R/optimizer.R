# ============================================================================
# autoresearch - Parameter Space Definition
# ============================================================================

#' Define a Numeric Parameter
#'
#' @param name Parameter name.
#' @param lower Lower bound.
#' @param upper Upper bound.
#' @return A list describing the parameter.
#' @export
param_numeric <- function(name, lower, upper) {
  stopifnot(is.character(name), length(name) == 1)
  stopifnot(is.numeric(lower), is.numeric(upper), lower < upper)
  list(name = name, type = "numeric", lower = lower, upper = upper)
}

#' Define an Integer Parameter
#'
#' @param name Parameter name.
#' @param lower Lower bound (integer).
#' @param upper Upper bound (integer).
#' @return A list describing the parameter.
#' @export
param_integer <- function(name, lower, upper) {
  stopifnot(is.character(name), length(name) == 1)
  stopifnot(lower < upper)
  list(name = name, type = "integer", lower = as.integer(lower),
       upper = as.integer(upper))
}

#' Define a Categorical Parameter
#'
#' @param name Parameter name.
#' @param choices Character vector of possible values.
#' @return A list describing the parameter.
#' @export
param_categorical <- function(name, choices) {
  stopifnot(is.character(name), length(name) == 1)
  stopifnot(length(choices) >= 2)
  list(name = name, type = "categorical", choices = choices)
}

#' Create a Parameter Space from Individual Parameter Definitions
#'
#' @param ... Parameter definitions created with \code{param_numeric},
#'   \code{param_integer}, or \code{param_categorical}.
#' @return A list of class \code{param_space}.
#' @export
#' @examples
#' space <- create_param_space(
#'   param_numeric("learning_rate", 0.001, 0.1),
#'   param_integer("n_trees", 50, 500),
#'   param_categorical("method", c("lm", "glm", "ridge"))
#' )
create_param_space <- function(...) {
  params <- list(...)
  stopifnot(length(params) >= 1)
  for (p in params) {
    stopifnot(all(c("name", "type") %in% names(p)))
  }
  structure(params, class = "param_space")
}

# Sample a single random configuration from the parameter space
sample_params <- function(space) {
  config <- list()
  for (p in space) {
    config[[p$name]] <- switch(p$type,
      numeric     = runif(1, p$lower, p$upper),
      integer     = sample(p$lower:p$upper, 1),
      categorical = sample(p$choices, 1)
    )
  }
  config
}

# Build a full grid from the parameter space (for grid search)
build_grid <- function(space, n_per_numeric = 5) {
  axes <- list()
  for (p in space) {
    axes[[p$name]] <- switch(p$type,
      numeric     = seq(p$lower, p$upper, length.out = n_per_numeric),
      integer     = seq(p$lower, p$upper, by = max(1, (p$upper - p$lower) %/%
                        (n_per_numeric - 1))),
      categorical = p$choices
    )
  }
  expand.grid(axes, stringsAsFactors = FALSE)
}

# ============================================================================
# autoresearch - Core Optimization Engine
# ============================================================================

#' Optimize Parameters Using the Specified Strategy
#'
#' This is the main entry point.  It accepts an objective function and a
#' parameter space and returns the best configuration found.
#'
#' @param objective A function that takes a named list of parameters and returns
#'   a single numeric score.  Lower values are considered better by default
#'   (see \code{minimize}).
#' @param space A parameter space created with \code{create_param_space}.
#' @param method One of \code{"grid"}, \code{"random"}.
#' @param n_iter Number of iterations (used by \code{"random"}).
#' @param n_grid Points per numeric axis (used by \code{"grid"}).
#' @param minimize If \code{TRUE}, lower objective values are better.
#' @param time_budget Optional time budget in seconds.  The search stops when
#'   the budget is exceeded.
#' @param seed Optional random seed for reproducibility.
#' @param verbose Print progress messages.
#' @return A list with elements \code{best_params}, \code{best_score}, and
#'   \code{results} (a \code{results_log}).
#' @export
#' @examples
#' # Minimize a simple quadratic
#' obj <- function(params) (params$x - 3)^2 + (params$y + 1)^2
#' space <- create_param_space(
#'   param_numeric("x", -10, 10),
#'   param_numeric("y", -10, 10)
#' )
#' res <- optimize_params(obj, space, method = "random", n_iter = 200)
#' cat("Best score:", res$best_score, "\n")
#' cat("Best x:", res$best_params$x, " y:", res$best_params$y, "\n")
optimize_params <- function(objective, space, method = c("random", "grid"),
                            n_iter = 100, n_grid = 5, minimize = TRUE,
                            time_budget = NULL, seed = NULL, verbose = TRUE) {
  method <- match.arg(method)
  if (!is.null(seed)) set.seed(seed)

  log <- new_results_log()
  start_time <- proc.time()[["elapsed"]]

  if (method == "grid") {
    log <- grid_search(objective, space, n_grid = n_grid, minimize = minimize,
                       time_budget = time_budget, verbose = verbose)
  } else {
    log <- random_search(objective, space, n_iter = n_iter,
                         minimize = minimize, time_budget = time_budget,
                         verbose = verbose)
  }

  best <- best_result(log, minimize = minimize)
  list(best_params = best$params, best_score = best$score, results = log)
}

#' Grid Search Over a Parameter Space
#'
#' @inheritParams optimize_params
#' @param n_grid Points per numeric axis.
#' @return A \code{results_log}.
#' @export
grid_search <- function(objective, space, n_grid = 5, minimize = TRUE,
                        time_budget = NULL, verbose = TRUE) {
  grid <- build_grid(space, n_per_numeric = n_grid)
  log  <- new_results_log()
  start_time <- proc.time()[["elapsed"]]

  for (i in seq_len(nrow(grid))) {
    if (!is.null(time_budget)) {
      elapsed <- proc.time()[["elapsed"]] - start_time
      if (elapsed >= time_budget) {
        if (verbose) message("Time budget reached after ", i - 1, " evaluations")
        break
      }
    }
    params <- as.list(grid[i, , drop = FALSE])
    score  <- tryCatch(objective(params), error = function(e) {
      if (verbose) message("Error at iteration ", i, ": ", conditionMessage(e))
      NA_real_
    })
    log <- add_result(log, params = params, score = score)
    if (verbose && i %% 10 == 0) {
      best <- best_result(log, minimize = minimize)
      message(sprintf("[%d/%d] best = %.6f", i, nrow(grid), best$score))
    }
  }
  log
}

#' Random Search Over a Parameter Space
#'
#' @inheritParams optimize_params
#' @return A \code{results_log}.
#' @export
random_search <- function(objective, space, n_iter = 100, minimize = TRUE,
                          time_budget = NULL, verbose = TRUE) {
  log <- new_results_log()
  start_time <- proc.time()[["elapsed"]]

  for (i in seq_len(n_iter)) {
    if (!is.null(time_budget)) {
      elapsed <- proc.time()[["elapsed"]] - start_time
      if (elapsed >= time_budget) {
        if (verbose) message("Time budget reached after ", i - 1, " evaluations")
        break
      }
    }
    params <- sample_params(space)
    score  <- tryCatch(objective(params), error = function(e) {
      if (verbose) message("Error at iteration ", i, ": ", conditionMessage(e))
      NA_real_
    })
    log <- add_result(log, params = params, score = score)
    if (verbose && i %% 20 == 0) {
      best <- best_result(log, minimize = minimize)
      message(sprintf("[%d/%d] best = %.6f", i, n_iter, best$score))
    }
  }
  log
}
