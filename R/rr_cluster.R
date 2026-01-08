# Functions to merge and cluster enrichment results
#
# This module provides clustering functionality for functional enrichment results.
# It supports multiple clustering methods:
#   1. richR::richCluster - Original Kappa-based clustering (from richR package)
#   2. richCluster::cluster - Hierarchical clustering with flexible linkage methods
#   3. richCluster::david_cluster - DAVID's functional clustering algorithm
#
# @author richStudio Development Team

#' @importFrom dplyr %>% group_by summarise arrange first n ungroup select any_of mutate
#' @importFrom rlang .data

# Null-coalescing operator (define at top so it's available throughout)
#' @keywords internal
`%||%` <- function(x, y) if (is.null(x)) y else x


# Ensure pipe is available when dplyr isn't attached (e.g., in non-tidyverse contexts)
if (!exists("%>%")) {
  `%>%` <- dplyr::`%>%`
}

#' Check if richCluster package is available
#'
#' @return TRUE if richCluster is installed and loadable, FALSE otherwise
#' @keywords internal
is_richCluster_available <- function() {

  requireNamespace("richCluster", quietly = TRUE)
}

#' Normalize enrichment dataframe
#'
#' Coerces column types and fills required columns to avoid downstream errors.
#' @keywords internal
normalize_geneset <- function(df) {
  if (is.null(df) || nrow(df) == 0) return(df)
  if (!("Term" %in% names(df))) stop("Geneset is missing required column 'Term'")
  # Ensure required columns exist
  if (!("GeneID" %in% names(df))) df$GeneID <- NA_character_
  if (!("Annot" %in% names(df))) df$Annot <- df$Term

  # Coerce types
  df$Term <- as.character(df$Term)
  df$Annot <- as.character(df$Annot)
  df$GeneID <- as.character(df$GeneID)

  # Coerce p-values to numeric if present (do not drop rows)
  if ("Pvalue" %in% names(df)) {
    df$Pvalue <- suppressWarnings(as.numeric(df$Pvalue))
  }
  if ("Padj" %in% names(df)) {
    df$Padj <- suppressWarnings(as.numeric(df$Padj))
  }

  # Drop rows without a Term
  df[!is.na(df$Term) & nzchar(df$Term), , drop = FALSE]
}


