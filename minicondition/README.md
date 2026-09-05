# minicondition

A minimal, zero-dependency reimplementation of rlang's `abort()`,
`warn()`, and `inform()`: signal a classed condition so callers can
catch it specifically via `tryCatch()`/`withCallingHandlers()`, plus a
small `assert()` built on top of `abort()`.

## Install

Copy [`minicondition.R`](minicondition.R) into your package's `R/`
directory. No `Imports`/`Suggests` entry needed.

## API

| Function | rlang equivalent | Notes |
|---|---|---|
| `mcond_abort(message, class = NULL)` | `abort()` | Signals a classed error |
| `mcond_warn(message, class = NULL)` | `warn()` | Signals a classed warning |
| `mcond_inform(message, class = NULL)` | `inform()` | Signals a classed message |
| `mcond_assert(expr, message = "Assertion failed.", class = NULL)` | -- | Calls `mcond_abort()` if `expr` contains any `FALSE` or `NA` |

```r
mcond_abort("Input must be positive.", class = "mypkg_invalid_input")

tryCatch(
  mcond_abort("bad input", class = "mypkg_invalid_input"),
  mypkg_invalid_input = function(e) message("caught: ", conditionMessage(e))
)

mcond_assert(x > 0, "x must be positive.", class = "mypkg_invalid_input")
```

## How it works

Base R's own condition system (`structure()` to build a classed
condition object, then `stop()`/`warning()`/`message()` to signal it)
supports exactly the same catch-by-class behaviour as
`rlang::abort()`/`warn()`/`inform()`: `tryCatch(f(), my_class =
handler)` catches a condition of class `my_class` regardless of which
mechanism raised it. `rlang`'s real value-adds over this (backtraces,
chained errors, `cnd_muffle()`, structured error data via `...`) aren't
reproduced here -- this covers plain classed messages only.

## Deliberate differences from the source this was adapted from

`emaxnls`'s internal `.assert()`/`.abort()`/`.warn()`/`.inform()`
(themselves thin `rlang::abort()`/`warn()`/`inform()` wrappers) defaulted
every condition's class to the package's own name (e.g.
`"emaxnls_error"`) and every message to package-specific placeholder
text (e.g. `"emax_nls error"`). Neither default makes sense in a mini
meant to be copied into any package:

- `class` now defaults to `NULL` (no extra class beyond
  `error`/`warning`/`message`/`condition`) rather than baking in one
  package's identity. Supply your own class explicitly when you want
  conditions to be catchable by type.
- `message` has no default at all -- a generic placeholder isn't useful
  to any caller.

Also fixed: `mcond_assert()` treats `NA` in `expr` as a failure. The
original's `if (any(expr == FALSE))` would itself error with "missing
value where TRUE/FALSE needed" when `expr` contained `NA`, instead of
raising the intended assertion error.

## Tests

See [`tests/testthat/test-minicondition.R`](tests/testthat/test-minicondition.R).
