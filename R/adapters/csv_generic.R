# ---------------------------------------------------------------------------
# Adapter: generic CSV download (VR Systems "Candidate Summary Results",
# county exports, anything with one row per contest/choice)
# ---------------------------------------------------------------------------
# sources.csv:  adapter = csv_generic
#               api_url = the CSV url
#               contest_pattern = regex for the contest/issue name
#               extra_json = {"contest_col": "Contest", "choice_col": "Candidate",
#                             "votes_col": "Total Votes",
#                             "prec_rep_col": "Precincts Reporting",
#                             "prec_tot_col": "Total Precincts", "skip": 0}
# Column names are matched case-insensitively and by substring, so
# "Votes" matches "Total Votes". skip = header lines to drop first.

adapter_csv_generic <- function(src) {
  e <- parse_extra(src$extra_json)
  path <- fetch_file(src$api_url %||% src$results_url, ext = ".csv")
  df <- readr::read_csv(path, skip = e$skip %||% 0, show_col_types = FALSE,
                        col_types = readr::cols(.default = readr::col_character()))
  contest_col <- find_col(df, e$contest_col %||% "Contest")
  choice_col  <- find_col(df, e$choice_col  %||% "Candidate")
  votes_col   <- find_col(df, e$votes_col   %||% "Votes")
  pr_col <- find_col(df, e$prec_rep_col %||% "Precincts Reporting")
  pt_col <- find_col(df, e$prec_tot_col %||% "Total Precincts")
  if (any(is.na(c(contest_col, choice_col, votes_col)))) {
    stop("could not find contest/choice/votes columns; columns are: ", paste(names(df), collapse = ", "))
  }
  tbl <- tibble(
    contest = df[[contest_col]], choice = df[[choice_col]], votes = parse_int(df[[votes_col]]),
    precincts_reporting = if (is.na(pr_col)) NA_integer_ else parse_int(df[[pr_col]]),
    precincts_total = if (is.na(pt_col)) NA_integer_ else parse_int(df[[pt_col]]),
    ballots_cast = NA_integer_, registered_voters = NA_integer_
  ) |> filter(!is.na(votes))
  standardize_result(tbl, src)
}
