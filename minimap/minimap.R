## minimap.R -------------------------------------------------------------
##
## A minimal, dependency-free reimplementation of purrr's core mapping
## functions: map(), map2(), imap(), walk(), iwalk(), and the type-stable
## map_dbl()/map_lgl()/map_chr() variants. Built entirely on lapply() and
## vapply().
##
## Design notes:
## - Base R only. No imports, no Suggests required.
## - All functions are dot-prefixed with the tag `.iter_` (not `.map_`,
##   even though the mini is named `minimap`) -- the tag names the
##   general iterate-over-a-list-or-vector family this mini covers (map
##   AND walk variants), since a tag literally named after only "map"
##   would misleadingly read as `walk`/`iwalk` being a special case of
##   `map`. There's no separate exported-vs-internal naming split; every
##   function here is treated as an implementation detail once copied
##   into a consuming package.
## - Argument checking uses a small inlined `.iter_assert()` built on
##   base `stop()`, not `rlang::abort()` -- deliberately simpler than
##   the internal helper this was adapted from, since pulling in rlang
##   purely for custom condition classes isn't worth it for a mini.
## - Deliberately excluded: pmap()/pmap_*(), map_if()/map_at()/map_at(),
##   list-column-aware behaviour, and purrr's richer
##   call-aware error messages -- this covers the common case of
##   "I want lapply()/vapply(), but want to write it as map()".
##
## Usage:
##   source("minimap.R")
##   .iter_map(1:3, function(x) x + 1)
##   .iter_map_dbl(1:3, function(x) x + 1)
##
## License: MIT (see LICENSE at the root of the minis repo). This file
## contains no code copied from {purrr}, only equivalent logic.

# --- internal helpers -----------------------------------------------------

#' @noRd
.iter_assert <- function(expr, message = "minimap error") {
  if (any(expr == FALSE)) stop(message, call. = FALSE)
}

# --- core mapping -----------------------------------------------------

#' Apply a function to each element of a list or vector
#' @param .x A list or atomic vector.
#' @param .f A function of one argument.
#' @return A list the same length as `.x`, with names preserved.
#' @export
.iter_map <- function(.x, .f) {
  out <- lapply(X = .x, FUN = .f)
  names(out) <- names(.x)
  out
}

#' Apply a function to each element, for its side effect
#'
#' Like [.iter_map()], but returns `.x` invisibly instead of the results.
#' @export
.iter_walk <- function(.x, .f) {
  .iter_map(.x, .f)
  invisible(.x)
}

#' Apply a function to pairs of elements from two lists/vectors
#' @param .x,.y Lists or atomic vectors of the same length.
#' @param .f A function of two arguments.
#' @export
.iter_map2 <- function(.x, .y, .f) {
  .iter_assert(length(.x) == length(.y), "`.x` and `.y` must have the same length")
  lapply(X = seq_along(.x), FUN = function(i) .f(.x[[i]], .y[[i]]))
}

#' Apply a function to pairs of elements, for its side effect
#' @export
.iter_iwalk <- function(.x, .f) {
  .iter_assert(!is.null(names(.x)), "`.x` must be named")
  .iter_map2(.x, names(.x), .f)
  invisible(.x)
}

#' Apply a function to each element together with its name
#' @param .x A named list or atomic vector.
#' @param .f A function of two arguments: the element, then its name.
#' @export
.iter_imap <- function(.x, .f) {
  .iter_assert(!is.null(names(.x)), "`.x` must be named")
  out <- .iter_map2(.x, names(.x), .f)
  names(out) <- names(.x)
  out
}

# --- type-stable variants ------------------------------------------------

#' Type-stable variants of .iter_map()
#'
#' Like [.iter_map()], but return an atomic vector of the named type
#' instead of a list, via `vapply()`. Errors if `.f` doesn't return a
#' length-1 value of the expected type for every element.
#' @param .x A list or atomic vector.
#' @param .f A function of one argument.
#' @name .iter_map_dbl
NULL

#' @rdname .iter_map_dbl
#' @export
.iter_map_dbl <- function(.x, .f) vapply(X = .x, FUN = .f, FUN.VALUE = numeric(1L))

#' @rdname .iter_map_dbl
#' @export
.iter_map_lgl <- function(.x, .f) vapply(X = .x, FUN = .f, FUN.VALUE = logical(1L))

#' @rdname .iter_map_dbl
#' @export
.iter_map_chr <- function(.x, .f) vapply(X = .x, FUN = .f, FUN.VALUE = character(1L))
