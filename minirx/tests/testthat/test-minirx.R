source(testthat::test_path("..", "..", "minirx.R"))

test_that(".rx_detect() detects matches and propagates NA", {
  expect_equal(.rx_detect(c("cat", "dog", NA), "^c"), c(TRUE, FALSE, NA))
})

test_that(".rx_detect() supports negate", {
  expect_equal(.rx_detect(c("cat", "dog"), "^c", negate = TRUE), c(FALSE, TRUE))
})

test_that(".rx_starts()/.rx_ends() anchor the pattern", {
  expect_equal(.rx_starts(c("cat", "scat"), "c"), c(TRUE, FALSE))
  expect_equal(.rx_ends(c("cat", "cats"), "t"), c(TRUE, FALSE))
})

test_that(".rx_extract() extracts the first match and NA for no match", {
  expect_equal(
    .rx_extract(c("item-12", "item-x", NA), "[0-9]+"),
    c("12", NA, NA)
  )
})

test_that(".rx_extract() does not silently drop non-matching elements", {
  out <- .rx_extract(c("a1", "no digits", "b2"), "[0-9]+")
  expect_length(out, 3)
  expect_equal(out, c("1", NA, "2"))
})

test_that(".rx_extract_all() returns one vector of matches per string", {
  out <- .rx_extract_all(c("a1 b2", "none", NA), "[0-9]")
  expect_equal(out[[1]], c("1", "2"))
  expect_equal(out[[2]], character(0))
  expect_equal(out[[3]], NA_character_)
})

test_that(".rx_match() extracts capture groups into a matrix", {
  out <- .rx_match(c("a1", "no match", "b2"), "([a-z])([0-9])")
  expect_equal(out[1, ], c("a1", "a", "1"))
  expect_true(all(is.na(out[2, ])))
  expect_equal(out[3, ], c("b2", "b", "2"))
})

test_that(".rx_match_all() returns one matrix per string", {
  out <- .rx_match_all(c("a1 b2", "none", NA), "([a-z])([0-9])")
  expect_equal(out[[1]], matrix(c("a1", "b2", "a", "b", "1", "2"), nrow = 2))
  expect_equal(dim(out[[2]]), c(0L, 3L))
  expect_equal(dim(out[[3]]), c(1L, 3L))
  expect_true(all(is.na(out[[3]])))
})

test_that(".rx_replace()/.rx_replace_all() replace matches", {
  expect_equal(.rx_replace("a-b-c", "-", "_"), "a_b-c")
  expect_equal(.rx_replace_all("a-b-c", "-", "_"), "a_b_c")
})

test_that(".rx_replace_all() supports backreferences", {
  expect_equal(.rx_replace_all("2024-01-02", "(\\d+)-(\\d+)-(\\d+)", "\\3/\\2/\\1"), "02/01/2024")
})

test_that(".rx_remove()/.rx_remove_all() remove matches", {
  expect_equal(.rx_remove("a-b-c", "-"), "ab-c")
  expect_equal(.rx_remove_all("a-b-c", "-"), "abc")
})

test_that(".rx_split() splits on every match", {
  expect_equal(.rx_split("a,b,,c", ",")[[1]], c("a", "b", "", "c"))
})

test_that(".rx_count() counts matches, fixing the -1 no-match sentinel", {
  expect_equal(.rx_count(c("aaa", "", "b", NA), "a"), c(3L, 0L, 0L, NA))
})

test_that(".rx_locate() finds the first match's position", {
  out <- .rx_locate(c("xxaax", "none", NA), "a+")
  expect_equal(out[1, ], c(start = 3, end = 4))
  expect_true(all(is.na(out[2, ])))
  expect_true(all(is.na(out[3, ])))
})

test_that(".rx_locate_all() finds every match's position", {
  out <- .rx_locate_all(c("a1a2", "none", NA), "a")
  expect_equal(out[[1]], cbind(start = c(1, 3), end = c(1, 3)))
  expect_equal(dim(out[[2]]), c(0L, 2L))
  expect_equal(dim(out[[3]]), c(1L, 2L))
  expect_true(all(is.na(out[[3]])))
})
