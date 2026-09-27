# minicuts.R
#
# Two ways to cut a numeric vector into bins: `.cut_quantile()` (fixed
# group size, boundaries determined by the data) and `.cut_evenly()`
# (fixed bin geometry, group sizes determined by the data).
#
# `.cut_quantile()` reimplements the quantile-based cutting from
# djnavarro/erplots's `cut_quantile()`/`cut_exposure_quantile()`
# (R/utils-helpers.R). Ties handling (`ties`/`seed`), `quantile_type`
# passthrough, the flexible `labeller` hook, and graceful fallback when
# `x` doesn't have enough resolution for the requested number of bins
# are all ported directly. `cut_exposure_quantile()`'s
# pharmacometrics-specific `is_placebo`/`"Placebo"` handling is
# generalized into a domain-neutral `exclude` argument: values matched
# by `exclude` are left out of the quantile *calculation* (so they
# don't skew break points) but still get assigned their own factor
# level in the output, rather than being dropped or set to `NA`.
#
# `.cut_evenly()` covers the two related equal-width cutting rules from
# santoku's `chop_evenly()` (fixed number of bins, width derived from
# `range(x)`) and `chop_width()` (fixed bin width, number of bins
# derived from the data) in one function with mutually exclusive
# `n_bins`/`width` arguments, since both are the same underlying
# fixed-geometry cutting logic. It shares `exclude`/`exclude_label`/
# `labeller` with `.cut_quantile()` for a consistent feel across the
# mini, but drops `ties = "split-even"` (no "equal group size" goal to
# chase when bins are fixed by geometry rather than by data-driven
# quantiles) and, consequently, `seed`.
#
# Deliberately excluded relative to the source material:
#  - santoku-style general interval chopping (arbitrary breaks, `left`/
#    `close_end`, non-numeric `x`, weighted quantiles) -- if that
#    generality is what's needed, use santoku itself.
#
# Deliberate fix relative to the erplots source: `rlang::abort()`/
# `rlang::warn()` and `withr::with_seed()` are replaced with base
# `stop()`/`warning()` and a manual RNG-state save/restore
# (`.cuts_with_seed()`), to keep this mini at zero runtime
# dependencies.
#
# All functions are dot-prefixed. Both user-facing functions keep their
# own descriptive names bare (`.cut_quantile()`/`.cut_evenly()`) rather
# than stuttering under a mechanically-derived tag; internal helpers
# use the mini-specific tag `.cuts_` -- there's no separate
# exported-vs-internal naming split, since every function here is
# meant to be treated as an implementation detail once copied into a
# consuming package.

# Resolves `exclude` (`NULL`/logical vector/predicate function) into a
# logical vector the same length as `x`, `TRUE` where that element is
# excluded from the quantile calculation. `NA` in the resolved vector
# is treated as "not excluded".
#' @noRd
.cuts_resolve_exclude <- function(x, exclude) {
  if (is.null(exclude)) return(rep(FALSE, length(x)))

  mask <- if (is.function(exclude)) exclude(x) else exclude

  if (!is.logical(mask) || length(mask) != length(x)) {
    stop(
      "`exclude` must be NULL, a logical vector the same length as `x`, ",
      "or a function of `x` returning such a vector.",
      call. = FALSE
    )
  }
  mask[is.na(mask)] <- FALSE
  mask
}

# Shared bin-assignment logic: assigns each element of `x` to an
# integer bin (`1:n_bins`, `NA` where `x` is missing or outside
# `range(breaks)`) according to the `ties` rule. `"upward"`/
# `"downward"` are direct `cut()` calls; `"split-even"` is handled by
# `.cuts_resolve_ties()` below.
#' @noRd
.cuts_bin_num <- function(x, breaks, n_bins, ties, seed = NULL) {
  switch(
    ties,
    upward = as.numeric(cut(x, breaks, labels = 1:n_bins, include.lowest = TRUE)),
    downward = as.numeric(cut(x, breaks, labels = 1:n_bins, right = FALSE, include.lowest = TRUE)),
    `split-even` = .cuts_resolve_ties(x, breaks, n_bins, seed = seed)
  )
}

