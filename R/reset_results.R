#!/usr/bin/env Rscript
# Write an empty, pre-election results.json (no votes anywhere). Run this
# before election night to clear any simulated data from the live site.
suppressMessages({ source("R/packages.R"); source("R/utils.R") })
races <- readr::read_csv("data/races.csv", show_col_types = FALSE,
                         col_types = readr::cols(.default = readr::col_character()))
if (file.exists("data/history.csv")) file.remove("data/history.csv")
system2("Rscript", "R/fetch_results.R")
cli::cli_alert_success("results.json rebuilt from live sources / manual entries only")
