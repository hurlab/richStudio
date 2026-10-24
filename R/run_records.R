# Versioned, read-only run records (SPEC-WS-006): the adapter manifest and result
# leaves (007/008) read. The exported form is canonical: records read exactly as they
# will read back after any save, in RDS and JSON alike, because both formats carry the
# same JSON string field `run_records_json`.

workspace_run_record_fields <- c("schema", "version", "run_id", "kind", "state", "created", "queued_at",
                                 "started", "ended", "settings", "inputs", "outputs", "retry_of",
                                 "imported_from", "note", "error_summary")

workspace_run_record_time <- function(x) {
  if (is.null(x) || length(x) != 1L || is.na(x)) return(NA_character_)
  if (is.character(x)) return(x)
  format(as.POSIXct(x), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

# Data only: no PID, handle, future, closure, session, environment or external pointer.
workspace_run_record_export <- function(record) {
  list(schema = "richstudio.run_record", version = 1L, run_id = record$run_id, kind = record$kind,
       state = record$state, created = workspace_run_record_time(record$created),
       queued_at = workspace_run_record_time(record$queued_at),
       started = workspace_run_record_time(record$started), ended = workspace_run_record_time(record$ended),
       settings = record$settings, inputs = record$inputs, outputs = record$outputs,
       retry_of = record$retry_of, imported_from = record$imported_from, note = record$note,
       error_summary = record$error_summary)
}

# Every character element is repaired: a declared encoding is converted first, then
# bytes that are still invalid become "?".
workspace_run_records_repair <- function(x) {
  rapply(x, function(s) iconv(enc2utf8(s), "UTF-8", "UTF-8", sub = "?"), classes = "character", how = "replace")
}

workspace_run_records_json <- function(records) {
  as.character(jsonlite::toJSON(workspace_run_records_repair(unname(records)), auto_unbox = TRUE,
                                digits = I(17), null = "null", na = "null"))
}

workspace_run_records_parse <- function(s) {
  if (is.null(s)) return(list())
  if (!is.character(s) || length(s) != 1L || is.na(s)) stop("run_records_json is not a single string", call. = FALSE)
  x <- tryCatch(jsonlite::fromJSON(s, simplifyVector = FALSE),
                error = function(e) stop("run_records_json could not be parsed: parse error", call. = FALSE))
  if (!is.list(x) || (length(x) && !is.null(names(x)))) stop("run_records_json is not an array", call. = FALSE)
  x
}

# The records exactly as they read back after a save.
workspace_run_records <- function(jobs) {
  if (is.null(jobs)) return(list())
  workspace_run_records_parse(workspace_run_records_json(lapply(jobs$records, workspace_run_record_export)))
}

workspace_run_record_value_ok <- function(x) {
  if (is.null(x)) return(TRUE)
  if (is.list(x) && is.null(attr(x, "class"))) return(all(vapply(x, workspace_run_record_value_ok, logical(1))))
  (is.character(x) || is.integer(x) || is.double(x) || is.logical(x)) && length(x) == 1L && is.null(attr(x, "class"))
}

workspace_run_record_string <- function(x) is.character(x) && length(x) == 1L && !is.na(x)

# One input: {store: character(1), label: character(1), revision: one number}.
workspace_run_record_input_ok <- function(x) {
  is.list(x) && workspace_run_record_string(x[["store"]]) && workspace_run_record_string(x[["label"]]) &&
    is.numeric(x[["revision"]]) && length(x[["revision"]]) == 1L && !is.na(x[["revision"]])
}

workspace_run_record_validate <- function(x) {
  if (!is.list(x) || !all(workspace_run_record_fields %in% names(x))) return(FALSE)
  if (!identical(x$schema, "richstudio.run_record") || !identical(x$version, 1L)) return(FALSE)
  if (!workspace_run_record_string(x$run_id)) return(FALSE)
  states <- c("queued", "running", "cancel_requested", "succeeded", "failed", "cancelled", "detached",
              "superseded", "interrupted")
  if (!workspace_run_record_string(x$state) || !x$state %in% states) return(FALSE)
  if (!workspace_run_record_string(x$kind) || !x$kind %in% c("enrichment", "clustering")) return(FALSE)
  if (!is.list(x$inputs) || !all(vapply(x$inputs, workspace_run_record_input_ok, logical(1)))) return(FALSE)
  all(vapply(x, workspace_run_record_value_ok, logical(1)))
}

# Saved records join the registry as history: queued and active ones become
# interrupted (never re-queued, never resumed), colliding ids are re-keyed with the
# original kept in `imported_from`, and the history bound applies right after.
workspace_run_records_reopen <- function(s, jobs) {
  if (is.null(s) || is.null(jobs)) return(invisible(0L))
  records <- tryCatch(workspace_run_records_parse(s), error = function(e) e)
  if (inherits(records, "error")) {
    shiny::showNotification(paste("Saved run history could not be read:", conditionMessage(records)), type = "warning")
    return(invisible(0L))
  }
  valid <- Filter(workspace_run_record_validate, records)
  dropped <- length(records) - length(valid)
  if (dropped) {
    shiny::showNotification(sprintf("%d saved run record(s) could not be read and were dropped", dropped),
                            type = "warning")
  }
  for (rec in valid) {
    if (rec$state %in% c("queued", "running", "cancel_requested")) {
      rec$state <- "interrupted"
      rec["ended"] <- list(NULL)
      rec$note <- "Session was saved while this run was queued or active; it was not resumed or re-queued"
    }
    existing <- vapply(jobs$records, function(r) as.character(r$run_id), character(1))
    if (rec$run_id %in% existing) {
      old <- rec$run_id
      rec$run_id <- workspace_jobs_new_run_id(jobs)
      rec$imported_from <- old
    }
    jobs$records[[length(jobs$records) + 1L]] <- rec
    jobs$imported <- c(jobs$imported, rec$run_id)
  }
  workspace_jobs_bound(jobs, imported_first = TRUE)
  workspace_jobs_bump(jobs)
  invisible(length(valid))
}
