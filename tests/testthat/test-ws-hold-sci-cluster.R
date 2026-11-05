# WS-HOLD-SCI B3-OBS-001: cluster summary representative row.

test_that("cluster summary values describe the representative term (B3-OBS-001)", {
  cluster_df <- data.frame(
    Cluster = c(1, 1, 2, 2), Term = c("A", "B", "C", "D"),
    Padj = c(.5, .1, .3, .2), Pvalue_f = c(.4, .05, .2, .1), Padj_f = c(.5, .1, .3, .2),
    stringsAsFactors = FALSE
  )
  testthat::local_mocked_bindings(
    normalize_geneset = function(x) x,
    perform_clustering = function(...) list(cluster_df = cluster_df),
    .package = "richStudio"
  )
  res <- richStudio:::workspace_cluster_compute(list(f = data.frame(Term = "A")),
                                               "richR", list(), "cl")
  s <- res$summary_df
  expect_identical(s$Representative_Term, c("B", "D"))
  expect_equal(s$Padj_f, c(.1, .2))
  expect_equal(s$Pvalue_f, c(.05, .1))
})
