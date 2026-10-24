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
  lines <- pdftools::pdf_text(path) |> paste(collapse = "\n") |> str_split("\n") |> unlist() |> str_squish()
  idx <- which(str_detect(lines, regex(src$contest_pattern %||% "", ignore_case = TRUE)))
  if (length(idx) == 0) stop("contest_pattern not found in PDF text")
  window <- lines[idx[1]:min(length(lines), idx[1] + 15)]
  yes_rx <- src$yes_pattern %||% YES_RX; no_rx <- src$no_pattern %||% NO_RX
  grab <- function(rx) {
    ln <- window[str_detect(window, regex(rx, ignore_case = TRUE))][1]
    if (is.na(ln)) return(NA_integer_)
    nums <- str_extract_all(ln, "\\d[\\d,]*")[[1]]
    if (length(nums) == 0) NA_integer_ else parse_int(nums[1])
  }
  prec <- extract_precincts(paste(window, collapse = " "))
  tbl <- tibble(
    contest = lines[idx[1]], choice = c("Yes", "No"),
    votes = c(grab(yes_rx), grab(no_rx)),
    precincts_reporting = prec[1], precincts_total = prec[2],
    ballots_cast = NA_integer_, registered_voters = NA_integer_
  )
  src2 <- src; src2$contest_pattern <- ""; src2$yes_pattern <- "^Yes$"; src2$no_pattern <- "^No$"
  standardize_result(tbl, src2)
}
