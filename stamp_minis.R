# stamp_minis.R
#
# Maintains a "## stamp: <hash> (<date>)" comment on line 2 of every
# `<mini>/<mini>.R` file, immediately below the `## <mini>.R` title
# line (every mini uses `##` for this top-of-file title/prose block,
# switching to plain `#` once code and section comments start). The
# hash is a content fingerprint of the file (excluding the stamp line
# itself, so the stamp doesn't hash itself); the date is only updated
# when the hash changes, so it reflects the last time the mini's
# behaviour actually changed rather than the last time this script
# happened to run.
#
# This lets a consumer who has vendored (copied) a mini's `.R` file
# compare its stamp against the current one in this repo to see, at a
# glance, whether the file they copied has since been updated -- no
# git access required on the consumer's side, since the stamp travels
# with the file itself.
#
# Usage:
#   Rscript stamp_minis.R          # update stamps in place, exit 0
#   Rscript stamp_minis.R --check  # don't write; exit 1 if any stamp
#                                   # is out of date (used in CI)

stamp_marker <- "##"
# Matches either '#' or '##' so a one-off migration (e.g. an earlier
# version of this script that used a different marker) is recognised
# and replaced rather than duplicated.
stamp_capture_pattern <- "^#{1,2} stamp: ([0-9a-f]{8}) \\(([0-9]{4}-[0-9]{2}-[0-9]{2})\\)$"

find_mini_files <- function() {
  dirs <- list.dirs(".", recursive = FALSE, full.names = FALSE)
  files <- file.path(dirs, paste0(dirs, ".R"))
  files[file.exists(files)]
}

content_hash <- function(lines_without_stamp) {
  tmp <- tempfile()
  writeLines(lines_without_stamp, tmp)
  hash <- unname(tools::md5sum(tmp))
  file.remove(tmp)
  substr(hash, 1, 8)
}

# Returns list(lines = <original lines minus any existing stamp line>,
# old_line = <that line verbatim, or NA>, old_hash = <8-char hash from
# it, or NA>, old_date = <date from it, or NA>). Keeping the verbatim
# line (as opposed to just its parsed parts) lets update_file() detect
# a marker-only change (e.g. migrating '#' to '##') even when the hash
# and date are unchanged.
strip_stamp <- function(lines) {
  is_stamp <- grepl(stamp_capture_pattern, lines)
  if (!any(is_stamp)) {
    return(list(lines = lines, old_line = NA_character_, old_hash = NA_character_, old_date = NA_character_))
  }
  stamp_line <- lines[which(is_stamp)[1]]
  m <- regmatches_first(stamp_line, stamp_capture_pattern)
  list(lines = lines[!is_stamp], old_line = stamp_line, old_hash = m[2], old_date = m[3])
}

regmatches_first <- function(x, pattern) {
  regmatches(x, regexec(pattern, x))[[1]]
}

# Inserts `stamp_line` as line 2, right after the `## <mini>.R` title
# line on line 1.
insert_stamp <- function(lines, stamp_line) {
  append(lines, stamp_line, after = 1)
}

update_file <- function(path, check_only) {
  original <- readLines(path)
  stripped <- strip_stamp(original)
  hash <- content_hash(stripped$lines)

  date <- if (identical(stripped$old_hash, hash)) stripped$old_date else as.character(Sys.Date())
  new_stamp <- sprintf("%s stamp: %s (%s)", stamp_marker, hash, date)

  up_to_date <- identical(stripped$old_line, new_stamp)

  if (!up_to_date && !check_only) {
    writeLines(insert_stamp(stripped$lines, new_stamp), path)
  }
  up_to_date
}

main <- function() {
  check_only <- "--check" %in% commandArgs(trailingOnly = TRUE)
  files <- find_mini_files()
  results <- vapply(files, update_file, logical(1), check_only = check_only)

  stale <- files[!results]
  if (length(stale) > 0) {
    action <- if (check_only) "would update" else "updated"
    message(sprintf("stamp_minis.R %s: %s", action, paste(stale, collapse = ", ")))
  }

  if (check_only && length(stale) > 0) {
    message("Run `Rscript stamp_minis.R` locally and commit the result.")
    quit(status = 1)
  }
}

main()
