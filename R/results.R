# ============================================================================
# autoresearch - Results Tracking
# ============================================================================

#' Create a New Results Log
#'
#' @return An empty \code{results_log} object.
#' @export
new_results_log <- function() {
  structure(
    list(
      entries    = list(),
      created_at = Sys.time()
    ),
    class = "results_log"
  )
}

#' Add a Result Entry
#'
#' @param log A \code{results_log}.
#' @param params Named list of parameters.
#' @param score Numeric score for this run.
#' @param extra Optional named list of additional data to store.
#' @return The updated \code{results_log}.
#' @export
add_result <- function(log, params, score, extra = list()) {
  entry <- list(
    params    = params,
    score     = score,
    timestamp = Sys.time(),
    extra     = extra
  )
  log$entries <- c(log$entries, list(entry))
  log
}

#' Get the Best Result
#'
#' @param log A \code{results_log}.
#' @param minimize If \code{TRUE}, the entry with the lowest score wins.
#' @return A list with \code{params}, \code{score}, and \code{index}.
#' @export
best_result <- function(log, minimize = TRUE) {
  if (length(log$entries) == 0) {
    return(list(params = list(), score = NA_real_, index = NA_integer_))
  }
  scores <- vapply(log$entries, function(e) e$score, numeric(1))
  valid  <- which(!is.na(scores))
  if (length(valid) == 0) {
    return(list(params = list(), score = NA_real_, index = NA_integer_))
  }
  idx <- valid[if (minimize) which.min(scores[valid]) else which.max(scores[valid])]
  list(
    params = log$entries[[idx]]$params,
    score  = log$entries[[idx]]$score,
    index  = idx
  )
}

#' Summarize Optimization Results
#'
#' @param log A \code{results_log}.
#' @return A data.frame with one row per evaluation.
#' @export
summarize_results <- function(log) {
  if (length(log$entries) == 0) {
    return(data.frame())
  }
  rows <- lapply(log$entries, function(e) {
    param_df <- as.data.frame(e$params, stringsAsFactors = FALSE)
    param_df$score     <- e$score
    param_df$timestamp <- e$timestamp
    param_df
  })
  do.call(rbind, rows)
}

#' Save Results to a TSV File
#'
#' @param log A \code{results_log}.
#' @param path File path.
#' @export
save_results <- function(log, path = "results.tsv") {
  df <- summarize_results(log)
  write.table(df, file = path, sep = "\t", row.names = FALSE, quote = FALSE)
  message("Results saved to ", path)
}

#' Load Results from a TSV File
#'
#' @param path File path.
#' @return A data.frame.
#' @export
load_results <- function(path = "results.tsv") {
  read.delim(path, stringsAsFactors = FALSE)
}

#' Plot Optimization Progress
#'
#' Creates a simple line plot of scores over iterations.
#'
#' @param log A \code{results_log}.
#' @param minimize If \code{TRUE}, tracks the running minimum.
#' @param main Plot title.
#' @export
plot_optimization <- function(log, minimize = TRUE, main = "Optimization Progress") {
  scores <- vapply(log$entries, function(e) e$score, numeric(1))
  best_so_far <- if (minimize) cummin(scores) else cummax(scores)

  plot(seq_along(scores), scores,
       type = "p", pch = 16, col = "grey60", cex = 0.6,
       xlab = "Iteration", ylab = "Score", main = main)
  lines(seq_along(best_so_far), best_so_far, col = "steelblue", lwd = 2)
  legend("topright", legend = c("Score", "Best so far"),
         col = c("grey60", "steelblue"), pch = c(16, NA), lty = c(NA, 1),
         lwd = c(NA, 2), bty = "n")
}
