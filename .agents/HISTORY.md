# minis design history

This file is a condensed historical record of completed design
decisions: what was tried, what was rejected, and why. It exists for
context in future sessions, not as a changelog or PR log --
step-by-step implementation narrative has generally been trimmed in
favour of the decisions themselves; see git history for that level of
detail if it's ever needed. Entries are in roughly chronological order.
Current-state facts that came out of this history (what minis exist
today, naming conventions) live in `AGENTS.md`, not here.

## Repo concept and philosophy: minis vs. source packages

The repo grew out of prototyping a stripped-down `cli` replacement
(`minicli`) for packages that want to minimise dependencies: base-R-only
ANSI/unicode capability detection modelled on `crayon`/`cli`'s own
internals (`crayon::has_color()`, `cli:::num_ansi_colors()`), reduced to
just the two booleans a "pretty vs. plain fallback" mini actually needs.

When a second mini (a purrr-style mapping helper, found among
`emaxnls`'s internal dot-prefixed utilities) was proposed, the question
of whether it should be one "miniplyr"-style grab-bag per source package,
or something narrower, came up. Decision: minis are scoped by
functionality, not mapped 1:1 onto the package that inspired them. purrr
split into `minimap` (the `map()` family) and `minitrap` (the
`safely()`/`quietly()` adverbs) as two separate, single-purpose minis
rather than one broad "purrr-lite" file.

## `minitrap` naming: rejecting "miniadverbs"

purrr's own docs call `safely()`/`quietly()` "function adverbs", making
"miniadverbs" the obvious name -- but it reads as a grammatical category
label rather than a name with its own identity, unlike `minicli`/
`minimap`, which both compress a concrete noun into the name (and
`minimap` gets an incidental pun with the video-game HUD term). Several
alternatives evoking the actual mechanism were considered (`minitry`,
`minicushion`, `minicapture`, `minimuffle`) before landing on
**`minitrap`**: it plays on "trap"ping errors/output/warnings, which is
literally what both wrapped functions do.

## Splitting the dplyr/tibble-inspired helpers into four minis

`emaxnls` has internal dot-prefixed reimplementations of dplyr's
`filter()`, `case_when()`, the `*_join()` family, and tibble's
construction helpers. Two groupings were considered: two broad minis
(`miniplyr` for the dplyr verbs + `minitable` for tibble), or four
narrow ones split per verb-family. Chose four
(`minifilter`/`minicase`/`minijoin`/`minitable`), consistent with the
"one file, one job" precedent set by `minimap`/`minitrap` -- `filter()`
and `case_when()` share no code with each other or with the joins, and
bundling them under one file would have been grouping by "feels
dplyr-ish" rather than by actual coupling. The four join verbs stayed
together as one mini since they share a single `.join_worker()`
implementation, the same pattern already used for `minimap`'s map
family.

## `minitable`: the cross-column-reference bug behind the source's restriction

`emaxnls`'s `.tibble()` (the source `minitable` was adapted from) was
not actually zero-dependency: it used `rlang::enexprs()` and optionally
deferred to real `tibble::tibble()` when installed, and it
unconditionally banned cross-column references
(`tibble(a = 1, b = a + 1)`), with a comment suggesting this was purely
to keep behaviour consistent whether or not real tibble was available.

Once the decision was made that `minitable` would always use the
lightweight fallback (never defer to a "real" package, consistent with
every other mini), that consistency rationale seemed to evaporate -- so
the plan was to *lift* the restriction, since the underlying
sequential-list evaluation mechanism (adapted from poorman, walking
`...` argument by argument via `match.call()`) appeared able to support
cross-column references when tested standalone.

Wiring it into `mtable_tibble()` surfaced the real reason for the
original restriction: `.tibble()` forwarded `...` to a separate `.lst()`
helper, and forwarding `...` through an intermediate function turns each
argument into an opaque `..1`/`..2` pronoun. Evaluating one of those
pronouns against a custom environment silently resolves free variables
against the *original caller's* environment instead of the supplied
one -- producing "object not found" errors or, worse, picking up an
unrelated same-named variable. The original ban on cross-column
references was a real bug workaround, not just a consistency choice.

Fix: inline the sequential-evaluation logic directly into
`mtable_tibble()` and `mtable_add_row()` (the functions that receive the
user's literal `...`), rather than factoring it into a shared
`...`-accepting helper. This restores cross-column-reference support
correctly. Also fixed while rewriting: `as.data.frame()`'s default
`make.names()` sanitisation was stripping tibble-style literal column
names (e.g. a column named `1:2` became `X1.2`) -- fixed with
`check.names = FALSE`; and `mtable_rownames_to_column()` now checks for
default sequential row names (matching tibble's `has_rownames()`)
instead of just `is.null(rownames(.data))`, which is never true for an
ordinary data frame.

## Repository setup and publication

Scaffolded as a plain git repo (not an R package -- no `DESCRIPTION`,
no roxygen2), with `testthat`/`withr` as dev-only dependencies for the
`tests/testthat/` suites, and a `run_tests.R` script at the root that
walks every `<mini>/tests/testthat/` directory. Added a GitHub Actions
workflow (`test.yaml`) that installs those two packages and runs
`run_tests.R` on push/PR. Published as a public repo at
github.com/djnavarro/minis via `gh repo create --source=. --remote=origin`.

Confirmed via `gh run list`/`gh run view` that the `test-minis` workflow
passes on GitHub's actual runners (not just locally) -- both the
`minitable` push and the subsequent `AGENTS.md` push completed
successfully in under a minute each. One informational, non-blocking
annotation appeared (`actions/checkout@v4` being forced onto Node.js 24
due to Node 20's deprecation on GitHub Actions runners); no action
needed.
