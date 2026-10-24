# ---------------------------------------------------------------------------
# Adapter: Scytl / Clarity election night reporting
# ---------------------------------------------------------------------------
# Used by many county election offices (and some states). Results pages look
# like  https://results.enr.clarityelections.com/<ST>/<County>/<electionid>/...
# The site version changes with every upload, so we read current_ver.txt and
# then download the machine-readable summary for that version.
#
# sources.csv:  adapter = clarity
#               api_url = base url up to and including the election id, e.g.
#                         https://results.enr.clarityelections.com/OH/Butler/123456
#               contest_pattern = regex for the question's contest name
#
# Two formats are tried in order:
#   1. <base>/<ver>/reports/summary.zip  (summary.csv: contest, choice, votes,
#      registered voters, ballots cast, num Area total, num Area rptg)
#   2. <base>/<ver>/json/en/summary.json (Contests[]: K = name, C = choices,
#      V = votes, P = precincts reporting info on newer sites)

clarity_version <- function(base) {
  base <- str_remove(base, "/+$")
  ver <- fetch_text(paste0(base, "/current_ver.txt")) |> str_trim()
  if (!str_detect(ver, "^\\d+$")) stop("Unexpected current_ver.txt: ", ver)
  ver
}

clarity_summary_csv <- function(base, ver) {
  zip_path <- fetch_file(paste0(base, "/", ver, "/reports/summary.zip"), ext = ".zip")
  exdir <- tempfile("clarity_")
  utils::unzip(zip_path, exdir = exdir)
  csv <- list.files(exdir, pattern = "summary\\.csv$", full.names = TRUE, recursive = TRUE)[1]
  if (is.na(csv)) stop("summary.csv not found in summary.zip")
  clarity_parse_summary_csv(csv)
}

# Counties differ in the precinct columns: "num Area rptg" (Bloomington) or
# "num Precinct rptg" (Madison). registered voters and ballots cast are per
# contest, so a township question carries the township's own registration.
clarity_parse_summary_csv <- function(csv) {
  raw <- readr::read_csv(csv, show_col_types = FALSE,
                         col_types = readr::cols(.default = readr::col_character()))
  names(raw) <- tolower(names(raw))
  col <- function(...) {
    hit <- intersect(c(...), names(raw))[1]
    if (is.na(hit)) NA else raw[[hit]]
  }
  tibble(
    contest = raw[["contest name"]],
    choice = raw[["choice name"]],
    votes = parse_int(raw[["total votes"]]),
    precincts_reporting = parse_int(col("num area rptg", "num precinct rptg")),
    precincts_total = parse_int(col("num area total", "num precinct total")),
    ballots_cast = parse_int(col("ballots cast")),
    registered_voters = parse_int(col("registered voters"))
  )
}

clarity_summary_json <- function(base, ver) {
  js <- fetch_json(paste0(base, "/", ver, "/json/en/summary.json"))
  contests <- js$Contests %||% js
  purrr::map_dfr(contests, function(ct) {
    choices <- unlist(ct$C); votes <- parse_int(unlist(ct$V))
    prec <- unlist(ct$P)
    tibble(
      contest = ct$K %||% NA_character_,
      choice = choices,
      votes = votes,
      precincts_reporting = if (length(prec) >= 1) parse_int(prec[1]) else NA_integer_,
      precincts_total = if (length(prec) >= 2) parse_int(prec[2]) else NA_integer_,
      ballots_cast = NA_integer_, registered_voters = NA_integer_
    )
  })
}

adapter_clarity <- function(src) {
  base <- str_remove(src$api_url, "/+$")
  ver <- clarity_version(base)
  tbl <- tryCatch(clarity_summary_csv(base, ver), error = function(e) {
    cli::cli_alert_warning("{src$race_id}: summary.zip failed ({conditionMessage(e)}); trying JSON")
    clarity_summary_json(base, ver)
  })
  standardize_result(tbl, src)
}
