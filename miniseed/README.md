# miniseed

Four functions for managing the RNG seed around a block of code or for
the rest of a function's execution -- a dependency-free reimplementation
of the slice of [withr](https://github.com/r-lib/withr) that
`with_seed()`/`with_preserve_seed()`/`local_seed()`/
`local_preserve_seed()` cover. `minicuts` already needed a private
version of `with_seed()`; `miniseed` generalizes that so other
minis/packages can take the same shortcut instead of depending on withr
for just this.

## Install

Copy `miniseed.R` into your package's `R/` directory. No `Imports` or
`Suggests` needed.

## API

| Function | Purpose |
|---|---|
| `.seed_with_seed()` | Seed the RNG, evaluate a block of code, then restore the RNG state as it was found. |
| `.seed_with_preserve_seed()` | Evaluate a block of code, restoring the RNG state as it was found afterwards -- without itself calling `set.seed()`. |
| `.seed_local_seed()` | Seed the RNG immediately and schedule the restore for when the *calling* function returns, instead of wrapping a code block. |
| `.seed_local_preserve_seed()` | Schedule the restore for when the calling function returns, without itself calling `set.seed()`. |

## Example

```r
source("miniseed.R")

# with_seed(): wraps a block of code
.seed_with_seed(42, runif(3))
identical(.seed_with_seed(42, runif(3)), .seed_with_seed(42, runif(3))) # TRUE

# with_preserve_seed(): restores state, but doesn't set a seed itself
.seed_with_preserve_seed({
  set.seed(42)
  runif(3)
})

# local_seed(): called directly inside a function, no block to wrap
my_fn <- function() {
  .seed_local_seed(42)
  runif(3)
}
identical(my_fn(), my_fn()) # TRUE, and the ambient RNG stream is untouched once my_fn() returns

# local_preserve_seed(): same idea, without setting a seed itself
your_fn <- function() {
  .seed_local_preserve_seed()
  set.seed(77)
  runif(2)
}
```

## Scope

Mirrors withr's own four RNG-seed functions; `rng_kind`/
`rng_normal_kind`/`rng_sample_kind` cover withr's `.rng_kind`/
`.rng_normal_kind`/`.rng_sample_kind` (renamed to drop the leading dot,
since these functions have no `...` for it to disambiguate against).
Deliberately excluded relative to withr as a whole: everything unrelated
to the RNG seed (`with_options()`, `with_dir()`, `with_envvar()`, etc.)
-- those are separate concerns for their own mini if ever needed, not
bolted onto this one. `local_seed()`/`local_preserve_seed()`'s `envir`
argument defaults to the immediate caller, matching withr's own
`local_*` functions; passing an explicit `envir` (e.g. to defer the
restore to a grandparent frame) is supported, mirroring withr, but is a
less common use case than the default.

## Tests

See `tests/testthat/test-miniseed.R`.
