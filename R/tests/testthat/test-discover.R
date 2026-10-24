find_root <- function(start = getwd()) {
  d <- normalizePath(start)
  for (i in 1:6) { if (file.exists(file.path(d, "R", "packages.R"))) return(d); d <- dirname(d) }
  stop("repo root not found")
}
ROOT <- find_root()
suppressMessages({ source(file.path(ROOT, "R/packages.R")); source(file.path(ROOT, "R/utils.R"))
  for (f in list.files(file.path(ROOT, "R/adapters"), pattern = "\\.R$", full.names = TRUE)) source(f) })

CLARITY_NOV3 <- '"EID":"(\\d+)","ElectionName":"[^"]*","Date":"11/3/2026'

# Page texts in the shape of the live pages (Oct 23, 2026), with a Nov 3 entry added.
CLARITY_JSON <- paste0('[{"State":"IL","County":"Madison","EID":"127001","ElectionName":"2026 General Election","Date":"11/3/2026 12:00:00 AM"},',
                       '{"State":"IL","County":"Madison","EID":"126058","ElectionName":"2026 General Primary Election","Date":"3/17/2026 12:00:00 AM"}]')
GBS_PAGE <- paste0('<a href="county_results.asp?id=7190">NOVEMBER 3, 2026 - GENERAL ELECTION - ** UNOFFICIAL RESULTS **</a>',
                   '<a href="county_results.asp?id=7104">MARCH 17, 2026 - GENERAL PRIMARY ELECTION - ** OFFICIAL RESULTS **</a>')
VOLUSIA_PAGE <- '<p><a href="https://enr.electionsfl.org/VOL/4052/Summary/">Election Night Results</a></p>'
TRUMBULL_PAGE <- paste0('<a href="pdfs/Election Summary110326.pdf">Nov</a><a href="pdfs/Election Summary050526.pdf">May</a>',
                        '<a href="pdfs/Election Results 11042025.pdf">2025</a><a href="pdfs/Voter%20FAQ.pdf">FAQ</a>')

src_row <- function(...) {
  tibble(race_id = "x", priority = 1L, adapter = "clarity", results_url = "https://example.org/",
         api_url = "https://results.enr.clarityelections.com/IL/Madison/ELECTION_ID",
         discover_url = "https://results.enr.clarityelections.com/IL/Madison/elections.json?v=1",
         discover_pattern = CLARITY_NOV3, discover_pick = "first") |> mutate(...)
}
fake_fetch <- function(pages) function(url, ...) {
  if (is.null(pages[[url]])) stop("HTTP 404 Not Found.")
  pages[[url]]
}

test_that("the registry's patterns find the Nov 3 entry on each kind of page", {
  expect_equal(discover_value(CLARITY_JSON, CLARITY_NOV3), "127001")
  expect_equal(discover_value(GBS_PAGE, 'county_results\\.asp\\?id=(\\d+)"[^>]*>\\s*NOVEMBER 3, 2026'), "7190")
  expect_equal(discover_value(VOLUSIA_PAGE, "enr\\.electionsfl\\.org/VOL/(\\d+)/"), "4052")
  trumbull <- 'href="(pdfs/[^"]*(?:Summary|Results)[^"]*(?:11-?0?3-?(?:20)?26|2026-11-0?3)[^"]*\\.pdf)"'
  expect_equal(discover_value(TRUMBULL_PAGE, trumbull, base_url = "https://boe.co.trumbull.oh.gov/boe_results.html"),
               "https://boe.co.trumbull.oh.gov/pdfs/Election%20Summary110326.pdf")
  # before the county posts Nov 3, nothing matches
  expect_true(is.na(discover_value(str_remove(TRUMBULL_PAGE, '<a href="pdfs/Election Summary110326.pdf">Nov</a>'), trumbull)))
})