# `ties = "split-even"`'s implementation. Starts from the `"upward"`
# baseline (every tied value assigned to the lower of its two candidate
# bins), then, for each interior break in turn, randomly moves just
# enough of that break's tied group up into the higher bin to bring the
# cumulative count assigned so far as close as possible to an even
# split (`target_cum`, a largest-remainder-style allocation of `n_obs`
# into `n_bins` roughly equal pieces) -- mirroring the equal-group-size
# goal of `dplyr::ntile()`, but breaking ties randomly rather than by
# row order. Only ties at a break point are ever moved; non-tied values
# keep the bin `cut()` already gave them.
#' @noRd
.cuts_resolve_ties <- function(x, breaks, n_bins, seed = NULL) {
  baseline <- as.numeric(cut(x, breaks, labels = 1:n_bins, include.lowest = TRUE))
  if (n_bins < 2) return(baseline)

  valid <- which(!is.na(baseline))
  n_obs <- length(valid)
  target_cum <- round((1:n_bins) * n_obs / n_bins)

  resolve <- function() {
    bin_num <- baseline
    for (j in 2:n_bins) {
      brk <- breaks[j]
      tied <- valid[x[valid] == brk]
      if (length(tied) == 0) next
      count_below <- sum(x[valid] < brk)
      k_lower <- max(0, min(length(tied), target_cum[j - 1] - count_below))
      if (k_lower < length(tied)) {
        move_up <- sample(tied, size = length(tied) - k_lower)
        bin_num[move_up] <- j
      }
    }
    bin_num
  }

  .cuts_with_seed(seed, resolve)
}

# Zero-dependency stand-in for `withr::with_seed()`: runs `fn()` under
# `seed` (if supplied) while leaving the ambient RNG state exactly as
# it was found, by saving/restoring `.Random.seed` in the global
# environment. `seed = NULL` runs `fn()` untouched, drawing from the
# ambient RNG stream (and so is not reproducible across calls).
#' @noRd
.cuts_with_seed <- function(seed, fn) {
  if (is.null(seed)) return(fn())

  has_seed <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
  old_seed <- if (has_seed) get(".Random.seed", envir = globalenv()) else NULL
  on.exit({
    if (has_seed) {
      assign(".Random.seed", old_seed, envir = globalenv())
    } else if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
      rm(".Random.seed", envir = globalenv())
    }
  })

  set.seed(seed)
  fn()
}

# Resolves `labeller` (`NULL`/function/character vector) into the
# character vector of `n_bins` quantile-bin labels. `n_bins`/`breaks`
# here are already post-fallback (i.e. the actual bin count/cutpoints
# used, not necessarily what the caller originally requested) -- see
# `?.cut_quantile`'s `@details` for why a character-vector `labeller`
# is checked against this `n_bins`, not the requested one.
#' @noRd
.cuts_resolve_labels <- function(labeller, n_bins, breaks) {
  if (is.null(labeller)) return(paste0("Q", 1:n_bins))

  labels <- if (is.function(labeller)) labeller(n_bins, breaks) else labeller

  if (!is.character(labels) || length(labels) != n_bins) {
    stop(
      sprintf(
        "`labeller` must produce %d label%s (the number of quantile bins actually used), not %d.",
        n_bins, if (n_bins == 1) "" else "s", length(labels)
      ),
      call. = FALSE
    )
  }
  labels
}

