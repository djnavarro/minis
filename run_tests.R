#!/usr/bin/env Rscript
## Runs every mini's tests/testthat/ suite and exits non-zero on failure.
## Dev dependencies: testthat, withr (only needed to run these tests --
## not required by anything the minis themselves produce).

root <- dirname(normalizePath(sub("--file=", "", grep("--file=", commandArgs(trailingOnly = FALSE), value = TRUE)[1])))
if (!length(root) || is.na(root)) root <- getwd()

minis <- list.dirs(root, recursive = FALSE, full.names = TRUE)
minis <- minis[!grepl("^\\.", basename(minis))]
minis <- minis[file.exists(file.path(minis, "tests", "testthat"))]

if (!length(minis)) {
  cat("No minis with a tests/testthat/ directory were found.\n")
  quit(status = 0)
}

ok <- TRUE
for (d in minis) {
  cat("\n== Testing", basename(d), "==\n")
  ok <- tryCatch(
    {
      testthat::test_dir(file.path(d, "tests", "testthat"),
        stop_on_failure = TRUE, reporter = "summary"
      )
      ok
    },
    error = function(e) {
      message("FAILED: ", basename(d), " - ", conditionMessage(e))
      FALSE
    }
  )
}

if (!ok) {
  cat("\nOne or more mini test suites failed.\n")
  quit(status = 1)
}
cat("\nAll mini test suites passed.\n")
