# Existing display behavior only; these fixtures do not claim clustering output
# or the future workspace identity/provenance contract.

test_that("result and cluster controls retain namespaces and supported defaults", {
  rr <- as.character(richStudio:::rrVisTabUI("results", "result_tab"))
  cl <- as.character(richStudio:::clusVisTabUI("clusters", "cluster_tab"))
  for (id in c("select_table", "select_bar", "bar_valtype", "dot_cutoff",
               "select_tophmap", "cushmap_add_rr", "rr_term_delete_select")) {
    expect_match(rr, paste0('id="results-', id, '"'), fixed = TRUE)
  }
  expect_match(rr, "Enrichment Result Visualization", fixed = TRUE)
  expect_match(rr, '<option value="rich" selected>Rich score</option>', fixed = TRUE)
  expect_match(rr, '<option value="Padj" selected>Padj</option>', fixed = TRUE)
  expect_match(rr, 'id="results-bar_pvalue"[^>]*value="0[.]05"')
  for (id in c("clusdf_select", "big_value_type", "value_by",
               "indiv_clus_select", "small_value_type", "cluslist_table")) {
    expect_match(cl, paste0('id="clusters-', id, '"'), fixed = TRUE)
  }
  expect_match(cl, "No cluster data loaded", fixed = TRUE)
  expect_match(cl, "No clusters selected", fixed = TRUE)
  expect_match(cl, '<option value="mean" selected>mean</option>', fixed = TRUE)
})

test_that("bar coordinates distinguish strict raw cutoff from adjusted selection", {
  rr <- ws_baseline_results()$untreated
  original <- rr
  raw <- richStudio:::rr_bar(rr, value_type = "Pvalue", view = "value")
  data <- plotly::plotly_data(raw)
  expect_identical(as.character(data$Term), c("A", "B", "C"))
  expect_equal(data$final_value, c(8, 7, 6))
  expect_equal(data$rich, c(.3, .3, .5))
  expect_identical(levels(data$Term), c("C", "B", "A"))
  trace <- plotly::plotly_build(raw)$x$data[[1]]
  expect_equal(as.numeric(trace$x), c(8, 7, 6))
  expect_identical(as.character(trace$y), c("A", "B", "C"))
  expect_identical(trace$type, "bar")
  adjusted <- plotly::plotly_data(richStudio:::rr_bar(rr))
  expect_identical(as.character(adjusted$Term), "D")
  expect_equal(adjusted$rich, .25)
  expect_equal(adjusted$final_value, 5)
  expect_identical(adjusted$ProviderExtra, "strict-boundary")
  expect_identical(rr, original)
  expect_identical(as.character(plotly::plotly_data(
    richStudio:::rr_bar(rr, top = 2, value_type = "Pvalue"))$Term), c("A", "B"))
  # Equality is excluded, rather than rounded into the selected set.
  expect_identical(as.character(plotly::plotly_data(
    richStudio:::rr_bar(rr, pvalue = 1e-6, value_type = "Pvalue"))$Term), c("A", "B"))
  expect_error(richStudio:::rr_bar(rr, view = "unsupported"), "Invalid view parameter")
})

test_that("dot positions sizes and colors describe the same selected terms", {
  rr <- ws_baseline_results()$untreated
  raw <- plotly::plotly_build(richStudio:::rr_dot(rr, value_type = "Pvalue"))
  trace <- raw$x$data[[1]]
  expect_identical(as.character(trace$y), c("A", "B", "C"))
  expect_equal(as.numeric(trace$x), c(.3, .3, .5))
  expect_equal(as.numeric(trace$marker$color), c(8, 7, 6))
  expect_equal(as.numeric(trace$marker$size), c(3, 3, 3))
  expect_equal(trace$marker$sizeref, 6 / 64)
  expect_identical(trace$mode, "markers")
  expect_match(trace$text[[1]], "-log10(Pvalue): 8", fixed = TRUE)
  adjusted <- plotly::plotly_build(richStudio:::rr_dot(rr))$x$data[[1]]
  expect_identical(as.character(adjusted$y), "D")
  expect_equal(as.numeric(adjusted$x), .25)
  expect_equal(as.numeric(adjusted$marker$color), 5)
  boundary <- plotly::plotly_data(richStudio:::rr_dot(
    rr, value_type = "Pvalue", value_cutoff = 1e-6, top = 1))
  expect_identical(as.character(boundary$Term), "A")
})

