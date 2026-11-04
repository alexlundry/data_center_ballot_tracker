# Run with:  Rscript -e 'testthat::test_dir("R/tests/testthat")'   from the repo root
find_root <- function(start = getwd()) {
  d <- normalizePath(start)
  for (i in 1:6) { if (file.exists(file.path(d, "R", "packages.R"))) return(d); d <- dirname(d) }
  stop("repo root not found")
}
ROOT <- find_root()
suppressMessages({ source(file.path(ROOT, "R/packages.R")); source(file.path(ROOT, "R/utils.R"))
  for (f in list.files(file.path(ROOT, "R/adapters"), pattern = "\\.R$", full.names = TRUE)) source(f) })
fx <- function(name) file.path(ROOT, "R/tests/testthat/fixtures", name)

test_that("Clarity summary.csv is parsed and standardized", {
  raw <- readr::read_csv(fx("clarity_summary.csv"), show_col_types = FALSE,
                         col_types = readr::cols(.default = readr::col_character()))
  names(raw) <- tolower(names(raw))
  tbl <- tibble(contest = raw[["contest name"]], choice = raw[["choice name"]],
                votes = parse_int(raw[["total votes"]]),
                precincts_reporting = parse_int(raw[["num area rptg"]]),
                precincts_total = parse_int(raw[["num area total"]]),
                ballots_cast = parse_int(raw[["ballots cast"]]),
                registered_voters = parse_int(raw[["registered voters"]]))
  src <- list(race_id = "oh-trenton", adapter = "clarity", contest_pattern = "Trenton", results_url = "x")
  res <- standardize_result(tbl, src)
  expect_equal(res$yes_votes, 1204L); expect_equal(res$no_votes, 868L)
  expect_equal(res$precincts_reporting, 4L); expect_equal(res$precincts_total, 6L)
  expect_equal(res$ballots_cast, 2345L)
})

test_that("For/Against choices map to yes/no", {
  tbl <- tibble(contest = "Levy", choice = c("For the Tax Levy", "Against the Tax Levy"), votes = c(500L, 400L),
                precincts_reporting = 3L, precincts_total = 3L, ballots_cast = NA_integer_, registered_voters = NA_integer_)
  res <- standardize_result(tbl, list(race_id = "t", adapter = "x", contest_pattern = "Levy"))
  expect_equal(res$yes_votes, 500L); expect_equal(res$no_votes, 400L)
})

test_that("HTML table adapter reads a county page", {
  src <- list(race_id = "oh-conneaut", adapter = "html_table", results_url = fx("county_results.html"),
              contest_pattern = "Conneaut", extra_json = NA)
  # monkeypatch fetch_text to read the fixture
  fetch_text <<- function(url, ...) paste(readLines(url, warn = FALSE), collapse = "\n")
  res <- adapter_html_table(src)
  expect_equal(res$yes_votes, 1532L); expect_equal(res$no_votes, 971L)
  expect_equal(res$precincts_reporting, 5L); expect_equal(res$precincts_total, 8L)
  src2 <- src; src2$contest_pattern <- "Monroeville"; src2$race_id <- "oh-monroeville"
  res2 <- adapter_html_table(src2)
  expect_equal(res2$yes_votes, 120L); expect_equal(res2$no_votes, 340L)
})

test_that("derive_fields flips sides for allow-type questions", {
  res <- tibble(yes_votes = 300L, no_votes = 700L, precincts_reporting = 2L, precincts_total = 4L,
                ballots_cast = NA, registered_voters = NA, status_override = NA_character_)
  d_allow <- derive_fields(res, list(yes_means = "allow"))
  expect_equal(d_allow$restrict_votes, 700L); expect_equal(d_allow$leader, "restrict")
  expect_equal(d_allow$pct_reporting, 50); expect_equal(d_allow$est_votes_remaining, 1000)
  d_restrict <- derive_fields(res, list(yes_means = "restrict"))
  expect_equal(d_restrict$restrict_votes, 300L); expect_equal(d_restrict$leader, "allow")
  d_none <- derive_fields(res |> mutate(yes_votes = NA_integer_, no_votes = NA_integer_), list(yes_means = "restrict"))
  expect_equal(d_none$status, "no_results"); expect_equal(d_none$leader, "none")
})

test_that("manual table parses override flags and keeps newest row", {
  tmp <- tempfile(fileext = ".csv")
  writeLines(c("race_id,yes_votes,no_votes,precincts_reporting,precincts_total,status,as_of,source_url,override,entered_by,note",
               "x,10,5,1,2,,2026-11-03T20:00:00-0500,,TRUE,alex,first",
               "x,20,9,2,2,final,2026-11-03T21:00:00-0500,,TRUE,alex,second"), tmp)
  m <- read_manual_table(tmp)
  expect_equal(nrow(m), 1); expect_equal(m$yes_votes, 20L); expect_true(m$override)
  r <- adapter_manual(list(race_id = "x", results_url = NA), m)
  expect_equal(r$status_override, "final")
})

