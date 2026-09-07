---
name: writing-minis
description: Guides creating a new mini or auditing/renaming an existing one in the djnavarro/minis repo, covering how to name the mini and its dot-prefixed functions, the required README/tests, the optional Quarto vignette, and commit conventions. Use when adding a new mini, splitting source material across minis, naming or renaming mini functions, writing a mini's README.md or vignette.qmd, or reviewing a mini for consistency with repo conventions.
---

# Writing minis

A mini is a single-file, zero-runtime-dependency R component meant to be
copied into a consuming package's `R/` directory and treated as wholly
internal there. This skill covers the mechanics of creating or auditing
one. For the philosophy/history behind these rules, see `AGENTS.md` and
`.agents/HISTORY.md` at the repo root — this skill only covers the "how".

## Before writing any code

Two decisions are judgment calls to surface to the user (e.g. via
enumerated options), not to make unilaterally:

- **Naming the mini.** Pick a short, concrete name evoking what the mini
  *does*, not the grammatical/abstract category it belongs to (rejected
  `miniadverbs` for `minitrap` because "adverb" is a category label, not
  an identity — "trap" describes the actual mechanism).
- **Splitting source material across minis.** A single inspiring package
  typically splits into several minis, scoped by functionality rather
  than mapped 1:1 onto the source package (purrr → `minimap` + `minitrap`,
  not one "purrr-lite" file). Functions that share a real implementation
  (e.g. `walk()` calling `map()` internally, the four `*_join()` verbs
  sharing one `.join_worker()`) stay in one mini; functions that merely
  "feel like they belong together" (e.g. `filter()` and `case_when()`
  just because both are dplyr-ish) get split.

Once agreed, implementation (source file, tests, README, root README
update) can proceed directly without further check-in.

## Function naming

Every function in a mini — whether the mini's own author would call it
"core" or "internal" — gets the **same short, mini-specific, dot-prefixed
tag**. There is no separate exported-vs-internal naming convention:
once copied into a consuming package, everything in a mini is an
internal implementation detail regardless of how the mini itself scopes
"core" vs. "helper".

Work through these in order when choosing a tag:

1. **Does the mini export exactly one function, and does its name already
   equal the natural tag?** (`minifilter` → `filter`, `minicase` →
   `case_when`.) If so, that one function gets a **bare dot-name** with no
   tag at all (`.filter()`, `.case_when()`) — a mechanically-derived tag
   would stutter (`.filter_filter()`, `.case_case_when()`). Internal
   helpers in that same mini still get a short tag (`.filter_dotdotdot()`,
   `.case_replace_with()`), since generic helper names are the ones
   actually at collision risk once copied elsewhere.
2. **Does the mini bundle two related-but-distinct verb families?**
   (`minimap` bundles a map-family and a walk-family, related by shared
   implementation but not synonymous.) If a tag derived from only one
   family reads badly applied to the other (`.map_walk()` misleadingly
   implies `walk()` is a kind of mapping operation), pick a broader,
   family-neutral tag instead (`.iter_`) — decoupled from the folder/file
   name, which can stay as-is.
3. **Otherwise**, use a short truncation of the folder name as the tag
   (`minicli` → `.cli_`, `minitrap` → `.trap_`, `minijoin` → `.join_`,
   `minitable` → `.table_`, `minicondition` → `.cond_`).

See AGENTS.md's mini table for the tag currently assigned to each mini.

## File layout

```
<name>/
  <name>.R                    # single, zero-dependency source file
  README.md                   # mandatory
  vignette.qmd                # OPTIONAL: see "Vignette" below
  tests/
    testthat/
      test-<name>.R
```

**`<name>.R` header comment** must state: what it reimplements, what's
deliberately excluded, any deliberate fixes relative to the
package/snippet adapted from, and a one-line naming-convention note
(e.g. "All functions are dot-prefixed with the tag `.cli_` — there's no
separate exported-vs-internal naming split, since every function here is
meant to be treated as an implementation detail once copied into a
consuming package."). `@export`/`@noRd` roxygen tags are still fine to
keep on functions — they document "main function" vs. "plumbing helper"
independent of the naming scheme, useful if a consumer later runs
roxygen2 over their copy.

**Zero runtime dependencies, always.** If the material being ported
isn't already dependency-free, that's a sign real rework is needed (as
with `minitable`, whose source forwarded `...` through an rlang-enabled
helper) — flag this to the user rather than silently keeping the
dependency.

**Verify by executing, not just reading**, when adapting existing
material (an internal helper, or an external dependency-free package
like poorman). Several minis in this repo had real behavioural bugs —
not just cosmetic naming differences — surface only once tests were
actually run against the ported logic.

## README.md (mandatory)

Plain markdown, no build step. Typical sections, in order: one-paragraph
description + link to the source package; `## Install` (copy the file,
no `Imports`/`Suggests` needed); `## API` (a table of function → purpose,
mirroring the source package's function where relevant); a short runnable
code example; `## Scope` (what's deliberately excluded); a
`## Deliberate fix...` section if a real bug was found and fixed relative
to the source; `## Tests` (pointer to the testthat file).

## Vignette (optional, additive)

A `<mini>/vignette.qmd` is an *executed*, worked-example page rendered
into the minis Quarto site — complementary to the README (not a
duplicate): the README is the terse reference, the vignette is the
narrative walkthrough whose code is guaranteed to still be true because
it actually runs. Never required to add a mini.

- Source the mini the same way tests do, relative to repo root:
  `source(file.path("<mini>", "<mini>.R"))` (works because
  `execute-dir: project` is set in `_quarto.yml`).
- Add `"<mini>/vignette.qmd"` — actually just the existing glob
  `"*/vignette.qmd"` in `_quarto.yml`'s `project.render` already covers
  new vignettes; you do not need to edit `_quarto.yml` per mini.
- **If the vignette cross-references another mini's function** (e.g.
  demonstrating two minis composing together), that reference will not
  be caught by a rename done only within the *other* mini's own files —
  grep the whole repo for the old name after any rename, not just the
  mini being renamed.
- After writing/editing, run `quarto render` and commit the resulting
  `_freeze/` changes alongside. To verify a specific page renders
  correctly in isolation (not masked by state left over from another
  page in the same project-wide render), delete its freeze entry first:
  `rm -rf _freeze/<mini> && quarto render <mini>/vignette.qmd`.

## Testing

- Test file sources the mini via
  `testthat::test_path("..", "..", "<name>.R")`.
- Run one mini's suite: `testthat::test_dir("<name>/tests/testthat")`.
- Run every mini's suite (do this before considering any edit done):
  `Rscript run_tests.R` from the repo root.
- `testthat`/`withr` are dev dependencies of *this repo only* — never
  add them (or anything else) to a mini's own runtime dependencies.

## Wiring in a new mini

Add a row to **both** the table in the root `README.md` and the mini
table in `AGENTS.md` (purpose/prefix-tag/adapted-from columns). If the
mini has a vignette, also add it to `index.qmd`'s table and to the
sidebar `contents` list in `_quarto.yml`.

## Commit conventions

One commit per new mini, message `Add <name>`, body summarising what it
reimplements and any deliberate fixes/bugs found relative to the source
material. For a change that touches multiple existing minis at once
(e.g. a repo-wide naming or convention change), prefer a single commit
describing the change as one coherent decision rather than splitting
per mini — especially if the change includes cross-mini references that
would leave an intermediate commit in a broken state.
