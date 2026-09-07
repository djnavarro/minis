# minifilter

A minimal, zero-dependency reimplementation of dplyr's `filter()`:
subset the rows of a data frame using unquoted conditions evaluated in
the data frame's own scope.

Adapted from [poorman](https://github.com/nathaneastwood/poorman)'s
`filter()`/dots.R, which is itself dependency-free, rather than from
`emaxnls`'s internal `.filter()` directly (`emaxnls` had in turn adapted
it from the same source).

## Install

Copy [`minifilter.R`](minifilter.R) into your package's `R/` directory.
No `Imports`/`Suggests` entry needed.

## API

| Function | Purpose |
|---|---|
| `.filter(.data, ...)` | Keep rows where all `...` conditions are `TRUE`; rows with `NA` conditions are dropped; conditions combine with AND |

```r
.filter(mtcars, cyl == 4, mpg > 25)
```

## Scope

Covers plain, ungrouped row filtering only. Not included: dplyr's
grouped filtering (`.by`/`group_by()`), `.preserve`, or tidyselect-style
column helpers.

## Deliberate fix relative to the source this was adapted from

Calling `.filter(df)` with no conditions now returns `.data`
unchanged, matching `dplyr::filter(df)`. The original `.filter()` this
was adapted from didn't guard against the empty-`...`  case, and would
silently drop every row (`Reduce("&", list())` returns `NULL`, and
indexing a data frame with `NULL & !is.na(NULL)` produces zero rows).

## Tests

See [`tests/testthat/test-minifilter.R`](tests/testthat/test-minifilter.R).
