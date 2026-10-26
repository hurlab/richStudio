# Reproducible project manifest and project writer (SPEC-WS-007)
#
# A project is a ZIP with three data-only members:
#   manifest.json  versioned description of every saved result (IDs, digests,
#                  effective parameters, statistics, versions, relationships)
#   tables.json    exact-value tables, one entry per generated table ID, encoded
#                  with the lossless session_json column encoding
#   methods.md     plain-language methods text generated from the manifest
# Nothing in a project is code: the importer never sources, evaluates or runs
# anything it reads (see R/project_import.R). The layout is documented in
# docs/PROJECT_FORMAT.md.

project_format_version <- "1.0"
project_schema_name <- "richstudio.project"
project_tables_schema_name <- "richstudio.project.tables"

# Typed absence: a field that holds no value says WHY. A missing value is never
# serialized as zero, an empty string or a guess.
#   not_recorded    the application never captured it (older save, no run record)
#   not_supplied    the user chose not to provide it (e.g. no custom background)
#   not_tested      the statistic was not computed for this row
#   not_significant the row is absent from that source because it did not pass
project_absent_types <- c("not_recorded", "not_supplied", "not_tested", "not_significant")

project_absent <- function(type = "not_recorded", reason = NULL) {
  if (!type %in% project_absent_types) stop("Unknown absence type", call. = FALSE)
  out <- list(status = type)
  if (!is.null(reason)) out$reason <- reason
  out
}

project_recorded <- function(value) list(status = "recorded", value = value)

project_blank <- function(x) {
  is.null(x) || !length(x) || (is.atomic(x) && length(x) == 1L && is.na(x))
}

project_typed <- function(value, absent = "not_recorded") {
  if (project_blank(value)) project_absent(absent) else project_recorded(value)
}

# {} for JSON; an unnamed empty list would serialize as [].
project_object <- function(x = list()) {
  if (!length(x)) return(structure(list(), names = character()))
  x
}

# Always a JSON array, including for one element.
project_array <- function(x) unname(as.list(x))

project_first_scalar <- function(x) {
  if (project_blank(x)) return(NA_character_)
  as.character(unlist(x, use.names = FALSE))[1]
}

project_pick <- function(lst, keys) {
  for (key in keys) {
    if (!is.null(lst[[key]]) && !project_blank(lst[[key]])) return(lst[[key]])
  }
  NULL
}

# ---- digests ----------------------------------------------------------------------

# Text form of one column used only for digesting: classes, levels and every value are
# part of it, doubles at 17 significant digits, NA distinct from the string "NA".
project_column_text <- function(x, name) {
  values <- if (is.double(x)) {
    out <- sprintf("%.17g", x)
    out[is.na(x) & !is.nan(x)] <- NA_character_
    out
  } else if (is.factor(x)) as.character(x) else as.character(x)
  values <- enc2utf8(values)
  cells <- ifelse(is.na(values), "NA", paste0(nchar(values, type = "bytes"), ":", values))
  lv <- if (is.factor(x)) paste(enc2utf8(levels(x)), collapse = "\r") else ""
  paste(c(enc2utf8(name), class(x)[1], lv, cells), collapse = "\n")
}

# Order-sensitive digest of a data frame's exact values (names, classes, levels,
# row count, every cell). Independent of how the table was serialized.
project_table_digest <- function(df) {
  rn <- if (.row_names_info(df) > 0L) paste0("rownames=", class(attr(df, "row.names")), ":",
                                              paste(enc2utf8(rownames(df)), collapse = "\r")) else "rownames=automatic"
  text <- c(sprintf("nrow=%d", nrow(df)), rn,
            vapply(seq_along(df), function(i) project_column_text(df[[i]], names(df)[i]), character(1)))
  digest::digest(paste(text, collapse = "\n\n"), algo = "sha256", serialize = FALSE)
}

project_file_digest <- function(path) digest::digest(path, algo = "sha256", file = TRUE)

project_short_id <- function(prefix, ...) {
  paste0(prefix, "-", substr(digest::digest(paste(enc2utf8(c(...)), collapse = "\r"),
                                            algo = "sha256", serialize = FALSE), 1L, 12L))
}

