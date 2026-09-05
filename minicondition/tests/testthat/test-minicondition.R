source(testthat::test_path("..", "..", "minicondition.R"))

test_that("mcond_abort() raises an error with the given message", {
  expect_error(mcond_abort("bad input"), "bad input")
})

test_that("mcond_abort() is catchable by a custom class", {
  out <- tryCatch(
    mcond_abort("bad input", class = "my_error"),
    my_error = function(e) paste("caught:", conditionMessage(e))
  )
  expect_equal(out, "caught: bad input")
})

test_that("mcond_abort() without a class is not catchable by an unrelated class", {
  expect_error(
    tryCatch(mcond_abort("bad input"), my_error = function(e) "should not fire"),
    "bad input"
  )
})

test_that("mcond_warn() raises a warning with the given message", {
  expect_warning(mcond_warn("careful"), "careful")
})

test_that("mcond_warn() is catchable by a custom class", {
  out <- tryCatch(
    mcond_warn("careful", class = "my_warning"),
    my_warning = function(w) paste("caught:", conditionMessage(w))
  )
  expect_equal(out, "caught: careful")
})

test_that("mcond_inform() raises a message with the given text", {
  expect_message(mcond_inform("hi there"), "hi there")
})

test_that("mcond_inform() is catchable by a custom class", {
  out <- withCallingHandlers(
    {
      mcond_inform("hi there", class = "my_message")
      "not caught"
    },
    my_message = function(m) {
      invokeRestart("muffleMessage")
    }
  )
  expect_equal(out, "not caught")
  expect_message(
    withCallingHandlers(
      mcond_inform("hi there", class = "my_message"),
      my_message = function(m) cat("caught:", conditionMessage(m))
    ),
    "hi there"
  )
})

test_that("mcond_assert() passes silently when the condition holds", {
  expect_no_error(mcond_assert(TRUE))
  expect_no_error(mcond_assert(c(TRUE, TRUE)))
})

test_that("mcond_assert() aborts when the condition fails", {
  expect_error(mcond_assert(FALSE, "x must be positive"), "x must be positive")
  expect_error(mcond_assert(c(TRUE, FALSE), "not all true"), "not all true")
})

test_that("mcond_assert() treats NA as a failure, not an error about missing values", {
  expect_error(mcond_assert(c(TRUE, NA)), "Assertion failed")
})

test_that("mcond_assert() passes its class through to the resulting error", {
  out <- tryCatch(
    mcond_assert(FALSE, "bad", class = "my_invalid_input"),
    my_invalid_input = function(e) "caught"
  )
  expect_equal(out, "caught")
})
