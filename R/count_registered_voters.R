#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------
# Count registered voters for each Ohio data center measure from the Ohio
# Secretary of State county voter files.
#
# The files come from https://www6.ohiosos.gov/ords/f?p=VOTERFTP:HOME
# ("Download Files" > county files). Download the counties listed in
# OHIO_JURISDICTIONS below into one folder, then run:
#
#   Rscript R/count_registered_voters.R <folder> [--only WYANDOT] [--write-sheet] [--sheet <id>]
#
# --only <text> reads just the files whose name contains <text> and merges the
# result into an existing data/registered_voters_ohio.csv (handy for re-running
# one county after adjusting a match rule).
#
# Output: data/registered_voters_ohio.csv (one row per race_id) and a summary
# in the console. With --write-sheet, the counts are also written to the
# manual_results tab of the election-night Google Sheet (columns G and Y),
# using googlesheets4 with an interactive login.
#
# Counting rules
#   city / village  : rows whose CITY (or VILLAGE) column names the place
#   township        : rows whose TOWNSHIP names the township and whose CITY
#                     and VILLAGE are blank (the unincorporated area, which is
#                     what votes on an ORC 519 zoning plan)
#   registered_total  = every row in the file for the jurisdiction
#   registered_active = rows with VOTER_STATUS == ACTIVE
# If the place columns give zero rows, the script falls back to PRECINCT_NAME
# starting with the place name and says so in match_rule.
# ---------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(readr); library(dplyr); library(purrr); library(stringr); library(tibble); library(tidyr)
})

args <- commandArgs(trailingOnly = TRUE)
write_sheet <- "--write-sheet" %in% args
only <- if ("--only" %in% args) args[which(args == "--only") + 1] else NA_character_
sheet_id <- if ("--sheet" %in% args) args[which(args == "--sheet") + 1] else
  (if (nzchar(Sys.getenv("RESULTS_SHEET_ID"))) Sys.getenv("RESULTS_SHEET_ID") else "1jma2RqwyFNB8dP23f0nM4LCRti54uBJBoqEIktR9fRs")
dir <- setdiff(args, c("--write-sheet", "--sheet", sheet_id, "--only", only))[1]
if (is.na(dir) || !dir.exists(dir)) stop("Give the folder that holds the county voter files, e.g. Rscript R/count_registered_voters.R ~/Downloads/ohio-voter-files")

# race_id -> county number (Ohio counties numbered alphabetically 1-88), place
# type and name as it appears in the CITY / VILLAGE / TOWNSHIP columns.
OHIO_JURISDICTIONS <- tribble(
  ~race_id,            ~county,      ~county_number, ~type,       ~name,            ~precinct_rx,
  "oh-sprigg-twp",     "Adams",      1,  "township", "SPRIGG",         NA,
  "oh-monroe-twp",     "Adams",      1,  "township", "MONROE", NA,
  "oh-conneaut",       "Ashtabula",  4,  "city",     "CONNEAUT", NA,
  "oh-trenton",        "Butler",     9,  "city",     "TRENTON", NA,
  "oh-urbana",         "Champaign",  11, "city",     "URBANA", NA,
  "oh-wilmington-1",   "Clinton",    14, "city",     "WILMINGTON", NA,
  "oh-wilmington-2",   "Clinton",    14, "city",     "WILMINGTON", NA,
  "oh-wilmington-3",   "Clinton",    14, "city",     "WILMINGTON", NA,
  "oh-wilmington-4",   "Clinton",    14, "city",     "WILMINGTON", NA,
  "oh-defiance",       "Defiance",   20, "city",     "DEFIANCE", NA,
  "oh-sunbury",        "Delaware",   21, "city",     "SUNBURY", NA,
  "oh-grove-city",     "Franklin",   25, "city",     "GROVE CITY", "^GROVE CITY",
  "oh-monroeville",    "Huron",      39, "village",  "MONROEVILLE", NA,
  "oh-perry-village",  "Lake",       43, "village",  "PERRY", NA,
  "oh-pataskala",      "Licking",    45, "city",     "PATASKALA", NA,
  "oh-granville",      "Licking",    45, "village",  "GRANVILLE", NA,
  "oh-oregon",         "Lucas",      48, "city",     "OREGON", NA,
  "oh-ashville",       "Pickaway",   65, "village",  "ASHVILLE", NA,
  "oh-hubbard",        "Trumbull",   78, "city",     "HUBBARD", NA,
  "oh-upper-sandusky", "Wyandot",    88, "city",     "UPPER SANDUSKY", "UPPER\\s*SAND|U\\.?\\s*SANDUSKY|UPR\\s*SAND"
)

