find_root <- function(start = getwd()) {
  d <- normalizePath(start)
  for (i in 1:6) { if (file.exists(file.path(d, "R", "packages.R"))) return(d); d <- dirname(d) }
  stop("repo root not found")
}
ROOT <- find_root()
suppressMessages({ source(file.path(ROOT, "R/packages.R")); source(file.path(ROOT, "R/utils.R"))
  for (f in list.files(file.path(ROOT, "R/adapters"), pattern = "\\.R$", full.names = TRUE)) source(f) })
fx <- function(name) file.path(ROOT, "R/tests/testthat/fixtures", name)

# A results PDF with one contest, written by R's pdf device (pdftools reads it back).
make_pdf <- function(path, heading, yes, no) {
  grDevices::pdf(path); graphics::plot.new()
  graphics::text(0.5, 0.9, heading); graphics::text(0.5, 0.8, "Precincts Reporting 6 of 9")
  graphics::text(0.5, 0.7, paste("Yes", yes)); graphics::text(0.5, 0.6, paste("No", no))
  grDevices::dev.off()
  invisible(path)
}
touch_at <- function(path, t) Sys.setFileTime(path, as.POSIXct(t, tz = "America/New_York"))

new_drop <- function() {
  d <- tempfile("drop"); dir.create(d)
  withr::local_envvar(DCBT_DROP_DIR = d, DCBT_DROP_SINCE = "2026-01-01", .local_envir = parent.frame())
  drop_cache_clear()
  d
}

test_that("needs_drop matches the blocked hosts by suffix only", {
  expect_true(needs_drop(list(results_url = "https://www.boe.ohio.gov/adams/election-info/election-results/")))
  expect_true(needs_drop(list(results_url = "https://www.huron.boe.ohio.gov/")))
  expect_true(needs_drop(list(results_url = "https://liveresults.boe.ohio.gov/ENR/butlerohenr/24/en/Index_24.html")))
  expect_true(needs_drop(list(results_url = "https://liveresults.franklincountyohio.gov/enr/franklinohenr/")))
  expect_true(needs_drop(list(results_url = "https://example.org/", api_url = "https://www.boe.ohio.gov/x.pdf")))
  expect_false(needs_drop(list(results_url = "https://www.lakecountyohio.gov/boe/election-results/",
                               api_url = "https://webapps.lakecountyohio.gov/boe/web1.pdf")))
  expect_false(needs_drop(list(results_url = "https://vote.delawarecountyohio.gov/")))
  expect_false(needs_drop(list(results_url = "https://boe.ohio.gov.example.com/")))
  expect_false(needs_drop(list(results_url = NA, api_url = NA)))
})

test_that("find_drop_file picks the newest file whose text matches the contest", {
  d <- new_drop()
  make_pdf(file.path(d, "20261103results.pdf"), "Issue 8 City of Urbana Charter Amendment", "100", "50")
  make_pdf(file.path(d, "20261103results (1).pdf"), "Issue 8 City of Urbana Charter Amendment", "300", "150")
  make_pdf(file.path(d, "other.pdf"), "Issue 3 Village of Ashville Referendum", "9", "9")
  make_pdf(file.path(d, "Precinct Detail.pdf"), "Issue 8 City of Urbana Charter Amendment", "1", "1")
  touch_at(file.path(d, "20261103results.pdf"), "2026-11-03 20:00")
  touch_at(file.path(d, "20261103results (1).pdf"), "2026-11-03 21:00")
  touch_at(file.path(d, "other.pdf"), "2026-11-03 22:00")
  touch_at(file.path(d, "Precinct Detail.pdf"), "2026-11-03 23:00")
  writeLines("partial", file.path(d, "late.pdf.crdownload"))

  src <- list(race_id = "oh-urbana", adapter = "pdf", contest_pattern = "Urbana.*(charter|data center)")
  expect_equal(basename(find_drop_file(src)), "20261103results (1).pdf")
  # an html_table source ignores PDFs
  expect_null(find_drop_file(modifyList(src, list(adapter = "html_table"))))
})

