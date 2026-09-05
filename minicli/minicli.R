## minicli.R -----------------------------------------------------------
##
## A minimal, dependency-free stand-in for the parts of {cli} most
## packages actually use: coloured/styled text, unicode-with-ascii-
## fallback symbols, and a handful of `alert_*()` message helpers.
##
## Design notes:
## - Base R only. No imports, no Suggests required.
## - All user-facing functions are prefixed `mcli_`; internals are
##   prefixed `.mcli_` to avoid collisions when this file is copied
##   into an existing package's R/ directory.
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
##   mcli_alert_success("Wrote %d files", 3)
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
.mcli_rstudio_console_with_color <- function() {
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
.mcli_positron_console_with_color <- function() {
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
.mcli_ansi_enabled <- function() {
  opt <- getOption("cli.num_colors", NULL)
  if (!is.null(opt)) return(opt > 1)

  # https://no-color.org
  if (nzchar(Sys.getenv("NO_COLOR", ""))) return(FALSE)

  # knitr/Quarto capture output to a string buffer, not a real terminal
  if (isTRUE(getOption("knitr.in.progress"))) return(FALSE)

  # output has been redirected/captured (e.g. capture.output(), testthat)
  if (sink.number() > 0) return(FALSE)

  if (.mcli_positron_console_with_color()) return(TRUE)
  if (.mcli_rstudio_console_with_color()) return(TRUE)

  isatty(stdout())
}

#' Is it safe to print unicode symbols right now?
#' @noRd
.mcli_unicode_enabled <- function() {
  opt <- getOption("cli.unicode", NULL)
  if (!is.null(opt)) return(isTRUE(opt))
  isTRUE(l10n_info()[["UTF-8"]])
}

# --- styling ------------------------------------------------------------

#' Build a function that wraps text in an SGR code, no-op when disabled
#' @noRd
.mcli_ansi_style <- function(code) {
  force(code)
  function(text) {
    if (!.mcli_ansi_enabled()) return(text)
    paste0("\033[", code, "m", text, "\033[0m")
  }
}

mcli_col_black   <- .mcli_ansi_style("30")
mcli_col_red     <- .mcli_ansi_style("31")
mcli_col_green   <- .mcli_ansi_style("32")
mcli_col_yellow  <- .mcli_ansi_style("33")
mcli_col_blue    <- .mcli_ansi_style("34")
mcli_col_magenta <- .mcli_ansi_style("35")
mcli_col_cyan    <- .mcli_ansi_style("36")
mcli_col_white   <- .mcli_ansi_style("37")
mcli_col_grey    <- .mcli_ansi_style("90")

mcli_style_bold      <- .mcli_ansi_style("1")
mcli_style_dim       <- .mcli_ansi_style("2")
mcli_style_italic    <- .mcli_ansi_style("3")
mcli_style_underline <- .mcli_ansi_style("4")

# Styles can be freely nested, e.g. mcli_style_bold(mcli_col_red("x")),
# because each wrapper's reset code is always emitted immediately after
# its own content, never in the middle of a still-open outer style.

# --- symbols with ascii fallback ----------------------------------------

.mcli_symbols_unicode <- c(
  tick        = "\u2714",
  cross       = "\u2716",
  info        = "\u2139",
  warn        = "\u26a0",
  bullet      = "\u2022",
  arrow_right = "\u2192",
  line        = "\u2500"
)

.mcli_symbols_ascii <- c(
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
mcli_symbol <- function(name) {
  set <- if (.mcli_unicode_enabled()) .mcli_symbols_unicode else .mcli_symbols_ascii
  if (!name %in% names(set)) stop("Unknown symbol: ", name, call. = FALSE)
  unname(set[[name]])
}

# --- alerts ---------------------------------------------------------------

#' @noRd
.mcli_alert <- function(symbol_name, color_fn, text, ...) {
  if (length(list(...))) text <- sprintf(text, ...)
  message(paste0(color_fn(mcli_symbol(symbol_name)), " ", text))
}

#' Success / info / warning / danger alerts
#'
#' Thin wrappers around `message()`. Extra `...` arguments are passed
#' through `sprintf()`, e.g. `mcli_alert_success("Wrote %d files", 3)`.
#' @export
mcli_alert_success <- function(text, ...) .mcli_alert("tick",  mcli_col_green,  text, ...)
#' @rdname mcli_alert_success
#' @export
mcli_alert_danger  <- function(text, ...) .mcli_alert("cross", mcli_col_red,    text, ...)
#' @rdname mcli_alert_success
#' @export
mcli_alert_warning <- function(text, ...) .mcli_alert("warn",  mcli_col_yellow, text, ...)
#' @rdname mcli_alert_success
#' @export
mcli_alert_info    <- function(text, ...) .mcli_alert("info",  mcli_col_blue,   text, ...)

# --- extras: rule + bullet list --------------------------------------------

#' A horizontal divider, optionally with a centred title
#' @export
mcli_rule <- function(title = NULL) {
  width <- max(getOption("width", 80L), 10L)
  ch <- mcli_symbol("line")

  if (is.null(title) || !nzchar(title)) {
    line <- strrep(ch, width)
  } else {
    label <- paste0(" ", title, " ")
    left  <- max(0L, (width - nchar(label)) %/% 2L)
    right <- max(0L, width - left - nchar(label))
    line <- paste0(strrep(ch, left), label, strrep(ch, right))
  }
  message(mcli_style_dim(line))
}

#' A simple bulleted list
#' @param items Character vector, one entry per line.
#' @export
mcli_bullets <- function(items) {
  message(paste0(mcli_symbol("bullet"), " ", items, collapse = "\n"))
}
