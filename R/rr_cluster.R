# Functions to merge and cluster enrichment results


# Sample genesets
# gs1 <- read.delim("./inst/extdata/go1.txt")
# gs2 <- read.delim("./inst/extdata/go2.txt")
# gs3 <- read.delim("./inst/extdata/kegg1.txt")
#
# genesets <- list(gs1, gs2, gs3)
# gs_names <- c('go1.txt', 'go2.txt', 'kegg1.txt')
#
# merged_gs <- merge_genesets(genesets)
# cluster_res <- cluster(merged_gs, 0.5, 0.5, 2)
# clus_liszt <- get_cluster_list(cluster_res, merged_gs, gs_names)

# names(genesets) <- c("go1.txt", "go2.txt", "kegg1.txt")
# gs_names <- c("go1.txt", "go2.txt", "kegg1.txt")


# Merges a list of genesets together to prepare for clustering
#' @export
merge_genesets <- function(genesets) {

  # suffix all non 'Term' columns with their gs name
  for (i in seq_along(genesets)) {
    #genesets[i] <- select_required_columns(genesets[i])
    rownames(genesets[[i]]) <- NULL # prevents rownames from messing up
    non_term_cols <- colnames(genesets[[i]])
    non_term_cols[-which(non_term_cols == 'Term')] <- paste(non_term_cols[-which(non_term_cols == 'Term')], names(genesets[i]), sep="_")
    colnames(genesets[[i]]) <- non_term_cols
  }

  # initialize merged_gs with first geneset
  merged_gs <- genesets[[1]]

  # merge genesets
  for (i in 2:length(genesets)) {
    merged_gs <- base::merge(merged_gs, genesets[[i]], by='Term', all=TRUE)
  }

  # combine unique 'GeneID' elements
  geneid_cols <- c()
  for (i in seq_along(genesets)) {
    geneid_cols <- c(geneid_cols, paste('GeneID', names(genesets[i]), sep="_"))
  }
  merged_gs$GeneID <- apply(merged_gs[, geneid_cols], 1, function (x) paste(unique(c(x)), collapse=','))
  # catch NA
  merged_gs$GeneID <- sapply(merged_gs$GeneID, function(x) gsub('NA,', '', x))
  # catch NA at the end
  merged_gs$GeneID <- sapply(merged_gs$GeneID, function(x) gsub(',NA$', '', x, perl=TRUE))

  # combine unique 'Annot' elements
  annot_cols <- c()
  for (i in seq_along(genesets)) {
    annot_cols <- c(annot_cols, paste('Annot', names(genesets[i]), sep="_"))
  }
  merged_gs$Annot <- apply(merged_gs[, annot_cols], 1, function(x) paste(unique(c(x)), collapse=',', recycle0=TRUE))
  # catch NA
  merged_gs$Annot <- sapply(merged_gs$Annot, function(x) gsub('NA,', '', x))
  # catch NA at the end
  merged_gs$Annot <- sapply(merged_gs$Annot, function(x) gsub(',NA$', '', x, perl=TRUE))
  merged_gs <- dplyr::select(merged_gs, -annot_cols)

  # average Pvalue
  pval_cols <- c()
  for (i in seq_along(genesets)) {
    pval_cols <- c(pval_cols, paste('Pvalue', names(genesets[i]), sep="_"))
  }
  merged_gs$Pvalue <- rowMeans(merged_gs[, pval_cols], na.rm=TRUE)

  # average Padj
  padj_cols <- c()
  for (i in seq_along(genesets)) {
    padj_cols <- c(padj_cols, paste('Padj', names(genesets[i]), sep="_"))
  }
  merged_gs$Padj <- rowMeans(merged_gs[, padj_cols], na.rm=TRUE)

  #return
  return(merged_gs)

}

# Clusters the merged geneset
cluster <- function(merged_gs, cutoff, overlap, minSize) {

  tryCatch({
    # cluster from richR package
    # gene=TRUE returns list of terms within cluster under 'Cluster' column
    clustered_gs <- richCluster(x=merged_gs, gene=TRUE, cutoff=cutoff, overlap=overlap, minSize=minSize) # from richR
    # order clusters by ascending cluster #
    clustered_gs <- clustered_gs[order(as.numeric(clustered_gs$AnnotationCluster)), ]
    return(clustered_gs)
  }, error = function(e) {
      stop(e$message)
  })

}


# Return list of terms & corresponding Pvalues, Padjs, GeneIDs for each cluster
get_cluster_list <- function(clustered_gs, merged_gs, gs_names) {

  # get list of Annots in cluster, index=cluster#
  term_indices <- sapply(clustered_gs$Cluster, function(x) unlist(strsplit(x, ',')))

  # for each cluster #, find matching row in merged_gs corresponding to Annot
  cluster_list <- data.frame()
  for (i in seq_along(term_indices)) {
    annots <- term_indices[[i]] # get Annot string from term_indices
    matching_rows <- merged_gs[merged_gs$Annot %in% annots, ] # find matching rows
    matching_rows$Cluster <- i # set cluster #
    cluster_list <- rbind(cluster_list, matching_rows) # append matching rows
  }

  # Create a vector of column names to subset
  selected_cols <- c("Cluster", "Term", "Annot")

  # Append the Pvalue, Padj, and GeneID columns for each file name
  selected_cols <- c(selected_cols,
                     paste0("Pvalue_", gs_names),
                     paste0("Padj_", gs_names),
                     paste0("GeneID_", gs_names))

  # Subset the dataframe based on the selected columns
  cluster_list <- cluster_list[, selected_cols]
  return(cluster_list)
}