#' Cut a numeric vector into quantile bins
#'
#' Assigns each element of a numeric vector to one of `n_bins` bins of
#' (approximately) equal size, delimited by empirical quantiles.
#'
#' @param x A numeric vector.
#' @param n_bins Number of quantile bins to create. Falls back to a
#'   smaller number (with a warning) if `x` doesn't have enough
#'   distinct values to distinguish this many bins.
#' @param exclude Controls values excluded from the quantile
#'   *calculation* while still appearing in the result as their own
#'   factor level (rather than being dropped or contributing to a
#'   quantile bin). `NULL` (the default) excludes nothing. Otherwise
#'   either a logical vector the same length as `x` (`TRUE` = exclude),
#'   or a function called as `exclude(x)` returning such a vector --
#'   e.g. `exclude = function(x) x == 0` to give exact zeroes their own
#'   level. `NA` in the resolved logical vector is treated as "not
#'   excluded". Missing (`NA`) elements of `x` are always `NA` in the
#'   result, regardless of `exclude`.
#' @param exclude_label Single string used as the factor level for
#'   excluded values. Only used (and only appears as a level) when
#'   `exclude` is not `NULL`.
#' @param ties Controls how values falling exactly on a quantile break
#'   point are assigned, where the bin membership would otherwise be
#'   ambiguous. `"upward"` (the default) is equivalent to [cut()] with
#'   `right = TRUE`; `"downward"` is equivalent to `right = FALSE`;
#'   `"split-even"` randomly divides each tied group between its two
#'   candidate bins so that final bin sizes are as equal as possible,
#'   rather than sending every tied value the same direction.
#' @param seed Optional single number used to seed the random tie-break
#'   used by `ties = "split-even"` (ignored for `"upward"`/
#'   `"downward"`, which involve no randomness). `NULL` (the default)
#'   draws from the ambient RNG stream and so is not reproducible
#'   across calls; pass a seed for reproducible bin assignment.
#' @param quantile_type Integer between 1 and 9, passed straight
#'   through as [stats::quantile()]'s own `type` argument to compute
#'   the quantile break points. Defaults to `7`, matching
#'   [stats::quantile()]'s own default.
#' @param labeller Controls the labels used for the `n_bins` quantile
#'   bins (the separate `exclude_label` level, if any, is always used
#'   as-is regardless of `labeller`). `NULL` (the default) labels bins
#'   `"Q1"`, `"Q2"`, etc. A function is called as `labeller(n_bins,
#'   breaks)` (the actual bin count and the `n_bins + 1` quantile
#'   cutpoints, after any resolution-driven fallback -- see `@details`
#'   below) and must return a character vector of length `n_bins`; this
#'   is the hook for, e.g., range-style labels built from `breaks`. A
#'   character vector is used directly as the `n_bins` labels.
#'
#' @returns A factor with `"breaks"`, `"ties"`, and `"quantile_type"`
#'   attributes recording the quantile cutpoints actually used and
#'   those two arguments. Has `n_bins` levels, or `n_bins + 1` (the
#'   extra one being `exclude_label`) when `exclude` is not `NULL`.
#'
#' @details Errors if, after removing missing and `exclude`d values,
#'   `x` has fewer than 2 distinct values, since quantile bins aren't
#'   well-defined in that case. If `x` doesn't have enough resolution
#'   to distinguish all `n_bins` requested bins (e.g. many repeated
#'   values clustered at one end), warns and falls back to using as
#'   many bins as the data supports, rather than erroring or silently
#'   showing fewer bins with no explanation. Because that fallback can
#'   lower `n_bins` below what was originally requested, a
#'   character-vector `labeller` is length-checked against the
#'   *actual* bin count, not the requested one, and errors informatively
#'   on a mismatch.
#'
#' @examples
#' x <- rnorm(100)
#' .cut_quantile(x)
#' .cut_quantile(x, ties = "split-even", seed = 8213)
#' .cut_quantile(x, quantile_type = 1)
#' .cut_quantile(x, labeller = function(n_bins, breaks) paste0("Group ", 1:n_bins))
#' .cut_quantile(x, labeller = c("Low", "Mid-low", "Mid-high", "High"))
#'
#' # exact zeroes kept out of the quantile calculation, but labelled
#' # rather than dropped
#' exposure <- c(rep(0, 20), abs(rnorm(80)))
#' .cut_quantile(exposure, exclude = function(x) x == 0, exclude_label = "None")
#'
#' @export
.cut_quantile <- function(x, n_bins = 4,
                           exclude = NULL, exclude_label = "Excluded",
                           ties = c("upward", "downward", "split-even"),
                           seed = NULL, quantile_type = 7, labeller = NULL) {
  ties <- match.arg(ties)
  if (!is.numeric(x)) {
    stop("`x` must be numeric.", call. = FALSE)
  }
  if (length(n_bins) != 1 || !is.numeric(n_bins) || n_bins < 1) {
    stop("`n_bins` must be a single number greater than or equal to 1.", call. = FALSE)
  }

  excluded <- .cuts_resolve_exclude(x, exclude)
  in_calc <- !excluded & !is.na(x)
  calc_x <- x[in_calc]

  n_distinct <- length(unique(calc_x))
  if (n_distinct < 2) {
    stop(
      sprintf(
        "Cannot compute quantiles: found only %d distinct non-missing, non-excluded value%s.",
        n_distinct, if (n_distinct == 1) "" else "s"
      ),
      call. = FALSE
    )
  }

  breaks <- stats::quantile(calc_x, probs = (0:n_bins) / n_bins, type = quantile_type)

  # if `x` doesn't have enough resolution to distinguish all `n_bins`
  # requested bins (e.g. many repeated values clustered at one end),
  # `stats::quantile()` produces duplicate breaks -- passed straight to
  # `cut()`, this would either crash with the opaque `'breaks' are not
  # unique` error, or (when only a few of the `n_bins` bins ended up
  # genuinely occupied) silently show fewer bins than requested once
  # empty bins were dropped downstream, with no indication `n_bins` was
  # too high for the data. Deduplicating breaks and reducing `n_bins`
  # to match fixes the crash and lets this warn instead of failing.
  unique_breaks <- unique(breaks)
  n_actual <- length(unique_breaks) - 1
  if (n_actual < n_bins) {
    warning(
      sprintf(
        "Requested %d quantile bins, but only %d are distinguishable -- using %d instead.",
        n_bins, n_actual, n_actual
      ),
      call. = FALSE
    )
    breaks <- unique_breaks
    n_bins <- n_actual
  }

  bin_num <- rep(NA_real_, length(x))
  bin_num[in_calc] <- .cuts_bin_num(calc_x, breaks, n_bins, ties, seed = seed)

  labels <- .cuts_resolve_labels(labeller, n_bins, breaks)

  if (is.null(exclude)) {
    code <- ifelse(is.na(x), NA_real_, bin_num)
    result <- factor(code, levels = 1:n_bins, labels = labels)
  } else {
    code <- ifelse(is.na(x), NA_real_, ifelse(excluded, 0, bin_num))
    result <- factor(code, levels = 0:n_bins, labels = c(exclude_label, labels))
  }

  attr(result, "breaks") <- breaks
  attr(result, "ties") <- ties
  attr(result, "quantile_type") <- quantile_type
  result
}

