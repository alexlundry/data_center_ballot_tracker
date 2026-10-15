# ---------------------------------------------------------------------------
# Adapter: generic HTML results page (county-built pages, ENR vendors that
# render plain tables)
# ---------------------------------------------------------------------------
# sources.csv:  adapter = html_table
#               results_url = the page
#               contest_pattern = regex that appears in the table or its
#                                 heading for this question
#               extra_json (optional) = {"choice_col": 1, "votes_col": 2}
#
# Strategy: read every <table>, keep the ones whose text (or the heading
# immediately before them) matches contest_pattern, then treat the first
# column as the choice label and the first numeric column as votes.
# Precincts are pulled from the surrounding text ("12 of 14 precincts").

adapter_html_table <- function(src) {
  page <- fetch_text(src$results_url)
  doc <- xml2::read_html(page)
  extra <- parse_extra(src$extra_json)
  tables <- rvest::html_elements(doc, "table")
  if (length(tables) == 0) stop("no <table> elements on page")

  rx <- regex(src$contest_pattern %||% "", ignore_case = TRUE)
  out <- list()
  for (i in seq_along(tables)) {
    tb <- tables[[i]]
    text_here <- rvest::html_text2(tb)
    # Headings / captions / paragraphs just before the table (nearest three),
    # so "Issue 10 - Conneaut" two elements up still identifies the table.
    prev <- xml2::xml_find_all(tb, "preceding::*[self::h1 or self::h2 or self::h3 or self::h4 or self::h5 or self::caption or self::p or self::strong or self::b][position() <= 3]")
    heading <- if (length(prev) == 0) "" else paste(rev(rvest::html_text2(prev)), collapse = " | ")
    caption <- xml2::xml_find_first(tb, ".//caption")
    if (!inherits(caption, "xml_missing")) heading <- paste(rvest::html_text2(caption), heading, sep = " | ")
    if (nzchar(src$contest_pattern %||% "") &&
        !str_detect(text_here, rx) && !str_detect(heading, rx)) next

    df <- tryCatch(rvest::html_table(tb, fill = TRUE), error = function(e) NULL)
    if (is.null(df) || nrow(df) == 0) next
    choice_col <- extra$choice_col %||% 1
    votes_col <- extra$votes_col %||% NA
    if (is.na(votes_col)) {
      # first column that parses as integers for most rows
      numeric_like <- vapply(df, function(col) mean(!is.na(parse_int(col))) >= 0.5, logical(1))
      numeric_like[choice_col] <- FALSE
      votes_col <- which(numeric_like)[1]
    }
    if (is.na(votes_col)) next
    prec <- extract_precincts(paste(heading, text_here))
    out[[length(out) + 1]] <- tibble(
      contest = if (nzchar(heading)) heading else paste("table", i),
      choice = as.character(df[[choice_col]]),
      votes = parse_int(df[[votes_col]]),
      precincts_reporting = prec[1], precincts_total = prec[2],
      ballots_cast = NA_integer_, registered_voters = NA_integer_
    ) |> filter(!is.na(votes))
  }
  if (length(out) == 0) stop("no table matched contest_pattern")
  tbl <- bind_rows(out)
  # The contest filter already happened at table level; match everything now.
  src2 <- src; src2$contest_pattern <- ""
  standardize_result(tbl, src2)
}
