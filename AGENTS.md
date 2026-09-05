# AGENTS.md

## What this repository is

`minis` is a collection of small, standalone, **zero-runtime-dependency**
R components, each shipped as a single `.R` file with its own drop-in
testthat suite. A mini exists so that a package which needs a small
slice of some larger package's behaviour (a few `cli`-style alerts, a
`purrr`-style `map()`, a `dplyr`-style `filter()`) can copy one file
into `R/` instead of adding a dependency.

Minis are not installed, are not an R package themselves, and are not
meant to be `library()`-loaded as a unit -- each is copied out
individually.

---

## Architecture reference (current state)

This section documents the repo as it stands today. For the reasoning
behind naming/scoping decisions and a record of bugs found while
porting, see [.agents/HISTORY.md](.agents/HISTORY.md). For work that's
been discussed but not done, see [.agents/PLAN.md](.agents/PLAN.md).

### Repository structure

```
minis/
  README.md                     # Philosophy, index of minis, usage instructions
  LICENSE                       # MIT
  run_tests.R                   # Runs every mini's tests/testthat/ suite; exits non-zero on failure
  _quarto.yml                   # Site config for the optional minis Quarto site (see below)
  index.qmd                     # Site front page: philosophy blurb + mini index, linking to READMEs/vignettes
  paleblue.scss                 # Site light-mode theme (shared palette/fonts with djnavarro's other sites)
  blackpink.scss                # Site dark-mode theme (ditto)
  _freeze/                      # Committed Quarto render cache (see "Vignettes and the minis site")
  .github/workflows/test.yaml   # CI: installs testthat+withr, runs run_tests.R
  .github/workflows/site.yaml   # CI: renders the Quarto site and publishes it to GitHub Pages
  <mini>/
    <mini>.R                    # The single, zero-dependency source file
    README.md                   # What it does, scope, deliberate fixes/restrictions vs. the source it's adapted from
    vignette.qmd                # OPTIONAL: executed worked-example page rendered into the minis site
    tests/
      testthat/
        test-<mini>.R           # testthat tests; source the mini via testthat::test_path("..", "..", "<mini>.R")
```

### Current minis

| Mini | Prefix | Adapted from | Purpose |
|---|---|---|---|
| `minicli` | `mcli_` | `cli`/`crayon` (own reimplementation) | Coloured alerts/symbols/rules with ANSI/unicode fallback |
| `minimap` | `mmap_` | `emaxnls`'s `.map()` family (from `purrr`) | `map`/`map2`/`imap`/`walk`/`iwalk`/`map_dbl`/`map_lgl`/`map_chr` |
| `minitrap` | `mtrap_` | `emaxnls`'s `.safe_fn()`/`.quiet_fn()` (from `purrr`) | `safely()`/`quietly()`-style function adverbs |
| `minifilter` | `mfilter_` | poorman's `filter()` (from `dplyr`) | Row filtering by unquoted conditions |
| `minicase` | `mcase_` | poorman's `case_when()` (from `dplyr`) | Vectorised if/else via formulas |
| `minijoin` | `mjoin_` | poorman's `joins.R` (from `dplyr`) | `inner_join`/`left_join`/`right_join`/`full_join` via `merge()` |
| `minitable` | `mtable_` | `emaxnls`'s `.tibble()` family (from `tibble`) | `tibble`/`as_tibble`/`rownames_to_column`/`add_row` |
| `minicondition` | `mcond_` | `emaxnls`'s `.assert()`/`.abort()`/`.warn()`/`.inform()` (from `rlang`) | Classed errors/warnings/messages, plus `assert()`, via base R's condition system |

### Design philosophy

- **One file, one job.** Each mini does one narrow thing. No mini
  depends on another mini's file, or on any external package, at
  runtime.
- **No 1:1 mapping to source packages.** A single inspiring package
  (e.g. purrr) typically splits into several minis (`minimap` +
  `minitrap`), scoped by functionality rather than by origin.
- **Copy, don't install.** Minis are vendored into a consuming
  package's `R/` directory, never added to `Imports`/`Depends`.
- **Namespaced defensively.** Exported functions use a mini-specific
  prefix (see table above); internal helpers use a dot-prefixed version
  of the same prefix (e.g. `.mtable_drop_dup_list()`).
- **Tested, but tests don't ship.** `tests/testthat/` lives in this
  repo for development only; `testthat`/`withr` are dev dependencies of
  the repo, never of a mini itself.
- **Deliberate restrictions over silent gaps.** Where a mini's scope is
  narrower than its inspiration (e.g. `minicase` has no `.default`
  argument, `minitable` has no list-columns), the mini's own README
  documents the restriction explicitly rather than leaving it implicit.

### Common commands

| Task | Command |
|---|---|
| Run every mini's tests | `Rscript run_tests.R` (from repo root; requires `testthat`, `withr`) |
| Run one mini's tests | `testthat::test_dir("<mini>/tests/testthat")` from R |

### Vignettes and the minis site

Every mini's `README.md` is mandatory and renders as plain markdown on
GitHub with no build step -- that stays true regardless of anything
below. Separately, a mini **may** also have a `<mini>/vignette.qmd`:
an executed, worked-example page that gets rendered into a small
Quarto website (`_quarto.yml`/`index.qmd` at the repo root) and
published to GitHub Pages by `.github/workflows/site.yaml`.

- **Optional and additive.** Adding a mini never requires a vignette;
  see "Adding a new mini" below, which is unchanged. Retrofit vignettes
  onto existing minis independently, one at a time.
