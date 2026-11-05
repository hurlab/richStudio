# SPEC-WS-013 M0: golden capture helpers (no behaviour change).
# Everything here is computed from the bundled demo data through existing package
# functions, so the goldens in tests/fixtures/ui-baseline/ describe the tree as it
# was before any M1 change. Numbers are text with 17 significant digits, keyed by
# term (never by position), so an ordering or layout change cannot hide a changed
# value and a display change cannot alter one.

ui_baseline_fixture_path <- function(name) {
  root <- Sys.getenv("WORKSPACE_SOURCE_ROOT", unset = "")
  path <- if (nzchar(root)) {
    file.path(root, "tests", "fixtures", "ui-baseline", name)
  } else {
    testthat::test_path("..", "fixtures", "ui-baseline", name)
  }
  normalizePath(path, mustWork = FALSE)
}

ui_baseline_num <- function(x) {
  out <- sprintf("%.17g", as.numeric(x))
  out[is.na(x)] <- NA_character_
  out
}

# Named list: key -> list of numeric columns as 17-digit text, sorted by key.
ui_baseline_keyed <- function(keys, ...) {
  cols <- list(...)
  keys <- as.character(keys)
  stopifnot(!anyDuplicated(keys))
  out <- lapply(seq_along(keys), function(i) {
    lapply(cols, function(col) {
      v <- col[[i]]
      if (is.character(v) || is.factor(v)) as.character(v) else ui_baseline_num(v)
    })
  })
  names(out) <- keys
  out[order(names(out), method = "radix")]
}

ui_baseline_labels <- c("go1", "go2", "kegg1")
ui_baseline_deg_labels <- c("deg_mouse1", "deg_mouse2", "deg_mouse3")
ui_baseline_cluster_params <- list(cutoff = 0.5, overlap = 0.5, minSize = 2)

# The bundled demo exactly as "Load demo results" and "Load demo" add them, plus
# one deterministic richR clustering of go1 and go2 under the default parameters.
ui_baseline_demo <- function() {
  rr <- lapply(ui_baseline_labels, function(l) {
    utils::read.delim(richStudio:::sample_rr_path(paste0(l, ".txt")))
  })
  names(rr) <- ui_baseline_labels
  deg <- lapply(ui_baseline_deg_labels, function(l) {
    utils::read.delim(richStudio:::sample_deg_path(paste0(l, ".txt")))
  })
  names(deg) <- ui_baseline_deg_labels
  cl <- richStudio:::workspace_cluster_compute(
    rr[c("go1", "go2")], "richR", ui_baseline_cluster_params, "clus1"
  )
  stopifnot(isTRUE(cl$success))
  list(rr = rr, deg = deg, cluster = cl)
}

# ---- figures ---------------------------------------------------------------

ui_baseline_plotly_cells <- function(plot, value = "z") {
  built <- plotly::plotly_build(plot)
  trace <- built$x$data[[1]]
  x <- as.character(trace$x)
  y <- as.character(trace$y)
  z <- trace[[value]]
  list(keys = paste(y, x, sep = " | "), values = z)
}

ui_baseline_heatmap <- function(plot) {
  cells <- ui_baseline_plotly_cells(plot)
  ui_baseline_keyed(cells$keys, value = cells$values)
}

ui_baseline_network <- function(net) {
  nodes <- net$data
  built <- ggplot2::ggplot_build(net)
  list(
    n_nodes = nrow(nodes),
    n_edge_rows = nrow(built$data[[1]]),
    # x/y come from a random layout and are deliberately not part of the golden.
    nodes = ui_baseline_keyed(
      nodes$label,
      color = nodes$color, size = nodes$size, shape = nodes$shape, alpha = nodes$alpha
    )
  )
}

