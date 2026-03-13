# ============================================================================
# autoresearch - Evaluation Helpers
# ============================================================================

#' Evaluate a Model with Cross-Validation
#'
#' Fits a model-building function on training folds and evaluates on hold-out
#' folds.  Returns the mean score across folds.
#'
#' @param data A data.frame.
#' @param target Name of the target column (character).
#' @param build_model A function \code{function(train_data, target)} that
#'   returns a fitted model object.
#' @param score_fn A function \code{function(model, test_data, target)} that
#'   returns a numeric score (lower is better by default).
#' @param n_folds Number of cross-validation folds.
#' @param seed Random seed.
#' @return Mean score across folds.
#' @export
#' @examples
#' score <- evaluate_model(
#'   data   = mtcars,
#'   target = "mpg",
#'   build_model = function(train, tgt) lm(as.formula(paste(tgt, "~ .")), train),
#'   score_fn    = function(mod, test, tgt) {
#'     preds <- predict(mod, test)
#'     sqrt(mean((test[[tgt]] - preds)^2))
#'   }
#' )
evaluate_model <- function(data, target, build_model, score_fn,
                           n_folds = 5, seed = 42) {
  set.seed(seed)
  n    <- nrow(data)
  folds <- sample(rep(seq_len(n_folds), length.out = n))
  scores <- numeric(n_folds)

  for (k in seq_len(n_folds)) {
    train_data <- data[folds != k, , drop = FALSE]
    test_data  <- data[folds == k, , drop = FALSE]

    model <- tryCatch(
      build_model(train_data, target),
      error = function(e) {
        warning("Fold ", k, " failed: ", conditionMessage(e))
        NULL
      }
    )

    if (is.null(model)) {
      scores[k] <- NA_real_
      next
    }

    scores[k] <- tryCatch(
      score_fn(model, test_data, target),
      error = function(e) {
        warning("Scoring fold ", k, " failed: ", conditionMessage(e))
        NA_real_
      }
    )
  }

  mean(scores, na.rm = TRUE)
}

#' Evaluate an R Script and Capture a Numeric Result
#'
#' Sources an R script in a temporary environment and captures its return
#' value.  The script must assign its result to a variable called
#' \code{.result}.
#'
#' @param script_path Path to the R script.
#' @param params Named list of parameters that will be available as variables
#'   inside the script.
#' @param time_budget Maximum seconds the script may run.
#' @return The numeric value of \code{.result} from the script, or \code{NA}
#'   on error/timeout.
#' @export
#' @examples
#' # Create a small test script
#' tmp <- tempfile(fileext = ".R")
#' writeLines(c(
#'   ".result <- (alpha - 3)^2 + (beta + 1)^2"
#' ), tmp)
#' score <- evaluate_script(tmp, params = list(alpha = 2.5, beta = -0.8))
#' cat("Score:", score, "\n")
evaluate_script <- function(script_path, params = list(), time_budget = 60) {
  stopifnot(file.exists(script_path))
  env <- new.env(parent = globalenv())

  # Inject parameters into the script environment
  for (nm in names(params)) {
    assign(nm, params[[nm]], envir = env)
  }

  result <- with_time_budget(time_budget, {
    tryCatch({
      source(script_path, local = env)
      if (exists(".result", envir = env)) {
        as.numeric(get(".result", envir = env))
      } else {
        warning("Script did not assign .result")
        NA_real_
      }
    }, error = function(e) {
      warning("Script error: ", conditionMessage(e))
      NA_real_
    })
  })

  result
}
