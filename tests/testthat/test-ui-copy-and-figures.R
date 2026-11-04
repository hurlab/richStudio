# SPEC-WS-013 M2 (copy and validation): AC-008 display formatting, AC-028 the
# refusal of an old .rds session. Display changes never alter stored values; the
# M0 goldens in tests/fixtures/ui-baseline/ are the reference.

test_that("AC-008 raw tracking-table names have display labels and the data is untouched", {
  spec <- richStudio:::workspace_display_spec
  df <- data.frame(name = c("a", "b"), GeneID_header = c("gene", "symbol"), num_genes = c("5", "7"),
                   has_expr_data = c("True", "False"), stringsAsFactors = FALSE)
  s <- spec(df)
  expect_identical(s$data, df)
  expect_identical(s$labels, c("name", "Gene ID column", "Genes", "Has expression data"))
  rr <- data.frame(name = "go1", from_deg = "No", annot = "?", keytype = "?", ontology = "?", species = "?")
  expect_identical(spec(rr)$labels, c("name", "Source gene list", "Annotation", "Gene ID type", "ontology", "species"))
  cl <- data.frame(Cluster = 1L, Representative_Term = "x", n_terms = 2L, min_pvalue = 0.001)
  expect_identical(spec(cl)$labels, c("Cluster", "Representative term", "Terms", "Smallest p-value"))
  for (raw in c("GeneID_header", "num_genes", "has_expr_data", "from_deg", "Representative_Term",
                "n_terms", "min_pvalue")) {
    expect_false(raw %in% richStudio:::workspace_display_label(raw), info = raw)
  }
})

test_that("AC-008 p-value columns are found and shown to three significant figures with an em-dash for unknown", {
  fmt <- richStudio:::workspace_format_p
  expect_identical(fmt(c(0.123456, 1e-8, 0.5, NA)), c("0.123", "1e-08", "0.5", "—"))
  expect_identical(fmt("?"), "—")
  expect_identical(fmt(0.000123456), "0.000123")
  df <- data.frame(Term = "t", Pvalue = 0.01234, Padj = 0.1, Pvalue_go1 = 1, p.adjust = 0.2, min_pvalue = 0.3,
                   Other = 1)
  expect_identical(richStudio:::workspace_display_spec(df)$p_columns, c(2L, 3L, 4L, 5L, 6L))
  # the formatter reads the value; it never rounds the stored one
  stored <- df
  invisible(richStudio:::workspace_format_p(stored$Pvalue))
  expect_identical(stored, df)
})

test_that("AC-008 display tables hide the row-name column and render unknown cells as an em-dash", {
  df <- data.frame(name = c("go1", "go2"), from_deg = c("No", "No"), annot = c("?", "?"),
                   Padj = c(0.0001234, NA), stringsAsFactors = FALSE)
  widget <- richStudio:::workspace_display_dt(df, editable = "cell")
  x <- widget$x
  expect_identical(unname(x$options$columnDefs[[1]]$targets), 0L)
  expect_false(isTRUE(x$options$columnDefs[[1]]$visible))
  expect_false(grepl("from_deg", paste(as.character(x$container), collapse = ""), fixed = TRUE))
  expect_match(paste(as.character(x$container), collapse = ""), "Source gene list", fixed = TRUE)
  renders <- vapply(x$options$columnDefs[-1], function(d) paste(as.character(d$render), collapse = ""), character(1))
  renders <- renders[nzchar(renders)]
  expect_length(renders, 2L)
  expect_true(all(grepl("\\u2014", renders, fixed = TRUE)))
  expect_true(any(grepl("toPrecision(3)", renders, fixed = TRUE)))
  # the table data is the stored data frame
  expect_identical(widget$x$data[[2]], df$name)
})

