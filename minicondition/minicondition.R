## minicondition.R -------------------------------------------------------------
##
## A minimal, dependency-free reimplementation of rlang's `abort()`,
## `warn()`, and `inform()`: signal a classed condition (an error,
## warning, or message carrying a custom class, so callers can catch it
## specifically via `tryCatch()`/`withCallingHandlers()`), plus a small
## `assert()` helper built on top of `abort()`.
##
## Design notes:
## - Base R only, using base R's own condition system
##   (`structure()` + `stop()`/`warning()`/`message()`) rather than
##   `rlang::abort()`/`warn()`/`inform()`. Custom condition classes work
##   identically either way: `tryCatch(f(), my_class = handler)` catches
##   a condition of class `my_class` regardless of whether it was raised
##   via rlang or via a plain classed condition object passed to
##   `stop()`.
## - Exported functions prefixed `mcond_`; internal helper is
##   `.mcond_condition()`.
## - `class` defaults to `NULL` (no extra class beyond
##   error/warning/message/condition) rather than a package-specific
##   default -- unlike the internal helper this was adapted from, which
##   defaulted every condition to its own package's name (e.g.
##   `"emaxnls_error"`). A mini meant to be copied into any package
##   shouldn't bake in one package's identity as the default; supply
##   your own class explicitly when you want conditions to be
##   catchable by type.
## - `message` has no default (unlike the source it's adapted from,
##   which defaulted to placeholder text like `"emax_nls error"`) --
##   a generic placeholder message isn't useful to a caller either.
##
## Usage:
##   source("minicondition.R")
##   mcond_abort("Input must be positive.", class = "mypkg_invalid_input")
##   mcond_assert(x > 0, "x must be positive.", class = "mypkg_invalid_input")
##
##   tryCatch(
##     mcond_abort("bad input", class = "mypkg_invalid_input"),
##     mypkg_invalid_input = function(e) cat("caught:", conditionMessage(e), "\n")
##   )
##
## License: MIT (see LICENSE at the root of the minis repo). This file
## contains no code copied from {rlang}, only equivalent logic built on
## base R's condition system.

#' @noRd
.mcond_condition <- function(message, class, base_class) {
  structure(
    class = c(class, base_class, "condition"),
    list(message = message, call = NULL)
  )
}

#' Signal a classed error
#' @param message Error message.
#' @param class Optional character vector of extra classes, so the
#'   condition can be caught specifically via `tryCatch(expr, <class> =
#'   handler)`. Defaults to no extra class.
#' @export
mcond_abort <- function(message, class = NULL) {
  stop(.mcond_condition(message, class, "error"))
}

#' Signal a classed warning
#' @inheritParams mcond_abort
#' @export
mcond_warn <- function(message, class = NULL) {
  warning(.mcond_condition(message, class, "warning"))
}

#' Signal a classed message
#' @inheritParams mcond_abort
#' @export
mcond_inform <- function(message, class = NULL) {
  message(.mcond_condition(paste0(message, "\n"), class, "message"))
}

#' Abort with a classed error if a condition doesn't hold
#'
#' @param expr A logical vector. `NA` counts as a failure, same as
#'   `FALSE` (unlike a plain `if (any(expr == FALSE))`, which would
#'   error on `NA` with "missing value where TRUE/FALSE needed" instead
#'   of raising the intended assertion error).
#' @param message Error message used if the assertion fails.
#' @param class Optional character vector of extra classes for the
#'   resulting error condition.
#' @export
mcond_assert <- function(expr, message = "Assertion failed.", class = NULL) {
  if (anyNA(expr) || any(expr == FALSE)) mcond_abort(message, class)
}
