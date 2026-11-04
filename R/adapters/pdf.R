# ---------------------------------------------------------------------------
# Adapter: PDF results reports (small counties often post only a PDF)
# ---------------------------------------------------------------------------
# sources.csv:  adapter = pdf
#               api_url = the PDF url
#               contest_pattern = regex for the question heading in the PDF
#               yes_pattern / no_pattern = labels of the two choices
# Reads the text, finds the first line matching contest_pattern, and reads
# the next ~15 lines for "<label> ... <votes>" rows. Precincts come from any
# "x of y precincts" phrase nearby. This is a best-effort parser; use the
# manual sheet if a county's layout defeats it.

adapter_pdf <- function(src) {
  if (!requireNamespace("pdftools", quietly = TRUE)) stop("install.packages('pdftools')")
  path <- src$local_file %||% fetch_file(src$api_url %||% src$results_url, ext = ".pdf")
  # An HTML page (no PDF url set yet, or a block page) must not parse as an empty result
  if (!identical(readBin(path, "raw", 5), charToRaw("%PDF-"))) stop("not a PDF; set api_url to the results PDF")
  pdftools::pdf_text(path) |> paste(collapse = "\n") |> str_split("\n") |> unlist() |> pdf_contest_result(src)
}

pdf_contest_result <- function(lines, src) {
  # pdf_text keeps vertical spacing as empty lines; drop them so the window
  # below counts printed rows (Hart reports push "Against" past line 15 otherwise)
  raw <- lines[nzchar(str_squish(lines))]
  lines <- str_squish(raw)
  idx <- which(str_detect(lines, regex(src$contest_pattern %||% "", ignore_case = TRUE)))
  if (length(idx) == 0) stop("contest_pattern not found in PDF text")
  # extra_json options, for Butler's summary PDF: "votes": "last" reads the last
  # whole number on a row (Absentee, Election Day, Provisional, Total), and
  # "stop_at_vote_for": false keeps the window open past its own "Vote For 1",
  # which sits five rows under the title
  e <- parse_extra(src$extra_json)
  if (isTRUE(e$inline)) return(pdf_inline_result(lines[idx[1]], src))
  # "columns": 2, for Hart summary reports (Delaware, Defiance), which print
  # contests side by side; pdf_text joins both columns on one line, so a
  # right-hand contest would read the left-hand one's counts. A right-hand
  # contest keeps each row from just left of its heading; a left-hand one
  # drops rows that start in the right-hand column.
  if (identical(as.numeric(e$columns %||% 1), 2)) {
    at <- str_locate(raw[idx[1]], regex(src$contest_pattern, ignore_case = TRUE))[1, 1]
    if (is.na(at)) stop("two-column report: could not place the heading ", lines[idx[1]])
    lead <- str_locate(raw, "\\S")[, 1]
    lines <- if (at > 25) {
      str_squish(str_remove(str_sub(raw, max(1, at - 4)), "^\\S+\\s{2,}"))
    } else {
      if_else(lead > 25, "", lines)
    }
  }
  # Read up to 15 rows, stopping before the next contest (its "Vote For" line,
  # less the heading row above it) so a contest without its own precinct line
  # does not borrow the next one's
  end <- min(length(lines), idx[1] + 15)
  nxt <- which(str_detect(lines, regex("vote for \\d", ignore_case = TRUE)))
  nxt <- nxt[nxt > idx[1] + 1 & nxt <= end]
  if (length(nxt) && !isFALSE(e$stop_at_vote_for)) end <- max(idx[1], nxt[1] - 2)
  window <- lines[idx[1]:end]
  yes_rx <- src$yes_pattern %||% YES_RX; no_rx <- src$no_pattern %||% NO_RX
  grab <- function(rx) {
    i <- which(str_detect(window, regex(rx, ignore_case = TRUE)))[1]
    if (is.na(i)) return(NA_integer_)
    if (identical(e$votes, "last")) {
      whole <- str_extract_all(window[i], "(?<![\\d.,])\\d[\\d,]*(?![\\d.,%])")[[1]]
      return(if (length(whole)) parse_int(whole[length(whole)]) else NA_integer_)
    }
    nums <- str_extract_all(window[i], "\\d[\\d,]*")[[1]]
    # Dominion (Adams) wraps a long label and prints its count on the row
    # between: "Against the Zoning" / "412" / "Resolution"
    if (length(nums) == 0 && i < length(window) && str_detect(window[i + 1], "^\\d[\\d,]*( |$)"))
      nums <- str_extract(window[i + 1], "^\\d[\\d,]*")
    if (length(nums) == 0) NA_integer_ else parse_int(nums[1])
  }
  votes <- c(grab(yes_rx), grab(no_rx))
  # standardize_result sums with na.rm, so an unread side would publish as 0
  if (anyNA(votes)) stop("could not read the ", c("yes", "no")[is.na(votes)][1], " count under ", lines[idx[1]])
  prec <- extract_precincts(paste(window, collapse = " "))
  tbl <- tibble(
    contest = lines[idx[1]], choice = c("Yes", "No"),
    votes = votes,
    precincts_reporting = prec[1], precincts_total = prec[2],
    ballots_cast = NA_integer_, registered_voters = NA_integer_
  )
  src2 <- src; src2$contest_pattern <- ""; src2$yes_pattern <- "^Yes$"; src2$no_pattern <- "^No$"
  standardize_result(tbl, src2)
}

# "inline": true, for Franklin County KS's InDesign results sheets, which print
# a question on one row under a Yes / No header, beside other boxes' columns
# ("Jacy Hurst 5011 3512 City of Ottawa Question 2882 1129"): YES and NO are
# the first two whole numbers after the title. The sheets give no precincts.
pdf_inline_result <- function(line, src) {
  at <- str_locate(line, regex(src$contest_pattern, ignore_case = TRUE))[1, 2]
  nums <- str_extract_all(str_sub(line, at + 1), "(?<![\\d.,])\\d[\\d,]*(?![\\d.,%])")[[1]]
  if (length(nums) < 2) stop("inline: no YES and NO counts after the title in ", line)
  tbl <- tibble(
    contest = str_sub(line, str_locate(line, regex(src$contest_pattern, ignore_case = TRUE))[1, 1], at),
    choice = c("Yes", "No"), votes = parse_int(nums[1:2]),
    precincts_reporting = NA_integer_, precincts_total = NA_integer_,
    ballots_cast = NA_integer_, registered_voters = NA_integer_
  )
  src2 <- src; src2$contest_pattern <- ""; src2$yes_pattern <- "^Yes$"; src2$no_pattern <- "^No$"
  standardize_result(tbl, src2)
}
