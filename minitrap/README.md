# minitrap

A minimal, zero-dependency reimplementation of purrr's `safely()` and
`quietly()` function adverbs: wrap a function so that instead of
throwing an error, or printing output/warnings/messages to the console,
it "traps" them and hands them back as part of its return value.

Scoped narrowly on purpose — purrr's other adverbs (`possibly()`,
`insistently()`, `slowly()`, `auto_browse()`) solve different problems
(default-value fallback, rate limiting) and belong in their own mini if
they're ever added, not folded into this one. See the root
[README](../README.md) for why minis favour many small, single-purpose
files over one broad one.

## Install

Copy [`minitrap.R`](minitrap.R) into your package's `R/` directory. No
`Imports`/`Suggests` entry needed. Add `@export` roxygen tags to
whichever functions you want to expose, or leave them unexported.

## API

| Function | purrr equivalent | Returns |
|---|---|---|
| `mtrap_safely(.f)` | `safely()` | A function returning `list(result =, error =)`; exactly one is `NULL` per call |
| `mtrap_quietly(.f)` | `quietly()` | A function returning `list(result =, output =, warnings =, messages =)` |

Both return shapes match purrr's, so code built against `minitrap` can
switch to real purrr later with no changes beyond the function names.

```r
safe_log <- mtrap_safely(log)
safe_log(-1)
#> $result: NULL
#> $error:  <simpleError in log(-1): NaNs produced>

quiet_fn <- mtrap_quietly(function() {
  message("starting")
  warning("using a default")
  42
})
quiet_fn()
#> $result:   42
#> $output:   ""
#> $warnings: "using a default"
#> $messages: "starting\n"
```

`mtrap_quietly()` does not catch errors — a `stop()` inside `.f` still
propagates. Compose with `mtrap_safely()` if you want both:

```r
robust_fn <- mtrap_safely(mtrap_quietly(my_function))
```

## How it works

- `mtrap_safely()` is a thin `tryCatch()` wrapper.
- `mtrap_quietly()` uses `withCallingHandlers()` with `warning`/`message`
  handlers that record the condition's text and then call
  `invokeRestart("muffleWarning")`/`invokeRestart("muffleMessage")` to
  stop it from reaching the console. Printed/`cat()`-ed output is
  captured separately via `sink()` to a temporary in-memory connection.

## Tests

See [`tests/testthat/test-minitrap.R`](tests/testthat/test-minitrap.R).
Dev-only, using `testthat` (no `withr` needed — there's no session state
to control deterministically here).
