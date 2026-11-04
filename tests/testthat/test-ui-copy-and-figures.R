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
