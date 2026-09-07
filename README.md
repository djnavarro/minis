# minis

A collection of small, standalone, zero-runtime-dependency R components
("minis"), each shipped as a single `.R` file with its own drop-in test
suite. The idea: when a package needs a little bit of `cli`-style
formatting, or a little bit of `purrr`-style mapping, or some other small
convenience, but taking on the full dependency isn't worth it, grab the
relevant mini and copy it straight into `R/`.

## Philosophy

- **One file, one job.** Each mini lives in its own directory and does one
  narrow thing (e.g. coloured console messages, or just the `map()`
  family of a purrr-like interface). No mini depends on another mini or
  on any external package at runtime.
- **No 1:1 mapping to the packages minis are inspired by.** A single
  source package can and usually should split into several minis, scoped
  by functionality rather than by origin. purrr's mapping functions live
  in `minimap`; purrr's `safely()`/`quietly()`-style adverbs are a
  separate mini, not bolted onto `minimap`. When in doubt, prefer more,
  smaller minis over fewer, broader ones.
- **Copy, don't install.** These are not meant to be installed as a
  package or added to `Imports`/`Depends`. Copy the `.R` file into your
  own package's `R/` directory (renaming if useful) and vendor it as your
  own code. Keep the license header comment intact.
- **Namespaced defensively, with a dot-prefix.** Every function in a
  mini is dot-prefixed with a short, mini-specific tag (`.cli_*`,
  `.iter_*`, `.trap_*`, `.join_*`, `.table_*`, `.cond_*`), whether the
  mini itself thinks of it as a "core" function or an internal helper —
  once copied into a consuming package, everything from a mini is
  internal to that package anyway, so there's no reason to distinguish
  the two in the name. A couple of single-function minis (`minifilter`,
  `minicase`) skip the tag on their one exported function to avoid
  stutter (`.filter`, `.case_when`, not `.filter_filter`), keeping the
  tag only on their internal helpers.
- **Tested, but the tests don't ship.** Each mini has a `tests/testthat/`
  suite that lives in *this* repo for development purposes. Consumers of
  a mini just take the single source file — the tests use `testthat` and
  `withr` as dev dependencies of this repo only.
- **Vignettes are optional, READMEs are not.** A mini may also have a
  `vignette.qmd`, an executed worked-example page rendered into the
  [minis site](https://djnavarro.github.io/minis/) (once published).
  It's purely additive — the plain README above is what every mini is
  required to have.

## Available minis

| Mini | Purpose |
|---|---|
| [`minicli`](minicli/) | Minimal `cli`-style coloured alerts/symbols/rules, with automatic fallback to plain text when ANSI/unicode isn't safe (e.g. knitr/Quarto renders, redirected output). |
| [`minimap`](minimap/) | Minimal `purrr`-style `map()`/`map2()`/`imap()`/`walk()`/`iwalk()` and type-stable `map_dbl()`/`map_lgl()`/`map_chr()`, built on `lapply()`/`vapply()`. |
| [`minitrap`](minitrap/) | Minimal `purrr`-style `safely()`/`quietly()` function adverbs: trap errors, or trap printed output/warnings/messages, instead of letting them hit the console. |
| [`minifilter`](minifilter/) | Minimal `dplyr`-style `filter()`: subset rows of a data frame by unquoted conditions. |
| [`minicase`](minicase/) | Minimal `dplyr`-style `case_when()`: vectorised if/else via a sequence of formulas. |
| [`minijoin`](minijoin/) | Minimal `dplyr`-style mutating joins (`inner_join()`/`left_join()`/`right_join()`/`full_join()`), built on `merge()`. |
| [`minitable`](minitable/) | Minimal `tibble`-style construction/coercion helpers (`tibble()`/`as_tibble()`/`rownames_to_column()`/`add_row()`), returning plain data frames. |
| [`minicondition`](minicondition/) | Minimal `rlang`-style `abort()`/`warn()`/`inform()` classed conditions, plus `assert()`, built on base R's own condition system. |
| [`minipivot`](minipivot/) | Minimal `tidyr`-style `pivot_longer()`/`pivot_wider()`, reshaping a data frame between long and wide layouts. |

## Using a mini

1. Open the mini's directory (e.g. [`minicli/`](minicli/)) and read its README.
2. Copy the single `.R` file into your package's `R/` directory.
3. Optionally rename the file and/or the function prefix if it clashes
   with something in your codebase.
4. Add `@export` roxygen tags / `NAMESPACE` entries as needed for the
   functions you actually use, or leave them unexported and call with
   `:::` internally — either is fine since there's no dependency to
   declare either way.

## Running the test suites

From the repo root (requires `testthat` and `withr` installed):

```r
Rscript run_tests.R
```

This runs every mini's `tests/testthat/` suite and exits non-zero if any
fail.

## Adding a new mini

Follow the layout of `minicli/`:

```
minis/
  <name>/
    <name>.R                       # the single, zero-dependency source file
    README.md                      # what it does, how to drop it in
    tests/
      testthat/
        test-<name>.R              # testthat tests, using withr for
                                    # deterministic option/env-var scoping
```

Then add a row to the table above.

## License

MIT. See [LICENSE](LICENSE). Each mini's source file also carries its own
short license note in the header comment, since files are meant to be
copied out of this repo individually.