test_that("custom joins retain dataset order membership and unknown numeric cells", {
  rr <- ws_baseline_results()
  joined <- richStudio:::add_custom_gs(NULL, rr$untreated, "untreated", c("A", "B", "C", "D"))
  joined <- richStudio:::add_custom_gs(joined, rr$treated, "treated", c("A", "C", "D"))
  expect_identical(joined$Term, c("A", "B", "D", "C"))
  expect_identical(joined$GeneID, c("g1,g2,g3", "g1,g2,g4", "g5,g6,g8", "g5,g6,g7"))
  expect_identical(joined$ProviderExtra_untreated,
                   c("retained-a", "retained-b", "strict-boundary", "retained-c"))
  absent <- joined[joined$Term == "B", ]
  unknown <- joined[joined$Term == "C", ]
  expect_true(is.na(absent$GeneID_treated))
  expect_true(is.na(absent$Pvalue_treated))
  expect_identical(unknown$GeneID_treated, "g5,g6,g7")
  expect_equal(unknown$Pvalue_treated, .03)
  expect_identical(unknown$Padj_treated, NA_real_)
  p <- richStudio:::custom_hmap(joined, "Padj")
  data <- plotly::plotly_data(p)
  expect_identical(levels(data$variable), c("untreated", "treated"))
  expect_identical(data$Term, rep(c("A", "B", "D", "C"), 2))
  expect_equal(data$value, c(.0458, .0458, 5, .0458, 1.3979, NA, .5229, NA))
  trace <- plotly::plotly_build(p)$x$data[[1]]
  expect_equal(as.numeric(trace$z), data$value)
  expect_identical(as.character(trace$x), rep(c("untreated", "treated"), each = 4))
  expect_identical(as.character(trace$y), data$Term)
  expect_error(richStudio:::custom_hmap(joined, "missing"), "Invalid value_type")
  removed <- richStudio:::remove_gs(joined, "untreated", "B")
  expect_identical(removed$Term, c("A", "D", "C"))
  expect_equal(removed$Padj_treated, c(.04, .3, NA))
})

test_that("top term tables preserve membership for disjoint dataset labels", {
  # SCI-RETENTION-001 remains unresolved for overlapping untreated/treated labels.
  # The byte-identical stronger test is retained in B4/original-counterexample.R
  # and must enter SPEC-WS-008/009 regression tests after the source repair.
  rr <- ws_baseline_results()
  top <- richStudio:::add_topterm_gs(data.frame(), rr$untreated,
                                    "control", "Pvalue", .05, 3)
  expect_identical(top$Term, c("A", "B", "C"))
  expect_equal(top$Pvalue_control, c(1e-8, 1e-7, 1e-6))
  top <- richStudio:::add_topterm_gs(top, rr$treated, "case", "Pvalue", .05, 3)
  expect_identical(top$Term, c("A", "B", "C"))
  expect_equal(top$Pvalue_case, c(.02, NA, .03))
  top <- richStudio:::add_topterm_gs(top, rr$untreated, "control", "Padj", .05, 3)
  expect_identical(top$Term, c("A", "D", "C"))
  expect_equal(top$Padj_control, c(NA, 1e-5, NA))
  expect_equal(top$Pvalue_case, c(.02, NA, .03))
  expect_warning(expect_error(richStudio:::add_topterm_gs(data.frame(), rr$untreated,
    "untreated", "Padj", "invalid", 3), "must be numeric"), "NAs introduced by coercion")
  expect_error(richStudio:::topterm_hmap(data.frame()), "No value columns found")
})

