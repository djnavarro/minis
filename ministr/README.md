# ministr

A minimal, zero-dependency reimplementation of stringr's basic string
manipulation verbs: padding, trimming, whitespace squishing, substrings,
length, case conversion, duplication, concatenation, and wrapping.

Adapted from [stringr](https://stringr.tidyverse.org), reimplementing
the same behaviour with base R string primitives only -- no regex
engine, no ICU, no locale awareness. (For pattern-matching functions
like `str_detect()`/`str_replace()`/`str_split()`, see the companion
`minirx` mini.)

## Install

Copy [`ministr.R`](ministr.R) into your package's `R/` directory. No
`Imports`/`Suggests` entry needed.

## API

| Function | Purpose |
|---|---|
| `.str_pad(string, width, side, pad)` | Pad a string to a fixed width |
| `.str_trim(string, side)` | Trim leading/trailing whitespace |
| `.str_squish(string)` | Trim and collapse internal whitespace runs to one space |
| `.str_sub(string, start, end)` | Extract a substring by (possibly negative) character position |
| `.str_length(string)` | Length of a string, in characters |
| `.str_to_upper(string)` / `.str_to_lower(string)` | Convert case |
| `.str_to_title(string)` | Convert to title case (ASCII word boundaries) |
| `.str_to_sentence(string)` | Convert to sentence case (first letter only) |
| `.str_dup(string, times)` | Repeat a string |
| `.str_c(..., sep, collapse)` | Concatenate strings, propagating `NA` |
| `.str_wrap(string, width, indent, exdent)` | Wrap a string to a target line width |

```r
.str_pad("7", 3, pad = "0")
#> [1] "007"
.str_squish("  too   much   space  ")
#> [1] "too much space"
.str_sub("hello world", -5, -1)
#> [1] "world"
.str_to_title("the quick brown fox")
#> [1] "The Quick Brown Fox"
.str_c("a", c(NA, "y"), sep = "-")
#> [1] NA    "a-y"
```

## Scope

- `.str_c()` and `.str_pad()` propagate `NA` the way stringr does (an
  `NA` anywhere in the inputs to a given position makes that position's
  output `NA`), unlike base `paste0()`, which coerces `NA` to the
  literal string `"NA"`.
- `.str_to_upper()`/`.str_to_lower()` are plain `toupper()`/`tolower()`,
  and `.str_to_title()` finds word starts with the ASCII regex `\\b`,
  not stringi's Unicode word-break algorithm -- fine for ASCII/Latin
  text, unreliable for scripts without whitespace-delimited words.
- Not included: `str_sub<-` (assignment form of substring replacement),
  `str_order()`/`str_sort()` (locale-aware sorting), `str_glue()`
  (templating).

## Tests

See [`tests/testthat/test-ministr.R`](tests/testthat/test-ministr.R).