test_that("public notes come through for races with no votes, and not from a sheet without the column", {
  tmp <- tempfile(fileext = ".csv")
  writeLines(c("race_id,yes_votes,no_votes,status,as_of,override,public_note",
               "me-peru,,,,,TRUE,Town office reopens Thursday.",
               "me-wells,,,,,TRUE,",
               "oh-urbana,700,300,,,TRUE, "), tmp)
  m <- read_manual_table(tmp)
  n <- public_notes(m)
  expect_equal(n$race_id, "me-peru"); expect_equal(n$public_note, "Town office reopens Thursday.")
  expect_null(adapter_manual(list(race_id = "me-peru", results_url = NA), m))
  expect_equal(nrow(public_notes(m |> select(-public_note))), 0)
  expect_equal(nrow(public_notes(NULL)), 0)
})

test_that("Clarity summary.csv with Madison's precinct columns maps to the township contest", {
  tbl <- clarity_parse_summary_csv(fx("clarity_summary_madison.csv"))
  src <- list(race_id = "il-chouteau-twp", adapter = "clarity", results_url = "x",
              contest_pattern = "CHOUTEAU (TOWNSHIP|TWP)|DATA CENT.*CHOUTEAU")
  res <- standardize_result(tbl, src)
  expect_equal(res$yes_votes, 412L); expect_equal(res$no_votes, 618L)
  expect_equal(res$precincts_reporting, 3L); expect_equal(res$precincts_total, 4L)
  expect_equal(res$registered_voters, 1890L)
  # Granite City's township pattern must not catch the school district levy
  gc <- list(race_id = "il-granite-city-twp", adapter = "clarity", results_url = "x",
             contest_pattern = "GRANITE CITY (TOWNSHIP|TWP)|DATA CENT.*GRANITE CITY")
  expect_null(suppressWarnings(standardize_result(tbl, gc)))
})

test_that("GOOGLE_SA_JSON may hold the key itself or a path to it", {
  source(file.path(ROOT, "R/write_sheet.R"))
  json <- '{"type": "service_account", "client_email": "x@y.iam.gserviceaccount.com"}'
  expect_equal(readLines(sa_key_file(json)), json)
  f <- tempfile(fileext = ".json"); writeLines(json, f)
  expect_equal(sa_key_file(f), f)
  expect_error(sa_key_file(file.path(tempdir(), "missing.json")), "neither key JSON")
})

# Nov 3 sources: fixtures are cut from that morning's responses, with invented counts
src_row <- function(race, pr = "1") {
  s <- readr::read_csv(file.path(ROOT, "data/sources.csv"), show_col_types = FALSE,
                       col_types = readr::cols(.default = readr::col_character()))
  as.list(s[s$race_id == race & s$priority == pr, ][1, ])
}

test_that("Enhanced Voting data (Volusia) reads Edgewater Amendment 4, not its neighbours", {
  fetch_text <<- function(url, ...) paste(readLines(url, warn = FALSE), collapse = "\n")
  src <- src_row("fl-edgewater"); src$api_url <- fx("enhanced_voting_volusia.json")
  expect_equal(src$adapter, "enhanced_voting")
  res <- adapter_enhanced_voting(src)
  expect_equal(res$yes_votes, 5210L); expect_equal(res$no_votes, 2875L)
  expect_equal(res$precincts_reporting, 14L); expect_equal(res$precincts_total, 17L)
  expect_equal(res$raw_contest, "Amendment 4 - Edgewater")
})

test_that("Enhanced Voting's 0 of 0 units before the first upload is unknown, not complete", {
  js <- jsonlite::fromJSON(fx("enhanced_voting_volusia.json"), simplifyVector = FALSE)
  for (i in seq_along(js$ballotItems)) js$ballotItems[[i]]$reportingStatus[c("reportingUnits", "totalUnits")] <- list(0L, 0L)
  f <- tempfile(fileext = ".json"); jsonlite::write_json(js, f, auto_unbox = TRUE, null = "null")
  src <- src_row("fl-edgewater"); src$api_url <- f
  res <- adapter_enhanced_voting(src)
  expect_true(is.na(res$precincts_reporting)); expect_true(is.na(res$precincts_total))
})

