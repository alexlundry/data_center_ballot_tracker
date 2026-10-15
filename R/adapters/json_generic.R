# ---------------------------------------------------------------------------
# Adapter: generic JSON endpoint
# ---------------------------------------------------------------------------
# Many ENR vendors expose JSON. Describe where things live in extra_json:
#   {"contests_path": "Contests",      # dotted path to the array of contests
#    "name_key": "K",                  # contest name
#    "choices_key": "C",               # array of choice labels  (or
#    "choice_rows_key": "Choices",     #   array of choice objects ...)
#    "choice_name_key": "Name",        #   ... with these keys
#    "choice_votes_key": "Votes",
#    "votes_key": "V",                 # array of votes parallel to choices
#    "prec_rep_key": "PrecinctsReporting",
#    "prec_tot_key": "PrecinctsTotal"}
# Defaults match the Clarity summary.json layout.

get_path <- function(x, path) {
  if (is.null(path) || !nzchar(path)) return(x)
  for (p in str_split(path, "\\.")[[1]]) {
    x <- x[[p]]
    if (is.null(x)) return(NULL)
  }
  x
}

adapter_json_generic <- function(src) {
  js <- fetch_json(src$api_url %||% src$results_url)
  e <- parse_extra(src$extra_json)
  contests <- get_path(js, e$contests_path %||% "Contests")
  if (is.null(contests)) stop("contests_path not found in JSON")
  name_key <- e$name_key %||% "K"
  tbl <- purrr::map_dfr(contests, function(ct) {
    if (!is.null(e$choice_rows_key)) {
      rows <- ct[[e$choice_rows_key]]
      choices <- purrr::map_chr(rows, ~ as.character(.x[[e$choice_name_key %||% "Name"]]))
      votes <- purrr::map_int(rows, ~ parse_int(.x[[e$choice_votes_key %||% "Votes"]]))
    } else {
      choices <- as.character(unlist(ct[[e$choices_key %||% "C"]]))
      votes <- parse_int(unlist(ct[[e$votes_key %||% "V"]]))
    }
    tibble(
      contest = as.character(ct[[name_key]] %||% NA_character_),
      choice = choices, votes = votes,
      precincts_reporting = parse_int(ct[[e$prec_rep_key %||% "__none__"]] %||% NA),
      precincts_total = parse_int(ct[[e$prec_tot_key %||% "__none__"]] %||% NA),
      ballots_cast = NA_integer_, registered_voters = NA_integer_
    )
  })
  standardize_result(tbl, src)
}
