#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------
# Build site/data/races.json from data/races.csv + data/sources.csv
# ---------------------------------------------------------------------------
# Run after any edit to the registry. Validates required fields and warns
# about races with no results source or no coordinates.

suppressMessages({ source("R/packages.R"); source("R/utils.R") })

races <- readr::read_csv("data/races.csv", show_col_types = FALSE,
                         col_types = readr::cols(.default = readr::col_character())) |>
  mutate(across(everything(), ~ na_if(str_trim(.x), "")))
sources <- readr::read_csv("data/sources.csv", show_col_types = FALSE,
                           col_types = readr::cols(.default = readr::col_character())) |>
  mutate(across(everything(), ~ na_if(str_trim(.x), "")))

required <- c("race_id", "state", "jurisdiction", "level", "election_date", "title",
              "measure_type", "yes_means", "status", "lat", "lon")
missing <- setdiff(required, names(races))
if (length(missing)) stop("races.csv is missing columns: ", paste(missing, collapse = ", "))

dupes <- races$race_id[duplicated(races$race_id)]
if (length(dupes)) stop("duplicate race_id: ", paste(dupes, collapse = ", "))

bad_dir <- races |> filter(!yes_means %in% c("restrict", "allow"))
if (nrow(bad_dir)) stop("yes_means must be restrict/allow: ", paste(bad_dir$race_id, collapse = ", "))

no_coords <- races |> filter(is.na(lat) | is.na(lon))
if (nrow(no_coords)) cli::cli_alert_warning("no coordinates: {paste(no_coords$race_id, collapse = ', ')}")

src_summary <- sources |>
  filter(tolower(coalesce(enabled, "true")) %in% c("true", "t", "yes", "y", "1")) |>
  group_by(race_id) |>
  summarise(adapters = paste(unique(adapter), collapse = ","),
            source_status = first(coalesce(source_status, "unverified")), .groups = "drop")

no_src <- races |> filter(election_date == "2026-11-03", !race_id %in% src_summary$race_id)
if (nrow(no_src)) cli::cli_alert_warning("no results source yet: {paste(no_src$race_id, collapse = ', ')}")

out <- races |>
  left_join(src_summary, by = "race_id") |>
  mutate(lat = as.numeric(lat), lon = as.numeric(lon),
         threshold_mw = suppressWarnings(as.numeric(threshold_mw)),
         adapters = coalesce(adapters, ""),
         source_status = coalesce(source_status, "none"))

not_on_ballot <- if (file.exists("data/not_on_ballot.csv")) {
  readr::read_csv("data/not_on_ballot.csv", show_col_types = FALSE,
                  col_types = readr::cols(.default = readr::col_character()))
} else tibble()

jsonlite::write_json(
  list(generated_at = now_iso(), count = nrow(out), races = out, not_on_ballot = not_on_ballot),
  "site/data/races.json", auto_unbox = TRUE, na = "null", pretty = TRUE, digits = NA
)
cli::cli_alert_success("wrote site/data/races.json ({nrow(out)} races)")
