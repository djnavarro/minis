source(testthat::test_path("..", "..", "ministr.R"))

test_that(".str_pad() pads left by default", {
  expect_equal(.str_pad("7", 3), "  7")
})

test_that(".str_pad() supports right and both sides", {
  expect_equal(.str_pad("7", 3, side = "right"), "7  ")
  expect_equal(.str_pad("7", 4, side = "both"), " 7  ")
})

test_that(".str_pad() supports a custom pad character", {
  expect_equal(.str_pad("7", 3, pad = "0"), "007")
})

test_that(".str_pad() leaves strings already wide enough unchanged", {
  expect_equal(.str_pad("hello", 3), "hello")
})

test_that(".str_pad() recycles and propagates NA", {
  expect_equal(.str_pad(c("a", NA, "bb"), 3), c("  a", NA, " bb"))
})

test_that(".str_pad() errors on a multi-character pad", {
  expect_error(.str_pad("7", 3, pad = "00"))
})

test_that(".str_trim() trims both sides by default", {
  expect_equal(.str_trim("  hi  "), "hi")
})

test_that(".str_trim() trims a single side", {
  expect_equal(.str_trim("  hi  ", side = "left"), "hi  ")
  expect_equal(.str_trim("  hi  ", side = "right"), "  hi")
})

test_that(".str_squish() trims and collapses internal whitespace", {
  expect_equal(.str_squish("  too   much   space  "), "too much space")
})

test_that(".str_squish() propagates NA", {
  expect_equal(.str_squish(NA_character_), NA_character_)
})

test_that(".str_sub() extracts with positive indices", {
  expect_equal(.str_sub("hello world", 1, 5), "hello")
})

test_that(".str_sub() extracts with negative indices", {
  expect_equal(.str_sub("hello world", -5, -1), "world")
})

test_that(".str_sub() defaults to the whole string", {
  expect_equal(.str_sub("hello"), "hello")
})

test_that(".str_sub() clamps out-of-range positions", {
  expect_equal(.str_sub("hi", 1, 10), "hi")
  expect_equal(.str_sub("hi", -10, -1), "hi")
})

test_that(".str_sub() returns empty string when start > end", {
  expect_equal(.str_sub("hello", 4, 2), "")
})

test_that(".str_sub() propagates NA and recycles", {
  expect_equal(.str_sub(c("hello", NA), 1, 3), c("hel", NA))
})

test_that(".str_length() counts characters and propagates NA", {
  expect_equal(.str_length(c("hi", "", NA)), c(2L, 0L, NA))
})

test_that(".str_to_upper()/.str_to_lower() convert case", {
  expect_equal(.str_to_upper("Hello"), "HELLO")
  expect_equal(.str_to_lower("Hello"), "hello")
})

test_that(".str_to_title() capitalises each word", {
  expect_equal(.str_to_title("the QUICK brown Fox"), "The Quick Brown Fox")
})

test_that(".str_to_sentence() capitalises only the first letter", {
  expect_equal(.str_to_sentence("the CAT in the hat"), "The cat in the hat")
})

test_that(".str_dup() repeats strings", {
  expect_equal(.str_dup("ab", 3), "ababab")
  expect_equal(.str_dup(c("a", "b"), c(2, 3)), c("aa", "bbb"))
})

test_that(".str_c() concatenates and recycles", {
  expect_equal(.str_c("a", c("x", "y"), sep = "-"), c("a-x", "a-y"))
})

test_that(".str_c() propagates NA elementwise", {
  expect_equal(.str_c("a", NA), NA_character_)
  expect_equal(.str_c(c("a", NA), c("x", "y")), c("ax", NA))
})

test_that(".str_c() returns character(0) for zero-length input", {
  expect_equal(.str_c(character(0), "a"), character(0))
  expect_equal(.str_c(), character(0))
})

test_that(".str_c() errors on incompatible recycling lengths", {
  expect_error(.str_c(c("a", "b"), c("x", "y", "z")))
})

test_that(".str_c() collapses, propagating NA", {
  expect_equal(.str_c(c("a", "b"), collapse = "-"), "a-b")
  expect_equal(.str_c(c("a", NA), collapse = "-"), NA_character_)
})

test_that(".str_wrap() wraps to the given width", {
  out <- .str_wrap("the quick brown fox jumps", width = 10)
  expect_true(all(nchar(strsplit(out, "\n")[[1]]) <= 10))
})

test_that(".str_wrap() is vectorised and propagates NA", {
  out <- .str_wrap(c("a short line", NA), width = 5)
  expect_true(is.na(out[2]))
  expect_false(is.na(out[1]))
})
