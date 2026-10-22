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
  expect_match(home, "Upload gene lists", fixed = TRUE)
  expect_match(home, "Load demo results", fixed = TRUE)
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

# Exercise the real future/promises callback queue, bounded even if publication
# fails. Sequential futures keep these module tests in the owning R process.
ws_ui_await <- function(predicate, session) {
  deadline <- Sys.time() + 10
  while (!predicate()) {
    if (Sys.time() > deadline) stop("Clustering did not publish before the test deadline")
    later::run_now(timeoutSecs = 0.01)
    session$flushReact()
  }
  later::run_now(timeoutSecs = 0)
  session$flushReact()
}

test_that("cluster button publishes hierarchical singleton statistics and dataset missingness", {
  previous_plan <- future::plan()
  withr::defer(future::plan(previous_plan))
  future::plan(future::sequential)
  withr::local_seed(42)
  state <- ws_baseline_state()
  raw <- ws_baseline_results()
  state$u_rrnames$labels <- names(raw)
  state$u_rrdfs$untreated <- raw$untreated
  state$u_rrdfs$treated <- raw$treated
  args <- ws_ui_args(richStudio::clusterTabServer, state)
  args$clus_intermed <- shiny::reactiveValues(DistanceMatrix = matrix(-1),
    cluster_summary = data.frame(stale = 1), cluster_df = data.frame(stale = 1),
    method = "stale", params = list(stale = 1))
  shiny::testServer(richStudio::clusterTabServer, args = args, {
    session$flushReact()
    session$setInputs(selected_rrs = c("untreated", "treated"), cluster_name = "singletons",
      clustering_method = "hierarchical", hier_distance_metric = "jaccard",
      hier_distance_cutoff = 0.1, hier_linkage_method = "average", hier_linkage_cutoff = 1,
      hier_min_terms = 1, hier_min_value = 0.05, cluster = 1L)
    ws_ui_await(function() "singletons" %in% u_clusnames$labels, session)
    terms <- u_cluslists$singletons
    expect_identical(terms$Term, c("A", "B", "C"))
    expect_equal(terms$Cluster, 1:3)
    expect_identical(terms$Representative_Term, c("A", "B", "C"))
    expect_equal(terms$Pvalue_untreated, c(1e-8, 1e-7, 1e-6))
    expect_equal(terms$Padj_untreated, rep(0.9, 3))
    expect_equal(terms$Pvalue_treated, c(0.02, NA_real_, 0.03))
    expect_equal(terms$Padj_treated, c(0.04, NA_real_, NA_real_))
    expect_identical(terms$GeneID_treated, c("g1,g2,g3", NA_character_, "g5,g6,g7"))
    summary <- u_clusdfs$singletons
    expect_equal(summary, data.frame(Cluster = 1:3, Representative_Term = c("A", "B", "C"),
      Pvalue_untreated = c(1e-8, 1e-7, 1e-6), Padj_untreated = rep(0.9, 3),
      Pvalue_treated = c(0.02, NA_real_, 0.03), Padj_treated = c(0.04, NA_real_, NA_real_)))
    expect_identical(u_big_clusdf$df, data.frame(name = "singletons", method = "hierarchical",
                                               n_clusters = 3L, n_terms = 3L))
    expect_identical(clus_intermed$cluster_df, terms)
    expect_identical(clus_intermed$method, "hierarchical")
    expect_identical(clus_intermed$params, list(distance_metric = "jaccard",
      distance_cutoff = 0.1, linkage_method = "average", linkage_cutoff = 1,
      min_terms = 1, min_value = 0.05))
    # A/B share two of four genes; C is disjoint. These values are independent
    # Jaccard oracles, not a second invocation of the clustering implementation.
    expect_equal(clus_intermed$DistanceMatrix, matrix(c(1, .5, 0, .5, 1, 0, 0, 0, 1),
      3, dimnames = list(c("A", "B", "C"), c("A", "B", "C"))))
    expect_identical(clus_intermed$cluster_summary$Representative_Term, c("A", "B", "C"))
    expect_equal(clus_intermed$cluster_summary$n_terms, rep(1, 3))
    expect_match(output$method_info, "Method: hierarchical", fixed = TRUE)
    expect_match(output$method_info, "distance_metric: jaccard", fixed = TRUE)
    expect_match(output$method_info, "min_value: 0.05", fixed = TRUE)
    expect_match(jsonlite::fromJSON(output$cluster_summary_table)$x$container,
                 "Representative_Term", fixed = TRUE)
    expect_match(jsonlite::fromJSON(output$cluster_details_table)$x$container,
                 "GeneID_treated", fixed = TRUE)
    expect_true(jsonlite::fromJSON(output$distanceMatrix_table)$x$options$serverSide)
    expect_identical(u_rrdfs$untreated, raw$untreated)
    expect_identical(u_rrdfs$treated, raw$treated)
  })
})

