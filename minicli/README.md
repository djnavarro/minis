# minicli

A minimal, zero-dependency stand-in for the small slice of
[`cli`](https://cli.r-lib.org/) that most packages actually use: coloured
alert messages, a few unicode symbols with ascii fallback, a rule, and a
bullet list. No glue-style interpolation, theming, progress bars, trees,
or colour-depth detection — just "pretty in a terminal, plain everywhere
ANSI/unicode isn't safe."

## Why

`cli` is excellent, but adding it as a dependency isn't always
proportionate for a package that just wants a few coloured `message()`
calls. `minicli.R` is ~180 lines of base R that replicates `cli`'s
capability-detection logic (and even respects its `cli.num_colors` /
`cli.unicode` options, so behaviour stays consistent if the calling
session already has `cli` configured) without requiring it as an import.

## Install

Copy [`minicli.R`](minicli.R) into your package's `R/` directory. That's
it — no `Imports`/`Suggests` entry needed. Add `@export` roxygen tags to
whichever functions you want to expose, or leave them unexported and
call them internally.

## What it detects

- **ANSI colour**: disabled when `NO_COLOR` is set, when
  `getOption("knitr.in.progress")` is `TRUE` (Rmd/Quarto renders), when
  output is being captured via `sink()`, or when stdout isn't a real
  terminal — except that Positron's and RStudio's Console panes are
  each detected explicitly first, since neither is a real tty but both
  do support ANSI colour. Can be forced either way with
  `options(cli.num_colors = ...)`.
- **Unicode symbols**: based on `l10n_info()[["UTF-8"]]`, overridable with
  `options(cli.unicode = ...)`.

## API

| Function | Purpose |
|---|---|
| `.cli_col_red()`, `_green()`, `_yellow()`, `_blue()`, `_magenta()`, `_cyan()`, `_white()`, `_black()`, `_grey()` | Wrap text in an ANSI colour, no-op when disabled |
| `.cli_style_bold()`, `_dim()`, `_italic()`, `_underline()` | Wrap text in an ANSI style, no-op when disabled |
| `.cli_symbol(name)` | Unicode symbol (`tick`, `cross`, `info`, `warn`, `bullet`, `arrow_right`, `line`) with ascii fallback |
| `.cli_alert_success()`, `_danger()`, `_warning()`, `_info()` | `message()`-based alerts with a coloured symbol prefix; extra `...` args go through `sprintf()` |
| `.cli_rule(title = NULL)` | A horizontal divider, optionally with a centred title |
| `.cli_bullets(items)` | A simple bulleted list |

```r
.cli_alert_success("Wrote %d files to %s", 3, "output/")
#> v Wrote 3 files to output/    (or a green tick + colour, in a real terminal)

.cli_rule("Summary")
.cli_bullets(c("one", "two", "three"))
```

## Tests

See [`tests/testthat/test-minicli.R`](tests/testthat/test-minicli.R).
These are dev-only — they don't ship with the copied file — and use
`testthat` + `withr` to force ANSI/unicode on or off deterministically
via the `cli.num_colors`/`cli.unicode` options rather than depending on
the real terminal capabilities of whatever machine runs them.
