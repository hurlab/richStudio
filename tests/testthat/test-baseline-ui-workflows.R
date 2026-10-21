# Installed-module characterizations of synthetic local workflows. No annotation
# provider, clustering worker, browser, or production deployment is required.
ws_ui_args <- function(module, state) {
  state[intersect(names(formals(module)), names(state))]
}

test_that("characterize home and module UIs expose namespaced controls in application startup context", {
  # The installed application entry point attaches these declared imports before
  # constructing its UIs. Mirror that setup, and restore this process afterward.
  for (package in c("shinyjs", "shinyWidgets")) {
    attached <- paste0("package:", package)
    if (!attached %in% search()) {
      do.call(withr::defer, list(
        substitute(detach(name = NAME, character.only = TRUE), list(NAME = attached)),
        envir = environment()))
      library(package, character.only = TRUE)
    }
  }
  home <- as.character(richStudio:::homeTabUI("home", "welcome", "fixture-version"))
  expect_match(home, 'id="shiny-tab-welcome"', fixed = TRUE)
  expect_match(home, "vfixture-version", fixed = TRUE)
  expect_match(home, "Upload &amp; Enrich", fixed = TRUE)
  expect_match(home, "Visualize &amp; Export", fixed = TRUE)
  expect_match(home, 'alt="richStudio logo"', fixed = TRUE)
  cases <- list(
    list(richStudio:::enrichTabUI, "deg_files", "upload_degtext", "enrich_deg"),
    list(richStudio:::clusterUploadTabUI, "rr_files", "remove_rr", "remove_clus"),
    list(richStudio::clusterTabUI, "selected_rrs", "cluster_name", "cluster"),
    list(richStudio::updateTabUI, "rename_deg_btn", "rename_rr_btn", "rename_clus_btn")
  )
  for (case in cases) {
    html <- as.character(case[[1L]]("fixture", "workflow"))
    expect_match(html, 'id="shiny-tab-workflow"', fixed = TRUE)
    for (control in unlist(case[-1L])) {
      expect_match(html, paste0('id="fixture-', control, '"'), fixed = TRUE)
    }
  }
})

test_that("characterize enrichment column aliases preserve values and normalize schema", {
  provider <- data.frame(identity = c("GO:1", "GO:2"),
                         description = c("alpha", "beta"),
                         `P-value` = c(0.001, 0.02), FDR = c(0.01, NA_real_),
                         `gene list` = c("g1/g2", "g3/g4"),
                         ProviderExtra = c("keep outside normalization", "extra"),
                         check.names = FALSE)
  expected <- data.frame(ID = c("GO:1", "GO:2"), Term = c("alpha", "beta"),
                         Pvalue = c(0.001, 0.02), Padj = c(0.01, NA_real_),
                         GeneID = c("g1/g2", "g3/g4"))
  expect_identical(richStudio:::select_required_columns(provider), expected)
  expect_identical(richStudio:::select_required_columns(expected), expected)
  expect_identical(provider$ProviderExtra,
                   c("keep outside normalization", "extra"))
})

test_that("characterize DEG upload selects CSV and TSV and maintains metadata through edits", {
  csv <- withr::local_tempfile(fileext = ".csv")
  tsv <- withr::local_tempfile(fileext = ".tsv")
  first <- data.frame(GeneID = c("g1", "g2"), log2FC = c(2L, -1L))
  second <- data.frame(symbol = c("g3", "g4", "g5"))
  write.csv(first, csv, row.names = FALSE)
  write.table(second, tsv, sep = "\t", row.names = FALSE)
  state <- ws_baseline_state()
  shiny::testServer(richStudio:::enrichTabServer,
    args = ws_ui_args(richStudio:::enrichTabServer, state), {
      session$flushReact()
      session$setInputs(deg_files = data.frame(
        name = c("first.csv", "second.tsv"), datapath = c(csv, tsv)))
      expect_identical(u_degnames$labels, c("first.csv", "second.tsv"))
      expect_identical(u_degdfs[["first.csv"]], first)
      expect_identical(u_degdfs[["second.tsv"]], second)
      expect_identical(u_big_degdf$df, data.frame(
        name = c("first.csv", "second.tsv"),
        GeneID_header = c("GeneID", "symbol"), num_genes = c("2", "3"),
        has_expr_data = c("True", "False")))
      session$setInputs(deg_table_select = "first.csv")
      expect_identical(deg_colnames_reactive(), c("GeneID", "log2FC"))
      expect_identical(deg_to_table(), first)
      expect_match(jsonlite::fromJSON(output$deg_table)$x$container, "GeneID", fixed = TRUE)
      session$setInputs(deg_list_table_cell_edit = list(row = 1L, col = 1L, value = "renamed"))
      expect_null(u_degdfs[["first.csv"]])
      expect_identical(u_degdfs$renamed, first)
      expect_identical(u_big_degdf$df$name, c("renamed", "second.tsv"))
      session$setInputs(deg_list_table_rows_selected = 2L, remove_deg = 1L)
      expect_null(u_degdfs[["second.tsv"]])
      expect_identical(u_degnames$labels, "renamed")
      expect_identical(u_big_degdf$df$name, "renamed")
      expect_identical(u_degdfs$renamed, first)
    })
})

