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

## `minicondition`: custom condition classes don't actually require rlang

`emaxnls`'s `.assert()`/`.abort()`/`.warn()`/`.inform()` were thin
wrappers around `rlang::abort()`/`warn()`/`inform()`, seemingly
reaching for rlang specifically for its classed-condition support
(catching a raised condition by a custom class name via `tryCatch(f(),
my_class = handler)`). This looked, at first, like a genuine
capability rlang added over base R -- notably, `minimap`'s
`.mmap_assert()` had already made this exact trade-off, dropping
custom condition classes and falling back to plain `stop()` specifically
to avoid the rlang dependency.

Verified experimentally that this trade-off wasn't actually necessary:
base R's own condition system supports the same catch-by-class
behaviour without rlang. Building a classed condition object directly
(`structure(class = c(class, "error", "condition"), list(message = ...,
call = ...))`) and signalling it via plain `stop()`/`warning()`/
`message()` is caught by `tryCatch()`/`withCallingHandlers()` on the
custom class exactly as an `rlang::abort()`-raised one would be. This
was confirmed by executing both versions side by side before writing
`minicondition`, not just inferred from documentation.

Two defaults were deliberately changed relative to the source: `class`
now defaults to `NULL` rather than a package-specific string (the
original always defaulted to e.g. `"emaxnls_error"`, which doesn't make
sense for a mini meant to be copied into any package), and `message`
has no default at all (the original defaulted to placeholder text like
`"emax_nls error"`, which isn't useful to any caller). Also fixed:
`mcond_assert()` treats `NA` in its logical vector as a failure --
the original's `if (any(expr == FALSE))` would itself error ("missing
value where TRUE/FALSE needed") on `NA` input instead of raising the
intended assertion error.

Named `minicondition` (over `minisignal`/`minithrow`/`minierr`) since
it maps directly onto base R's own name for this subsystem ("the
condition system"), rather than either of the two narrower verbs
(throw/signal) that undersell the warn/inform half of the API.

## Optional vignettes and the minis site: README vs. vignette split

Considered making every mini's `README.md` an `.Rmd`/`.qmd` that knits
to `README.md`, so code examples would be executed and verified
instead of hand-typed. Rejected: it makes the mandatory, zero-tooling
GitHub-facing doc require a knit step before every commit (with a new
"did you forget to re-knit" CI failure mode), for every mini, just to
add a mini at all -- too large a burden increase for the benefit, and
several existing READMEs (e.g. `minitrap`, `minimap`) already showed
that hand-typed `#>` output can drift silently, which is the actual
problem worth solving.

Chose instead: keep `README.md` plain and mandatory (unchanged), and
add a wholly optional `<mini>/vignette.qmd` that gets executed and
rendered into a small Quarto website. The two docs are deliberately
complementary rather than duplicates: the README stays the terse
reference (API table, scope notes, install instructions); the vignette
is the executed, worked-example walkthrough, and is the one guaranteed
to still be true after a render since its code actually runs. Adding a
mini's vignette is a separate, later, per-mini step -- it never gates
"Adding a new mini".

Scaffolded as: `_quarto.yml` (website project) + `index.qmd` (front
page listing every mini, linking to the rendered vignette when one
exists and to the GitHub README otherwise) + `.github/workflows/
site.yaml` (renders and publishes to GitHub Pages) + a committed
`_freeze/` cache (so unchanged vignettes aren't re-executed every
render, and non-R environments can still `quarto render`). Piloted on
one mini (`minitrap/vignette.qmd`) before deciding whether/how to
retrofit the rest.

One real bug surfaced while testing this end to end: Quarto website
projects render every `.qmd`/`.md` under the project root by default,
which was silently pulling `AGENTS.md` and `.agents/*.md` into the
rendered site as pages. Fixed by giving `_quarto.yml`'s
`project.render` an explicit list (`index.qmd`, `*/vignette.qmd`)
rather than relying on the default "render everything" behaviour.

## Pretty per-mini URLs without renaming `vignette.qmd`

Once the site existed, `<mini>/vignette.qmd` rendered to
`<mini>/vignette.html`, giving URLs like `baseurl/minitrap/vignette.html`
rather than the tidier `baseurl/minitrap/`. The obvious fix -- rename
each mini's vignette source file to `<mini>/index.qmd` -- was
considered and rejected: every mini folder would then contain both
`README.md` and `index.qmd` side by side, and it's not obvious at a
glance which one is "the" index without already knowing the Quarto
convention, especially since `README.md` already plays that role for
GitHub.

Verified experimentally that Quarto's per-format `output-file` option
solves this without a rename: setting `format.html.output-file: index`
project-wide in `_quarto.yml` makes every rendered page (the vignettes,
and the already-named-index root page) emit as `index.html` in its own
output directory, giving `baseurl/<mini>/` for free. Note the value
must be `index`, not `index.html` -- passing an extension raises
`Invalid value for 'output-file': paths are not allowed`. Source files
keep their self-documenting `vignette.qmd` name; only the rendered
output path changes.

## Retrofitting all eight minis with vignettes

Following the scaffolding and pretty-URL work above, each of the
remaining minis got its own `vignette.qmd`, one at a time
(`minicli`, `minifilter`, `minicase`, `minijoin`, `minitable`,
`minicondition`, joining the original `minitrap`/`minimap` pilots) --
all eight minis now have a rendered site page. `minifilter` and
`minicase` deliberately share the same small toy `fruits` data frame
(each vignette redefines it independently, since vignettes don't
source one another) so the two are easy to compare side by side.
`minijoin`'s vignette surfaced a real, worth-documenting subtlety
while verifying output before writing prose: on `right_join()`/
`full_join()`, matched rows keep `x`'s original order, and rows
unmatched-in-`x` are *appended at the end* rather than interleaved in
`y`'s order -- confirmed by executing the join before describing it,
not inferred from the source code. Every vignette's example output was
executed and checked against its prose claims before committing,
consistent with the "verify by executing, not just reading" practice
already established elsewhere in this repo.

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

## `minicli`: ANSI detection gap in Positron/RStudio consoles

While reimplementing `minicli`-style helpers inside a separate package
(`djnavarro/sessioncheck`, `R/display.R`), the original
`.mcli_ansi_enabled()` was found to silently disable colour in both
Positron's and RStudio's Console panes: its final fallback,
`isatty(stdout())`, is `FALSE` in both, since neither is a real tty.
`sessioncheck` had already worked around this with two additional
front-end checks, verified against real console sessions rather than
inferred: `.rstudio_console_with_color()`, which trusts
`RSTUDIO_CONSOLE_COLOR` only when `RSTUDIO == "1"` (this env var is set
specifically in RStudio's Console pane, not its Terminal/Build panes or
RStudio Jobs, mirroring crayon/cli's own `rstudio_with_ansi_support()`);
and `.positron_console_with_color()`, which trusts ark's
`options(cli.default_num_colors = <n>)` only when `POSITRON == "1"`,
since Positron's R kernel sets that option directly at startup rather
than relying on tty detection at all.

Ported both checks into `minicli.R` verbatim (as
`.mcli_positron_console_with_color()`/
`.mcli_rstudio_console_with_color()`), inserted into
`.mcli_ansi_enabled()` after the `sink.number()`/`knitr.in.progress`
short-circuits but before the `isatty()` fallback -- the same ordering
`sessioncheck` used, so that captured/non-interactive output still
correctly suppresses colour regardless of which front end is hosting
the session. Confirmed while testing that this environment's own
`Rscript` sessions run with `NO_COLOR=1` set ambiently, which the new
tests must clear explicitly via `withr::local_envvar()` alongside the
Positron/RStudio env vars they set, or the ambient value leaks in and
masks the behaviour under test.

## Repo-wide rename: dropping the exported/internal prefix split for a uniform dot-prefix

The original convention prefixed exported functions with a bare
mini-specific string (`mtrap_safely`) and internal helpers with a
dot-prefixed version of the same string (`.mtrap_assert`). Revisited
this once it became clear the exported/internal distinction doesn't
actually matter to a mini's consumer: a mini is always copied into a
package's `R/` directory and treated as wholly internal there,
regardless of which functions the mini's own author considered "core"
versus "helper" — so the naming scheme was drawing a distinction real
usage never observes. Decided instead to dot-prefix every function in
a mini uniformly with the same short tag, collapsing the two naming
tiers into one.

Two complications surfaced once this was worked through mini-by-mini,
both resolved by treating the tag as a per-mini judgment call rather
than a mechanical truncation of the folder name:

- **Stutter on single-function minis.** `minifilter` and `minicase`
  each export exactly one function whose name already *is* the
  natural tag (`filter`, `case_when`), so a mechanically-derived tag
  produces `.filter_filter()`/`.case_case_when()`. Fix: those two
  minis export a bare dot-name (`.filter()`, `.case_when()`) with no
  additional tag, while their internal helpers (`.filter_dotdotdot()`,
  `.case_replace_with()`, etc.) keep a short tag — the generic helper
  names are the ones actually at risk of colliding with something
  else once copied into a consuming package, not the single
  distinctively-named exported function.
- **Semantic mismatch on multi-verb minis.** `minimap` bundles a
  map-family (`map`/`map2`/`imap`/`map_dbl`/`map_lgl`/`map_chr`) and a
  walk-family (`walk`/`iwalk`, which call `map()` internally for a
  side-effect variant) in one file, consistent with this repo's
  "shared implementation stays together" precedent (see the `minijoin`
  entry above). A tag literally named "map" reads badly on the walk
  half (`.map_walk()` sounds like walk is a kind of mapping operation,
  when to a reader it's a related-but-distinct verb). Fix: gave
  `minimap` the tag `.iter_` instead of `.map_`, decoupling the
  internal namespace tag from the folder/file name — `minimap` the
  folder wasn't itself confusing, only a tag mechanically derived from
  it would have been. This established that the tag is its own
  per-mini naming decision, not something that has to match the
  mini's name.

The other five minis (`minicli`, `minitrap`, `minijoin`, `minitable`,
`minicondition`) kept a straightforward tag matching their folder name
(`.cli_`, `.trap_`, `.join_`, `.table_`, `.cond_`) since none of their
exported functions collide with the tag word or span a semantically
split family. Applied across all eight minis' source files, tests,
READMEs, and vignettes; `Rscript run_tests.R` confirmed all suites
still pass after the rename.

## Repo-wide stress test: real bugs found only by executing edge cases

With all eleven minis and their vignettes in place, ran a deliberate
stress-testing pass rather than waiting for bugs to surface
incidentally: one subagent per mini, each instructed to read the
mini's source/README/vignette/tests, cross-check every documented
claim by executing it, and then actively try to break the mini with
edge cases the existing tests didn't cover (empty/zero-length input,
`NA` in unusual positions, type mismatches, duplicate names). A
separate pass checked the repo-level docs (root `README.md`,
`AGENTS.md`, `index.qmd`, `_quarto.yml`) for staleness. This surfaced
far more than the incidental bug-finding of previous work: most of the
mismatches were real, previously-unexercised bugs, not just doc drift,
reinforcing the existing "verify by executing" practice rather than
supplanting it -- reading the code alone had already missed all of
these.

Fixed one mini at a time on a dedicated branch, each with regression
tests, updated docs, and a full `Rscript run_tests.R` pass before
moving on. The fixes worth remembering for their own sake, beyond
routine doc corrections (a dead `minifilter` reference in the root
README's Philosophy section, left over from that mini's rename to
`miniverb`; function-count typos in the `minirx`/`ministr` vignettes;
a copy-paste typo in `minimap`'s header comment; and `minitrap`'s
worked example calling `log(-1)`, which only warns and never actually
raises the error the doc claimed):

- **`minicli`**: `.cli_ansi_enabled()` returned `NA` instead of
  `TRUE`/`FALSE` whenever `cli.num_colors` was set to `NA` (`opt > 1`
  on `NA` is `NA`, not caught before being returned), crashing any
  styling call. Fixed by coercing defensively and falling through to
  the other detection checks on a non-numeric option value -- which
  also fixed a related latent bug where a numeric-looking *string*
  option (`cli.num_colors = "8"`) only "worked" by accident via
  lexicographic string comparison. Also fixed: `.cli_symbol()` crashed
  with an opaque base-R error on a vector `name` instead of its own
  "Unknown symbol" message, and `.cli_alert_*()` ran a vectorised
  `text` argument's entries together with no line separator.
- **`minicondition`**: `.cond_inform()` stored `paste0(message, "\n")`
  in the condition object itself (to get `message()`-style trailing-
  newline console output when handing a pre-built condition straight
  to `message()`), so `conditionMessage()` on a caught `.cond_inform()`
  condition returned `"hi there\n"`, unlike the exact-text
  `.cond_abort()`/`.cond_warn()`. Fixed by manually replicating
  `message()`'s own signal/restart/print mechanics
  (`signalCondition()` + `withRestarts(muffleMessage = )` + a final
  `cat()`), so the newline is added only at print time, never stored.
  While regression-testing this, discovered that a test which left
  `cli.num_colors = NA` set for an entire `test_that()` block (to test
  the `minicli` fix above) crashed testthat's own `cli`-based
  "summary" reporter, since it reads that same session-wide option to
  colourise its own pass/fail dots -- a reminder that a test's
  `withr::local_options()` scope can leak into unrelated framework
  internals, not just the code under test; rescoped with
  `withr::with_options()` tightly around just the call being tested.
- **`minipivot`**: four separate `.pivot_wider()`/`.pivot_longer()`
  bugs, all in previously-untested territory -- a `names_from` value
  identical to an existing id column's name silently overwrote that id
  column (`out[[cn]] <- col_out` with no collision check); a
  `values_fill` of a different type than `values_from` coerced the
  *entire* output column, including cells with real, already-matched
  data, because `col_out` was seeded via `rep(fill_val, n)` before any
  real values were assigned into it; `NA` in `names_from` crashed with
  "NAs are not allowed in subscripted assignments"; and a zero-row
  `.data` silently dropped `.pivot_longer()`'s `values_to` column
  entirely, since `unlist(list())` is `NULL` and `out[[col]] <- NULL`
  removes/never-creates a data frame column. Fixed by seeding
  `.pivot_wider()`'s output column from `values_col`'s own type (an NA
  vector of the correct type/class) rather than from `values_fill`,
  coercing an `NA` `names_from` value to the literal string `"NA"`
  up front, and guarding the zero-row `NULL`-vs-empty-vector case in
  `.pivot_longer()`.
- **`minicase`**: `.case_check_class()` compared `class(x)` vs
  `class(y)` only, so two factors both satisfied it (both class
  `"factor"`) regardless of whether they shared the same *levels*.
  Assigning between them (`x[i] <- val`) then triggered
  `[<-.factor`'s label-based lookup, silently turning any label absent
  from the target's levels into `NA` -- a real, silent data-loss bug,
  with only a base R warning, not an error. Fixed by additionally
  comparing `levels()` when both sides are factors.
- **`minijoin`**: two bugs found together in `keep = TRUE` handling.
  First, `.join_worker()` looked up the joined column in `merge()`'s
  output using `by`'s own *value*, which only works when `by` is
  unnamed -- `merge()` with differing `by.x`/`by.y` always collapses
  the joined column to `by.x`'s *name*, so a named `by` (renamed join
  columns) crashed with "undefined columns selected". While fixing
  that, found a second, independent, pre-existing bug: the "kept"
  column for whichever side didn't already have the collapsed by-
  column was built by copying that already-merged column, so it
  silently mirrored the *other* side's value even on rows with no
  actual match -- exactly the information `keep = TRUE` exists to
  preserve. Fixed by carrying each side's own by-column value through
  `merge()` under a temporary, non-`by` column name so `merge()`'s own
  `all.x`/`all.y` `NA`-filling applies to it like any other real
  column, then dropping the now-redundant single collapsed by-column
  afterward.
- **`minitable`**: `.table_add_row()` hands its new row straight to
  `rbind()` with no validation, which had two consequences: a
  missing/extra/misspelled column name surfaced `rbind()`'s own
  low-level "numbers of columns of arguments do not match" instead of
  naming the problem column, and a new value of a different type than
  its existing column (e.g. a character value for a numeric column)
  let `rbind()` silently upcast the *entire* column -- including
  already-correct existing values -- with no warning. Fixed with
  explicit pre-`rbind()` checks for both, naming the offending
  column(s)/type(s) in the error (integer/double are treated as
  interchangeable, since mixing those two is unremarkable).
- **`miniverb`**: `.verb_split_by()` ordered groups by sorted key
  value (`order()`), but dplyr's actual `.by`/`group_by()` semantics
  return/process groups in *first-appearance* order -- confirmed by
  running `dplyr::summarise(.by = )` side by side, and the divergence
  was already silently visible in this mini's own vignette (the
  fruits/`in_stock` example showed `FALSE` before `TRUE`, since
  `FALSE` sorts first, even though `TRUE` is the value actually seen
  first in the data). Fixed by ranking each distinct key by first
  appearance (`match(key, unique(key))`) instead of sorting --
  `split()` on that small-integer vector sorts numerically by rank,
  so first-appearance order falls out without a separate sort step.
  Also fixed: `.verb_summarise()` let a summary expression's name
  collide with a `.by` grouping column's name, silently producing two
  output columns both named the same via `cbind()`, since the
  grouping columns are always prepended with no collision check.

As with `minitable`'s cross-column-reference bug and `minicondition`'s
rlang-independence finding earlier in this file, every one of these
was confirmed by actually running the failing case, not inferred from
reading the source -- reinforcing that reading a mini's code is not a
substitute for exercising the edge cases its own tests don't cover,
especially for logic (factor levels, `merge()`'s column-collapsing,
`.by`'s group order) whose surprising behaviour lives in a dependency
(base R's own semantics) rather than in the mini's own code.
