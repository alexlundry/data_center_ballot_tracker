# ---------------------------------------------------------------------------
# Adapter: Enhanced Voting public results (app.enhancedvoting.com)
# ---------------------------------------------------------------------------
# Volusia County FL and Pickaway County OH moved to Enhanced Voting for the
# Nov 2026 general. The public page is an Angular app that reads one JSON file:
#   https://app.enhancedvoting.com/results/public/api/elections/<jurisdiction>/<election>/data
# e.g. volusia-county-fl/2026GeneralElection, pickaway-county-oh/GE2026_20261028170048
# (the <election> slug is the last part of the public results url).
#
# sources.csv:  adapter = enhanced_voting
#               api_url = the .../data url above
#               contest_pattern = regex for the ballot item name
#
# ballotItems[]: name = [{languageId, text}] (English plus Spanish in Volusia),
# summaryResults.ballotOptions[] = {name, voteCount}, reportingStatus =
# {reportingUnits, totalUnits}. Checked Nov 3 morning at zero votes.

ev_text <- function(x) {
  if (is.null(x) || length(x) == 0) return(NA_character_)
  if (is.character(x)) return(x[1])
  en <- purrr::keep(x, ~ identical(.x$languageId, "en"))
  (if (length(en)) en[[1]] else x[[1]])$text %||% NA_character_
}

adapter_enhanced_voting <- function(src) {
  js <- fetch_json(src$api_url %||% src$results_url)
  items <- js$ballotItems
  if (length(items) == 0) stop("no ballotItems in Enhanced Voting data")
  tbl <- purrr::map_dfr(items, function(b) {
    opts <- b$summaryResults$ballotOptions
    if (length(opts) == 0) return(NULL)
    tibble(
      contest = ev_text(b$name),
      choice = purrr::map_chr(opts, ~ ev_text(.x$name)),
      votes = purrr::map_int(opts, ~ parse_int(.x$voteCount %||% NA)),
      precincts_reporting = parse_int(b$reportingStatus$reportingUnits %||% NA),
      precincts_total = parse_int(b$reportingStatus$totalUnits %||% NA),
      ballots_cast = NA_integer_, registered_voters = NA_integer_
    )
  })
  # totalUnits is 0 before the first upload; 0 of 0 would read as "complete"
  tbl <- tbl |> mutate(across(c(precincts_reporting, precincts_total), ~ if_else(precincts_total %in% 0L, NA_integer_, .x)))
  standardize_result(tbl, src)
}
