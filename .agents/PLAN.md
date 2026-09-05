# minis development plan

This document tracks scoped-out future work for the minis repo --
things that have been discussed but not done, or deliberately deferred.
It is not a changelog: once an item here is completed, its write-up
should move to [.agents/HISTORY.md](HISTORY.md) and be removed from
this file rather than marked "done" in place.

## Candidate future minis

Other `emaxnls` internal helpers that haven't been reviewed/ported yet:

- **Conditions/assertions** (`utils-conditions.R`: `.assert()`,
  `.abort()`, `.warn()`, `.inform()`) -- currently reimplemented as a
  simplified inline assert per-mini (e.g. `minimap`'s
  `.mmap_assert()`), rather than extracted as their own mini; worth
  revisiting if a richer condition-signalling mini (with custom
  condition classes, base R only) turns out to be broadly useful.
- **mvtnorm wrappers** (`utils-mvtnorm.R`: `.rmvnorm()`, `.qmvnorm()`)
  -- not yet reviewed for zero-dependency feasibility; `mvtnorm` itself
  has no pure-base-R equivalent, so this would need to be a genuine
  reimplementation (at least for the specific distributions/dimensions
  actually needed), not just a rename.
- **`possibly()`-style adverb** (default value in place of an error) --
  explicitly deferred out of `minitrap`'s scope when it was built; would
  be its own mini if ever added, not folded into `minitrap`.

## Confirm CI passes on GitHub's runners

The `.github/workflows/test.yaml` workflow was added and the repo
pushed, but a green run on GitHub's actual runners (as opposed to local
`Rscript run_tests.R`) hasn't been confirmed yet.

## Discoverability

Consider adding GitHub repo topics (e.g. `r`, `zero-dependency`,
`vendoring`) for discoverability, and possibly a short listing page if
the mini count grows significantly.
