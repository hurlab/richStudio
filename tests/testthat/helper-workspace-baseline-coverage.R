# Shared synthetic data for baseline characterization, not future workspace APIs.
# All work is lazy: sourcing this file only defines functions. Each call returns
# fresh objects. Direct source() callers outside testthat set WORKSPACE_SOURCE_ROOT.
ws_baseline_path <- function(name) {
  root <- Sys.getenv("WORKSPACE_SOURCE_ROOT", unset = "")
  path <- if (nzchar(root)) {
    file.path(root, "tests", "fixtures", "workspace", name)
  } else {
    testthat::test_path("..", "fixtures", "workspace", name)
  }
  normalizePath(path, mustWork = TRUE)
}

# Committed oracle: 20 background genes, two disjoint annotation sets of ten,
# query g1:g10. Imported values and provider columns are returned unchanged.
ws_baseline_inputs <- function() {
  list(
    annotation = read.delim(ws_baseline_path("annotation.tsv")),
    query = read.delim(ws_baseline_path("query.tsv")),
    background = read.delim(ws_baseline_path("background.tsv"))$gene,
    imported = read.delim(ws_baseline_path("imported-results.tsv"))
  )
}

# Existing rr_bar/rr_dot require Significant and Annotated in addition to the
# imported schema. Each row has three comma-delimited genes; rich scores are
# 0.3, 0.3, 0.5, 0.25. Counts are synthetic, not inferred enrichment estimates.
# Raw cutoff <0.05 selects A/B/C, adjusted cutoff <0.05 selects D.
# treated lacks B; its C has measured raw Pvalue but unknown Padj (NA_real_).
ws_baseline_results <- function() {
  untreated <- ws_baseline_inputs()$imported
  untreated$Significant <- rep(3L, 4L)
  untreated$Annotated <- c(10L, 10L, 6L, 12L)
  treated <- untreated[c(1L, 3L, 4L), , drop = FALSE]
  treated$Pvalue <- c(0.02, 0.03, 0.2)
  treated$Padj <- c(0.04, NA_real_, 0.3)
  rownames(treated) <- NULL
  list(untreated = untreated, treated = treated)
}

# Deterministic display tables, not an algorithm's claimed clustering output.
# cluster_list is term-level (cluslists); summary is cluster-level (clusdfs).
# Qualified values retain dataset identity. Representatives follow minimum Padj:
# A (tie with B), D. Summary counts/minima are independent fixture oracles.
ws_baseline_cluster_tables <- function() {
  rr <- ws_baseline_results()
  terms <- rr$untreated
  terms$Cluster <- c(1L, 1L, 2L, 2L)
  for (dataset in names(rr)) {
    index <- match(terms$Term, rr[[dataset]]$Term)
    for (column in c("Pvalue", "Padj", "GeneID")) {
      terms[[paste(column, dataset, sep = "_")]] <- rr[[dataset]][[column]][index]
    }
  }
  summary <- data.frame(
    Cluster = 1:2, Representative_Term = c("A", "D"),
    n_terms = c(2L, 2L), min_pvalue = c(0.9, 1e-5)
  )
  value_columns <- c("Pvalue_untreated", "Pvalue_treated",
                     "Padj_untreated", "Padj_treated")
  summary[value_columns] <- terms[c(1L, 4L), value_columns]
  list(cluster_list = terms, summary = summary)
}

# Plain, serializable version-1.0 saveTabServer payload with a fixed timestamp.
# Use table[FALSE, , drop=FALSE] in consumers for typed-empty legacy cases.
ws_baseline_session <- function() {
  rr <- ws_baseline_results()
  clusters <- ws_baseline_cluster_tables()
  list(
    version = "1.0", created = "2026-10-20T00:00:00Z",
    degnames = "query", degdfs = list(query = ws_baseline_inputs()$query),
    rrnames = names(rr), rrdfs = rr, clusnames = "fixture",
    clusdfs = list(fixture = clusters$summary),
    cluslists = list(fixture = clusters$cluster_list)
  )
}

# Fresh app argument names, including big metadata tables where populated.
# Call inside each test; reactive handles never enter the serializable payload.
ws_baseline_state <- function(populated = FALSE) {
  state <- list(
    u_degnames = shiny::reactiveValues(labels = NULL),
    u_degdfs = shiny::reactiveValues(),
    u_big_degdf = shiny::reactiveValues(),
    u_rrnames = shiny::reactiveValues(labels = NULL),
    u_rrdfs = shiny::reactiveValues(),
    u_big_rrdf = shiny::reactiveValues(),
    u_clusnames = shiny::reactiveValues(labels = NULL),
    u_clusdfs = shiny::reactiveValues(),
    u_big_clusdf = shiny::reactiveValues(),
    u_cluslists = shiny::reactiveValues()
  )
  if (populated) {
    payload <- ws_baseline_session()
    for (kind in c("deg", "rr", "clus")) {
      state[[paste0("u_", kind, "names")]]$labels <- payload[[paste0(kind, "names")]]
      for (name in names(payload[[paste0(kind, "dfs")]])) {
        state[[paste0("u_", kind, "dfs")]][[name]] <- payload[[paste0(kind, "dfs")]][[name]]
      }
    }
    state$u_cluslists$fixture <- payload$cluslists$fixture
    state$u_big_degdf$df <- richStudio::add_file_degdf(data.frame(), "query", payload$degdfs$query)
    metadata <- data.frame()
    for (name in payload$rrnames) {
      metadata <- richStudio::add_file_rrdf(metadata, name = name, file = TRUE)
    }
    state$u_big_rrdf$df <- metadata
    state$u_big_clusdf$df <- richStudio::add_file_clusdf(
      data.frame(), payload$clusdfs$fixture, "fixture", payload$rrnames
    )
  }
  state
}