#' Merge multiple genesets (enrichment results) for clustering
#'
#' Combines multiple enrichment result dataframes by merging on the Term column.
#' GeneIDs are combined (unique), p-values are averaged, and columns are suffixed
#' with the geneset name for traceability.
#'
#' @param genesets A named list of dataframes, each containing enrichment results.
#'   Each dataframe must have at least columns: Term, GeneID, Pvalue, Padj, Annot.
#'
#' @return A merged dataframe with combined GeneIDs, averaged p-values, and
#'   per-geneset columns suffixed with geneset names.
#'
#' @examples
#' # Load example enrichment results
#' go1 <- read.delim(system.file("extdata", "go1.txt", package = "richStudio"))
#' go2 <- read.delim(system.file("extdata", "go2.txt", package = "richStudio"))
#'
#' # Merge the genesets
#' genesets <- list(GO1 = go1, GO2 = go2)
#' merged <- merge_genesets(genesets)
#' head(merged[, c("Term", "Pvalue", "Padj")])
#'
#' @seealso \code{\link{perform_clustering}}
#'
#' @export
merge_genesets <- function(genesets) {

  if (length(genesets) == 0) {
    stop("No genesets provided for merging")
  }

  genesets <- lapply(genesets, normalize_geneset)

  if (is.null(names(genesets))) {
    names(genesets) <- paste0("geneset_", seq_along(genesets))
  }

  # Clean geneset names (remove special characters that cause column issues)
  clean_names <- gsub("[^[:alnum:]_]", "_", names(genesets))
  # Remove multiple consecutive underscores
  clean_names <- gsub("_+", "_", clean_names)
  # Remove leading/trailing underscores
  clean_names <- gsub("^_|_$", "", clean_names)

  # Ensure uniqueness by appending index to duplicates
  if (length(unique(clean_names)) != length(clean_names)) {
    # Find duplicates and make unique
    seen <- list()
    for (i in seq_along(clean_names)) {
      name <- clean_names[i]
      if (is.null(seen[[name]])) {
        seen[[name]] <- 1
      } else {
        seen[[name]] <- seen[[name]] + 1
        clean_names[i] <- paste0(name, "_", seen[[name]])
      }
    }
  }

  names(genesets) <- clean_names

  # Suffix all non 'Term' columns with their geneset name
  for (i in seq_along(genesets)) {
    rownames(genesets[[i]]) <- NULL  # prevents rownames from messing up
    non_term_cols <- colnames(genesets[[i]])
    term_idx <- which(non_term_cols == 'Term')
    if (length(term_idx) == 0) {
      stop(paste("Geneset", names(genesets)[i], "does not have a 'Term' column"))
    }
    non_term_cols[-term_idx] <- paste(non_term_cols[-term_idx], names(genesets)[i], sep = "_")
    colnames(genesets[[i]]) <- non_term_cols
  }

  # Initialize merged_gs with first geneset
  merged_gs <- genesets[[1]]

  # Merge genesets
  if (length(genesets) > 1) {
    for (i in seq_len(length(genesets) - 1) + 1) {
      merged_gs <- base::merge(merged_gs, genesets[[i]], by = 'Term', all = TRUE)
    }
  }

  # Combine unique 'GeneID' elements
  geneid_cols <- paste('GeneID', names(genesets), sep = "_")
  geneid_cols_present <- geneid_cols[geneid_cols %in% colnames(merged_gs)]
  if (length(geneid_cols_present) > 0) {
    merged_gs$GeneID <- apply(merged_gs[, geneid_cols_present, drop = FALSE], 1, function(x) {
      paste(unique(na.omit(unlist(strsplit(as.character(x), ",")))), collapse = ',')
    })
  }

  # Combine unique 'Annot' elements
  annot_cols <- paste('Annot', names(genesets), sep = "_")
  annot_cols_present <- annot_cols[annot_cols %in% colnames(merged_gs)]
  if (length(annot_cols_present) > 0) {
    merged_gs$Annot <- apply(merged_gs[, annot_cols_present, drop = FALSE], 1, function(x) {
      paste(unique(na.omit(as.character(x))), collapse = ',')
    })
    merged_gs <- dplyr::select(merged_gs, -dplyr::any_of(annot_cols_present))
  }

  # Average Pvalue
  pval_cols <- paste('Pvalue', names(genesets), sep = "_")
  pval_cols_present <- pval_cols[pval_cols %in% colnames(merged_gs)]
  if (length(pval_cols_present) > 0) {
    merged_gs$Pvalue <- rowMeans(merged_gs[, pval_cols_present, drop = FALSE], na.rm = TRUE)
  }

  # Average Padj
  padj_cols <- paste('Padj', names(genesets), sep = "_")
  padj_cols_present <- padj_cols[padj_cols %in% colnames(merged_gs)]
  if (length(padj_cols_present) > 0) {
    merged_gs$Padj <- rowMeans(merged_gs[, padj_cols_present, drop = FALSE], na.rm = TRUE)
  }

  return(merged_gs)
}


