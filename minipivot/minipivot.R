## minipivot.R -------------------------------------------------------------
##
## A minimal, dependency-free reimplementation of tidyr's `pivot_longer()`
## and `pivot_wider()`: reshape a data frame between "long" and "wide"
## layouts.
##
## Design notes:
## - Base R only, written from scratch against tidyr's documented
##   behaviour (not adapted from an existing dependency-free source).
## - Both exported functions are bare dot-names, `.pivot_longer()` and
##   `.pivot_wider()` -- not additionally tagged, since this mini's
##   purpose already is "pivot" and a mechanical `.pivot_pivot_longer()`
##   tag would stutter, the same reasoning `minicase` used for its
##   single exported function, extended here to two functions that
##   both already start with the mini's own name.
## - `.pivot_longer()`'s `cols` argument supports a minimal, non-tidyselect
##   NSE: a character vector of column names, a numeric vector of
##   positions, bare unquoted column names, `c(...)` of either, and
##   negation with unary `-` (e.g. `-c(id, group)`) to select "every
##   other column". There is no `starts_with()`/`everything()`/`:`-range
##   support -- name/position vectors and `-` are all this mini
##   implements.
## - `.pivot_wider()`'s `names_from`/`values_from` are single column
##   names only (no multi-column keys); every other column is treated as
##   an id column automatically (no explicit `id_cols` argument).
## - `.pivot_wider()` deliberately has no `values_fn`-style aggregation
##   for duplicate `names_from`/id-column combinations, nor tidyr's
##   fallback of silently producing a list-column -- this mini has no
##   list-column support (consistent with `minitable`), so a duplicate
##   combination is a hard error instead.
## - Deliberately excluded (both functions): multiple `names_to`/
##   `values_to` or `names_from`/`values_from` columns, `names_sep`/
##   `names_pattern` (splitting one key column into several),
##   `names_prefix`, `names_glue`, `values_drop_na`, `unused_fn`.
##   `.pivot_wider()` does support a single scalar `values_fill`.
##
## Usage:
##   source("minipivot.R")
##   fish <- data.frame(
##     location = c("lake", "lake", "sea", "sea"),
##     species  = c("trout", "bass", "trout", "bass"),
##     count    = c(5, 3, 7, 2)
##   )
##   long <- .pivot_longer(fish, count, names_to = "metric", values_to = "n")
##   wide <- .pivot_wider(fish, names_from = "species", values_from = "count")
##
## License: MIT (see LICENSE at the root of the minis repo). Original
## logic, not copied from {tidyr}.

#' Pivot columns into longer, "key-value" rows
#'
#' Like `tidyr::pivot_longer()`, but with a single `names_to`/`values_to`
#' pair only. Each original row expands into one new row per selected
#' column, in the original column order.
#'
#' @param .data A data frame.
#' @param cols Columns to pivot: a character vector of names, a numeric
#'   vector of positions, or an unquoted expression using bare column
#'   names, `c(...)`, and/or a leading `-` to select "everything except".
#'   Unselected columns are treated as id columns and repeated as-is.
#' @param names_to,values_to Names of the two new columns holding the
#'   pivoted column names and values, respectively.
#' @return A data frame with `length(id columns) + 2` columns and
#'   `nrow(.data) * length(cols)` rows. `values_to` is built with
#'   `unlist()`, so mixing incompatible column types in `cols` coerces
#'   to a common type the same way `c()` would.
#' @export
.pivot_longer <- function(.data, cols, names_to = "name", values_to = "value") {
  nm <- names(.data)
  cols_expr <- substitute(cols)
  pos_env <- as.list(seq_along(nm))
  names(pos_env) <- nm
  cols_val <- eval(cols_expr, envir = pos_env, enclos = parent.frame())
  idx <- if (is.character(cols_val)) match(cols_val, nm) else as.integer(cols_val)
  if (anyNA(idx)) stop(".pivot_longer(): unmatched entries in `cols`.")
  if (any(idx < 0)) idx <- seq_along(nm)[idx]
  id_idx <- setdiff(seq_along(nm), idx)

  n_rows <- nrow(.data)
  n_cols <- length(idx)
  rows_rep <- rep(seq_len(n_rows), each = n_cols)

  selected <- .data[idx]
  value_part <- unlist(
    lapply(seq_len(n_rows), function(r) unlist(selected[r, ], use.names = FALSE)),
    use.names = FALSE
  )
  # unlist() of an empty list is NULL, not a zero-length vector -- guard
  # against that so a zero-row `.data` still produces a `values_to` column
  # (empty, but present) instead of silently losing it via `out[[values_to]]
  # <- NULL`, which removes/never-creates a data frame column.
  if (is.null(value_part)) value_part <- logical(0)
  name_part <- rep(nm[idx], times = n_rows)

  out <- if (length(id_idx)) {
    as.data.frame(.data[rows_rep, id_idx, drop = FALSE], check.names = FALSE)
  } else {
    as.data.frame(matrix(nrow = length(rows_rep), ncol = 0))
  }
  out[[names_to]] <- name_part
  out[[values_to]] <- value_part
  rownames(out) <- NULL
  out
}

