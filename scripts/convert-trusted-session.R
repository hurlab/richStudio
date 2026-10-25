#!/usr/bin/env Rscript
# Convert a legacy richStudio .rds session file to the JSON session format.
#
# SECURITY: readRDS() can execute code embedded in a file. Run this script ONLY
# on session files you created yourself or otherwise fully trust, and only on your
# own computer. The richStudio web app refuses .rds uploads for this reason.
#
# Usage: Rscript scripts/convert-trusted-session.R in.rds out.json
#
# Nothing is evaluated from the file beyond readRDS(). Only the known session
# fields are copied into a fresh list, and the output is written by the same
# writer the app uses (R/session_json.R). An existing output file is never
# overwritten.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) {
  stop("Usage: Rscript scripts/convert-trusted-session.R in.rds out.json", call. = FALSE)
}
in_path <- args[[1L]]
out_path <- args[[2L]]

script_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])
writer <- file.path(dirname(normalizePath(script_file)), "..", "R", "session_json.R")
if (!file.exists(writer)) stop("Cannot find R/session_json.R next to scripts/.", call. = FALSE)
if (!requireNamespace("jsonlite", quietly = TRUE)) stop("Package 'jsonlite' is required.", call. = FALSE)
source(writer, local = TRUE)

if (!file.exists(in_path)) stop("Input file not found: ", in_path, call. = FALSE)
if (file.exists(out_path)) stop("Refusing to overwrite existing file: ", out_path, call. = FALSE)

session <- readRDS(in_path)

fail <- function(...) stop("Not a richStudio session file: ", ..., call. = FALSE)
if (!is.list(session) || is.data.frame(session) || is.null(session$version)) {
  fail("expected a list with a 'version' field")
}
label_fields <- c("degnames", "rrnames", "clusnames")
for (field in label_fields) {
  value <- session[[field]]
  if (!is.null(value) && !is.character(value)) fail("'", field, "' is not a character vector")
}
for (field in session_json_sections) {
  items <- session[[field]]
  if (is.null(items)) next
  if (!is.list(items) || is.data.frame(items) || (length(items) && is.null(names(items)))) {
    fail("'", field, "' is not a named list of tables")
  }
  if (!all(vapply(items, is.data.frame, logical(1)))) fail("'", field, "' holds a non-table entry")
}

clean <- list(version = as.character(session$version)[1L], created = session$created)
if (!inherits(clean$created, "POSIXct") && !is.character(clean$created)) clean$created <- NULL
for (field in label_fields) clean[[field]] <- as.character(session[[field]])
for (field in session_json_sections) clean[[field]] <- session[[field]]
if (is.character(session$run_records_json) && length(session$run_records_json) == 1L) {
  clean$run_records_json <- session$run_records_json
}

session_json_write(clean, out_path)
message("Wrote ", out_path)
