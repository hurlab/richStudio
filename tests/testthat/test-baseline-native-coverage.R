# Existing installed-package behavior only; no source loader or engine substitute.
# The shared helper records the committed imported-table provenance and oracles.

test_that("characterize installed clustering engines and distinct native API", {
  expect_identical(as.character(utils::packageVersion("richR")), "0.1.5")
  expect_identical(as.character(utils::packageVersion("richCluster")), "2.0.1")
  methods <- richStudio::get_clustering_methods()
  expect_named(methods, c("richR", "hierarchical", "david"))
  expect_true(all(vapply(methods, function(x) x$available, logical(1))))
  expect_identical(names(formals(richStudio::richCluster)), c(
    "distanceMetric", "distanceCutoff", "mergeStrategy", "membershipCutoff",
    "termNameColumn", "geneIDColumn", "PvalueColumn"
  ))
  expect_false(identical(richStudio::richCluster, richR::richCluster))
  registered <- getDLLRegisteredRoutines("richStudio")$.Call
  expect_named(registered, "_richStudio_richCluster")
  expect_identical(registered[[1]]$numParameters, 7L)
  expect_false(getLoadedDLLs()[["richStudio"]][["dynamicLookup"]])
})

test_that("characterize normalization without losing unknown values or provider data", {
  input <- data.frame(
    Term = factor(c("B", "", NA, "A")), GeneID = factor(c("b", "x", "y", "a")),
    Pvalue = c("0.02", "0.03", "0.04", NA),
    Padj = c(NA, "0.1", "0.2", "0.9"), Provider = c("B-source", "", "", "A-source")
  )
  normalized <- richStudio:::normalize_geneset(input)
  expect_identical(normalized$Term, c("B", "A"))
  expect_identical(normalized$Annot, c("B", "A"))
  expect_identical(normalized$GeneID, c("b", "a"))
  expect_identical(normalized$Pvalue, c(0.02, NA_real_))
  expect_identical(normalized$Padj, c(NA_real_, 0.9))
  expect_identical(normalized$Provider, c("B-source", "A-source"))
  without_genes <- richStudio:::normalize_geneset(data.frame(Term = "unknown"))
  expect_identical(without_genes$GeneID, NA_character_)
  expect_identical(without_genes$Annot, "unknown")
  expect_null(richStudio:::normalize_geneset(NULL))
  expect_identical(richStudio:::normalize_geneset(input[FALSE, ]), input[FALSE, ])
})

test_that("characterize merged dataset order, provenance and absent versus measured NA", {
  raw <- ws_baseline_results()
  merged <- richStudio::merge_genesets(list(
    `untreated group` = raw$untreated, `untreated-group` = raw$treated
  ))
  expect_identical(merged$Term, c("A", "B", "C", "D"))
  expect_identical(merged$GeneID, c("g1,g2,g3", "g1,g2,g4", "g5,g6,g7", "g5,g6,g8"))
  expect_identical(merged$Annot, c("Alpha", "Beta", "Gamma", "Delta"))
  expect_equal(merged$Pvalue, c(0.010000005, 1e-7, 0.0150005, 0.125))
  expect_equal(merged$Padj, c(0.47, 0.9, 0.9, 0.150005))
  expect_identical(merged$ProviderExtra_untreated_group, c(
    "retained-a", "retained-b", "retained-c", "strict-boundary"
  ))
  # B was absent from treated; C was present with unknown adjusted probability.
  expect_identical(merged$GeneID_untreated_group_2, c(
    "g1,g2,g3", NA_character_, "g5,g6,g7", "g5,g6,g8"
  ))
  expect_identical(merged$Padj_untreated_group_2, c(0.04, NA_real_, NA_real_, 0.3))
  single <- richStudio::merge_genesets(list(raw$untreated[c(4L, 1L), ]))
  expect_identical(single$Term, c("D", "A"))
  expect_identical(single$GeneID_geneset_1, c("g5,g6,g8", "g1,g2,g3"))
  expect_equal(single$Pvalue, c(0.05, 1e-8))
})

test_that("characterize native positive kappa, seed indices and merged membership", {
  # Universe {g1,g2}; A=B={g1}. Po=1, Pe=(1/2)^2+(1/2)^2=1/2,
  # so ordinary Cohen kappa(A,B)=(1-1/2)/(1-1/2)=1 independently.
  # For A/C ordinary Cohen kappa is -1. This native API explicitly returns 0
  # for disjoint sets (DistanceMetric::getKappa common==0); 0 below characterizes
  # that convention, not an independent claim about general Cohen kappa.
  terms <- c("A", "B", "C")
  result <- richStudio::richCluster(
    "kappa", 0.5, "DAVID", 0.7, terms, c("g1", "g1", "g2"), c(0.01, 0.02, 0.03)
  )
  expect_named(result, c("DistanceMatrix", "SeedMap", "FilteredSeeds", "MergedSeeds"))
  expect_equal(result$DistanceMatrix, matrix(c(
    -99, 1, 0, 1, -99, 0, 0, 0, -99
  ), 3L, dimnames = list(terms, terms)))
  # C++ unordered containers promise membership, not string/row iteration order.
  for (seed in list(result$SeedMap, result$FilteredSeeds)) {
    seed <- seed[order(seed$Term_Index), ]
    expect_identical(seed$Term, c("A", "B"))
    expect_identical(seed$Term_Index, 0:1)
    expect_identical(seed$SignificantTermPairs, c("B", "A"))
    expect_identical(seed$SignificantTermPair_Indices, c("1", "0"))
  }
  expect_equal(nrow(result$MergedSeeds), 1L)
  expect_setequal(strsplit(result$MergedSeeds$Cluster, ", ", fixed = TRUE)[[1]], c("A", "B"))
  expect_setequal(strsplit(result$MergedSeeds$ClusterIndices, ", ", fixed = TRUE)[[1]], c("0", "1"))
})