- **Complementary to the README, not a duplicate of it.** The README
  stays the terse reference (API table, scope notes, install
  instructions). The vignette is the executed narrative walkthrough --
  if the two disagree, the vignette's *executed* code is the one that's
  guaranteed to still be true; the README's prose is not automatically
  checked.
- **Sourcing convention.** A vignette sources its mini the same way
  tests do, but relative to the repo root (the project's
  `execute-dir: project` setting in `_quarto.yml` guarantees this
  resolves correctly regardless of which page triggered the render):
  ```r
  source(file.path("<mini>", "<mini>.R"))
  ```
- **Pretty URLs without renaming the source file.** `_quarto.yml` sets
  `format.html.output-file: index` project-wide, so every rendered
  `<mini>/vignette.qmd` produces `<mini>/index.html` and is reachable
  at `baseurl/<mini>/` -- while the source file keeps the
  self-documenting `vignette.qmd` name (as opposed to naming the source
  file itself `<mini>/index.qmd`, which would read ambiguously next to
  `<mini>/README.md`).
- **Site scope is explicit.** `_quarto.yml`'s `project.render` list
  (`index.qmd` plus `*/vignette.qmd`) is deliberately narrow -- Quarto
  website projects render every `.qmd`/`.md` file under the project
  root by default, which would otherwise pull in `AGENTS.md` and the
  `.agents/` files as site pages. Any new top-level `.qmd` intended for
  the site must be added to that list explicitly.
- **`index.qmd`** lists every mini, linking to the rendered vignette
  page when one exists and to the GitHub README otherwise. Keep both
  the root `README.md` table and `index.qmd`'s table in sync when
  adding a mini.
- **`_freeze/`** is Quarto's render cache and is committed (not
  gitignored) so that unchanged vignettes aren't re-executed on every
  render, and so `quarto render` doesn't require R for unchanged pages.
  Re-render (`quarto render`) after editing a `vignette.qmd` or its
  mini's `.R` file, and commit the resulting `_freeze/` changes
  alongside.
- Local preview: `quarto preview` from the repo root.
- **Theming.** `_quarto.yml`'s `format.html.theme` points at
  `paleblue.scss` (light) and `blackpink.scss` (dark), with
  `respect-user-color-scheme: true` so the site defaults to the
  visitor's OS preference and Quarto adds a manual toggle to the
  navbar. Both files are copied from djnavarro's other Quarto sites
  (e.g. `code.djnavarro.net`) to keep a consistent look across sites --
  edit them in place here if the minis site ever needs to diverge.

### Adding a new mini

1. Create `<name>/<name>.R`, `<name>/README.md`,
   `<name>/tests/testthat/test-<name>.R`, following the layout above.
2. Pick a short, concrete name evoking what the mini *does*, not the
   grammatical/abstract category it belongs to -- see the `minitrap`
   naming discussion in `.agents/HISTORY.md` for why `miniadverbs` was
   rejected.
3. Give every exported function a mini-specific prefix; give internal
   helpers a dot-prefixed version of the same prefix.
4. Header-comment the source file with: what it reimplements, what's
   deliberately excluded, and any deliberate fixes relative to the
   package/snippet it was adapted from.
5. Add a row to the table in the root `README.md` and to the table
   above, in this file.
6. Run `Rscript run_tests.R` before committing.

### Commit conventions

One commit per mini when adding a new one, named `Add <name>`, with a
body summarising what it reimplements and any deliberate fixes/bugs
found relative to the source material (see `git log` for examples).

---

## Assistant preferences

### Autonomy

- Naming a new mini, and deciding how source material should be split
  across minis, are judgment calls worth surfacing to the user (e.g.
  via enumerated options) before writing code -- see
  `.agents/HISTORY.md` for past examples of this.
- Implementation of an agreed-upon mini (source file, tests, README,
  root README update) can proceed directly without further check-ins.
- After writing or editing a mini, **run `Rscript run_tests.R`** before
  considering the work done.

### Dependencies

- Minis themselves must stay at zero runtime dependencies, always. If
  the material being ported isn't already dependency-free (as was the
  case with `minitable`), that's a sign real rework is needed, not just
  a copy-paste -- flag it and explain the rework rather than silently
  keeping a dependency.

### Sourcing material

- When adapting an existing internal helper (e.g. from `emaxnls`) or an
  external dependency-free package (e.g. poorman), verify the ported
  logic actually behaves as expected by executing it, not just by
  reading it -- several minis in this repo had real bugs (not just
  cosmetic differences from the original) surface only once tests were
  run.

### Commit messages

Freeform imperative mood ("Add x", "Fix y"), no conventional-commit
prefix required.

---

## Keeping this documentation current

This file (`AGENTS.md`) should stay a lean, current-state reference --
if a change makes something above inaccurate, update it in place rather
than appending a note about the change.

Two companion files in `.agents/` carry the parts that don't belong
here:

- **[.agents/HISTORY.md](.agents/HISTORY.md)** -- a condensed record of
  completed design decisions and their rationale (what was tried,
  rejected, and why), for context in future sessions. When you finish a
  piece of nontrivial design work, add an entry here rather than
  growing this file with "used to be X, now Y" narrative.
- **[.agents/PLAN.md](.agents/PLAN.md)** -- scoped-out future work and
  deferred/open items. When you finish something listed there, move its
  write-up into `HISTORY.md` and remove it from `PLAN.md` rather than
  marking it "done" in place.
