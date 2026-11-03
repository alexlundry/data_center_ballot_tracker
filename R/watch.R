#!/usr/bin/env Rscript
# Election-night loop for the Mac: fetch, commit and push every N seconds.
# It is the main loop (RUNBOOK.md): only it reads the drop folder and Clarity.
# Ctrl-C to stop.
#   Rscript R/watch.R 120
args <- commandArgs(trailingOnly = TRUE)
every <- if (length(args)) as.numeric(args[1]) else 120
FILES <- "site/data/results.json site/data/results.csv data/history.csv"

# results.json carries a generated_at that changes every pass; like the
# workflow's jq guard, commit only when something else in it changed
counts_changed <- function() {
  old <- tryCatch(jsonlite::parse_json(paste(system("git show HEAD:site/data/results.json", intern = TRUE), collapse = "\n")),
                  error = function(e) NULL)
  new <- jsonlite::read_json("site/data/results.json")
  old$generated_at <- NULL; new$generated_at <- NULL
  !identical(old, new)
}

repeat {
  t0 <- Sys.time()
  # Start from the latest remote: the Actions bot commits results too. A local
  # commit that did not get pushed is replayed on top, and on a clash its
  # numbers win (-X theirs is "ours" when rebasing).
  system("git pull --rebase --autostash -X theirs -q || git rebase --abort 2>/dev/null")
  status <- system2("Rscript", "R/fetch_results.R")
  if (status == 0) {
    if (counts_changed()) {
      system(paste("git add", FILES, "&& git commit -q -m \"results $(date -u +%Y-%m-%dT%H:%MZ)\""))
    } else {
      system(paste("git checkout --", FILES))
    }
  }
  # Push whatever is not on GitHub yet, including a commit an earlier push missed
  system("test -z \"$(git log @{u}..HEAD --oneline)\" || git push -q")
  wait <- max(5, every - as.numeric(difftime(Sys.time(), t0, units = "secs")))
  cat(format(Sys.time(), "%H:%M:%S"), "sleeping", round(wait), "s\n")
  Sys.sleep(wait)
}
