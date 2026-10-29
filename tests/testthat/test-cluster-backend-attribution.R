test_that("clustering descriptions distinguish corrected and legacy backends", {
  methods <- get_clustering_methods()
  expect_identical(names(methods), c("richR", "hierarchical", "david"))
  expect_identical(methods$hierarchical$name, "Hierarchical Kappa/Jaccard - richCluster")
  expect_identical(methods$david$name, "DAVID-style - richCluster")
  expect_identical(methods$richR$name, "Legacy Kappa - richR")
  expect_match(methods$richR$description, "enrichment-score", fixed = TRUE)
  expect_match(methods$hierarchical$description, "richCluster", fixed = TRUE)
})

test_that("method selection keeps corrected Kappa as the default and names its filter", {
  state <- ws_baseline_state()
  state$clus_intermed <- shiny::reactiveValues()
  args <- state[intersect(names(state), names(formals(richStudio:::clusterTabServer)))]
  shiny::testServer(richStudio:::clusterTabServer, args = args, {
    session$flushReact()
    selector <- output$method_selector$html
    expect_match(selector, 'value="hierarchical" checked="checked"', fixed = TRUE)
    expect_match(selector, "Hierarchical Kappa/Jaccard - richCluster", fixed = TRUE)
    expect_match(selector, "DAVID-style - richCluster", fixed = TRUE)
    expect_match(selector, "Legacy Kappa - richR", fixed = TRUE)
    session$setInputs(clustering_method = "hierarchical")
    expect_match(output$method_params_ui$html, "Raw Pvalue Filter", fixed = TRUE)
    expect_match(output$method_params_ui$html, "strictly below", fixed = TRUE)
    expect_identical(richStudio:::build_cluster_params(list(), "hierarchical"), list(
      distance_metric = "kappa", distance_cutoff = 0.5, linkage_method = "average",
      linkage_cutoff = 0.5, min_terms = 2, min_value = 0.1
    ))
    session$setInputs(clustering_method = "richR")
    expect_match(output$method_description$html, "enrichment-score", fixed = TRUE)
  })
})

test_that("corrected Kappa dispatch agrees with an independent binary-membership oracle", {
  input <- data.frame(
    Term = c("A", "B", "C", "D"), Annot = paste0("id", 1:4),
    GeneID = c("g1,g2,g3", "g2,g3,g4", "g5,g6", "g1,g2,g3"),
    Pvalue = c(0.01, 0.02, 0.03, 0.04), Padj = c(0.8, 0.7, 0.6, 0.5)
  )
  original <- input
  result <- perform_clustering(input, method = "hierarchical", params = list(min_terms = 1),
                               gs_names = "fixture", raw_genesets = list(fixture = input))
  gene_sets <- strsplit(input$GeneID, ",", fixed = TRUE)
  names(gene_sets) <- input$Term
  universe <- unique(unlist(gene_sets))
  oracle <- function(a, b) {
    av <- universe %in% a
    bv <- universe %in% b
    observed <- mean(av == bv)
    chance <- mean(av) * mean(bv) + mean(!av) * mean(!bv)
    if (chance == 1) return(1)
    max(0, (observed - chance) / (1 - chance))
  }
  dm <- result$distance_matrix
  expected <- outer(rownames(dm), colnames(dm), Vectorize(function(a, b) {
    oracle(gene_sets[[a]], gene_sets[[b]])
  }))
  dimnames(expected) <- dimnames(dm)
  expect_equal(dm, expected, tolerance = 1e-12)
  expect_equal(dm["A", "D"], 1)
  expect_equal(dm["A", "C"], 0)
  expect_identical(result$raw_result$cluster_options$distance_metric, "kappa")
  expect_identical(result$raw_result$cluster_options$filter_on, "Pvalue")
  expect_identical(result$raw_result$df_list$fixture, input)
  expect_identical(result$method, "hierarchical")
  expect_identical(input, original)
  full <- input[1:2, ]
  full$GeneID <- c("g1,g2,g3", "g1,g2,g3")
  perfect <- perform_clustering(full, method = "hierarchical", params = list(min_terms = 1),
                                gs_names = "fixture", raw_genesets = list(fixture = full))
  expect_equal(unname(perfect$distance_matrix), matrix(1, 2, 2))
})

test_that("legacy enrichment-score errors guide users without invoking a replacement", {
  fallback_calls <- 0L
  testthat::local_mocked_bindings(
    cluster_richR = function(...) stop("Enrichment score too high, No significant cluster"),
    cluster_hierarchical = function(...) {
      fallback_calls <<- fallback_calls + 1L
      stop("unexpected replacement")
    },
    cluster_david = function(...) {
      fallback_calls <<- fallback_calls + 1L
      stop("unexpected replacement")
    },
    .package = "richStudio"
  )
  input <- data.frame(Term = "A", GeneID = "g1,g2", Pvalue = 0.01, Padj = 0.02)
  error <- tryCatch(perform_clustering(input, "richR"), error = identity)
  expect_s3_class(error, "error")
  expect_match(conditionMessage(error), "Enrichment score too high", fixed = TRUE)
  expect_match(conditionMessage(error), "Legacy Kappa - richR", fixed = TRUE)
  expect_match(conditionMessage(error), "Hierarchical Kappa/Jaccard - richCluster", fixed = TRUE)
  expect_identical(fallback_calls, 0L)
})

test_that("empty legacy results remain explicit non-results without new metadata", {
  testthat::local_mocked_bindings(
    cluster_richR = function(...) list(cluster_df = data.frame(), cluster_summary = data.frame()),
    .package = "richStudio"
  )
  input <- data.frame(Term = "A", GeneID = "g1,g2", Pvalue = 0.01, Padj = 0.02)
  result <- richStudio:::workspace_cluster_compute(list(fixture = input), "richR", list(), "legacy")
  expect_identical(result, list(success = FALSE))
})

test_that("a small real legacy score rejection retains its backend and guidance", {
  input <- data.frame(
    Term = c("A1", "A2", "A3", "B"), Annot = paste0("id", 1:4),
    GeneID = c(rep("g1,g2,g3", 3), "g4,g5,g6"), Pvalue = 0.9, Padj = 0.9
  )
  error <- tryCatch(perform_clustering(input, "richR"), error = identity)
  expect_s3_class(error, "error")
  expect_match(conditionMessage(error), "Enrichment score too high", fixed = TRUE)
  expect_match(conditionMessage(error), "Legacy Kappa - richR", fixed = TRUE)
  expect_match(conditionMessage(error), "For a different algorithm", fixed = TRUE)
})
