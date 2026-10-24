# ---------------------------------------------------------------------------
# Discovery: fill ELECTION_ID / PDF_URL placeholders in data/sources.csv
# ---------------------------------------------------------------------------
# Counties publish the Nov 3 election id or results PDF only once they set the
# election up (Clarity, LA County, Volusia, GBS) or post the file (Trumbull,
# Delaware). Rather than pasting each one on the night, a source can say where
# to look:
#
#   discover_url      page to read once per pass (shared by every source that
#                     names it), or for probe mode a template with {n}
#   discover_pattern  regex; capture group 1 is the value (a whole match when
#                     there is no group). Relative links are made absolute.
#   discover_pick     first | last | max (largest number in the value) |
#                     probe:<from>-<to>: try {n} = from..to, value = the first
#                     n whose response matches the pattern
#
# The value replaces ELECTION_ID or PDF_URL in results_url and api_url. Found
# values are cached in data/discovered.json (gitignored) so a failed fetch
# keeps the last good value; probe values are never re-probed. The cache file
# is rewritten only when a value changes.

DISCOVER_PATH <- "data/discovered.json"
PLACEHOLDERS <- c("ELECTION_ID", "PDF_URL")

discover_value <- function(text, pattern, pick = "first", base_url = NULL) {
  m <- str_match_all(text %||% "", pattern)[[1]]
  if (nrow(m) == 0) return(NA_character_)
  vals <- if (ncol(m) > 1) apply(m[, -1, drop = FALSE], 1, function(r) r[!is.na(r)][1]) else m[, 1]
  vals <- unique(vals[!is.na(vals)])
  if (length(vals) == 0) return(NA_character_)
  v <- switch(pick %||% "first",
              first = vals[1],
              last = vals[length(vals)],
              max = vals[which.max(as.numeric(str_extract(vals, "\\d+")))],
              stop("unknown discover_pick: ", pick))
  if (!str_detect(v, "^\\d+$")) {
    v <- str_replace_all(v, fixed("&amp;"), "&") |> str_replace_all(" ", "%20")
    if (!is.null(base_url)) v <- xml2::url_absolute(v, base_url)
  }
  v
}

discover_probe <- function(template, pattern, range, fetch = fetch_text) {
  bounds <- as.integer(str_match(range, "^(\\d+)-(\\d+)$")[, 2:3])
  if (anyNA(bounds)) stop("probe range must look like probe:4339-4370, got probe:", range)
  for (n in seq(bounds[1], bounds[2])) {
    txt <- tryCatch(fetch(str_replace(template, fixed("{n}"), n), tries = 1), error = function(e) "")
    if (str_detect(txt, pattern)) return(as.character(n))
  }
  NA_character_
}

read_discovered <- function(path) {
  empty <- tibble(race_id = character(), priority = integer(), placeholder = character(),
                  value = character(), found_at = character())
  if (!file.exists(path)) return(empty)
  tryCatch(as_tibble(jsonlite::fromJSON(path)) |> mutate(priority = as.integer(priority)),
           error = function(e) empty)
}

discover_placeholders <- function(sources, cache_path = DISCOVER_PATH, fetch = fetch_text) {
  for (col in c("discover_url", "discover_pattern", "discover_pick")) {
    if (!col %in% names(sources)) sources[[col]] <- NA_character_
  }
  ph_rx <- paste(PLACEHOLDERS, collapse = "|")
  todo <- which(!is.na(sources$discover_url) & !is.na(sources$discover_pattern) &
                (str_detect(coalesce(sources$results_url, ""), ph_rx) | str_detect(coalesce(sources$api_url, ""), ph_rx)))
  if (length(todo) == 0) return(sources)

  cache <- read_discovered(cache_path)
  changed <- FALSE
  pages <- list()
  page <- function(url) {
    if (is.null(pages[[url]])) {
      pages[[url]] <<- tryCatch(fetch(url), error = function(e) {
        log_msg("discover: ", url, " failed (", conditionMessage(e), ")"); NA_character_
      })
    }
    pages[[url]]
  }

  for (i in todo) {
    s <- sources[i, ]
    ph <- str_extract(paste(s$results_url, s$api_url), ph_rx)
    hit <- cache |> filter(race_id == s$race_id, priority == as.integer(s$priority), placeholder == ph)
    cached <- if (nrow(hit)) hit$value[1] else NA_character_
    pick <- coalesce(s$discover_pick, "first")

    value <- if (str_starts(pick, "probe:")) {
      if (!is.na(cached)) cached else discover_probe(s$discover_url, s$discover_pattern, str_remove(pick, "^probe:"), fetch)
    } else {
      txt <- page(s$discover_url)
      if (is.na(txt)) NA_character_ else discover_value(txt, s$discover_pattern, pick, base_url = s$discover_url)
    }

    if (is.na(value)) {
      if (!is.na(cached)) log_msg(s$race_id, ": ", ph, " not on ", s$discover_url, " now; keeping ", cached)
      value <- cached
    } else if (!identical(value, cached)) {
      log_msg(s$race_id, ": discovered ", ph, " = ", value, if (!is.na(cached)) paste0(" (was ", cached, ")"))
      cache <- cache |> filter(!(race_id == s$race_id & priority == as.integer(s$priority) & placeholder == ph)) |>
        bind_rows(tibble(race_id = s$race_id, priority = as.integer(s$priority), placeholder = ph,
                         value = value, found_at = now_iso()))
      changed <- TRUE
    }
    if (!is.na(value)) {
      sources$results_url[i] <- str_replace_all(sources$results_url[i], ph, value)
      sources$api_url[i] <- str_replace_all(sources$api_url[i], ph, value)
    }
  }
  if (changed) jsonlite::write_json(cache |> arrange(race_id, priority), cache_path, pretty = TRUE, auto_unbox = TRUE)
  sources
}