#' Perform clustering using the selected method
#'
#' This is the main clustering dispatcher function that routes to the appropriate
#' clustering implementation based on the selected method.
#'
#' @param merged_gs Merged geneset dataframe (output of merge_genesets)
#' @param method Clustering method: "richR" (original), "hierarchical", or "david"
#' @param params List of clustering parameters (varies by method):
#'   \itemize{
#'     \item richR: cutoff, overlap, minSize
#'     \item hierarchical: distance_metric, distance_cutoff, linkage_method,
#'       linkage_cutoff, min_terms, min_value
#'     \item david: similarity_threshold, initial_group_membership,
#'       final_group_membership, multiple_linkage_threshold
#'   }
#' @param gs_names Character vector of geneset names (for output formatting)
#'
#' @return A list containing clustering results with components:
#'   \itemize{
#'     \item cluster_df: Dataframe with cluster assignments and term details
#'     \item cluster_summary: Summary dataframe with cluster representative terms
#'     \item method: The clustering method used
#'     \item params: Parameters used for clustering
#'   }
#'
#' @examples
#' # Load and merge example data
#' go1 <- read.delim(system.file("extdata", "go1.txt", package = "richStudio"))
#' go2 <- read.delim(system.file("extdata", "go2.txt", package = "richStudio"))
#' genesets <- list(GO1 = go1, GO2 = go2)
#' merged <- merge_genesets(genesets)
#'
#' # Perform clustering with richR method
#' params <- list(cutoff = 0.5, overlap = 0.5, minSize = 2)
#' result <- perform_clustering(merged, method = "richR", params = params)
#'
#' # View results
#' if (nrow(result$cluster_df) > 0) {
#'   head(result$cluster_summary)
#' }
#'
#' @seealso \code{\link{merge_genesets}}, \code{\link{get_clustering_methods}}
#'
#' @export
perform_clustering <- function(merged_gs, method = "richR", params = list(), gs_names = NULL, raw_genesets = NULL) {

  # Validate input
  if (is.null(merged_gs) || nrow(merged_gs) == 0) {
    stop("No data provided for clustering")
  }

  required_cols <- c("Term", "GeneID")
  missing_cols <- setdiff(required_cols, colnames(merged_gs))
  if (length(missing_cols) > 0) {
    stop(paste("Missing required columns:", paste(missing_cols, collapse = ", ")))
  }

  # Ensure numeric Pvalue/Padj
  if ("Pvalue" %in% names(merged_gs)) {
    merged_gs$Pvalue <- suppressWarnings(as.numeric(merged_gs$Pvalue))
  }
  if ("Padj" %in% names(merged_gs)) {
    merged_gs$Padj <- suppressWarnings(as.numeric(merged_gs$Padj))
  }

  # Check if richCluster is available for hierarchical/david methods
  if (method %in% c("hierarchical", "david") && !is_richCluster_available()) {
    stop(paste0(
      "The richCluster package is required for the '", method, "' method but is not installed.\n",
      "Install from CRAN with: install.packages('richCluster')"
    ))
  }

  result <- tryCatch({
    switch(method,
           "richR" = cluster_richR(merged_gs, params, gs_names),
           "hierarchical" = cluster_hierarchical(merged_gs, params, gs_names, raw_genesets),
           "david" = cluster_david(merged_gs, params, gs_names, raw_genesets),
           stop(paste("Unknown clustering method:", method))
    )
  }, error = function(e) {
    stop(paste("Clustering failed:", e$message))
  })

  result$method <- method
  result$params <- params

  return(result)
}


#' Original richR clustering method
#'
#' Uses richR::richCluster for Kappa-based clustering. This is the original
#' method used in richStudio_hurlab-server.
#'
#' @param merged_gs Merged geneset dataframe
#' @param params List with: cutoff (similarity cutoff), overlap, minSize
#' @param gs_names Geneset names for output
#' @return Clustering result list
#' @keywords internal
cluster_richR <- function(merged_gs, params, gs_names) {

  # Set defaults
  cutoff <- params$cutoff %||% 0.5
  overlap <- params$overlap %||% 0.5
  minSize <- params$minSize %||% 2

  # Perform clustering using richR
  clustered_gs <- richR::richCluster(
    x = merged_gs,
    gene = TRUE,
    cutoff = cutoff,
    overlap = overlap,
    minSize = minSize
  )

  # Check if clustering returned results
  if (is.null(clustered_gs) || nrow(clustered_gs) == 0) {
    return(list(
      cluster_df = data.frame(),
      cluster_summary = data.frame(),
      raw_result = clustered_gs
    ))
  }

  # Order clusters by ascending cluster number
  if ("AnnotationCluster" %in% colnames(clustered_gs)) {
    clustered_gs <- clustered_gs[order(as.numeric(clustered_gs$AnnotationCluster)), ]
  }

  # Build cluster list with term details
  cluster_list <- get_cluster_list_richR(clustered_gs, merged_gs, gs_names)

  # Build cluster summary dataframe
  cluster_summary <- build_cluster_summary(cluster_list)

  return(list(
    cluster_df = cluster_list,
    cluster_summary = cluster_summary,
    raw_result = clustered_gs
  ))
}


