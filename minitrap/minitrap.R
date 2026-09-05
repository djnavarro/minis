## minitrap.R -------------------------------------------------------------
##
## A minimal, dependency-free reimplementation of purrr's `safely()` and
## `quietly()` function adverbs: wrap a function so that instead of
## throwing an error, or printing output/warnings/messages to the
## console, it "traps" them and hands them back as part of its return
## value.
##
## Design notes:
## - Base R only. `mtrap_safely()` uses tryCatch(); `mtrap_quietly()`
##   uses withCallingHandlers() plus the muffleWarning/muffleMessage
##   restarts, and sink() to capture printed output.
## - Exported functions prefixed `mtrap_`; no internal helpers needed.
## - Return shapes deliberately mirror purrr's `safely()`/`quietly()`
##   (list(result=, error=) and list(result=, output=, warnings=,
##   messages=) respectively), so trapped calls are drop-in compatible
##   if a package later adopts purrr for real.
## - Deliberately excluded: purrr's `possibly()`, `auto_browse()`,
##   `insistently()`, `slowly()` -- separate concerns (default-value
##   fallback, rate limiting) that belong in their own mini if ever
##   added, not bolted onto this one.
##
## Usage:
##   source("minitrap.R")
##   safe_log <- mtrap_safely(log)
##   safe_log(-1)   # $result NULL,     $error <simpleError in log(-1): ...>
##   safe_log(10)   # $result 2.302585, $error NULL
##
##   quiet_fn <- mtrap_quietly(function() { message("hi"); warning("careful"); 42 })
##   quiet_fn()     # $result 42, $output "", $warnings "careful", $messages "hi\n"
##
## License: MIT (see LICENSE at the root of the minis repo). This file
## contains no code copied from {purrr}, only equivalent logic.

#' Wrap a function so errors are captured instead of thrown
#'
#' @param .f A function.
#' @return A function with the same arguments as `.f`. Calling it
#'   returns `list(result = ..., error = ...)`: exactly one of the two
#'   is `NULL` on any given call.
#' @export
mtrap_safely <- function(.f) {
  function(...) {
    tryCatch(
      list(result = .f(...), error = NULL),
      error = function(e) list(result = NULL, error = e)
    )
  }
}

#' Wrap a function so printed output, warnings, and messages are
#' captured instead of shown
#'
#' Errors are not caught here -- compose with [mtrap_safely()] for that,
#' e.g. `mtrap_safely(mtrap_quietly(f))`.
#'
#' @param .f A function.
#' @return A function with the same arguments as `.f`. Calling it
#'   returns `list(result = ..., output = ..., warnings = ..., messages
#'   = ...)`. `output` is any printed/`cat()`-ed text, collapsed into a
#'   single string; `warnings`/`messages` are character vectors, one
#'   entry per warning/message raised, in the order they occurred.
#' @export
mtrap_quietly <- function(.f) {
  function(...) {
    warnings <- character()
    warning_handler <- function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    }

    messages <- character()
    message_handler <- function(m) {
      messages <<- c(messages, conditionMessage(m))
      invokeRestart("muffleMessage")
    }

    temp <- file()
    sink(temp)
    on.exit({
      sink()
      close(temp)
    })

    result <- withCallingHandlers(
      .f(...),
      warning = warning_handler,
      message = message_handler
    )
    output <- paste0(readLines(temp, warn = FALSE), collapse = "\n")

    list(result = result, output = output, warnings = warnings, messages = messages)
  }
}