# ---- versions ---------------------------------------------------------------------

project_package_version <- function(pkg) {
  tryCatch(as.character(utils::packageVersion(pkg)), error = function(e) NA_character_)
}

project_versions <- function() {
  richr <- project_package_version("richR")
  list(
    richStudio = project_typed(project_package_version("richStudio")),
    engine = list(name = "richR", version = project_typed(richr)),
    R = R.version.string,
    format = project_format_version
  )
}

# ---- escaping and spreadsheet safety ----------------------------------------------

# Text that reaches HTML or markdown is escaped; control characters are dropped.
project_html_escape <- function(x) {
  x <- gsub("[[:cntrl:]]", " ", enc2utf8(as.character(x)))
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub("\"", "&quot;", x, fixed = TRUE)
  gsub("'", "&#39;", x, fixed = TRUE)
}

# Human-readable export only. Cells that a spreadsheet would read as a formula get a
# leading apostrophe; exact-value data lives in tables.json and is never altered.
project_spreadsheet_safe <- function(df) {
  guard <- function(x) {
    hit <- !is.na(x) & grepl("^[=+@\t\r-]", x)
    x[hit] <- paste0("'", x[hit])
    x
  }
  for (i in seq_along(df)) {
    if (is.character(df[[i]])) df[[i]] <- guard(df[[i]])
    if (is.factor(df[[i]])) df[[i]] <- factor(guard(as.character(df[[i]])))
  }
  names(df) <- guard(names(df))
  df
}

# ---- background record <-> manifest -----------------------------------------------

project_background_integer_fields <- c(
  "submitted_count", "mapped_size", "unique_count", "duplicate_count", "invalid_count",
  "unmapped_count", "query_effective", "query_unmapped_count", "query_excluded_count",
  "annotation_genes")

# The enrichment background record (R/enrichment_background.R) with each NA scalar
# replaced by a typed absence. A custom-background field on an annotation-universe run
# is not_supplied; every other missing field is not_recorded.
project_background_encode <- function(bg) {
  if (!is.list(bg) || is.null(names(bg))) return(project_absent("not_recorded"))
  annotation_mode <- identical(bg$mode, "annotation")
  encode <- function(x, field = "") {
    if (is.list(x)) {
      out <- lapply(names(x), function(nm) encode(x[[nm]], nm))
      names(out) <- names(x)
      return(out)
    }
    if (length(x) == 1L && is.na(x)) {
      return(project_absent(if (annotation_mode && field %in% c("background_digest", "submitted_count"))
        "not_supplied" else "not_recorded"))
    }
    if (length(x) != 1L) return(project_array(x))
    x
  }
  fields <- setdiff(names(bg), "unavailable")
  out <- lapply(fields, function(nm) encode(bg[[nm]], nm))
  names(out) <- fields
  out$unavailable <- project_array(bg$unavailable)
  project_recorded(out)
}

project_is_absent <- function(x) {
  is.list(x) && length(x) >= 1L && is.character(x$status) && length(x$status) == 1L &&
    x$status %in% project_absent_types
}

# Inverse of project_background_encode: typed absences become typed NA values again.
project_background_decode <- function(entry) {
  if (!is.list(entry) || !identical(entry$status, "recorded")) return(NULL)
  decode <- function(x, field = "") {
    if (project_is_absent(x)) {
      return(if (field %in% project_background_integer_fields) NA_integer_ else NA_character_)
    }
    if (is.list(x) && !is.null(names(x))) {
      out <- lapply(names(x), function(nm) decode(x[[nm]], nm))
      names(out) <- names(x)
      return(out)
    }
    if (is.list(x)) return(as.character(unlist(x, use.names = FALSE)))
    if (field %in% project_background_integer_fields && is.numeric(x)) return(as.integer(x))
    x
  }
  out <- entry$value
  fields <- setdiff(names(out), "unavailable")
  decoded <- lapply(fields, function(nm) decode(out[[nm]], nm))
  names(decoded) <- fields
  decoded$unavailable <- as.character(unlist(out$unavailable, use.names = FALSE))
  decoded
}

