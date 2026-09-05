source(testthat::test_path("..", "..", "minimap.R"))

add_one <- function(x) x + 1

test_that("mmap_map() applies a function elementwise and preserves names", {
  expect_equal(mmap_map(list(1, "a", TRUE), as.character), list("1", "a", "TRUE"))
  expect_equal(mmap_map(1:3, add_one), list(2, 3, 4))
  expect_equal(mmap_map(c(a = 1, b = 2), add_one), list(a = 2, b = 3))
})

test_that("mmap_map_xxx() are type-stable and vector-returning", {
  expect_equal(mmap_map_chr(list(1, "a", TRUE), as.character), c("1", "a", "TRUE"))
  expect_equal(mmap_map_dbl(1:3, add_one), c(2, 3, 4))
  expect_equal(mmap_map_lgl(list(1, "a", TRUE), is.character), c(FALSE, TRUE, FALSE))
})

test_that("mmap_map_dbl() errors when .f doesn't return a length-1 double", {
  expect_error(mmap_map_dbl(1:3, as.character))
  expect_error(mmap_map_dbl(1:3, function(x) c(x, x)))
})

test_that("mmap_walk() runs for side effects and returns .x invisibly", {
  expect_output(mmap_walk(list(1, "a", TRUE), cat), "1aTRUE")
  invisible(capture.output(res <- mmap_walk(list(1, "a", TRUE), cat)))
  expect_equal(res, list(1, "a", TRUE))
  expect_invisible(mmap_walk(list(1), identity))
})

test_that("mmap_map2() applies a function pairwise", {
  expect_equal(mmap_map2(1:3, c("a", "b", "c"), paste0), list("1a", "2b", "3c"))
})

test_that("mmap_map2() asserts .x and .y have equal length", {
  expect_error(mmap_map2(1:2, 1:3, paste0))
})

test_that("mmap_imap() applies a function to each element and its name", {
  expect_equal(
    mmap_imap(c(a = 1, b = 2, c = 3), paste0),
    list(a = "1a", b = "2b", c = "3c")
  )
})

test_that("mmap_imap() asserts .x is named", {
  expect_error(mmap_imap(1:3, paste0))
  expect_error(mmap_imap(list(1, 2), paste0))
})

test_that("mmap_iwalk() runs for side effects keyed by name, returns .x invisibly", {
  expect_output(
    mmap_iwalk(c(a = 1, b = 2), function(val, name) cat(name, val, " ")),
    "a 1  b 2"
  )
  expect_invisible(mmap_iwalk(c(a = 1), function(val, name) invisible(NULL)))
})

test_that("mmap_iwalk() asserts .x is named", {
  expect_error(mmap_iwalk(1:3, function(val, name) NULL))
})
