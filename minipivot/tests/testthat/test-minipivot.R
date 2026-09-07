source(testthat::test_path("..", "..", "minipivot.R"))

fish <- data.frame(
  location = c("lake", "lake", "sea", "sea"),
  species = c("trout", "bass", "trout", "bass"),
  count = c(5, 3, 7, 2)
)

wk <- data.frame(
  id = 1:2,
  group = c("a", "b"),
  wk1 = c(1, 3),
  wk2 = c(2, 4)
)

test_that(".pivot_longer selects cols by bare names and by c(...)", {
  out1 <- .pivot_longer(wk, c(wk1, wk2))
  out2 <- .pivot_longer(wk, wk1)
  expect_equal(nrow(out1), 4L)
  expect_equal(names(out1), c("id", "group", "name", "value"))
  expect_equal(out1$name, c("wk1", "wk2", "wk1", "wk2"))
  expect_equal(out1$value, c(1, 2, 3, 4))
  expect_equal(nrow(out2), 2L)
})

test_that(".pivot_longer selects cols by character vector and by negation", {
  out_chr <- .pivot_longer(wk, c("wk1", "wk2"), names_to = "week", values_to = "val")
  out_neg <- .pivot_longer(wk, -c(id, group), names_to = "week", values_to = "val")
  expect_equal(names(out_chr), c("id", "group", "week", "val"))
  expect_equal(out_chr, out_neg)
})

test_that(".pivot_longer preserves row-major order (all cols for row 1, then row 2, ...)", {
  out <- .pivot_longer(wk, c(wk1, wk2))
  expect_equal(out$id, c(1, 1, 2, 2))
})

test_that(".pivot_longer works with zero id columns", {
  df <- data.frame(wk1 = c(1, 3), wk2 = c(2, 4))
  out <- .pivot_longer(df, c(wk1, wk2))
  expect_equal(names(out), c("name", "value"))
  expect_equal(nrow(out), 4L)
})

test_that(".pivot_longer errors on an unmatched column name", {
  expect_error(.pivot_longer(wk, c("nope")))
})

test_that(".pivot_longer keeps the values_to column when .data has zero rows", {
  df0 <- data.frame(id = integer(0), a = numeric(0), b = numeric(0))
  out <- .pivot_longer(df0, c(a, b))
  expect_equal(names(out), c("id", "name", "value"))
  expect_equal(nrow(out), 0L)
})

test_that(".pivot_wider spreads names_from/values_from into new columns", {
  out <- .pivot_wider(fish, names_from = "species", values_from = "count")
  expect_equal(names(out), c("location", "trout", "bass"))
  expect_equal(out$trout, c(5, 7))
  expect_equal(out$bass, c(3, 2))
})

test_that(".pivot_wider fills missing combinations with NA by default", {
  out <- .pivot_wider(fish[-4, ], names_from = "species", values_from = "count")
  expect_true(is.na(out$bass[out$location == "sea"]))
})

test_that(".pivot_wider fills missing combinations with values_fill", {
  out <- .pivot_wider(fish[-4, ], names_from = "species", values_from = "count", values_fill = 0)
  expect_equal(out$bass[out$location == "sea"], 0)
})

test_that(".pivot_wider errors on a duplicate names_from/id combination", {
  dup <- rbind(fish, data.frame(location = "lake", species = "trout", count = 99))
  expect_error(.pivot_wider(dup, names_from = "species", values_from = "count"))
})

test_that(".pivot_wider works with zero id columns", {
  df <- data.frame(k = c("a", "b"), v = c(1, 2))
  out <- .pivot_wider(df, names_from = "k", values_from = "v")
  expect_equal(names(out), c("a", "b"))
  expect_equal(nrow(out), 1L)
  expect_equal(out$a, 1)
  expect_equal(out$b, 2)
})

test_that(".pivot_wider errors when names_from/values_from aren't valid single column names", {
  expect_error(.pivot_wider(fish, names_from = c("species", "location"), values_from = "count"))
  expect_error(.pivot_wider(fish, names_from = "nope", values_from = "count"))
})

test_that(".pivot_wider errors instead of silently overwriting a colliding id column", {
  df <- data.frame(loc = c("lake", "sea"), grp = c("loc", "other"), val = c(1, 2))
  expect_error(.pivot_wider(df, names_from = "grp", values_from = "val"), "collide")
})

test_that(".pivot_wider turns a NA in names_from into a column literally named \"NA\"", {
  df <- data.frame(id = c(1, 1, 2), key = c("a", NA, "a"), val = c(10, 20, 30))
  out <- .pivot_wider(df, names_from = "key", values_from = "val")
  expect_equal(names(out), c("id", "a", "NA"))
  expect_equal(out[["NA"]], c(20, NA))
})

test_that(".pivot_wider preserves real values' type when values_fill's type differs", {
  df <- data.frame(location = c("lake", "lake", "sea"), species = c("trout", "bass", "trout"), count = c(5, 3, 7))
  out <- expect_warning(
    .pivot_wider(df, names_from = "species", values_from = "count", values_fill = "missing"),
    "different type"
  )
  expect_equal(out$trout, c("5", "7"))
  expect_equal(out$bass, c("3", "missing"))
})

test_that("pivot_longer and pivot_wider round-trip", {
  long <- .pivot_longer(fish, count, names_to = "metric", values_to = "n")
  expect_equal(nrow(long), nrow(fish))
  wide <- .pivot_wider(fish, names_from = "species", values_from = "count")
  back <- .pivot_longer(wide, c(trout, bass), names_to = "species", values_to = "count")
  expect_equal(sort(back$count), sort(fish$count))
})