test_that("characterize pasted genes are parsed by the installed enrichment module", {
  state <- ws_baseline_state()
  shiny::testServer(richStudio:::enrichTabServer,
    args = ws_ui_args(richStudio:::enrichTabServer, state), {
      session$flushReact()
      session$setInputs(deg_text = "g1, g2;g3\ng4", degtext_name = "pasted", upload_degtext = 1L)
      expect_identical(u_degdfs$pasted, data.frame(GeneID = c("g1", "g2", "g3", "g4")))
      expect_identical(u_degnames$labels, "pasted")
      expect_identical(u_big_degdf$df, data.frame(name = "pasted", GeneID_header = "GeneID",
                                                num_genes = "4", has_expr_data = "False"))
    })
})

test_that("characterize result upload retains provider columns and raw versus adjusted values", {
  csv <- withr::local_tempfile(fileext = ".csv")
  tsv <- withr::local_tempfile(fileext = ".tsv")
  imported <- ws_baseline_inputs()$imported
  write.csv(imported, csv, row.names = FALSE)
  write.table(imported, tsv, sep = "\t", row.names = FALSE)
  state <- ws_baseline_state()
  shiny::testServer(richStudio:::clusterUploadTabServer,
    args = ws_ui_args(richStudio:::clusterUploadTabServer, state), {
      session$flushReact()
      session$setInputs(rr_files = data.frame(name = c("results.csv", "results.tsv"),
                                              datapath = c(csv, tsv)))
      expect_identical(u_rrnames$labels, c("results.csv", "results.tsv"))
      for (name in c("results.csv", "results.tsv")) {
        expect_identical(u_rrdfs[[name]], imported)
        expect_identical(u_rrdfs[[name]]$ProviderExtra,
                         c("retained-a", "retained-b", "retained-c", "strict-boundary"))
        expect_equal(u_rrdfs[[name]]$Pvalue, c(1e-8, 1e-7, 1e-6, 0.05))
        expect_equal(u_rrdfs[[name]]$Padj, c(0.9, 0.9, 0.9, 1e-5))
      }
      expect_identical(u_big_rrdf$df, data.frame(
        name = c("results.csv", "results.tsv"), from_deg = c("No", "No"),
        annot = c("?", "?"), keytype = c("?", "?"),
        ontology = c("?", "?"), species = c("?", "?")))
      session$setInputs(rr_table_select = "results.tsv")
      expect_identical(rr_to_table(), imported)
      expect_match(jsonlite::fromJSON(output$rr_table)$x$container, "ProviderExtra", fixed = TRUE)
      session$setInputs(rr_list_table_cell_edit = list(row = 1L, col = 3L, value = "GO"))
      expect_identical(u_big_rrdf$df$annot, c("GO", "?"))
      session$setInputs(rr_list_table_cell_edit = list(row = 1L, col = 1L, value = "renamed"))
      expect_null(u_rrdfs[["results.csv"]])
      expect_identical(u_rrdfs$renamed, imported)
      expect_identical(u_big_rrdf$df$name, c("renamed", "results.tsv"))
      session$setInputs(rr_list_table_rows_selected = 2L, remove_rr = 1L)
      expect_null(u_rrdfs[["results.tsv"]])
      expect_identical(u_rrnames$labels, "renamed")
      expect_identical(u_big_rrdf$df$name, "renamed")
      expect_identical(u_rrdfs$renamed, imported)
    })
})