test_that("files older than DCBT_DROP_SINCE are ignored", {
  d <- new_drop()
  make_pdf(file.path(d, "may.pdf"), "Issue 8 City of Urbana Charter Amendment", "1", "1")
  touch_at(file.path(d, "may.pdf"), "2026-05-05 21:00")
  withr::local_envvar(DCBT_DROP_SINCE = "2026-11-03")
  expect_null(find_drop_file(list(race_id = "oh-urbana", adapter = "pdf", contest_pattern = "Urbana")))
})

test_that("run_adapter reads a dropped PDF for a blocked host and keeps the county URL", {
  d <- new_drop()
  p <- make_pdf(file.path(d, "results.pdf"), "Issue 8 City of Urbana Charter Amendment", "1,204", "868")
  touch_at(p, "2026-11-03 21:15")
  src <- list(race_id = "oh-urbana", adapter = "pdf", contest_pattern = "Urbana.*charter",
              results_url = "https://www.boe.ohio.gov/champaign/",
              api_url = "https://www.boe.ohio.gov/champaign/c/elecres/20261103results.pdf",
              yes_pattern = NA, no_pattern = NA)
  res <- run_adapter(src, list())
  expect_false(inherits(res, "adapter_error"))
  expect_equal(res$yes_votes, 1204L); expect_equal(res$no_votes, 868L)
  expect_equal(res$precincts_reporting, 6L); expect_equal(res$precincts_total, 9L)
  expect_equal(res$source_url, "https://www.boe.ohio.gov/champaign/")
  expect_equal(res$as_of, "2026-11-03T21:15:00-0500")
})

test_that("run_adapter reads a dropped HTML page", {
  d <- new_drop()
  file.copy(fx("county_results.html"), file.path(d, "Index_24.html"))
  src <- list(race_id = "oh-trenton", adapter = "html_table", contest_pattern = "Conneaut",
              results_url = "https://liveresults.boe.ohio.gov/ENR/butlerohenr/24/en/Index_24.html", extra_json = NA)
  res <- run_adapter(src, list())
  expect_equal(res$yes_votes, 1532L); expect_equal(res$no_votes, 971L)
})

test_that("a blocked host with no matching file fails without a network request", {
  d <- new_drop()
  src <- list(race_id = "oh-urbana", adapter = "pdf", contest_pattern = "Urbana",
              results_url = "https://www.boe.ohio.gov/champaign/", api_url = NA)
  res <- suppressMessages(run_adapter(src, list()))
  expect_s3_class(res, "adapter_error")
  expect_match(res$error, "drop folder")
  withr::local_envvar(DCBT_DROP_DIR = file.path(d, "missing"))
  res2 <- suppressMessages(run_adapter(src, list()))
  expect_match(res2$error, "does not exist")
})

test_that("a blocked ENR source with an unfilled ELECTION_ID still reads the drop folder", {
  d <- new_drop()
  file.copy(fx("county_results.html"), file.path(d, "Index.html"))
  src <- list(race_id = "oh-trenton", adapter = "html_table", contest_pattern = "Conneaut", extra_json = NA,
              results_url = "https://liveresults.boe.ohio.gov/ENR/butlerohenr/ELECTION_ID/en/Index_ELECTION_ID.html")
  res <- run_adapter(src, list())
  expect_false(inherits(res, "adapter_error"))
  expect_equal(res$yes_votes, 1532L)
})

test_that("the pdf adapter rejects an HTML page instead of reading it as 0 / 0", {
  d <- new_drop()
  writeLines("<html><title>Website Maintenance</title>Urbana charter</html>", file.path(d, "page.pdf"))
  src <- list(race_id = "oh-urbana", adapter = "pdf", contest_pattern = "Urbana", results_url = "https://e.org/")
  expect_error(adapter_pdf(modifyList(src, list(local_file = file.path(d, "page.pdf")))), "not a PDF")
})