test_that("real clustering callbacks retain an overlapping pair and leave unrelated stores unchanged", {
  previous_plan <- future::plan()
  withr::defer(future::plan(previous_plan))
  future::plan(future::sequential)
  withr::local_seed(42)
  # Reuse the independently measured balanced two-cluster fixture in
  # test-dependency-kappa.R (richR enrichment scores 7.5 and 5.5). It has sorted
  # significance values and two separated overlap groups, unlike the retained
  # original imported-result counterexample whose representative is not first.
  fixture <- data.frame(Term = LETTERS[1:4], Annot = LETTERS[1:4],
    GeneID = c("g1,g2,g3", "g1,g2,g4", "g5,g6,g7", "g5,g6,g8"),
    Pvalue = c(1e-8, 1e-7, 1e-6, 1e-5), Padj = c(1e-8, 1e-7, 1e-6, 1e-5))
  state <- ws_baseline_state()
  state$u_rrnames$labels <- "local"
  state$u_rrdfs$local <- fixture
  args <- ws_ui_args(richStudio::clusterTabServer, state)
  args$clus_intermed <- shiny::reactiveValues()
  shiny::testServer(richStudio::clusterTabServer, args = args, {
    session$flushReact()
    session$setInputs(selected_rrs = "local", cluster_name = "kappa", clustering_method = "richR",
      richR_cutoff = .1, richR_overlap = 0, richR_minSize = 2, cluster = 1L)
    ws_ui_await(function() "kappa" %in% u_clusnames$labels, session)
    kappa <- u_cluslists$kappa
    expect_identical(kappa$Term, LETTERS[1:4])
    expect_equal(kappa$Cluster, c(1, 1, 2, 2))
    expect_identical(kappa$Representative_Term, c("A", "A", "C", "C"))
    expect_equal(kappa$Pvalue_local, c(1e-8, 1e-7, 1e-6, 1e-5))
    expect_equal(kappa$Padj_local, c(1e-8, 1e-7, 1e-6, 1e-5))
    expect_equal(u_clusdfs$kappa, data.frame(Cluster = 1:2, Representative_Term = c("A", "C"),
                                          Pvalue_local = c(1e-8, 1e-6), Padj_local = c(1e-8, 1e-6)))
    expect_equal(clus_intermed$cluster_summary$min_pvalue, c(1e-8, 1e-6))
    expect_null(clus_intermed$DistanceMatrix)
    expect_match(output$method_info, "cutoff: 0.1", fixed = TRUE)
    expect_match(jsonlite::fromJSON(output$cluster_details_table)$x$container,
                 "Pvalue_local", fixed = TRUE)
    session$setInputs(cluster_name = "david", clustering_method = "david",
      david_similarity = .1, david_initial_membership = 1, david_final_membership = 1,
      david_linkage = .5, cluster = 2L)
    ws_ui_await(function() "david" %in% u_clusnames$labels, session)
    david <- u_cluslists$david
    expect_identical(david$Term, LETTERS[1:4])
    expect_equal(david$Cluster, c(1, 1, 2, 2))
    expect_identical(david$Representative_Term, c("A", "A", "C", "C"))
    expect_equal(david$Pvalue_local, c(1e-8, 1e-7, 1e-6, 1e-5))
    expect_equal(david$Padj_local, c(1e-8, 1e-7, 1e-6, 1e-5))
    expect_equal(u_clusdfs$david, data.frame(Cluster = 1:2, Representative_Term = c("A", "C"),
                                          Pvalue_local = c(1e-8, 1e-6), Padj_local = c(1e-8, 1e-6)))
    expect_identical(u_clusnames$labels, c("kappa", "david"))
    expect_identical(u_cluslists$kappa, kappa)
    expect_identical(u_big_clusdf$df, data.frame(name = c("kappa", "david"),
      method = c("richR", "david"), n_clusters = c(2L, 2L), n_terms = c(4L, 4L)))
    expect_identical(clus_intermed$method, "david")
    expect_identical(clus_intermed$params, list(similarity_threshold = .1,
      initial_group_membership = 1, final_group_membership = 1, multiple_linkage_threshold = .5))
    expect_identical(clus_intermed$cluster_df, david)
    expect_identical(u_rrdfs$local, fixture)
  })
})