test_that("explicit gene network retains the overlapping term pair", {
  withr::local_seed(42)
  rr <- ws_baseline_results()$untreated
  original <- rr
  p <- richStudio:::rr_network(rr, deg = paste0("g", 1:8))
  expect_s3_class(p, "ggplot")
  expect_setequal(p$data$label, c("A", "B"))
  expect_identical(as.character(p$data$label), c("A", "B"))
  expect_true(all(is.finite(p$data$x)))
  expect_true(all(is.finite(p$data$y)))
  expect_equal(length(unique(p$data$color)), 1L)
  built <- ggplot2::ggplot_build(p)
  expect_gt(length(built$data), 0L)
  expect_identical(rr, original)
})

test_that("individual cluster heatmap preserves measured and unknown cells", {
  x <- ws_baseline_cluster_tables()
  original <- x
  p <- richStudio:::cluster_hmap(x$cluster_list, "A", x$summary)
  expect_s3_class(p, "plotly")
  traces <- plotly::plotly_build(p)$x$data
  main <- Filter(function(trace) identical(trace$type, "heatmap") &&
                   all(c("untreated", "treated") %in% colnames(trace$z)), traces)
  expect_length(main, 1)
  z <- main[[1]]$z
  expect_setequal(rownames(z), c("A", "B"))
  expect_identical(colnames(z), c("Padj", "untreated", "treated"))
  expect_equal(as.numeric(z["A", ]), c(.04575749056, .04575749056, 1.39794000867))
  expect_equal(as.numeric(z["B", ]), c(.04575749056, .04575749056, NA))
  expect_identical(x, original)
})

test_that("cluster summaries describe mean minimum median and maximum without changing source", {
  x <- ws_baseline_cluster_tables()
  original <- x
  mean <- richStudio:::change_finaldata_valueby(x$summary, x$cluster_list, "mean")
  expect_equal(mean$Pvalue_untreated, c(5.5e-8, .0250005))
  expect_equal(mean$Pvalue_treated, c(.02, .115))
  expect_equal(mean$Padj_untreated, c(.9, .450005))
  expect_equal(mean$Padj_treated, c(.04, .3))
  minimum <- richStudio:::change_finaldata_valueby(x$summary, x$cluster_list, "min")
  expect_equal(minimum$Pvalue_untreated, c(1e-8, 1e-6))
  expect_equal(minimum$Pvalue_treated, c(.02, .03))
  expect_equal(minimum$Padj_untreated, c(.9, 1e-5))
  expect_equal(minimum$Padj_treated, c(.04, .3))
  median <- richStudio:::change_finaldata_valueby(x$summary, x$cluster_list, "median")
  expect_equal(median$Pvalue_treated, c(.02, .115))
  maximum <- richStudio:::change_finaldata_valueby(x$summary, x$cluster_list, "max")
  expect_equal(maximum$Pvalue_treated, c(.02, .2))
  expect_identical(mean$Representative_Term, c("A", "D"))
  expect_identical(mean$n_terms, c(2L, 2L))
  expect_identical(x, original)
  p <- richStudio:::comprehensive_hmap(x$summary, x$cluster_list, "Pvalue", "min")
  data <- plotly::plotly_data(p)
  expect_identical(as.character(data$variable), c("untreated", "treated", "untreated", "treated"))
  expect_identical(data$Representative_Term, c("A", "A", "D", "D"))
  expect_equal(data$value, c(8, 1.699, 6, 1.5229))
  trace <- plotly::plotly_build(p)$x$data[[1]]
  expect_equal(as.numeric(trace$z), data$value)
  expect_match(trace$text[[1]], "Cluster 1<br>A", fixed = TRUE)
})

