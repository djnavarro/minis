## minimap.R -------------------------------------------------------------
##
## A minimal, dependency-free reimplementation of purrr's core mapping
## functions: map(), map2(), imap(), walk(), iwalk(), and the type-stable
## map_dbl()/map_lgl()/map_chr() variants. Built entirely on lapply() and
## vapply().
##
## Design notes:
## - Base R only. No imports, no Suggests required.
## - All user-facing functions are prefixed `mmap_`; internals are
##   prefixed `.mmap_`, to avoid collisions when this file is copied
##   into an existing package's R/ directory.
## - Argument checking uses a small inlined `.mmap_assert()` built on
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
##   mmap_map(1:3, function(x) x + 1)
##   mmap_map_dbl(1:3, function(x) x + 1)
##
## License: MIT (see LICENSE at the root of the minis repo). This file
## contains no code copied from {purrr}, only equivalent logic.

# --- internal helpers -----------------------------------------------------

#' @noRd
.mmap_assert <- function(expr, message = "minimap error") {
  if (any(expr == FALSE)) stop(message, call. = FALSE)
}

# --- core mapping -----------------------------------------------------

#' Apply a function to each element of a list or vector
#' @param .x A list or atomic vector.
#' @param .f A function of one argument.
#' @return A list the same length as `.x`, with names preserved.
#' @export
mmap_map <- function(.x, .f) {
  out <- lapply(X = .x, FUN = .f)
  names(out) <- names(.x)
  out
}

#' Apply a function to each element, for its side effect
#'
#' Like [mmap_map()], but returns `.x` invisibly instead of the results.
#' @export
mmap_walk <- function(.x, .f) {
  mmap_map(.x, .f)
  invisible(.x)
}

#' Apply a function to pairs of elements from two lists/vectors
#' @param .x,.y Lists or atomic vectors of the same length.
#' @param .f A function of two arguments.
#' @export
mmap_map2 <- function(.x, .y, .f) {
  .mmap_assert(length(.x) == length(.y), "`.x` and `.y` must have the same length")
  lapply(X = seq_along(.x), FUN = function(i) .f(.x[[i]], .y[[i]]))
}

#' Apply a function to pairs of elements, for its side effect
#' @export
mmap_iwalk <- function(.x, .f) {
  .mmap_assert(!is.null(names(.x)), "`.x` must be named")
  mmap_map2(.x, names(.x), .f)
  invisible(.x)
}

#' Apply a function to each element together with its name
#' @param .x A named list or atomic vector.
#' @param .f A function of two arguments: the element, then its name.
#' @export
mmap_imap <- function(.x, .f) {
  .mmap_assert(!is.null(names(.x)), "`.x` must be named")
  out <- mmap_map2(.x, names(.x), .f)
  names(out) <- names(.x)
  out
}

# --- type-stable variants ------------------------------------------------

#' Type-stable variants of mmap_map()
#'
#' Like [mmap_map()], but return an atomic vector of the named type
#' instead of a list, via `vapply()`. Errors if `.f` doesn't return a
#' length-1 value of the expected type for every element.
#' @param .x A list or atomic vector.
#' @param .f A function of one argument.
#' @name mmap_map_dbl
NULL

#' @rdname mmap_map_dbl
#' @export
mmap_map_dbl <- function(.x, .f) vapply(X = .x, FUN = .f, FUN.VALUE = numeric(1L))

#' @rdname mmap_map_dbl
#' @export
mmap_map_lgl <- function(.x, .f) vapply(X = .x, FUN = .f, FUN.VALUE = logical(1L))

#' @rdname mmap_map_dbl
#' @export
mmap_map_chr <- function(.x, .f) vapply(X = .x, FUN = .f, FUN.VALUE = character(1L))