#' Hierarchical clustering using richCluster package
#'
#' Uses richCluster::cluster for flexible hierarchical clustering with
#' user-selectable distance metrics and linkage methods.
#'
#' @param merged_gs Merged geneset dataframe
#' @param params List with: distance_metric (kappa/jaccard), distance_cutoff,
#'   linkage_method (single/complete/average/ward), linkage_cutoff, min_terms, min_value
#' @param gs_names Geneset names for output
#' @return Clustering result list
#' @keywords internal
cluster_hierarchical <- function(merged_gs, params, gs_names, raw_genesets = NULL) {

  # Set defaults
  distance_metric <- params$distance_metric %||% "kappa"
  distance_cutoff <- params$distance_cutoff %||% 0.5
  linkage_method <- params$linkage_method %||% "average"
  linkage_cutoff <- params$linkage_cutoff %||% 0.5
  min_terms <- params$min_terms %||% 2
  min_value <- params$min_value %||% 0.1

  # Prepare input as list of dataframes (richCluster expects this format)
  enrichment_list <- raw_genesets %||% list(merged_gs)
  if (is.null(names(enrichment_list))) {
    names(enrichment_list) <- paste0("geneset_", seq_along(enrichment_list))
  }
  enrichment_list <- lapply(enrichment_list, normalize_geneset)

  # Perform clustering
  cluster_result <- richCluster::cluster(
    enrichment_results = enrichment_list,
    df_names = names(enrichment_list),
    min_terms = min_terms,
    min_value = min_value,
    distance_metric = distance_metric,
    distance_cutoff = distance_cutoff,
    linkage_method = linkage_method,
    linkage_cutoff = linkage_cutoff
  )

  # Convert to standard format
  cluster_df <- cluster_result$cluster_df

  # Check if clustering returned results
  if (is.null(cluster_df) || nrow(cluster_df) == 0) {
    return(list(
      cluster_df = data.frame(),
      cluster_summary = data.frame(),
      raw_result = cluster_result,
      distance_matrix = cluster_result$distance_matrix
    ))
  }

  # Add geneset-specific columns if gs_names provided
  if (!is.null(gs_names) && length(gs_names) > 0) {
    cluster_df <- add_geneset_columns(cluster_df, merged_gs, gs_names)
  }

  # Build cluster summary
  cluster_summary <- build_cluster_summary(cluster_df)

  return(list(
    cluster_df = cluster_df,
    cluster_summary = cluster_summary,
    raw_result = cluster_result,
    distance_matrix = cluster_result$distance_matrix
  ))
}


