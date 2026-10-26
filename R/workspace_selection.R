# Identity, context compatibility and session-local selection for the results
# explorer (SPEC-WS-008). These helpers read result tables and never modify them.
# A selection is an opaque row key; it is only ever compared with the known keys of
# the visible result and is never used to build a selector or a code path.

# The qualified term identifier column and the human label column of an enrichment
# result. richR reports Annot (identifier) and Term (description); a table with only
# one of them uses it for both.
workspace_term_columns <- function(df) {
  has_annot <- "Annot" %in% names(df)
  has_term <- "Term" %in% names(df)
  list(
    id = if (has_annot) "Annot" else if (has_term) "Term" else NA_character_,
    label = if (has_term) "Term" else if (has_annot) "Annot" else NA_character_
  )
}

# Content identity of a result: the exact values, never the display name, so a rename
# or reorder cannot change it.
workspace_result_id <- function(df) {
  project_short_id("rs", "explorer", project_table_digest(df))
}

# Species, key type, annotation type and ontology of a result, each NA when not
# recorded. The recorded enrichment background wins over run settings; unknown
# placeholders ("?", "NULL", "") are NA.
workspace_result_context <- function(df, settings = NULL) {
  bg <- attr(df, "richstudio_background", exact = TRUE)
  annotation <- if (is.list(bg)) bg$annotation else NULL
  pick <- function(field) {
    for (source in list(annotation, settings)) {
      v <- workspace_recorded_value(project_first_scalar(source[[field]]))
      if (!is.na(v)) return(v)
    }
    NA_character_
  }
  list(species = pick("species"), keytype = pick("keytype"),
       annotation_type = pick("anntype"), ontology = pick("ontology"))
}

workspace_context_namespace <- function(context) {
  parts <- vapply(c("annotation_type", "ontology", "species", "keytype"), function(f) {
    v <- context[[f]]
    if (is.null(v) || length(v) != 1L || is.na(v) || !nzchar(v)) "unknown" else as.character(v)
  }, character(1))
  paste(parts, collapse = "/")
}

# Gene-overlap and term comparison across datasets needs the same species, key type
# and annotation; an unknown value is never assumed to match.
workspace_context_compatible <- function(a, b) {
  required <- c(species = "species", keytype = "key type", annotation_type = "annotation type")
  known <- function(x) !is.null(x) && length(x) == 1L && !is.na(x) && nzchar(x)
  for (field in names(required)) {
    if (!known(a[[field]]) || !known(b[[field]])) {
      return(list(supported = FALSE,
        reason = sprintf("Comparison unsupported: %s is not recorded for both datasets", required[[field]])))
    }
    if (!identical(tolower(a[[field]]), tolower(b[[field]]))) {
      return(list(supported = FALSE,
        reason = sprintf("Comparison unsupported: %s differs (%s and %s)", required[[field]],
                         a[[field]], b[[field]])))
    }
  }
  if (known(a$ontology) || known(b$ontology)) {
    if (!known(a$ontology) || !known(b$ontology)) {
      return(list(supported = FALSE,
        reason = "Comparison unsupported: ontology is not recorded for both datasets"))
    }
    if (!identical(tolower(a$ontology), tolower(b$ontology))) {
      return(list(supported = FALSE,
        reason = sprintf("Comparison unsupported: ontology differs (%s and %s)", a$ontology, b$ontology)))
    }
  }
  list(supported = TRUE, reason = NA_character_)
}

# @MX:ANCHOR: [AUTO] Stable row identity shared by the explorer table, figure,
# comparison and cluster link.
# @MX:REASON: results_explorer.R, rr_visualize_tab.R and clus_visualize_tab.R select
# rows only through these keys; changing the key recipe changes every linked view.
# One opaque key per source row: dataset identity + annotation namespace + qualified
# term ID. A term ID repeated inside one source table is told apart by its occurrence
# rank among the repeats (never by the table's row number for a unique ID). Rows with
# no term ID have no key and cannot be selected.
workspace_row_keys <- function(df, dataset_id, namespace) {
  cols <- workspace_term_columns(df)
  if (is.na(cols$id)) stop("Result has no term identifier column", call. = FALSE)
  ids <- as.character(df[[cols$id]])
  n <- length(ids)
  if (!n) return(character())
  occurrence <- rep(1L, n)
  for (rows in split(seq_len(n), ids)) {
    if (length(rows) > 1L) occurrence[rows] <- seq_along(rows)
  }
  keys <- vapply(seq_len(n), function(i) {
    project_short_id("rk", dataset_id, namespace, ids[i],
                     if (occurrence[i] > 1L) as.character(occurrence[i]) else "")
  }, character(1))
  keys[is.na(ids)] <- NA_character_
  keys
}

# Position of a key in the keys of the visible result; integer(0) when absent.
workspace_selection_index <- function(keys, key) {
  if (is.null(key) || length(key) != 1L || is.na(key)) return(integer())
  which(keys == key)
}

# Member genes of a term as text. The raw GeneID cell is left untouched.
workspace_member_genes <- function(x) {
  x <- as.character(x)
  x <- x[!is.na(x)]
  genes <- unlist(strsplit(x, "[,;|/[:space:]]+"), use.names = FALSE)
  unique(genes[nzchar(genes)])
}

# Session-local selection holder. Call it inside the server function so the
# reactives belong to that session. `info` carries the selected term's display text
# (id, label, dataset) for other views; it is never used as an identifier.
workspace_selection_state <- function() {
  list(key = shiny::reactiveVal(NULL), info = shiny::reactiveVal(NULL))
}

# Accepts one key that is among the known keys of the visible result; anything else
# is rejected and leaves the selection unchanged.
workspace_selection_set <- function(state, key, known, info = NULL) {
  if (!is.character(key) || length(key) != 1L || is.na(key) || !key %in% known) {
    return(FALSE)
  }
  if (!identical(shiny::isolate(state$key()), key)) state$key(key)
  if (!identical(shiny::isolate(state$info()), info)) state$info(info)
  TRUE
}

workspace_selection_clear <- function(state) {
  if (!is.null(shiny::isolate(state$key()))) state$key(NULL)
  if (!is.null(shiny::isolate(state$info()))) state$info(NULL)
  invisible(TRUE)
}