test_that("AC-008 the module tables show labels, not raw names", {
  state <- ws_baseline_state(populated = TRUE)
  args <- state[intersect(names(state), names(formals(richStudio:::rr_vis_tab_server)))]
  shiny::testServer(richStudio:::rr_vis_tab_server, args = args, {
    session$flushReact()
    html <- jsonlite::fromJSON(output$rr_list_table)$x$container
    expect_false(grepl("from_deg", html, fixed = TRUE))
    expect_match(html, "Source gene list", fixed = TRUE)
  })
  cargs <- state[intersect(names(state), names(formals(richStudio:::clus_vis_tab_server)))]
  shiny::testServer(richStudio:::clus_vis_tab_server, args = cargs, {
    session$flushReact()
    html <- jsonlite::fromJSON(output$clus_list_table)$x$container
    for (raw in c("n_clusters")) expect_false(grepl(raw, html, fixed = TRUE), info = raw)
    expect_match(html, "Clusters", fixed = TRUE)
    expect_match(html, "Source results", fixed = TRUE)
  })
  dstate <- ws_baseline_state(populated = TRUE)
  dargs <- dstate[intersect(names(dstate), names(formals(richStudio:::enrich_tab_server)))]
  shiny::testServer(richStudio:::enrich_tab_server, args = dargs, {
    session$flushReact()
    html <- jsonlite::fromJSON(output$deg_list_table)$x$container
    for (raw in c("GeneID_header", "num_genes", "has_expr_data")) expect_false(grepl(raw, html, fixed = TRUE), info = raw)
    expect_match(html, "Gene ID column", fixed = TRUE)
  })
})

test_that("AC-008 downloads still write original names and full precision (M0 golden)", {
  golden <- jsonlite::fromJSON(ui_baseline_fixture_path("demo-downloads.json"), simplifyVector = FALSE)
  demo <- ui_baseline_demo()
  state <- ui_baseline_state(demo)
  shiny::testServer(richStudio:::cluster_upload_tab_server,
    args = ui_baseline_module_args(richStudio:::cluster_upload_tab_server, state), {
      session$flushReact()
      session$setInputs(rr_table_select = "go1", rr_export_type = ".csv")
      record <- ui_baseline_download_record(output$download_rr)
      expected <- golden[["cluster_upload:rr go1 .csv"]]
      expect_identical(record$sha256, expected$sha256)
      expect_identical(record$head[[1]], "\"Annot\",\"Term\",\"Annotated\",\"Significant\",\"Pvalue\",\"Padj\",\"GeneID\"")
      expect_match(record$head[[2]], "2.27e-08", fixed = TRUE)
    })
  expect_identical(demo$rr$go1$Pvalue[[1]], 2.27e-08)
})

test_that("AC-028 the .rds refusal is short, says nothing was loaded, and keeps the steps in an expandable block", {
  ui <- richStudio:::workspace_rds_refusal_ui()
  html <- paste(as.character(ui), collapse = "")
  visible <- gsub("<details.*</details>", "", html)
  text <- gsub("<[^>]+>", "", visible)
  sentences <- strsplit(trimws(text), "(?<=[.!?])\\s+", perl = TRUE)[[1]]
  expect_lte(length(sentences), 3L)
  expect_match(text, "nothing was loaded", fixed = TRUE)
  expect_match(text, "Open a session saved as .json or a project (.zip) instead", fixed = TRUE)
  expect_false(grepl("Rscript", text, fixed = TRUE))
  expect_match(html, "<details class=\"rs-refusal-steps\">", fixed = TRUE)
  expect_false(grepl("<details[^>]* open", html))
  details <- sub(".*(<details.*</details>).*", "\\1", html)
  for (step in c("archive/refs/heads/main.zip", "unzip",
                 "Rscript scripts/convert-trusted-session.R my-session.rds my-session.json",
                 "jsonlite", "class=\"btn btn-default btn-sm rs-copy\"")) {
    expect_match(details, step, fixed = TRUE)
  }
  expect_match(details, "data-copy=\"Rscript scripts/convert-trusted-session.R my-session.rds my-session.json\"", fixed = TRUE)
})

test_that("AC-008 the Cluster page summary table and details table show labels, not raw names", {
  state <- ws_baseline_state()
  tables <- ws_baseline_cluster_tables()
  state$clus_intermed <- shiny::reactiveValues(
    cluster_summary = data.frame(Cluster = 1:2, Representative_Term = c("A", "D"), n_terms = c(2L, 2L),
                                 min_pvalue = c(0.9, 1e-5)),
    cluster_df = tables$cluster_list)
  args <- state[intersect(names(state), names(formals(richStudio:::clusterTabServer)))]
  shiny::testServer(richStudio:::clusterTabServer, args = args, {
    session$flushReact()
    html <- jsonlite::fromJSON(output$cluster_summary_table)$x$container
    for (raw in c("Representative_Term", "n_terms", "min_pvalue")) expect_false(grepl(raw, html, fixed = TRUE), info = raw)
    for (label in c("Representative term", "Terms", "Smallest p-value")) expect_match(html, label, fixed = TRUE)
    details <- jsonlite::fromJSON(output$cluster_details_table)$x$container
    expect_false(grepl("Representative_Term", details, fixed = TRUE))
  })
  # the stored summary is unchanged
  expect_identical(shiny::isolate(state$clus_intermed$cluster_summary$n_terms), c(2L, 2L))
})