#' DAVID functional clustering
#'
#' Uses richCluster::david_cluster for DAVID-style functional clustering
#' with multiple linkage thresholds.
#'
#' @param merged_gs Merged geneset dataframe
#' @param params List with: similarity_threshold, initial_group_membership,
#'   final_group_membership, multiple_linkage_threshold
#' @param gs_names Geneset names for output
#' @return Clustering result list
#' @keywords internal
cluster_david <- function(merged_gs, params, gs_names, raw_genesets = NULL) {

  # Set defaults
  similarity_threshold <- params$similarity_threshold %||% 0.5
  initial_group_membership <- params$initial_group_membership %||% 3
  final_group_membership <- params$final_group_membership %||% 3
  multiple_linkage_threshold <- params$multiple_linkage_threshold %||% 0.5

  # Prepare input
  enrichment_list <- raw_genesets %||% list(merged_gs)
  if (is.null(names(enrichment_list))) {
    names(enrichment_list) <- paste0("geneset_", seq_along(enrichment_list))
  }
  enrichment_list <- lapply(enrichment_list, normalize_geneset)

  # Perform DAVID clustering
  cluster_result <- richCluster::david_cluster(
    enrichment_results = enrichment_list,
    df_names = names(enrichment_list),
    similarity_threshold = similarity_threshold,
    initial_group_membership = initial_group_membership,
    final_group_membership = final_group_membership,
    multiple_linkage_threshold = multiple_linkage_threshold
  )

  # Convert to standard format
  cluster_df <- cluster_result$cluster_df

  # Check if clustering returned results
  if (is.null(cluster_df) || nrow(cluster_df) == 0) {
    return(list(
      cluster_df = data.frame(),
      cluster_summary = data.frame(),
      raw_result = cluster_result
    ))
  }

  # Add geneset-specific columns if gs_names provided
  if (!is.null(gs_names) && length(gs_names) > 0) {
    cluster_df <- add_geneset_columns(cluster_df, merged_gs, gs_names)
  }

  # Build cluster summary
  cluster_summary <- build_cluster_summary(cluster_df)

  return(list(
    cluster_df = cluster_df,
    cluster_summary = cluster_summary,
    raw_result = cluster_result
  ))
}


#' Build cluster list from richR clustering result
#'
#' @param clustered_gs Output from richR::richCluster
#' @param merged_gs Original merged geneset
#' @param gs_names Geneset names
#' @return Dataframe with cluster assignments and term details
#' @keywords internal
get_cluster_list_richR <- function(clustered_gs, merged_gs, gs_names) {

  if (is.null(gs_names) || length(gs_names) == 0) {
    gs_names <- "merged"
  }

  # Check required columns
  if (!("Cluster" %in% colnames(clustered_gs))) {
    return(data.frame())
  }


  # Get list of Annots in cluster, index=cluster#
  term_indices <- lapply(clustered_gs$Cluster, function(x) unlist(strsplit(x, ',')))

  # For each cluster #, find matching row in merged_gs corresponding to Annot
  cluster_list <- data.frame()

  # Handle case where merged_gs doesn't have Annot column
  if (!("Annot" %in% colnames(merged_gs))) {
    # Try to use Term as fallback
    if ("Term" %in% colnames(merged_gs)) {
      merged_gs$Annot <- merged_gs$Term
    } else {
      return(data.frame())
    }
  }

  for (i in seq_along(term_indices)) {
    annots <- term_indices[[i]]
    matching_rows <- merged_gs[merged_gs$Annot %in% annots, , drop = FALSE]
    if (nrow(matching_rows) > 0) {
      matching_rows$Cluster <- i
      cluster_list <- rbind(cluster_list, matching_rows)
    }
  }

  if (nrow(cluster_list) == 0) {
    return(data.frame())
  }

  # Select relevant columns
  base_cols <- c("Cluster", "Term", "Annot", "GeneID", "Pvalue", "Padj")
  geneset_cols <- c(
    paste0("Pvalue_", gs_names),
    paste0("Padj_", gs_names),
    paste0("GeneID_", gs_names)
  )

  available_cols <- intersect(c(base_cols, geneset_cols), colnames(cluster_list))
  cluster_list <- cluster_list[, available_cols, drop = FALSE]

  return(cluster_list)
}


