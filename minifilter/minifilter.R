## minifilter.R -------------------------------------------------------------
##
## A minimal, dependency-free reimplementation of dplyr's `filter()`:
## subset the rows of a data frame using unquoted conditions evaluated
## in the data frame's own scope.
##
## Design notes:
## - Base R only, adapted from poorman's filter()/dots.R
##   (https://github.com/nathaneastwood/poorman), itself dependency-free.
## - The sole exported function is a bare dot-name, `.filter()` -- not
##   tagged, since this mini's entire purpose already is "filter" and a
##   `.filter_filter()` name would stutter. The internal helper keeps a
##   short `.filter_` tag (`.filter_dotdotdot()`) since generic helper
##   names are the ones actually at risk of colliding with something
##   else once copied into a consuming package.
## - Multiple conditions are combined with logical AND, same as
##   `dplyr::filter(df, cond1, cond2)`. Rows where the combined
##   condition is `NA` are dropped, matching dplyr's semantics.
## - Deliberately excluded: grouped filtering (dplyr's `.by`/prior
##   `group_by()`), `.preserve`, tidyselect-style helpers -- this covers
##   plain, ungrouped row filtering only.
##
## Usage:
##   source("minifilter.R")
##   .filter(mtcars, cyl == 4, mpg > 25)
##
## License: MIT (see LICENSE at the root of the minis repo). Logic
## adapted from poorman (MIT licensed), not copied from {dplyr}.

#' @noRd
.filter_dotdotdot <- function(...) {
  eval(substitute(alist(...)))
}

#' Filter rows of a data frame by unquoted conditions
#'
#' @param .data A data frame.
#' @param ... Logical expressions, evaluated in the scope of `.data`
#'   (columns can be referred to by bare name). Multiple expressions are
#'   combined with `&`.
#' @return A data frame containing only rows where all conditions are
#'   `TRUE`. Rows where the combined condition is `NA` are dropped, as
#'   in dplyr. Calling with no conditions returns `.data` unchanged.
#' @export
.filter <- function(.data, ...) {
  conditions <- .filter_dotdotdot(...)
  if (length(conditions) == 0L) return(.data)
  rows <- lapply(
    conditions,
    function(cond, frame) eval(cond, .data, frame),
    frame = parent.frame()
  )
  rows <- Reduce("&", rows)
  .data[rows & !is.na(rows), ]
}
