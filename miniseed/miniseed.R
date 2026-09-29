## miniseed.R -------------------------------------------------------------
## stamp: c599d527 (2026-09-29)
##
## A minimal, dependency-free reimplementation of the RNG-seed-management
## slice of {withr}: `with_seed()`, `with_preserve_seed()`, `local_seed()`,
## and `local_preserve_seed()`. `minicuts` already needed a private
## version of `with_seed()`; `miniseed` generalizes that into its own
## mini so other minis/packages can take the same shortcut instead of
## depending on withr for just this.
##
## Design notes:
## - `.seed_with_seed()`/`.seed_with_preserve_seed()` wrap a block of code,
##   restoring the prior RNG state (via base R's `.Random.seed`) on exit
##   regardless of how the block exits (normal return, error, or an
##   early `return()` inside the block). They rely on ordinary R
##   promise semantics -- `code` is passed in unevaluated and only
##   forced (evaluated in the caller's own frame) after the seed has
##   been set and the restore has been scheduled with `on.exit()` --
##   rather than the `substitute()`/`eval()` dance withr itself uses.
## - `.seed_local_seed()`/`.seed_local_preserve_seed()` are the
##   deferred-cleanup variants meant to be called directly inside a
##   function body (no code block to wrap): they schedule the restore
##   to run when *the caller's* frame exits, not their own. This needs
##   the same trick withr's internal `defer()` uses -- build a call
##   whose head is an actual closure object (not a symbol), so that
##   `on.exit()`, registered against the caller's frame via `envir =`,
##   can invoke it without any name lookup in that frame; the closure
##   still resolves `old_state` lexically, from `local_seed()`'s own
##   execution environment.
## - `.rng_kind`/`.rng_normal_kind`/`.rng_sample_kind` are passed straight
##   through to `set.seed()`, matching withr's arguments of the same
##   name (minus the leading dot, since these functions have no `...`
##   to collide with). Restoring the prior `.Random.seed` afterwards
##   restores the prior RNG kind too, since the kind is encoded in its
##   first element -- no separate `RNGkind()` bookkeeping is needed.
## - All functions are dot-prefixed with the tag `.seed_` -- there's no
##   separate exported-vs-internal naming split, since every function
##   here is meant to be treated as an implementation detail once
##   copied into a consuming package.
##
## Usage:
##   source("miniseed.R")
##
##   .seed_with_seed(42, runif(3))       # reproducible, ambient RNG stream untouched afterwards
##   .seed_with_preserve_seed({          # runs as-is, but restores the RNG state on exit
##     set.seed(42)
##     runif(3)
##   })
##
##   my_fn <- function() {
##     .seed_local_seed(42)              # restores the RNG state when my_fn() returns
##     runif(3)
##   }
##
## License: MIT (see LICENSE at the root of the minis repo). This file
## contains no code copied from {withr}, only equivalent logic.

# Snapshots the current RNG state (`NULL` if `.Random.seed` doesn't
# exist yet, i.e. the RNG has never been touched this session).
#' @noRd
.seed_get_state <- function() {
  if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
    get(".Random.seed", envir = globalenv())
  } else {
    NULL
  }
}

# Restores a snapshot taken by `.seed_get_state()`. A `NULL` snapshot
# removes `.Random.seed` entirely, putting the RNG back into its
# "never touched" state rather than leaving behind a state introduced
# only while the seed was set.
#' @noRd
.seed_set_state <- function(state) {
  if (is.null(state)) {
    if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
      rm(".Random.seed", envir = globalenv())
    }
  } else {
    assign(".Random.seed", state, envir = globalenv())
  }
  invisible(NULL)
}

# Schedules `fn()` (a zero-argument closure, not an unevaluated
# expression -- unlike withr's own `defer()`) to run when `envir`
# exits, rather than when `.seed_defer()`'s own frame exits. This is
# what lets `.seed_local_seed()`/`.seed_local_preserve_seed()` register
# their restore against their *caller's* frame.
#
# Two things are load-bearing here, both needed together:
#  - `as.call(list(fn))` builds the call `fn()` with `fn` embedded as
#    the actual closure object, not a symbol. So when that call is
#    later evaluated inside `envir`, it doesn't need `fn` to be bound
#    there by name -- `fn` still resolves whatever it needs (e.g. a
#    saved RNG state) via ordinary lexical scoping back to wherever it
#    was defined (`.seed_local_seed()`'s own execution environment).
#  - Routing the call to `on.exit()` through `do.call(..., envir =
#    envir)`, instead of calling `on.exit()` directly, does two things
#    at once: it makes the registration apply to `envir`'s frame
#    rather than the current one, *and* it hands `on.exit()` the
#    already-built call object as a plain value. That second part
#    matters because `on.exit()` never evaluates its own argument up
#    front -- it stores whatever expression it's given, unevaluated,
#    to run at exit. Calling `on.exit(as.call(list(fn)), ...)` directly
#    would store the literal expression `as.call(list(fn))`, which
#    would only *build* a call at exit time and then discard it,
#    without ever invoking `fn()`.
#' @noRd
.seed_defer <- function(fn, envir) {
  do.call(on.exit, list(as.call(list(fn)), add = TRUE), envir = envir)
}