WANT <- c("COUNTY_NUMBER", "VOTER_STATUS", "CITY", "VILLAGE", "TOWNSHIP", "PRECINCT_NAME", "PRECINCT_CODE")

# "GROVE CITY CITY" / "PERRY VILLAGE" / "SPRIGG TOWNSHIP" -> "GROVE CITY" / "PERRY" / "SPRIGG"
norm_place <- function(x) {
  x <- str_to_upper(str_squish(coalesce(x, "")))
  str_squish(str_remove(x, "\\s+(CITY|VILLAGE|TOWNSHIP|TWP)$"))
}

read_county_file <- function(path) {
  hdr <- names(read_csv(path, n_max = 0, show_col_types = FALSE, progress = FALSE))
  names(hdr) <- str_to_upper(hdr)
  keep <- hdr[intersect(WANT, names(hdr))]
  if (!all(c("CITY", "VILLAGE", "TOWNSHIP") %in% names(keep))) {
    message("  skipping ", basename(path), ": no CITY / VILLAGE / TOWNSHIP columns (is this an SOS voter file?)")
    return(NULL)
  }
  df <- read_csv(path, col_select = all_of(unname(keep)), col_types = cols(.default = col_character()),
                 show_col_types = FALSE, progress = FALSE)
  names(df) <- str_to_upper(names(df))
  df |>
    mutate(across(any_of(c("CITY", "VILLAGE", "TOWNSHIP")), norm_place),
           VOTER_STATUS = str_to_upper(str_squish(coalesce(.data$VOTER_STATUS %||% "", ""))),
           COUNTY_NUMBER = suppressWarnings(as.integer(.data$COUNTY_NUMBER %||% NA)),
           source_file = basename(path))
}
`%||%` <- function(a, b) if (is.null(a)) b else a

count_one <- function(df, j) {
  rows <- switch(j$type,
    city     = df |> filter(CITY == j$name | VILLAGE == j$name),
    village  = df |> filter(VILLAGE == j$name | CITY == j$name),
    township = df |> filter(TOWNSHIP == j$name, CITY == "", VILLAGE == ""))
  rule <- switch(j$type, city = "CITY/VILLAGE column", village = "VILLAGE/CITY column",
                 township = "TOWNSHIP column, unincorporated (CITY and VILLAGE blank)")
  if (nrow(rows) == 0 && "PRECINCT_NAME" %in% names(df)) {
    pn <- str_to_upper(coalesce(df$PRECINCT_NAME, ""))
    if (!is.na(j$precinct_rx)) {
      rows <- df |> filter(str_detect(pn, regex(j$precinct_rx)))
      rule <- paste0("fallback: PRECINCT_NAME matches /", j$precinct_rx, "/")
    } else {
      rows <- df |> filter(str_starts(pn, fixed(j$name)))
      rule <- "fallback: PRECINCT_NAME prefix"
    }
  }
  tibble(race_id = j$race_id, jurisdiction = j$name, county = j$county,
         registered_total = nrow(rows),
         registered_active = sum(rows$VOTER_STATUS == "ACTIVE"),
         registered_confirmation = sum(rows$VOTER_STATUS != "ACTIVE"),
         match_rule = rule, source_file = if (nrow(df)) df$source_file[1] else NA_character_)
}

files <- list.files(dir, pattern = "\\.(txt|csv)$", full.names = TRUE, ignore.case = TRUE)
if (!is.na(only)) files <- files[str_detect(str_to_upper(basename(files)), fixed(str_to_upper(only)))]
if (!length(files)) stop("No .txt or .csv files in ", dir)
message("Reading ", length(files), " file(s) from ", dir)