test_that("LA County JSON walks ContestGroups to Alhambra Measure DB", {
  src <- src_row("ca-alhambra"); src$api_url <- fx("lavote_4348.json")
  res <- adapter_json_generic(src)
  expect_equal(res$yes_votes, 8123L); expect_equal(res$no_votes, 6034L)
  expect_match(res$raw_contest, "MEASURE DB$")
})

test_that("Adams (Dominion) zero report: Township of Monroe heading, wrapped Against row", {
  src <- src_row("oh-monroe-twp"); src$local_file <- fx("adams_20261103_zero.pdf")
  res <- adapter_pdf(src)
  expect_equal(res$yes_votes, 0L); expect_equal(res$no_votes, 0L)
  expect_match(res$raw_contest, "^Township of Monroe Proposed Zoning Plan")
  # "Against the Zoning" / count / "Resolution": write distinct counts into the real lines
  lines <- str_split_1(paste(pdftools::pdf_text(fx("adams_20261103_zero.pdf")), collapse = "\n"), "\n")
  put <- function(lines, head, yes, no) {
    f <- grep(head, lines, fixed = TRUE) + grep("^For the Zoning", lines[-(1:grep(head, lines, fixed = TRUE))])[1]
    lines[f] <- sub("0$", yes, lines[f]); lines[f + 2] <- sub("0$", no, lines[f + 2]); lines
  }
  lines <- put(put(lines, "Township of Monroe Proposed", "211", "187"), "Township of Sprigg Proposed", "512", "1,034")
  m <- pdf_contest_result(lines, src)
  expect_equal(c(m$yes_votes, m$no_votes), c(211L, 187L))
  s <- pdf_contest_result(lines, src_row("oh-sprigg-twp"))
  expect_equal(c(s$yes_votes, s$no_votes), c(512L, 1034L))
  # An Against count the reader cannot find is an error, not a 0
  expect_error(pdf_contest_result(lines[-(grep("Township of Monroe Proposed", lines) + 7)], src), "could not read the no count")
})

test_that("Nov 3 zero reports: Ashtabula's short Conneaut title, Licking's four Pataskala amendments, Butler's Total column", {
  # Write counts over a contest's YES and NO rows in the real report
  counts <- function(file, head, yes_row, no_row) {
    l <- str_split_1(paste(pdftools::pdf_text(fx(file)), collapse = "\n"), "\n")
    h <- grep(head, l, fixed = TRUE)[1]; after <- l[-(1:h)]
    l[h + grep("^\\s*yes\\s", after, ignore.case = TRUE)[1]] <- yes_row
    l[h + grep("^\\s*no\\s", after, ignore.case = TRUE)[1]] <- no_row
    l
  }
  co <- src_row("oh-conneaut"); co$local_file <- fx("ashtabula_20261103_zero.pdf")
  expect_equal(adapter_pdf(co)$raw_contest, "10 Conn City Charter Amend")
  r <- pdf_contest_result(counts("ashtabula_20261103_zero.pdf", "10 Conn City Charter Amend", "YES 2,100 51.22%", "NO 2,000 48.78%"), co)
  expect_equal(c(r$yes_votes, r$no_votes), c(2100L, 2000L))

  pa <- src_row("oh-pataskala"); pa$local_file <- fx("licking_20261103_zero.pdf")
  expect_equal(adapter_pdf(pa)$raw_contest, "City of Pataskala - Charter Amendment - Data Centers")
  # TOTAL comes first: TOTAL, VOTE %, Election Day, Absentee Mail, Absentee Office, Provisional
  r <- pdf_contest_result(counts("licking_20261103_zero.pdf", "City of Pataskala - Charter Amendment - Data Centers",
                                 "YES 1,500 55.56% 900 400 150 50", "NO 1,200 44.44% 700 300 150 50"), pa)
  expect_equal(c(r$yes_votes, r$no_votes), c(1500L, 1200L))

  tr <- src_row("oh-trenton", "3"); tr$local_file <- fx("butler_20261103_zero.pdf")
  z <- adapter_pdf(tr)
  expect_equal(z$raw_contest, "ISSUE 17 CITY OF TRENTON")
  expect_equal(c(z$precincts_reporting, z$precincts_total), c(0L, 8L))
  # Absentee, Election Day, Provisional, Total: the last number is the count
  r <- pdf_contest_result(counts("butler_20261103_zero.pdf", "ISSUE 17 CITY OF TRENTON", "Yes 120 2,345 3 2,468", "No 98 1,870 2 1,970"), tr)
  expect_equal(c(r$yes_votes, r$no_votes), c(2468L, 1970L))
})