#' Pivot key-value rows into wider columns
#'
#' Like `tidyr::pivot_wider()`, but with a single `names_from`/
#' `values_from` pair only, and no `id_cols` argument -- every other
#' column is used as an id column automatically.
#'
#' @param .data A data frame.
#' @param names_from,values_from Single column names (character
#'   scalars): `names_from`'s unique values become new column names,
#'   filled from `values_from`.
#' @param values_fill A single value to use for id/`names_from`
#'   combinations that don't appear in `.data` (default `NA`). A
#'   `values_fill` of a different type than `values_from` triggers a
#'   warning, since filling then coerces the affected column(s).
#' @return A data frame with one row per unique combination of the id
#'   columns. A `NA` value in `names_from` becomes a column literally
#'   named `"NA"` (a string), rather than crashing or being dropped. A
#'   `names_from` value identical to an existing id column's name is an
#'   error, not a silent overwrite of that id column.
#' @export
.pivot_wider <- function(.data, names_from, values_from, values_fill = NULL) {
  nm <- names(.data)
  if (!(is.character(names_from) && length(names_from) == 1L && names_from %in% nm)) {
    stop(".pivot_wider(): `names_from` must be a single existing column name.")
  }
  if (!(is.character(values_from) && length(values_from) == 1L && values_from %in% nm)) {
    stop(".pivot_wider(): `values_from` must be a single existing column name.")
  }
  id_cols <- setdiff(nm, c(names_from, values_from))

  key <- if (length(id_cols)) {
    do.call(paste, c(unname(as.list(.data[id_cols])), list(sep = "\r")))
  } else {
    rep("", nrow(.data))
  }
  name_val <- as.character(.data[[names_from]])
  # A `NA` in `names_from` would otherwise silently survive as a literal NA
  # element of `new_col_names`, and `col_out[match(key[sel], unique_keys)] <-
  # ...` with an NA-valued `sel` selector crashes with "NAs are not allowed
  # in subscripted assignments". Coercing to the string "NA" gives a
  # deterministic (if unusual-looking) column name instead.
  name_val[is.na(name_val)] <- "NA"
  combo <- paste(key, name_val, sep = "\r")
  if (anyDuplicated(combo) != 0L) {
    stop(
      ".pivot_wider(): `names_from`/id-column combination is not unique ",
      "(duplicate rows would need to be aggregated); this mini does not ",
      "implement a `values_fn`-style aggregation step."
    )
  }

  unique_keys <- unique(key)
  new_col_names <- unique(name_val)

  # A `names_from` value identical to an existing id column's name would
  # otherwise silently overwrite that id column below (`out[[cn]] <-
  # col_out`), destroying its original data with no error or warning.
  collisions <- intersect(new_col_names, id_cols)
  if (length(collisions)) {
    stop(
      ".pivot_wider(): value(s) of `names_from` (",
      paste(collisions, collapse = ", "),
      ") collide with existing id column name(s); rename the id column(s) first."
    )
  }

  first_row <- match(unique_keys, key)

  out <- if (length(id_cols)) {
    as.data.frame(.data[first_row, id_cols, drop = FALSE], check.names = FALSE)
  } else {
    as.data.frame(matrix(nrow = length(unique_keys), ncol = 0))
  }

  values_col <- .data[[values_from]]
  if (!is.null(values_fill) &&
      !identical(typeof(values_fill), typeof(values_col)) &&
      !(is.numeric(values_fill) && is.numeric(values_col))) {
    warning(
      ".pivot_wider(): `values_fill` (", typeof(values_fill), ") is a ",
      "different type than `", values_from, "` (", typeof(values_col),
      "); the affected column(s) will be coerced.",
      call. = FALSE
    )
  }

  for (cn in new_col_names) {
    sel <- name_val == cn
    matched <- unique_keys %in% key[sel]
    # Seed with an NA vector of `values_from`'s own type/class (works for
    # factors, Dates, etc., not just atomic vectors) so that real,
    # successfully-matched values are never forced through `values_fill`'s
    # type before being assigned -- only genuinely-missing combinations are.
    col_out <- values_col[rep(NA_integer_, length(unique_keys))]
    col_out[match(key[sel], unique_keys)] <- values_col[sel]
    if (!is.null(values_fill)) col_out[!matched] <- values_fill
    out[[cn]] <- col_out
  }
  rownames(out) <- NULL
  out
}
