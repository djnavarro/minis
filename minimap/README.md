# minimap

A minimal, zero-dependency reimplementation of purrr's core mapping
functions: `map()`, `map2()`, `imap()`, `walk()`, `iwalk()`, and the
type-stable `map_dbl()`/`map_lgl()`/`map_chr()` variants. Built entirely
on `lapply()`/`vapply()`.

This is deliberately scoped narrower than "all of purrr" or even "all of
purrr's mapping functions" — it covers the common case of wanting to
write `map()`-style code in a package without taking on the `purrr`
dependency. Other purrr-inspired behaviour (`safely()`/`quietly()`-style
adverbs, `pmap()`, `map_if()`/`map_at()`, list-columns) is intentionally
left to other, separate minis rather than bolted on here — see the root
[README](../README.md) for why minis favour many small, single-purpose
files over one big one.

## Install

Copy [`minimap.R`](minimap.R) into your package's `R/` directory. No
`Imports`/`Suggests` entry needed. Add `@export` roxygen tags to
whichever functions you want to expose, or leave them unexported.

## API

| Function | purrr equivalent | Notes |
|---|---|---|
| `mmap_map(.x, .f)` | `map()` | Always returns a list; preserves names |
| `mmap_map_dbl(.x, .f)`, `_lgl()`, `_chr()` | `map_dbl()`, `map_lgl()`, `map_chr()` | Type-stable via `vapply()`; errors if `.f` doesn't return a length-1 value of the right type |
| `mmap_walk(.x, .f)` | `walk()` | Runs `.f` for its side effects, returns `.x` invisibly |
| `mmap_map2(.x, .y, .f)` | `map2()` | `.x` and `.y` must have equal length |
| `mmap_imap(.x, .f)` | `imap()` | `.f` receives `(element, name)`; `.x` must be named |
| `mmap_iwalk(.x, .f)` | `iwalk()` | Like `mmap_imap()`, for side effects; returns `.x` invisibly |

```r
mmap_map(1:3, \(x) x + 1)
#> [[1]] 2  [[2]] 3  [[3]] 4

mmap_map_dbl(1:3, \(x) x + 1)
#> [1] 2 3 4

mmap_imap(c(a = 1, b = 2), \(val, name) paste0(name, "=", val))
#> $a [1] "a=1"   $b [1] "b=2"
```

## Provenance and deliberate differences

This started life as a set of dot-prefixed internal helpers
(`.map()`, `.imap()`, etc.) in the `emaxnls` package, which leaned on
`rlang::abort()` for argument checking via a shared `.assert()` helper.
Two changes were made when extracting it as a standalone mini:

1. **Argument checking uses base `stop()`**, not `rlang::abort()` — a
   mini shouldn't need `rlang` just to raise a clear error, and losing
   custom condition classes is an acceptable trade-off here.
2. **`mmap_imap()`/`mmap_iwalk()` check `!is.null(names(.x))`**, not
   `!is.null(.x)`. The original checked that `.x` itself wasn't `NULL`,
   which doesn't actually verify `.x` is named — an unnamed vector would
   pass the original check and then silently `imap()` over `NULL` names.

## Tests

See [`tests/testthat/test-minimap.R`](tests/testthat/test-minimap.R).
Dev-only, using `testthat` (no `withr` needed here, unlike `minicli` —
there's no session state to control deterministically).
