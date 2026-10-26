# Project import (SPEC-WS-007)
#
# Opening a project is three steps that never mix:
#   1. project_import_read()  validates the complete bounded archive and builds a
#      data-only candidate in temporary structures. Nothing outside this function is
#      touched; any failure raises a "richstudio_project_invalid" error.
#   2. the caller shows the candidate's summary if it wants to;
#   3. project_commit_candidate() applies the candidate to the workspace in one swap,
#      after invalidating the WS-006 job generation. Legacy JSON 1.0 sessions reach the
#      same step through project_legacy_candidate().
# Nothing here sources, evaluates, deserializes R objects or runs a bundled recipe: the
# only readers are jsonlite parsers and the zip central-directory/extraction routines.

project_member_names <- c("manifest.json", "tables.json", "methods.md")

# Hard bounds that the resource policy does not name.
project_max_compression_ratio <- 200
project_ratio_floor_bytes <- 1048576
project_json_depth_limit <- 16L

project_invalid <- function(...) {
  stop(structure(class = c("richstudio_project_invalid", "error", "condition"),
                 list(message = paste0(...), call = NULL)))
}

project_json_depth <- function(x, depth = 0L) {
  if (!is.list(x) || !length(x)) return(depth)
  max(vapply(x, project_json_depth, integer(1), depth = depth + 1L))
}

# ---- archive listing: everything decided before a byte is extracted ----------------

project_unsafe_name <- function(name) {
  is.na(name) || !nzchar(name) || grepl("[[:cntrl:]\\\\]", name) || grepl("^/", name) ||
    grepl("^[A-Za-z]:", name) || any(strsplit(name, "/", fixed = TRUE)[[1]] %in% c("..", ".", ""))
}

project_list_archive <- function(path, policy) {
  size <- file.size(path)
  if (is.na(size)) project_invalid("The project file could not be read")
  tryCatch(workspace_check_resources(list(archive_bytes = size), policy),
           error = function(e) project_invalid("The project archive is larger than the reviewed limit"))
  entries <- tryCatch(as.data.frame(zip::zip_list(path), stringsAsFactors = FALSE),
                      error = function(e) project_invalid("The file is not a readable ZIP archive"))
  if (!nrow(entries)) project_invalid("The project archive is empty")
  names <- entries$filename

  # Duplicate or ambiguous names: exact, case-insensitive, or equal after normalizing.
  normalized <- tolower(gsub("\\\\", "/", names))
  if (anyDuplicated(names) || anyDuplicated(normalized)) {
    project_invalid("The project archive has duplicate or ambiguous member names")
  }
  if (any(vapply(names, project_unsafe_name, logical(1)))) {
    project_invalid("The project archive has an unsafe member path (traversal, absolute or malformed)")
  }
  type <- if ("type" %in% names(entries)) entries$type else rep("file", nrow(entries))
  mode_text <- suppressWarnings(strtoi(as.character(entries$permissions), 8L))
  linked <- !is.na(mode_text) & bitwAnd(mode_text, 61440L) == 40960L
  if (any(type != "file") || any(linked)) {
    project_invalid("The project archive has a link, directory or special member")
  }
  if ("encryption" %in% names(entries) && any(entries$encryption != "none")) {
    project_invalid("The project archive has an encrypted member")
  }

  depth <- max(vapply(strsplit(names, "/", fixed = TRUE), length, integer(1)))
  expanded <- sum(as.numeric(entries$uncompressed_size))
  tryCatch(
    workspace_check_resources(list(archive_members = nrow(entries), archive_expanded_bytes = expanded,
                                   archive_depth = depth), policy),
    error = function(e) project_invalid("The project archive exceeds a reviewed limit: ",
                                        sub("^Workspace resource limit exceeded: ", "", conditionMessage(e))))
  compressed <- as.numeric(entries$compressed_size)
  uncompressed <- as.numeric(entries$uncompressed_size)
  bomb <- uncompressed > project_ratio_floor_bytes &
    (compressed == 0 | uncompressed / pmax(compressed, 1) > project_max_compression_ratio)
  if (any(bomb)) project_invalid("The project archive expands suspiciously (compression ratio limit)")

  if (!all(names %in% project_member_names)) {
    project_invalid("The project archive has an unexpected member: ",
                    project_html_escape(utils::head(setdiff(names, project_member_names), 1L)))
  }
  if (!all(c("manifest.json", "tables.json") %in% names)) {
    project_invalid("The project archive lacks manifest.json or tables.json")
  }
  entries
}