test_that("characterize native singleton and disjoint input invariants", {
  singleton <- richStudio::richCluster("kappa", 0.5, "DAVID", 0.7, "only", "g1", 0.01)
  expect_equal(singleton$DistanceMatrix, matrix(-99, 1L, dimnames = list("only", "only")))
  expect_equal(vapply(singleton[-1L], nrow, integer(1)), c(SeedMap = 0L, FilteredSeeds = 0L, MergedSeeds = 0L))
  terms <- c("third", "first", "second")
  for (cutoff in c(0.1, 0.9)) {
    disjoint <- richStudio::richCluster(
      "kappa", cutoff, "DAVID", 0.7, terms, c("g3", "g1", "g2"), c(0.3, 0.1, 0.2)
    )
    expect_identical(rownames(disjoint$DistanceMatrix), terms)
    expect_identical(colnames(disjoint$DistanceMatrix), terms)
    expect_equal(diag(disjoint$DistanceMatrix), stats::setNames(rep(-99, 3L), terms))
    expect_equal(unname(disjoint$DistanceMatrix[row(disjoint$DistanceMatrix) != col(disjoint$DistanceMatrix)]), rep(0, 6L))
    expect_equal(vapply(disjoint[-1L], nrow, integer(1)), c(SeedMap = 0L, FilteredSeeds = 0L, MergedSeeds = 0L))
  }
})

test_that("characterize richR route membership, explicit background and representatives", {
  input <- ws_baseline_inputs()$imported
  params <- list(cutoff = 0.1, overlap = 0, minSize = 2)
  result <- richStudio::perform_clustering(input, "richR", params, gs_names = "fixture")
  # Background is the union of the actual submitted eight genes, not query.tsv
  # or the enrichment fixture's twenty-gene universe. Different domains stay distinct.
  direct <- richR::richCluster(input, gene = paste0("g", 1:8), cutoff = 0.1, overlap = 0, minSize = 2)
  expect_equal(result$raw_result, direct)
  expect_identical(result$method, "richR")
  expect_identical(result$params, params)
  expect_identical(result$cluster_df$Term, c("A", "B", "C", "D"))
  expect_equal(result$cluster_df$Cluster, c(1, 1, 2, 2))
  expect_equal(result$cluster_df$Pvalue_fixture, c(1e-8, 1e-7, 1e-6, 0.05))
  expect_equal(result$cluster_df$Padj_fixture, c(0.9, 0.9, 0.9, 1e-5))
  expect_identical(result$cluster_df$GeneID_fixture, input$GeneID)
  expect_identical(result$cluster_summary$Representative_Term, c("A", "D"))
  expect_equal(result$cluster_summary$n_terms, c(2, 2))
  expect_equal(result$cluster_summary$min_pvalue, c(0.9, 1e-5))
})

test_that("characterize supported richR no-cluster error and dispatcher context", {
  input <- ws_baseline_inputs()$imported
  # Installed richR help defines minSize as the minimum term count. Both pairs
  # have size two; .kappa_cluster_internal deliberately errors when no scores
  # remain. perform_clustering intentionally wraps that provider condition.
  expect_error(richR::richCluster(input, gene = paste0("g", 1:8),
    cutoff = 0.1, overlap = 0, minSize = 3),
    "^Enrichment score too high, No significant cluster\\n$")
  expect_error(richStudio::perform_clustering(input, "richR",
    list(cutoff = 0.1, overlap = 0, minSize = 3)),
    "^Clustering failed: Enrichment score too high, No significant cluster\\n$")
})