ui_baseline_figures <- function(demo = ui_baseline_demo()) {
  rr <- demo$rr
  figs <- list(bar = list(), dot = list(), network = list())
  for (lab in names(rr)) {
    df <- rr[[lab]]
    for (spec in list(c("Padj", "rich"), c("Pvalue", "value"))) {
      data <- plotly::plotly_data(richStudio:::rr_bar(
        df, top = 25, pvalue = 0.05, value_type = spec[[1]], view = spec[[2]]
      ))
      figs$bar[[paste(lab, spec[[1]], spec[[2]], sep = ":")]] <- list(
        order = as.character(data$Term),
        values = ui_baseline_keyed(data$Term, final_value = data$final_value, rich = data$rich)
      )
    }
    for (type in c("Padj", "Pvalue")) {
      data <- plotly::plotly_data(richStudio:::rr_dot(
        df, top = 30, value_cutoff = 0.05, value_type = type
      ))
      figs$dot[[paste(lab, type, sep = ":")]] <- list(
        order = as.character(data$Term),
        values = ui_baseline_keyed(data$Term, final_value = data$final_value, rich = data$rich)
      )
    }
    figs$network[[lab]] <- ui_baseline_network(richStudio:::rr_network(rr = df, deg = NULL))
  }
  figs$network_has_nodes <- vapply(figs$network, function(n) n$n_nodes >= 1L, logical(1))

  # Enrichment heatmaps: top terms of go1 and go2 combined (Padj and Pvalue).
  figs$enrichment_heatmap <- list()
  for (type in c("Padj", "Pvalue")) {
    custom <- data.frame()
    for (lab in c("go1", "go2")) {
      custom <- richStudio:::add_topterm_gs(custom, rr[[lab]], lab, type, 0.05, 10)
    }
    figs$enrichment_heatmap[[type]] <- ui_baseline_heatmap(richStudio:::topterm_hmap(custom, type))
  }

  # Cluster heatmaps from the demo clustering result.
  cl <- demo$cluster
  summary_df <- cl$summary_df
  figs$cluster_table <- ui_baseline_keyed(
    summary_df$Cluster,
    representative = summary_df$Representative_Term,
    pvalue_go1 = summary_df$Pvalue_go1, pvalue_go2 = summary_df$Pvalue_go2,
    padj_go1 = summary_df$Padj_go1, padj_go2 = summary_df$Padj_go2
  )
  figs$cluster_heatmap <- list()
  for (type in c("Padj", "Pvalue")) {
    figs$cluster_heatmap[[paste0("summary:", type)]] <- ui_baseline_heatmap(
      richStudio:::comprehensive_hmap(
        final_data = summary_df, cluster_list = cl$cluster_df,
        value_type = type, value_by = "mean"
      )
    )
    term_vec <- paste0("cluster:", summary_df$Cluster)
    figs$cluster_heatmap[[paste0("terms:", type)]] <- ui_baseline_heatmap(
      richStudio:::cluster_hmap(
        cluster_list = cl$cluster_df, term_vec = term_vec,
        final_data = summary_df, value_type = type
      )
    )
  }
  figs
}

# ---- downloads, written by the real download handlers ------------------------

ui_baseline_download_record <- function(path) {
  lines <- readLines(path, warn = FALSE)
  list(
    name = basename(path),
    bytes = unname(file.size(path)),
    sha256 = digest::digest(path, algo = "sha256", file = TRUE),
    n_lines = length(lines),
    head = utils::head(lines, 3L)
  )
}

ui_baseline_state <- function(demo) {
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
  state$u_degnames$labels <- names(demo$deg)
  big_deg <- data.frame()
  for (lab in names(demo$deg)) {
    state$u_degdfs[[lab]] <- demo$deg[[lab]]
    big_deg <- richStudio::add_file_degdf(big_deg, lab, demo$deg[[lab]])
  }
  state$u_big_degdf$df <- big_deg
  state$u_rrnames$labels <- names(demo$rr)
  big_rr <- NULL
  for (lab in names(demo$rr)) {
    state$u_rrdfs[[lab]] <- demo$rr[[lab]]
    big_rr <- richStudio::add_file_rrdf(big_rr, name = lab, file = TRUE)
  }
  state$u_big_rrdf$df <- big_rr
  cl <- demo$cluster
  state$u_clusnames$labels <- "clus1"
  state$u_clusdfs[["clus1"]] <- cl$summary_df
  state$u_cluslists[["clus1"]] <- cl$cluster_df
  state$u_big_clusdf$df <- cl$new_row
  state
}

ui_baseline_module_args <- function(module, state) {
  state[intersect(names(formals(module)), names(state))]
}

ui_baseline_downloads <- function(demo = ui_baseline_demo()) {
  out <- list()
  # Results page importer module (cluster_upload_tab): .txt/.csv/.tsv per result.
  for (type in c(".txt", ".csv", ".tsv")) {
    for (lab in names(demo$rr)) {
      state <- ui_baseline_state(demo)
      shiny::testServer(
        richStudio:::cluster_upload_tab_server,
        args = ui_baseline_module_args(richStudio:::cluster_upload_tab_server, state), {
          session$flushReact()
          session$setInputs(rr_table_select = lab, rr_export_type = type)
          out[[paste("cluster_upload:rr", lab, type)]] <<- ui_baseline_download_record(output$download_rr)
        }
      )
    }
  }
  # Save page exports: enrichment results (csv, tsv) and the clustering summary.
  for (safe in c(FALSE, TRUE)) {
    for (format in c("csv", "tsv")) {
      for (lab in names(demo$rr)) {
        state <- ui_baseline_state(demo)
        shiny::testServer(
          richStudio:::saveTabServer,
          args = ui_baseline_module_args(richStudio:::saveTabServer, state), {
            session$flushReact()
            session$setInputs(export_rr_select = lab, export_rr_format = format, export_safe = safe)
            out[[paste("save:export_rr", lab, format, if (safe) "safe" else "exact")]] <<-
              ui_baseline_download_record(output$export_rr)
          }
        )
      }
    }
  }
  state <- ui_baseline_state(demo)
  shiny::testServer(
    richStudio:::saveTabServer,
    args = ui_baseline_module_args(richStudio:::saveTabServer, state), {
      session$flushReact()
      session$setInputs(export_clus_select = "clus1", export_clus_format = "csv", export_safe = FALSE)
      out[["save:export_clus clus1 csv exact"]] <<- ui_baseline_download_record(output$export_clus)
    }
  )
  out[order(names(out), method = "radix")]
}