test_that("AC-008 the importer-page tables show labels, not raw names", {
  state <- ws_baseline_state(populated = TRUE)
  args <- state[intersect(names(state), names(formals(richStudio:::cluster_upload_tab_server)))]
  shiny::testServer(richStudio:::cluster_upload_tab_server, args = args, {
    session$flushReact()
    expect_false(grepl("from_deg", jsonlite::fromJSON(output$rr_list_table)$x$container, fixed = TRUE))
    expect_false(grepl("n_clusters", jsonlite::fromJSON(output$clus_list_table)$x$container, fixed = TRUE))
    session$setInputs(clus_table_select = "fixture")
    expect_false(grepl("Representative_Term", jsonlite::fromJSON(output$clus_table)$x$container, fixed = TRUE))
    expect_match(jsonlite::fromJSON(output$clus_table)$x$container, "Representative term", fixed = TRUE)
  })
})

test_that("AC-008 the Explorer table renders unknown cells as an em-dash and numbers to three significant figures (formatSignif)", {
  state <- ws_baseline_state(populated = TRUE)
  args <- state[intersect(names(state), names(formals(richStudio:::rr_vis_tab_server)))]
  shiny::testServer(richStudio:::rr_vis_tab_server, args = args, {
    session$flushReact()
    session$setInputs(ex_result = "untreated")
    session$flushReact()
    widget <- jsonlite::fromJSON(output$ex_table, simplifyVector = FALSE)$x
    renders <- vapply(widget$options$columnDefs, function(d) paste(unlist(d$render), collapse = ""), character(1))
    expect_true(any(grepl("2014", renders, fixed = TRUE)))
    expect_true(any(grepl("3", vapply(widget$options$columnDefs, function(d) paste(unlist(d$render), collapse = ""), character(1)))))
    expect_false(grepl("Representative_Term|from_deg", paste(unlist(widget$container), collapse = ""), fixed = FALSE))
  })
  expect_identical(shiny::isolate(state$u_rrdfs$untreated), ws_baseline_results()$untreated)
})

# ---- SPEC-WS-013 M4 (AC-013, AC-029): figure legibility, display only -----------------------

m4_demo <- local({
  cache <- NULL
  function() {
    if (is.null(cache)) cache <<- ui_baseline_demo()
    cache
  }
})

m4_colour_stops <- function(plot) {
  attrs <- plotly::plotly_build(plot)$x$attrs
  unlist(lapply(attrs, function(a) a$colors))
}

m4_is_viridis <- function(colours) {
  length(colours) >= 2L && identical(tolower(colours[[1]]), tolower(grDevices::hcl.colors(9L, "viridis")[[1]])) &&
    !any(tolower(colours) %in% c("green", "red"))
}

m4_summary <- function(n) {
  ids <- seq_len(n) * 3L
  p <- seq_len(n) / (n * 10)
  list(
    summary = data.frame(Cluster = ids, Representative_Term = paste("term", ids),
                         Padj_a = p, Padj_b = rev(p), Pvalue_a = p / 2, Pvalue_b = rev(p) / 2),
    details = data.frame(Cluster = ids, Term = paste("term", ids), Representative_Term = paste("term", ids),
                         Padj_a = p, Padj_b = rev(p), Pvalue_a = p / 2, Pvalue_b = rev(p) / 2))
}

test_that("AC-013 enrichment and cluster heatmaps use a sequential viridis scale, not red-to-green", {
  demo <- m4_demo()
  custom <- data.frame()
  for (lab in c("go1", "go2")) custom <- richStudio:::add_topterm_gs(custom, demo$rr[[lab]], lab, "Padj", 0.05, 10)
  expect_true(m4_is_viridis(m4_colour_stops(richStudio:::topterm_hmap(custom, "Padj"))))
  expect_true(m4_is_viridis(m4_colour_stops(richStudio:::custom_hmap(custom, "Padj"))))
  summary_df <- demo$cluster$summary_df
  expect_true(m4_is_viridis(m4_colour_stops(
    richStudio:::comprehensive_hmap(summary_df, demo$cluster$cluster_df, "Padj", "mean"))))
  expect_identical(richStudio:::hmap_colors, grDevices::hcl.colors(9L, "viridis"))
  built <- plotly::plotly_build(richStudio:::cluster_hmap(demo$cluster$cluster_df,
    paste0("cluster:", summary_df$Cluster), summary_df, "Padj"))
  scales <- Filter(Negate(is.null), lapply(built$x$data, function(t) t$colorscale))
  expect_gt(length(scales), 0L)
  first <- scales[[1]][1L, 2L]
  channels <- as.numeric(strsplit(gsub("[^0-9,.]", "", first), ",")[[1]])
  # viridis starts at a dark purple (about 68, 1, 84); red-to-green scales do not
  expect_true(channels[[1]] < 100 && channels[[2]] < 30 && channels[[3]] > 60)
})

