## minijoin.R -------------------------------------------------------------
##
## A minimal, dependency-free reimplementation of dplyr's mutating joins
## (`inner_join()`, `left_join()`, `right_join()`, `full_join()`), built
## on base `merge()`.
##
## Design notes:
## - Base R only, adapted from poorman's joins.R
##   (https://github.com/nathaneastwood/poorman), itself dependency-free.
## - Exported functions prefixed `mjoin_`; internal helper `.mjoin_worker()`.
## - Unlike dplyr, `by` must always be supplied explicitly -- there is
##   no auto-detection of common columns. This avoids a class of silent
##   bugs and keeps the implementation simple.
## - Row order matches `x`'s original row order (`merge()` does not
##   guarantee this on its own); a `.join_id` column is added and
##   removed internally to restore it.
## - Deliberately excluded: dplyr's `relationship`, `multiple`,
##   `unmatched` validation arguments -- this covers plain two-table
##   joins only.
##
## Usage:
##   source("minijoin.R")
##   bands <- data.frame(band = c("Beatles", "Who"), founded = c(1960, 1964))
##   albums <- data.frame(band = c("Beatles", "Kinks"), album = c("Abbey Road", "Arthur"))
##   mjoin_inner_join(bands, albums, by = "band")
##   mjoin_left_join(bands, albums, by = "band")
##
## License: MIT (see LICENSE at the root of the minis repo). Logic
## adapted from poorman (MIT licensed), not copied from {dplyr}.

#' @noRd
.mjoin_worker <- function(x, y, by, suffix, keep, na_matches, ...) {
  na_matches <- match.arg(arg = na_matches, choices = c("na", "never"), several.ok = FALSE)
  incomparables <- if (na_matches == "never") NA else NULL
  x[, ".join_id"] <- seq_len(nrow(x))
  merged <- if (is.null(names(by))) {
    merge(x = x, y = y, by = by, suffixes = suffix, incomparables = incomparables, ...)
  } else {
    merge(x = x, y = y, by.x = names(by), by.y = by, suffixes = suffix, incomparables = incomparables, ...)
  }
  merged <- merged[order(merged[, ".join_id"]), colnames(merged) != ".join_id", drop = FALSE]
  if (isTRUE(keep)) {
    keep_pos <- match(by, names(merged))
    x_by <- paste0(by, suffix[1L])
    colnames(merged)[keep_pos] <- x_by
    merged[, paste0(by, suffix[2L])] <- merged[, x_by]
  }
  rownames(merged) <- NULL
  merged
}

#' Inner join: keep rows present in both `x` and `y`
#'
#' @param x,y Data frames to join.
#' @param by Column name(s) to join on. Must always be supplied
#'   explicitly. Use a named character vector (`c("a" = "b")`) to join
#'   on differently-named columns.
#' @param suffix Length-2 character vector of suffixes applied to
#'   overlapping non-join column names.
#' @param ... Passed on to `merge()`.
#' @param na_matches `"na"` (default) matches `NA` to `NA`, as in
#'   dplyr/SQL joins; `"never"` never matches `NA` to anything.
#' @export
mjoin_inner_join <- function(x, y, by, suffix = c(".x", ".y"), ..., na_matches = c("na", "never")) {
  .mjoin_worker(x = x, y = y, by = by, suffix = suffix, sort = FALSE, ..., keep = FALSE, na_matches = na_matches)
}

#' Left join: keep all rows of `x`
#' @inheritParams mjoin_inner_join
#' @param keep Keep both join columns (suffixed) rather than collapsing
#'   them into one.
#' @export
mjoin_left_join <- function(x, y, by, suffix = c(".x", ".y"), ..., keep = FALSE, na_matches = c("na", "never")) {
  .mjoin_worker(x = x, y = y, by = by, suffix = suffix, all.x = TRUE, ..., keep = keep, na_matches = na_matches)
}

#' Right join: keep all rows of `y`
#' @inheritParams mjoin_left_join
#' @export
mjoin_right_join <- function(x, y, by, suffix = c(".x", ".y"), ..., keep = FALSE, na_matches = c("na", "never")) {
  .mjoin_worker(x = x, y = y, by = by, suffix = suffix, all.y = TRUE, ..., keep = keep, na_matches = na_matches)
}

#' Full join: keep all rows of both `x` and `y`
#' @inheritParams mjoin_left_join
#' @export
mjoin_full_join <- function(x, y, by, suffix = c(".x", ".y"), ..., keep = FALSE, na_matches = c("na", "never")) {
  .mjoin_worker(x = x, y = y, by = by, suffix = suffix, all = TRUE, ..., keep = keep, na_matches = na_matches)
}
