# Functions to create comprehensive and individual term heatmaps for cluster results

# Named constants for heatmap configuration
HMAP_ROUND_DIGITS <- 4L
HMAP_COLOR_LOW <- "green"
HMAP_COLOR_HIGH <- "red"


# Prepare cluster result for heatmap
hmap_prepare <- function(clustered_gs, gs_names) {
  
  # Create tibble with Term and AnnotationCluster
  x <- tibble::as_tibble(cbind(clustered_gs$AnnotationCluster, clustered_gs$Term))
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


# Convert display probabilities without altering the source tables.
hmap_numeric_pvalues <- function(values, where) {
  raw <- values
  if (is.factor(values)) values <- as.character(values)
  values <- suppressWarnings(as.numeric(values))
  coerced <- is.na(values) & !is.na(raw) & nzchar(as.character(raw))
  if (any(coerced)) {
    warning(sprintf("%s: %d non-numeric value(s) coerced to NA in heatmap data",
                    where, sum(coerced)), call. = FALSE)
  }
  invalid <- !is.na(values) & (!is.finite(values) | values < 0 | values > 1)
  if (any(invalid)) {
    warning(sprintf("%s: %d probability value(s) outside [0, 1] treated as missing",
                    where, sum(invalid)), call. = FALSE)
    values[invalid] <- NA_real_
  }
  values
}

hmap_display_values <- function(values, digits=HMAP_ROUND_DIGITS) {
  # The smallest representable positive value keeps an underflowed zero finite.
  # Raw zeros are retained separately and explicitly identified in hover text.
  floor_value <- .Machine$double.xmin * .Machine$double.eps
  if (floor_value == 0) floor_value <- .Machine$double.xmin
  values[!is.na(values) & values == 0] <- floor_value
  scores <- -log10(values)
  if (is.null(digits)) scores else round(scores, digits)
}

hmap_cluster_choices <- function(final_data) {
  ids <- as.character(final_data$Cluster)
  if (anyNA(ids) || any(!nzchar(ids)) || anyDuplicated(ids)) {
    stop("Cluster summary must contain unique, non-missing cluster IDs", call. = FALSE)
  }
  stats::setNames(paste0("cluster:", ids),
                  paste0("Cluster ", ids, " | ", final_data$Representative_Term))
}

# Change whether heatmap cells display mean, median, min, or max Pvalue/Padj.
change_finaldata_valueby <- function(final_data, cluster_list, value_by="mean") {
  if (length(value_by) != 1L || !value_by %in% c("mean", "median", "min", "max")) {
    stop("Invalid value_by parameter", call. = FALSE)
  }
  new_final_data <- final_data
  value_cols <- intersect(grep("^(Pvalue|Padj)", names(cluster_list), value=TRUE),
                          names(final_data))
  values <- lapply(cluster_list[value_cols], hmap_numeric_pvalues,
                   where = "change_finaldata_valueby")
  aggregate_value <- function(x) {
    if (!length(x) || all(is.na(x))) return(NA_real_)
    switch(value_by, mean = mean(x, na.rm=TRUE), median = median(x, na.rm=TRUE),
           min = min(x, na.rm=TRUE), max = max(x, na.rm=TRUE))
  }
  for (i in seq_len(nrow(final_data))) {
    rows <- !is.na(cluster_list$Cluster) &
      as.character(cluster_list$Cluster) == as.character(final_data$Cluster[i])
    for (column in value_cols) {
      new_final_data[i, column] <- aggregate_value(values[[column]][rows])
    }
  }
  new_final_data
}

# Create the cluster summary heatmap using cluster IDs, not representative names.
comprehensive_hmap <- function(final_data, cluster_list, value_type="Padj", value_by="mean") {
  if (length(value_type) != 1L || !value_type %in% c("Pvalue", "Padj")) {
    stop("Invalid value_type parameter", call. = FALSE)
  }
  choices <- hmap_cluster_choices(final_data)
  new_final_data <- change_finaldata_valueby(final_data, cluster_list, value_by)
  value_cols <- grep(paste0("^", value_type, "(_|$)"), names(new_final_data), value=TRUE)
  subsetted <- new_final_data[, c("Cluster", "Representative_Term", value_cols), drop=FALSE]
  names(subsetted) <- sub(paste0("^", value_type, "_"), "", names(subsetted))
  melted_data <- reshape2::melt(subsetted, id.vars=c("Cluster", "Representative_Term"))
  numeric_ids <- suppressWarnings(as.numeric(as.character(melted_data$Cluster)))
  ordering <- if (anyNA(numeric_ids)) as.character(melted_data$Cluster) else numeric_ids
  melted_data <- melted_data[order(ordering), ]
  melted_data$raw_value <- hmap_numeric_pvalues(melted_data$value, "comprehensive_hmap")
  melted_data$value <- hmap_display_values(melted_data$raw_value)
  if (all(is.na(melted_data$value))) melted_data$value <- I(melted_data$value)
  melted_data$cluster_key <- paste0("cluster:", melted_data$Cluster)
  description <- ifelse(is.na(melted_data$raw_value), "Not available",
    ifelse(melted_data$raw_value == 0,
           paste0("0 (display floor; -log10 = ", melted_data$value, ")"),
           paste0("-log10(", value_type, "): ", melted_data$value)))
  melted_data$hover <- paste0("Cluster ", melted_data$Cluster, "<br>",
                             melted_data$Representative_Term, "<br>", description)
  plot_ly(
    data=melted_data, x=~variable, y=~cluster_key, z=~value, type="heatmap",
    colors=c(HMAP_COLOR_LOW, HMAP_COLOR_HIGH), text=~hover, hoverinfo="text",
    hoverongaps=TRUE, colorbar=list(title=paste0("-log10(", value_type, ")"))
  ) %>% layout(
    title=paste0("-log10(", value_type, ") by Cluster"),
    xaxis=list(title="Geneset"),
    yaxis=list(title="Cluster and representative term", categoryorder="array",
               categoryarray=unname(choices), tickmode="array", tickvals=unname(choices),
               ticktext=names(choices)),
    plot_bgcolor="#eeeeee",
    annotations=list(list(text="Grey cells: no available value; zero p-values use a display floor",
                          x=0, y=-0.18, xref="paper", yref="paper", showarrow=FALSE,
                          xanchor="left", font=list(size=11))),
    margin=list(b=95)
  )
}

# Create a term heatmap. New UI selections use IDs; legacy representative names
# remain accepted, selecting all matching clusters as in older saved sessions.
cluster_hmap <- function(cluster_list, term_vec, final_data, value_type="Padj") {
  if (length(value_type) != 1L || !value_type %in% c("Pvalue", "Padj")) {
    stop("Invalid value_type parameter", call. = FALSE)
  }
  choices <- hmap_cluster_choices(final_data)
  id_selection <- paste0("cluster:", final_data$Cluster) %in% term_vec
  legacy_selection <- final_data$Representative_Term %in% setdiff(term_vec, unname(choices))
  ids <- final_data$Cluster[id_selection | legacy_selection]
  selected <- cluster_list[cluster_list$Cluster %in% ids, , drop=FALSE]
  if (!nrow(selected)) stop("No matching clusters selected", call. = FALSE)
  selected <- selected[order(match(selected$Cluster, ids)), , drop=FALSE]
  value_cols <- grep(paste0("^", value_type, "(_|$)"), names(selected), value=TRUE)
  if (!length(value_cols)) stop("No probability columns available", call. = FALSE)
  values <- as.data.frame(lapply(selected[value_cols], hmap_numeric_pvalues,
                                 where="cluster_hmap"))
  names(values) <- sub(paste0("^", value_type, "_"), "", names(values))
  raw_values <- as.matrix(values)
  clusty <- matrix(hmap_display_values(as.vector(raw_values), digits=NULL), nrow=nrow(raw_values),
                   dimnames=list(NULL, names(values)))
  labels <- as.character(selected$Term)
  if (anyDuplicated(labels)) labels <- paste0("Cluster ", selected$Cluster, " | ", labels)
  rownames(clusty) <- make.unique(labels)
  notes <- matrix(ifelse(is.na(raw_values), "Not available",
                         ifelse(raw_values == 0, "0 (display floor)", as.character(raw_values))),
                  nrow=nrow(raw_values), dimnames=dimnames(clusty))
  notes <- matrix(paste0("Term: ", rownames(clusty)[row(clusty)],
                          "<br>Analysis: ", colnames(clusty)[col(clusty)],
                          "<br>", value_type, ": ", notes,
                          "<br>-log10(", value_type, "): ", clusty),
                  nrow=nrow(clusty), dimnames=dimnames(clusty))
  # heatmaply cannot infer a color domain when every cell is missing.
  # AsIs keeps plotly from mapping the NA matrix through a numeric palette.
  if (all(is.na(clusty))) {
    return(plotly::plot_ly(
      x=colnames(clusty), y=rownames(clusty), z=I(clusty), text=notes,
      type="heatmap", hoverinfo="text", hoverongaps=TRUE, showscale=FALSE
    ) %>% layout(title="No available values", plot_bgcolor="#eeeeee",
                 xaxis=list(title="Analysis"), yaxis=list(title="Term")))
  }
  heatmaply(
    clusty, row_side_colors=data.frame("Cluster"=as.character(selected$Cluster), check.names=FALSE),
    custom_hovertext=notes, plot_method="plotly", cluster_rows=FALSE, cluster_cols=FALSE,
    Rowv=FALSE, Colv=FALSE, main=paste0("-log10(", value_type, ") by Term"),
    key.title=paste0("-log10(", value_type, ")"), na.value="#eeeeee"
  )
}
