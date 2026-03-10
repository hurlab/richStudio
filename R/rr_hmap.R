# Functions to create integrative heatmaps from multiple enrichment results
# (No clustering)
#
# Naming conventions in this file:
# - *_gs functions: geneset manipulation helpers (add, remove geneset data)
# - *_hmap functions: heatmap plot generators
# These names are used by Shiny UI modules and must not be renamed without
# updating all call sites.


#' Add custom-selected terms from a geneset to the combined dataframe
#'
#' Merges user-selected terms from a geneset into the cumulative
#' \code{custom_data} dataframe used for integrative heatmap construction.
#' Handles first-time addition, repeat additions, and GeneID column merging.
#'
#' @param custom_data A data frame (possibly empty) accumulating terms across
#'   genesets. Must contain columns Annot, Term, and GeneID when non-empty.
#' @param gs A data frame for one enrichment result (geneset).
#' @param gs_name Character. Label for this geneset, appended as a suffix to
#'   column names to distinguish sources.
#' @param term_vec Character vector. Terms selected by the user to include.
#' @return Updated \code{custom_data} data frame with the new terms merged in.
add_custom_gs <- function(custom_data=NULL, gs, gs_name, term_vec) {
  
  # Subset gs by rows with gs$Term in term_vec
  gs <- gs[which(gs$Term %in% term_vec), ]
  
  # Append filename to all colnames except "Annot" and "Term"
  exclude_cols <- c("Annot", "Term")
  colnames(gs) <- ifelse(colnames(gs) %in% exclude_cols, colnames(gs), 
                         paste(colnames(gs), gs_name, sep="_"))
  
  # If custom_data empty, set it to gs
  if (nrow(custom_data) == 0) {
    custom_data <- gs
  } else {
    # Match anything + _ + (gs_name)
    gsname_cols <-  c(grep(paste0(".*_", gs_name), colnames(custom_data), value=TRUE))
    
    # If gs not previously added
    if (length(gsname_cols) == 0) {
      custom_data <- base::merge(custom_data, gs, by=c('Annot', 'Term'), all=TRUE)
    } 
    # Else, gs previously added
    else { 
      # Get columns present in custom_data but not in gs
      cd_only_cols <- setdiff(colnames(custom_data), colnames(gs))
      gs[ , cd_only_cols] <- NA # Add cd_only_cols to gs as NA values (enables rbind)
      
      # Create dataframe of already added terms (term already added, gsname_cols are not NA)
      added_term_df <- custom_data[which(custom_data$Term %in% term_vec), ]
      added_term_df <- added_term_df[, c('Term', which(colnames(custom_data) %in% gsname_cols))]
      added_term_df <- drop_na(added_term_df) 
      
      gs <- gs[!which(gs$Term %in% added_term_df$Term), ] # Exclude already added terms from gs
      
      custom_data <- rbind(custom_data, gs) # Rbind
    }
  }
  
  # Merge GeneID cols
  geneid_cols <- c(grep(paste0("^", "GeneID", "_"), colnames(custom_data), value=TRUE))
  tmp <- custom_data[, geneid_cols]
  # Only one GeneID column (tmp is atomic)
  if (is.null(dim(tmp))) {
    names(tmp) <- c("GeneID")
    custom_data$GeneID <- tmp
  } 
  # Else, merge multiple GeneID columns
  else {
    custom_data$GeneID <- apply(custom_data[, geneid_cols], 1, function (x) {
      paste(unique(c(x)), collapse=',') # Collect unique GeneIDs
    })
    custom_data$GeneID <- sapply(custom_data$GeneID, function(x) {
      gsub('NA,', '', x) # Catch NA
    })
    custom_data$GeneID <- sapply(custom_data$GeneID, function(x) {
      gsub(',NA$', '', x, perl=TRUE) # Catch NA at the end
    })
  }
  # Return resulting custom_data df
  return(custom_data)
}


