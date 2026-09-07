## minitable.R -------------------------------------------------------------
##
## A minimal, dependency-free reimplementation of a few tibble
## construction/coercion helpers: `tibble()`, `as_tibble()`,
## `rownames_to_column()`, `add_row()`.
##
## Design notes:
## - Base R only. Results are plain data.frames, not tibbles -- this
##   mini gives tibble-style *construction* ergonomics (in particular,
##   later columns can refer to earlier ones by name, e.g.
##   `.table_tibble(a = 1:3, b = a * 2)`), not tibble's printing,
##   stricter recycling-length validation, or class.
## - All functions are dot-prefixed with the tag `.table_` -- there's
##   no separate exported-vs-internal naming split, since every
##   function here is meant to be treated as an implementation detail
##   once copied into a consuming package.
## - IMPORTANT: the sequential-evaluation logic that makes cross-column
##   references work (`match.call()` + walking `...` argument by
##   argument) lives directly inside `.table_tibble()` and
##   `.table_add_row()`, rather than being factored into a shared
##   `...`-accepting helper. Forwarding `...` through an intermediate
##   function turns each argument into an opaque `..1`/`..2` pronoun
##   that resolves against the *original* caller's environment when
##   evaluated, not against a custom environment -- so a factored-out
##   helper silently breaks cross-column references (either erroring
##   with "object not found" or, worse, evaluating against the wrong
##   scope). This is also why the internal helper this was adapted from
##   (emaxnls's `.tibble()`, which *did* forward to a separate `.lst()`)
##   defensively banned cross-column references outright -- it was
##   working around this exact limitation, not just keeping behavior
##   consistent with real tibble.
## - `as.data.frame(..., check.names = FALSE)` is used throughout to
##   preserve tibble-style literal column names (e.g. a column named
##   `1:2`) instead of `as.data.frame()`'s default `make.names()`
##   sanitisation.
## - Deliberately excluded: list-columns, tibble's strict recycling
##   rules (only length-1-vs-N recycling is enforced, via
##   `as.data.frame()`'s own, more permissive rules), and an
##   opportunistic "use real tibble if installed" branch -- left out
##   for predictability, unlike the internal helper this was adapted
##   from, which deferred to real tibble when available.
##
## Usage:
##   source("minitable.R")
##   .table_tibble(a = 1:3, b = a * 2)
##   .table_add_row(mtcars, mpg = 99)
##   .table_rownames_to_column(mtcars, var = "model")
##
## License: MIT (see LICENSE at the root of the minis repo). Logic
## adapted from poorman (MIT licensed), not copied from {tibble}.

#' @noRd
.table_drop_dup_list <- function(x) {
  list_names <- names(x)
  if (identical(list_names, unique(list_names))) return(x)
  count <- table(list_names)
  dupes <- names(count[count > 1])
  uniques <- names(count[count == 1])
  to_drop <- do.call(c, lapply(dupes, function(nm) {
    matches <- which(list_names == nm)
    matches[-length(matches)]
  }))
  x[uniques] <- Filter(Negate(is.null), x[uniques])
  x[-to_drop]
}

#' Build a data frame column by column, sequentially
#'
#' Like `tibble::tibble()`, later columns can refer to earlier ones by
#' name (`.table_tibble(a = 1:3, b = a * 2)`). Unlike a real tibble, the
#' result is a plain `data.frame`, and recycling/type validation follows
#' whatever `as.data.frame()` does, not tibble's stricter rules.
#'
#' @param ... Name-value pairs of columns. `NULL`/length-0 values become
#'   `NA`. Unnamed arguments are named after their deparsed expression,
#'   as in `tibble::tibble()`.
#' @export
.table_tibble <- function(...) {
  fn_call <- match.call()
  list_to_eval <- as.list(fn_call)[-1]
  out <- vector(mode = "list", length = length(list_to_eval))
  names(out) <- names(list_to_eval)
  exprs <- lapply(substitute(list(...)), deparse)[-1]
  for (element in seq_along(list_to_eval)) {
    value <- list_to_eval[[element]]
    if (is.language(value)) {
      value <- eval(
        value,
        envir = if (element == 1L) list_to_eval else .table_drop_dup_list(out[seq_len(element - 1)])
      )
    }
    if (is.null(value)) {
      out[element] <- list(NULL)
    } else {
      out[[element]] <- value
    }
    invalid_name <- is.null(names(out)[element]) || is.na(names(out)[element]) || names(out)[element] == ""
    if (invalid_name) names(out)[element] <- exprs[[element]]
  }
  out <- lapply(out, function(x) if (is.null(x) || length(x) == 0) NA else x)
  as.data.frame(out, check.names = FALSE)
}

#' Coerce to a data frame
#' @param x An object coercible via `as.data.frame()`.
#' @param ... Passed on to `as.data.frame()`.
#' @export
.table_as_tibble <- function(x, ...) as.data.frame(x, ..., check.names = FALSE)

#' Move row names into an explicit column
#'
#' A no-op if `.data` has no row names, or only the default sequential
#' ones (`"1"`, `"2"`, ...).
#' @param .data A data frame.
#' @param var Name of the new column.
#' @export
.table_rownames_to_column <- function(.data, var = "rowname") {
  rn <- rownames(.data)
  is_default_rn <- is.null(rn) || identical(rn, as.character(seq_len(NROW(.data))))
  if (is_default_rn) return(.data)
  rownames(.data) <- NULL
  df_col <- data.frame(rn)
  names(df_col) <- var
  cbind(df_col, .data)
}

#' Append a row to a data frame
#'
#' @param .data A data frame.
#' @param ... Name-value pairs for the new row, matched to `.data`'s
#'   columns. Supports the same sequential cross-reference evaluation
#'   as `.table_tibble()`.
#' @export
.table_add_row <- function(.data, ...) {
  fn_call <- match.call(expand.dots = FALSE)
  list_to_eval <- fn_call[["..."]]
  out <- vector(mode = "list", length = length(list_to_eval))
  names(out) <- names(list_to_eval)
  exprs <- lapply(substitute(list(...)), deparse)[-1]
  for (element in seq_along(list_to_eval)) {
    value <- list_to_eval[[element]]
    if (is.language(value)) {
      value <- eval(
        value,
        envir = if (element == 1L) list_to_eval else .table_drop_dup_list(out[seq_len(element - 1)])
      )
    }
    if (is.null(value)) {
      out[element] <- list(NULL)
    } else {
      out[[element]] <- value
    }
    invalid_name <- is.null(names(out)[element]) || is.na(names(out)[element]) || names(out)[element] == ""
    if (invalid_name) names(out)[element] <- exprs[[element]]
  }
  out <- lapply(out, function(x) if (is.null(x) || length(x) == 0) NA else x)
  new_row <- as.data.frame(out, check.names = FALSE)
  rbind(.data, new_row)
}
