source(testthat::test_path("..", "..", "minifilter.R"))

df <- data.frame(
  x = c(1, 2, 3, 4, NA),
  g = c("a", "a", "b", "b", "a"),
  stringsAsFactors = FALSE
)

test_that("mfilter_filter() keeps rows matching a single condition", {
  out <- mfilter_filter(df, g == "a")
  expect_equal(out$x, c(1, 2, NA))
})

test_that("mfilter_filter() combines multiple conditions with AND", {
  out <- mfilter_filter(df, g == "a", x > 1)
  expect_equal(out$x, 2)
})

test_that("mfilter_filter() drops rows where the condition is NA", {
  out <- mfilter_filter(df, x > 1)
  expect_equal(out$x, c(2, 3, 4))
})

test_that("mfilter_filter() with no conditions returns .data unchanged", {
  expect_equal(mfilter_filter(df), df)
})

test_that("mfilter_filter() evaluates conditions against .data's columns, not just the caller's", {
  threshold <- 2
  out <- mfilter_filter(df, x > threshold)
  expect_equal(out$x, c(3, 4))
})