# Extract one validated member into the private staging directory and re-check its
# real size against what the central directory declared.
project_extract_member <- function(path, name, declared, stage) {
  tryCatch(zip::unzip(path, files = name, exdir = stage),
           error = function(e) project_invalid("The project archive member ", name, " could not be extracted"))
  out <- file.path(stage, name)
  if (!file.exists(out) || is.na(file.size(out)) || file.size(out) > declared) {
    project_invalid("The project archive member ", name, " does not match its declared size")
  }
  out
}

# ---- manifest validation ----------------------------------------------------------

project_scalar_string <- function(x) is.character(x) && length(x) == 1L && !is.na(x)

project_check_label <- function(x, policy, what) {
  if (!project_scalar_string(x) || !nzchar(x) || nchar(x, type = "bytes") > policy$limits$string_bytes) {
    project_invalid("Invalid ", what, " label in the manifest")
  }
}

project_check_version <- function(version) {
  if (!project_scalar_string(version) || !grepl("^[0-9]+\\.[0-9]+$", version)) {
    project_invalid("The manifest has no valid format_version")
  }
  major <- as.integer(strsplit(version, ".", fixed = TRUE)[[1]][1])
  current <- as.integer(strsplit(project_format_version, ".", fixed = TRUE)[[1]][1])
  if (major > current) {
    project_invalid("This project uses format version ", version, ", which this richStudio does not support")
  }
  if (major < 1L) project_invalid("The manifest has no valid format_version")
}

project_check_table_ref <- function(entry, tables, policy, seen) {
  id <- entry$table
  if (!project_scalar_string(id) || !grepl("^t[0-9]{4}$", id) || is.null(tables[[id]])) {
    project_invalid("The manifest references a missing table")
  }
  if (id %in% seen) project_invalid("The manifest references a table more than once")
  digest_ok <- is.list(entry$table_digest) && identical(entry$table_digest$algo, "sha256") &&
    project_scalar_string(entry$table_digest$value)
  if (!digest_ok) project_invalid("The manifest has an invalid table digest")
  id
}

# Decode and check one table against its manifest entry. Returns the data frame.
project_decode_table <- function(entry, store, policy) {
  schema <- store$schema
  declared_rows <- suppressWarnings(as.integer(schema$nrow))
  declared_cols <- length(schema$names)
  if (length(declared_rows) != 1L || is.na(declared_rows)) project_invalid("A table has an invalid schema")
  tryCatch(workspace_check_resources(list(rows = declared_rows, columns = declared_cols), policy),
           error = function(e) project_invalid("A table exceeds a reviewed limit: ",
                                               sub("^Workspace resource limit exceeded: ", "", conditionMessage(e))))
  df <- tryCatch(session_json_decode_df(store$data, schema),
                 error = function(e) project_invalid("A table could not be decoded"))
  if (!is.data.frame(df)) project_invalid("A table could not be decoded")
  if (identical(schema$row_names_class, "integer") && !is.null(schema$row_names)) {
    ints <- suppressWarnings(as.integer(schema$row_names))
    if (anyNA(ints) || length(ints) != nrow(df)) project_invalid("A table could not be decoded")
    attr(df, "row.names") <- ints
  }
  if (!identical(project_table_digest(df), entry$table_digest$value)) {
    project_invalid("A table does not match its recorded digest")
  }
  if (!identical(as.integer(entry$nrow), nrow(df)) || !identical(as.integer(entry$ncol), ncol(df)) ||
      !identical(vapply(entry$columns, function(c) as.character(c$name), character(1)), names(df))) {
    project_invalid("A table does not match its manifest description")
  }
  df
}

# ---- reading ----------------------------------------------------------------------

