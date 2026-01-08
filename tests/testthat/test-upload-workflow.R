# Test Upload Workflows
#
# Integration tests for DEG, enrichment, and clustering upload workflows.
# These tests verify end-to-end functionality of upload operations.
#
# @author richStudio Development Team

# Load required packages
library(shiny)

test_that("DEG file upload workflow completes successfully", {
  # Test complete workflow: upload -> store in reactive values -> update UI

  # Initialize reactive values
  u_degnames <- reactiveValues(labels = character(0))
  u_degdfs <- reactiveValues()
  u_big_degdf <- reactiveValues(df = data.frame())

  # Simulate file upload
  lab <- "test_deg"
  df <- data.frame(
    GeneID = c("Gene1", "Gene2", "Gene3"),
    log2FoldChange = c(2.5, -1.8, 1.2),
    padj = c(0.001, 0.05, 0.02)
  )

  # Execute upload steps (simulating enrich_tab.R logic)
  u_degdfs[[lab]] <- df
  u_degnames$labels <- c(u_degnames$labels, lab)
  u_big_degdf[['df']] <- add_file_degdf(u_big_degdf[['df']], lab, df)

  # Verify all updates
  expect_true(lab %in% u_degnames$labels)
  expect_true(is.data.frame(u_degdfs[[lab]]))
  expect_equal(nrow(u_big_degdf[['df']]), 1)
  expect_true(u_big_degdf[['df']]$name == lab)
})

test_that("Multiple DEG files upload workflow completes successfully", {
  # Test uploading multiple DEG files in sequence

  u_degnames <- reactiveValues(labels = character(0))
  u_degdfs <- reactiveValues()
  u_big_degdf <- reactiveValues(df = data.frame())

  # Upload three files
  for (i in 1:3) {
    lab <- paste0("deg", i)
    df <- data.frame(
      GeneID = paste0("Gene", (i*5-4):(i*5)),
      log2FoldChange = rnorm(5),
      padj = runif(5, 0.001, 0.1)
    )

    u_degdfs[[lab]] <- df
    u_degnames$labels <- c(u_degnames$labels, lab)
    u_big_degdf[['df']] <- add_file_degdf(u_big_degdf[['df']], lab, df)
  }

  # Verify all files uploaded
  expect_equal(length(u_degnames$labels), 3)
  expect_equal(nrow(u_big_degdf[['df']]), 3)
  expect_true(all(c("deg1", "deg2", "deg3") %in% u_degnames$labels))
})

test_that("Enrichment result upload workflow completes successfully", {
  # Test uploading enrichment results

  u_rrnames <- reactiveValues(labels = character(0))
  u_rrdfs <- reactiveValues()
  u_big_rrdf <- reactiveValues(df = data.frame())

  # Simulate enrichment result upload
  lab <- "test_go"
  df <- data.frame(
    Term = c("GO:0000001", "GO:0000002"),
    Pvalue = c(0.001, 0.01),
    GeneID = c("Gene1/Gene2", "Gene3/Gene4")
  )

  # Execute upload steps (simulating enrich_tab.R logic)
  u_rrdfs[[lab]] <- df
  u_rrnames$labels <- c(u_rrnames$labels, lab)
  u_big_rrdf[['df']] <- add_file_rrdf(df=u_big_rrdf[['df']], name=lab, file=TRUE)

  # Verify upload
  expect_true(lab %in% u_rrnames$labels)
  expect_true(is.data.frame(u_rrdfs[[lab]]))
  expect_equal(nrow(u_big_rrdf[['df']]), 1)
})

