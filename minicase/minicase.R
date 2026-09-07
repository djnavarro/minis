## minicase.R -------------------------------------------------------------
##
## A minimal, dependency-free reimplementation of dplyr's `case_when()`:
## vectorised if/else via a sequence of two-sided formulas.
##
## Design notes:
## - Base R only, adapted from poorman's case_when()/replace_with()
##   (https://github.com/nathaneastwood/poorman), itself dependency-free.
## - The sole exported function is a bare dot-name, `.case_when()` -- not
##   additionally tagged, since this mini's entire purpose already is
##   "case_when" and a `.case_case_when()` name would stutter. The
##   internal helpers keep a short `.case_` tag (e.g. `.case_replace_with()`)
##   since generic helper names are the ones actually at risk of colliding
##   with something else once copied into a consuming package.
## - Conditions and values are evaluated in the caller's environment
##   (there's no data-masking here), so reference data frame columns via
##   `df$col`, or wrap the call in `with(df, .case_when(...))`.
## - Deliberately excluded: dplyr's `.default`, `.ptype`, `.size`
##   arguments -- this covers the plain "match conditions in order,
##   first match wins, unmatched positions are NA" case.
##
## Usage:
##   source("minicase.R")
##   x <- c(-5, 0, 5, NA)
##   .case_when(
##     x < 0  ~ "negative",
##     x == 0 ~ "zero",
##     x > 0  ~ "positive",
##     TRUE   ~ "unknown"
##   )
##
## License: MIT (see LICENSE at the root of the minis repo). Logic
## adapted from poorman (MIT licensed), not copied from {dplyr}.

#' Vectorised if/else across a sequence of formulas
#'
#' @param ... A sequence of two-sided formulas, `condition ~ value`. The
#'   first formula whose `condition` is `TRUE` (and not already matched
#'   by an earlier formula) determines the output for that position.
#'   Use `TRUE ~ value` as a catch-all default at the end.
#' @return A vector the same length as the (recycled) conditions/values,
#'   with `NA` in positions matched by no condition.
#' @export
.case_when <- function(...) {
  fs <- list(...)
  lapply(fs, function(x) {
    if (!inherits(x, "formula")) stop("`.case_when()` requires formula inputs.")
  })
  n <- length(fs)
  if (n == 0L) stop("No cases provided.")
  query <- vector("list", n)
  value <- vector("list", n)
  default_env <- parent.frame()
  for (i in seq_len(n)) {
    query[[i]] <- eval(fs[[i]][[2]], envir = default_env)
    value[[i]] <- eval(fs[[i]][[3]], envir = default_env)
    if (!is.logical(query[[i]])) stop(fs[[i]][[2]], " does not return a `logical` vector.")
  }
  m <- .case_validate_length(query, value, fs)
  out <- value[[1]][rep(NA_integer_, m)]
  replaced <- rep(FALSE, m)
  for (i in seq_len(n)) {
    out <- .case_replace_with(out, query[[i]] & !replaced, value[[i]], NULL)
    replaced <- replaced | (query[[i]] & !is.na(query[[i]]))
  }
  out
}

#' @noRd
.case_validate_length <- function(query, value, fs) {
  lhs_lengths <- lengths(query)
  rhs_lengths <- lengths(value)
  all_lengths <- unique(c(lhs_lengths, rhs_lengths))
  if (length(all_lengths) <= 1L) return(all_lengths[[1L]])
  non_atomic_lengths <- all_lengths[all_lengths != 1L]
  len <- non_atomic_lengths[[1L]]
  if (length(non_atomic_lengths) == 1L) return(len)
  inconsistent_lengths <- non_atomic_lengths[-1L]
  lhs_problems <- lhs_lengths %in% inconsistent_lengths
  rhs_problems <- rhs_lengths %in% inconsistent_lengths
  problems <- lhs_problems | rhs_problems
  if (any(problems)) {
    stop(
      "The following formulas must be length ", len, " or 1, not ",
      paste(inconsistent_lengths, collapse = ", "), ".\n    ",
      paste(fs[problems], collapse = "\n    ")
    )
  }
}

#' @noRd
.case_replace_with <- function(x, i, val, arg_name) {
  if (is.null(val)) return(x)
  .case_check_length(val, x, arg_name)
  .case_check_type(val, x, arg_name)
  .case_check_class(val, x, arg_name)
  i[is.na(i)] <- FALSE
  if (length(val) == 1L) {
    x[i] <- val
  } else {
    x[i] <- val[i]
  }
  x
}

#' @noRd
.case_check_length <- function(x, y, arg_name) {
  length_x <- length(x)
  length_y <- length(y)
  if (all(length_x %in% c(1L, length_y))) return(invisible(NULL))
  if (length_y == 1) {
    stop(arg_name, " must be length 1, not ", length_x)
  } else {
    stop(arg_name, " must be length ", length_y, " or 1, not ", length_x)
  }
}

#' @noRd
.case_check_type <- function(x, y, arg_name) {
  x_type <- typeof(x)
  y_type <- typeof(y)
  if (identical(x_type, y_type)) return(invisible(NULL))
  stop(arg_name, " must be `", y_type, "`, not `", x_type, "`")
}

#' @noRd
.case_check_class <- function(x, y, arg_name) {
  if (!is.object(x)) return(invisible(NULL))
  exp_classes <- class(y)
  out_classes <- class(x)
  if (identical(out_classes, exp_classes)) return(invisible(NULL))
  stop(arg_name, " must have class `", exp_classes, "`, not class `", out_classes, "`")
}