test_that("characterize hierarchical strict raw filtering and independent Jaccard values", {
  input <- ws_baseline_inputs()$imported
  params <- list(distance_metric = "jaccard", distance_cutoff = 0.1,
                 linkage_method = "average", linkage_cutoff = 1, min_terms = 1, min_value = 0.05)
  result <- richStudio::perform_clustering(input, "hierarchical", params,
    gs_names = "fixture", raw_genesets = list(fixture = input))
  expect_identical(result$method, "hierarchical")
  expect_identical(result$params, params)
  # Raw values A/B/C <.05 survive even with adjusted .9; D at exactly .05
  # is excluded despite adjusted 1e-5. No adjusted-value filter is substituted.
  expect_identical(result$raw_result$df_list$fixture$Term, c("A", "B", "C"))
  expect_identical(result$cluster_df$Term, c("A", "B", "C"))
  expect_equal(result$cluster_df$Cluster, 1:3)
  expect_equal(result$cluster_df$Pvalue_fixture, c(1e-8, 1e-7, 1e-6))
  expect_equal(result$cluster_df$Padj_fixture, rep(0.9, 3L))
  # A/B share g1,g2 among g1,g2,g3,g4: Jaccard=2/4=.5. C disjoint.
  expect_equal(result$distance_matrix, matrix(c(1, 0.5, 0, 0.5, 1, 0, 0, 0, 1),
    3L, dimnames = list(c("A", "B", "C"), c("A", "B", "C"))))
  expect_identical(result$cluster_summary$Representative_Term, c("A", "B", "C"))
  expect_equal(result$cluster_summary$n_terms, rep(1, 3L))
  expect_false(any(grepl("^(Pvalue|Padj|GeneID)_[0-9]+$", names(result$cluster_df))))
  empty <- richStudio::perform_clustering(input, "hierarchical",
    modifyList(params, list(min_value = 1e-8)), raw_genesets = list(fixture = input))
  expect_identical(empty$cluster_df, data.frame())
  expect_identical(empty$cluster_summary, data.frame())
  expect_null(empty$raw_result)
  expect_null(empty$distance_matrix)
})

test_that("characterize hierarchical per-dataset missingness after raw filtering", {
  raw <- ws_baseline_results()
  result <- richStudio::perform_clustering(richStudio::merge_genesets(raw), "hierarchical",
    params = list(distance_metric = "jaccard", distance_cutoff = 0.1,
                  linkage_cutoff = 1, min_terms = 1, min_value = 0.05),
    gs_names = names(raw), raw_genesets = raw)
  expect_identical(result$raw_result$df_list$untreated$Term, c("A", "B", "C"))
  expect_identical(result$raw_result$df_list$treated$Term, c("A", "C"))
  expect_identical(result$cluster_df$Term, c("A", "B", "C"))
  expect_identical(result$cluster_df$GeneID_treated, c("g1,g2,g3", NA_character_, "g5,g6,g7"))
  expect_equal(result$cluster_df$Pvalue_treated, c(0.02, NA_real_, 0.03))
  expect_equal(result$cluster_df$Padj_treated, c(0.04, NA_real_, NA_real_))
  expect_equal(result$cluster_df$Pvalue_untreated, c(1e-8, 1e-7, 1e-6))
  expect_equal(result$cluster_df$Padj_untreated, rep(0.9, 3L))
  expect_false("D" %in% result$cluster_df$Term)
})

test_that("characterize DAVID explicit raw input and adjusted representative selection", {
  input <- ws_baseline_inputs()$imported
  params <- list(similarity_threshold = 0.1, initial_group_membership = 1,
                 final_group_membership = 1, multiple_linkage_threshold = 0.5)
  result <- richStudio::perform_clustering(input, "david", params,
    gs_names = "fixture", raw_genesets = list(fixture = input))
  expect_identical(result$method, "david")
  expect_identical(result$params, params)
  expect_identical(result$raw_result$df_list$fixture$Term, c("A", "B", "C", "D"))
  expect_identical(result$cluster_df$Term, c("A", "B", "C", "D"))
  expect_equal(result$cluster_df$Cluster, c(1, 1, 2, 2))
  expect_equal(result$cluster_df$Pvalue_fixture, c(1e-8, 1e-7, 1e-6, 0.05))
  expect_equal(result$cluster_df$Padj_fixture, c(0.9, 0.9, 0.9, 1e-5))
  expect_identical(result$cluster_df$GeneID_fixture, input$GeneID)
  expect_identical(result$cluster_summary$Representative_Term, c("A", "D"))
  expect_equal(result$cluster_summary$min_pvalue, c(0.9, 1e-5))
  expect_equal(result$cluster_summary$n_terms, c(2, 2))
  expect_false(any(grepl("^(Pvalue|Padj|GeneID)_[0-9]+$", names(result$cluster_df))))
})

test_that("characterize summary probability priority, ties and missing-statistic fallback", {
  fixture <- ws_baseline_cluster_tables()
  adjusted <- richStudio:::build_cluster_summary(fixture$cluster_list)
  expect_equal(as.data.frame(adjusted), fixture$summary[, 1:4])
  raw <- fixture$cluster_list
  raw$Padj <- NULL
  raw_summary <- richStudio:::build_cluster_summary(raw)
  expect_identical(raw_summary$Representative_Term, c("A", "C"))
  expect_equal(raw_summary$min_pvalue, c(1e-8, 1e-6))
  without_stats <- raw[, c("Cluster", "Term")]
  counts <- richStudio:::build_cluster_summary(without_stats)
  expect_named(counts, c("Cluster", "Representative_Term", "n_terms"))
  expect_identical(counts$Representative_Term, c("A", "C"))
  expect_equal(counts$n_terms, c(2, 2))
  expect_identical(richStudio:::build_cluster_summary(without_stats[FALSE, ]), data.frame())
})
