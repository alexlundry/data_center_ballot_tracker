# ---------------------------------------------------------------------------
# Adapter: Ohio Secretary of State local questions & issues
# ---------------------------------------------------------------------------
# Ohio is special: ~20 of the November 2026 measures are there, and the
# Secretary of State publishes local questions and issues statewide. Before
# the election the SOS posts "November 3, 2026 General Election - Local
# Questions and Issues (XLSX)" (the ballot language list). On election night
# the SOS results site reports local issues by county. Column names on the
# night-of file are not known until it appears, so they are configurable:
#
# sources.csv:  adapter = ohio_sos
#               api_url = the XLSX/CSV url
#               contest_pattern = regex matched against the issue text column
#               extra_json = {"county": "Trumbull",
#                             "county_col": "County", "issue_col": "Issue",
#                             "yes_col": "Yes", "no_col": "No",
#                             "prec_rep_col": "Precincts Reporting",
#                             "prec_tot_col": "Total Precincts", "sheet": 1}
# Any column name that does not exist is skipped. If the night-of page is an
# HTML table instead, switch that race to adapter = html_table.

ohio_read_table <- function(url, sheet = 1) {
  ext <- if (str_detect(tolower(url), "\\.csv(\\?|$)")) ".csv" else ".xlsx"
  path <- fetch_file(url, ext = ext)
  if (ext == ".csv") {
    readr::read_csv(path, show_col_types = FALSE,
                    col_types = readr::cols(.default = readr::col_character()))
  } else {
    readxl::read_excel(path, sheet = sheet, col_types = "text")
  }
}

find_col <- function(df, wanted) {
  if (is.null(wanted)) return(NA_character_)
  nm <- names(df)
  hit <- nm[tolower(str_squish(nm)) == tolower(str_squish(wanted))]
  if (length(hit) == 0) hit <- nm[str_detect(tolower(nm), fixed(tolower(wanted)))]
  if (length(hit) == 0) NA_character_ else hit[1]
}

adapter_ohio_sos <- function(src, cache = new.env()) {
  e <- parse_extra(src$extra_json)
  url <- src$api_url
  key <- paste0(url, "#", e$sheet %||% 1)
  df <- if (!is.null(cache[[key]])) cache[[key]] else {
    cache[[key]] <- ohio_read_table(url, e$sheet %||% 1); cache[[key]]
  }
  county_col <- find_col(df, e$county_col %||% "County")
  issue_col  <- find_col(df, e$issue_col  %||% "Issue")
  yes_col    <- find_col(df, e$yes_col    %||% "Yes")
  no_col     <- find_col(df, e$no_col     %||% "No")
  pr_col     <- find_col(df, e$prec_rep_col %||% "Precincts Reporting")
  pt_col     <- find_col(df, e$prec_tot_col %||% "Precincts")
  if (is.na(issue_col) || is.na(yes_col) || is.na(no_col)) {
    stop("could not find issue/yes/no columns; columns are: ", paste(names(df), collapse = ", "))
  }
  rows <- df
  if (!is.na(county_col) && !is.null(e$county)) {
    rows <- rows |> filter(str_detect(tolower(.data[[county_col]]), tolower(e$county)))
  }
  rows <- rows |> filter(str_detect(.data[[issue_col]], regex(src$contest_pattern %||% "", ignore_case = TRUE)))
  if (nrow(rows) == 0) stop("no row matched county/issue pattern")
  if (nrow(rows) > 1) cli::cli_warn("{src$race_id}: {nrow(rows)} rows matched; using the first")
  r <- rows[1, ]
  tbl <- tibble(
    contest = r[[issue_col]],
    choice = c("Yes", "No"),
    votes = c(parse_int(r[[yes_col]]), parse_int(r[[no_col]])),
    precincts_reporting = if (is.na(pr_col)) NA_integer_ else parse_int(r[[pr_col]]),
    precincts_total = if (is.na(pt_col)) NA_integer_ else parse_int(r[[pt_col]]),
    ballots_cast = NA_integer_, registered_voters = NA_integer_
  )
  src2 <- src; src2$contest_pattern <- ""
  standardize_result(tbl, src2)
}
