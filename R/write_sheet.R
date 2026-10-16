# ---------------------------------------------------------------------------
# Optional: push the latest results straight into the election-night Google
# Sheet (tab live_results) so the people entering numbers by hand see what
# the automated feeds already have, with no refresh lag.
#
# Needs a Google service account that has been given Editor access to the
# sheet. Set two environment variables (GitHub: repository secrets, passed
# through in update-results.yml):
#   GOOGLE_SA_JSON   the service account key file contents (JSON)
#   RESULTS_SHEET_ID the spreadsheet id (the long token in its URL)
# Without them this script does nothing, and the sheet falls back to its
# IMPORTDATA formula, which Google refreshes about hourly.
# ---------------------------------------------------------------------------
push_results_to_sheet <- function(csv_path = "site/data/results.csv") {
  key <- Sys.getenv("GOOGLE_SA_JSON"); sheet_id <- Sys.getenv("RESULTS_SHEET_ID")
  if (!nzchar(key) || !nzchar(sheet_id)) return(invisible(FALSE))
  if (!requireNamespace("googlesheets4", quietly = TRUE)) {
    cli::cli_alert_warning("googlesheets4 not installed; skipping sheet write-back"); return(invisible(FALSE))
  }
  tryCatch({
    key_file <- tempfile(fileext = ".json"); writeLines(key, key_file)
    googlesheets4::gs4_auth(path = key_file)
    flat <- readr::read_csv(csv_path, show_col_types = FALSE, col_types = readr::cols(.default = readr::col_character()))
    flat[is.na(flat)] <- ""
    # Replace the IMPORTDATA formula with plain values; the layout is identical
    # (same columns in the same order), so the auto_ lookups keep working.
    googlesheets4::range_clear(sheet_id, sheet = "live_results", range = "A1:Z300", reformat = FALSE)
    googlesheets4::range_write(sheet_id, flat, sheet = "live_results", range = "A1", col_names = TRUE, reformat = FALSE)
    cli::cli_alert_success("wrote {nrow(flat)} rows to the live_results tab")
    invisible(TRUE)
  }, error = function(e) { cli::cli_alert_warning("sheet write-back failed: {conditionMessage(e)}"); invisible(FALSE) })
}
