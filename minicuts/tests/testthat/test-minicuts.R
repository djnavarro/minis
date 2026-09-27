source(testthat::test_path("..", "..", "minicuts.R"))

test_that("basic quantile cutting produces the requested number of roughly equal bins", {
  x <- 1:100
  result <- .cut_quantile(x, n_bins = 4)

  expect_s3_class(result, "factor")
  expect_equal(levels(result), paste0("Q", 1:4))
  expect_equal(as.integer(table(result)), rep(25, 4))
})

test_that("default labels are Q1..Qn and custom labellers work", {
  x <- 1:20

  expect_equal(levels(.cut_quantile(x, n_bins = 5)), paste0("Q", 1:5))

  by_fn <- .cut_quantile(x, n_bins = 4, labeller = function(n_bins, breaks) paste0("Group ", 1:n_bins))
  expect_equal(levels(by_fn), paste0("Group ", 1:4))

  by_chr <- .cut_quantile(x, n_bins = 4, labeller = c("Low", "Mid-low", "Mid-high", "High"))
  expect_equal(levels(by_chr), c("Low", "Mid-low", "Mid-high", "High"))
})

test_that("character labeller is checked against the actual (post-fallback) bin count", {
  x <- c(rep(1, 10), 2:5)
  expect_error(
    .cut_quantile(x, n_bins = 4, labeller = c("A", "B", "C", "D")) |> suppressWarnings(),
    "must produce"
  )
})

test_that("NA in x propagates to NA in the result regardless of exclude", {
  x <- c(1:9, NA)
  result <- .cut_quantile(x, n_bins = 3)
  expect_true(is.na(result[10]))
  expect_equal(sum(is.na(result)), 1)
})

test_that("ties = 'upward'/'downward' match cut()'s right = TRUE/FALSE", {
  x <- c(1, 1, 2, 2, 3, 3, 4, 4)
  breaks <- stats::quantile(x, probs = 0:4 / 4, type = 7)

  up <- .cut_quantile(x, n_bins = 4, ties = "upward")
  down <- .cut_quantile(x, n_bins = 4, ties = "downward")

  expect_equal(as.integer(up), as.integer(cut(x, breaks, labels = 1:4, include.lowest = TRUE)))
  expect_equal(as.integer(down), as.integer(cut(x, breaks, labels = 1:4, right = FALSE, include.lowest = TRUE)))
})

test_that("ties = 'split-even' is reproducible with a seed and leaves the ambient RNG stream untouched", {
  x <- rep(1:5, each = 4)

  before <- .Random.seed
  result1 <- .cut_quantile(x, n_bins = 5, ties = "split-even", seed = 999)
  after <- .Random.seed
  expect_identical(before, after)

  result2 <- .cut_quantile(x, n_bins = 5, ties = "split-even", seed = 999)
  expect_identical(result1, result2)

  # bin sizes should be much closer to equal than the "upward" baseline
  # would give for this tied data
  expect_true(max(table(result1)) - min(table(result1)) <= 1)
})

test_that("quantile_type is passed through to stats::quantile() and recorded as an attribute", {
  x <- 1:10
  result <- .cut_quantile(x, n_bins = 4, quantile_type = 1)
  expect_equal(attr(result, "quantile_type"), 1)
  expect_equal(
    unname(attr(result, "breaks")),
    unname(stats::quantile(x, probs = 0:4 / 4, type = 1))
  )
})

test_that("attributes record breaks/ties/quantile_type", {
  result <- .cut_quantile(1:20, n_bins = 4, ties = "downward", quantile_type = 5)
  expect_equal(attr(result, "ties"), "downward")
  expect_equal(attr(result, "quantile_type"), 5)
  expect_length(attr(result, "breaks"), 5)
})

test_that("not enough distinct values to form 2 bins errors informatively", {
  expect_error(.cut_quantile(rep(1, 10), n_bins = 4), "distinct")
  expect_error(.cut_quantile(c(NA, NA, 1), n_bins = 4), "distinct")
})

test_that("not enough resolution for the requested n_bins warns and falls back", {
  x <- c(rep(1, 20), 2, 3)
  expect_warning(result <- .cut_quantile(x, n_bins = 10), "only")
  expect_lte(nlevels(result), 10)
})

test_that("x must be numeric", {
  expect_error(.cut_quantile(letters[1:10]), "numeric")
})

test_that("n_bins must be a single number >= 1", {
  expect_error(.cut_quantile(1:10, n_bins = 0), "n_bins")
  expect_error(.cut_quantile(1:10, n_bins = c(2, 3)), "n_bins")
})

test_that("exclude as a logical vector keeps excluded values out of the quantile calc but labels them", {
  x <- c(rep(0, 10), 1:40)
  is_zero <- x == 0

  result <- .cut_quantile(x, n_bins = 4, exclude = is_zero)

  expect_equal(levels(result), c("Excluded", paste0("Q", 1:4)))
  expect_true(all(result[is_zero] == "Excluded"))
  expect_equal(as.integer(table(droplevels(result[!is_zero]))), rep(10, 4))

  # breaks are computed only from the non-excluded values
  expect_equal(unname(attr(result, "breaks")), unname(stats::quantile(x[!is_zero], probs = 0:4 / 4, type = 7)))
})

test_that("exclude as a predicate function behaves the same way, with a custom label", {
  x <- c(rep(0, 10), 1:40)

  result <- .cut_quantile(x, n_bins = 4, exclude = function(x) x == 0, exclude_label = "None")

  expect_equal(levels(result), c("None", paste0("Q", 1:4)))
  expect_true(all(result[x == 0] == "None"))
})