#' Run code with the RNG seeded, then restore the prior RNG state
#'
#' Sets the RNG seed, evaluates `code`, and restores the RNG state as
#' it was found -- so calling `.seed_with_seed()` reproducibly is safe
#' without disturbing the ambient RNG stream for whatever runs next.
#'
#' @param seed Single integer used to seed the RNG.
#' @param code An expression to evaluate under the seeded RNG. Only
#'   evaluated once, in the caller's own environment, after the seed
#'   has been set.
#' @param rng_kind,rng_normal_kind,rng_sample_kind Passed straight
#'   through to [set.seed()]'s `kind`/`normal.kind`/`sample.kind`
#'   arguments. `NULL` (the default for all three) leaves the
#'   corresponding generator unchanged.
#'
#' @returns The value of `code`.
#'
#' @examples
#' .seed_with_seed(42, runif(3))
#' identical(.seed_with_seed(42, runif(3)), .seed_with_seed(42, runif(3)))
#'
#' @export
.seed_with_seed <- function(seed, code,
                             rng_kind = NULL, rng_normal_kind = NULL,
                             rng_sample_kind = NULL) {
  old_state <- .seed_get_state()
  on.exit(.seed_set_state(old_state))
  set.seed(seed, kind = rng_kind, normal.kind = rng_normal_kind,
           sample.kind = rng_sample_kind)
  code
}

#' Run code, restoring the prior RNG state afterwards
#'
#' Like [.seed_with_seed()], but doesn't itself call [set.seed()] --
#' useful when `code` sets its own seed (or draws from the ambient
#' stream) and you just want to guarantee the RNG is left as it was
#' found once `code` finishes.
#'
#' @param code An expression to evaluate. Only evaluated once, in the
#'   caller's own environment.
#'
#' @returns The value of `code`.
#'
#' @examples
#' .seed_with_preserve_seed({
#'   set.seed(42)
#'   runif(3)
#' })
#'
#' @export
.seed_with_preserve_seed <- function(code) {
  old_state <- .seed_get_state()
  on.exit(.seed_set_state(old_state))
  code
}

#' Seed the RNG for the rest of the calling function
#'
#' Sets the RNG seed immediately, and schedules the prior RNG state to
#' be restored when `envir` exits -- by default, when the function
#' that called `.seed_local_seed()` returns. Meant to be called
#' directly inside a function body (no code block to wrap), unlike
#' [.seed_with_seed()].
#'
#' @param seed Single integer used to seed the RNG.
#' @param rng_kind,rng_normal_kind,rng_sample_kind As in
#'   [.seed_with_seed()].
#' @param envir Environment whose exit triggers the restore. Defaults
#'   to the caller of `.seed_local_seed()`, which is what you want when
#'   calling it directly inside the function you'd like reset.
#'
#' @returns The prior RNG state (invisibly), as a snapshot compatible
#'   with the internal `.seed_set_state()` helper -- not meant to be
#'   inspected directly, only there in case a caller wants to restore
#'   it manually.
#'
#' @examples
#' f <- function() {
#'   .seed_local_seed(42)
#'   runif(3)
#' }
#' identical(f(), f())
#'
#' @export
.seed_local_seed <- function(seed,
                              rng_kind = NULL, rng_normal_kind = NULL,
                              rng_sample_kind = NULL,
                              envir = parent.frame()) {
  old_state <- .seed_get_state()
  restore <- function() .seed_set_state(old_state)
  .seed_defer(restore, envir)
  set.seed(seed, kind = rng_kind, normal.kind = rng_normal_kind,
           sample.kind = rng_sample_kind)
  invisible(old_state)
}

#' Preserve the RNG state for the rest of the calling function
#'
#' Like [.seed_local_seed()], but doesn't itself call [set.seed()] --
#' schedules the restore without touching the current RNG state first.
#'
#' @param envir Environment whose exit triggers the restore. Defaults
#'   to the caller of `.seed_local_preserve_seed()`.
#'
#' @returns The prior RNG state (invisibly).
#'
#' @examples
#' f <- function() {
#'   .seed_local_preserve_seed()
#'   set.seed(42)
#'   runif(3)
#' }
#' identical(f(), f())
#'
#' @export
.seed_local_preserve_seed <- function(envir = parent.frame()) {
  old_state <- .seed_get_state()
  restore <- function() .seed_set_state(old_state)
  .seed_defer(restore, envir)
  invisible(old_state)
}