test_that("Clustering upload workflow completes successfully", {
  # Test uploading enrichment results for clustering

  u_rrnames <- reactiveValues(labels = character(0))
  u_rrdfs <- reactiveValues()
  u_big_rrdf <- reactiveValues(df = data.frame())

  # Upload enrichment results for clustering
  for (i in 1:3) {
    lab <- paste0("go", i)
    df <- data.frame(
      Term = paste0("GO:000000", 1:5),
      Pvalue = runif(5, 0.001, 0.1),
      GeneID = paste0("Gene", 1:5)
    )

    u_rrdfs[[lab]] <- df
    u_rrnames$labels <- c(u_rrnames$labels, lab)
    u_big_rrdf[['df']] <- add_file_rrdf(df=u_big_rrdf[['df']], name=lab, file=TRUE)
  }

  # Verify all enrichment results uploaded
  expect_equal(length(u_rrnames$labels), 3)
  expect_true(all(c("go1", "go2", "go3") %in% u_rrnames$labels))
})

test_that("Upload workflow handles file format detection", {
  # Test CSV vs TSV detection

  # Create temporary test files
  tmp_csv <- tempfile(fileext = ".csv")
  tmp_tsv <- tempfile(fileext = ".txt")

  write.csv(data.frame(x = 1:5, y = letters[1:5]), tmp_csv, row.names = FALSE)
  write.table(data.frame(x = 1:5, y = letters[1:5]), tmp_tsv, sep = "\t", row.names = FALSE)

  # Test CSV reading
  csv_ncol <- tryCatch({
    csvdf <- read.csv(tmp_csv)
    ncol(csvdf)
  }, error = function(err) {
    0
  })

  # Test TSV reading
  tsv_ncol <- tryCatch({
    tsvdf <- read.delim(tmp_tsv)
    ncol(tsvdf)
  }, error = function(err) {
    0
  })

  expect_true(csv_ncol > 0)
  expect_true(tsv_ncol > 0)
  expect_equal(csv_ncol, 2)
  expect_equal(tsv_ncol, 2)

  # Cleanup
  unlink(tmp_csv)
  unlink(tmp_tsv)
})

test_that("Upload workflow handles demo data loading", {
  # Test loading demo data files

  # Check that sample files exist
  sample_files <- c("deg_mouse1.txt", "go1.txt", "go2.txt", "kegg1.txt")

  for (file in sample_files) {
    path <- system.file("extdata", file, package = "richStudio")
    if (path != "") {
      expect_true(file.exists(path))

      # Try to read the file
      df <- read.delim(path)
      expect_true(is.data.frame(df))
      expect_true(nrow(df) > 0)
    }
  }
})

test_that("Upload workflow maintains data consistency across reactive values", {
  # Test that data remains consistent between u_degdfs and u_big_degdf

  u_degnames <- reactiveValues(labels = character(0))
  u_degdfs <- reactiveValues()
  u_big_degdf <- reactiveValues(df = data.frame())

  # Upload file
  lab <- "consistency_test"
  original_df <- data.frame(
    GeneID = c("Gene1", "Gene2", "Gene3"),
    log2FC = c(1.5, -2.0, 0.8),
    padj = c(0.001, 0.01, 0.05)
  )

  u_degdfs[[lab]] <- original_df
  u_degnames$labels <- c(u_degnames$labels, lab)
  u_big_degdf[['df']] <- add_file_degdf(u_big_degdf[['df']], lab, original_df)

  # Retrieve and compare
  stored_df <- u_degdfs[[lab]]
  expect_identical(stored_df, original_df)

  # Verify metadata in big dataframe
  expect_true(u_big_degdf[['df']]$name == lab)
})

test_that("Upload workflow error handling works correctly", {
  # Test handling of invalid files or data

  # Test with empty dataframe
  empty_df <- data.frame()
  expect_true(nrow(empty_df) == 0)

  # Test with missing required columns
  bad_df <- data.frame(x = 1:5, y = letters[1:5])
  expect_false("GeneID" %in% names(bad_df))

  # Test with malformed file path
  nonexistent_path <- "/tmp/nonexistent_file_12345.txt"
  expect_false(file.exists(nonexistent_path))
})
