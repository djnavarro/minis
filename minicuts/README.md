# minicuts

A single function, `.cut_quantile()`, for cutting a numeric vector into
quantile bins. Adapted from
[djnavarro/erplots](https://github.com/djnavarro/erplots)'s
`cut_quantile()`/`cut_exposure_quantile()`, and inspired by the
`chop_quantiles()`/`chop_equally()` family in
[santoku](https://github.com/hughjonesd/santoku).

## Install

Copy `minicuts.R` into your package's `R/` directory. No `Imports` or
`Suggests` needed.

## API

| Function | Purpose |
|---|---|
| `.cut_quantile()` | Cut a numeric vector into `n_bins` quantile bins, with control over tie-breaking, the quantile algorithm, custom labels, and an `exclude` argument for values that should be labelled separately rather than included in the quantile calculation. |

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
```

## Scope

Deliberately narrower than santoku:

- No general interval-chopping engine (arbitrary breaks, `left`/
  `close_end`, non-numeric `x` such as Dates). If you need that
  generality, use santoku itself.
- No weighted quantiles.
- No equal-*width* cutting (santoku's `chop_evenly()`/`chop_width()`) --
  `.cut_quantile()` only cuts into equal-*sized* groups. This may be
  added as a second function to this mini later.

`cut_exposure_quantile()`'s pharmacometrics-specific `is_placebo`/
`"Placebo"` handling is generalized into the domain-neutral `exclude`
argument: values matched by `exclude` (a logical vector, or a predicate
function of `x`) are left out of the quantile calculation entirely (so
they don't skew break points) but still appear in the result under
their own factor level (`exclude_label`), rather than being dropped or
set to `NA`. `exclude = NULL` (the default) behaves like plain
quantile cutting, with no extra level added.

## Deliberate fix relative to the source

`cut_quantile()`/`cut_exposure_quantile()` use `rlang::abort()`/
`rlang::warn()` and `withr::with_seed()`. `.cut_quantile()` uses base
`stop()`/`warning()` instead, and a manual `.Random.seed`
save-and-restore (`.cuts_with_seed()`) in place of `withr::with_seed()`,
to keep this mini at zero runtime dependencies.

## Tests

See `tests/testthat/test-minicuts.R`.
