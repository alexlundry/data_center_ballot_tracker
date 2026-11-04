# ---------------------------------------------------------------------------
# Adapter: Franklin County, OH live results viewer (vote.franklincountyohio.gov/elections)
# ---------------------------------------------------------------------------
# sources.csv:  adapter = franklin_live
#               api_url = https://vote.franklincountyohio.gov/elections/api/election/live
#               contest_pattern = regex for the race name ("#28 Proposed Charter Amendment City of Grove City")
# The viewer's JSON lists races[] with choices[]; each choice carries votes[],
# one total per precinct (absentee included: before a precinct's Election Day
# count arrives, votes equals abs), so the county count is the sum. The feed has
# no per-race precinct-reporting count, so precincts are left blank.
adapter_franklin_live <- function(src) {
  path <- src$local_file %||% fetch_file(src$api_url %||% src$results_url, ext = ".json")
  d <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  if (isTRUE(d$isTest)) stop("Franklin's feed is flagged isTest")
  rows <- purrr::map_dfr(d$races, function(r) purrr::map_dfr(r$choices, function(ch) tibble(
    contest = r$name, choice = ch$name,
    votes = as.integer(sum(unlist(ch$votes), na.rm = TRUE) + (ch$overlapVotes %||% 0)),
    precincts_reporting = NA_integer_, precincts_total = NA_integer_,
    ballots_cast = NA_integer_, registered_voters = NA_integer_)))
  standardize_result(rows, src)
}
