# Functions to create comprehensive and individual term heatmaps for cluster results
library(cowplot)
library(ComplexHeatmap)
library(circlize)
library(tidyHeatmap)
library(grid)
library(patchwork)

# Prepare cluster result for heatmap
hmap_prepare <- function(clustered_gs, gs_names) {
  
  # Create tibble with Term and AnnotationCluster
  x <- as_tibble(cbind(clustered_gs$AnnotationCluster, clustered_gs$Term))
  colnames(x) <- c('Cluster', 'Representative_Term')
  
  # Order clusters numerically
  x <- x[order(as.numeric(x$Cluster)), ]
  
  # Subset Padj columns of clustered_gs into new df values
  value_cols <- c(paste0("Pvalue_", gs_names), paste0("Padj_", gs_names))
  values <- clustered_gs[, value_cols]
  
  # Combine Term and Cluster with Padj values
  final_data <- data.frame()
  final_data <- cbind(x, values)
  
  return(final_data)
}


# Change whether heatmap cell displays mean, median, min, or max Pvalue/Padj
change_finaldata_valueby <- function(final_data, cluster_list, value_by="mean") {
  
  new_final_data <- final_data
  value_cols <- c(grep(paste0("^", "Pvalue"), colnames(cluster_list), value=TRUE), 
                  grep(paste0("^", "Padj"), colnames(cluster_list), value=TRUE))
  
  for (i in seq_along(final_data$Cluster)) {
    x <- filter(cluster_list, Cluster == i) # Creat subsetted df containing all terms in cluster
    
    # Find mean/med/min/max of Pvalue and Padjs
    if (value_by == "mean") {
      x_values <- colMeans(x[, c(value_cols)], na.rm = TRUE)
    } else if (value_by == "median") {
      x_values <- sapply(x[, c(value_cols)], median, na.rm = TRUE)
    } else if (value_by == "min") {
      x_values <- sapply(x[, c(value_cols)], function(col) suppressWarnings(min(col, na.rm = TRUE)))
    } else if (value_by == "max") {
      x_values <- sapply(x[, c(value_cols)], function(col) suppressWarnings(max(col, na.rm = TRUE)))
    }
    x_values[!is.finite(x_values)] <- NA
    
    final_x <- new_final_data[new_final_data$Cluster==i, ] # Specific row in final_data
    final_x[, c(value_cols)] <- x_values 
    
    new_final_data[new_final_data$Cluster==i, ] <- final_x
  }
  
  return(new_final_data)
  
}


# Create comprehensive heatmap displaying Pvalue/Padj for each cluster
# value_type = Type of value to display in heatmap (Pvalue/Padj)
# value_by = How Pvalue is calculated
comprehensive_hmap <- function(final_data, cluster_list, value_type="Padj", value_by="mean") {
  
  # change value based on value_by
  new_final_data <- change_finaldata_valueby(final_data=final_data, cluster_list=cluster_list, value_by=value_by)
  
  # grab either Pvalue or Padj
  value_cols <- grep(paste0("^", value_type), colnames(new_final_data), value=TRUE)
  
  # subset new_final_data by value_type
  subsetted_final_data <- new_final_data[, c("Cluster", "Representative_Term", value_cols)]
  
  # remove "Pvalue" or "Padj" from colnames
  colnames(subsetted_final_data) <- gsub(paste0("^", value_type, "_"), "", colnames(subsetted_final_data))
  
  # melt the data for heatmap construction
  melted_data <- reshape2::melt(subsetted_final_data, id.vars = c("Cluster", "Representative_Term"))
  melted_data$Cluster <- as.numeric(melted_data$Cluster)
  melted_data <- melted_data[order(melted_data$Cluster), ] # order by cluster #
  melted_data$value <- -log10(melted_data$value)
  melted_data$value <- round(melted_data$value, 4)
  my_nticks <- length(unique(melted_data$Representative_Term)) # get # of clusters to show on y axis
  
  p <- plot_ly (
    data = melted_data,
    x = ~variable,
    y = ~Representative_Term,
    z = ~value,
    type = "heatmap",
    colors = c('green', 'red'),
    text = ~paste0("Cluster ", Cluster, "<br>", Representative_Term, "<br>", "-log10(", value_type, "): ", value),
    colorbar = list(title = paste0("-log10(", value_type, ")")),
    hoverinfo = "text"
  ) %>%
    layout (
      title = paste0("-log10(", value_type, ") by Cluster"),
      xaxis = list(title = 'Geneset'), 
      yaxis = list(title = 'Representative Term for Cluster', categoryorder = "trace", nticks = my_nticks)
    )
    return(p)
}