test_that("table formatting preserves labels provider content and typed missingness", {
  rr <- ws_baseline_results()$treated
  original <- rr
  # Nonnumeric scientific/provider content is retained with explicit diagnostics.
  diagnostics <- character()
  rounded <- withCallingHandlers(richStudio:::round_tbl(rr, 3), warning = function(w) {
    diagnostics <<- c(diagnostics, conditionMessage(w))
    invokeRestart("muffleWarning")
  })
  expect_length(diagnostics, 4)
  expect_true(all(grepl("round_tbl: 3 non-numeric value", diagnostics, fixed = TRUE)))
  expect_identical(rounded$Term, c("A", "C", "D"))
  expect_identical(rounded$GeneID, c("g1,g2,g3", "g5,g6,g7", "g5,g6,g8"))
  expect_identical(rounded$ProviderExtra, c("retained-a", "retained-c", "strict-boundary"))
  expect_true(is.na(rounded$Padj[[2]]))
  expect_equal(as.numeric(rounded$Pvalue), c(.02, .03, .2))
  expect_identical(richStudio:::format_cells(1e-8, 3), "1.000e-08")
  expect_identical(richStudio:::format_cells(1e6, 3), "1.000e+06")
  expect_equal(richStudio:::format_cells(.123456, 3), .123)
  expect_identical(rr, original)
})

test_that("result module selections use the chosen dataset without mutating result stores", {
  state <- ws_baseline_state(populated = TRUE)
  original <- ws_baseline_results()
  args <- state[intersect(names(state), names(formals(richStudio:::rrVisTabServer)))]
  shiny::testServer(richStudio:::rrVisTabServer, args = args, {
    session$flushReact()
    expect_error(get_rr_table(), class = "shiny.silent.error")
    expect_null(plot_topterm_heatmap())
    expect_null(plot_custom_hmap())
    session$setInputs(select_table = "treated", select_bar = "untreated",
      bar_nterms = 25, bar_pvalue = .05, bar_valtype = "Pvalue", bar_type = "value",
      select_dot = "treated", dot_nterms = 25, dot_cutoff = .05, dot_valtype = "Padj")
    expect_identical(get_rr_table(), original$treated)
    expect_identical(as.character(plotly::plotly_data(get_rr_barplot())$Term), c("A", "B", "C"))
    expect_identical(as.character(plotly::plotly_data(get_rr_dotplot())$Term), "A")
    session$setInputs(select_bar = "treated", bar_valtype = "Padj", bar_type = "rich")
    bar <- plotly::plotly_data(get_rr_barplot())
    expect_identical(as.character(bar$Term), "A")
    expect_equal(bar$rich, .3)
    session$setInputs(edit_hmap_box = "Top terms", select_tophmap = "untreated",
      tophmap_valtype = "Pvalue", tophmap_cutoff = .05, tophmap_nterms = 3)
    top <- plotly::plotly_data(plot_topterm_heatmap())
    expect_identical(top$Term, c("A", "B", "C"))
    expect_equal(top$value, c(8, 7, 6))
    session$setInputs(select_cushmap = "treated", cushmap_valtype = "Padj",
      cushmap_select_table_rows_selected = c(1, 2), rr_delete_select = "")
    session$setInputs(cushmap_add_rr = 1)
    custom <- plotly::plotly_data(plot_custom_hmap())
    expect_identical(custom$Term, c("A", "C"))
    expect_equal(custom$value, c(1.3979, NA))
    expect_identical(u_rrdfs$untreated, original$untreated)
    expect_identical(u_rrdfs$treated, original$treated)
  })
})