# ---- manifest ---------------------------------------------------------------------

project_columns <- function(df) {
  lapply(seq_along(df), function(i) list(name = names(df)[i], class = class(df[[i]])[1]))
}

project_stat_column <- function(df, pattern) {
  hit <- grep(pattern, names(df), ignore.case = TRUE, value = TRUE)
  if (length(hit)) hit[1] else NA_character_
}

project_stat_entry <- function(df, column, missing_type) {
  if (is.na(column)) return(project_absent("not_recorded"))
  x <- df[[column]]
  list(status = "recorded", column = column, n_missing = sum(is.na(x)),
       missing_type = if (any(is.na(x))) missing_type else NULL)
}

project_run_for <- function(records, kind, label) {
  hit <- Filter(function(r) identical(r$kind, kind) &&
                  label %in% as.character(unlist(r$outputs, use.names = FALSE)), records)
  if (length(hit)) hit[[length(hit)]] else NULL
}

project_ordered_labels <- function(names_list, dfs) {
  listed <- as.character(unlist(names_list, use.names = FALSE))
  listed <- listed[listed %in% names(dfs) & vapply(listed, function(l) is.data.frame(dfs[[l]]), logical(1))]
  listed <- unique(listed)
  extra <- setdiff(names(dfs)[vapply(dfs, is.data.frame, logical(1))], listed)
  list(labels = c(listed, extra), listed = c(rep(TRUE, length(listed)), rep(FALSE, length(extra))))
}

