test_that("merge_genesets works correctly", {
  # Load test data
  gs1 <- read.delim(system.file("extdata", "go1.txt", package = "richStudio"))
  gs2 <- read.delim(system.file("extdata", "go2.txt", package = "richStudio"))

  # Test with named list

  mergelist <- list(gs1 = gs1, gs2 = gs2)
  merged <- merge_genesets(mergelist)


  # Check that merge produced output
  expect_true(is.data.frame(merged))
  expect_true(nrow(merged) > 0)
  expect_true("Term" %in% colnames(merged))
  expect_true("GeneID" %in% colnames(merged))
})

test_that("merge_genesets handles single geneset", {
  gs1 <- read.delim(system.file("extdata", "go1.txt", package = "richStudio"))

  mergelist <- list(single = gs1)
  merged <- merge_genesets(mergelist)

  expect_true(is.data.frame(merged))
  expect_equal(nrow(merged), nrow(gs1))
})

test_that("merge_genesets rejects empty input", {
  expect_error(merge_genesets(list()), "No genesets provided")
})

test_that("get_clustering_methods returns valid structure", {
  methods <- get_clustering_methods()

  expect_true(is.list(methods))
  expect_true("richR" %in% names(methods))

  # Check structure of each method
  for (method_name in names(methods)) {
    method <- methods[[method_name]]
    expect_true("name" %in% names(method))
    expect_true("description" %in% names(method))
    expect_true("available" %in% names(method))
    expect_true(is.logical(method$available))
  }
})

test_that("perform_clustering validates input", {
  # Test with NULL input
  expect_error(perform_clustering(NULL), "No data provided")

  # Test with empty dataframe
  expect_error(perform_clustering(data.frame()), "No data provided")

  # Test with missing columns
  bad_df <- data.frame(x = 1:5, y = letters[1:5])
  expect_error(perform_clustering(bad_df), "Missing required columns")
})

test_that("perform_clustering works with richR method", {
  # Load and merge test data

  gs1 <- read.delim(system.file("extdata", "go1.txt", package = "richStudio"))
  gs2 <- read.delim(system.file("extdata", "go2.txt", package = "richStudio"))

  mergelist <- list(gs1 = gs1, gs2 = gs2)
  merged <- merge_genesets(mergelist)

  # Run clustering
  params <- list(cutoff = 0.5, overlap = 0.5, minSize = 2)
  result <- perform_clustering(
    merged_gs = merged,
    method = "richR",
    params = params,
    gs_names = names(mergelist)
  )

  # Check result structure
  expect_true(is.list(result))
  expect_true("cluster_df" %in% names(result))
  expect_true("cluster_summary" %in% names(result))
  expect_true("method" %in% names(result))
  expect_equal(result$method, "richR")
})

test_that("is_richCluster_available returns logical",
{
  result <- is_richCluster_available()
  expect_true(is.logical(result))
  expect_length(result, 1)
})