#' Add top-ranked terms from a geneset to the combined dataframe
#'
#' Filters a geneset by significance threshold and selects the top N terms,
#' then merges them into the cumulative \code{custom_data} dataframe. Replaces
#' any previously added data for the same geneset.
#'
#' @param custom_data A data frame accumulating terms across genesets.
#' @param gs A data frame for one enrichment result (geneset).
#' @param gs_name Character. Label for this geneset, appended as a suffix to
#'   column names to distinguish sources.
#' @param value_type Character. Column name for significance values
#'   (\code{"Padj"} or \code{"Pvalue"}).
#' @param value_cutoff Numeric. P-value cutoff for filtering.
#' @param top_nterms Integer. Number of top terms to include.
#' @return Updated \code{custom_data} data frame with the top terms merged in.
add_topterm_gs <- function(custom_data, gs, gs_name, value_type, value_cutoff, top_nterms) {
  
  # Make sure value_cutoff, top_nterms are numeric
  value_cutoff <- as.numeric(value_cutoff)
  top_nterms <- as.numeric(top_nterms)
  if (is.na(value_cutoff) || is.na(top_nterms)) {
    stop("value_cutoff and top_nterms must be numeric")
  }
  
  # Fix top_nterms later...
  # if (top_nterms == 0) {
  #   same_gs_cols <- grepl(gs_name, colnames(custom_data))
  #   if (!is.null(same_gs_cols)) { # Gs already in custom_data
  #     null_vec <- replicate(length(same_gs_cols), NULL) # Number of NULL = ncol
  #     null_vec <- setNames(null_vec, colnames(custom_data))
  #   }
  # }
  
  # Filter gs by value_type, value_cutoff, and top_nterms
  gs <- filter(gs, gs[, value_type] < value_cutoff)
  gs <- gs %>%
    arrange(value_type) %>%
    slice_head(n = top_nterms)
  
  # else { # Set gs to NULL vector
  #   gs <- setNames(replicate(ncol(gs), NULL), colnames(gs))
  #   gs <- data.frame(gs)
  # }
  
  # Append filename to all colnames except "Annot" and "Term"
  exclude_cols <- c("Annot", "Term")
  colnames(gs) <- ifelse(colnames(gs) %in% exclude_cols, colnames(gs), 
                         paste(colnames(gs), gs_name, sep="_"))
  
  # If gs already added, remove corresponding columns
  same_gs_cols <- grepl(gs_name, colnames(custom_data))
  custom_data <- custom_data[, !same_gs_cols]
  
  # If no other gs in custom_data...
  if (nrow(custom_data) == 0 || length(colnames(custom_data)) == 3) {
    custom_data <- gs # Set gs as the new custom_data
  } else { # Else, merge
    custom_data <- base::merge(custom_data, gs, by=c('Annot', 'Term'), all=TRUE)
  }
  
  # MERGE GENEID COLS
  geneid_cols <- c(grep(paste0("^", "GeneID", "_"), colnames(custom_data), value=TRUE))
  tmp <- custom_data[, geneid_cols]
  # If tmp is a vector (one gs in custom_data)
  if (is.null(dim(tmp))) { 
    names(tmp) <- c("GeneID")
    custom_data$GeneID <- tmp
  }
  # Multiple genesets in custom_data; merge GeneIDs
  else { 
    custom_data$GeneID <- apply(custom_data[, geneid_cols], 1, function(x) {
      paste(unique(c(x)), collapse=',') # Iterate over all geneid_cols for unique items
    })
    custom_data$GeneID <- sapply(custom_data$GeneID, function(x) {
      gsub('NA,', '', x) # Catch NA in the beginning/middle
    })
    custom_data$GeneID <- sapply(custom_data$GeneID, function(x) {
      gsub(',NA$', '', x, perl=TRUE) # Catch NA at the end
    })
  }
  
  # Remove rows from custom_data where no gs has values (NA or NULL)
  remove_df <- custom_data[, !(colnames(custom_data) %in% c("Annot", "Term", "GeneID"))]
  remove_vec <- apply(remove_df, 1, function(row) {
    all(is.na(row) | sapply(row, is.null)) # Create logical vector, FALSE if entire row is NA or NULL
  })
  custom_data <- custom_data[!remove_vec, ] # Remove all NA/NULL rows from custom_data
  return(custom_data)
}


#' Remove selected terms or an entire geneset from the combined dataframe
#'
#' Removes specific terms from \code{custom_data}, or removes an entire
#' geneset's columns and associated term rows when \code{delete_all} is
#' provided.
#'
#' @param custom_data A data frame accumulating terms across genesets.
#' @param gs_name Character. Label of the geneset to operate on.
#' @param term_vec Character vector. Terms to remove (used when
#'   \code{delete_all} is \code{NULL}).
#' @param delete_all Character vector or \code{NULL}. If provided, all columns
#'   for \code{gs_name} and all rows matching these terms are removed.
#' @return Updated \code{custom_data} data frame with terms/geneset removed.
remove_gs <- function(custom_data, gs_name, term_vec, delete_all=NULL) {
  # delete entire geneset if passed term_vec arg "delete_all" w/ all terms
  if (!is.null(delete_all)) {
    # match anything + _ + (gs_name)
    gs_cols <- c(grep(paste0(".*_", gs_name), colnames(custom_data), value=TRUE))
    # filter out gs columns and term rows
    custom_data2 <- custom_data[, -which(colnames(custom_data) %in% gs_cols)]
    custom_data2 <- custom_data2[-which(custom_data2$Term %in% delete_all), ]
    if (nrow(custom_data2) == 0) {
      custom_data2 <- data.frame()
    }
  } 
  # else only delete selected terms
  else {
    # subset custom_data by terms to delete
    custom_data2 <- custom_data[-which(custom_data$Term %in% term_vec), ]
  }
  return(custom_data2)
}


