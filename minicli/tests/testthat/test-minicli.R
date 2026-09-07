source(testthat::test_path("..", "..", "minicli.R"))

test_that("ansi styling no-ops when ansi is disabled", {
  withr::local_options(cli.num_colors = 1)
  expect_equal(.cli_col_red("x"), "x")
  expect_equal(.cli_style_bold("x"), "x")
})

test_that("ansi styling wraps text with SGR codes when enabled", {
  withr::local_options(cli.num_colors = 8)
  expect_equal(.cli_col_red("x"), "\033[31mx\033[0m")
  expect_equal(.cli_style_bold("x"), "\033[1mx\033[0m")
})

test_that("styles can be nested without breaking the outer style", {
  withr::local_options(cli.num_colors = 8)
  expect_equal(.cli_style_bold(.cli_col_red("x")), "\033[1m\033[31mx\033[0m\033[0m")
})

test_that("NO_COLOR disables ansi even when otherwise allowed", {
  withr::local_options(cli.num_colors = NULL)
  withr::local_envvar(NO_COLOR = "1")
  expect_equal(.cli_col_red("x"), "x")
})

test_that("knitr.in.progress disables ansi", {
  withr::local_options(cli.num_colors = NULL, knitr.in.progress = TRUE)
  expect_equal(.cli_col_red("x"), "x")
})

test_that("an explicit cli.num_colors option overrides the knitr fallback", {
  withr::local_options(cli.num_colors = 8, knitr.in.progress = TRUE)
  expect_equal(.cli_col_red("x"), "\033[31mx\033[0m")
})

test_that("Positron's console is detected as ansi-capable even though it's not a tty", {
  withr::local_options(cli.num_colors = NULL, cli.default_num_colors = 8)
  withr::local_envvar(POSITRON = "1", RSTUDIO = "", NO_COLOR = "")
  expect_true(.cli_positron_console_with_color())
  expect_equal(.cli_col_red("x"), "\033[31mx\033[0m")
})

test_that("Positron detection requires both the env var and the option", {
  withr::local_options(cli.num_colors = NULL, cli.default_num_colors = NULL)
  withr::local_envvar(POSITRON = "1", RSTUDIO = "", NO_COLOR = "")
  expect_false(.cli_positron_console_with_color())

  withr::local_options(cli.default_num_colors = 8)
  withr::local_envvar(POSITRON = "", RSTUDIO = "", NO_COLOR = "")
  expect_false(.cli_positron_console_with_color())
})

test_that("RStudio's Console pane is detected as ansi-capable even though it's not a tty", {
  withr::local_options(cli.num_colors = NULL)
  withr::local_envvar(RSTUDIO = "1", RSTUDIO_CONSOLE_COLOR = "256", POSITRON = "", NO_COLOR = "")
  expect_true(.cli_rstudio_console_with_color())
  expect_equal(.cli_col_red("x"), "\033[31mx\033[0m")
})

test_that("RStudio detection excludes non-Console panes (no RSTUDIO_CONSOLE_COLOR)", {
  withr::local_options(cli.num_colors = NULL)
  withr::local_envvar(RSTUDIO = "1", RSTUDIO_CONSOLE_COLOR = "", POSITRON = "", NO_COLOR = "")
  expect_false(.cli_rstudio_console_with_color())
})

test_that("symbols fall back to ascii when unicode is disabled", {
  withr::local_options(cli.unicode = FALSE)
  expect_equal(.cli_symbol("tick"), "v")
  expect_equal(.cli_symbol("cross"), "x")
})

test_that("symbols use unicode glyphs when enabled", {
  withr::local_options(cli.unicode = TRUE)
  expect_equal(.cli_symbol("tick"), "\u2714")
})

test_that(".cli_symbol errors on an unknown name", {
  expect_error(.cli_symbol("nope"), "Unknown symbol")
})

test_that("alert functions message the right text, with sprintf interpolation", {
  withr::local_options(cli.num_colors = 1, cli.unicode = FALSE)
  expect_message(.cli_alert_success("done"), "v done", fixed = TRUE)
  expect_message(.cli_alert_success("wrote %d files", 3), "v wrote 3 files", fixed = TRUE)
  expect_message(.cli_alert_danger("failed"), "x failed", fixed = TRUE)
  expect_message(.cli_alert_warning("careful"), "! careful", fixed = TRUE)
  expect_message(.cli_alert_info("fyi"), "i fyi", fixed = TRUE)
})

test_that(".cli_rule produces a line of the configured width, with a centred title", {
  withr::local_options(width = 20, cli.num_colors = 1, cli.unicode = FALSE)
  expect_message(.cli_rule(), strrep("-", 20), fixed = TRUE)
  expect_message(.cli_rule("Hi"), "Hi", fixed = TRUE)
})

test_that(".cli_bullets prefixes each item", {
  withr::local_options(cli.num_colors = 1, cli.unicode = FALSE)
  expect_message(.cli_bullets(c("a", "b")), "* a\n* b", fixed = TRUE)
})