test_that("Rock County page reads the Janesville summary and its precinct line", {
  src <- src_row("wi-janesville"); src$local_file <- fx("rock_20261103.html")
  res <- adapter_html_table(src)
  expect_equal(res$yes_votes, 11204L); expect_equal(res$no_votes, 9877L)
  expect_equal(res$precincts_reporting, 31L); expect_equal(res$precincts_total, 40L)
  expect_match(res$raw_contest, "^Development Referendum City of Janesville")
})

test_that("Clark County nests contest tables in a layout table: Boulder City reads its own Question 1", {
  src <- src_row("nv-boulder-city"); src$local_file <- fx("clark_20241105_enr.html")
  # Nov 2024 general: CITY OF BOULDER CITY BALLOT QUESTION NUM. 1 was 5,752 to 3,871
  res <- adapter_html_table(src)
  expect_equal(c(res$yes_votes, res$no_votes), c(5752L, 3871L))
  expect_match(res$raw_contest, "BOULDER CITY BALLOT QUESTION NUM. 1")
  # Without the option the layout table matches and every YES/NO in the county is summed
  plain <- src; plain$extra_json <- NA
  expect_gt(adapter_html_table(plain)$yes_votes, 1e6)
  # A span heading also carries the next contest's VOTE FOR 1; Question 2 must not match
  q2 <- tempfile(fileext = ".html")
  readr::write_file(sub("BOULDER CITY BALLOT QUESTION NUM. 1", "BOULDER CITY BALLOT QUESTION NUM. 2",
                        readr::read_file(fx("clark_20241105_enr.html")), fixed = TRUE), q2)
  src$local_file <- q2
  expect_error(adapter_html_table(src), "no table matched")
})

test_that("Hart two-column summary: columns = 2 reads a right-hand contest's own counts", {
  # Delaware May 2026: Shawnee Hills (right column) sits beside Fort Morrow (59 / 32)
  src <- list(race_id = "x", adapter = "pdf", local_file = fx("delaware_20260505_summary.pdf"),
              contest_pattern = "Village of Shawnee Hills\\W+Proposed Tax Levy", extra_json = NA)
  expect_equal(c(adapter_pdf(src)$yes_votes, adapter_pdf(src)$no_votes), c(59L, 32L))
  src$extra_json <- '{"columns": 2}'
  expect_equal(c(adapter_pdf(src)$yes_votes, adapter_pdf(src)$no_votes), c(141L, 104L))
  src$contest_pattern <- "City of Columbus\\W+Proposed Charter Amendment"
  expect_equal(c(adapter_pdf(src)$yes_votes, adapter_pdf(src)$no_votes), c(776L, 377L))
  # Sunbury and Defiance use the option; their patterns cannot span both columns
  expect_equal(parse_extra(src_row("oh-sunbury")$extra_json)$columns, 2)
  expect_false(str_detect(src_row("oh-sunbury")$contest_pattern, fixed(".*")))
  de <- src_row("oh-defiance"); de$local_file <- fx("defiance_20260505_summary.pdf")
  expect_no_error(tryCatch(adapter_pdf(de), error = function(e) if (grepl("not found", conditionMessage(e))) NULL else stop(e)))
})

test_that("older numbers never replace newer published ones", {
  # fetch_results.R defines older_than_published next to fetch_one; read it from there
  src <- readLines(file.path(ROOT, "R/fetch_results.R"))
  a <- grep("^older_than_published <- function", src); b <- a + which(src[(a + 1):length(src)] == "}")[1]
  eval(parse(text = src[a:b]))
  pub <- list(yes_votes = 2004, no_votes = 766, as_of = "2026-11-03T20:15:13-0500")
  expect_true(older_than_published(list(as_of = "2026-11-03T14:31:52-0500"), pub))   # zero report from the drop folder
  expect_false(older_than_published(list(as_of = "2026-11-03T20:48:30-0500"), pub))  # a newer county file
  expect_false(older_than_published(list(as_of = "2026-11-03T14:31:52-0500"), list(yes_votes = 0, no_votes = 0, as_of = "2026-11-03T20:15:13-0500")))  # nothing published yet
  expect_false(older_than_published(list(as_of = NA), pub))
  expect_false(older_than_published(list(as_of = "2026-11-03T14:31:52-0500"), NULL))
})

test_that("Franklin's live viewer JSON: Grove City's #28 sums its precinct totals", {
  src <- src_row("oh-grove-city", "0"); src$local_file <- fx("franklin_live_20261103.json")
  expect_equal(src$adapter, "franklin_live")
  res <- adapter_franklin_live(src)
  expect_equal(c(res$yes_votes, res$no_votes), c(7694L, 6432L))
  expect_equal(res$raw_contest, "#28 Proposed Charter Amendment City of Grove City")
  expect_true(is.na(res$precincts_reporting))
})
