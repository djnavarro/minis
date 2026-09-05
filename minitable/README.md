# minitable

A minimal, zero-dependency reimplementation of a few `tibble`
construction/coercion helpers: `tibble()`, `as_tibble()`,
`rownames_to_column()`, `add_row()`. Results are plain `data.frame`s,
not tibbles.

## Install

Copy [`minitable.R`](minitable.R) into your package's `R/` directory. No
`Imports`/`Suggests` entry needed.

## API

| Function | tibble equivalent | Notes |
|---|---|---|
| `mtable_tibble(...)` | `tibble()` | Later columns can reference earlier ones by name |
| `mtable_as_tibble(x, ...)` | `as_tibble()` | Just `as.data.frame()` |
| `mtable_rownames_to_column(.data, var)` | `rownames_to_column()` | No-op if row names are absent or the default sequence |
| `mtable_add_row(.data, ...)` | `add_row()` | Appends one row, matched by column name |

```r
mtable_tibble(a = 1:3, b = a * 2, c = a + b)
#>   a b c
#> 1 1 2 3
#> 2 2 4 6
#> 3 3 6 9

mtable_add_row(mtcars, mpg = 99)
mtable_rownames_to_column(mtcars, var = "model")
```

## Why this one needed more rework than the others

Unlike `minifilter`/`minicase`/`minijoin`, the internal helper this was
adapted from (`emaxnls`'s `.tibble()` family) was not actually
zero-dependency: it used `rlang::enexprs()` for argument capture and
`rlang::is_installed()` to opportunistically defer to real
`tibble::tibble()` when installed, falling back to a restricted,
`data.frame()`-based version otherwise -- and it explicitly *forbade*
cross-column references (`mtable_tibble(a = 1, b = a + 1)`).

That restriction turned out not to be just a "keep behavior consistent
with real tibble" nicety -- it was working around a real limitation.
The sequential-evaluation trick (`match.call()` + walking `...`
argument by argument, adapted from poorman) only works when it runs
directly inside the function that receives the user's literal `...`.
The original code forwarded `...` from `.tibble()` to a separate
`.lst()` helper, and forwarding `...` through an intermediate function
turns each argument into an opaque `..1`/`..2` pronoun: evaluating one
of those against a custom environment silently resolves free variables
against the *original caller's* environment instead, either erroring
("object not found") or, worse, picking up an unrelated variable of the
same name. Banning cross-column references sidesteps the bug entirely
by making sure it's never exercised.

`minitable` keeps the feature by avoiding the forwarding step: the
sequential-evaluation logic lives directly inside `mtable_tibble()` and
`mtable_add_row()` rather than in a shared `...`-accepting helper, so
`match.call()` sees the real argument expressions instead of `..n`
pronouns. It also drops the `rlang` dependency and the opportunistic
deferral to real tibble, for consistency with the other minis (none of
which check for or prefer a "real" package) -- so this mini ends up
*more* capable than the internal helper it was extracted from, while
using less code.

Also fixed relative to the original: `mtable_rownames_to_column()` now
checks whether row names are the default sequential ones
(`"1"`, `"2"`, ...) and no-ops in that case, matching real
`tibble::rownames_to_column()`'s `has_rownames()` check. The original
only checked `is.null(rownames(.data))`, which is never true for an
ordinary data frame (row names always default to a sequence), so it
would have added a spurious rowname column to every data frame with
default row names.

## Scope

No list-columns. Recycling/type validation is whatever
`as.data.frame()` does (permissive: any lengths that are exact
multiples of each other are recycled), not tibble's stricter
length-1-or-error rules.

## Tests

See [`tests/testthat/test-minitable.R`](tests/testthat/test-minitable.R).