# ---- SPEC-WS-004 input revision and query snapshot -----------------------------

ui_baseline_review_settings <- list(
  species = "human", anntype = "GO", keytype = "SYMBOL", ontology = "BP"
)

ui_baseline_revision <- function(demo = ui_baseline_demo()) {
  big <- data.frame()
  for (lab in names(demo$deg)) {
    big <- richStudio::add_file_degdf(big, lab, demo$deg[[lab]])
  }
  out <- list()
  for (lab in names(demo$deg)) {
    header <- as.character(big[big$name %in% lab, "GeneID_header"][[1]])
    snap <- richStudio:::review_resolve(
      demo$deg[[lab]], gene_header = header, cutoff = 0.05, name = lab,
      settings = ui_baseline_review_settings
    )
    stopifnot(isTRUE(snap$ok))
    out[[lab]] <- list(
      gene_col = snap$gene_col,
      query_rule = snap$query_rule,
      counts = snap$counts,
      note = snap$note,
      # The digest values depend on the R serialization of the table; they are
      # part of the golden so a change of the recorded revision is detected.
      source_digest = snap$source_digest,
      digest = snap$digest,
      submitted_n = length(snap$submitted),
      submitted_head = utils::head(snap$submitted, 5L),
      submitted_sha256 = digest::digest(snap$submitted, algo = "sha256"),
      items = vapply(
        richStudio:::review_snapshot_items(snap),
        function(li) paste(as.character(li$children[[1]]), collapse = ""), character(1)
      )
    )
  }
  out
}

ui_baseline_compute <- function(demo = ui_baseline_demo()) {
  list(
    figures = ui_baseline_figures(demo),
    downloads = ui_baseline_downloads(demo),
    revision = ui_baseline_revision(demo)
  )
}

# ---- project saved at the baseline ----------------------------------------------

ui_baseline_created <- as.POSIXct("2026-11-04 00:00:00", tz = "UTC")

ui_baseline_project_session <- function(demo = ui_baseline_demo()) {
  cl <- demo$cluster
  big_rr <- NULL
  for (lab in names(demo$rr)) big_rr <- richStudio::add_file_rrdf(big_rr, name = lab, file = TRUE)
  list(
    version = "1.0",
    created = ui_baseline_created,
    degnames = names(demo$deg),
    degdfs = demo$deg,
    rrnames = names(demo$rr),
    rrdfs = demo$rr,
    clusnames = "clus1",
    clusdfs = list(clus1 = cl$summary_df),
    cluslists = list(clus1 = cl$cluster_df),
    big_rrdf = list(df = big_rr),
    big_clusdf = list(df = cl$new_row)
  )
}

ui_baseline_project_write <- function(file, demo = ui_baseline_demo()) {
  richStudio:::project_write(
    ui_baseline_project_session(demo), list(), file, created = ui_baseline_created
  )
  invisible(file)
}

# Members compared by the test: the table payload, tracking metadata and manifest
# with the version-dependent fields removed (richStudio/R/engine versions change
# with the toolchain, not with the saved data).
ui_baseline_project_members <- function(zip_path) {
  dir <- tempfile("ui_baseline_zip_")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  utils::unzip(zip_path, exdir = dir)
  manifest <- jsonlite::fromJSON(file.path(dir, "manifest.json"), simplifyVector = FALSE)
  manifest$versions <- NULL
  manifest$files <- NULL
  list(
    members = sort(list.files(dir)),
    tables_sha256 = digest::digest(file.path(dir, "tables.json"), algo = "sha256", file = TRUE),
    tracking_sha256 = if (file.exists(file.path(dir, "tracking.json"))) {
      digest::digest(file.path(dir, "tracking.json"), algo = "sha256", file = TRUE)
    } else NA_character_,
    manifest = manifest
  )
}

# Maintainer entry point (not run by the tests): rewrites the four fixtures.
ui_baseline_write_goldens <- function(dir) {
  demo <- ui_baseline_demo()
  computed <- ui_baseline_compute(demo)
  write <- function(x, name) {
    jsonlite::write_json(x, file.path(dir, name), auto_unbox = TRUE, pretty = TRUE,
                         digits = I(17), na = "null", null = "null")
  }
  write(computed$figures, "figure-values.json")
  write(computed$downloads, "demo-downloads.json")
  write(computed$revision, "input-revision.json")
  ui_baseline_project_write(file.path(dir, "project-baseline.zip"), demo)
  invisible(computed)
}
