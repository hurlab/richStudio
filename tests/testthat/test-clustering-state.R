# Test Clustering State Management
#
# These tests ensure clustering operations properly manage state
# across reactive values and data structures.
#
# @author richStudio Development Team

# Load required packages
library(shiny)

# Source the clustering functions
source("../R/rr_cluster.R")

test_that("clustering state is properly initialized", {
  # Test initial state of clustering reactive values

  u_clusnames <- reactiveValues(labels = character(0))
  u_clusdfs <- reactiveValues()
  u_cluslists <- reactiveValues()
  u_big_clusdf <- reactiveValues(df = data.frame())

  # Verify initial state
  expect_equal(length(u_clusnames$labels), 0)
  expect_equal(length(names(u_clusdfs)), 0)
  expect_equal(length(names(u_cluslists)), 0)
  expect_true(is.data.frame(u_big_clusdf[['df']]))
  expect_equal(nrow(u_big_clusdf[['df']]), 0)
})

test_that("clustering state updates after richR clustering", {
  # Test state after performing richR clustering

  u_clusnames <- reactiveValues(labels = character(0))
  u_clusdfs <- reactiveValues()
  u_cluslists <- reactiveValues()
  u_big_clusdf <- reactiveValues(df = data.frame())

  # Load test data
  gs1 <- read.delim(system.file("extdata", "go1.txt", package = "richStudio"))
  gs2 <- read.delim(system.file("extdata", "go2.txt", package = "richStudio"))

  mergelist <- list(gs1 = gs1, gs2 = gs2)
  merged <- merge_genesets(mergelist)

  # Perform clustering
  params <- list(cutoff = 0.5, overlap = 0.5, minSize = 2)
  result <- perform_clustering(
    merged_gs = merged,
    method = "richR",
    params = params,
    gs_names = names(mergelist)
  )

  # Verify clustering produced results
  expect_true(is.list(result))
  expect_true("cluster_df" %in% names(result))

  # Update state (simulating cluster_tab.R logic)
  lab <- "test_cluster"
  u_clusdfs[[lab]] <- result$cluster_df
  u_cluslists[[lab]] <- result$cluster_summary
  u_clusnames$labels <- c(u_clusnames$labels, lab)

  # Verify state updated
  expect_true(lab %in% u_clusnames$labels)
  expect_true(is.data.frame(u_clusdfs[[lab]]))
  expect_true(is.list(u_cluslists[[lab]]))
})

test_that("clustering state handles multiple clusters", {
  # Test managing multiple clustering results

  u_clusnames <- reactiveValues(labels = character(0))
  u_clusdfs <- reactiveValues()
  u_cluslists <- reactiveValues()
  u_big_clusdf <- reactiveValues(df = data.frame())

  # Create multiple cluster results
  for (i in 1:3) {
    lab <- paste0("cluster", i)

    # Mock cluster data
    cluster_df <- data.frame(
      Cluster = rep(paste0("C", 1:2), each = 3),
      Term = paste0("GO:", 1:6),
      Padj = runif(6, 0.001, 0.1)
    )

    cluster_list <- list(
      n_clusters = 2,
      cluster_sizes = c(3, 3)
    )

    u_clusdfs[[lab]] <- cluster_df
    u_cluslists[[lab]] <- cluster_list
    u_clusnames$labels <- c(u_clusnames$labels, lab)
  }

  # Verify all clusters stored
  expect_equal(length(u_clusnames$labels), 3)
  expect_true(all(c("cluster1", "cluster2", "cluster3") %in% u_clusnames$labels))
})

test_that("clustering state handles cluster rename operations", {
  # Test renaming clustering results

  u_clusnames <- reactiveValues(labels = c("cluster1"))
  u_clusdfs <- reactiveValues()
  u_cluslists <- reactiveValues()

  # Add cluster data
  u_clusdfs[["cluster1"]] <- data.frame(Cluster = "C1", Term = "GO:1")
  u_cluslists[["cluster1"]] <- list(n_clusters = 1)

  # Rename cluster1 to new_cluster
  old_name <- "cluster1"
  new_name <- "new_cluster"

  # Execute rename (simulating cluster_upload_tab.R logic)
  u_clusdfs[[new_name]] <- u_clusdfs[[old_name]]
  u_cluslists[[new_name]] <- u_cluslists[[old_name]]
  u_clusdfs[[old_name]] <- NULL
  u_cluslists[[old_name]] <- NULL
  u_clusnames$labels <- setdiff(u_clusnames$labels, old_name)
  u_clusnames$labels <- c(u_clusnames$labels, new_name)

  # Verify rename worked
  expect_null(u_clusdfs[["cluster1"]])
  expect_null(u_cluslists[["cluster1"]])
  expect_true(is.data.frame(u_clusdfs[["new_cluster"]]))
  expect_true(is.list(u_cluslists[["new_cluster"]]))
  expect_false("cluster1" %in% u_clusnames$labels)
  expect_true("new_cluster" %in% u_clusnames$labels)
})