test_that("cluster module links selected summary representatives and term tables", {
  state <- ws_baseline_state(populated = TRUE)
  x <- ws_baseline_cluster_tables()
  args <- state[intersect(names(state), names(formals(richStudio:::clusVisTabServer)))]
  shiny::testServer(richStudio:::clusVisTabServer, args = args, {
    session$flushReact()
    expect_null(term_vec_reactive())
    expect_error(cluslist_to_table(), class = "shiny.silent.error")
    session$setInputs(big_value_type = "Padj", value_by = "mean",
                      clusdf_select = "fixture", cluslist_select = "fixture")
    expect_identical(term_vec_reactive(), c("A", "D"))
    expect_identical(cluslist_to_table(), x$cluster_list)
    expect_identical(u_clusdfs$fixture, x$summary)
    expect_identical(u_cluslists$fixture, x$cluster_list)
  })
})

test_that("cluster heatmap controls rerender and empty-state messages follow valid plots", {
  state <- ws_baseline_state()
  state$u_clusnames$labels <- "fixture"
  expected_summary <- data.frame(
    Cluster = 1L, Representative_Term = "A1", Pvalue_fixture = 0.01, Padj_fixture = 0.02
  )
  expected_terms <- data.frame(
    Cluster = c(1L, 1L), Term = c("A1", "A2"), Representative_Term = c("A1", "A1"),
    Pvalue_fixture = c(0.01, 0.04), Padj_fixture = c(0.02, 0.06)
  )
  state$u_clusdfs$fixture <- expected_summary
  state$u_cluslists$fixture <- expected_terms
  args <- state[intersect(names(state), names(formals(richStudio:::clusVisTabServer)))]
  args$id <- "clusters"
  owned_session <- shiny::MockShinySession$new()
  withr::defer(owned_session$close())
  sent <- new.env(parent = emptyenv())
  sent$custom <- list()
  original_custom <- owned_session$sendCustomMessage
  withr::defer(owned_session$sendCustomMessage <- original_custom)
  owned_session$sendCustomMessage <- function(type, message) {
    sent$custom[[length(sent$custom) + 1L]] <- list(type = type, message = message)
    original_custom(type, message)
  }

  shiny::testServer(richStudio:::clusVisTabServer, args = args, session = owned_session, {
    session$flushReact()
    session$setInputs(clusdf_select = "fixture", big_value_type = "Padj", value_by = "mean",
                      small_value_type = "Padj")
    padj <- output$clusdf_hmap
    expect_match(padj, "-log10(Padj) by Cluster", fixed = TRUE)

    session$setInputs(big_value_type = "Pvalue")
    pvalue <- output$clusdf_hmap
    expect_false(identical(padj, pvalue))
    expect_match(pvalue, "-log10(Pvalue) by Cluster", fixed = TRUE)

    session$setInputs(value_by = "min")
    minimum <- output$clusdf_hmap
    expect_false(identical(pvalue, minimum))
    expect_match(minimum, "-log10(Pvalue) by Cluster", fixed = TRUE)
    expect_identical(u_clusdfs$fixture, expected_summary)
    expect_identical(u_cluslists$fixture, expected_terms)

    session$setInputs(indiv_clus_select = "A1")
    expect_match(output$indiv_clus_hmap, "A1", fixed = TRUE)
    actions <- sent$custom
    expect_true(any(vapply(actions, function(x) identical(x$type, "shinyjs-hide") &&
      identical(x$message$id, "clusters-clusdf_hmap_empty"), logical(1))))
    expect_true(any(vapply(actions, function(x) identical(x$type, "shinyjs-hide") &&
      identical(x$message$id, "clusters-indiv_hmap_empty"), logical(1))))

    session$setInputs(clusdf_select = "", indiv_clus_select = character())
    session$flushReact()
    actions <- sent$custom
    expect_true(any(vapply(actions, function(x) identical(x$type, "shinyjs-show") &&
      identical(x$message$id, "clusters-clusdf_hmap_empty"), logical(1))))
    expect_true(any(vapply(actions, function(x) identical(x$type, "shinyjs-show") &&
      identical(x$message$id, "clusters-indiv_hmap_empty"), logical(1))))
  })
})