#' Add geneset-specific columns to cluster dataframe
#'
#' @param cluster_df Cluster dataframe
#' @param merged_gs Original merged geneset
#' @param gs_names Geneset names
#' @return Updated cluster dataframe
#' @keywords internal
add_geneset_columns <- function(cluster_df, merged_gs, gs_names) {

  if (!("Term" %in% colnames(cluster_df)) || !("Term" %in% colnames(merged_gs))) {
    return(cluster_df)
  }

  # Match terms and add geneset-specific columns
  for (gs_name in gs_names) {
    pval_col <- paste0("Pvalue_", gs_name)
    padj_col <- paste0("Padj_", gs_name)
    geneid_col <- paste0("GeneID_", gs_name)

    if (pval_col %in% colnames(merged_gs)) {
      cluster_df[[pval_col]] <- merged_gs[[pval_col]][match(cluster_df$Term, merged_gs$Term)]
    }
    if (padj_col %in% colnames(merged_gs)) {
      cluster_df[[padj_col]] <- merged_gs[[padj_col]][match(cluster_df$Term, merged_gs$Term)]
    }
    if (geneid_col %in% colnames(merged_gs)) {
      cluster_df[[geneid_col]] <- merged_gs[[geneid_col]][match(cluster_df$Term, merged_gs$Term)]
    }
  }

  return(cluster_df)
}


#' Build cluster summary with representative terms
#'
#' Creates a summary dataframe with one row per cluster, showing the
#' representative term (most significant) for each cluster.
#'
#' @param cluster_df Full cluster dataframe
#' @return Summary dataframe with cluster representatives
#' @keywords internal
build_cluster_summary <- function(cluster_df) {

  if (is.null(cluster_df) || nrow(cluster_df) == 0) {
    return(data.frame())
  }

  # Check for required columns
  if (!("Cluster" %in% colnames(cluster_df)) || !("Term" %in% colnames(cluster_df))) {
    return(data.frame())
  }

  # Get representative term per cluster (most significant by Pvalue or Padj)
  value_col <- if ("Padj" %in% colnames(cluster_df)) "Padj" else if ("Pvalue" %in% colnames(cluster_df)) "Pvalue" else NULL

  if (is.null(value_col)) {
    # No p-value column, just count terms
    summary_df <- cluster_df %>%
      dplyr::group_by(Cluster) %>%
      dplyr::summarise(
        Representative_Term = dplyr::first(Term),
        n_terms = dplyr::n(),
        .groups = "drop"
      )
  } else {
    summary_df <- cluster_df %>%
      dplyr::group_by(Cluster) %>%
      dplyr::arrange(.data[[value_col]]) %>%
      dplyr::summarise(
        Representative_Term = dplyr::first(Term),
        n_terms = dplyr::n(),
        min_pvalue = min(.data[[value_col]], na.rm = TRUE),
        .groups = "drop"
      )
  }

  return(summary_df)
}


#' Get clustering method descriptions for UI
#'
#' Returns a list of available clustering methods with descriptions
#' for display in the UI.
#'
#' @return A named list where each element contains:
#'   \itemize{
#'     \item name: Display name for the method
#'     \item description: Detailed description of the method
#'     \item available: Logical indicating if the method can be used
#'   }
#'
#' @examples
#' methods <- get_clustering_methods()
#' names(methods)
#'
#' # Check which methods are available
#' vapply(methods, function(m) m$available, logical(1))
#'
#' @export
get_clustering_methods <- function() {
  methods <- list(
    "richR" = list(
      name = "richR (Original)",
      description = "Kappa-based clustering using the original richR::richCluster method",
      available = TRUE
    )
  )

  # Check if richCluster is available for additional methods
  if (is_richCluster_available()) {
    methods$hierarchical <- list(
      name = "Hierarchical (richCluster)",
      description = "Flexible hierarchical clustering with selectable distance metrics and linkage methods",
      available = TRUE
    )
    methods$david <- list(
      name = "DAVID Method",
      description = "DAVID-style functional clustering with multiple linkage thresholds",
      available = TRUE
    )
  } else {
    methods$hierarchical <- list(
      name = "Hierarchical (richCluster) - Not Available",
      description = "Install richCluster package to enable this method",
      available = FALSE
    )
    methods$david <- list(
      name = "DAVID Method - Not Available",
      description = "Install richCluster package to enable this method",
      available = FALSE
    )
  }

  return(methods)
}
