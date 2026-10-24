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
#   DCBT_DROP_SINCE  ignore files modified before this date or datetime,
#                    Eastern (default: election day once it arrives, so a
#                    leftover May PDF is never read as a Nov 3 result)

DROP_HOSTS <- c("boe.ohio.gov", "ohiosos.gov", "liveresults.franklincountyohio.gov")
DROP_ELECTION_DAY <- "2026-11-03"
DROP_EXT <- list(pdf = "pdf", html_table = c("html", "htm"))

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
  txt <- tryCatch({
    if (grepl("\\.pdf$", path, ignore.case = TRUE)) {
      paste(suppressMessages(pdftools::pdf_text(path)), collapse = "\n")
    } else {
      rvest::html_text2(xml2::read_html(path))
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
# set, or stops with a message that says what to download.
resolve_drop_file <- function(src) {
  dir <- drop_dir()
  if (!dir.exists(dir)) stop("drop folder ", dir, " does not exist (set DCBT_DROP_DIR or create it)")
  path <- find_drop_file(src, dir)
  if (is.null(path)) {
    stop("no file in drop folder ", dir, " matches /", src$contest_pattern,
         "/; download the county's cumulative results from ", src$results_url)
  }
  age <- round(as.numeric(difftime(Sys.time(), file.info(path)$mtime, units = "mins")))
  log_msg(src$race_id, ": drop file ", basename(path), " (", age, " min old)")
  src$local_file <- path
  src
}