test_that("AC-013 the cluster heatmap shows the 30 most significant clusters by default and keeps every row", {
  f <- m4_summary(45L)
  all <- richStudio:::comprehensive_hmap(f$summary, f$details, "Padj", "mean")
  expect_false(isTRUE(attr(all, "hmap_limited")))
  m4_title <- function(plot) {
    t <- plotly::plotly_build(plot)$x$layout$title
    if (is.list(t)) t$text else t
  }
  expect_match(m4_title(all), "Rows 1–45 of 45", fixed = TRUE)
  top <- richStudio:::comprehensive_hmap(f$summary, f$details, "Padj", "mean", top_n = richStudio:::hmap_top_default)
  expect_identical(richStudio:::hmap_top_default, 30L)
  expect_true(isTRUE(attr(top, "hmap_limited")))
  expect_match(m4_title(top), "30 of 45 shown", fixed = TRUE)
  built <- plotly::plotly_build(top)
  trace <- built$x$data[[1]]
  # the built object keeps all 45 clusters x 2 datasets
  expect_length(unique(as.character(trace$y)), 45L)
  expect_length(trace$z, 90L)
  # the visible window is the first 30 categories, ordered most significant first
  array <- built$x$layout$yaxis$categoryarray
  expect_length(array, 45L)
  # the display counts from the top of the reversed axis: the most significant cluster is last
  expect_identical(array[[45]], "cluster:3")
  expect_equal(abs(diff(unlist(built$x$layout$yaxis$range))), 30, tolerance = 1)
  # same values as the unlimited figure, keyed by cluster and dataset
  key <- function(t) stats::setNames(unlist(t$z), paste(t$y, t$x))
  expect_equal(key(trace)[order(names(key(trace)))], key(plotly::plotly_build(all)$x$data[[1]])[order(names(key(plotly::plotly_build(all)$x$data[[1]])))])
  # at or below the limit nothing is hidden
  small <- m4_summary(30L)
  expect_false(isTRUE(attr(richStudio:::comprehensive_hmap(small$summary, small$details, "Padj", "mean", top_n = 30L), "hmap_limited")))
})

test_that("AC-013 bars are ordered by the plotted value and keep the golden values", {
  golden <- jsonlite::fromJSON(ui_baseline_fixture_path("figure-values.json"), simplifyVector = FALSE)
  rr <- m4_demo()$rr$go1
  data <- plotly::plotly_data(richStudio:::rr_bar(rr, top = 25, pvalue = 0.05, value_type = "Padj", view = "rich"))
  expect_identical(as.character(data$Term), unlist(golden$bar[["go1:Padj:rich"]]$order))
  expect_false(is.unsorted(rev(data$final_value)))
})

test_that("AC-013 dot plots carry a size legend and a title and axis labels that name the plotted variables", {
  rr <- m4_demo()$rr$go1
  built <- suppressWarnings(plotly::plotly_build(richStudio:::rr_dot(rr)))
  layout <- built$x$layout
  title <- if (is.list(layout$title)) layout$title$text else layout$title
  expect_match(title, "rich score", ignore.case = TRUE)
  expect_match(title, "-log10(Padj)", fixed = TRUE)
  expect_match(title, "size", ignore.case = TRUE)
  expect_false(identical(title, "-log10(Padj) for Enriched Terms"))
  axis_title <- if (is.list(layout$xaxis$title)) layout$xaxis$title$text else layout$xaxis$title
  expect_match(axis_title, "Rich score", fixed = TRUE)
  notes <- vapply(layout$annotations, function(a) a$text, character(1))
  expect_true(any(grepl("Size legend", notes, fixed = TRUE)))
  expect_true(any(grepl("significant genes", notes, fixed = TRUE)))
  bar_title <- built$x$data[[1]]$marker$colorbar$title
  expect_match(if (is.list(bar_title)) bar_title$text else bar_title, "-log10(Padj)", fixed = TRUE)
})