test_that("custom heatmap selection and term removal preserve disjoint datasets and unknown cells", {
  state <- ws_baseline_state()
  raw <- ws_baseline_results()
  state$u_rrnames$labels <- c("control", "case")
  state$u_rrdfs$control <- raw$untreated
  state$u_rrdfs$case <- raw$treated
  args <- ws_ui_args(richStudio:::rrVisTabServer, state)
  shiny::testServer(richStudio:::rrVisTabServer, args = args, {
    session$flushReact()
    session$setInputs(edit_hmap_box = "Custom terms", select_cushmap = "control",
      cushmap_select_table_rows_selected = 1:2, cushmap_valtype = "Padj",
      rr_delete_select = "control", cushmap_add_rr = 1L)
    expect_identical(rr_to_table(), raw$untreated)
    expect_match(jsonlite::fromJSON(output$cushmap_select_table)$x$container,
                 "ProviderExtra", fixed = TRUE)
    expect_identical(rr_term_vec_reactive$control, c("A", "B"))
    expect_identical(custom_data_reactive$df$Term, c("A", "B"))
    expect_equal(custom_data_reactive$df$Padj_control, c(.9, .9))
    session$setInputs(select_cushmap = "case", cushmap_select_table_rows_selected = 2:3,
                      cushmap_add_rr = 2L)
    joined <- custom_data_reactive$df
    expect_identical(joined$Term, c("A", "B", "D", "C"))
    expect_equal(joined$Pvalue_control, c(1e-8, 1e-7, NA_real_, NA_real_))
    expect_equal(joined$Padj_control, c(.9, .9, NA_real_, NA_real_))
    expect_equal(joined$Pvalue_case, c(NA_real_, NA_real_, .2, .03))
    expect_equal(joined$Padj_case, c(NA_real_, NA_real_, .3, NA_real_))
    expect_identical(joined$GeneID_case, c(NA_character_, NA_character_, "g5,g6,g8", "g5,g6,g7"))
    expect_identical(rr_term_vec_reactive$case, c("C", "D"))
    expect_identical(rr_custom_list_reactive$labels, c("control", "case"))
    session$setInputs(rr_term_delete_select = "B", delete_rr_terms = 1L)
    expect_identical(custom_data_reactive$df$Term, c("A", "D", "C"))
    expect_equal(custom_data_reactive$df$Pvalue_case, c(NA_real_, .2, .03))
    expect_identical(rr_term_vec_reactive$control, "A")
    session$setInputs(rr_term_delete_select = "A", delete_rr_terms = 2L)
    expect_identical(custom_data_reactive$df$Term, c("D", "C"))
    expect_equal(custom_data_reactive$df$Pvalue_case, c(.2, .03))
    expect_equal(custom_data_reactive$df$Padj_case, c(.3, NA_real_))
    expect_identical(rr_term_vec_reactive$control, character())
    # Removing the now-empty control leaves the independent case rows intact.
    # Deleting a populated result has a retained counterexample outside this test.
    session$setInputs(delete_rr = 1L)
    expect_identical(rr_custom_list_reactive$labels, "case")
    expect_false(any(grepl("_control$", names(custom_data_reactive$df))))
    expect_identical(custom_data_reactive$df$Term, c("D", "C"))
    expect_equal(custom_data_reactive$df$Pvalue_case, c(.2, .03))
    session$setInputs(cushmap_valtype = "Pvalue")
    values <- plotly::plotly_data(plot_custom_hmap())
    expect_identical(values$Term, c("D", "C"))
    expect_equal(values$value, c(.699, 1.5229))
    expect_identical(u_rrdfs$control, raw$untreated)
    expect_identical(u_rrdfs$case, raw$treated)
  })
})

