# minijoin

A minimal, zero-dependency reimplementation of dplyr's mutating joins
(`inner_join()`, `left_join()`, `right_join()`, `full_join()`), built on
base `merge()`.

Adapted from [poorman](https://github.com/nathaneastwood/poorman)'s
`joins.R`, which is itself dependency-free.

## Install

Copy [`minijoin.R`](minijoin.R) into your package's `R/` directory. No
`Imports`/`Suggests` entry needed.

## API

| Function | Keeps |
|---|---|
| `.join_inner_join(x, y, by, ...)` | Rows matching in both `x` and `y` |
| `.join_left_join(x, y, by, ...)` | All rows of `x` |
| `.join_right_join(x, y, by, ...)` | All rows of `y` |
| `.join_full_join(x, y, by, ...)` | All rows of both |

```r
bands <- data.frame(band = c("Beatles", "Who"), founded = c(1960, 1964))
albums <- data.frame(band = c("Beatles", "Kinks"), album = c("Abbey Road", "Arthur"))

.join_inner_join(bands, albums, by = "band")
.join_left_join(bands, albums, by = "band")
```

Common arguments across all four:

- **`by`** must always be supplied explicitly -- unlike dplyr, there is
  no auto-detection of shared column names.
- **`suffix`** (default `c(".x", ".y")`) is applied to overlapping
  non-join column names.
- **`keep`** (left/right/full only) keeps both join columns, suffixed,
  instead of collapsing them into one -- e.g. `band.x`/`band.y` rather
  than a single `band`. Both suffixed copies are named after `by`'s
  x-side name even when `by` renames the join column (`by = c("band" =
  "artist")` with `keep = TRUE` still produces `band.x`/`band.y`, not
  `band`/`artist`). Each side's column reflects that side's own data,
  so it's `NA` on any row with no actual match on that side -- e.g. a
  left join's `band.y` is `NA` wherever there's no match in `y`, even
  though `band.x` (from `x`) is fully populated.
- **`na_matches`**: `"na"` (default) matches `NA` to `NA`, as dplyr/SQL
  joins do; `"never"` excludes `NA`-keyed rows from matching at all.
- Row order always matches `x`'s original order (restored internally
  via a temporary `.join_id` column), since `merge()` doesn't guarantee
  this on its own.

## Scope

Plain two-table joins only. Not included: dplyr's `relationship`,
`multiple`, and `unmatched` validation arguments.

## Tests

See [`tests/testthat/test-minijoin.R`](tests/testthat/test-minijoin.R).
