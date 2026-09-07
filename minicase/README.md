# minicase

A minimal, zero-dependency reimplementation of dplyr's `case_when()`:
vectorised if/else via a sequence of two-sided formulas.

Adapted from [poorman](https://github.com/nathaneastwood/poorman)'s
`case_when()`/`replace_with()`, which is itself dependency-free.

## Install

Copy [`minicase.R`](minicase.R) into your package's `R/` directory. No
`Imports`/`Suggests` entry needed.

## API

| Function | Purpose |
|---|---|
| `.case_when(...)` | Given `condition ~ value` formulas, return a vector where each position takes the value from the first matching condition; unmatched positions are `NA` |

```r
x <- c(-5, 0, 5, NA)
.case_when(
  x < 0  ~ "negative",
  x == 0 ~ "zero",
  x > 0  ~ "positive",
  TRUE   ~ "unknown"
)
#> [1] "negative" "zero"     "positive" "unknown"
```

Conditions and values are evaluated in the *caller's* environment --
there's no data-masking layer here, so reference data frame columns
with `df$col`, or wrap the call: `with(df, .case_when(...))`.

## Scope

Covers the plain "match conditions in order, first match wins" case
only. Not included: dplyr's `.default`, `.ptype`, `.size` arguments.

Values across formulas must share a type, and -- for factors
specifically -- the same set of levels, not just the same class:
combining two factors with different levels is a hard error rather
than a silent `NA` (which is what plain `x[i] <- val` would otherwise
produce for any label not present in the first formula's factor's
levels).

## Tests

See [`tests/testthat/test-minicase.R`](tests/testthat/test-minicase.R).
