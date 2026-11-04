# ---------------------------------------------------------------------------
# Drop folder: results files a person downloaded in an ordinary browser
# ---------------------------------------------------------------------------
# boe.ohio.gov and friends block every automated client, including Chrome
# driven by chromote (see CLAUDE.md, network facts). For sources on those
# hosts the pipeline makes no request at all; a person opens the county page
# in their own browser and saves the results PDF or page into the drop folder,
# and the source's adapter parses that file instead.
#
# Files are matched to races by content, not by name: the newest file whose
# text matches the source's contest_pattern wins, so "20261103results (3).pdf"
# needs no renaming. PDFs go to pdf sources, .html/.htm to html_table sources.
# Names containing "precinct" or "detail" are skipped, because precinct
# reports repeat the contest heading once per precinct.
#
# Environment:
#   DCBT_DROP_DIR    folder to read (default ~/Downloads/dcbt_drop)
#   DCBT_DIRECT      0 = never request a blocked host's PDF directly (see direct_pdf)
#   DCBT_DROP_SINCE  ignore files modified before this date or datetime,
#                    Eastern (default: election day once it arrives, so a
#                    leftover May PDF is never read as a Nov 3 result)

DROP_HOSTS <- c("boe.ohio.gov", "ohiosos.gov", "liveresults.franklincountyohio.gov")
DROP_ELECTION_DAY <- "2026-11-03"
DROP_EXT <- list(pdf = "pdf", html_table = c("html", "htm"), ohio_enr = c("html", "htm"))

drop_dir <- function() {
  d <- Sys.getenv("DCBT_DROP_DIR")
  path.expand(if (nzchar(d)) d else "~/Downloads/dcbt_drop")
}

drop_since <- function() {
  s <- Sys.getenv("DCBT_DROP_SINCE")
  if (!nzchar(s)) {
    if (Sys.Date() < as.Date(DROP_ELECTION_DAY)) return(as.POSIXct(-Inf))
    s <- DROP_ELECTION_DAY
  }
  as.POSIXct(s, tz = TRACKER_TZ, tryFormats = c("%Y-%m-%d %H:%M", "%Y-%m-%d"))
}

url_host <- function(url) {
  if (is.null(url) || is.na(url)) return(NA_character_)
  tolower(str_match(url, "^[a-z]+://([^/:?#]+)")[, 2])
}

needs_drop <- function(src) {
  hosts <- vapply(list(src$results_url, src$api_url), url_host, character(1))
  hosts <- hosts[!is.na(hosts)]
  any(vapply(hosts, function(h) any(h == DROP_HOSTS | endsWith(h, paste0(".", DROP_HOSTS))), logical(1)))
}

# Text of each dropped file, cached by path + mtime + size so sixteen sources
# scanning the same folder read each PDF once per pass.
.drop_cache <- new.env()
drop_cache_clear <- function() rm(list = ls(.drop_cache), envir = .drop_cache)

drop_text <- function(path) {
  info <- file.info(path)
  key <- paste(path, as.numeric(info$mtime), info$size)
  if (!is.null(.drop_cache[[key]])) return(.drop_cache[[key]])
  # A missing pdftools would otherwise look like "no file matches"
  if (grepl("\\.pdf$", path, ignore.case = TRUE) && !requireNamespace("pdftools", quietly = TRUE)) {
    stop("install.packages('pdftools') to read PDFs in the drop folder")
  }
  txt <- tryCatch({
    if (grepl("\\.pdf$", path, ignore.case = TRUE)) {
      paste(suppressMessages(pdftools::pdf_text(path)), collapse = "\n")
    } else {
      # Matching needs only the contest titles; extracting all text from a
      # 36 MB Lucas page takes minutes, the titles take a second
      raw <- readr::read_file(path)
      titles <- str_match_all(raw, 'class="race-title">([^<]*)')[[1]][, 2]
      if (length(titles)) paste(titles, collapse = "\n") else rvest::html_text2(xml2::read_html(raw))
    }
  }, error = function(e) "")
  assign(key, txt, envir = .drop_cache)
  txt
}

find_drop_file <- function(src, dir = drop_dir()) {
  exts <- DROP_EXT[[src$adapter]]
  if (is.null(exts)) return(NULL)
  files <- list.files(dir, pattern = paste0("\\.(", paste(exts, collapse = "|"), ")$"),
                      ignore.case = TRUE, full.names = TRUE)
  files <- files[!str_detect(basename(files), regex("precinct|detail", ignore_case = TRUE))]
  if (length(files) == 0) return(NULL)
  mtime <- file.info(files)$mtime
  files <- files[mtime >= drop_since()]
  files <- files[order(file.info(files)$mtime, decreasing = TRUE)]
  rx <- regex(src$contest_pattern %||% "", ignore_case = TRUE)
  for (f in files) if (str_detect(drop_text(f), rx)) return(f)
  NULL
}

# Called by run_adapter for sources on DROP_HOSTS: returns src with local_file
# set, or stops with a message that says what to download. The messages leave
# out the folder path: they end up in the public results.json, and on the Mac
# the path names the owner's Google Drive account. `make drop` prints it.
resolve_drop_file <- function(src) {
  dir <- drop_dir()
  if (!dir.exists(dir)) stop("drop folder does not exist (set DCBT_DROP_DIR or create it; make drop shows the path)")
  path <- find_drop_file(src, dir)
  if (is.null(path)) {
    stop("no file in drop folder matches /", src$contest_pattern,
         "/; download the county's cumulative results from ", src$results_url)
  }
  age <- round(as.numeric(difftime(Sys.time(), file.info(path)$mtime, units = "mins")))
  log_msg(src$race_id, ": drop file ", basename(path), " (", age, " min old)")
  src$local_file <- path
  src
}

# One plain request for a pdf source's own file on a blocked host (see
# run_adapter). Returns list(path, modified) when the answer is a PDF, else NULL; no
# retries, and each url is asked once per pass however many races share it.
.direct_cache <- new.env()
direct_pdf <- function(src) {
  # DCBT_DIRECT=0 turns this off (the tests do; so can a worried operator)
  if (identical(Sys.getenv("DCBT_DIRECT"), "0")) return(NULL)
  url <- src$api_url %||% NA_character_
  if (!identical(src$adapter, "pdf") || is.na(url) || !grepl("^https?://", url)) return(NULL)
  if (exists(url, envir = .direct_cache, inherits = FALSE)) return(get(url, envir = .direct_cache))
  path <- tempfile(fileext = ".pdf")
  out <- tryCatch({
    resp <- base_request(url, timeout = 20, tries = 1) |>
      httr2::req_error(is_error = function(r) FALSE) |>
      httr2::req_perform(path = path)
    if (httr2::resp_status(resp) == 200 && identical(readBin(path, "raw", 5), charToRaw("%PDF-"))) {
      # dated by the county's Last-Modified, like a dropped file by its mtime
      lm <- httr2::resp_header(resp, "last-modified")
      t <- if (is.null(lm)) NA else as.POSIXct(lm, format = "%a, %d %b %Y %H:%M:%S", tz = "GMT")
      list(path = path, modified = if (is.na(t)) Sys.time() else t)
    } else NULL
  }, error = function(e) NULL)
  assign(url, out, envir = .direct_cache)
  out
}