test_that("clustering state handles cluster remove operations", {
  # Test removing clustering results

  u_clusnames <- reactiveValues(labels = c("cluster1", "cluster2", "cluster3"))
  u_clusdfs <- reactiveValues()
  u_cluslists <- reactiveValues()

  # Add cluster data
  for (i in 1:3) {
    lab <- paste0("cluster", i)
    u_clusdfs[[lab]] <- data.frame(Cluster = paste0("C", i), Term = "GO:1")
    u_cluslists[[lab]] <- list(n_clusters = 1)
  }

  # Remove cluster1 and cluster3
  to_remove <- c("cluster1", "cluster3")
  for (name in to_remove) {
    u_clusdfs[[name]] <- NULL
    u_cluslists[[name]] <- NULL
  }
  u_clusnames$labels <- setdiff(u_clusnames$labels, to_remove)

  # Verify removals worked
  expect_null(u_clusdfs[["cluster1"]])
  expect_true(is.data.frame(u_clusdfs[["cluster2"]]))
  expect_null(u_clusdfs[["cluster3"]])
  expect_equal(u_clusnames$labels, "cluster2")
})

test_that("clustering state maintains data integrity during updates", {
  # Test that clustering data remains consistent

  u_clusnames <- reactiveValues(labels = character(0))
  u_clusdfs <- reactiveValues()
  u_cluslists <- reactiveValues()

  lab <- "integrity_test"

  # Add comprehensive cluster data
  cluster_df <- data.frame(
    Cluster = rep(c("C1", "C2", "C3"), each = 3),
    Representative_Term = c("GO:1", "GO:2", "GO:3", "GO:1", "GO:2", "GO:3", "GO:1", "GO:2", "GO:3"),
    Term = paste0("GO:", 1:9),
    Padj = runif(9, 0.001, 0.1)
  )

  cluster_list <- list(
    n_clusters = 3,
    cluster_sizes = c(3, 3, 3),
    representative_terms = c("GO:1", "GO:2", "GO:3")
  )

  u_clusdfs[[lab]] <- cluster_df
  u_cluslists[[lab]] <- cluster_list
  u_clusnames$labels <- c(u_clusnames$labels, lab)

  # Verify data integrity
  expect_identical(u_clusdfs[[lab]], cluster_df)
  expect_identical(u_cluslists[[lab]], cluster_list)
  expect_equal(nrow(u_clusdfs[[lab]]), 9)
  expect_equal(u_cluslists[[lab]]$n_clusters, 3)
})

test_that("clustering state handles DataTable edits", {
  # Test editing cluster results via DataTable

  u_clusnames <- reactiveValues(labels = c("cluster1"))
  u_clusdfs <- reactiveValues()
  u_big_clusdf <- reactiveValues(df = data.frame())

  # Add cluster data
  cluster_df <- data.frame(
    name = "cluster1",
    from_rr = "go1",
    n_clusters = 3
  )
  u_big_clusdf[['df']] <- cluster_df

  # Simulate DataTable cell edit (using corrected pattern)
  i <- 1
  j <- 1
  v <- "renamed_cluster"

  # Apply edit with corrected pattern
  updated_df <- u_big_clusdf[['df']]
  updated_df[i, j] <- DT::coerceValue(v, updated_df[i, j])
  u_big_clusdf[['df']] <- updated_df

  # Verify edit worked
  expect_equal(u_big_clusdf[['df']][1, 1], "renamed_cluster")
})

test_that("get_clustering_methods returns valid methods", {
  # Test clustering method availability checking

  methods <- get_clustering_methods()

  expect_true(is.list(methods))
  expect_true("richR" %in% names(methods))

  # Check richR method structure
  expect_true("name" %in% names(methods$richR))
  expect_true("description" %in% names(methods$richR))
  expect_true("available" %in% names(methods$richR))
  expect_true(is.logical(methods$richR$available))
})

test_that("is_richCluster_available works correctly", {
  # Test richCluster package availability check

  result <- is_richCluster_available()

  expect_true(is.logical(result))
  expect_length(result, 1)

  # Result should be either TRUE or FALSE
  expect_true(result %in% c(TRUE, FALSE))
})

test_that("clustering state handles edge cases", {
  # Test edge cases in clustering state management

  u_clusnames <- reactiveValues(labels = character(0))
  u_clusdfs <- reactiveValues()
  u_cluslists <- reactiveValues()

  # Test with empty cluster result
  empty_df <- data.frame()
  u_clusdfs[["empty"]] <- empty_df
  u_cluslists[["empty"]] <- list()

  expect_true(nrow(u_clusdfs[["empty"]]) == 0)

  # Test with single cluster
  single_cluster <- data.frame(Cluster = "C1", Term = "GO:1")
  u_clusdfs[["single"]] <- single_cluster
  u_cluslists[["single"]] <- list(n_clusters = 1)

  expect_equal(nrow(u_clusdfs[["single"]]), 1)
  expect_equal(u_cluslists[["single"]]$n_clusters, 1)
})
