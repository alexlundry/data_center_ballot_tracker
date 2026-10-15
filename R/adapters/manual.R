# ---------------------------------------------------------------------------
# Adapter: manual entry (data/manual_results.csv) and Google Sheet mirror
# ---------------------------------------------------------------------------
# This is the election-night backstop. Any race whose automated feed is not
# working can be keyed in by hand, either in data/manual_results.csv or in a
# Google Sheet published to the web as CSV (File > Share > Publish to web).
# A manual row wins over automated feeds when its `override` column is TRUE,
# or when no automated source returned a result.

read_manual_table <- function(path = "data/manual_results.csv") {
  if (!file.exists(path)) return(empty_manual_table())
  readr::read_csv(path, show_col_types = FALSE,
                  col_types = readr::cols(.default = readr::col_character())) |>
    clean_manual_table()
}

read_sheet_table <- function(url) {
  readr::read_csv(url, show_col_types = FALSE,
                  col_types = readr::cols(.default = readr::col_character())) |>
    clean_manual_table()
}

empty_manual_table <- function() {
  tibble(race_id = character(), yes_votes = integer(), no_votes = integer(),
         precincts_reporting = integer(), precincts_total = integer(),
         ballots_cast = integer(), registered_voters = integer(),
         status = character(), as_of = character(), source_url = character(),
         override = logical(), entered_by = character(), note = character())
}

clean_manual_table <- function(tbl) {
  needed <- c("race_id", "yes_votes", "no_votes", "precincts_reporting", "precincts_total",
              "ballots_cast", "registered_voters", "status", "as_of", "source_url",
              "override", "entered_by", "note")
  for (col in setdiff(needed, names(tbl))) tbl[[col]] <- NA_character_
  tbl |>
    mutate(across(everything(), ~ na_if(str_trim(.x), ""))) |>
    filter(!is.na(race_id)) |>
    mutate(
      yes_votes = parse_int(yes_votes), no_votes = parse_int(no_votes),
      precincts_reporting = parse_int(precincts_reporting),
      precincts_total = parse_int(precincts_total),
      ballots_cast = parse_int(ballots_cast %||% NA),
      registered_voters = parse_int(registered_voters %||% NA),
      override = tolower(coalesce(override, "false")) %in% c("true", "t", "yes", "y", "1")
    ) |>
    # keep the most recent row per race if the sheet has a running log
    arrange(race_id, desc(coalesce(as_of, ""))) |>
    distinct(race_id, .keep_all = TRUE)
}

# Returns a standard result row for one race, or NULL.
adapter_manual <- function(src, manual_tbl) {
  row <- manual_tbl |> filter(race_id == src$race_id)
  if (nrow(row) == 0) return(NULL)
  if (is.na(row$yes_votes) && is.na(row$no_votes)) return(NULL)
  tibble(
    yes_votes = row$yes_votes, no_votes = row$no_votes,
    precincts_reporting = row$precincts_reporting, precincts_total = row$precincts_total,
    ballots_cast = row$ballots_cast, registered_voters = row$registered_voters,
    raw_contest = "manual entry",
    as_of = row$as_of %||% now_iso(),
    source_url = row$source_url %||% src$results_url %||% NA_character_,
    adapter = "manual",
    note = paste0("entered by ", row$entered_by %||% "unknown",
                  if (!is.na(row$note %||% NA)) paste0(": ", row$note) else ""),
    status_override = row$status %||% NA_character_,
    override = row$override
  )
}

adapter_sheet <- function(src) {
  url <- src$api_url %||% src$results_url
  tbl <- read_sheet_table(url)
  adapter_manual(src, tbl)
}
