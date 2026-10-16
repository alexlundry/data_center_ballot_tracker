#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------
# Fetch live results for every race and write site/data/results.json
# ---------------------------------------------------------------------------
# Usage:  Rscript R/fetch_results.R            # one pass
#         Rscript R/fetch_results.R --dry-run  # fetch, print, do not write
#
# Order of precedence for each race:
#   1. a manual row with override = TRUE            (data/manual_results.csv
#      or the Google Sheet listed in data/sources.csv as adapter = sheet)
#   2. automated sources in data/sources.csv, by priority, first success wins
#   3. a manual row without override
#   4. the previous results.json value, flagged stale
#
# Every pass appends one row per race to data/history.csv, which feeds the
# sparklines and the "as it happened" timeline on the dashboard.

args <- commandArgs(trailingOnly = TRUE)
DRY_RUN <- "--dry-run" %in% args

suppressMessages({
  source("R/packages.R")
  source("R/utils.R")
  for (f in list.files("R/adapters", pattern = "\\.R$", full.names = TRUE)) source(f)
})

ELECTION_DATE <- "2026-11-03"
RESULTS_PATH <- "site/data/results.json"
HISTORY_PATH <- "data/history.csv"

races <- readr::read_csv("data/races.csv", show_col_types = FALSE,
                         col_types = readr::cols(.default = readr::col_character())) |>
  mutate(across(everything(), ~ na_if(str_trim(.x), "")))
sources <- readr::read_csv("data/sources.csv", show_col_types = FALSE,
                           col_types = readr::cols(.default = readr::col_character())) |>
  mutate(across(everything(), ~ na_if(str_trim(.x), ""))) |>
  mutate(priority = as.integer(coalesce(priority, "9")),
         enabled = tolower(coalesce(enabled, "true")) %in% c("true", "t", "yes", "y", "1")) |>
  filter(enabled) |>
  arrange(race_id, priority)

ctx <- list(
  manual_tbl = read_manual_table("data/manual_results.csv"),
  ohio_cache = new.env()
)

# Pull any Google Sheet mirrors once and merge them into the manual table
sheet_srcs <- sources |> filter(adapter == "sheet") |> distinct(api_url, results_url)
for (i in seq_len(nrow(sheet_srcs))) {
  url <- sheet_srcs$api_url[i] %||% sheet_srcs$results_url[i]
  tbl <- tryCatch(read_sheet_table(url), error = function(e) {
    cli::cli_alert_warning("sheet {url} failed: {conditionMessage(e)}"); NULL
  })
  if (!is.null(tbl) && nrow(tbl) > 0) {
    ctx$manual_tbl <- bind_rows(tbl, ctx$manual_tbl) |>
      arrange(race_id, desc(coalesce(as_of, ""))) |> distinct(race_id, .keep_all = TRUE)
  }
}

prev <- if (file.exists(RESULTS_PATH)) {
  tryCatch(jsonlite::fromJSON(RESULTS_PATH, simplifyVector = TRUE)$races, error = function(e) NULL)
} else NULL
prev_row <- function(id) {
  if (is.null(prev) || !("race_id" %in% names(prev))) return(NULL)
  r <- prev[prev$race_id == id, , drop = FALSE]
  if (nrow(r) == 0) NULL else as_tibble(r)
}

fetch_one <- function(race) {
  id <- race$race_id
  manual <- adapter_manual(list(race_id = id, results_url = race$results_page_url), ctx$manual_tbl)
  if (!is.null(manual) && isTRUE(manual$override)) {
    log_msg(id, ": manual override")
    return(manual |> mutate(fetch_ok = TRUE, fetch_error = NA_character_))
  }
  srcs <- sources |> filter(race_id == id, adapter != "sheet")
  errors <- character()
  for (i in seq_len(nrow(srcs))) {
    src <- as.list(srcs[i, ])
    res <- run_adapter(src, ctx)
    if (inherits(res, "adapter_error")) { errors <- c(errors, paste0(src$adapter, ": ", res$error)); next }
    if (!is.null(res) && nrow(res) == 1) {
      log_msg(id, ": ok via ", src$adapter, " (", res$yes_votes, " yes / ", res$no_votes, " no)")
      if (!"status_override" %in% names(res)) res$status_override <- NA_character_
      return(res |> mutate(fetch_ok = TRUE, fetch_error = NA_character_))
    }
    errors <- c(errors, paste0(src$adapter, ": no match"))
  }
  if (!is.null(manual)) {
    log_msg(id, ": manual entry (no automated feed)")
    return(manual |> mutate(fetch_ok = TRUE, fetch_error = if (length(errors)) paste(errors, collapse = " | ") else NA_character_))
  }
  pr <- prev_row(id)
  if (!is.null(pr) && !is.na(pr$yes_votes %||% NA)) {
    log_msg(id, ": STALE, keeping previous values")
    return(tibble(
      yes_votes = as.integer(pr$yes_votes), no_votes = as.integer(pr$no_votes),
      precincts_reporting = as.integer(pr$precincts_reporting), precincts_total = as.integer(pr$precincts_total),
      ballots_cast = as.integer(pr$ballots_cast), registered_voters = as.integer(pr$registered_voters),
      raw_contest = pr$raw_contest, as_of = pr$as_of, source_url = pr$source_url,
      adapter = pr$adapter, note = "stale: last fetch failed", status_override = NA_character_,
      fetch_ok = FALSE, fetch_error = paste(errors, collapse = " | ")
    ))
  }
  if (nrow(srcs) == 0 && is.null(manual)) log_msg(id, ": no sources configured")
  empty_result() |> mutate(status_override = NA_character_, fetch_ok = nrow(srcs) == 0,
                           fetch_error = if (length(errors)) paste(errors, collapse = " | ") else NA_character_)
}