test_that("AC-013 enrichment-heatmap labels over the limit are truncated with the full label in the hover text", {
  long <- paste(rep("long term name", 8), collapse = " ")
  custom <- data.frame(Annot = c("a", "b"), Term = c(long, "short"), Annotated_x = 10, Significant_x = 3,
                       Pvalue_x = c(0.01, 0.02), Padj_x = c(0.02, 0.03), GeneID_x = "g1")
  custom$GeneID <- "g1"
  plot <- richStudio:::topterm_hmap(custom, "Padj")
  built <- plotly::plotly_build(plot)
  ticks <- built$x$layout$yaxis$ticktext
  expect_true(any(ticks == paste0(substr(long, 1L, 39L), intToUtf8(8230L))))
  expect_true(all(nchar(ticks) <= richStudio:::hmap_label_limit))
  expect_true(any(grepl(long, unlist(built$x$data[[1]]$text), fixed = TRUE)))
  expect_identical(richStudio:::hmap_truncate_labels("short"), "short")
})

test_that("AC-013 and AC-029 network nodes exist for the demo results, labels are legible and the colour legend is shown", {
  for (lab in names(m4_demo()$rr)) {
    net <- richStudio:::rr_network(m4_demo()$rr[[lab]])
    expect_gte(nrow(net$data), 1L)
    layer <- Filter(function(l) inherits(l$geom, "GeomTextRepel"), net$layers)[[1]]
    px <- layer$aes_params$size * ggplot2::.pt * 96 / 72
    expect_gte(px, 10)
    expect_false(identical(net$guides$guides$colour, "none"))
  }
  golden <- jsonlite::fromJSON(ui_baseline_fixture_path("figure-values.json"), simplifyVector = FALSE)
  net <- richStudio:::rr_network(m4_demo()$rr$go1)
  expect_identical(nrow(net$data), golden$network$go1$n_nodes)
})

test_that("AC-013 network: only the 15 most significant terms are labelled, every node is drawn, colours are viridis", {
  rr <- m4_demo()$rr$go1
  net <- richStudio:::rr_network(rr)
  layer <- Filter(function(l) inherits(l$geom, "GeomTextRepel"), net$layers)[[1]]
  labels <- layer$aes_params$label
  expect_length(labels, nrow(net$data))
  expect_identical(sum(nzchar(labels)), 15L)
  top <- rr$Term[order(rr$Padj)][seq_len(15L)]
  expect_setequal(labels[nzchar(labels)], intersect(top, net$data$label))
  expect_match(net$labels$caption, "Labels shown for the 15 most significant terms", fixed = TRUE)
  # the node data (and so the M0 golden) is untouched; only the colour scale is viridis
  scale <- net$scales$get_scales("colour")
  palette <- grDevices::hcl.colors(256L, "viridis")
  values <- unname(scale$palette(length(unique(net$data$color))))
  expect_true(all(toupper(substr(values, 1L, 7L)) %in% toupper(palette)))
  expect_false(any(toupper(values) %in% c("#FF0000", "#FFA500")))
})

test_that("AC-013 dot and bar plot heights grow with the number of displayed terms", {
  many <- data.frame(Annot = paste0("GO:", seq_len(60)), Term = paste("term", seq_len(60)),
                     Annotated = 100L, Significant = 5L + seq_len(60) %% 7L,
                     Pvalue = seq_len(60) / 1e4, Padj = seq_len(60) / 1e4, GeneID = "g1,g2")
  height <- function(plot) plotly::plotly_build(plot)$x$layout$height
  expect_identical(richStudio:::rr_term_plot_height(2L), 400L)
  for (n in c(25L, 50L)) {
    expect_identical(height(suppressWarnings(richStudio:::rr_dot(many, top = n))), richStudio:::rr_term_plot_height(n))
    expect_identical(height(richStudio:::rr_bar(many, top = n)), richStudio:::rr_term_plot_height(n))
  }
  expect_gte(richStudio:::rr_term_plot_height(25L), 18L * 25L)
  expect_gt(richStudio:::rr_term_plot_height(50L), richStudio:::rr_term_plot_height(25L))
  # long labels are truncated on the axis and complete in the hover text
  long <- many
  long$Term[1] <- paste(rep("long go term", 10), collapse = " ")
  built <- plotly::plotly_build(suppressWarnings(richStudio:::rr_dot(long, top = 25L)))
  expect_true(all(nchar(built$x$layout$yaxis$ticktext) <= richStudio:::hmap_label_limit))
  expect_true(any(grepl(long$Term[1], unlist(built$x$data[[1]]$text), fixed = TRUE)))
})
