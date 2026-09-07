## miniverb.R ----------------------------------------------------------------
##
## A minimal, dependency-free reimplementation of five dplyr one-table
## verbs -- `filter()`, `select()`, `mutate()`, `arrange()`, `summarise()`
## -- plus a `.by`-style grouping argument shared across `filter()`,
## `mutate()`, and `summarise()`.
##
## Design notes:
## - Base R only. `.verb_filter()`'s core logic is adapted from poorman's
##   filter()/dots.R (https://github.com/nathaneastwood/poorman), itself
##   dependency-free; `.verb_select()`/`.verb_mutate()`/`.verb_arrange()`/
##   `.verb_summarise()` are original reimplementations of dplyr semantics,
##   not copied or adapted from dplyr or poorman.
## - All functions are dot-prefixed with the shared tag `.verb_` -- there's
##   no separate exported-vs-internal naming split, since every function
##   here is meant to be treated as an implementation detail once copied
##   into a consuming package. A shared tag (rather than bare names like
##   the old `.filter()`) was chosen because these five verbs share real
##   implementation (the `.verb_split_by()` grouping helper), not just a
##   theme.
## - `.by` accepts a plain character vector of column names only (e.g.
##   `.by = c("cyl", "gear")`) -- no unquoted/tidyselect-lite syntax.
##   Supported on `.verb_filter()`, `.verb_mutate()`, `.verb_summarise()`.
##   Not supported on `.verb_arrange()`, which has no grouped variant in
##   dplyr either (`.by_group` requires a persistent `group_by()` object,
##   which doesn't exist here).
## - Deliberately excluded, across every verb: `across()`, tidyselect
##   helpers (`starts_with()`/`contains()`/`everything()`/`where()`/
##   `all_of()`/`any_of()`), injection operators (`{{ }}`/`!!`/`!!!`), and
##   any persistent `group_by()` object. The moment a use case needs a
##   *programmable* column selection rather than columns typed out by
##   hand, that's a signal to take the real dplyr dependency instead of
##   stretching this mini further.
## - `.verb_select()` supports unquoted bare column names, integer
##   positions, `-col`/`-position` to exclude, and `new = old` renaming.
##   Inclusion and exclusion cannot be mixed in one call.
## - `.verb_mutate()` evaluates `name = expr` arguments in the scope of
##   `.data` (plus any already-added columns from earlier arguments in
##   the same call), recycling length-1 results and otherwise relying on
##   base R's own vector-assignment recycling rules -- there's no
##   vctrs-style strict size checking.
## - `.verb_arrange()` sorts ascending by default; wrap a column in the
##   bundled `.verb_desc()` for descending order. `NA`s sort last
##   regardless of direction, matching `dplyr::arrange()`.
## - `.verb_summarise()` returns exactly one row per group (or one row
##   overall with no `.by`); expressions that don't reduce to a single
##   value per group are an error, not silently recycled.
##
## Usage:
##   source("miniverb.R")
##   .verb_filter(mtcars, mpg > mean(mpg), .by = "cyl")
##   .verb_select(mtcars, mpg, cylinders = cyl)
##   .verb_mutate(mtcars, mpg_z = (mpg - mean(mpg)) / sd(mpg), .by = "cyl")
##   .verb_arrange(mtcars, .verb_desc(mpg))
##   .verb_summarise(mtcars, mean_mpg = mean(mpg), .by = "cyl")
##
## License: MIT (see LICENSE at the root of the minis repo). `.verb_filter()`
## logic adapted from poorman (MIT licensed), not copied from {dplyr}; the
## other four verbs are original reimplementations of dplyr semantics.

#' @noRd
.verb_dotdotdot <- function(...) {
  eval(substitute(alist(...)))
}

