# minipivot

A minimal, dependency-free reimplementation of
[tidyr](https://tidyr.tidyverse.org/)'s `pivot_longer()` and
`pivot_wider()`: reshape a data frame between "long" and "wide"
layouts.

## Install

Copy [`minipivot.R`](minipivot.R) into your package's `R/` directory.
No `Imports`/`Suggests` needed.

## API

| Function | Purpose |
|---|---|
| `.pivot_longer(.data, cols, names_to = "name", values_to = "value")` | Melt `cols` into two new columns: pivoted-column names and their values. |
| `.pivot_wider(.data, names_from, values_from, values_fill = NULL)` | Spread unique `names_from` values into new columns, filled from `values_from`. |

## Example

```r
source("minipivot.R")

fish <- data.frame(
  location = c("lake", "lake", "sea", "sea"),
  species  = c("trout", "bass", "trout", "bass"),
  count    = c(5, 3, 7, 2)
)

.pivot_wider(fish, names_from = "species", values_from = "count")
#>   location trout bass
#> 1     lake     5    3
#> 2      sea     7    2

wide <- .pivot_wider(fish, names_from = "species", values_from = "count")
.pivot_longer(wide, c(trout, bass), names_to = "species", values_to = "count")
#>   location species count
#> 1     lake   trout     5
#> 2     lake    bass     3
#> 3      sea   trout     7
#> 4      sea    bass     2
```

`cols` in `.pivot_longer()` accepts a character vector, a numeric
vector, or an unquoted expression using bare column names, `c(...)`,
and/or a leading `-` (e.g. `.pivot_longer(df, -c(id, group))` to select
"every column except these").

## Scope

Deliberately excluded, relative to real tidyr:

- A single `names_to`/`values_to` pair in `.pivot_longer()`, and a
  single `names_from`/`values_from` pair in `.pivot_wider()` -- no
  multi-column keys.
- No `names_sep`/`names_pattern` (splitting one key column into
  several), `names_prefix`, `names_glue`, or `values_drop_na`.
- No `id_cols` argument for `.pivot_wider()` -- every column other
  than `names_from`/`values_from` is treated as an id column
  automatically.
- No tidyselect helpers (`starts_with()`, `everything()`, `:` ranges)
  for `cols` -- only bare names, `c(...)`, character/numeric vectors,
  and unary `-` negation.
- No `values_fn`-style aggregation, and no list-column fallback, when
  a `.pivot_wider()` names/id combination has duplicate rows -- this
  is a hard error instead. A single scalar `values_fill` **is**
  supported for combinations that are simply absent (not duplicated).

## Tests

See [`tests/testthat/test-minipivot.R`](tests/testthat/test-minipivot.R).
