# miniverb

A minimal, zero-dependency reimplementation of five dplyr one-table
verbs: `filter()`, `select()`, `mutate()`, `arrange()`, `summarise()` --
plus a `.by`-style grouping argument shared across `filter()`,
`mutate()`, and `summarise()`.

`.verb_filter()`'s core logic is adapted from
[poorman](https://github.com/nathaneastwood/poorman)'s
`filter()`/dots.R, which is itself dependency-free. The other four verbs
are original reimplementations of dplyr semantics, not copied or
adapted from dplyr or poorman.

## Install

Copy [`miniverb.R`](miniverb.R) into your package's `R/` directory. No
`Imports`/`Suggests` entry needed.

## API

| Function | Purpose |
|---|---|
| `.verb_filter(.data, ..., .by = NULL)` | Keep rows where all `...` conditions are `TRUE`; rows with `NA` conditions are dropped; conditions combine with AND |
| `.verb_select(.data, ...)` | Keep (and optionally rename) columns by bare name, integer position, or `new = old`; `-col`/`-position` drops columns |
| `.verb_mutate(.data, ..., .by = NULL)` | Add or overwrite columns via named `name = expr` arguments; later arguments see columns added by earlier ones |
| `.verb_arrange(.data, ...)` | Reorder rows by one or more columns; wrap a column in `.verb_desc()` for descending order |
| `.verb_desc(x)` | Mark a column for descending order inside `.verb_arrange()` |
| `.verb_summarise(.data, ..., .by = NULL)` | Collapse to one row per group (or one row overall) via named `name = expr` arguments that must each reduce to a single value |

```r
.verb_filter(mtcars, mpg > mean(mpg), .by = "cyl")
.verb_select(mtcars, mpg, cylinders = cyl)
.verb_mutate(mtcars, mpg_z = (mpg - mean(mpg)) / sd(mpg), .by = "cyl")
.verb_arrange(mtcars, .verb_desc(mpg))
.verb_summarise(mtcars, mean_mpg = mean(mpg), .by = "cyl")
```

## `.by`

`.verb_filter()`, `.verb_mutate()`, and `.verb_summarise()` accept a
`.by` argument for grouped evaluation, restricted to a **plain character
vector of column names** (`.by = c("cyl", "gear")`) -- not dplyr's
unquoted/tidyselect-lite syntax. `.verb_arrange()` doesn't take `.by`:
dplyr's own `arrange(.by_group = )` requires a persistent `group_by()`
object, which doesn't exist here either.

Groups are processed (and, for `.verb_summarise()`, returned) in the
order each distinct combination of `.by` columns is first seen in
`.data`, matching dplyr's own `.by`/`group_by()` semantics -- not
sorted key order.

A `.verb_summarise()` output name that collides with a `.by` grouping
column's name is an error, since `.by`'s grouping columns are always
included as the leading columns of the result -- reusing one of those
names for a summary expression would otherwise produce two columns
with the same name.

## Scope

Deliberately excluded, across every verb:

- `across()` and any form of programmable/bulk column operations.
- Tidyselect helpers (`starts_with()`, `contains()`, `everything()`,
  `where()`, `all_of()`, `any_of()`). `.verb_select()` only supports
  bare names, integer positions, `-` exclusion, and `new = old`
  renaming.
- Injection operators (`{{ }}`, `!!`, `!!!`) and any other tidyeval
  machinery.
- A persistent `group_by()` object -- grouping is always a one-off
  `.by` argument passed to the verb that needs it, never a standing
  property of the data frame.
- `.verb_mutate()`'s recycling relies on base R's own vector-assignment
  rules (length-1 values are recycled explicitly; anything else is left
  to `x[idx] <- value`), not vctrs-style strict size checking.
- `.verb_summarise()` only supports exactly one row per group; an
  expression that doesn't reduce to a single value per group is an
  error.

If a use case needs a *programmable* column selection rather than
columns typed out by hand, that's a sign to take the real dplyr
dependency instead of stretching this mini further.

## Tests

See [`tests/testthat/test-miniverb.R`](tests/testthat/test-miniverb.R).