test_that("exclude = NULL (the default) never introduces an extra level", {
  result <- .cut_quantile(1:40, n_bins = 4)
  expect_equal(nlevels(result), 4)
})

test_that("NA produced by an exclude predicate is treated as 'not excluded'", {
  x <- c(NA, 1:20)
  result <- .cut_quantile(x, n_bins = 4, exclude = function(x) x == 0)

  expect_true(is.na(result[1]))
  expect_equal(nlevels(result), 5)
  expect_equal(sum(result == "Excluded", na.rm = TRUE), 0)
})

test_that("exclude must resolve to a logical vector the same length as x", {
  expect_error(.cut_quantile(1:10, exclude = 1:10), "exclude")
  expect_error(.cut_quantile(1:10, exclude = c(TRUE, FALSE)), "exclude")
  expect_error(.cut_quantile(1:10, exclude = function(x) x[1:5] == 0), "exclude")
})

test_that("n_bins mode spans range(x) with n_bins equal-width bins", {
  x <- 0:100
  result <- .cut_evenly(x, n_bins = 5)

  expect_equal(nlevels(result), 5)
  expect_equal(unname(attr(result, "breaks")), seq(0, 100, by = 20))
  expect_equal(attr(result, "width"), 20)
  expect_false(anyNA(result))
})

test_that("width mode derives the number of bins from the data, anchored at min(x) by default", {
  x <- 1:10
  result <- .cut_evenly(x, width = 2)

  expect_equal(unname(attr(result, "breaks")), seq(1, 11, by = 2))
  expect_equal(attr(result, "width"), 2)
  expect_false(anyNA(result))
})

test_that("width mode respects an explicit start", {
  x <- 1:10
  result <- .cut_evenly(x, width = 2, start = 0)
  expect_equal(unname(attr(result, "breaks")), seq(0, 10, by = 2))
  expect_false(anyNA(result))
})

test_that("negative width builds bins downward from start (default max(x))", {
  x <- 1:9
  result <- .cut_evenly(x, width = -2)

  expect_equal(unname(attr(result, "breaks")), seq(1, 9, by = 2))
  expect_equal(attr(result, "width"), -2)
  expect_false(anyNA(result))
})

test_that("values outside the bins implied by an explicit start are NA with a warning", {
  x <- c(-5, 1:10)
  expect_warning(result <- .cut_evenly(x, width = 2, start = 0), "outside")
  expect_true(is.na(result[1]))
  expect_false(anyNA(result[-1]))
})

test_that("ties = 'upward'/'downward' match cut()'s right = TRUE/FALSE for evenly cut bins", {
  x <- c(0, 2, 4, 6, 8, 10)
  breaks <- seq(0, 10, by = 2)

  up <- .cut_evenly(x, width = 2, ties = "upward")
  down <- .cut_evenly(x, width = 2, ties = "downward")

  expect_equal(as.integer(up), as.integer(cut(x, breaks, labels = 1:5, include.lowest = TRUE)))
  expect_equal(as.integer(down), as.integer(cut(x, breaks, labels = 1:5, right = FALSE, include.lowest = TRUE)))
})

test_that("exactly one of n_bins/width must be supplied", {
  expect_error(.cut_evenly(1:10), "Exactly one")
  expect_error(.cut_evenly(1:10, n_bins = 4, width = 2), "Exactly one")
})

test_that("start without width is rejected", {
  expect_error(.cut_evenly(1:10, n_bins = 4, start = 0), "start")
})

test_that("n_bins mode errors when x has zero range", {
  expect_error(.cut_evenly(rep(5, 10), n_bins = 4), "are equal")
})

test_that("x must be numeric, and n_bins/width must be valid single numbers", {
  expect_error(.cut_evenly(letters[1:5], n_bins = 2), "numeric")
  expect_error(.cut_evenly(1:10, n_bins = 0), "n_bins")
  expect_error(.cut_evenly(1:10, width = 0), "width")
})

test_that("NA in x propagates to NA in the result", {
  x <- c(1:9, NA)
  result <- .cut_evenly(x, n_bins = 3)
  expect_true(is.na(result[10]))
  expect_equal(sum(is.na(result)), 1)
})

test_that("exclude keeps values out of the range calculation but labels them", {
  x <- c(rep(0, 5), 1:20)
  result <- .cut_evenly(x, n_bins = 4, exclude = function(x) x == 0, exclude_label = "None")

  expect_equal(levels(result), c("None", paste0("Q", 1:4)))
  expect_true(all(result[x == 0] == "None"))
  expect_equal(unname(attr(result, "breaks")), seq(1, 20, length.out = 5))
})

test_that("exclude = NULL never introduces an extra level", {
  result <- .cut_evenly(1:40, n_bins = 4)
  expect_equal(nlevels(result), 4)
})

test_that("labeller works the same way as for .cut_quantile()", {
  x <- 1:20
  by_fn <- .cut_evenly(x, n_bins = 4, labeller = function(n_bins, breaks) paste0("Bin ", 1:n_bins))
  expect_equal(levels(by_fn), paste0("Bin ", 1:4))

  by_chr <- .cut_evenly(x, n_bins = 4, labeller = c("Low", "Mid-low", "Mid-high", "High"))
  expect_equal(levels(by_chr), c("Low", "Mid-low", "Mid-high", "High"))
})
