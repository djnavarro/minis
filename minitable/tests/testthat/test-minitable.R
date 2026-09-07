source(testthat::test_path("..", "..", "minitable.R"))

test_that(".table_tibble() builds a data.frame from name-value pairs", {
  out <- .table_tibble(a = 1:3, b = c("x", "y", "z"))
  expect_s3_class(out, "data.frame")
  expect_equal(out$a, 1:3)
  expect_equal(out$b, c("x", "y", "z"))
})

test_that(".table_tibble() supports cross-column references", {
  out <- .table_tibble(a = 1:3, b = a * 2, c = a + b)
  expect_equal(out$b, c(2, 4, 6))
  expect_equal(out$c, c(3, 6, 9))
})

test_that(".table_tibble() names unnamed columns after their expression", {
  out <- .table_tibble(1:2, letters[1:2])
  expect_equal(names(out), c("1:2", "letters[1:2]"))
})

test_that(".table_tibble() converts NULL/length-0 columns to NA", {
  out <- .table_tibble(a = 1, b = NULL)
  expect_true(is.na(out$b))
})

test_that(".table_as_tibble() coerces to a plain data.frame", {
  out <- .table_as_tibble(matrix(1:4, nrow = 2))
  expect_s3_class(out, "data.frame")
  expect_equal(dim(out), c(2, 2))
})

test_that(".table_rownames_to_column() moves custom row names into a column", {
  df <- data.frame(x = 1:2, row.names = c("r1", "r2"))
  out <- .table_rownames_to_column(df, var = "id")
  expect_equal(out$id, c("r1", "r2"))
  expect_equal(rownames(out), c("1", "2"))
})

test_that(".table_rownames_to_column() is a no-op for default sequential row names", {
  df <- data.frame(x = 1:2)
  out <- .table_rownames_to_column(df, var = "id")
  expect_false("id" %in% names(out))
  expect_equal(out, df)
})

test_that(".table_add_row() appends a row matched by column name", {
  df <- data.frame(x = 1:2, y = c("a", "b"), stringsAsFactors = FALSE)
  out <- .table_add_row(df, x = 3, y = "c")
  expect_equal(nrow(out), 3)
  expect_equal(out$x, c(1, 2, 3))
  expect_equal(out$y, c("a", "b", "c"))
})

test_that(".table_add_row() supports cross-column references in the new row", {
  df <- data.frame(x = 1:2, y = c(2, 4))
  out <- .table_add_row(df, x = 3, y = x * 2)
  expect_equal(out$x, c(1, 2, 3))
  expect_equal(out$y, c(2, 4, 6))
})
