#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------
# Write a SIMULATED results.json so the dashboard can be exercised before
# election night. Output is flagged simulated = TRUE and the page shows a
# banner. Never run this on election night against the live site.
#
# Usage: Rscript R/simulate_results.R [stage]   stage in 0..1 (share of the
#        night elapsed; default 0.55). stage 0 = polls just closed.
# ---------------------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
stage <- if (length(args)) as.numeric(args[1]) else 0.55
suppressMessages({ source("R/packages.R"); source("R/utils.R") })
set.seed(2026)

races <- readr::read_csv("data/races.csv", show_col_types = FALSE,
                         col_types = readr::cols(.default = readr::col_character()))
manual <- readr::read_csv("data/manual_results.csv", show_col_types = FALSE,
                          col_types = readr::cols(.default = readr::col_character()))

sim_one <- function(race) {
  decided <- manual |> filter(race_id == race$race_id, !is.na(yes_votes))
  if (nrow(decided)) {
    return(tibble(yes_votes = parse_int(decided$yes_votes[1]), no_votes = parse_int(decided$no_votes[1]),
                  precincts_reporting = parse_int(decided$precincts_total[1]), precincts_total = parse_int(decided$precincts_total[1]),
                  ballots_cast = NA_integer_, registered_voters = NA_integer_, raw_contest = "certified result",
                  as_of = decided$as_of[1], source_url = decided$source_url[1], adapter = "manual",
                  note = "certified", status_override = "final"))
  }
  if (race$election_date != "2026-11-03") return(empty_result() |> mutate(status_override = NA_character_))
  # Poll-close offset: later-closing states have fewer precincts in at a given stage
  close_offset <- c(OH = 0, FL = 0, PA = 0, KS = 0.08, IL = 0.08, WI = 0.15, MI = 0.15, NV = 0.25, CA = 0.33)[race$state] %||% 0.1
  prog <- max(0, min(1, (stage - close_offset) / (1 - close_offset) * runif(1, 0.8, 1.3)))
  ptot <- sample(c(2:12, 15, 20, 30, 45), 1)
  prep <- round(ptot * prog)
  if (prep == 0) return(empty_result() |> mutate(status_override = NA_character_))
  turnout <- sample(600:9000, 1) * ptot / 10
  counted <- round(turnout * prep / ptot)
  # Restrict side tends to win locally; advisory and allow questions vary
  p_restrict <- rbeta(1, 6, 3.4)
  restrict <- rbinom(1, counted, p_restrict); allow <- counted - restrict
  yes <- if (race$yes_means == "restrict") restrict else allow
  no  <- counted - yes
  tibble(yes_votes = yes, no_votes = no, precincts_reporting = prep, precincts_total = ptot,
         ballots_cast = counted, registered_voters = round(turnout * 2.2), raw_contest = race$title,
         as_of = now_iso(), source_url = race$results_page_url, adapter = "simulated",
         note = "SIMULATED", status_override = NA_character_)
}

results <- purrr::map_dfr(seq_len(nrow(races)), function(i) {
  race <- as.list(races[i, ])
  res <- sim_one(race)
  d <- derive_fields(res, race)
  hist <- if (!is.na(res$yes_votes) && race$election_date == "2026-11-03") {
    n <- 6; f <- seq(0.15, 1, length.out = n)
    tibble(t = format(Sys.time() - rev(seq_len(n)) * 600, "%Y-%m-%dT%H:%M:%S%z"),
           yes = round(res$yes_votes * f * runif(n, 0.9, 1.1)), no = round(res$no_votes * f * runif(n, 0.9, 1.1)),
           rep = round(d$pct_reporting * f))
  } else tibble()
  bind_cols(tibble(race_id = race$race_id), res, d) |> mutate(fetch_ok = TRUE, fetch_error = NA_character_,
                                                               history = list(hist))
})

nov <- results |> inner_join(races |> select(race_id, election_date, scope, status_registry = status), by = "race_id") |>
  filter(election_date == "2026-11-03", scope == "direct", status_registry %in% c("on_ballot", "pending_litigation"))
wv <- nov |> filter(!is.na(total_votes), total_votes > 0)
summary <- list(measures_nov3 = nrow(nov), with_results = nrow(wv),
                restrict_leading = sum(wv$leader == "restrict"), allow_leading = sum(wv$leader == "allow"),
                tied = sum(wv$leader == "tie"),
                mean_restrict_pct = round(mean(wv$restrict_pct), 1), mean_allow_pct = round(mean(wv$allow_pct), 1),
                pooled_restrict_pct = round(100 * sum(wv$restrict_votes) / sum(wv$total_votes), 1),
                total_votes_counted = sum(wv$total_votes), fetch_failures = 0L)

out <- list(generated_at = now_iso(), election_date = "2026-11-03", simulated = TRUE, summary = summary, races = results)
path <- "site/data/results.json"
jsonlite::write_json(out, path, auto_unbox = TRUE, na = "null", pretty = TRUE, digits = NA)
write_results_csv(results |> select(-history), races)
cli::cli_alert_success("wrote SIMULATED {path} (and results.csv) at stage {stage}")
