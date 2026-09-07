## ministr.R -----------------------------------------------------------------
##
## A minimal, dependency-free reimplementation of stringr's basic string
## manipulation verbs -- padding, trimming, whitespace squishing,
## substrings, length, case conversion, duplication, concatenation, and
## wrapping.
##
## Design notes:
## - Base R only, adapted from stringr's basic manipulation functions
##   (https://stringr.tidyverse.org), itself a thin wrapper around
##   stringi/ICU. This mini reimplements the same *behaviour* using only
##   base R string primitives -- no regex-engine dependency, no ICU, no
##   locale awareness.
## - All functions are dot-prefixed with the tag `.str_` -- there's no
##   separate exported-vs-internal naming split, since every function
##   here is meant to be treated as an implementation detail once copied
##   into a consuming package.
## - Deliberate fix relative to naive base-R wrapping: `.str_c()` and
##   `.str_pad()` propagate `NA` the way stringr does (an `NA` anywhere
##   in the inputs to a given position makes that position's output
##   `NA`), unlike base `paste0()`, which coerces `NA` to the literal
##   string `"NA"`.
## - Deliberately excluded:
##     - Locale-aware case conversion/collation. `.str_to_upper()` /
##       `.str_to_lower()` are just `toupper()`/`tolower()`, and
##       `.str_to_title()` uses ASCII word-boundary matching (`\\b`) to
##       find word starts, not stringi's Unicode word-break algorithm --
##       fine for ASCII/Latin text, unreliable for scripts without
##       whitespace-delimited words.
##     - `str_sub<-`, stringr's assignment form of substring replacement.
##     - `str_order()`/`str_sort()` (locale-aware sorting) and
##       `str_glue()` (templating) -- out of scope for this mini.
##
## Usage:
##   source("ministr.R")
##   .str_pad("7", 3, pad = "0")
##   .str_squish("  too   much   space  ")
##   .str_sub("hello world", -5, -1)
##   .str_to_title("the quick brown fox")
##   .str_c("a", c("x", "y"), sep = "-")
##
## License: MIT (see LICENSE at the root of the minis repo). Logic
## adapted from stringr (MIT licensed), not copied from it.

#' Pad a string to a fixed width
#'
#' @param string Character vector.
#' @param width Minimum field width (integer). Strings already at least
#'   this wide are returned unchanged.
#' @param side Which side(s) to pad: `"left"` (default), `"right"`, or
#'   `"both"` (as evenly as possible, with the extra padding character,
#'   if any, on the right).
#' @param pad A single padding character (default `" "`).
#' @return A character vector the same length as the recycled inputs.
#' @export
.str_pad <- function(string, width, side = c("left", "right", "both"), pad = " ") {
  side <- match.arg(side)
  if (length(pad) != 1L || nchar(pad) != 1L) stop("`pad` must be a single character.")
  n <- max(length(string), length(width))
  string <- rep_len(string, n)
  width <- rep_len(width, n)
  needed <- pmax(width - nchar(string), 0L)
  needed[is.na(needed)] <- 0L
  out <- switch(
    side,
    left = paste0(strrep(pad, needed), string),
    right = paste0(string, strrep(pad, needed)),
    both = {
      left_n <- needed %/% 2L
      right_n <- needed - left_n
      paste0(strrep(pad, left_n), string, strrep(pad, right_n))
    }
  )
  out[is.na(string)] <- NA_character_
  out
}

#' Trim leading/trailing whitespace
#'
#' @param string Character vector.
#' @param side Which side(s) to trim: `"both"` (default), `"left"`, or
#'   `"right"`.
#' @return A character vector the same length as `string`.
#' @export
.str_trim <- function(string, side = c("both", "left", "right")) {
  side <- match.arg(side)
  trimws(string, which = side)
}

#' Trim whitespace and collapse internal runs of whitespace to one space
#'
#' @param string Character vector.
#' @return A character vector the same length as `string`.
#' @export
.str_squish <- function(string) {
  gsub("\\s+", " ", trimws(string, which = "both"))
}

#' Extract substrings by (possibly negative) character position
#'
#' Negative `start`/`end` values count from the end of the string, as in
#' stringr (`-1` is the last character). Out-of-range positions are
#' clamped rather than erroring.
#'
#' @param string Character vector.
#' @param start,end Integer vectors of start/end positions (inclusive),
#'   recycled against `string`. Default to the whole string.
#' @return A character vector the same length as the recycled inputs.
#' @export
.str_sub <- function(string, start = 1L, end = -1L) {
  n <- max(length(string), length(start), length(end))
  string <- rep_len(string, n)
  start <- rep_len(as.integer(start), n)
  end <- rep_len(as.integer(end), n)
  len <- nchar(string)
  start <- ifelse(start < 0L, pmax(len + start + 1L, 1L), pmax(start, 1L))
  end <- ifelse(end < 0L, len + end + 1L, pmin(end, len))
  out <- substr(string, start, end)
  out[!is.na(start) & !is.na(end) & start > end] <- ""
  out[is.na(string)] <- NA_character_
  out
}