#' Cut a numeric vector into fixed-geometry bins
#'
#' Assigns each element of a numeric vector to a bin of fixed width,
#' either a fixed *number* of bins spanning `range(x)` (`n_bins`), or a
#' fixed bin *width* with the number of bins following from the data
#' (`width`) -- santoku's `chop_evenly()`/`chop_width()`, respectively,
#' unified into one function since both compute breaks the same way
#' once a width and a starting point are known.
#'
#' @param x A numeric vector.
#' @param n_bins Number of equal-width bins to create, spanning
#'   `range(x)` (after removing missing/`exclude`d values). Exactly one
#'   of `n_bins`/`width` must be supplied.
#' @param width Width of each bin. Positive builds bins upward from
#'   `start` (default `min(x)`); negative builds them downward from
#'   `start` (default `max(x)`), enough of them to cover `range(x)`.
#'   Exactly one of `n_bins`/`width` must be supplied.
#' @param start Only used together with `width`: the shared edge of the
#'   first bin (upward) or last bin (downward). `NULL` (the default)
#'   uses `min(x)`/`max(x)` as appropriate, which guarantees every
#'   non-missing, non-excluded value of `x` falls in some bin. An
#'   explicit `start` that doesn't reach one edge of `range(x)` leaves
#'   values beyond it uncovered -- see `@details`.
#' @param exclude,exclude_label As in [.cut_quantile()]: values matched
#'   by `exclude` are left out of the bin-geometry calculation (so they
#'   don't affect `range(x)`-derived defaults) but still appear in the
#'   result under their own `exclude_label` level, rather than being
#'   dropped or set to `NA`.
#' @param ties Controls how values falling exactly on a bin boundary
#'   are assigned. `"upward"` (the default) is equivalent to [cut()]
#'   with `right = TRUE`; `"downward"` is equivalent to `right = FALSE`.
#'   Unlike [.cut_quantile()], there is no `"split-even"` option (bin
#'   geometry here is fixed, not derived from equal group sizes) and so
#'   no `seed` argument either.
#' @param labeller As in [.cut_quantile()]: `NULL` (the default) labels
#'   bins `"Q1"`, `"Q2"`, etc.; a function is called as
#'   `labeller(n_bins, breaks)`; a character vector of length `n_bins`
#'   (the actual, post-computation bin count) is used directly.
#'
#' @returns A factor with `"breaks"`, `"ties"`, and `"width"`
#'   attributes recording the bin cutpoints actually used, `ties`, and
#'   the bin width actually used (as supplied, or as derived from
#'   `n_bins`). Has `n_bins` levels, or `n_bins + 1` (the extra one
#'   being `exclude_label`) when `exclude` is not `NULL`.
#'
#' @details In `width` mode, if `start` is supplied explicitly and
#'   doesn't reach one edge of `range(x)` (e.g. `start` greater than
#'   `min(x)` with a positive `width`), values beyond that edge aren't
#'   covered by any bin. Rather than silently extending the outermost
#'   bin to include them (as santoku's `chop()` does by default), those
#'   values are coded `NA`, with a warning -- consistent with
#'   [cut()]'s own out-of-range behaviour.
#'
#' @examples
#' x <- runif(100, 0, 10)
#' .cut_evenly(x, n_bins = 5)
#' .cut_evenly(x, width = 2)
#' .cut_evenly(x, width = 2, start = 0)
#' .cut_evenly(x, width = -2)
#'
#' @export
.cut_evenly <- function(x, n_bins = NULL, width = NULL, start = NULL,
                         exclude = NULL, exclude_label = "Excluded",
                         ties = c("upward", "downward"), labeller = NULL) {
  ties <- match.arg(ties)
  if (!is.numeric(x)) {
    stop("`x` must be numeric.", call. = FALSE)
  }
  if (is.null(n_bins) == is.null(width)) {
    stop("Exactly one of `n_bins` or `width` must be supplied.", call. = FALSE)
  }
  if (!is.null(n_bins) && !is.null(start)) {
    stop("`start` is only used together with `width`, not `n_bins`.", call. = FALSE)
  }

  excluded <- .cuts_resolve_exclude(x, exclude)
  in_calc <- !excluded & !is.na(x)
  calc_x <- x[in_calc]

  if (length(calc_x) < 1) {
    stop("Cannot compute bins: found no non-missing, non-excluded values.", call. = FALSE)
  }

  if (!is.null(n_bins)) {
    if (length(n_bins) != 1 || !is.numeric(n_bins) || n_bins < 1) {
      stop("`n_bins` must be a single number greater than or equal to 1.", call. = FALSE)
    }
    lo <- min(calc_x)
    hi <- max(calc_x)
    if (lo == hi) {
      stop(
        "Cannot compute evenly spaced bins: all non-missing, non-excluded values of `x` are equal.",
        call. = FALSE
      )
    }
    width_used <- (hi - lo) / n_bins
    breaks <- lo + (0:n_bins) * width_used
  } else {
    if (length(width) != 1 || !is.numeric(width) || width == 0) {
      stop("`width` must be a single nonzero number.", call. = FALSE)
    }
    width_used <- width

    if (width > 0) {
      anchor <- if (is.null(start)) min(calc_x) else start
      n_bins <- max(1, ceiling((max(calc_x) - anchor) / width))
      breaks <- anchor + (0:n_bins) * width
      out_of_range <- calc_x < anchor
    } else {
      anchor <- if (is.null(start)) max(calc_x) else start
      n_bins <- max(1, ceiling((anchor - min(calc_x)) / abs(width)))
      breaks <- anchor - (n_bins:0) * abs(width)
      out_of_range <- calc_x > anchor
    }

    if (any(out_of_range)) {
      warning(
        "Some non-missing, non-excluded values of `x` fall outside the bins implied by `start`/`width` and are coded NA.",
        call. = FALSE
      )
    }
  }

  raw_bin_num <- switch(
    ties,
    upward = as.numeric(cut(calc_x, breaks, labels = 1:n_bins, include.lowest = TRUE)),
    downward = as.numeric(cut(calc_x, breaks, labels = 1:n_bins, right = FALSE, include.lowest = TRUE))
  )
  bin_num <- rep(NA_real_, length(x))
  bin_num[in_calc] <- raw_bin_num

  labels <- .cuts_resolve_labels(labeller, n_bins, breaks)

  if (is.null(exclude)) {
    code <- ifelse(is.na(x), NA_real_, bin_num)
    result <- factor(code, levels = 1:n_bins, labels = labels)
  } else {
    code <- ifelse(is.na(x), NA_real_, ifelse(excluded, 0, bin_num))
    result <- factor(code, levels = 0:n_bins, labels = c(exclude_label, labels))
  }

  attr(result, "breaks") <- breaks
  attr(result, "ties") <- ties
  attr(result, "width") <- width_used
  result
}