test_that("the pdf adapter skips blank lines (Adams/Hart layout puts Against past line 15)", {
  d <- new_drop()
  p <- file.path(d, "adams.pdf")
  rows <- c("Adams County EMS (Vote for 1)", "Precincts Reported: 21 of 21 (100.00%)", "Total",
            "Times Cast 4,070 / 17,042 23.88%", "Candidate Party Total",
            "For the Tax Levy 1,750", "Against the Tax Levy 2,274", "Total Votes 4,024")
  grDevices::pdf(p, height = 14); graphics::plot.new()
  for (i in seq_along(rows)) graphics::text(0, 1 - i * 0.06, rows[i], adj = 0)  # wide spacing -> blank lines
  grDevices::dev.off()
  res <- adapter_pdf(list(race_id = "t", adapter = "pdf", contest_pattern = "Adams County EMS", local_file = p,
                          results_url = "x", yes_pattern = NA, no_pattern = NA))
  expect_equal(res$yes_votes, 1750L); expect_equal(res$no_votes, 2274L)
  expect_equal(res$precincts_reporting, 21L); expect_equal(res$precincts_total, 21L)
})

test_that("a real Electionware summary (Ashtabula, May 2026) reads the TOTAL column", {
  src <- list(race_id = "t", adapter = "pdf", results_url = "x", yes_pattern = NA, no_pattern = NA,
              local_file = fx("ashtabula_20260505_summary.pdf"))
  a <- adapter_pdf(modifyList(src, list(contest_pattern = "Ashtabula Area CSD Tax Levy")))
  expect_equal(a$yes_votes, 1565L); expect_equal(a$no_votes, 2061L)
  r <- adapter_pdf(modifyList(src, list(contest_pattern = "Rock Creek Public LIbrary")))
  expect_equal(r$yes_votes, 252L); expect_equal(r$no_votes, 176L)
})

test_that("real May 2026 county summaries read the right totals and precincts", {
  cases <- tibble::tribble(~file, ~pattern, ~yes, ~no, ~prec_rep, ~prec_tot,
    "ashtabula", "Ashtabula Area CSD Tax Levy",                    1565L, 2061L, NA,  NA,
    "champaign", "Urbana City School 1% Income Tax",               903L,  1508L, NA,  NA,
    "clinton",   "Wayne Twp Cemetery Levy",                        131L,  56L,   1L,  1L,
    "defiance",  "Defiance County Add'l Levy",                     3275L, 2803L, 33L, 33L,
    "licking",   "Riverview School District - Proposed Tax Levy",  53L,   93L,   NA,  NA,
    "pickaway",  "Southwest Public Libraries",                     5L,    25L,   1L,  1L,
    "wyandot",   "Income Tax Renewal Riverdale",                   158L,  140L,  NA,  NA)
  for (i in seq_len(nrow(cases))) {
    c <- cases[i, ]
    r <- adapter_pdf(list(race_id = c$file, adapter = "pdf", contest_pattern = c$pattern, results_url = "x",
                          yes_pattern = NA, no_pattern = NA, local_file = fx(paste0(c$file, "_20260505_summary.pdf"))))
    expect_equal(c(r$yes_votes, r$no_votes), c(c$yes, c$no), label = c$file)
    expect_equal(c(r$precincts_reporting, r$precincts_total), c(c$prec_rep, c$prec_tot), label = paste(c$file, "precincts"))
  }
})

test_that("precinct phrasing from Clinton/Huron and Defiance is understood", {
  expect_equal(extract_precincts("1 precincts reported out of 1 total"), c(1L, 1L))
  expect_equal(extract_precincts("46 precincts reported out of 46 total"), c(46L, 46L))
  expect_equal(extract_precincts("Number of Precincts 33 Precincts Reporting 30 90.91%"), c(30L, 33L))
})

test_that("NO does not match 'No Valid Petition Filed'", {
  expect_false(str_detect("No Valid Petition Filed 0", regex(NO_RX, ignore_case = TRUE)))
  expect_true(str_detect("No 218", regex(NO_RX, ignore_case = TRUE)))
})