#' Split row indices of a data frame into groups
#'
#' @param .data A data frame.
#' @param by `NULL`, or a character vector of column names in `.data` to
#'   group by.
#' @return A list of integer vectors of row indices, one per group, in
#'   ascending order of the grouping columns. With `by = NULL`, a
#'   single-element list holding all row indices in original order.
#' @noRd
.verb_split_by <- function(.data, by = NULL) {
  n <- nrow(.data)
  if (is.null(by) || length(by) == 0L) {
    return(list(seq_len(n)))
  }
  if (!is.character(by)) {
    stop(
      ".by must be a character vector of column names (e.g. `.by = c(\"g\")`)",
      call. = FALSE
    )
  }
  keys <- .data[by]
  ord <- do.call(order, as.list(keys))
  key_str <- do.call(paste, c(as.list(keys[ord, , drop = FALSE]), sep = "\r"))
  grp <- cumsum(c(TRUE, key_str[-1] != key_str[-length(key_str)]))
  unname(split(ord, grp))
}

#' Filter rows of a data frame by unquoted conditions
#'
#' @param .data A data frame.
#' @param ... Logical expressions, evaluated in the scope of `.data`
#'   (columns can be referred to by bare name). Multiple expressions are
#'   combined with `&`.
#' @param .by `NULL` (default), or a character vector of column names to
#'   evaluate `...` within each group of separately (e.g. so
#'   `x > mean(x)` compares against the group mean, not the overall
#'   mean).
#' @return A data frame containing only rows where all conditions are
#'   `TRUE`. Rows where the combined condition is `NA` are dropped, as
#'   in dplyr. Calling with no conditions returns `.data` unchanged.
#' @export
.verb_filter <- function(.data, ..., .by = NULL) {
  conditions <- .verb_dotdotdot(...)
  if (length(conditions) == 0L) return(.data)
  frame <- parent.frame()
  groups <- .verb_split_by(.data, .by)
  keep <- logical(nrow(.data))
  for (idx in groups) {
    sub <- .data[idx, , drop = FALSE]
    rows <- lapply(conditions, function(cond) eval(cond, sub, frame))
    rows <- Reduce(`&`, rows)
    keep[idx] <- rows & !is.na(rows)
  }
  .data[keep, , drop = FALSE]
}

#' Select and optionally rename columns of a data frame
#'
#' @param .data A data frame.
#' @param ... Unquoted column names or integer positions to keep,
#'   optionally named to rename (`new = old`); or `-col`/`-position` to
#'   drop columns. Inclusion and exclusion cannot be mixed in one call.
#' @return A data frame with the selected columns, in the order given.
#' @export
.verb_select <- function(.data, ...) {
  dots <- eval(substitute(alist(...)))
  nms <- names(dots)
  if (is.null(nms)) nms <- rep("", length(dots))
  all_names <- names(.data)

  resolve <- function(expr) {
    if (is.symbol(expr)) return(as.character(expr))
    if (is.numeric(expr)) return(all_names[abs(expr)])
    stop(
      ".verb_select: unsupported expression `", deparse(expr), "` -- ",
      "only bare column names, integer positions, and `-` exclusions ",
      "are supported (no tidyselect helpers)",
      call. = FALSE
    )
  }

  include <- character(0)
  exclude <- character(0)
  out_names <- character(0)

  for (i in seq_along(dots)) {
    expr <- dots[[i]]
    nm <- nms[i]
    is_excl <- (is.call(expr) && identical(expr[[1]], as.name("-"))) ||
      (is.numeric(expr) && expr < 0)
    if (is_excl) {
      target <- if (is.call(expr)) expr[[2]] else -expr
      exclude <- c(exclude, resolve(target))
      next
    }
    col <- resolve(expr)
    include <- c(include, col)
    out_names <- c(out_names, if (nzchar(nm)) nm else col)
  }

  if (length(exclude) > 0L) {
    if (length(include) > 0L) {
      stop(".verb_select: cannot mix inclusion and exclusion", call. = FALSE)
    }
    include <- setdiff(all_names, exclude)
    out_names <- include
  }

  out <- .data[include]
  names(out) <- out_names
  out
}