test_that("top heatmap edits replace only the selected disjoint-label dataset", {
  state <- ws_baseline_state()
  raw <- ws_baseline_results()
  state$u_rrnames$labels <- c("control", "case")
  state$u_rrdfs$control <- raw$untreated
  state$u_rrdfs$case <- raw$treated
  shiny::testServer(richStudio:::rrVisTabServer,
    args = ws_ui_args(richStudio:::rrVisTabServer, state), {
      session$flushReact()
      session$setInputs(edit_hmap_box = "Top terms", select_tophmap = c("control", "case"),
        tophmap_valtype = "Pvalue", tophmap_cutoff = .05, tophmap_nterms = 3)
      expect_identical(top_hmap_to_table(), data.frame(
        name = c("control", "case"), value_type = c("Pvalue", "Pvalue"),
        value_cutoff = c("0.05", "0.05"), top_nterms = c("3", "3")))
      expect_identical(tt_custom_data_reactive$df$Term, c("A", "B", "C"))
      expect_equal(tt_custom_data_reactive$df$Pvalue_control, c(1e-8, 1e-7, 1e-6))
      expect_equal(tt_custom_data_reactive$df$Pvalue_case, c(.02, NA_real_, .03))
      expect_identical(tt_custom_data_reactive$df$Padj_case, c(.04, NA_real_, NA_real_))
      expect_match(jsonlite::fromJSON(output$tophmap_table)$x$container,
                   "top_nterms", fixed = TRUE)
      session$setInputs(tophmap_table_cell_edit = list(row = 1L, col = 4L, value = "1"))
      expect_identical(top_hmap_to_table()$top_nterms, c("1", "3"))
      selected <- tt_custom_data_reactive$df
      expect_identical(selected$Term, c("A", "C"))
      expect_equal(selected$Pvalue_control, c(1e-8, NA_real_))
      expect_equal(selected$Pvalue_case, c(.02, .03))
      expect_identical(selected$Padj_case, c(.04, NA_real_))
      session$setInputs(tophmap_table_cell_edit = list(row = 1L, col = 3L, value = "1e-9"))
      expect_identical(top_hmap_to_table()$value_cutoff, c("1e-9", "0.05"))
      expect_identical(tt_custom_data_reactive$df$Term, c("A", "C"))
      expect_true(all(is.na(tt_custom_data_reactive$df$Pvalue_control)))
      expect_equal(tt_custom_data_reactive$df$Pvalue_case, c(.02, .03))
      expect_identical(u_rrdfs$control, raw$untreated)
      expect_identical(u_rrdfs$case, raw$treated)
    })
})

test_that("clustering resets send supported defaults and valid-empty runs clear stale intermediates", {
  previous_plan <- future::plan()
  withr::defer(future::plan(previous_plan))
  future::plan(future::sequential)
  withr::local_seed(42)
  state <- ws_baseline_state()
  state$u_rrnames$labels <- "fixture"
  state$u_rrdfs$fixture <- ws_baseline_inputs()$imported
  args <- ws_ui_args(richStudio::clusterTabServer, state)
  args$clus_intermed <- shiny::reactiveValues(DistanceMatrix = matrix(1),
    cluster_df = data.frame(Term = "stale"), cluster_summary = data.frame(Term = "stale"),
    method = "hierarchical", params = list(min_value = 1))
  # Use a genuine owning test session: a module's session proxy is read-only.
  owned_session <- shiny::MockShinySession$new()
  withr::defer(owned_session$close())
  sent <- new.env(parent = emptyenv())
  sent$inputs <- list()
  sent$custom <- list()
  original_input <- owned_session$sendInputMessage
  original_custom <- owned_session$sendCustomMessage
  withr::defer({
    owned_session$sendInputMessage <- original_input
    owned_session$sendCustomMessage <- original_custom
  })
  # Call-through spies observe actual update*Input/shinyjs messages. No
  # calculation or namespace function is replaced.
  owned_session$sendInputMessage <- function(inputId, message) {
    sent$inputs[[inputId]] <- message
    original_input(inputId, message)
  }
  owned_session$sendCustomMessage <- function(type, message) {
    sent$custom[[length(sent$custom) + 1L]] <- list(type = type, message = message)
    original_custom(type, message)
  }
  shiny::testServer(richStudio::clusterTabServer, args = args, session = owned_session, {
    session$flushReact()
    session$setInputs(clustering_method = "richR", reset_params = 1L)
    expect_identical(sent$inputs$richR_cutoff$value, "0.5")
    expect_identical(sent$inputs$richR_overlap$value, "0.5")
    expect_identical(sent$inputs$richR_minSize$value, "2")
    session$setInputs(clustering_method = "hierarchical", reset_params = 2L)
    expect_identical(sent$inputs$hier_distance_metric$value, "kappa")
    expect_identical(sent$inputs$hier_distance_cutoff$value, "0.5")
    expect_identical(sent$inputs$hier_linkage_method$value, "average")
    expect_identical(sent$inputs$hier_linkage_cutoff$value, "0.5")
    expect_identical(sent$inputs$hier_min_terms$value, "2")
    expect_identical(sent$inputs$hier_min_value$value, "0.1")
    session$setInputs(clustering_method = "david", reset_params = 3L)
    expect_identical(sent$inputs$david_similarity$value, "0.5")
    expect_identical(sent$inputs$david_initial_membership$value, "3")
    expect_identical(sent$inputs$david_final_membership$value, "3")
    expect_identical(sent$inputs$david_linkage$value, "0.5")
    sent$custom <- list()
    # Strict raw filtering at the smallest raw Pvalue legitimately retains no
    # rows. It must not resurrect prior results or publish a synthetic cluster.
    session$setInputs(selected_rrs = "fixture", cluster_name = "empty",
      clustering_method = "hierarchical", hier_min_value = 1e-8, cluster = 1L)
    ws_ui_await(function() any(vapply(sent$custom,
      function(message) identical(message$type, "shinyjs-enable"), logical(1))), session)
    types <- vapply(sent$custom, `[[`, character(1), "type")
    expect_true("shinyjs-disable" %in% types)
    expect_true("shinyjs-enable" %in% types)
    expect_null(u_clusnames$labels)
    expect_length(shiny::reactiveValuesToList(u_clusdfs), 0L)
    expect_length(shiny::reactiveValuesToList(u_cluslists), 0L)
    expect_null(u_big_clusdf$df)
    for (key in c("DistanceMatrix", "cluster_summary", "cluster_df", "method", "params")) {
      expect_null(clus_intermed[[key]])
    }
  })
})