results <- purrr::map_dfr(seq_len(nrow(races)), function(i) {
  race <- as.list(races[i, ])
  res <- fetch_one(race)
  d <- derive_fields(res, race)
  bind_cols(tibble(race_id = race$race_id), res |> select(-any_of("override")), d)
})

# ---- history -----------------------------------------------------------------
prev_counts <- if (!is.null(prev) && all(c("race_id", "yes_votes", "no_votes", "precincts_reporting") %in% names(prev))) {
  as_tibble(prev) |> transmute(race_id, p_yes = as.integer(yes_votes), p_no = as.integer(no_votes),
                               p_prec = as.integer(precincts_reporting))
} else tibble(race_id = character(), p_yes = integer(), p_no = integer(), p_prec = integer())
hist_rows <- results |>
  filter(!is.na(total_votes)) |>
  left_join(prev_counts, by = "race_id") |>
  # log a row only when the count moved (or the race is new), so history.csv
  # and the dashboard's update log reflect real changes, not every poll
  filter(is.na(p_yes) | p_yes != yes_votes | p_no != no_votes |
           coalesce(p_prec != precincts_reporting, FALSE)) |>
  transmute(race_id, fetched_at = now_iso(), yes_votes, no_votes, total_votes,
            precincts_reporting, precincts_total, pct_reporting, adapter)
if (!DRY_RUN && nrow(hist_rows) > 0) {
  readr::write_csv(hist_rows, HISTORY_PATH, append = file.exists(HISTORY_PATH))
}
history <- if (file.exists(HISTORY_PATH)) {
  readr::read_csv(HISTORY_PATH, show_col_types = FALSE) |>
    group_by(race_id) |>
    # keep only rows where the count changed, so sparklines show real movement
    arrange(fetched_at, .by_group = TRUE) |>
    filter(is.na(lag(total_votes)) | total_votes != lag(total_votes) | row_number() == n()) |>
    slice_tail(n = 60) |>
    summarise(history = list(transmute(pick(everything()), t = fetched_at, yes = yes_votes, no = no_votes,
                                       rep = pct_reporting)), .groups = "drop")
} else tibble(race_id = character(), history = list())

results <- results |> left_join(history, by = "race_id")
results$history <- purrr::map(results$history, ~ if (is.null(.x)) list() else .x)

# ---- summary -------------------------------------------------------------------
nov <- results |> inner_join(races |> select(race_id, election_date, yes_means, scope, status_registry = status), by = "race_id") |>
  filter(election_date == ELECTION_DATE, scope == "direct", status_registry %in% c("on_ballot", "pending_litigation"))
with_votes <- nov |> filter(!is.na(total_votes), total_votes > 0)
summary <- list(
  measures_nov3 = nrow(nov),
  with_results = nrow(with_votes),
  restrict_leading = sum(with_votes$leader == "restrict"),
  allow_leading = sum(with_votes$leader == "allow"),
  tied = sum(with_votes$leader == "tie"),
  mean_restrict_pct = if (nrow(with_votes)) round(mean(with_votes$restrict_pct), 1) else NA,
  mean_allow_pct = if (nrow(with_votes)) round(mean(with_votes$allow_pct), 1) else NA,
  pooled_restrict_pct = if (nrow(with_votes)) round(100 * sum(with_votes$restrict_votes) / sum(with_votes$total_votes), 1) else NA,
  total_votes_counted = sum(with_votes$total_votes),
  fetch_failures = sum(!results$fetch_ok)
)

out <- list(
  generated_at = now_iso(),
  election_date = ELECTION_DATE,
  simulated = FALSE,
  summary = summary,
  races = results
)

if (DRY_RUN) {
  print(results |> select(race_id, yes_votes, no_votes, pct_reporting, leader, status, adapter, fetch_ok))
} else {
  jsonlite::write_json(out, RESULTS_PATH, auto_unbox = TRUE, na = "null", pretty = TRUE, digits = NA)
  write_results_csv(results, races)
  log_msg("wrote ", RESULTS_PATH, " and site/data/results.csv (", nrow(results), " races, ", summary$with_results, " with results)")
  source("R/write_sheet.R"); push_results_to_sheet()
}
