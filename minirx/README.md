# minirx

A minimal, zero-dependency reimplementation of stringr's regex-based
pattern-matching verbs: detect, extract, match, replace, remove, split,
count, and locate. Every function takes a single PCRE pattern, applied
via base R's `perl = TRUE` regex engine -- not stringr/stringi's ICU
engine.

Adapted from [stringr](https://stringr.tidyverse.org). (For non-regex
string manipulation like padding/trimming/case conversion, see the
companion `ministr` mini.)

## Install

Copy [`minirx.R`](minirx.R) into your package's `R/` directory. No
`Imports`/`Suggests` entry needed.

## API

| Function | Purpose |
|---|---|
| `.rx_detect(string, pattern, negate)` | Detect whether a pattern matches |
| `.rx_starts(string, pattern, negate)` / `.rx_ends(string, pattern, negate)` | Detect whether a string starts/ends with a pattern |
| `.rx_extract(string, pattern)` | Extract the first match |
| `.rx_extract_all(string, pattern)` | Extract every match |
| `.rx_match(string, pattern)` | Extract the first match plus capture groups, as a matrix |
| `.rx_match_all(string, pattern)` | Extract every match plus capture groups, as a list of matrices |
| `.rx_replace(string, pattern, replacement)` / `.rx_replace_all(string, pattern, replacement)` | Replace the first/every match |
| `.rx_remove(string, pattern)` / `.rx_remove_all(string, pattern)` | Remove the first/every match |
| `.rx_split(string, pattern)` | Split a string on every match |
| `.rx_count(string, pattern)` | Count non-overlapping matches |
| `.rx_locate(string, pattern)` / `.rx_locate_all(string, pattern)` | Locate the position(s) of the first/every match |

```r
.rx_detect(c("cat", "dog", NA), "^c")
#> [1]  TRUE FALSE    NA
.rx_extract(c("item-12", "item-x"), "[0-9]+")
#> [1] "12" NA
.rx_replace_all("2024-01-02", "(\\d+)-(\\d+)-(\\d+)", "\\3/\\2/\\1")
#> [1] "02/01/2024"
```

## Scope

- `pattern` is always a single string; this mini does not vectorise
  over `pattern` (base R's own `grepl()`/`sub()`/`gsub()` don't either
  -- a multi-element pattern would silently use only its first
  element).
- No `fixed()`/`coll()`/`boundary()` pattern-type wrappers, and no
  locale-aware collation. If you need genuinely locale-sensitive
  matching, this mini isn't a substitute for `stringr` itself.
- `.rx_match()`/`.rx_match_all()` determine the number of output
  columns (one for the full match, plus one per capture group) from
  whichever input string matched first. If a pattern's capture groups
  can vary in count across matches (e.g. via alternation), this is a
  real restriction, not just a cosmetic simplification.

## Deliberate fixes relative to naive base-R wrapping

- `grepl()` returns `FALSE` for an `NA` input rather than propagating
  the missing value; `.rx_detect()`/`.rx_starts()`/`.rx_ends()` force
  those positions back to `NA`, matching `stringr::str_detect()`.
- `regmatches(string, regexpr(...))` silently *drops* elements of
  `string` that didn't match, shortening the result vector instead of
  leaving a hole. `.rx_extract()` reconstructs a full-length result
  with `NA` in the positions that didn't match.
- `gregexpr()`'s "no match" sentinel is a single `-1`, which naively
  looks like one match rather than zero. `.rx_count()` fixes this, and
  separately distinguishes an `NA` input (giving `NA`) from a genuine
  zero-match string (giving `0`).

## Tests

See [`tests/testthat/test-minirx.R`](tests/testthat/test-minirx.R).
