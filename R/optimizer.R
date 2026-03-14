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
#' @param method One of \code{"grid"}, \code{"random"}, \code{"bayesian"}.
#' @param n_iter Number of iterations (used by \code{"random"} and
#'   \code{"bayesian"}).
#' @param n_grid Points per numeric axis (used by \code{"grid"}).
#' @param n_initial Number of random initial points before the Bayesian
#'   surrogate is fitted (used by \code{"bayesian"}, default 5).
#' @param kappa Exploration-exploitation trade-off for the UCB acquisition
#'   function used in Bayesian optimisation (default 2.0).  Higher values
#'   favour exploration.
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
optimize_params <- function(objective, space,
                            method = c("random", "grid", "bayesian"),
                            n_iter = 100, n_grid = 5,
                            n_initial = 5, kappa = 2.0,
                            minimize = TRUE,
                            time_budget = NULL, seed = NULL, verbose = TRUE) {
  method <- match.arg(method)
  if (!is.null(seed)) set.seed(seed)

  if (method == "grid") {
    log <- grid_search(objective, space, n_grid = n_grid, minimize = minimize,
                       time_budget = time_budget, verbose = verbose)
  } else if (method == "bayesian") {
    log <- bayesian_search(objective, space, n_iter = n_iter,
                           n_initial = n_initial, kappa = kappa,
                           minimize = minimize, time_budget = time_budget,
                           verbose = verbose)
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

# ============================================================================
# Bayesian Optimization (Gaussian Process Surrogate + Expected Improvement)
# ============================================================================

# Encode a parameter configuration as a numeric vector for the GP surrogate.
# Categorical parameters are encoded as zero-based integers.
encode_params <- function(params, space) {
  vapply(space, function(p) {
    v <- params[[p$name]]
    if (p$type == "categorical") {
      match(v, p$choices) - 1L   # 0-based for uniform scaling
    } else {
      as.numeric(v)
    }
  }, numeric(1))
}

# RBF kernel: k(x, x') = exp(-||x - x'||^2 / (2 * l^2))
rbf_kernel <- function(X, Xp, length_scale = 1.0) {
  # X: (n x d), Xp: (m x d) -> returns (n x m) matrix
  n <- nrow(X)
  m <- nrow(Xp)
  K <- matrix(0, n, m)
  for (i in seq_len(n)) {
    for (j in seq_len(m)) {
      diff <- X[i, ] - Xp[j, ]
      K[i, j] <- exp(-sum(diff^2) / (2 * length_scale^2))
    }
  }
  K
}

# Simple GP surrogate: compute posterior mean and variance at a new point.
# Parameters:
#   X_train     : (n x d) matrix of observed (normalized) inputs
#   y_train     : (n) vector of observed objective values
#   x_new       : (d) numeric vector for the query point (normalized)
#   noise       : observation noise variance added to kernel diagonal
#   length_scale: RBF length scale
# Returns: list(mean, var) – posterior predictive mean and variance
gp_predict <- function(X_train, y_train, x_new, noise = 1e-6, length_scale = 1.0) {
  K    <- rbf_kernel(X_train, X_train, length_scale)
  K    <- K + diag(noise, nrow(K))
  k_s  <- rbf_kernel(X_train, matrix(x_new, nrow = 1), length_scale)
  k_ss <- 1.0  # k(x_new, x_new) = 1 for normalized RBF

  # Numerically stable solution via Cholesky decomposition
  L   <- tryCatch(chol(K), error = function(e) {
    chol(K + diag(1e-4, nrow(K)))
  })
  alpha <- backsolve(L, forwardsolve(t(L), y_train))
  mu    <- as.numeric(t(k_s) %*% alpha)
  v     <- forwardsolve(t(L), k_s)
  sigma2 <- max(0, k_ss - sum(v^2))
  list(mean = mu, var = sigma2)
}

# Expected Improvement (EI): E[max(0, f_best - f(x))] under minimization.
# Parameters:
#   mu     : GP posterior mean at the candidate point
#   sigma2 : GP posterior variance at the candidate point
#   f_best : current best observed objective value
#   xi     : exploration jitter (larger = more exploration)
# Returns: scalar EI value (>= 0)
expected_improvement <- function(mu, sigma2, f_best, xi = 0.01) {
  sigma <- sqrt(max(sigma2, 0))
  if (sigma < 1e-10) return(0)
  z   <- (f_best - mu - xi) / sigma
  ei  <- (f_best - mu - xi) * pnorm(z) + sigma * dnorm(z)
  max(0, ei)
}

# Build per-parameter [0, 1] normalization bounds for the GP input space
normalize_space <- function(space) {
  lapply(space, function(p) {
    if (p$type == "categorical") {
      list(lower = 0, upper = length(p$choices) - 1L)
    } else {
      list(lower = p$lower, upper = p$upper)
    }
  })
}

# Candidate sampling via random EI maximization: sample n_cand random points
# and return the one with the highest Expected Improvement.
next_candidate_ei <- function(X_train, y_train, space, f_best,
                              n_cand = 1000, length_scale = 1.0,
                              noise = 1e-6, xi = 0.01) {
  norms  <- normalize_space(space)
  best_ei <- -Inf
  best_x  <- NULL

  for (i in seq_len(n_cand)) {
    cand <- sample_params(space)
    x_vec <- encode_params(cand, space)
    # Normalize each dimension to [0, 1]
    x_norm <- mapply(function(v, n) {
      rng <- n$upper - n$lower
      if (rng == 0) 0 else (v - n$lower) / rng
    }, x_vec, norms)

    pred <- gp_predict(X_train, y_train, x_norm, noise = noise,
                       length_scale = length_scale)
    ei   <- expected_improvement(pred$mean, pred$var, f_best, xi = xi)
    if (ei > best_ei) {
      best_ei <- ei
      best_x  <- cand
    }
  }
  best_x
}

#' Bayesian Search Over a Parameter Space
#'
#' Uses a Gaussian Process surrogate model with an RBF kernel and Expected
#' Improvement as the acquisition function to guide the search toward
#' promising regions.
#'
#' @inheritParams optimize_params
#' @param n_initial Number of random initial points before the first surrogate
#'   fit.
#' @param kappa Exploration-exploitation trade-off (used as \code{xi} scaling
#'   factor for EI; higher = more exploration).
#' @return A \code{results_log}.
#' @export
bayesian_search <- function(objective, space, n_iter = 50, n_initial = 5,
                            kappa = 2.0, minimize = TRUE,
                            time_budget = NULL, verbose = TRUE) {
  log        <- new_results_log()
  start_time <- proc.time()[["elapsed"]]
  norms      <- normalize_space(space)
  d          <- length(space)

  # --- Phase 1: initial random points ---
  n_init <- min(n_initial, n_iter)
  for (i in seq_len(n_init)) {
    if (!is.null(time_budget) &&
        proc.time()[["elapsed"]] - start_time >= time_budget) {
      if (verbose) message("Time budget reached after ", i - 1, " evaluations")
      return(log)
    }
    params <- sample_params(space)
    score  <- tryCatch(objective(params), error = function(e) {
      if (verbose) message("Error at iteration ", i, ": ", conditionMessage(e))
      NA_real_
    })
    log <- add_result(log, params = params, score = score)
    if (verbose)
      message(sprintf("[Init %d/%d] score = %.6f", i, n_init, score))
  }

  # --- Phase 2: Bayesian optimization loop ---
  for (i in seq(n_init + 1L, n_iter)) {
    if (!is.null(time_budget) &&
        proc.time()[["elapsed"]] - start_time >= time_budget) {
      if (verbose) message("Time budget reached after ", i - 1, " evaluations")
      break
    }

    # Collect valid (non-NA) observations so far
    entries <- log$entries
    valid   <- Filter(function(e) !is.na(e$score), entries)
    if (length(valid) < 2) {
      # Too few points to fit a surrogate – fall back to random sampling
      params <- sample_params(space)
    } else {
      y_obs  <- vapply(valid, function(e) e$score, numeric(1))
      X_obs  <- do.call(rbind, lapply(valid, function(e) {
        x_raw  <- encode_params(e$params, space)
        x_norm <- mapply(function(v, n) {
          rng <- n$upper - n$lower
          if (rng == 0) 0 else (v - n$lower) / rng
        }, x_raw, norms)
        x_norm
      }))
      if (!is.matrix(X_obs)) X_obs <- matrix(X_obs, nrow = 1)

      # Fit GP on scores (negate for maximization so GP always minimizes)
      y_fit  <- if (minimize) y_obs else -y_obs
      f_best <- min(y_fit)

      # Heuristic: shrink length_scale as more observations accumulate
      ls <- max(0.1, 1.0 / sqrt(length(valid)))

      params <- tryCatch(
        next_candidate_ei(X_obs, y_fit, space, f_best,
                          n_cand = 500, length_scale = ls,
                          xi = 0.01 * kappa),
        error = function(e) sample_params(space)
      )
    }

    score <- tryCatch(objective(params), error = function(e) {
      if (verbose) message("Error at iteration ", i, ": ", conditionMessage(e))
      NA_real_
    })
    log <- add_result(log, params = params, score = score)
    if (verbose) {
      best <- best_result(log, minimize = minimize)
      message(sprintf("[Bayes %d/%d] score = %.6f  best = %.6f",
                      i, n_iter, score, best$score))
    }
  }
  log
}

# ============================================================================
# Search Space Narrowing
# ============================================================================

#' Narrow a Parameter Space Around the Best Observed Results
#'
#' Creates a new parameter space centred on the best observed configurations
#' (zoom-in strategy).  For numeric/integer parameters the new range is
#' \code{mean(top) +/- shrink_factor * (old_range / 2)}.  For categorical
#' parameters only the categories that appeared in the top results are kept
#' (at least two choices are always retained).
#'
#' @param space A \code{param_space} object.
#' @param best_results A \code{data.frame} (output of \code{summarize_results})
#'   or a list of entry objects containing the most promising configurations.
#' @param shrink_factor Fraction of the old range retained on each side of the
#'   new centre.  Default 0.5 halves the range.
#' @return A new \code{param_space} object with narrowed bounds.
#' @export
narrow_param_space <- function(space, best_results, shrink_factor = 0.5) {
  # Accept either a data.frame (summarize_results output) or a list of entries
  if (is.data.frame(best_results)) {
    df <- best_results
  } else {
    # List of entry objects (e.g. log$entries)
    df <- do.call(rbind, lapply(best_results, function(e) {
      as.data.frame(e$params, stringsAsFactors = FALSE)
    }))
  }

  new_params <- lapply(space, function(p) {
    if (p$type == "categorical") {
      # Keep only the categories that appeared in the top results
      if (p$name %in% names(df)) {
        used <- unique(df[[p$name]])
        used <- intersect(p$choices, used)   # preserve original ordering
        # param_categorical requires at least 2 choices
        if (length(used) < 2) used <- p$choices
      } else {
        used <- p$choices
      }
      param_categorical(p$name, used)
    } else {
      # numeric / integer: centre on mean of top values
      if (p$name %in% names(df)) {
        vals     <- as.numeric(df[[p$name]])
        vals     <- vals[!is.na(vals)]
        center   <- mean(vals)
        old_half <- (p$upper - p$lower) / 2
        half     <- shrink_factor * old_half
        new_lower <- max(p$lower, center - half)
        new_upper <- min(p$upper, center + half)
        if (new_lower >= new_upper) {
          # Safety net: ensure a minimal range around the centre
          new_lower <- max(p$lower, center - old_half * 0.1)
          new_upper <- min(p$upper, center + old_half * 0.1)
          if (new_lower >= new_upper) {
            new_lower <- p$lower
            new_upper <- p$upper
          }
        }
      } else {
        new_lower <- p$lower
        new_upper <- p$upper
      }
      if (p$type == "integer") {
        param_integer(p$name,
                      max(p$lower, floor(new_lower)),
                      min(p$upper, ceiling(new_upper)))
      } else {
        param_numeric(p$name, new_lower, new_upper)
      }
    }
  })
  structure(new_params, class = "param_space")
}
