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