# Create heatmap displaying expression for each term in cluster
# term_vec = Vector of clusters to display
# term_vec <- c("transport", "monocarboxylic acid biosynthetic process", "isoprenoid metabolic process", "acetyl-CoA metabolic process")
cluster_hmap <- function(cluster_list, term_vec, final_data, value_type="Padj") {
  
  # find cluster associated with term
  term_name_df <- final_data[final_data$Representative_Term %in% term_vec, ]
  term_nums <- term_name_df$Cluster # list of cluster #s
  
  cluster_hmap <- data.frame()
  for (i in seq_along(term_nums)) {
    tmp <- cluster_list[cluster_list$Cluster == term_nums[i], ]
    cluster_hmap <- rbind(cluster_hmap, tmp)
  }
  
  # Subset value_type columns
  value_cols <- base::grep(paste0("^", value_type), colnames(cluster_hmap), value=TRUE)
  cluster_hmap <- cluster_hmap[, c("Cluster", "Term", value_cols)]
  # Remove "Padj_" from colnames
  colnames(cluster_hmap) <- gsub(paste0("^", value_type, "_"), "", colnames(cluster_hmap))
  
  # Melt the data for heatmap construction
  melted_chmap_data <- reshape2::melt(cluster_hmap, id.vars = c("Cluster", "Term"))
  
  
  melted_chmap_data$value <- as.numeric(melted_chmap_data$value)
  melted_chmap_data$value <- -log10(melted_chmap_data$value)
  melted_chmap_data$value <- round(melted_chmap_data$value, 4)
  
  melted_chmap_data$Cluster <- as.numeric(melted_chmap_data$Cluster)
  melted_chmap_data <- melted_chmap_data[order(melted_chmap_data$Cluster), ] # Order by cluster #
  
  my_nticks <- length(unique(melted_chmap_data$Term)) # Get # of terms to show on y axis
  
  
  # Plot the heatmap
  p <- plot_ly (
    data = melted_chmap_data,
    x = ~variable,
    y = ~Term,
    z = ~value,
    type = "heatmap",
    colors = c('green', 'red'),
    text = ~paste0("Cluster ", Cluster, "<br>", Term, "<br>", "-log10(", value_type, "): ", value),  # Customize hover text
    colorbar = list(title = paste0("-log10(", value_type, ")")),
    hoverinfo = "text"
  ) %>%
  layout (
    title = paste0("-log10(", value_type, ") by Term"),
    xaxis = list(title = 'Geneset'), 
    yaxis = list(title = 'Term', categoryorder = "trace", nticks = my_nticks)
  )
  
  clusty_annot <- melted_chmap_data %>%
    distinct(Cluster, Term) %>%
    arrange(Cluster)
  
  clusty <- cluster_hmap[, !(colnames(cluster_hmap) %in% c("Cluster", "Term"))]
  clusty <- apply(clusty, c(1, 2), function(x) -log10(x))
  rownames(clusty) <- clusty_annot$Term
  
  my_hm <- heatmaply(
    clusty, 
    row_side_colors=data.frame("Cluster"=clusty_annot$Cluster, check.names=FALSE),
    cellnote=clusty,
    plot_method='plotly',
    cluster_rows=FALSE, cluster_cols=FALSE,
    Rowv=FALSE,
    Colv=FALSE,
    main=paste0("-log10(", value_type, ") by Term"),
    key.title=paste0("-log10(", value_type, ")")
  )
  
  return(my_hm)
}
  