test_that("discover_pick chooses first, last or the largest number", {
  txt <- "id=12 id=40 id=7"
  expect_equal(discover_value(txt, "id=(\\d+)", "first"), "12")
  expect_equal(discover_value(txt, "id=(\\d+)", "last"), "7")
  expect_equal(discover_value(txt, "id=(\\d+)", "max"), "40")
  expect_equal(discover_value('<a href="/x?a=1&amp;b=2">', 'href="([^"]+)"', base_url = "https://h.org/p/"),
               "https://h.org/x?a=1&b=2")
})

test_that("placeholders are filled, shared pages fetched once, and the cache written", {
  cache <- tempfile(fileext = ".json")
  calls <- 0
  pages <- list("https://results.enr.clarityelections.com/IL/Madison/elections.json?v=1" = CLARITY_JSON)
  f <- fake_fetch(pages); counting <- function(url, ...) { calls <<- calls + 1; f(url) }
  srcs <- bind_rows(src_row(race_id = "il-chouteau-twp"), src_row(race_id = "il-venice-twp"),
                    src_row(race_id = "nv-boulder-city", api_url = "https://fixed.example/", discover_url = NA))
  out <- suppressMessages(discover_placeholders(srcs, cache_path = cache, fetch = counting))
  expect_equal(out$api_url[1:2], rep("https://results.enr.clarityelections.com/IL/Madison/127001", 2))
  expect_equal(out$api_url[3], "https://fixed.example/")
  expect_equal(calls, 1)
  cached <- jsonlite::fromJSON(cache)
  expect_setequal(cached$race_id, c("il-chouteau-twp", "il-venice-twp"))
  expect_equal(unique(cached$value), "127001")
})

test_that("a failed fetch keeps the last good value, and an unchanged value does not rewrite the cache", {
  cache <- tempfile(fileext = ".json")
  url <- "https://results.enr.clarityelections.com/IL/Madison/elections.json?v=1"
  suppressMessages(discover_placeholders(src_row(), cache_path = cache, fetch = fake_fetch(setNames(list(CLARITY_JSON), url))))
  first_write <- file.info(cache)$mtime
  Sys.setFileTime(cache, first_write - 60)
  suppressMessages(discover_placeholders(src_row(), cache_path = cache, fetch = fake_fetch(setNames(list(CLARITY_JSON), url))))
  expect_equal(file.info(cache)$mtime, first_write - 60)
  out <- suppressMessages(discover_placeholders(src_row(), cache_path = cache, fetch = fake_fetch(list())))
  expect_equal(out$api_url, "https://results.enr.clarityelections.com/IL/Madison/127001")
})

test_that("probe mode walks an id range once and then trusts the cache", {
  cache <- tempfile(fileext = ".json")
  tpl <- "https://results.lavote.gov/electionresults/json?electionid={n}"
  pages <- list("https://results.lavote.gov/electionresults/json?electionid=4339" = '"Election ID: 4339 returned no data."',
                "https://results.lavote.gov/electionresults/json?electionid=4341" = '{"Election":{"ID":4341,"Date":"2026-11-03T00:00:00-08:00"}}')
  calls <- 0; f <- fake_fetch(pages); counting <- function(url, ...) { calls <<- calls + 1; f(url) }
  s <- src_row(race_id = "ca-alhambra", api_url = "https://results.lavote.gov/electionresults/json?electionid=ELECTION_ID",
               discover_url = tpl, discover_pattern = '"Date"\\s*:\\s*"2026-11-03', discover_pick = "probe:4339-4345")
  out <- suppressMessages(discover_placeholders(s, cache_path = cache, fetch = counting))
  expect_equal(out$api_url, "https://results.lavote.gov/electionresults/json?electionid=4341")
  expect_equal(calls, 3)
  suppressMessages(discover_placeholders(s, cache_path = cache, fetch = counting))
  expect_equal(calls, 3)
})

test_that("run_adapter refuses a source whose placeholder is still unfilled", {
  res <- suppressMessages(run_adapter(list(race_id = "x", adapter = "clarity", results_url = "https://e.org/",
                                           api_url = "https://results.enr.clarityelections.com/IL/Will/ELECTION_ID"), list()))
  expect_s3_class(res, "adapter_error")
  expect_match(res$error, "ELECTION_ID not discovered yet")
})
