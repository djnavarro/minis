# minicuts

Two functions for cutting a numeric vector into bins: `.cut_quantile()`
(fixed group size, boundaries determined by the data) and
`.cut_evenly()` (fixed bin geometry, group sizes determined by the
data). `.cut_quantile()` is adapted from
[djnavarro/erplots](https://github.com/djnavarro/erplots)'s
`cut_quantile()`/`cut_exposure_quantile()`; both functions are inspired
by the `chop_quantiles()`/`chop_equally()`/`chop_evenly()`/
`chop_width()` family in
[santoku](https://github.com/hughjonesd/santoku).

## Install

Copy `minicuts.R` into your package's `R/` directory. No `Imports` or
`Suggests` needed.

## API

| Function | Purpose |
|---|---|
| `.cut_quantile()` | Cut a numeric vector into `n_bins` quantile bins, with control over tie-breaking, the quantile algorithm, custom labels, and an `exclude` argument for values that should be labelled separately rather than included in the quantile calculation. |
| `.cut_evenly()` | Cut a numeric vector into equal-width bins, either a fixed *number* of bins spanning `range(x)` (`n_bins`) or a fixed *width* with the bin count following from the data (`width`/`start`) -- santoku's `chop_evenly()`/`chop_width()` unified into one function. Shares `exclude`/`exclude_label`/`labeller` with `.cut_quantile()`. |

## Example

```r
source("minicuts.R")

x <- rnorm(100)
.cut_quantile(x)
.cut_quantile(x, n_bins = 10, ties = "split-even", seed = 8213)
.cut_quantile(x, labeller = c("Low", "Mid-low", "Mid-high", "High"))

# exact zeroes kept out of the quantile calculation, but labelled
# rather than dropped
exposure <- c(rep(0, 20), abs(rnorm(80)))
.cut_quantile(exposure, exclude = function(x) x == 0, exclude_label = "None")

y <- runif(100, 0, 10)
.cut_evenly(y, n_bins = 5)     # 5 bins spanning range(y)
.cut_evenly(y, width = 2)      # bins of width 2, however many that takes
.cut_evenly(y, width = 2, start = 0)
```

## Scope

Deliberately narrower than santoku:

- No general interval-chopping engine (arbitrary breaks, `left`/
  `close_end`, non-numeric `x` such as Dates). If you need that
  generality, use santoku itself.
- No weighted quantiles.
- `.cut_evenly()`'s out-of-range handling differs from santoku's
  `chop()`: when an explicit `start` doesn't reach one edge of
  `range(x)`, values beyond it are coded `NA` with a warning (matching
  base [cut()]'s own out-of-range behaviour), rather than santoku's
  default of silently extending the outermost bin to cover them.

`cut_exposure_quantile()`'s pharmacometrics-specific `is_placebo`/
`"Placebo"` handling is generalized into the domain-neutral `exclude`
argument, shared by both functions: values matched by `exclude` (a
logical vector, or a predicate function of `x`) are left out of the
bin calculation entirely (so they don't skew break points, or
`range(x)`-derived defaults) but still appear in the result under
their own factor level (`exclude_label`), rather than being dropped or
set to `NA`. `exclude = NULL` (the default) behaves like plain
cutting, with no extra level added.

`.cut_evenly()` also drops `.cut_quantile()`'s `ties = "split-even"`
option (and, with it, `seed`): there's no "equal group size" goal to
chase when bins are fixed by geometry rather than by data-driven
quantiles, so only the boundary-direction choice (`ties =
"upward"`/`"downward"`) carries over.

## Deliberate fix relative to the source

`cut_quantile()`/`cut_exposure_quantile()` use `rlang::abort()`/
`rlang::warn()` and `withr::with_seed()`. `.cut_quantile()` uses base
`stop()`/`warning()` instead, and a manual `.Random.seed`
save-and-restore (`.cuts_with_seed()`) in place of `withr::with_seed()`,
to keep this mini at zero runtime dependencies.

## Tests

See `tests/testthat/test-minicuts.R`.