test_that("characterize cluster table rename and removal move summary and membership together", {
  state <- ws_baseline_state(populated = TRUE)
  expected <- ws_baseline_cluster_tables()
  shiny::testServer(richStudio:::clusterUploadTabServer,
    args = ws_ui_args(richStudio:::clusterUploadTabServer, state), {
      session$flushReact()
      session$setInputs(clus_table_select = "fixture")
      expect_identical(clusdf_to_table(), expected$summary)
      expect_match(output$clus_table, "Representative_Term", fixed = TRUE)
      session$setInputs(clus_list_table_cell_edit = list(row = 1L, col = 1L, value = "renamed"))
      expect_null(u_clusdfs$fixture)
      expect_null(u_cluslists$fixture)
      expect_identical(u_clusdfs$renamed, expected$summary)
      expect_identical(u_cluslists$renamed, expected$cluster_list)
      expect_identical(u_clusnames$labels, "renamed")
      expect_identical(u_big_clusdf$df$name, "renamed")
      session$setInputs(clus_list_table_rows_selected = 1L, remove_clus = 1L)
      expect_null(u_clusdfs$renamed)
      expect_null(u_cluslists$renamed)
      expect_identical(u_clusnames$labels, character())
      expect_equal(nrow(u_big_clusdf$df), 0L)
      expect_identical(u_rrnames$labels, c("untreated", "treated"))
    })
})

test_that("characterize manage-files renames reject empty or duplicate names and preserve data", {
  state <- ws_baseline_state(populated = TRUE)
  payload <- ws_baseline_session()
  shiny::testServer(richStudio::updateTabServer,
    args = ws_ui_args(richStudio::updateTabServer, state), {
      session$flushReact()
      session$setInputs(rename_rr_select = "untreated", new_rr_name = "treated", rename_rr_btn = 1L)
      expect_identical(u_rrnames$labels, c("untreated", "treated"))
      expect_identical(u_rrdfs$untreated, payload$rrdfs$untreated)
      expect_identical(u_rrdfs$treated, payload$rrdfs$treated)
      session$setInputs(new_rr_name = "   ", rename_rr_btn = 2L)
      expect_identical(u_rrnames$labels, c("untreated", "treated"))
      session$setInputs(new_rr_name = "  renamed  ", rename_rr_btn = 3L)
      expect_identical(u_rrnames$labels, c("treated", "renamed"))
      expect_null(u_rrdfs$untreated)
      expect_identical(u_rrdfs$renamed, payload$rrdfs$untreated)
      session$setInputs(rename_deg_select = "query", new_deg_name = "genes", rename_deg_btn = 1L)
      expect_identical(u_degnames$labels, "genes")
      expect_null(u_degdfs$query)
      expect_identical(u_degdfs$genes, payload$degdfs$query)
      session$setInputs(rename_clus_select = "fixture", new_clus_name = "clusters", rename_clus_btn = 1L)
      expect_identical(u_clusnames$labels, "clusters")
      expect_null(u_clusdfs$fixture)
      expect_null(u_cluslists$fixture)
      expect_identical(u_clusdfs$clusters, payload$clusdfs$fixture)
      expect_identical(u_cluslists$clusters, payload$cluslists$fixture)
    })
})