#' Add or modify columns of a data frame
#'
#' @param .data A data frame.
#' @param ... Named `name = expr` arguments, evaluated in the scope of
#'   `.data` (columns added by earlier arguments in the same call are
#'   visible to later ones). Length-1 results are recycled to the number
#'   of rows in the group; other lengths rely on base R's own
#'   vector-assignment recycling.
#' @param .by `NULL` (default), or a character vector of column names to
#'   evaluate `...` within each group separately.
#' @return `.data` with the named columns added or overwritten.
#' @export
.verb_mutate <- function(.data, ..., .by = NULL) {
  dots <- eval(substitute(alist(...)))
  nms <- names(dots)
  if (length(dots) == 0L) return(.data)
  if (is.null(nms) || any(!nzchar(nms))) {
    stop(".verb_mutate: all arguments must be named", call. = FALSE)
  }
  frame <- parent.frame()
  groups <- .verb_split_by(.data, .by)
  out <- .data
  for (i in seq_along(dots)) {
    col <- NULL
    for (idx in groups) {
      sub <- out[idx, , drop = FALSE]
      val <- eval(dots[[i]], sub, frame)
      if (length(val) == 1L) val <- rep(val, length(idx))
      if (is.null(col)) col <- val[rep(NA_integer_, nrow(out))]
      col[idx] <- val
    }
    out[[nms[i]]] <- col
  }
  out
}

#' Mark a column for descending order in `.verb_arrange()`
#'
#' @param x A vector.
#' @return `x` transformed so that sorting it ascending produces
#'   descending order on the original values.
#' @export
.verb_desc <- function(x) {
  -xtfrm(x)
}

#' Reorder the rows of a data frame
#'
#' @param .data A data frame.
#' @param ... Unquoted columns (or expressions, e.g. `.verb_desc(col)`)
#'   to sort by, evaluated in the scope of `.data`. Ties are broken by
#'   later arguments, as in `order()`.
#' @return `.data` reordered. `NA`s sort last, matching
#'   `dplyr::arrange()`. Calling with no arguments returns `.data`
#'   unchanged.
#' @export
.verb_arrange <- function(.data, ...) {
  dots <- eval(substitute(alist(...)))
  if (length(dots) == 0L) return(.data)
  frame <- parent.frame()
  keys <- lapply(dots, function(e) eval(e, .data, frame))
  ord <- do.call(order, keys)
  .data[ord, , drop = FALSE]
}

#' Collapse a data frame to one summary row per group
#'
#' @param .data A data frame.
#' @param ... Named `name = expr` arguments, each of which must evaluate
#'   to a single value per group.
#' @param .by `NULL` (default), or a character vector of column names to
#'   group by. With `.by`, the grouping columns are included as the
#'   leading columns of the result.
#' @return A data frame with one row per group (or one row overall, with
#'   no `.by`) and one column per named argument in `...` (plus the
#'   grouping columns, if `.by` is supplied).
#' @export
.verb_summarise <- function(.data, ..., .by = NULL) {
  dots <- eval(substitute(alist(...)))
  nms <- names(dots)
  if (length(dots) == 0L) {
    stop(".verb_summarise: no summary expressions supplied", call. = FALSE)
  }
  if (is.null(nms) || any(!nzchar(nms))) {
    stop(".verb_summarise: all arguments must be named", call. = FALSE)
  }
  frame <- parent.frame()
  groups <- .verb_split_by(.data, .by)
  rows <- lapply(groups, function(idx) {
    sub <- .data[idx, , drop = FALSE]
    values <- lapply(dots, function(e) eval(e, sub, frame))
    if (any(lengths(values) != 1L)) {
      stop(
        ".verb_summarise: expressions must return a single value per group",
        call. = FALSE
      )
    }
    result <- as.data.frame(values, stringsAsFactors = FALSE)
    names(result) <- nms
    if (!is.null(.by)) {
      result <- cbind(sub[1, .by, drop = FALSE], result)
    }
    result
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}
