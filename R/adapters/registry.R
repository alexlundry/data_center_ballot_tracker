# Map adapter names in data/sources.csv to functions.
ADAPTERS <- list(
  clarity      = function(src, ctx) adapter_clarity(src),
  html_table   = function(src, ctx) adapter_html_table(src),
  json_generic = function(src, ctx) adapter_json_generic(src),
  csv_generic  = function(src, ctx) adapter_csv_generic(src),
  ohio_sos     = function(src, ctx) adapter_ohio_sos(src, ctx$ohio_cache),
  pdf          = function(src, ctx) adapter_pdf(src),
  sheet        = function(src, ctx) adapter_sheet(src),
  manual       = function(src, ctx) adapter_manual(src, ctx$manual_tbl)
)

run_adapter <- function(src, ctx) {
  fn <- ADAPTERS[[src$adapter]]
  if (is.null(fn)) {
    cli::cli_warn("{src$race_id}: unknown adapter '{src$adapter}'")
    return(NULL)
  }
  tryCatch({
    # Blocked hosts: parse the newest matching file from the drop folder
    # (R/adapters/drop_folder.R) and date the result by that file.
    if (needs_drop(src)) {
      src <- resolve_drop_file(src)
      res <- fn(src, ctx)
      if (!is.null(res) && nrow(res) == 1) res$as_of <- now_iso_at(file.info(src$local_file)$mtime)
      res
    } else fn(src, ctx)
  }, error = function(e) {
    cli::cli_alert_danger("{src$race_id} [{src$adapter}] failed: {conditionMessage(e)}")
    attr(e, "race_id") <- src$race_id
    structure(list(error = conditionMessage(e)), class = "adapter_error")
  })
}