#' Validate a project archive into a data-only candidate
#'
#' @param path Path to the uploaded ZIP.
#' @param policy_loader Returns the installed resource policy; a failure blocks import.
#' @return A candidate list (session fields plus `manifest`, `methods`, `source`).
#' @noRd
project_import_read <- function(path, policy_loader = workspace_resource_policy) {
  policy <- tryCatch(workspace_validate_resource_policy(policy_loader()), error = function(e) {
    project_invalid("Project import unavailable: resource policy missing or invalid")
  })
  if (length(path) != 1L || !is.character(path) || !file.exists(path)) {
    project_invalid("The project file could not be read")
  }
  entries <- project_list_archive(path, policy)
  stage <- tempfile("richstudio_import_")
  dir.create(stage)
  on.exit(unlink(stage, recursive = TRUE), add = TRUE)
  declared <- stats::setNames(as.numeric(entries$uncompressed_size), entries$filename)

  manifest_path <- project_extract_member(path, "manifest.json", declared[["manifest.json"]], stage)
  manifest <- tryCatch(jsonlite::read_json(manifest_path, simplifyVector = FALSE),
                       error = function(e) project_invalid("manifest.json is not valid JSON"))
  if (!is.list(manifest) || !identical(manifest$schema, project_schema_name)) {
    project_invalid("manifest.json is not a richStudio project manifest")
  }
  project_check_version(manifest$format_version)
  if (project_json_depth(manifest) > project_json_depth_limit) {
    project_invalid("manifest.json is nested too deeply")
  }

  files <- manifest$files
  file_digest <- function(name) {
    for (f in files) if (identical(f$name, name)) return(f)
    NULL
  }
  tables_path <- project_extract_member(path, "tables.json", declared[["tables.json"]], stage)
  tables_meta <- file_digest("tables.json")
  if (is.null(tables_meta) || !identical(tables_meta$sha256, project_file_digest(tables_path))) {
    project_invalid("tables.json does not match the digest in the manifest")
  }
  methods <- NULL
  if ("methods.md" %in% entries$filename) {
    methods_path <- project_extract_member(path, "methods.md", declared[["methods.md"]], stage)
    methods_meta <- file_digest("methods.md")
    if (is.null(methods_meta) || !identical(methods_meta$sha256, project_file_digest(methods_path))) {
      project_invalid("methods.md does not match the digest in the manifest")
    }
    methods <- paste(readLines(methods_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  }
  payload <- tryCatch(jsonlite::read_json(tables_path, simplifyVector = TRUE),
                      error = function(e) project_invalid("tables.json is not valid JSON"))
  if (!is.list(payload) || !identical(payload$schema, project_tables_schema_name) ||
      !is.list(payload$tables)) {
    project_invalid("tables.json is not a richStudio project table store")
  }
  project_check_version(payload$format_version)

  project_build_candidate(manifest, payload$tables, methods, policy)
}

project_build_candidate <- function(manifest, stores, methods, policy) {
  sections <- list(datasets = "deg", results = "enrichment", clusters = "clustering")
  all_ids <- character()
  seen_tables <- character()
  decoded <- list()
  out <- list(datasets = list(), results = list(), clusters = list())

  for (section in names(sections)) {
    entries <- manifest[[section]]
    if (!is.list(entries) || (length(entries) && !is.null(names(entries)))) {
      project_invalid("The manifest section ", section, " is not an array")
    }
    labels <- character()
    for (entry in entries) {
      if (!is.list(entry)) project_invalid("The manifest section ", section, " has an invalid entry")
      project_check_label(entry$label, policy, sections[[section]])
      if (!identical(entry$kind, sections[[section]])) project_invalid("The manifest has an entry of the wrong kind")
      if (!project_scalar_string(entry$id) || !grepl("^(ds|rs|cl)-[0-9a-f]{12}$", entry$id)) {
        project_invalid("The manifest has an invalid ID")
      }
      if (entry$id %in% all_ids) project_invalid("The manifest repeats an ID")
      if (entry$label %in% labels) project_invalid("The manifest repeats a label")
      if (!is.logical(entry$listed) || length(entry$listed) != 1L || is.na(entry$listed)) {
        project_invalid("The manifest has an invalid entry")
      }
      all_ids <- c(all_ids, entry$id)
      labels <- c(labels, entry$label)

      tid <- project_check_table_ref(entry, stores, policy, seen_tables)
      seen_tables <- c(seen_tables, tid)
      df <- project_decode_table(entry, stores[[tid]], policy)

      detail_df <- NULL
      if (identical(section, "clusters") && is.list(entry$detail) && identical(entry$detail$status, "recorded")) {
        did <- project_check_table_ref(entry$detail, stores, policy, seen_tables)
        seen_tables <- c(seen_tables, did)
        detail_df <- project_decode_table(entry$detail, stores[[did]], policy)
      }
      if (identical(section, "results")) {
        attr(df, "richstudio_background") <- project_background_decode(entry$background)
      }
      out[[section]][[length(out[[section]]) + 1L]] <- list(entry = entry, df = df, detail = detail_df)
    }
  }
  if (!setequal(seen_tables, names(stores)) || anyDuplicated(names(stores))) {
    project_invalid("tables.json has tables that the manifest does not reference")
  }

  runs <- manifest$runs
  if (!is.list(runs) || (length(runs) && !is.null(names(runs)))) project_invalid("The manifest runs are not an array")
  if (!all(vapply(runs, workspace_run_record_validate, logical(1)))) {
    project_invalid("The manifest has an invalid run record")
  }
  run_ids <- vapply(runs, function(r) r$run_id, character(1))
  if (anyDuplicated(run_ids)) project_invalid("The manifest repeats a run ID")

  rels <- manifest$relationships
  if (!is.list(rels) || (length(rels) && !is.null(names(rels)))) project_invalid("The manifest relationships are not an array")
  for (rel in rels) {
    ok <- is.list(rel) && project_scalar_string(rel$type) && rel$type %in% c("input_of", "produced_by") &&
      project_scalar_string(rel$from) && project_scalar_string(rel$to) && rel$from %in% all_ids &&
      rel$to %in% c(all_ids, run_ids)
    if (!ok) project_invalid("The manifest has a broken relationship reference")
  }

  collect <- function(section, listed_only = FALSE) {
    items <- out[[section]]
    if (listed_only) items <- Filter(function(i) isTRUE(i$entry$listed), items)
    items
  }
  frames <- function(section) {
    items <- out[[section]]
    stats::setNames(lapply(items, function(i) i$df), vapply(items, function(i) i$entry$label, character(1)))
  }
  labels_of <- function(section) {
    vapply(collect(section, TRUE), function(i) i$entry$label, character(1))
  }
  details <- Filter(Negate(is.null), stats::setNames(
    lapply(out$clusters, function(i) i$detail), vapply(out$clusters, function(i) i$entry$label, character(1))))
  list(
    version = "1.0", created = manifest$created,
    degnames = labels_of("datasets"), degdfs = frames("datasets"),
    rrnames = labels_of("results"), rrdfs = frames("results"),
    clusnames = labels_of("clusters"), clusdfs = frames("clusters"), cluslists = details,
    run_records_json = workspace_run_records_json(runs),
    source = list(kind = "project", format_version = manifest$format_version),
    manifest = manifest, methods = methods
  )
}

# ---- legacy JSON 1.0 adapter -------------------------------------------------------

#' Validate a session-JSON list into the same candidate shape as a project
#'
#' Absent metadata stays absent: nothing is recomputed or inferred, and a manifest built
#' from the candidate marks it not_recorded.
#' @noRd
project_legacy_candidate <- function(session_data) {
  bad <- function() stop("Invalid session file format", call. = FALSE)
  if (!is.list(session_data)) bad()
  as_names <- function(x) {
    if (is.null(x)) return(NULL)
    if (!is.atomic(x) && !is.list(x)) bad()
    out <- unlist(x, use.names = FALSE)
    if (is.null(out)) return(character())
    if (!is.character(out)) bad()
    out
  }
  frames <- function(x) {
    if (is.null(x)) return(list())
    if (!is.list(x) || is.data.frame(x) || (length(x) && is.null(names(x)))) bad()
    if (!all(vapply(x, is.data.frame, logical(1)))) bad()
    x
  }
  run_records <- session_data$run_records_json
  if (!is.null(run_records) && !project_scalar_string(run_records)) bad()
  list(
    version = session_data$version, created = session_data$created,
    degnames = as_names(session_data$degnames), degdfs = frames(session_data$degdfs),
    rrnames = as_names(session_data$rrnames), rrdfs = frames(session_data$rrdfs),
    clusnames = as_names(session_data$clusnames), clusdfs = frames(session_data$clusdfs),
    cluslists = frames(session_data$cluslists),
    run_records_json = run_records,
    source = list(kind = "legacy_session_json", format_version = as.character(session_data$version),
                  metadata = "not_recorded"),
    manifest = NULL, methods = NULL
  )
}

# ---- the one atomic apply ---------------------------------------------------------

#' Apply a validated candidate to the workspace in one swap
#'
#' The candidate is complete and valid before this runs. The job generation is
#' invalidated immediately before the stores change, so no callback of the previous
#' workspace can publish into the new one.
#' @param candidate Output of project_import_read() or project_legacy_candidate().
#' @param stores List of the seven reactive stores.
#' @param jobs The WS-006 registry, or NULL.
#' @noRd
project_commit_candidate <- function(candidate, stores, jobs = NULL) {
  if (!is.null(jobs)) workspace_jobs_commit_workspace_swap(jobs)
  clear <- function(rv) for (nm in shiny::isolate(names(rv))) rv[[nm]] <- NULL
  fill <- function(rv, items) for (nm in names(items)) rv[[nm]] <- items[[nm]]
  clear(stores$u_degdfs)
  clear(stores$u_rrdfs)
  clear(stores$u_clusdfs)
  clear(stores$u_cluslists)
  stores$u_degnames$labels <- candidate$degnames
  fill(stores$u_degdfs, candidate$degdfs)
  stores$u_rrnames$labels <- candidate$rrnames
  fill(stores$u_rrdfs, candidate$rrdfs)
  stores$u_clusnames$labels <- candidate$clusnames
  fill(stores$u_clusdfs, candidate$clusdfs)
  fill(stores$u_cluslists, candidate$cluslists)
  if (!is.null(jobs)) workspace_run_records_reopen(candidate$run_records_json, jobs)
  invisible(candidate)
}
