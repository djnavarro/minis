source(testthat::test_path("..", "..", "minitrap.R"))

test_that("mtrap_safely() returns the result with a NULL error on success", {
  safe_sqrt <- mtrap_safely(sqrt)
  out <- safe_sqrt(4)
  expect_equal(out$result, 2)
  expect_null(out$error)
})

test_that("mtrap_safely() returns a NULL result with the error on failure", {
  safe_fn <- mtrap_safely(function() stop("boom"))
  out <- safe_fn()
  expect_null(out$result)
  expect_s3_class(out$error, "error")
  expect_equal(conditionMessage(out$error), "boom")
})

test_that("mtrap_safely() passes arguments through to .f", {
  safe_paste <- mtrap_safely(paste0)
  expect_equal(safe_paste("a", "b")$result, "ab")
})

test_that("mtrap_quietly() captures cat() output and still returns the result", {
  quiet_fn <- mtrap_quietly(function() {
    cat("hello")
    42
  })
  out <- quiet_fn()
  expect_equal(out$result, 42)
  expect_equal(out$output, "hello")
  expect_equal(out$warnings, character())
  expect_equal(out$messages, character())
})

test_that("mtrap_quietly() captures warnings without letting them propagate", {
  quiet_fn <- mtrap_quietly(function() {
    warning("careful")
    1
  })
  expect_silent(out <- quiet_fn())
  expect_equal(out$warnings, "careful")
})

test_that("mtrap_quietly() captures messages without letting them propagate", {
  quiet_fn <- mtrap_quietly(function() {
    message("hi")
    1
  })
  expect_silent(out <- quiet_fn())
  expect_equal(out$messages, "hi\n")
})

test_that("mtrap_quietly() captures multiple warnings/messages, in order", {
  quiet_fn <- mtrap_quietly(function() {
    message("m1")
    warning("w1")
    message("m2")
    "done"
  })
  out <- quiet_fn()
  expect_equal(out$result, "done")
  expect_equal(out$messages, c("m1\n", "m2\n"))
  expect_equal(out$warnings, "w1")
})

test_that("mtrap_quietly() still lets real errors propagate", {
  quiet_fn <- mtrap_quietly(function() stop("boom"))
  expect_error(quiet_fn(), "boom")
})

test_that("mtrap_safely() and mtrap_quietly() compose", {
  both <- mtrap_safely(mtrap_quietly(function() {
    message("hi")
    stop("boom")
  }))
  out <- both()
  expect_null(out$result)
  expect_s3_class(out$error, "error")
})
