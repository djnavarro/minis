## minirx.R -------------------------------------------------------------
##
## A minimal, dependency-free reimplementation of stringr's regex-based
## pattern-matching verbs -- detect, extract, match, replace, remove,
## split, count, and locate -- built entirely on base R's own regex
## engine with `perl = TRUE` (PCRE), not stringr/stringi's ICU engine.
##
## Design notes:
## - Base R only, adapted from stringr's pattern-matching functions
##   (https://stringr.tidyverse.org). Every function here takes a single
##   PCRE pattern applied with `perl = TRUE` -- there is no support for
##   stringr's `fixed()`/`coll()`/`boundary()` pattern-type wrappers, and
##   no locale-aware collation. If you need genuinely locale-sensitive
##   matching, this mini isn't a substitute for the real thing.
## - All functions are dot-prefixed with the tag `.rx_` -- there's no
##   separate exported-vs-internal naming split, since every function
##   here is meant to be treated as an implementation detail once
##   copied into a consuming package.
## - `pattern` is always a single string (base R's own `grepl()`/
##   `sub()`/`gsub()`/etc. only ever use the first element of a
##   multi-element pattern anyway); this mini does not vectorise over
##   `pattern`.
## - Deliberate fixes relative to naive base-R wrapping:
##     - `grepl()` (used by `.rx_detect()`/`.rx_starts()`/`.rx_ends()`)
##       returns `FALSE` for an `NA` input rather than propagating the
##       missing value; this mini forces those positions back to `NA`,
##       matching `stringr::str_detect()`.
##     - `.rx_extract()` is built on `regexpr()`, and
##       `regmatches(string, regexpr(...))` silently *drops* elements
##       of `string` that didn't match, shortening the result vector
##       instead of leaving a hole. This mini reconstructs a full-length
##       result with `NA` in the positions that didn't match (or were
##       `NA` to begin with).
##     - `.rx_count()` fixes `gregexpr()`'s "no match" sentinel (a
##       single `-1`) so it counts as `0` matches, not `1`, and
##       distinguishes an `NA` input (giving `NA`) from a genuine
##       zero-match string (giving `0`).
## - `.rx_match()`/`.rx_match_all()` determine the number of output
##   columns (1 for the full match, plus one per capture group) from
##   whichever input string matched first; if a pattern's capture
##   groups can vary in count across matches (e.g. via alternation),
##   this is a real restriction to be aware of -- not just a cosmetic
##   simplification.
##
## Usage:
##   source("minirx.R")
##   .rx_detect(c("cat", "dog"), "^c")
##   .rx_extract(c("item-12", "item-x"), "[0-9]+")
##   .rx_replace_all("a-b-c", "-", "_")
##   .rx_split("a,b,,c", ",")
##
## License: MIT (see LICENSE at the root of the minis repo). Logic
## adapted from stringr (MIT licensed), not copied from it.

#' Detect whether a pattern matches a string
#'
#' @param string Character vector.
#' @param pattern A single PCRE pattern.
#' @param negate If `TRUE`, return `TRUE` for strings that do *not*
#'   match.
#' @return A logical vector the same length as `string`, `NA` where
#'   `string` is `NA`.
#' @export
.rx_detect <- function(string, pattern, negate = FALSE) {
  out <- grepl(pattern, string, perl = TRUE)
  out[is.na(string)] <- NA
  if (negate) !out else out
}

#' Detect whether a string starts/ends with a pattern
#'
#' @param string Character vector.
#' @param pattern A single PCRE pattern.
#' @param negate If `TRUE`, return `TRUE` for strings that do *not*
#'   match.
#' @return A logical vector the same length as `string`, `NA` where
#'   `string` is `NA`.
#' @export
.rx_starts <- function(string, pattern, negate = FALSE) {
  .rx_detect(string, paste0("^(?:", pattern, ")"), negate = negate)
}

#' @rdname dot-rx_starts
#' @export
.rx_ends <- function(string, pattern, negate = FALSE) {
  .rx_detect(string, paste0("(?:", pattern, ")$"), negate = negate)
}

#' Extract the first match of a pattern
#'
#' @param string Character vector.
#' @param pattern A single PCRE pattern.
#' @return A character vector the same length as `string`, `NA` where
#'   there was no match (or `string` was `NA`).
#' @export
.rx_extract <- function(string, pattern) {
  r <- regexpr(pattern, string, perl = TRUE)
  out <- rep(NA_character_, length(string))
  start <- suppressWarnings(as.integer(r))
  matched <- !is.na(start) & start > 0L
  out[matched] <- regmatches(string, r)
  out
}

#' Extract every match of a pattern
#'
#' @param string Character vector.
#' @param pattern A single PCRE pattern.
#' @return A list the same length as `string`; each element is a
#'   character vector of the matches found in that string (`character(0)`
#'   if none, `NA_character_` if that element of `string` was `NA`).
#' @export
.rx_extract_all <- function(string, pattern) {
  m <- gregexpr(pattern, string, perl = TRUE)
  out <- regmatches(string, m)
  out[is.na(string)] <- NA_character_
  out
}

