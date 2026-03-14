# ============================================================================
# autoresearch - Research Agent
# ============================================================================

#' Adaptive Multi-Round Research Agent
#'
#' Runs multiple optimization rounds, progressively narrowing the search space
#' toward the most promising regions (exploration -> zoom-in strategy).  When
#' no improvement is observed for several consecutive rounds the search space is
#' reset to the original to escape local optima.
#'
#' @param objective A function that accepts a named list of parameters and
#'   returns a single numeric score.
#' @param space A parameter space created with \code{create_param_space}.
#' @param n_rounds Number of optimization rounds (default 5).
#' @param strategies Character vector of strategies to use, cycling across
#'   rounds.  Allowed values: \code{"random"}, \code{"bayesian"}.
#'   Round 1 always uses \code{"random"} for broad initial exploration.
#' @param n_iter_per_round Number of objective evaluations per round
#'   (default 50).
#' @param top_fraction Fraction of the best results used to compute the new
#'   search space centre (default 0.10 = top 10\%).
#' @param shrink_factor Space narrowing factor per round (default 0.5).
#' @param stagnation_rounds Number of consecutive rounds without improvement
#'   after which the search space is reset (default 2).
#' @param minimize If \code{TRUE}, lower scores are better.
#' @param seed Optional random seed for reproducibility.
#' @param verbose Print progress messages.
#' @return A list with:
#'   \describe{
#'     \item{best_params}{Best parameter configuration found.}
#'     \item{best_score}{Best score found.}
#'     \item{rounds}{List of \code{results_log} objects, one per round.}
#'     \item{strategy_log}{Strategy used in each round.}
#'     \item{improvement_history}{Best score after each round.}
#'     \item{search_space_history}{Search space at the start of each round.}
#'   }
#' @export
#' @examples
#' # Ackley function with global minimum at (0, 0)
#' ackley <- function(params) {
#'   x <- params$x; y <- params$y
#'   -20 * exp(-0.2 * sqrt(0.5 * (x^2 + y^2))) -
#'     exp(0.5 * (cos(2 * pi * x) + cos(2 * pi * y))) + exp(1) + 20
#' }
#' space <- create_param_space(
#'   param_numeric("x", -5, 5),
#'   param_numeric("y", -5, 5)
#' )
#' agent_result <- research_agent(ackley, space, n_rounds = 3,
#'                                n_iter_per_round = 30, seed = 42,
#'                                verbose = FALSE)
#' cat("Bester Score:", agent_result$best_score, "\n")
research_agent <- function(objective, space,
                           n_rounds          = 5,
                           strategies        = c("random", "bayesian"),
                           n_iter_per_round  = 50,
                           top_fraction      = 0.10,
                           shrink_factor     = 0.5,
                           stagnation_rounds = 2,
                           minimize          = TRUE,
                           seed              = NULL,
                           verbose           = TRUE) {

  if (!is.null(seed)) set.seed(seed)
  stopifnot(n_rounds >= 1, n_iter_per_round >= 1)
  stopifnot(all(strategies %in% c("random", "bayesian")))

  original_space   <- space
  current_space    <- space

  rounds_log          <- vector("list", n_rounds)
  strategy_log        <- character(n_rounds)
  improvement_history <- numeric(n_rounds)
  space_history       <- vector("list", n_rounds)

  global_best_score  <- if (minimize) Inf else -Inf
  global_best_params <- list()
  stagnation_count   <- 0L

  for (r in seq_len(n_rounds)) {
    space_history[[r]] <- current_space

    # Determine strategy: round 1 always uses random search for broad exploration
    if (r == 1L) {
      strategy <- "random"
    } else {
      strategy <- strategies[((r - 2L) %% length(strategies)) + 1L]
    }
    strategy_log[r] <- strategy

    if (verbose) {
      message(sprintf(
        "\n[Agent] Round %d/%d  |  Strategy: %s  |  Iterations: %d",
        r, n_rounds, strategy, n_iter_per_round
      ))
    }

    # Run search for this round
    round_log <- if (strategy == "bayesian") {
      bayesian_search(objective, current_space,
                      n_iter    = n_iter_per_round,
                      # Use ~20% of iterations as random warm-up for the GP
                      n_initial = max(3L, n_iter_per_round %/% 5L),
                      minimize  = minimize,
                      verbose   = verbose)
    } else {
      random_search(objective, current_space,
                    n_iter   = n_iter_per_round,
                    minimize = minimize,
                    verbose  = verbose)
    }

    rounds_log[[r]] <- round_log

    # Best result from this round
    round_best <- best_result(round_log, minimize = minimize)

    # Update global best
    improved <- if (minimize) {
      !is.na(round_best$score) && round_best$score < global_best_score
    } else {
      !is.na(round_best$score) && round_best$score > global_best_score
    }

    if (improved) {
      global_best_score  <- round_best$score
      global_best_params <- round_best$params
      stagnation_count   <- 0L
    } else {
      stagnation_count <- stagnation_count + 1L
    }

    improvement_history[r] <- global_best_score

    if (verbose) {
      message(sprintf(
        "[Agent] Round %d done  |  Round best: %.6f  |  Global best: %.6f",
        r, round_best$score, global_best_score
      ))
    }

    # Adapt search space for the next round (only if more rounds follow)
    if (r < n_rounds) {
      if (stagnation_count >= stagnation_rounds) {
        # Stagnation detected: reset search space to original for re-exploration
        if (verbose)
          message(sprintf(
            "[Agent] Stagnation detected (%d rounds) – resetting search space.",
            stagnation_count
          ))
        current_space    <- original_space
        stagnation_count <- 0L
      } else {
        # Improvement: narrow search space around the best results
        all_entries <- round_log$entries
        valid_entries <- Filter(function(e) !is.na(e$score), all_entries)

        if (length(valid_entries) >= 2L) {
          scores <- vapply(valid_entries, function(e) e$score, numeric(1))
          n_top  <- max(1L, ceiling(length(valid_entries) * top_fraction))
          if (minimize) {
            top_idx <- order(scores)[seq_len(n_top)]
          } else {
            top_idx <- order(scores, decreasing = TRUE)[seq_len(n_top)]
          }
          top_entries <- valid_entries[top_idx]

          top_df <- do.call(rbind, lapply(top_entries, function(e) {
            as.data.frame(e$params, stringsAsFactors = FALSE)
          }))

          current_space <- tryCatch(
            narrow_param_space(current_space, top_df,
                               shrink_factor = shrink_factor),
            error = function(e) current_space
          )
        }
      }
    }
  }

  if (verbose) {
    message(sprintf(
      "\n[Agent] Done! Best score: %.6f after %d rounds.",
      global_best_score, n_rounds
    ))
  }

  list(
    best_params         = global_best_params,
    best_score          = global_best_score,
    rounds              = rounds_log,
    strategy_log        = strategy_log,
    improvement_history = improvement_history,
    search_space_history = space_history
  )
}