test_that("characterize manage-files removal waits for confirmation and isolates selected datasets", {
  state <- ws_baseline_state(populated = TRUE)
  payload <- ws_baseline_session()
  shiny::testServer(richStudio::updateTabServer,
    args = ws_ui_args(richStudio::updateTabServer, state), {
      session$flushReact()
      session$setInputs(remove_rr_select = "treated", remove_rr_btn = 1L)
      expect_identical(u_rrnames$labels, c("untreated", "treated"))
      expect_identical(u_rrdfs$treated, payload$rrdfs$treated)
      session$setInputs(confirm_remove_rr = 1L)
      expect_identical(u_rrnames$labels, "untreated")
      expect_null(u_rrdfs$treated)
      expect_identical(u_rrdfs$untreated, payload$rrdfs$untreated)
      session$setInputs(remove_deg_select = "query", remove_deg_btn = 1L)
      expect_identical(u_degdfs$query, payload$degdfs$query)
      session$setInputs(confirm_remove_deg = 1L)
      expect_identical(u_degnames$labels, character())
      expect_null(u_degdfs$query)
      session$setInputs(remove_clus_select = "fixture", remove_clus_btn = 1L)
      expect_identical(u_cluslists$fixture, payload$cluslists$fixture)
      session$setInputs(confirm_remove_clus = 1L)
      expect_identical(u_clusnames$labels, character())
      expect_null(u_clusdfs$fixture)
      expect_null(u_cluslists$fixture)
      expect_identical(u_rrdfs$untreated, payload$rrdfs$untreated)
    })
})

test_that("characterize clustering controls render method-specific parameters without running algorithms", {
  state <- ws_baseline_state()
  args <- ws_ui_args(richStudio::clusterTabServer, state)
  args$clus_intermed <- shiny::reactiveValues()
  shiny::testServer(richStudio::clusterTabServer, args = args, {
    session$flushReact()
    for (case in list(c("richR", "richR_cutoff", "Kappa"),
                      c("hierarchical", "hier_distance_metric", "linkage"),
                      c("david", "david_similarity", "seed"))) {
      session$setInputs(clustering_method = case[[1L]])
      expect_match(output$method_params_ui$html, session$ns(case[[2L]]), fixed = TRUE)
      expect_match(output$method_description$html, case[[3L]], fixed = TRUE)
    }
    expect_null(u_clusnames$labels)
    expect_length(shiny::reactiveValuesToList(u_clusdfs), 0L)
  })
  expect_identical(richStudio:::build_cluster_params(list(), "richR"),
                   list(cutoff = 0.5, overlap = 0.5, minSize = 2))
  expect_identical(richStudio:::build_cluster_params(list(), "hierarchical"),
                   list(distance_metric = "kappa", distance_cutoff = 0.5,
                        linkage_method = "average", linkage_cutoff = 0.5,
                        min_terms = 2, min_value = 0.1))
  expect_identical(richStudio:::build_cluster_params(list(), "david"),
                   list(similarity_threshold = 0.5, initial_group_membership = 3,
                        final_group_membership = 3, multiple_linkage_threshold = 0.5))
  expect_identical(richStudio:::build_cluster_params(
    list(richR_cutoff = 0, richR_overlap = 0.7, richR_minSize = 4), "richR"),
    list(cutoff = 0, overlap = 0.7, minSize = 4))
})

test_that("characterize enrichment module manages existing result metadata without changing measurements", {
  state <- ws_baseline_state(populated = TRUE)
  rr <- ws_baseline_results()
  shiny::testServer(richStudio:::enrichTabServer,
    args = ws_ui_args(richStudio:::enrichTabServer, state), {
      session$flushReact()
      session$setInputs(rr_table_select = "treated")
      expect_identical(rr_to_table(), rr$treated)
      expect_match(jsonlite::fromJSON(output$rr_table)$x$container, "Padj", fixed = TRUE)
      session$setInputs(rr_list_table_cell_edit = list(row = 2L, col = 6L, value = "human"))
      expect_identical(u_big_rrdf$df$species, c("?", "human"))
      expect_identical(u_rrdfs$treated, rr$treated)
      session$setInputs(rr_list_table_cell_edit = list(row = 2L, col = 1L, value = "renamed"))
      expect_null(u_rrdfs$treated)
      expect_identical(u_rrdfs$renamed, rr$treated)
      expect_identical(u_rrnames$labels, c("untreated", "renamed"))
      expect_identical(u_big_rrdf$df$name, c("untreated", "renamed"))
      session$setInputs(rr_list_table_rows_selected = 1L, remove_rr = 1L)
      expect_null(u_rrdfs$untreated)
      expect_identical(u_rrnames$labels, "renamed")
      expect_identical(u_big_rrdf$df$name, "renamed")
      expect_identical(u_rrdfs$renamed$Padj, c(0.04, NA_real_, 0.3))
      expect_identical(u_degnames$labels, "query")
    })
})
