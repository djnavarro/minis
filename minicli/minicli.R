## minicli.R -----------------------------------------------------------
##
## A minimal, dependency-free stand-in for the parts of {cli} most
## packages actually use: coloured/styled text, unicode-with-ascii-
## fallback symbols, and a handful of `alert_*()` message helpers.
##
## Design notes:
## - Base R only. No imports, no Suggests required.
## - All functions are dot-prefixed with the short tag `.cli_` --
##   there's no separate exported-vs-internal naming split, since
##   every function here is meant to be treated as an implementation
##   detail once copied into a consuming package.
## - Detection honours the same session options {cli} itself uses
##   (`cli.num_colors`, `cli.unicode`), so behaviour stays consistent
##   if a user or a calling package has already configured cli.
## - ANSI detection also recognises Positron's and RStudio's Console
##   panes explicitly, since neither is a real tty (isatty(stdout())
##   is FALSE in both), which would otherwise disable colour there.
##   Ported from djnavarro/sessioncheck's R/display.R after this gap
##   surfaced while reimplementing minicli-style helpers in that
##   package.
## - Deliberately excluded: glue-style interpolation (use sprintf()),
##   theming/nesting scopes, progress bars, trees, boxes, colour-depth
##   detection (256/truecolor) -- none of this is needed to get
##   "pretty in a terminal, plain in an Rmd/Quarto render".
##
## Usage:
##   source("minicli.R")
##   .cli_alert_success("Wrote %d files", 3)
##
## License: MIT (see LICENSE at the root of the minis repo). This file
## contains no code copied from {cli}/{crayon}, only equivalent logic.

# --- capability detection ---------------------------------------------

#' Does RStudio's Console pane support ANSI colour?
#'
#' RStudio (>= 1.3) sets `RSTUDIO_CONSOLE_COLOR` only in the Console pane,
#' not in the Terminal pane, Build pane, or RStudio Jobs, so this is a
#' safe, console-scoped signal -- unlike a bare `RSTUDIO == "1"` check,
#' which is set in all of those contexts. Mirrors the approach used by
#' crayon/cli's `rstudio_with_ansi_support()`.
#' @noRd
.cli_rstudio_console_with_color <- function() {
  if (!identical(Sys.getenv("RSTUDIO", ""), "1")) return(FALSE)
  cols <- Sys.getenv("RSTUDIO_CONSOLE_COLOR", "")
  !is.na(suppressWarnings(as.numeric(cols)))
}

#' Does Positron's console support ANSI colour?
#'
#' ark (Positron's R kernel) sets `options(cli.default_num_colors = <n>)`
#' directly at session startup to tell `cli` that its console can render
#' ANSI colour, bypassing `isatty()`/RSTUDIO-style detection entirely --
#' Positron's console is not a real tty, and it does not set
#' `RSTUDIO = "1"`. Scoped to `Sys.getenv("POSITRON") == "1"` so this
#' doesn't trust `cli.default_num_colors` if something else set it
#' outside of a Positron session.
#' @noRd
.cli_positron_console_with_color <- function() {
  if (!identical(Sys.getenv("POSITRON", ""), "1")) return(FALSE)
  n <- getOption("cli.default_num_colors", NULL)
  is.numeric(n) && n > 1
}

#' Is ANSI styling safe to emit right now?
#'
#' `cli.num_colors` is checked first so that this defers to detection
#' already performed by other packages (e.g. cli) when present. After
#' that, front-end signals are checked in order: Positron's console, then
#' RStudio's console, falling back to `isatty(stdout())` for plain
#' terminals -- both consoles are not real ttys, so without these checks
#' colour would be silently disabled in them.
#' @noRd
.cli_ansi_enabled <- function() {
  opt <- getOption("cli.num_colors", NULL)
  if (!is.null(opt)) return(opt > 1)

  # https://no-color.org
  if (nzchar(Sys.getenv("NO_COLOR", ""))) return(FALSE)

  # knitr/Quarto capture output to a string buffer, not a real terminal
  if (isTRUE(getOption("knitr.in.progress"))) return(FALSE)

  # output has been redirected/captured (e.g. capture.output(), testthat)
  if (sink.number() > 0) return(FALSE)

  if (.cli_positron_console_with_color()) return(TRUE)
  if (.cli_rstudio_console_with_color()) return(TRUE)

  isatty(stdout())
}

