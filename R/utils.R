# ---------------------------------------------------------------------------
# Shared helpers for the data center ballot tracker pipeline
# ---------------------------------------------------------------------------

TRACKER_TZ <- "America/New_York"
USER_AGENT <- "RedbudDataCenterTracker/1.0 (+https://www.redbud.consulting)"

now_iso <- function(tz = TRACKER_TZ) now_iso_at(Sys.time(), tz)

now_iso_at <- function(time, tz = TRACKER_TZ) {
  format(lubridate::with_tz(time, tz), "%Y-%m-%dT%H:%M:%S%z")
}

log_msg <- function(...) {
  cat(format(Sys.time(), "%H:%M:%S"), paste0(...), "\n", sep = " ")
}

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || all(is.na(a))) b else a

# Default regexes for the two sides of a yes/no question. Override per source
# with yes_pattern / no_pattern in data/sources.csv when a county labels the
# choices differently ("For the Ordinance", "Shall be approved", etc.).
YES_RX <- "^\\s*(yes|for|approve|in favor|for the|shall be approved|favor)"
NO_RX  <- "^\\s*(no|against|reject|disapprove|opposed|shall not be approved)"

# ---- HTTP ------------------------------------------------------------------

base_request <- function(url, timeout = 25, tries = 3) {
  httr2::request(url) |>
    httr2::req_user_agent(USER_AGENT) |>
    httr2::req_timeout(timeout) |>
    httr2::req_retry(max_tries = tries, backoff = ~ 2)
}

fetch_text <- function(url, ...) {
  base_request(url, ...) |> httr2::req_perform() |> httr2::resp_body_string()
}

fetch_bytes <- function(url, ...) {
  base_request(url, ...) |> httr2::req_perform() |> httr2::resp_body_raw()
}

fetch_json <- function(url, ...) {
  jsonlite::fromJSON(fetch_text(url, ...), simplifyVector = FALSE)
}

# Download a url to a temp file and return the path.
fetch_file <- function(url, ext = "", ...) {
  path <- tempfile(fileext = ext)
  writeBin(fetch_bytes(url, ...), path)
  path
}

# ---- Parsing helpers --------------------------------------------------------

parse_int <- function(x) {
  x <- as.character(x)
  x <- str_replace_all(x, "[,\\s]", "")
  suppressWarnings(as.integer(x))
}

parse_extra <- function(extra_json) {
  if (is.null(extra_json) || is.na(extra_json) || !nzchar(extra_json)) return(list())
  jsonlite::fromJSON(extra_json, simplifyVector = TRUE)
}

# Pull "123 of 456 precincts" style phrases out of free text.
extract_precincts <- function(text) {
  m <- str_match(
    text,
    regex("(\\d[\\d,]*)\\s*(?:of|/)\\s*(\\d[\\d,]*)\\s*precincts", ignore_case = TRUE)
  )
  if (is.na(m[1, 1])) {
    m <- str_match(
      text,
      regex("precincts\\s*(?:reporting|reported|counted)?[^\\d]{0,20}(\\d[\\d,]*)\\s*(?:of|/)\\s*(\\d[\\d,]*)",
            ignore_case = TRUE)
    )
  }
  if (is.na(m[1, 1])) return(c(NA_integer_, NA_integer_))
  c(parse_int(m[1, 2]), parse_int(m[1, 3]))
}

# ---- Contest table -> standard result ---------------------------------------
#
# Every adapter produces a "contest table": one row per (contest, choice) with
# columns  contest, choice, votes, precincts_reporting, precincts_total,
# ballots_cast, registered_voters.  standardize_result() picks the contest the
# source row asks for, maps its choices to yes/no and returns one tidy row.

empty_contest_table <- function() {
  tibble(
    contest = character(), choice = character(), votes = integer(),
    precincts_reporting = integer(), precincts_total = integer(),
    ballots_cast = integer(), registered_voters = integer()
  )
}

empty_result <- function() {
  tibble(
    yes_votes = NA_integer_, no_votes = NA_integer_,
    precincts_reporting = NA_integer_, precincts_total = NA_integer_,
    ballots_cast = NA_integer_, registered_voters = NA_integer_,
    raw_contest = NA_character_, as_of = NA_character_,
    source_url = NA_character_, adapter = NA_character_, note = NA_character_
  )
}

