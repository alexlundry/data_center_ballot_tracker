# ---------------------------------------------------------------------------
# Adapter: NIST SP 1500-100 results feed in JSON (Delaware County OH's
# boeresults.delco-gis.org/boe/api/results)
# ---------------------------------------------------------------------------
# sources.csv:  adapter = nist_json
#               api_url = the feed url
#               contest_pattern = regex for the contest Name
# ElectionReport.Election.ContestCollection.Contest[] holds each contest's
# BallotSelection[], each with VoteCountsCollection.VoteCounts[]: one entry per
# precinct (GpUnitId) and count type ("total", "election-day", "absentee",
# "early"), so only the "total" entries are summed. A contest's precincts are
# the precinct GpUnits its counts name. NIST's per-precinct CountStatus says
# which are done, but Delaware leaves every precinct "in-process" all night;
# its feed adds a county-wide "reporting": "180/180", so the contest's
# precincts all count as in once the whole county is. The feed's
# GeneratedDate dates the result.
adapter_nist_json <- function(src) {
  js <- jsonlite::fromJSON(fetch_text(src$api_url %||% src$results_url), simplifyVector = FALSE)
  rpt <- js$ElectionReport
  if (is.null(rpt)) stop("no ElectionReport in the feed")
  # one-element collections may come as a bare object rather than an array
  as_items <- function(x) if (!is.null(names(x))) list(x) else x
  label <- function(x) if (is.list(x)) label(x$Text %||% x[["#text"]] %||% x[[1]]) else as.character(x)

  units <- as_items(rpt$GpUnitCollection$GpUnit)
  precinct_ids <- purrr::map_chr(purrr::keep(units, ~ identical(.x$Type, "precinct")), "objectId")
  done_ids <- purrr::map_chr(purrr::keep(units, function(u) {
    any(purrr::map_lgl(as_items(u$CountStatus), ~ identical(.x$Type, "total") && identical(.x$Status, "completed")))
  }), "objectId")
  county <- parse_int(str_match(js$reporting %||% "", "^(\\d+)\\s*/\\s*(\\d+)$")[1, 2:3])
  county_in <- !anyNA(county) && county[2] > 0 && county[1] == county[2]

  election <- rpt$Election
  if (is.null(names(election))) election <- election[[1]]
  tbl <- purrr::map_dfr(as_items(election$ContestCollection$Contest), function(ct) {
    sels <- as_items(ct$BallotSelection)
    counts <- purrr::map(sels, function(s) {
      vc <- as_items(s$VoteCountsCollection$VoteCounts)
      tot <- purrr::keep(vc, ~ identical(.x$Type, "total"))
      if (length(tot) == 0) tot <- vc
      tot
    })
    prec <- intersect(unique(purrr::map_chr(unlist(counts, recursive = FALSE), "GpUnitId")), precinct_ids)
    tibble(
      contest = label(ct$Name),
      choice = purrr::map_chr(sels, ~ label(.x$Selection %||% .x$objectId)),
      votes = purrr::map_int(counts, ~ sum(parse_int(purrr::map_chr(.x, "Count")), na.rm = TRUE)),
      precincts_reporting = if (length(prec) == 0) NA_integer_ else if (county_in) length(prec) else sum(prec %in% done_ids),
      precincts_total = if (length(prec) == 0) NA_integer_ else length(prec),
      ballots_cast = NA_integer_, registered_voters = NA_integer_
    )
  })
  res <- standardize_result(tbl, src)
  generated <- suppressWarnings(lubridate::ymd_hms(rpt$GeneratedDate %||% NA))
  if (!is.null(res) && !is.na(generated)) res$as_of <- now_iso_at(generated)
  res
}
