# Functions to create integrative heatmaps from multiple enrichment results
# (No clustering)
#
# Naming conventions in this file:
# - *_gs functions: geneset manipulation helpers (add, remove geneset data)
# - *_hmap functions: heatmap plot generators
# These names are used by Shiny UI modules and must not be renamed without
# updating all call sites.


# Columns belonging to one dataset: the merged tables name them
# "<column>_<gs_name>", so match the literal "_<gs_name>" suffix (no regex).
# When the dataset's own columns are known (base_cols) the match is exact.
gs_dataset_cols <- function(col_names, gs_name, base_cols=NULL) {
  if (!is.null(base_cols)) {
    return(col_names %in% paste(base_cols, gs_name, sep="_"))
  }
  endsWith(col_names, paste0("_", gs_name)) & !(col_names %in% c("Annot", "Term", "GeneID"))
}

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
add_custom_gs <- function(custom_data = NULL, gs, gs_name, term_vec) {
  # Subset gs by rows with gs$Term in term_vec
  gs <- gs[which(gs$Term %in% term_vec), ]

  # Append filename to all colnames except "Annot" and "Term"
  exclude_cols <- c("Annot", "Term")
  gs_orig <- colnames(gs)
  colnames(gs) <- ifelse(colnames(gs) %in% exclude_cols, colnames(gs), 
                         paste(colnames(gs), gs_name, sep="_"))
  
  # If custom_data empty, set it to gs
  if (is.null(custom_data) || nrow(custom_data) == 0) {
    custom_data <- gs
  } else {
    # Columns already added for this geneset (exact names, no regex)
    gsname_cols <- colnames(custom_data)[gs_dataset_cols(
      colnames(custom_data), gs_name, setdiff(gs_orig, exclude_cols))]
    
    # If gs not previously added
    if (length(gsname_cols) == 0) {
      custom_data <- base::merge(custom_data, gs, by=c('Annot', 'Term'), all=TRUE)
    } 
    # Else, gs previously added
    else { 
      gs_own_cols <- setdiff(colnames(gs), exclude_cols)
      
      # Get columns present in custom_data but not in gs
      cd_only_cols <- setdiff(colnames(custom_data), colnames(gs))
      # Add cd_only_cols to gs as NA values (enables rbind)
      gs[, cd_only_cols] <- NA

      # Create dataframe of already added terms (term already added, gsname_cols
      # are not NA)
      added_term_df <- custom_data[which(custom_data$Term %in% term_vec), ]
      added_term_df <- added_term_df[, c('Term', gsname_cols), drop=FALSE]
      added_term_df <- tidyr::drop_na(added_term_df)
      
      gs <- gs[!(gs$Term %in% added_term_df$Term), , drop=FALSE] # Exclude already added terms from gs
      
      # Terms another geneset already holds fill that row; the rest are appended
      hit <- match(paste(gs$Annot, gs$Term), paste(custom_data$Annot, custom_data$Term))
      shared <- !is.na(hit)
      custom_data[hit[shared], gs_own_cols] <- gs[shared, gs_own_cols, drop=FALSE]
      custom_data <- rbind(custom_data, gs[!shared, , drop=FALSE]) # Rbind
    }
  }

  # Merge GeneID cols
  geneid_cols <- c(grep(
    paste0("^", "GeneID", "_"),
    colnames(custom_data),
    value = TRUE
  ))
  tmp <- custom_data[, geneid_cols]
  # Only one GeneID column (tmp is atomic)
  if (is.null(dim(tmp))) {
    names(tmp) <- c("GeneID")
    custom_data$GeneID <- tmp
  } else {
    # Else, merge multiple GeneID columns
    custom_data$GeneID <- apply(custom_data[, geneid_cols], 1, function(x) {
      paste(unique(c(x)), collapse = ",") # Collect unique GeneIDs
    })
    custom_data$GeneID <- sapply(custom_data$GeneID, function(x) {
      gsub("NA,", "", x) # Catch NA
    })
    custom_data$GeneID <- sapply(custom_data$GeneID, function(x) {
      gsub(",NA$", "", x, perl = TRUE) # Catch NA at the end
    })
  }
  # Return resulting custom_data df
  custom_data
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
add_topterm_gs <- function(
  custom_data,
  gs,
  gs_name,
  value_type,
  value_cutoff,
  top_nterms
) {
  # Make sure value_cutoff, top_nterms are numeric
  value_cutoff <- as.numeric(value_cutoff)
  top_nterms <- as.numeric(top_nterms)
  if (is.na(value_cutoff) || is.na(top_nterms)) {
    stop("value_cutoff and top_nterms must be numeric")
  }

  # Historical inactive example: see the rr_hmap.R section in
  # The reference is in `docs/development/historical-r-examples.md`.

  # Filter gs by value_type, value_cutoff, and top_nterms
  gs <- filter(gs, gs[, value_type] < value_cutoff)
  gs <- gs %>%
    arrange(.data[[value_type]]) %>%
    slice_head(n = top_nterms)

  # Historical inactive example: see the rr_hmap.R section in
  # The reference is in `docs/development/historical-r-examples.md`.

  # Append filename to all colnames except "Annot" and "Term"
  exclude_cols <- c("Annot", "Term")
  gs_orig <- colnames(gs)
  colnames(gs) <- ifelse(colnames(gs) %in% exclude_cols, colnames(gs), 
                         paste(colnames(gs), gs_name, sep="_"))
  
  # If gs already added, remove corresponding columns (exact names, no regex)
  same_gs_cols <- gs_dataset_cols(colnames(custom_data), gs_name,
                                  setdiff(gs_orig, exclude_cols))
  custom_data <- custom_data[, !same_gs_cols, drop=FALSE]
  
  # If no other gs in custom_data (no dataset-specific columns remain)...
  if (is.null(custom_data) || nrow(custom_data) == 0 ||
      all(colnames(custom_data) %in% c("Annot", "Term", "GeneID"))) {
    custom_data <- gs # Set gs as the new custom_data
  } else {
    # Else, merge
    custom_data <- base::merge(
      custom_data,
      gs,
      by = c("Annot", "Term"),
      all = TRUE
    )
  }

  # MERGE GENEID COLS
  geneid_cols <- c(grep(
    paste0("^", "GeneID", "_"),
    colnames(custom_data),
    value = TRUE
  ))
  tmp <- custom_data[, geneid_cols]
  # If tmp is a vector (one gs in custom_data)
  if (is.null(dim(tmp))) {
    names(tmp) <- c("GeneID")
    custom_data$GeneID <- tmp
  } else {
    # Multiple genesets in custom_data; merge GeneIDs
    custom_data$GeneID <- apply(custom_data[, geneid_cols], 1, function(x) {
      # Iterate over all geneid_cols for unique items
      paste(unique(c(x)), collapse = ",")
    })
    custom_data$GeneID <- sapply(custom_data$GeneID, function(x) {
      gsub("NA,", "", x) # Catch NA in the beginning/middle
    })
    custom_data$GeneID <- sapply(custom_data$GeneID, function(x) {
      gsub(",NA$", "", x, perl = TRUE) # Catch NA at the end
    })
  }

  # Remove rows from custom_data where no gs has values (NA or NULL)
  remove_df <- custom_data[,
    !(colnames(custom_data) %in% c("Annot", "Term", "GeneID"))
  ]
  remove_vec <- apply(remove_df, 1, function(row) {
    # Create logical vector, FALSE if entire row is NA or NULL
    all(is.na(row) | sapply(row, is.null))
  })
  # Remove all NA/NULL rows from custom_data
  custom_data <- custom_data[!remove_vec, ]
  custom_data
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
#'   for \code{gs_name} are removed, together with every row that no other
#'   geneset still holds a value for. Only its non-\code{NULL} status matters.
#' @param gs_cols Character vector or \code{NULL}. Column names of the geneset's
#'   own result table; when given, its merged columns are matched exactly
#'   instead of by the \code{_gs_name} suffix.
#' @return Updated \code{custom_data} data frame with terms/geneset removed.
remove_gs <- function(custom_data, gs_name, term_vec, delete_all=NULL, gs_cols=NULL) {
  # delete entire geneset if passed "delete_all" w/ the geneset's selected terms
  if (!is.null(delete_all)) {
    drop_cols <- gs_dataset_cols(colnames(custom_data), gs_name,
                                 if (is.null(gs_cols)) NULL else setdiff(gs_cols, c("Annot", "Term")))
    # filter out gs columns
    custom_data2 <- custom_data[, !drop_cols, drop=FALSE]
    # a row with no value left in any other geneset is exclusive to this one
    # (an orphan by definition), whatever delete_all lists; shared rows survive
    other_cols <- setdiff(colnames(custom_data2), c("Annot", "Term", "GeneID"))
    still_used <- if (length(other_cols) == 0) {
      rep(FALSE, nrow(custom_data2))
    } else {
      rowSums(!is.na(custom_data2[, other_cols, drop=FALSE])) > 0
    }
    custom_data2 <- custom_data2[still_used, , drop=FALSE]
    if (nrow(custom_data2) == 0) {
      custom_data2 <- data.frame()
    } else {
      # surviving shared terms describe the remaining genesets only
      geneid_cols <- grep("^GeneID_", colnames(custom_data2), value=TRUE)
      if ("GeneID" %in% colnames(custom_data2) && length(geneid_cols) > 0) {
        custom_data2$GeneID <- apply(custom_data2[, geneid_cols, drop=FALSE], 1, function(x) {
          paste(unique(x[!is.na(x)]), collapse=',')
        })
      }
    }
  } else {
    # else only delete selected terms
    # subset custom_data by terms to delete
    custom_data2 <- custom_data[!(custom_data$Term %in% term_vec), ]
  }
  custom_data2
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
  value_cols <- c(grep(
    paste0("^", value_type, "_"),
    colnames(custom_data),
    value = TRUE
  ))
  if (length(value_cols) == 0) {
    stop("Invalid value_type")
  }
  # Subset new_final_data by value_type
  subsetted_final_data <- custom_data[, c(
    "Annot",
    "Term",
    "GeneID",
    value_cols
  )]
  # Remove "Pvalue" or "Padj" from colnames
  colnames(subsetted_final_data) <- gsub(
    paste0("^", value_type, "_"),
    "",
    colnames(subsetted_final_data)
  )

  melted_custom_data <- reshape2::melt(
    subsetted_final_data,
    id.vars = c("Term", "Annot", "GeneID")
  )

  melted_custom_data$value <- as.numeric(melted_custom_data$value)
  melted_custom_data$value <- -log10(melted_custom_data$value)
  melted_custom_data$value <- round(melted_custom_data$value, 4)

  my_nticks <- length(unique(melted_custom_data$Term))

  # Plot the heatmap
  p <- plot_ly(
    data = melted_custom_data,
    x = ~variable,
    y = ~Term,
    z = ~value,
    type = "heatmap",
    colors = hmap_colors,
    # Customize hover text
    text = ~ paste0(Term, "<br>", "-log10(", value_type, "): ", value, "<br>"),
    colorbar = list(title = paste0("-log10(", value_type, ")")),
    hoverinfo = "text"
  ) %>%
    layout(
      title = paste0("-log10(", value_type, ") by Term"),
      xaxis = list(title = "Geneset"),
      yaxis = hmap_term_axis(melted_custom_data$Term, my_nticks)
    )
  p
}


# Longest term label drawn on the y axis; longer labels end in an ellipsis and the
# full term stays in the hover text.
hmap_label_limit <- 40L

hmap_truncate_labels <- function(x, limit = hmap_label_limit) {
  x <- as.character(x)
  long <- !is.na(x) & nchar(x, type = "width") > limit
  x[long] <- paste0(substr(x[long], 1L, limit - 1L), intToUtf8(8230L))
  x
}

# Height of a bar or dot plot that grows with the number of displayed terms
# (about 18 px per term plus room for the title, axis and legend), with a minimum.
rr_term_plot_height <- function(n_terms, per_term = 18L, base = 160L, minimum = 400L) {
  as.integer(max(minimum, base + per_term * max(0L, as.integer(n_terms))))
}

# Term axis for bar and dot plots: truncated labels (the hover text keeps the full
# term), automatic left margin.
rr_term_axis <- function(levels) {
  values <- as.character(levels)
  list(
    title = "Term",
    categoryorder = "trace",
    tickmode = "array",
    tickvals = values,
    ticktext = htmltools::htmlEscape(hmap_truncate_labels(values)),
    automargin = TRUE
  )
}

# Sets the widget element to the figure's height so a tall figure is not clipped to
# the default output height.
rr_apply_plot_height <- function(plot, height) {
  htmlwidgets::onRender(
    plot,
    sprintf(
      "function(el, x) { el.style.height = '%dpx'; Plotly.Plots.resize(el); }",
      as.integer(height)
    )
  )
}

# Term axis with truncated tick labels; the categories themselves are untouched.
hmap_term_axis <- function(terms, nticks) {
  values <- unique(as.character(terms))
  list(
    title = "Term",
    categoryorder = "trace",
    nticks = nticks,
    tickmode = "array",
    tickvals = values,
    ticktext = htmltools::htmlEscape(hmap_truncate_labels(values))
  )
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
  value_cols <- c(grep("^(Pvalue_|Padj_)", colnames(custom_data), value = TRUE))
  if (length(value_cols) == 0) {
    stop("No value columns found")
  }
  # Subset new_final_data by value_type
  subsetted_final_data <- custom_data[, c(
    "Annot",
    "Term",
    "GeneID",
    value_cols
  )]
  # Remove "Pvalue" or "Padj" from colnames
  colnames(subsetted_final_data) <- gsub(
    "^(Pvalue_|Padj_)",
    "",
    colnames(subsetted_final_data)
  )

  melted_custom_data <- reshape2::melt(
    subsetted_final_data,
    id.vars = c("Term", "Annot", "GeneID")
  )

  melted_custom_data$value <- as.numeric(melted_custom_data$value)
  melted_custom_data$value <- -log10(melted_custom_data$value)
  melted_custom_data$value <- round(melted_custom_data$value, 4)

  my_nticks <- length(unique(melted_custom_data$Term))

  # Plot the heatmap
  p <- plot_ly(
    data = melted_custom_data,
    x = ~variable,
    y = ~Term,
    z = ~value,
    type = "heatmap",
    colors = hmap_colors,
    # Customize hover text
    text = ~ paste0(Term, "<br>", "-log10(", value_type, "): ", value, "<br>"),
    colorbar = list(title = paste0("-log10(", value_type, ")")),
    hoverinfo = "text"
  ) %>%
    layout(
      title = paste0("-log10(", value_type, ") by Term"),
      xaxis = list(title = "Geneset"),
      yaxis = hmap_term_axis(melted_custom_data$Term, my_nticks)
    )
  p
}