#' Length of a string, in characters
#'
#' @param string Character vector.
#' @return An integer vector the same length as `string`, `NA` where
#'   `string` is `NA`.
#' @export
.str_length <- function(string) {
  nchar(string, type = "chars", keepNA = TRUE)
}

#' Convert to upper/lower case
#'
#' @param string Character vector.
#' @return A character vector the same length as `string`.
#' @export
.str_to_upper <- function(string) toupper(string)

#' @rdname dot-str_to_upper
#' @export
.str_to_lower <- function(string) tolower(string)

#' Convert to title case
#'
#' Lower-cases the whole string, then upper-cases the first letter of
#' each ASCII word (a maximal run of letters/digits). Word boundaries are
#' found with the regex `\\b`, not a Unicode-aware word-break algorithm.
#'
#' @param string Character vector.
#' @return A character vector the same length as `string`.
#' @export
.str_to_title <- function(string) {
  out <- tolower(string)
  gsub("\\b([a-z])", "\\U\\1", out, perl = TRUE)
}

#' Convert to sentence case
#'
#' Lower-cases the whole string, then upper-cases only its first letter
#' (the entire input is treated as one sentence, not split on `.`/`!`/`?`).
#'
#' @param string Character vector.
#' @return A character vector the same length as `string`.
#' @export
.str_to_sentence <- function(string) {
  out <- tolower(string)
  sub("^([a-z])", "\\U\\1", out, perl = TRUE)
}

#' Repeat (duplicate) a string
#'
#' @param string Character vector.
#' @param times Integer vector of repeat counts, recycled against `string`.
#' @return A character vector.
#' @export
.str_dup <- function(string, times) strrep(string, times)

#' Concatenate strings, propagating `NA`
#'
#' Like `paste0()`, but (a) an `NA` in any argument at a given position
#' makes that position's result `NA` (base `paste0()` instead coerces
#' `NA` to the literal string `"NA"`), and (b) any zero-length argument
#' makes the whole result `character(0)`.
#'
#' @param ... Character vectors to concatenate, recycled to a common
#'   length.
#' @param sep Separator inserted between the (recycled) arguments.
#' @param collapse If not `NULL`, the recycled+concatenated results are
#'   further joined into a single string with this separator; if any
#'   result is `NA`, the collapsed result is `NA`.
#' @return A character vector (or a length-1 character vector if
#'   `collapse` is supplied).
#' @export
.str_c <- function(..., sep = "", collapse = NULL) {
  args <- list(...)
  if (length(args) == 0L) return(character(0))
  args <- lapply(args, as.character)
  lens <- lengths(args)
  if (any(lens == 0L)) return(character(0))
  n <- max(lens)
  if (any(n %% lens != 0L)) {
    stop("Lengths of `...` are not compatible for recycling.")
  }
  args <- lapply(args, rep_len, length.out = n)
  na_mask <- Reduce(`|`, lapply(args, is.na))
  out <- do.call(paste, c(args, list(sep = sep)))
  out[na_mask] <- NA_character_
  if (!is.null(collapse)) {
    if (anyNA(out)) return(NA_character_)
    out <- paste(out, collapse = collapse)
  }
  out
}

#' Wrap a string to a target line width
#'
#' Each element of `string` is wrapped independently (existing
#' whitespace, including newlines, is collapsed before rewrapping, as
#' in `base::strwrap()`) and its wrapped lines are rejoined with `"\n"`
#' into a single string, so the result is the same length as `string`.
#'
#' @param string Character vector.
#' @param width Target line width in characters.
#' @param indent Number of spaces to indent the first line of each
#'   paragraph.
#' @param exdent Number of spaces to indent subsequent lines of each
#'   paragraph.
#' @return A character vector the same length as `string`.
#' @export
.str_wrap <- function(string, width = 80, indent = 0, exdent = 0) {
  vapply(
    string,
    function(s) {
      if (is.na(s)) return(NA_character_)
      paste(strwrap(s, width = width, indent = indent, exdent = exdent), collapse = "\n")
    },
    character(1),
    USE.NAMES = FALSE
  )
}
