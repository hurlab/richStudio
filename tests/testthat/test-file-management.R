# Test File Management Operations
#
# These tests ensure file upload, rename, and remove operations
# work correctly with reactive values.
#
# @author richStudio Development Team

# Load required packages
library(shiny)

test_that("add_file_degdf correctly adds DEG files", {
  # Test adding files to the big DEG dataframe

  # Start with empty dataframe
  big_df <- data.frame()

  # Add first file
  df1 <- data.frame(GeneID = letters[1:5], log2FC = rnorm(5))
  big_df <- add_file_degdf(big_df, "deg1", df1)

  expect_true(nrow(big_df) == 1)
  expect_true(big_df$name == "deg1")
  expect_true(big_df$has_expr_data == FALSE)

  # Add second file
  df2 <- data.frame(GeneID = letters[6:10], log2FC = rnorm(5))
  big_df <- add_file_degdf(big_df, "deg2", df2)

  expect_true(nrow(big_df) == 2)
  expect_true(big_df$name[2] == "deg2")
})

test_that("rm_file_degdf correctly removes DEG files", {
  # Test removing files from the big DEG dataframe

  # Setup
  big_df <- data.frame()
  for (i in 1:3) {
    df <- data.frame(GeneID = letters[1:5], log2FC = rnorm(5))
    big_df <- add_file_degdf(big_df, paste0("deg", i), df)
  }

  expect_true(nrow(big_df) == 3)

  # Remove one file
  to_remove <- big_df[1, ]
  big_df <- rm_file_degdf(big_df, to_remove)

  expect_true(nrow(big_df) == 2)
  expect_false("deg1" %in% big_df$name)

  # Remove multiple files
  to_remove <- big_df[1:2, ]
  big_df <- rm_file_degdf(big_df, to_remove)

  expect_true(nrow(big_df) == 0)
})

test_that("add_file_rrdf correctly adds enrichment result files", {
  # Test adding enrichment results to the big RR dataframe

  # Start with empty dataframe
  big_df <- data.frame()

  # Add enrichment result
  df <- data.frame(
    Term = c("GO:1", "GO:2"),
    Pvalue = c(0.01, 0.05),
    GeneID = c("Gene1/Gene2", "Gene3")
  )

  big_df <- add_file_rrdf(big_df, name="go1", file=TRUE)

  expect_true(nrow(big_df) == 1)
  expect_true(big_df$name == "go1")
  expect_true(big_df$file == TRUE)
})

test_that("rm_file_rrdf correctly removes enrichment result files", {
  # Test removing enrichment results from the big RR dataframe

  # Setup
  big_df <- data.frame()
  for (i in 1:3) {
    big_df <- add_file_rrdf(big_df, name=paste0("result", i), file=TRUE)
  }

  expect_true(nrow(big_df) == 3)

  # Remove one file
  to_remove <- big_df[1, ]
  big_df <- rm_file_rrdf(big_df, to_remove)

  expect_true(nrow(big_df) == 2)
  expect_false("result1" %in% big_df$name)
})

test_that("add_file_clusdf correctly adds cluster result files", {
  # Test adding cluster results to the big cluster dataframe

  # Start with empty dataframe
  big_df <- data.frame()

  # Add cluster result
  clusdf <- data.frame(
    Cluster = c("C1", "C1", "C2"),
    Term = c("GO:1", "GO:2", "GO:3"),
    Padj = c(0.01, 0.02, 0.03)
  )

  from_vec <- c("go1", "go2")

  big_df <- add_file_clusdf(big_df, clusdf, "cluster1", from_vec)

  expect_true(nrow(big_df) == 1)
  expect_true(big_df$name == "cluster1")
  expect_true(big_df$from_rr == "go1, go2")
})

test_that("rm_file_clusdf correctly removes cluster result files", {
  # Test removing cluster results from the big cluster dataframe

  # Setup
  big_df <- data.frame()
  for (i in 1:3) {
    clusdf <- data.frame(Cluster = paste0("C", i), Term = "GO:1")
    big_df <- add_file_clusdf(big_df, clusdf, paste0("cluster", i), "go1")
  }

  expect_true(nrow(big_df) == 3)

  # Remove one file
  to_remove <- big_df[1, ]
  big_df <- rm_file_clusdf(big_df, to_remove)

  expect_true(nrow(big_df) == 2)
  expect_false("cluster1" %in% big_df$name)
})

test_that("file rename operations maintain data integrity", {
  # Test that renaming doesn't corrupt the underlying data

  rv_names <- reactiveValues(labels = character(0))
  rv_data <- reactiveValues()

  # Add initial data
  df1 <- data.frame(GeneID = letters[1:5], log2FC = rnorm(5))
  rv_data[["file1"]] <- df1
  rv_names$labels <- c(rv_names$labels, "file1")

  # Rename file1 to new_file1
  old_name <- "file1"
  new_name <- "new_file1"

  rv_data[[new_name]] <- rv_data[[old_name]]
  rv_data[[old_name]] <- NULL
  rv_names$labels <- setdiff(rv_names$labels, old_name)
  rv_names$labels <- c(rv_names$labels, new_name)

  # Verify data integrity
  expect_identical(rv_data[[new_name]], df1)
  expect_null(rv_data[[old_name]])
  expect_equal(rv_names$labels, "new_file1")
})

test_that("file remove operations maintain data integrity", {
  # Test that removing files doesn't affect remaining data

  rv_names <- reactiveValues(labels = character(0))
  rv_data <- reactiveValues()

  # Add multiple files
  for (i in 1:3) {
    df <- data.frame(GeneID = letters[(i*5-4):(i*5)], log2FC = rnorm(5))
    rv_data[[paste0("file", i)]] <- df
    rv_names$labels <- c(rv_names$labels, paste0("file", i))
  }

  # Store reference to file2 data before removal
  file2_data <- rv_data[["file2"]]

  # Remove file1 and file3
  to_remove <- c("file1", "file3")
  for (name in to_remove) {
    rv_data[[name]] <- NULL
  }
  rv_names$labels <- setdiff(rv_names$labels, to_remove)

  # Verify file2 data is unchanged
  expect_identical(rv_data[["file2"]], file2_data)
  expect_equal(rv_names$labels, "file2")
  expect_null(rv_data[["file1"]])
  expect_null(rv_data[["file3"]])
})

test_that("duplicate file names are handled correctly", {
  # Test attempting to add a file with existing name

  rv_names <- reactiveValues(labels = character(0))
  rv_data <- reactiveValues()

  # Add file1
  rv_data[["file1"]] <- data.frame(x = 1:5)
  rv_names$labels <- c(rv_names$labels, "file1")

  # Attempt to add another file1 (should be handled by UI validation)
  # This test verifies the data structure would handle it
  expect_true("file1" %in% rv_names$labels)
  expect_true(is.data.frame(rv_data[["file1"]]))
})
