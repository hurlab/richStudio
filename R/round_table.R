# Functions to round off decimal places in dataframe tables

format_cells <- function(x, n) {
  if (abs(x) < 1e-5 || abs(x) > 1e+5) {
    # Historical inactive example: see the round_table.R section in
    # The reference is in `docs/development/historical-r-examples.md`.
    sprintf(paste0("%.", n, "e"), x)
  } else {
    # Historical inactive example: see the round_table.R section in
    # The reference is in `docs/development/historical-r-examples.md`.
    signif(x, digits = n)
    # Historical inactive example: see the round_table.R section in
    # The reference is in `docs/development/historical-r-examples.md`.
  }
}

round_tbl <- function(df, n) {
  df[] <- lapply(df, function(col) {
    numeric_col <- withCallingHandlers(
      as.numeric(col),
      warning = function(w) {
        if (grepl("NAs introduced by coercion", conditionMessage(w))) {
          invokeRestart("muffleWarning")
        }
      }
    )
    # Detect values that were non-NA strings but became NA after conversion
    coerced_na <- is.na(numeric_col) & !is.na(col) & nzchar(as.character(col))
    if (any(coerced_na)) {
      n_bad <- sum(coerced_na)
      sample_vals <- utils::head(unique(as.character(col[coerced_na])), 3)
      warning(
        sprintf(
          paste0(
            "round_tbl: %d non-numeric value(s) could not be ",
            "converted (e.g., %s)"
          ),
          n_bad,
          paste(sQuote(sample_vals), collapse = ", ")
        ),
        call. = FALSE
      )
    }
    is_numeric <- !is.na(numeric_col) & !is.na(col)
    col[is_numeric] <- vapply(
      numeric_col[is_numeric],
      function(x) as.character(format_cells(x, n)),
      character(1)
    )
    col
  })
  df
}

# ---- Display of tables (SPEC-WS-013 F9) -----------------------------------------
# Display formatting only: the stored data frames, the downloads and the saved
# projects keep their original names and full-precision values. Labels, the
# em-dash for unknown cells and three significant figures are applied by the
# browser (DT column renderers), so numeric columns still sort as numbers.

workspace_display_labels <- c(
  GeneID_header = "Gene ID column",
  num_genes = "Genes",
  has_expr_data = "Has expression data",
  from_deg = "Source gene list",
  annot = "Annotation",
  keytype = "Gene ID type",
  Representative_Term = "Representative term",
  n_terms = "Terms",
  n_clusters = "Clusters",
  min_pvalue = "Smallest p-value",
  from = "Source results",
  Pvalue = "P-value",
  Padj = "Adjusted p-value",
  p.adjust = "Adjusted p-value",
  Annotated = "Annotated genes",
  Significant = "Significant genes",
  GeneID = "Genes",
  Annot = "Term ID",
  Cluster = "Cluster"
)

# Columns whose values are p-values (also the per-dataset Pvalue_x / Padj_x).
workspace_display_p_pattern <- "^(Pvalue|Padj|p[.]adjust|pvalue|padj|min_pvalue)(_|$)"

# Text values that mean "unknown" in the tracking tables and imports.
workspace_display_unknown <- c("?", "NA", "NULL", "")

workspace_display_label <- function(name) {
  hit <- match(name, names(workspace_display_labels))
  ifelse(is.na(hit), name, unname(workspace_display_labels[hit]))
}

# One p-value as text: three significant figures, an em-dash when unknown.
workspace_format_p <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  vapply(
    x,
    function(v) {
      if (is.na(v)) {
        "\u2014"
      } else {
        format(signif(v, 3), digits = 3, scientific = (v != 0 && abs(v) < 1e-4))
      }
    },
    character(1)
  )
}

# What the browser needs to show `df`: the data itself (unchanged), the display
# labels, and the p-value columns.
workspace_display_spec <- function(df) {
  stopifnot(is.data.frame(df))
  list(
    data = df,
    labels = unname(workspace_display_label(names(df))),
    p_columns = grep(workspace_display_p_pattern, names(df))
  )
}

workspace_display_js_unknown <- paste0(
  "function(data, type) {",
  " if (type !== 'display') return data;",
  " if (data === null || data === undefined || data === '?' || data === 'NA' ||",
  " data === 'NULL' || data === '') return '\\u2014';",
  " return data; }"
)

workspace_display_js_p <- paste0(
  "function(data, type) {",
  " if (type !== 'display') return data;",
  " if (data === null || data === undefined || data === '' || data === '?' || data === 'NA') return '\\u2014';",
  " var v = Number(data); if (isNaN(v)) return data;",
  " return v === 0 ? '0' : Number(v.toPrecision(3)).toString(); }"
)

# A DT table with display labels, em-dash for unknown cells, p-values to three
# significant figures and no visible row-name column. The row-name column is
# hidden rather than dropped so the cell-edit column indexes stay those of the
# data (the editable tracking tables depend on them).
workspace_display_dt <- function(df, editable = FALSE, filter = "none", options = list(), labels = TRUE, ...) {
  spec <- workspace_display_spec(df)
  p_cols <- spec$p_columns
  all_cols <- seq_len(ncol(df))
  defs <- list(
    list(visible = FALSE, targets = 0L),
    list(targets = setdiff(all_cols, p_cols), render = DT::JS(workspace_display_js_unknown)),
    list(targets = p_cols, render = DT::JS(workspace_display_js_p))
  )
  defs <- Filter(function(d) length(d$targets) > 0L, defs)
  merged <- utils::modifyList(list(columnDefs = defs, autoWidth = FALSE), options)
  DT::datatable(
    df,
    rownames = TRUE,
    colnames = c("", if (isTRUE(labels)) spec$labels else names(df)),
    editable = editable,
    filter = filter,
    options = merged,
    class = "display compact rs-display-table",
    ...
  )
}
