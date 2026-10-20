test_that("richR clustering uses the merged comma-delimited gene union", {
  merged <- data.frame(
    Term = c("T1", "T2", "T3"), Annot = c("one", "two", "background"),
    GeneID = c("g1,g2,g3,g4", "g2,g3,g4,g5", paste0("g", 6:20, collapse = ",")),
    Pvalue = c(1e-6, 1e-7, 0.5), Padj = c(1e-5, 1e-6, 0.5)
  )
  result <- perform_clustering(
    merged, method = "richR",
    params = list(cutoff = 0.1, overlap = 0, minSize = 2),
    gs_names = "fixture"
  )
  expected_genes <- unique(trimws(unlist(strsplit(merged$GeneID, ",", fixed = TRUE))))
  expected <- richR::richCluster(
    merged, gene = expected_genes, cutoff = 0.1, overlap = 0, minSize = 2
  )

  expect_gt(length(expected_genes), 0L)
  expect_true(all(expected_genes %in% c(paste0("g", 1:20))))
  expect_equal(result$raw_result, expected)
  expect_identical(result$raw_result$Cluster, "one,two")
  expect_equal(result$raw_result$EnrichmentScore, 6.5)
})

test_that("richR NULL background matches the explicit merged gene union", {
  merged <- data.frame(
    Term = paste0("T", 1:6), Annot = LETTERS[1:6],
    GeneID = c("g5,g7,g6,g2", "g6,g9", "g9,g6,g5,g1", "g6,g8",
               "g8,g3,g7,g1,g6", "g6,g4,g5,g1"),
    Pvalue = 10^(-1:-6), Padj = 10^(-1:-6)
  )
  union_genes <- unique(trimws(unlist(strsplit(merged$GeneID, ",", fixed = TRUE))))
  params <- list(cutoff = 0.1, overlap = 0.1, minSize = 2)

  result <- perform_clustering(merged, method = "richR", params = params, gs_names = "fixture")
  union_oracle <- richR::richCluster(
    merged, gene = union_genes, cutoff = params$cutoff,
    overlap = params$overlap, minSize = params$minSize
  )
  expect_identical(result$raw_result, union_oracle)
  expect_identical(result$raw_result$Cluster, "C,F,B,E")
  expect_equal(result$raw_result$EnrichmentScore, 4)

  logical_background <- richR::richCluster(
    merged, gene = TRUE, cutoff = params$cutoff,
    overlap = params$overlap, minSize = params$minSize
  )
  expect_false(identical(result$raw_result, logical_background))
  unrelated_background <- tryCatch(richR::richCluster(
    merged, gene = paste0("unrelated", seq_len(100)), cutoff = params$cutoff,
    overlap = params$overlap, minSize = params$minSize
  ), error = identity)
  expect_false(identical(result$raw_result, unrelated_background))
})

test_that("richR wrapper preserves balanced two-cluster assembly", {
  balanced <- data.frame(
    Term = LETTERS[1:4], Annot = LETTERS[1:4],
    GeneID = c("g1,g2,g3", "g1,g2,g4", "g5,g6,g7", "g5,g6,g8"),
    Pvalue = c(1e-8, 1e-7, 1e-6, 1e-5),
    Padj = c(1e-8, 1e-7, 1e-6, 1e-5)
  )
  params <- list(cutoff = 0.1, overlap = 0, minSize = 2)
  union_genes <- unique(trimws(unlist(strsplit(balanced$GeneID, ",", fixed = TRUE))))
  result <- perform_clustering(balanced, method = "richR", params = params, gs_names = "fixture")
  oracle <- richR::richCluster(
    balanced, gene = union_genes, cutoff = params$cutoff,
    overlap = params$overlap, minSize = params$minSize
  )

  expect_identical(result$raw_result, oracle)
  expect_gt(nrow(result$raw_result), 0L)
  expect_identical(result$raw_result$Cluster, c("A,B", "C,D"))
  expect_equal(result$raw_result$EnrichmentScore, c(7.5, 5.5), tolerance = 1e-8)
})

test_that("richR wrapper preserves a single-cluster assembly", {
  clique <- data.frame(
    Term = LETTERS[1:3], Annot = LETTERS[1:3],
    GeneID = c("g1,g2,g3,g4", "g1,g2,g3,g5", "g1,g2,g3,g6"),
    Pvalue = c(1e-6, 1e-7, 1e-8),
    Padj = c(1e-5, 1e-6, 1e-7)
  )
  params <- list(cutoff = 0.1, overlap = 0, minSize = 2)
  union_genes <- unique(trimws(unlist(strsplit(clique$GeneID, ",", fixed = TRUE))))
  result <- perform_clustering(clique, method = "richR", params = params, gs_names = "fixture")
  oracle <- richR::richCluster(
    clique, gene = union_genes, cutoff = params$cutoff,
    overlap = params$overlap, minSize = params$minSize
  )

  expect_identical(result$raw_result, oracle)
  expect_equal(nrow(result$raw_result), 1L)
  expect_identical(result$raw_result$Cluster, "A,B,C")
  expect_equal(result$raw_result$EnrichmentScore, 7, tolerance = 1e-8)
})