test_that("visualization uploads parse CSV and TSV while preserving an unrelated result", {
  csv <- withr::local_tempfile(pattern = "B3-owned-upload-csv-", fileext = ".csv")
  tsv <- withr::local_tempfile(pattern = "B3-owned-upload-tsv-", fileext = ".tsv")
  raw <- ws_baseline_results()
  uploaded <- raw$treated
  write.csv(uploaded, csv, row.names = FALSE)
  write.table(uploaded, tsv, sep = "\t", row.names = FALSE)
  state <- ws_baseline_state()
  state$u_rrnames$labels <- "sentinel"
  state$u_rrdfs$sentinel <- raw$untreated
  state$u_big_rrdf$df <- data.frame(name = "sentinel", from_deg = "No",
    annot = "?", keytype = "?", ontology = "?", species = "?")
  shiny::testServer(richStudio:::rrVisTabServer,
    args = ws_ui_args(richStudio:::rrVisTabServer, state), {
      session$flushReact()
      session$setInputs(rr_files = data.frame(name = c("result.csv", "result.tsv"),
                                               datapath = c(csv, tsv)))
      expect_identical(u_rrnames$labels, c("sentinel", "result.csv", "result.tsv"))
      expect_identical(u_big_rrdf$df, data.frame(
        name = c("sentinel", "result.csv", "result.tsv"), from_deg = rep("No", 3),
        annot = rep("?", 3), keytype = rep("?", 3), ontology = rep("?", 3), species = rep("?", 3)))
      for (name in c("result.csv", "result.tsv")) {
        expect_identical(u_rrdfs[[name]], uploaded)
        expect_identical(u_rrdfs[[name]]$Term, c("A", "C", "D"))
        expect_identical(u_rrdfs[[name]]$Pvalue, c(.02, .03, .2))
        expect_identical(u_rrdfs[[name]]$Padj, c(.04, NA_real_, .3))
        expect_identical(u_rrdfs[[name]]$ProviderExtra,
                         c("retained-a", "retained-c", "strict-boundary"))
        expect_identical(u_rrdfs[[name]]$Significant, rep(3L, 3))
        expect_identical(u_rrdfs[[name]]$Annotated, c(10L, 6L, 12L))
        session$setInputs(select_table = name)
        expect_identical(get_rr_table(), uploaded)
      }
      expect_identical(u_rrdfs$sentinel, raw$untreated)
      session$setInputs(select_table = "sentinel")
      expect_identical(get_rr_table(), raw$untreated)
      expect_identical(u_big_rrdf$df[1, ], data.frame(name = "sentinel", from_deg = "No",
        annot = "?", keytype = "?", ontology = "?", species = "?"))
    })
})
