# Map adapter names in data/sources.csv to functions.
ADAPTERS <- list(
  clarity      = function(src, ctx) adapter_clarity(src),
  enhanced_voting = function(src, ctx) adapter_enhanced_voting(src),
  html_table   = function(src, ctx) adapter_html_table(src),
  json_generic = function(src, ctx) adapter_json_generic(src),
  csv_generic  = function(src, ctx) adapter_csv_generic(src),
  ohio_sos     = function(src, ctx) adapter_ohio_sos(src, ctx$ohio_cache),
  ohio_enr     = function(src, ctx) adapter_ohio_enr(src),
  pdf          = function(src, ctx) adapter_pdf(src),
  franklin_live = function(src, ctx) adapter_franklin_live(src),
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
    # (R/adapters/drop_folder.R) and date the result by that file. The url is
    # never requested, so an unfilled ELECTION_ID in it does not matter.
    if (needs_drop(src)) {
      # Nov 3 evening: boe.ohio.gov began serving the county results PDFs (and
      # Lucas its precinct CSV) to plain requests (no-store, straight from the county), though its pages
      # still answer with a bot challenge. Ask once for the file itself and use
      # it when it is a real PDF holding the contest and is at least as new as
      # the newest dropped file; otherwise the drop folder, as before.
      direct <- direct_file(src)
      dropped <- tryCatch(find_drop_file(src), error = function(e) NULL)
      if (!is.null(direct) && (is.null(dropped) || file.info(dropped)$mtime <= direct$modified)) {
        res <- tryCatch(fn(modifyList(src, list(local_file = direct$path)), ctx), error = function(e) NULL)
        if (!is.null(res) && nrow(res) == 1) {
          res$as_of <- now_iso_at(direct$modified)
          log_msg(src$race_id, ": direct file ", src$api_url)
          return(res)
        }
      }
      src <- resolve_drop_file(src)
      res <- fn(src, ctx)
      if (!is.null(res) && nrow(res) == 1) res$as_of <- now_iso_at(file.info(src$local_file)$mtime)
      res
    } else {
      # Placeholders that discovery (R/adapters/discover.R) has not filled yet
      ph <- str_extract(paste(src$results_url, src$api_url), paste(PLACEHOLDERS, collapse = "|"))
      if (!is.na(ph)) stop(ph, " not discovered yet")
      fn(src, ctx)
    }
  }, error = function(e) {
    cli::cli_alert_danger("{src$race_id} [{src$adapter}] failed: {conditionMessage(e)}")
    attr(e, "race_id") <- src$race_id
    structure(list(error = conditionMessage(e)), class = "adapter_error")
  })
}
