source(testthat::test_path("..", "..", "minitrap.R"))

test_that(".trap_safely() returns the result with a NULL error on success", {
  safe_sqrt <- .trap_safely(sqrt)
  out <- safe_sqrt(4)
  expect_equal(out$result, 2)
  expect_null(out$error)
})

test_that(".trap_safely() returns a NULL result with the error on failure", {
  safe_fn <- .trap_safely(function() stop("boom"))
  out <- safe_fn()
  expect_null(out$result)
  expect_s3_class(out$error, "error")
  expect_equal(conditionMessage(out$error), "boom")
})

test_that(".trap_safely() passes arguments through to .f", {
  safe_paste <- .trap_safely(paste0)
  expect_equal(safe_paste("a", "b")$result, "ab")
})

test_that(".trap_quietly() captures cat() output and still returns the result", {
  quiet_fn <- .trap_quietly(function() {
    cat("hello")
    42
  })
  out <- quiet_fn()
  expect_equal(out$result, 42)
  expect_equal(out$output, "hello")
  expect_equal(out$warnings, character())
  expect_equal(out$messages, character())
})

test_that(".trap_quietly() captures warnings without letting them propagate", {
  quiet_fn <- .trap_quietly(function() {
    warning("careful")
    1
  })
  expect_silent(out <- quiet_fn())
  expect_equal(out$warnings, "careful")
})

test_that(".trap_quietly() captures messages without letting them propagate", {
  quiet_fn <- .trap_quietly(function() {
    message("hi")
    1
  })
  expect_silent(out <- quiet_fn())
  expect_equal(out$messages, "hi\n")
})

test_that(".trap_quietly() captures multiple warnings/messages, in order", {
  quiet_fn <- .trap_quietly(function() {
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

test_that(".trap_quietly() still lets real errors propagate", {
  quiet_fn <- .trap_quietly(function() stop("boom"))
  expect_error(quiet_fn(), "boom")
})

test_that(".trap_safely() and .trap_quietly() compose", {
  both <- .trap_safely(.trap_quietly(function() {
    message("hi")
    stop("boom")
  }))
  out <- both()
  expect_null(out$result)
  expect_s3_class(out$error, "error")
})
