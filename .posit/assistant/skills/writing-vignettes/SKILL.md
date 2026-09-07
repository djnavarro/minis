---
name: writing-vignettes
description: Guides writing or auditing the prose style of a mini's vignette.qmd in the djnavarro/minis repo — the opening framing, bold/link conventions for package and mini names, the Functions section format, sentence-level rules (no code-first sentences, no jargon, third-person voice, British spelling), and a final cross-vignette consistency check. Use when writing a new vignette.qmd, editing vignette prose, or reviewing existing vignettes for stylistic drift. Does not cover vignette file mechanics (sourcing, _freeze/, wiring into _quarto.yml) — see the writing-minis skill for that.
---

# Writing vignette prose

This skill covers *how a vignette should read*, distilled from a full
style pass applied to all nine existing vignettes. For *where the file
goes and how it's rendered/wired in*, see the writing-minis skill's
"Vignette" section instead — the two are deliberately split because
writing a mini and writing its narrative walkthrough are different
tasks.

## Opening paragraph

State the mini's purpose, name the source package it reimplements
(bold + linked on this first mention), then hand off to the README and
preview the page's structure:

> The purpose of **minifilter** is to provide a zero-dependency
> reimplementation of a single function from the
> [**dplyr**](https://dplyr.tidyverse.org/) package: `filter()`. It
> keeps rows of a data frame where every one of a set of unquoted
> conditions is `TRUE`. The [README](https://github.com/djnavarro/minis/tree/main/minifilter)
> provides scope notes; this page walks through its behaviour on a
> small toy data frame, including two things worth knowing about
> before you rely on it: how missing values are handled, and what
> happens when no conditions are supplied at all.

- README links are always the absolute `https://github.com/djnavarro/minis/tree/main/<mini>` URL (plain `[README](...)`, not bolded) — the vignette can't assume it's being read from the rendered site.
- Cross-references to *another mini's* vignette use a bold, site-relative link instead: `[**minicase**](../minicase/)`.
- A source package (dplyr, tidyr, tibble, rlang, purrr, cli, poorman, ...) gets **bold + linked** the first time it's named. Later bare mentions in the body (e.g. "the same way you would in `dplyr`") stay as plain inline code — don't re-bold/re-link every occurrence.

## Functions section

Always open with a linked reference to the mini's own script, then
list functions as bullets — **even when there is only one function**,
core or internal. This keeps a clean visual rule: functions live in
bullet lists, prose lives outside them.

```markdown
The [**minifilter.R**](https://github.com/djnavarro/minis/blob/main/minifilter/minifilter.R)
script supplies a single core function:

- `.filter(.data, ...)` is used to keep rows of `.data` where every
  condition in `...` evaluates to `TRUE`. Conditions are evaluated in
  the scope of `.data`, so columns can be referred to by bare name.

There is also one internal helper:

- `.filter_dotdotdot()` captures the unevaluated `...` conditions so
  each one can be evaluated against the data frame individually,
  rather than evaluated eagerly against the caller's environment.
```

If a mini has no internal helpers, say so explicitly rather than
omitting the sentence: "It contains no internal helpers." Bullet
phrasing is normally "`fn(...)` is used to ...", but a short "`fn(...)`
builds/captures/is the shared implementation ..." reads fine too as
long as it's a complete, self-contained sentence per bullet.

## Sentence-level rules

**Never start a sentence with inline code.** Every sentence should be
able to start with a capitalised word, so a value/function name that
would otherwise open a sentence gets a noun in front of it:

- Bad: `` `date` has a missing `price`, so... ``
  Good: "The `date` row has a missing `price`, so..."
- Bad: `` `.cli_warn()` signals a classed warning... ``
  Good: "The `.cli_warn()` function signals a classed warning..."
- Bad: `` `"Rolling Stones"` is kept, with `NA` for `album`... ``
  Good: "The `"Rolling Stones"` row is kept, with `NA` for `album`..."

This applies however deep into a paragraph the sentence falls, not
just the paragraph's first sentence.

**Avoid programming jargon an R user wouldn't use.** "No-op" is the
canonical example — say "leaves the data frame unchanged" or "does
nothing" instead. Prefer plain description of *behaviour* over jargon
labels for it.

**Third person throughout, no asides in first person.** Not "I decided
not to implement `.default`..." — instead: "There was no need for this
mini to implement dplyr's newer, separate `.default` argument...".

**British/Australian spelling**: colour, behaviour, centred, recognise,
sanitised.

**Keep it a little informal, not dry reference prose** — this is a
tutorial page, not the README. Contractions ("it's", "doesn't") and a
conversational aside here and there are fine; a personal joke or rant
is not (one vignette had an AI-generated-dataset joke trimmed down to
a plain factual sentence during review — keep asides about the
*mini's behaviour*, not about how the example data came to exist).

## Final step: cross-vignette consistency check

After writing or editing one or more vignettes, read all nine
`*/vignette.qmd` files together (not just the one(s) just touched) and
check for:

- Typos and duplicated words (`generat outout`, "that that", missing
  articles) — these are easy to miss editing one file at a time.
- Drift in phrasing established above bleeding back into
  already-written vignettes (e.g. one vignette still saying `` `pkg` ``
  in prose where it should be **pkg**, or a Functions-section bullet
  using different phrasing than the rest).
- Trailing whitespace and stray double-spaces introduced by editing.

After any content edit, re-render the affected vignette
(`quarto render <mini>/vignette.qmd`) and re-run the full suite
(`Rscript run_tests.R` from the repo root) before committing —
commit the vignette change together with its updated `_freeze/`
entry.