#' Create a custom integrative heatmap from the combined dataframe
#'
#' Generates an interactive heatmap (via plotly) showing -log10 transformed
#' significance values for user-selected terms across multiple genesets.
#' Uses \code{custom_data} built by \code{add_custom_gs}.
#'
#' @param custom_data A data frame built by \code{add_custom_gs} or
#'   \code{add_topterm_gs}, containing multi-geneset enrichment data.
#' @param value_type Character. Column prefix for significance values,
#'   typically \code{"Padj"} or \code{"Pvalue"}.
#' @return A plotly heatmap object.
custom_hmap <- function(custom_data, value_type) {
  
  # Grab either Pvalue or Padj based on value_type
  value_cols <- c(grep(paste0("^", value_type, "_"), colnames(custom_data), value=TRUE))
  if (length(value_cols) == 0) {
    stop("Invalid value_type")
  }
  # Subset new_final_data by value_type
  subsetted_final_data <- custom_data[, c("Annot", "Term", "GeneID", value_cols)]
  # Remove "Pvalue" or "Padj" from colnames
  colnames(subsetted_final_data) <- gsub(paste0("^", value_type, "_"), "", colnames(subsetted_final_data))

  melted_custom_data <- reshape2::melt(subsetted_final_data, id.vars = c("Term", "Annot", "GeneID"))
  
  melted_custom_data$value <- as.numeric(melted_custom_data$value)
  melted_custom_data$value <- -log10(melted_custom_data$value)
  melted_custom_data$value <- round(melted_custom_data$value, 4)
  
  my_nticks <- length(unique(melted_custom_data$Term))
  
  # Plot the heatmap
  p <- plot_ly (
    data = melted_custom_data,
    x = ~variable,
    y = ~Term,
    z = ~value,
    type = "heatmap",
    colors = c('green', 'red'),
    text = ~paste0(Term, "<br>", "-log10(", value_type, "): ", value, "<br>"),  # Customize hover text
    colorbar = list(title = paste0("-log10(", value_type, ")")),
    hoverinfo = "text"
  ) %>%
    layout (
      title = paste0("-log10(", value_type, ") by Term"),
      xaxis = list(title = 'Geneset'), 
      yaxis = list(title = 'Term', categoryorder = "trace", nticks = my_nticks)
    )
  return(p)
}



#' Create an integrative heatmap from top-ranked terms
#'
#' Generates an interactive heatmap (via plotly) showing -log10 transformed
#' significance values for top-ranked terms across multiple genesets. Unlike
#' \code{custom_hmap}, this function handles mixed Pvalue/Padj column prefixes.
#' Uses \code{custom_data} built by \code{add_topterm_gs}.
#'
#' @param custom_data A data frame built by \code{add_topterm_gs}, containing
#'   multi-geneset enrichment data with Pvalue_ and/or Padj_ prefixed columns.
#' @param value_type Character. Preferred significance column type, used for
#'   plot labels. Default \code{"Padj"}.
#' @return A plotly heatmap object.
topterm_hmap <- function(custom_data, value_type = "Padj") {

  # Grab either Pvalue or Padj based on value_type
  value_cols <- c(grep("^(Pvalue_|Padj_)", colnames(custom_data), value=TRUE))
  if (length(value_cols) == 0) {
    stop("No value columns found")
  }
  # Subset new_final_data by value_type
  subsetted_final_data <- custom_data[, c("Annot", "Term", "GeneID", value_cols)]
  # Remove "Pvalue" or "Padj" from colnames
  colnames(subsetted_final_data) <- gsub("^(Pvalue_|Padj_)", "", colnames(subsetted_final_data))

  melted_custom_data <- reshape2::melt(subsetted_final_data, id.vars = c("Term", "Annot", "GeneID"))

  melted_custom_data$value <- as.numeric(melted_custom_data$value)
  melted_custom_data$value <- -log10(melted_custom_data$value)
  melted_custom_data$value <- round(melted_custom_data$value, 4)

  my_nticks <- length(unique(melted_custom_data$Term))

  # Plot the heatmap
  p <- plot_ly (
    data = melted_custom_data,
    x = ~variable,
    y = ~Term,
    z = ~value,
    type = "heatmap",
    colors = c('green', 'red'),
    text = ~paste0(Term, "<br>", "-log10(", value_type, "): ", value, "<br>"),  # Customize hover text
    colorbar = list(title = paste0("-log10(", value_type, ")")),
    hoverinfo = "text"
  ) %>%
    layout (
      title = paste0("-log10(", value_type, ") by Term"),
      xaxis = list(title = 'Geneset'),
      yaxis = list(title = 'Term', categoryorder = "trace", nticks = my_nticks)
    )
  return(p)
}