# Build the manifest and the table store for a session-shaped list. Pure: no files, no
# reactive reads. `run_records` are the exported WS-006 records (parsed JSON lists).
project_manifest_build <- function(session, run_records = list(), created = Sys.time(),
                                   versions = project_versions()) {
  tables <- list()
  add_table <- function(df) {
    id <- sprintf("t%04d", length(tables) + 1L)
    tables[[id]] <<- df
    id
  }
  table_fields <- function(df, id) {
    list(table = id, table_digest = list(algo = "sha256", value = project_table_digest(df)),
         nrow = nrow(df), ncol = ncol(df), columns = project_columns(df))
  }

  relationships <- list()
  relate <- function(type, from, to, ...) {
    relationships[[length(relationships) + 1L]] <<- c(list(type = type, from = from, to = to), list(...))
  }

  # Datasets (DEG sets): the sources every result is derived from.
  deg <- project_ordered_labels(session$degnames, session$degdfs)
  datasets <- lapply(seq_along(deg$labels), function(i) {
    label <- deg$labels[i]
    df <- session$degdfs[[label]]
    id <- project_short_id("ds", "deg", label, project_table_digest(df))
    c(list(id = id, label = label, kind = "deg", listed = deg$listed[i]),
      table_fields(df, add_table(df)),
      list(source_digest = list(algo = "sha256", value = project_table_digest(df)),
           origin = project_absent("not_recorded")))
  })
  dataset_id <- function(label) {
    for (d in datasets) if (identical(d$label, label)) return(d$id)
    NULL
  }

  # Enrichment results.
  rr <- project_ordered_labels(session$rrnames, session$rrdfs)
  results <- lapply(seq_along(rr$labels), function(i) {
    label <- rr$labels[i]
    df <- session$rrdfs[[label]]
    bg <- attr(df, "richstudio_background", exact = TRUE)
    run <- project_run_for(run_records, "enrichment", label)
    settings <- if (is.null(run)) NULL else run$settings
    annotation <- if (is.list(bg)) bg$annotation else NULL
    pick_ann <- function(field) {
      v <- project_first_scalar(annotation[[field]])
      if (is.na(v) || !nzchar(v)) v <- project_first_scalar(settings[[field]])
      if (!is.na(v) && !nzchar(v)) v <- NA_character_
      project_typed(v)
    }
    term_col <- if ("Term" %in% names(df)) "Term" else if ("Annot" %in% names(df)) "Annot" else NA_character_
    term_ids <- if (is.na(term_col)) NULL else {
      terms <- as.character(df[[term_col]])
      ifelse(is.na(terms), NA_character_, vapply(terms, function(t) project_short_id("tm", t), character(1)))
    }
    id <- project_short_id("rs", "enrichment", label, project_table_digest(df))
    if (!is.null(run)) {
      relate("produced_by", id, run$run_id)
      for (inp in run$inputs) {
        src <- if (identical(inp$store, "deg")) dataset_id(inp$label) else NULL
        if (!is.null(src)) relate("input_of", src, id, run_id = run$run_id, input_revision = inp$revision)
      }
    }
    c(list(id = id, label = label, kind = "enrichment", listed = rr$listed[i]),
      table_fields(df, add_table(df)),
      list(
        run_id = if (is.null(run)) project_absent("not_recorded") else project_recorded(run$run_id),
        species = pick_ann("species"), keytype = pick_ann("keytype"),
        annotation_type = pick_ann("anntype"), ontology = pick_ann("ontology"),
        annotation_provenance = project_absent("not_recorded", "provider, release, build and digest are not reported by the engine"),
        parameters = if (is.null(run)) project_absent("not_recorded") else project_recorded(settings),
        background = project_background_encode(bg),
        statistics = list(
          raw_p = project_stat_entry(df, project_stat_column(df, "^p[-_ ]?value$"), "not_tested"),
          adjusted_p = project_stat_entry(df, project_stat_column(df, "^p[-_ ]?adj"), "not_tested"),
          correction_method = project_typed(project_pick(settings, c("padj_method", "padj.method", "correction"))),
          correction_family = if (is.null(run)) project_absent("not_recorded") else
            project_recorded("terms tested in this run (the rows of the result table)")
        ),
        term_id_column = project_typed(term_col),
        term_ids = if (is.null(term_ids)) NULL else project_array(unname(term_ids))
      ))
  })
  result_id <- function(label) {
    for (r in results) if (identical(r$label, label)) return(r$id)
    NULL
  }

  # Clustering results: a summary table (clusdfs) and a per-term table (cluslists).
  clus <- project_ordered_labels(session$clusnames, session$clusdfs)
  clusters <- lapply(seq_along(clus$labels), function(i) {
    label <- clus$labels[i]
    summary_df <- session$clusdfs[[label]]
    detail_df <- session$cluslists[[label]]
    run <- project_run_for(run_records, "clustering", label)
    settings <- if (is.null(run)) NULL else run$settings
    id <- project_short_id("cl", "clustering", label, project_table_digest(summary_df))
    if (!is.null(run)) {
      relate("produced_by", id, run$run_id)
      for (inp in run$inputs) {
        src <- if (identical(inp$store, "rr")) result_id(inp$label) else NULL
        if (!is.null(src)) relate("input_of", src, id, run_id = run$run_id, input_revision = inp$revision)
      }
    }
    members <- NULL
    if (is.data.frame(detail_df) && "Cluster" %in% names(detail_df)) {
      values <- unique(as.character(detail_df$Cluster))
      members <- lapply(values[!is.na(values)], function(v) list(id = project_short_id("cn", label, v), value = v))
    }
    per_dataset <- if (is.data.frame(detail_df)) grep("^(Pvalue_|Padj_)", names(detail_df), value = TRUE) else character()
    c(list(id = id, label = label, kind = "clustering", listed = clus$listed[i]),
      table_fields(summary_df, add_table(summary_df)),
      list(
        detail = if (is.data.frame(detail_df)) {
          c(list(status = "recorded"), table_fields(detail_df, add_table(detail_df)))
        } else project_absent("not_recorded"),
        run_id = if (is.null(run)) project_absent("not_recorded") else project_recorded(run$run_id),
        method = project_typed(project_first_scalar(settings$method)),
        parameters = if (is.null(run)) project_absent("not_recorded") else project_recorded(settings$params),
        cluster_column = if (length(members)) "Cluster" else NULL,
        clusters = project_array(members %||% list()),
        statistics = list(per_dataset = lapply(per_dataset, function(col) {
          list(column = col, n_missing = sum(is.na(detail_df[[col]])), missing_type = "not_significant")
        }))
      ))
  })

  runs <- lapply(run_records, function(r) r)
  manifest <- list(
    schema = project_schema_name,
    format_version = project_format_version,
    created = format(as.POSIXct(created), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    software = versions,
    datasets = project_array(datasets),
    results = project_array(results),
    clusters = project_array(clusters),
    runs = project_array(runs),
    relationships = project_array(relationships),
    display = project_object(),
    absence_types = project_array(project_absent_types)
  )
  list(manifest = manifest, tables = tables)
}

# ---- methods text -----------------------------------------------------------------

# Plain-language methods summary generated from the manifest only. Recorded facts,
# display labels (names the user typed, not parameters) and unavailable provenance are
# kept apart. Every label is escaped before it reaches the text.
project_methods_text <- function(manifest) {
  esc <- project_html_escape
  fact <- function(entry) if (identical(entry$status, "recorded")) esc(entry$value) else NULL
  lines <- c("# Methods summary", "",
             "Generated from the project manifest. Only recorded parameters are stated as facts.", "",
             "## Recorded facts", "")
  sw <- manifest$software
  lines <- c(lines, sprintf("- richStudio %s with %s %s on %s.",
                            fact(sw$richStudio) %||% "(version not recorded)",
                            esc(sw$engine$name), fact(sw$engine$version) %||% "(version not recorded)",
                            esc(sw$R)))
  unavailable <- character()
  for (r in manifest$results) {
    label <- esc(r$label)
    if (!identical(r$parameters$status, "recorded")) {
      unavailable <- c(unavailable, sprintf("Enrichment %s: run parameters.", label))
    }
    parts <- c(
      if (!is.null(fact(r$annotation_type))) sprintf("annotation %s", fact(r$annotation_type)),
      if (!is.null(fact(r$species))) sprintf("species %s", fact(r$species)),
      if (!is.null(fact(r$keytype))) sprintf("key type %s", fact(r$keytype)),
      if (!is.null(fact(r$ontology))) sprintf("ontology %s", fact(r$ontology)))
    if (length(parts)) lines <- c(lines, sprintf("- Enrichment result %s: %s.", label, paste(parts, collapse = ", ")))
    bg <- r$background
    if (identical(bg$status, "recorded")) {
      lines <- c(lines, sprintf("- Enrichment result %s: background mode %s.", label, esc(bg$value$mode)))
    } else {
      unavailable <- c(unavailable, sprintf("Enrichment %s: background identity.", label))
    }
    if (!identical(r$statistics$correction_method$status, "recorded")) {
      unavailable <- c(unavailable, sprintf("Enrichment %s: multiple-testing correction method.", label))
    }
    if (identical(r$statistics$adjusted_p$status, "recorded") && r$statistics$adjusted_p$n_missing > 0) {
      lines <- c(lines, sprintf("- Enrichment result %s: %d adjusted p-value(s) were not tested and are stored as missing, not as zero.",
                                label, r$statistics$adjusted_p$n_missing))
    }
    unavailable <- c(unavailable, sprintf("Enrichment %s: annotation provider, release, build and digest.", label))
  }
  for (cl in manifest$clusters) {
    label <- esc(cl$label)
    if (identical(cl$method$status, "recorded")) {
      lines <- c(lines, sprintf("- Clustering result %s: method %s.", label, esc(cl$method$value)))
    } else {
      unavailable <- c(unavailable, sprintf("Clustering %s: method and parameters.", label))
    }
  }
  lines <- c(lines, "", "## Display labels (names chosen by the user, not parameters)", "")
  labels <- c(vapply(manifest$datasets, function(d) esc(d$label), character(1)),
              vapply(manifest$results, function(d) esc(d$label), character(1)),
              vapply(manifest$clusters, function(d) esc(d$label), character(1)))
  lines <- c(lines, if (length(labels)) sprintf("- %s", labels) else "- (none)")
  lines <- c(lines, "", "## Unavailable provenance", "")
  lines <- c(lines, if (length(unavailable)) sprintf("- %s", unique(unavailable)) else "- (none)")
  paste0(paste(lines, collapse = "\n"), "\n")
}

# ---- resource admission -----------------------------------------------------------

# Table shape limits from the installed workspace resource policy.
project_check_table_limits <- function(tables, policy) {
  for (id in names(tables)) {
    df <- tables[[id]]
    if (nrow(df) > policy$limits$rows) {
      stop(sprintf("Project table %s has %d rows; the limit is %d", id, nrow(df), policy$limits$rows), call. = FALSE)
    }
    if (ncol(df) > policy$limits$columns) {
      stop(sprintf("Project table %s has %d columns; the limit is %d", id, ncol(df), policy$limits$columns), call. = FALSE)
    }
  }
  invisible(TRUE)
}

# ---- writer -----------------------------------------------------------------------

#' Write a project archive
#'
#' @param session Session-shaped list (degnames, degdfs, rrnames, rrdfs, clusnames,
#'   clusdfs, cluslists).
#' @param run_records Exported WS-006 run records (parsed JSON lists).
#' @param file Output path of the ZIP.
#' @param policy_loader Returns the installed resource policy; failure blocks the save.
#' @return `file`, invisibly.
#' @noRd
project_write <- function(session, run_records, file, policy_loader = workspace_resource_policy,
                          created = Sys.time()) {
  policy <- tryCatch(workspace_validate_resource_policy(policy_loader()), error = function(e) {
    stop("Project save unavailable: resource policy missing or invalid", call. = FALSE)
  })
  built <- project_manifest_build(session, run_records, created = created)
  project_check_table_limits(built$tables, policy)

  stage <- tempfile("richstudio_project_")
  dir.create(stage)
  on.exit(unlink(stage, recursive = TRUE), add = TRUE)

  encoded <- lapply(built$tables, function(df) {
    e <- session_json_encode_df(df)
    # session_json writes explicit row names as strings; remember an integer row-name vector.
    if (.row_names_info(df) > 0L && is.integer(attr(df, "row.names"))) e$schema$row_names_class <- "integer"
    e
  })
  payload <- list(schema = project_tables_schema_name, format_version = project_format_version,
                  tables = lapply(encoded, function(e) list(data = e$data, schema = e$schema)))
  tables_path <- file.path(stage, "tables.json")
  jsonlite::write_json(payload, tables_path, auto_unbox = TRUE, digits = I(17), na = "null", null = "null")

  methods_path <- file.path(stage, "methods.md")
  writeLines(project_methods_text(built$manifest), methods_path, useBytes = TRUE)

  manifest <- built$manifest
  manifest$files <- list(
    list(name = "tables.json", role = "tables", sha256 = project_file_digest(tables_path),
         bytes = file.size(tables_path)),
    list(name = "methods.md", role = "methods", sha256 = project_file_digest(methods_path),
         bytes = file.size(methods_path)))
  manifest_path <- file.path(stage, "manifest.json")
  jsonlite::write_json(manifest, manifest_path, auto_unbox = TRUE, pretty = TRUE, digits = I(17),
                       na = "null", null = "null")

  expanded <- sum(file.size(file.path(stage, c("manifest.json", "tables.json", "methods.md"))))
  if (expanded > policy$limits$archive_expanded_bytes) {
    stop("Project is larger than the reviewed archive limit and cannot be saved", call. = FALSE)
  }
  out <- tempfile("richstudio_project_", fileext = ".zip")
  on.exit(unlink(out), add = TRUE)
  zip::zipr(out, c("manifest.json", "tables.json", "methods.md"), root = stage)
  if (file.size(out) > policy$limits$archive_bytes) {
    stop("Project is larger than the reviewed archive limit and cannot be saved", call. = FALSE)
  }
  if (!file.copy(out, file, overwrite = TRUE)) stop("Project could not be written", call. = FALSE)
  invisible(file)
}

#' Human-readable table export (spreadsheet-safe CSV)
#'
#' Distinct from the exact-value tables in a project: cells a spreadsheet would read as
#' a formula are prefixed, so the file is for reading, not for round-tripping.
#' @noRd
project_export_csv <- function(df, file, spreadsheet_safe = TRUE) {
  if (spreadsheet_safe) df <- project_spreadsheet_safe(df)
  utils::write.csv(df, file, row.names = FALSE)
  invisible(file)
}