#' Is it safe to print unicode symbols right now?
#' @noRd
.cli_unicode_enabled <- function() {
  opt <- getOption("cli.unicode", NULL)
  if (!is.null(opt)) return(isTRUE(opt))
  isTRUE(l10n_info()[["UTF-8"]])
}

# --- styling ------------------------------------------------------------

#' Build a function that wraps text in an SGR code, no-op when disabled
#' @noRd
.cli_ansi_style <- function(code) {
  force(code)
  function(text) {
    if (!.cli_ansi_enabled()) return(text)
    paste0("\033[", code, "m", text, "\033[0m")
  }
}

.cli_col_black   <- .cli_ansi_style("30")
.cli_col_red     <- .cli_ansi_style("31")
.cli_col_green   <- .cli_ansi_style("32")
.cli_col_yellow  <- .cli_ansi_style("33")
.cli_col_blue    <- .cli_ansi_style("34")
.cli_col_magenta <- .cli_ansi_style("35")
.cli_col_cyan    <- .cli_ansi_style("36")
.cli_col_white   <- .cli_ansi_style("37")
.cli_col_grey    <- .cli_ansi_style("90")

.cli_style_bold      <- .cli_ansi_style("1")
.cli_style_dim       <- .cli_ansi_style("2")
.cli_style_italic    <- .cli_ansi_style("3")
.cli_style_underline <- .cli_ansi_style("4")

# Styles can be freely nested, e.g. .cli_style_bold(.cli_col_red("x")),
# because each wrapper's reset code is always emitted immediately after
# its own content, never in the middle of a still-open outer style.

# --- symbols with ascii fallback ----------------------------------------

.cli_symbols_unicode <- c(
  tick        = "\u2714",
  cross       = "\u2716",
  info        = "\u2139",
  warn        = "\u26a0",
  bullet      = "\u2022",
  arrow_right = "\u2192",
  line        = "\u2500"
)

.cli_symbols_ascii <- c(
  tick        = "v",
  cross       = "x",
  info        = "i",
  warn        = "!",
  bullet      = "*",
  arrow_right = "->",
  line        = "-"
)

#' Look up a symbol, respecting the current unicode capability
#' @param name One of "tick", "cross", "info", "warn", "bullet",
#'   "arrow_right", "line".
#' @export
.cli_symbol <- function(name) {
  set <- if (.cli_unicode_enabled()) .cli_symbols_unicode else .cli_symbols_ascii
  if (!name %in% names(set)) stop("Unknown symbol: ", name, call. = FALSE)
  unname(set[[name]])
}

# --- alerts ---------------------------------------------------------------

#' @noRd
.cli_alert <- function(symbol_name, color_fn, text, ...) {
  if (length(list(...))) text <- sprintf(text, ...)
  message(paste0(color_fn(.cli_symbol(symbol_name)), " ", text))
}

#' Success / info / warning / danger alerts
#'
#' Thin wrappers around `message()`. Extra `...` arguments are passed
#' through `sprintf()`, e.g. `.cli_alert_success("Wrote %d files", 3)`.
#' @export
.cli_alert_success <- function(text, ...) .cli_alert("tick",  .cli_col_green,  text, ...)
#' @rdname .cli_alert_success
#' @export
.cli_alert_danger  <- function(text, ...) .cli_alert("cross", .cli_col_red,    text, ...)
#' @rdname .cli_alert_success
#' @export
.cli_alert_warning <- function(text, ...) .cli_alert("warn",  .cli_col_yellow, text, ...)
#' @rdname .cli_alert_success
#' @export
.cli_alert_info    <- function(text, ...) .cli_alert("info",  .cli_col_blue,   text, ...)

# --- extras: rule + bullet list --------------------------------------------

#' A horizontal divider, optionally with a centred title
#' @export
.cli_rule <- function(title = NULL) {
  width <- max(getOption("width", 80L), 10L)
  ch <- .cli_symbol("line")

  if (is.null(title) || !nzchar(title)) {
    line <- strrep(ch, width)
  } else {
    label <- paste0(" ", title, " ")
    left  <- max(0L, (width - nchar(label)) %/% 2L)
    right <- max(0L, width - left - nchar(label))
    line <- paste0(strrep(ch, left), label, strrep(ch, right))
  }
  message(.cli_style_dim(line))
}

#' A simple bulleted list
#' @param items Character vector, one entry per line.
#' @export
.cli_bullets <- function(items) {
  message(paste0(.cli_symbol("bullet"), " ", items, collapse = "\n"))
}