standardize_result <- function(tbl, src) {
  if (is.null(tbl) || nrow(tbl) == 0) return(NULL)
  contest_rx <- src$contest_pattern %||% ""
  yes_rx <- src$yes_pattern %||% YES_RX
  no_rx  <- src$no_pattern  %||% NO_RX

  hits <- tbl
  if (nzchar(contest_rx)) {
    hits <- tbl |> filter(str_detect(contest, regex(contest_rx, ignore_case = TRUE)))
  }
  if (nrow(hits) == 0) {
    cli::cli_warn("{src$race_id}: no contest matched /{contest_rx}/ (contests seen: {paste(head(unique(tbl$contest), 8), collapse = ' | ')})")
    return(NULL)
  }
  contests <- unique(hits$contest)
  if (length(contests) > 1) {
    cli::cli_warn("{src$race_id}: {length(contests)} contests matched; using the first: {contests[1]}")
    hits <- hits |> filter(contest == contests[1])
  }

  yes <- hits |> filter(str_detect(choice, regex(yes_rx, ignore_case = TRUE)))
  no  <- hits |> filter(str_detect(choice, regex(no_rx,  ignore_case = TRUE)))
  if (nrow(yes) == 0 || nrow(no) == 0) {
    cli::cli_warn("{src$race_id}: could not map choices to yes/no (choices: {paste(hits$choice, collapse = ' | ')})")
    return(NULL)
  }

  tibble(
    yes_votes = sum(yes$votes, na.rm = TRUE),
    no_votes  = sum(no$votes,  na.rm = TRUE),
    precincts_reporting = suppressWarnings(max(hits$precincts_reporting, na.rm = TRUE)) |> na_if_inf(),
    precincts_total     = suppressWarnings(max(hits$precincts_total,     na.rm = TRUE)) |> na_if_inf(),
    ballots_cast        = suppressWarnings(max(hits$ballots_cast,        na.rm = TRUE)) |> na_if_inf(),
    registered_voters   = suppressWarnings(max(hits$registered_voters,   na.rm = TRUE)) |> na_if_inf(),
    raw_contest = contests[1],
    as_of = now_iso(),
    source_url = src$results_url %||% src$api_url %||% NA_character_,
    adapter = src$adapter,
    note = NA_character_
  )
}

na_if_inf <- function(x) {
  x <- as.numeric(x)
  if (!is.finite(x)) NA_integer_ else as.integer(x)
}

# ---- Derived fields ---------------------------------------------------------

# Given a result row and the race's yes_means ("restrict" or "allow"), compute
# the fields the dashboard uses. restrict_votes/allow_votes are the two sides
# of the data-center question regardless of how the ballot is worded.
derive_fields <- function(res, race) {
  yes <- res$yes_votes; no <- res$no_votes
  total <- ifelse(is.na(yes) | is.na(no), NA_integer_, yes + no)
  yes_means <- race$yes_means %||% "restrict"
  restrict_votes <- if (yes_means == "restrict") yes else no
  allow_votes    <- if (yes_means == "restrict") no  else yes

  pct <- function(a, b) ifelse(is.na(b) | b == 0, NA_real_, round(100 * a / b, 2))
  pct_reporting <- pct(res$precincts_reporting, res$precincts_total)

  # Naive outstanding-vote estimate: assumes precincts report at the same
  # average size. Only produced when precinct counts exist; flagged as rough.
  est_remaining <- NA_real_
  if (!is.na(pct_reporting) && pct_reporting > 0 && !is.na(total) && total > 0) {
    est_remaining <- round(total / (pct_reporting / 100) - total)
  }

  margin <- pct(restrict_votes, total) - pct(allow_votes, total)
  leader <- case_when(
    is.na(total) | total == 0 ~ "none",
    restrict_votes > allow_votes ~ "restrict",
    allow_votes > restrict_votes ~ "allow",
    TRUE ~ "tie"
  )

  status <- case_when(
    !is.na(res$status_override) & nzchar(res$status_override) ~ res$status_override,
    is.na(total) | total == 0 ~ "no_results",
    !is.na(pct_reporting) & pct_reporting >= 100 ~ "all_precincts",
    TRUE ~ "counting"
  )

  tibble(
    total_votes = total,
    yes_pct = pct(yes, total), no_pct = pct(no, total),
    restrict_votes = restrict_votes, allow_votes = allow_votes,
    restrict_pct = pct(restrict_votes, total), allow_pct = pct(allow_votes, total),
    margin_pts = round(margin, 2),
    pct_reporting = pct_reporting,
    est_votes_remaining = est_remaining,
    leader = leader,
    status = status
  )
}

# ---- Flat CSV for the Google Sheet ------------------------------------------
# One row per race with the latest numbers. The election-night sheet imports
# this file (IMPORTDATA) so people entering results by hand can see which
# races the automated feeds already cover. Written next to results.json.
write_results_csv <- function(results, races, path = "site/data/results.csv") {
  flat <- races |>
    select(race_id, state, jurisdiction, election_date, yes_means) |>
    inner_join(results |> select(any_of(c("race_id", "yes_votes", "no_votes", "total_votes", "yes_pct",
                                          "restrict_pct", "leader", "precincts_reporting", "precincts_total",
                                          "pct_reporting", "status", "adapter", "as_of", "source_url", "fetch_ok"))),
               by = "race_id") |>
    mutate(yes_pct = round(as.numeric(yes_pct), 1), restrict_pct = round(as.numeric(restrict_pct), 1),
           pct_reporting = round(as.numeric(pct_reporting), 1),
           feed = case_when(adapter == "manual" ~ "manual entry", is.na(adapter) ~ "none yet", TRUE ~ adapter))
  readr::write_csv(flat, path, na = "")
  invisible(flat)
}
