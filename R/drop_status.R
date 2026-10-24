#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------
# Election-night checklist for the drop folder (see R/adapters/drop_folder.R)
# ---------------------------------------------------------------------------
# Usage:  Rscript R/drop_status.R      (or: make drop)
#
# One line per county page on a blocked host: the page to open in your
# browser, the races it feeds, and the file in the drop folder each race is
# reading now (with its age). "MISSING" means nothing in the folder matches
# that race's contest_pattern yet.

suppressMessages({
  source("R/packages.R")
  source("R/utils.R")
  for (f in list.files("R/adapters", pattern = "\\.R$", full.names = TRUE)) source(f)
})

sources <- readr::read_csv("data/sources.csv", show_col_types = FALSE,
                           col_types = readr::cols(.default = readr::col_character())) |>
  mutate(across(everything(), ~ na_if(str_trim(.x), ""))) |>
  filter(tolower(coalesce(enabled, "true")) %in% c("true", "t", "yes", "y", "1"))
blocked <- sources[vapply(seq_len(nrow(sources)), function(i) needs_drop(as.list(sources[i, ])), logical(1)), ]

dir <- drop_dir()
cli::cli_h1("Drop folder: {dir}")
if (!dir.exists(dir)) cli::cli_alert_danger("folder does not exist; create it and point your browser's downloads there")
since <- drop_since()
if (is.finite(since)) cli::cli_alert_info("reading files modified since {format(since, '%b %d %H:%M %Z')}")

status <- blocked |>
  mutate(file = purrr::map_chr(seq_len(n()), function(i) {
    if (!dir.exists(dir)) return(NA_character_)
    find_drop_file(as.list(blocked[i, ]), dir) %||% NA_character_
  }),
  age_min = round(as.numeric(difftime(Sys.time(), file.info(file)$mtime, units = "mins"))))

for (page in unique(status$results_url)) {
  rows <- status |> filter(results_url == page)
  # ENR urls carry an ELECTION_ID placeholder, and the ENR folder itself answers
  # "Forbidden"; say how to reach the election's page instead
  if (grepl("ELECTION_ID", page)) {
    cli::cli_h2(paste0(sub("ELECTION_ID.*$", "", page), "<id>/en/Index_<id>.html"))
    cli::cli_text("(the folder alone says Forbidden; follow the county board's results link, or set the id in sources.csv)")
  } else cli::cli_h2(page)
  for (i in seq_len(nrow(rows))) {
    r <- rows[i, ]
    if (is.na(r$file)) cli::cli_alert_danger("{r$race_id}: MISSING ({r$adapter}, looking for /{r$contest_pattern}/)")
    else cli::cli_alert_success("{r$race_id}: {basename(r$file)}, {r$age_min} min old")
  }
}
cli::cli_text("")
cli::cli_alert_info("{sum(!is.na(status$file))} of {nrow(status)} blocked sources have a file")