#' Extract the first match of a pattern, with capture groups
#'
#' @param string Character vector.
#' @param pattern A single PCRE pattern, typically containing capture
#'   groups (`(...)`).
#' @return A character matrix with one row per element of `string` and
#'   one column per capture group plus one (the full match first). Rows
#'   with no match (or an `NA` input) are entirely `NA`.
#' @export
.rx_match <- function(string, pattern) {
  matches <- regmatches(string, regexec(pattern, string, perl = TRUE))
  lens <- lengths(matches)
  ncol <- if (any(lens > 0L)) max(lens) else 1L
  out <- matrix(NA_character_, nrow = length(string), ncol = ncol)
  for (i in seq_along(matches)) {
    if (lens[i] > 0L) out[i, seq_len(lens[i])] <- matches[[i]]
  }
  out
}

#' Extract every match of a pattern, with capture groups
#'
#' @param string Character vector.
#' @param pattern A single PCRE pattern, typically containing capture
#'   groups (`(...)`).
#' @return A list the same length as `string`; each element is a
#'   character matrix with one row per match found in that string and
#'   one column per capture group plus one. A string with no matches
#'   gets a zero-row matrix; an `NA` input gets a one-row, all-`NA`
#'   matrix.
#' @export
.rx_match_all <- function(string, pattern) {
  matches <- regmatches(string, gregexec(pattern, string, perl = TRUE))
  dims <- vapply(matches, function(x) if (is.matrix(x)) nrow(x) else NA_integer_, integer(1))
  ncol <- if (any(!is.na(dims))) dims[!is.na(dims)][[1]] else 1L
  lapply(seq_along(matches), function(i) {
    x <- matches[[i]]
    if (is.na(string[i])) return(matrix(NA_character_, nrow = 1L, ncol = ncol))
    if (is.matrix(x)) t(x) else matrix(character(0), nrow = 0L, ncol = ncol)
  })
}

#' Replace the first (or every) match of a pattern
#'
#' @param string Character vector.
#' @param pattern A single PCRE pattern.
#' @param replacement Replacement string; may refer to capture groups
#'   with `\1`, `\2`, etc.
#' @return A character vector the same length as `string`.
#' @export
.rx_replace <- function(string, pattern, replacement) {
  sub(pattern, replacement, string, perl = TRUE)
}

#' @rdname dot-rx_replace
#' @export
.rx_replace_all <- function(string, pattern, replacement) {
  gsub(pattern, replacement, string, perl = TRUE)
}

#' Remove the first (or every) match of a pattern
#'
#' @param string Character vector.
#' @param pattern A single PCRE pattern.
#' @return A character vector the same length as `string`.
#' @export
.rx_remove <- function(string, pattern) sub(pattern, "", string, perl = TRUE)

#' @rdname dot-rx_remove
#' @export
.rx_remove_all <- function(string, pattern) gsub(pattern, "", string, perl = TRUE)

#' Split a string on every match of a pattern
#'
#' @param string Character vector.
#' @param pattern A single PCRE pattern.
#' @return A list the same length as `string`, each element a character
#'   vector of the pieces between matches.
#' @export
.rx_split <- function(string, pattern) strsplit(string, pattern, perl = TRUE)

#' Count non-overlapping matches of a pattern
#'
#' @param string Character vector.
#' @param pattern A single PCRE pattern.
#' @return An integer vector the same length as `string`, `NA` where
#'   `string` is `NA`.
#' @export
.rx_count <- function(string, pattern) {
  m <- gregexpr(pattern, string, perl = TRUE)
  vapply(m, function(x) {
    if (identical(as.integer(x), -1L)) return(0L)
    if (anyNA(x)) return(NA_integer_)
    length(x)
  }, integer(1))
}

#' Locate the position of the first match of a pattern
#'
#' @param string Character vector.
#' @param pattern A single PCRE pattern.
#' @return An integer matrix with columns `start`/`end` (both
#'   1-indexed, inclusive) and one row per element of `string`. Rows
#'   with no match (or an `NA` input) are `NA` in both columns.
#' @export
.rx_locate <- function(string, pattern) {
  r <- regexpr(pattern, string, perl = TRUE)
  start <- suppressWarnings(as.integer(r))
  len <- attr(r, "match.length")
  end <- ifelse(!is.na(start) & start > 0L, start + len - 1L, NA_integer_)
  start[!is.na(start) & start < 0L] <- NA_integer_
  cbind(start = start, end = end)
}

#' Locate the positions of every match of a pattern
#'
#' @param string Character vector.
#' @param pattern A single PCRE pattern.
#' @return A list the same length as `string`; each element is an
#'   integer matrix with columns `start`/`end`, one row per match found
#'   in that string. A string with no matches gets a zero-row matrix;
#'   an `NA` input gets a one-row, all-`NA` matrix.
#' @export
.rx_locate_all <- function(string, pattern) {
  m <- gregexpr(pattern, string, perl = TRUE)
  lapply(seq_along(m), function(i) {
    v <- m[[i]]
    start <- suppressWarnings(as.integer(v))
    if (is.na(string[i])) {
      return(matrix(NA_integer_, nrow = 1L, ncol = 2L, dimnames = list(NULL, c("start", "end"))))
    }
    if (identical(start, -1L)) {
      return(matrix(integer(0), nrow = 0L, ncol = 2L, dimnames = list(NULL, c("start", "end"))))
    }
    len <- attr(v, "match.length")
    cbind(start = start, end = start + len - 1L)
  })
}
