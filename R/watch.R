#!/usr/bin/env Rscript
# Election-night loop for a laptop: fetch, rebuild, commit and push every
# N seconds. Use this if GitHub's cron schedule is lagging (it often does on
# busy nights). Ctrl-C to stop.
#   Rscript R/watch.R 120
args <- commandArgs(trailingOnly = TRUE)
every <- if (length(args)) as.numeric(args[1]) else 120
repeat {
  t0 <- Sys.time()
  status <- system2("Rscript", "R/fetch_results.R")
  if (status == 0) {
    system("git add site/data/results.json data/history.csv && git diff --cached --quiet || git commit -q -m \"results $(date -u +%Y-%m-%dT%H:%MZ)\" && git push -q")
  }
  wait <- max(5, every - as.numeric(difftime(Sys.time(), t0, units = "secs")))
  cat(format(Sys.time(), "%H:%M:%S"), "sleeping", round(wait), "s\n")
  Sys.sleep(wait)
}
