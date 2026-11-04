test_that("help controls resolve their widget and JavaScript providers", {
  enrich <- as.character(richStudio:::enrich_tab_ui("enrich", "Enrichment"))
  upload <- as.character(richStudio:::cluster_upload_tab_ui("upload", "Upload"))
  expect_match(enrich, "enrich-deglist_help", fixed = TRUE)
  expect_match(enrich, "enrich-rrlist_help", fixed = TRUE)
  expect_match(upload, "upload-rrlist_help", fixed = TRUE)
  expect_match(upload, "upload-cluslist_help", fixed = TRUE)
})

test_that("column normalization retains canonical values and input", {
  input <- data.frame(
    ID = "id", Term = "A", Pvalue = 0.01, Padj = 0.02, GeneID = "g1,g2"
  )
  original <- input
  result <- richStudio:::select_required_columns(input)
  expect_identical(result, input)
  expect_identical(input, original)
})

test_that("weighted network retains the provider overlap calculation", {
  input <- data.frame(
    Term = c("A", "B"), GeneID = c("g1,g2", "g2,g3"),
    Significant = c(2, 2), Padj = c(0.01, 0.02)
  )
  original <- input
  result <- richStudio:::my_net(input, c("g1", "g2", "g3"))
  expected <- matrix(
    c(1, NA_real_, 1 / 3, 1), nrow = 2,
    dimnames = list(c("A", "B"), c("A", "B"))
  )
  expect_equal(result$w, expected)
  expect_equal(result$value_col, c(A = 2, B = -log10(0.02)))
  expect_identical(result$x$Term, input$Term)
  expect_identical(input, original)
})

test_that("cluster callbacks preserve representative priority and missing columns", {
  fixture <- data.frame(
    Cluster = c(1L, 1L, 2L, 2L), Term = c("A", "B", "C", "D"),
    Padj = c(0.02, 0.01, NA, NA), Pvalue = c(0.001, 0.002, 0.04, 0.03)
  )
  testthat::local_mocked_bindings(
    perform_clustering = function(...) list(cluster_df = fixture),
    .package = "richStudio"
  )
  input <- list(source = data.frame(Term = "A", GeneID = "g1,g2"))
  compute <- function() {
    richStudio:::workspace_cluster_compute(input, "richR", list(), "fixture")
  }
  adjusted <- compute()
  expect_identical(adjusted$cluster_df$Representative_Term, c("B", "B", "C", "C"))
  expect_identical(adjusted$summary_df$Representative_Term, c("B", "C"))
  expect_identical(adjusted$new_row$n_clusters, 2L)
  expect_identical(adjusted$new_row$n_terms, 4L)

  fixture$Padj <- NULL
  raw <- compute()
  expect_identical(raw$cluster_df$Representative_Term, c("A", "A", "D", "D"))
  fixture$Pvalue <- NULL
  first <- compute()
  expect_identical(first$cluster_df$Representative_Term, c("A", "A", "C", "C"))
  counts <- richStudio:::build_cluster_summary(fixture)
  expect_identical(counts$Representative_Term, c("A", "C"))
  expect_identical(counts$n_terms, c(2L, 2L))

  fixture$Term <- NULL
  expect_error(compute())
  fixture$Term <- c("A", "B", "C", "D")
  fixture$Cluster <- NULL
  expect_error(compute())
})
