source(testthat::test_path("..", "..", "minifilter.R"))

df <- data.frame(
  x = c(1, 2, 3, 4, NA),
  g = c("a", "a", "b", "b", "a"),
  stringsAsFactors = FALSE
)

test_that(".filter() keeps rows matching a single condition", {
  out <- .filter(df, g == "a")
  expect_equal(out$x, c(1, 2, NA))
})

test_that(".filter() combines multiple conditions with AND", {
  out <- .filter(df, g == "a", x > 1)
  expect_equal(out$x, 2)
})

test_that(".filter() drops rows where the condition is NA", {
  out <- .filter(df, x > 1)
  expect_equal(out$x, c(2, 3, 4))
})

test_that(".filter() with no conditions returns .data unchanged", {
  expect_equal(.filter(df), df)
})

test_that(".filter() evaluates conditions against .data's columns, not just the caller's", {
  threshold <- 2
  out <- .filter(df, x > threshold)
  expect_equal(out$x, c(3, 4))
})