results <- list(); county_totals <- list()
for (f in files) {
  message("- ", basename(f))
  df <- read_county_file(f)
  if (is.null(df)) next
  cn <- suppressWarnings(as.integer(names(sort(table(df$COUNTY_NUMBER), decreasing = TRUE))[1]))
  js <- OHIO_JURISDICTIONS |> filter(is.na(cn) | county_number == cn)
  if (!nrow(js)) { message("  county number ", cn, " has no measures in the registry; skipped"); next }
  county_totals[[basename(f)]] <- tibble(source_file = basename(f), county_number = cn, county_total = nrow(df),
                                         county_active = sum(df$VOTER_STATUS == "ACTIVE"))
  for (i in seq_len(nrow(js))) {
    j <- js[i, ]
    out <- count_one(df, j)
    if (out$registered_total == 0) {
      near <- unique(c(df$CITY, df$VILLAGE, df$TOWNSHIP))
      near <- near[str_detect(near, fixed(word(j$name, 1)))]
      message("  ", j$race_id, ": no rows matched ", j$name, "; similar values in the file: ",
              if (length(near)) paste(head(near, 8), collapse = " | ") else "(none)")
      if ("PRECINCT_NAME" %in% names(df)) {
        pcs <- sort(unique(str_to_upper(coalesce(df$PRECINCT_NAME, ""))))
        message("  precinct names in this file (", length(pcs), "): ", paste(head(pcs, 60), collapse = " | "))
        plc <- df |> count(CITY, VILLAGE, TOWNSHIP, sort = TRUE) |> head(15)
        message("  place columns (CITY / VILLAGE / TOWNSHIP -> voters): ",
                paste(sprintf("%s / %s / %s -> %d", plc$CITY, plc$VILLAGE, plc$TOWNSHIP, plc$n), collapse = " | "))
      }
    }
    results[[length(results) + 1]] <- out
  }
}
res <- bind_rows(results)
if (!nrow(res)) stop("Nothing counted. Check that the folder holds the SOS county files.")
res <- OHIO_JURISDICTIONS |> select(race_id) |> left_join(res, by = "race_id") |>
  mutate(counted_at = format(Sys.time(), "%Y-%m-%d"),
         note = if_else(is.na(registered_total), "county file not found in folder", ""))

out_path <- "data/registered_voters_ohio.csv"
if (!is.na(only) && file.exists(out_path)) {
  prev <- read_csv(out_path, col_types = cols(.default = col_character()), show_col_types = FALSE) |>
    mutate(across(c(registered_total, registered_active, registered_confirmation), as.integer))
  fresh <- res |> filter(!is.na(registered_total))
  res <- bind_rows(fresh, prev |> filter(!race_id %in% fresh$race_id)) |>
    arrange(match(race_id, OHIO_JURISDICTIONS$race_id))
}
write_csv(res, out_path, na = "")
message("\nWrote ", out_path)
print(as.data.frame(res |> select(race_id, county, registered_total, registered_active, match_rule, note)), row.names = FALSE, right = FALSE)
if (length(county_totals)) { message("\nCounty totals (for reference):"); print(as.data.frame(bind_rows(county_totals)), row.names = FALSE, right = FALSE) }

if (write_sheet) {
  if (!requireNamespace("googlesheets4", quietly = TRUE)) stop("install.packages('googlesheets4') first")
  googlesheets4::gs4_auth()
  ids <- googlesheets4::read_sheet(sheet_id, sheet = "manual_results", range = "A:A", col_types = "c")$race_id
  cur <- googlesheets4::read_sheet(sheet_id, sheet = "manual_results", range = "G:G", col_types = "c")[[1]]
  src <- googlesheets4::read_sheet(sheet_id, sheet = "manual_results", range = "Y:Y", col_types = "c")[[1]]
  length(cur) <- length(ids); length(src) <- length(ids)
  got <- res |> filter(!is.na(registered_total), registered_total > 0)
  for (i in seq_len(nrow(got))) {
    k <- match(got$race_id[i], ids); if (is.na(k)) next
    cur[k] <- as.character(got$registered_total[i])
    src[k] <- sprintf("Ohio Secretary of State county voter file (%s), counted %s: %s registered (%s active). Rule: %s.",
                      got$source_file[i], got$counted_at[i], format(got$registered_total[i], big.mark = ","),
                      format(got$registered_active[i], big.mark = ","), got$match_rule[i])
  }
  n <- length(ids)
  googlesheets4::range_write(sheet_id, tibble(registered_voters = cur), sheet = "manual_results",
                             range = sprintf("G2:G%d", n + 1), col_names = FALSE, reformat = FALSE)
  googlesheets4::range_write(sheet_id, tibble(registered_voters_source = src), sheet = "manual_results",
                             range = sprintf("Y2:Y%d", n + 1), col_names = FALSE, reformat = FALSE)
  message("Wrote ", nrow(got), " counts to the sheet (columns G and Y of manual_results).")
}
