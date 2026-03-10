# Functions to create uploaded file dataframe


#' Add DEG Set to File Table
#'
#' Adds a differentially expressed gene (DEG) set to the master file tracking table.
#' Automatically detects GeneID column and checks for expression data.
#'
#' @param df Existing file tracking dataframe (or NULL/atomic for new table)
#' @param name Name identifier for the DEG set
#' @param new_df Dataframe containing the DEG data
#'
#' @return Updated file tracking dataframe with columns: name, GeneID_header, num_genes, has_expr_data
#'   Returns original df if name already exists (prevents duplicates)
#'   Returns vector of GeneID column matches if multiple/none found
#'
#' @examples
#' \dontrun{
#' deg_data <- data.frame(GeneID = c("Gene1", "Gene2"), log2FC = c(2.5, -1.8))
#' file_table <- add_file_degdf(NULL, "deg1", deg_data)
#' }
#'
#' @export
add_file_degdf <- function(df, name, new_df) {
  # Don't add if name already in df
  if (is.atomic(df) && name %in% df) { # Prevent error in $ operator for atomic vectors
    return(df)
  } else if (!is.atomic(df) && name %in% df$name) {
    return(df)
  }

  possible_geneID <- c("GeneID", "gene_id", "gene", "gene list", "symbol") # Possible "GeneID" colnames
  geneIDmatches <- grep(paste(possible_geneID, collapse="|"), colnames(new_df), ignore.case=TRUE)

  # Make expr_data checking better later
  # For now assumes dataframe-like objects contain expression data
  if (length(names(new_df)) > 1) {
    expr_data <- "True"
  } else {
    expr_data <- "False"
  }

  # Determine GeneID column
  if (length(geneIDmatches) == 1) {
    geneIDcol <- names(new_df[geneIDmatches])
  } else if (length(geneIDmatches) > 1) {
    # Multiple matches: use the first match
    geneIDcol <- names(new_df[geneIDmatches[1]])
  } else {
    # No match: use the first column as fallback
    geneIDcol <- names(new_df)[1]
  }

  num_genes <- length(new_df[, geneIDcol])

  new_file_vec <- c(name=name, GeneID_header=geneIDcol, num_genes=num_genes, has_expr_data=expr_data)
  if (!is.null(df)) { # Rbind if df already exists
    df <- rbind(df, new_file_vec)
    names(df) <- c("name", "GeneID_header", "num_genes", "has_expr_data")
    rownames(df) <- NULL
  } else { # Else set df to the new file vector
    df <- new_file_vec
    df <- base::t(df)
    df <- as.data.frame(df)
    rownames(df) <- NULL
  }
  return(df)
}

#' Remove DEG Set from File Table
#'
#' Removes specified DEG sets from the master file tracking table.
#'
#' @param df Existing file tracking dataframe
#' @param rm_vec Dataframe or vector containing DEG sets to remove (must have 'name' column)
#'
#' @return Updated file tracking dataframe with specified DEG sets removed
#'   Returns NULL if df is atomic
#'
#' @examples
#' \dontrun{
#' file_table <- rm_file_degdf(file_table, file_table[1, ])
#' }
#'
#' @export
rm_file_degdf <- function(df, rm_vec) {
  #df <- df[df %!in% rm_vec]
  if(!is.atomic(df)){
    df <- df[-which(df$name %in% rm_vec$name), ]
  } else {
    df <- NULL
  }
  return(df)
}


#' Add Enrichment Result to File Table
#'
#' Adds an enrichment result to the master file tracking table.
#' Can handle both file-uploaded results and results from richStudio enrichment analysis.
#'
#' @param df Existing file tracking dataframe (or NULL for new table)
#' @param name Name identifier for the enrichment result
#' @param annot Annotation type (GO, KEGG, Reactome, or '?' if unknown)
#' @param keytype Gene ID keytype used (or '?' if unknown)
#' @param ontology Ontology used (BP, MF, CC, or '?' if unknown)
#' @param species Species analyzed (or '?' if unknown)
#' @param file Logical: TRUE if from file upload, FALSE if from richStudio enrichment
#'
#' @return Updated file tracking dataframe with columns: name, from_deg, annot, keytype, ontology, species
#'   Appends "_enriched" to name if file=FALSE
#'
#' @examples
#' \dontrun{
#' file_table <- add_file_rrdf(NULL, "go1", annot="GO", keytype="SYMBOL",
#'                             ontology="BP", species="human", file=TRUE)
#' }
#'
#' @export
add_file_rrdf <- function(df, name, annot='?', keytype='?', ontology='?', species='?', file=FALSE) {
  if (file==FALSE) {
    rr_name <- paste0(name, "_enriched")
    deg_name <- name
  } else if (file==TRUE) {
    rr_name <- name
    deg_name <- "No"
  }
  new_rr_vec <- c(name=rr_name, from_deg=deg_name, annot=annot, keytype=keytype, ontology=ontology, species=species)

  # If df is not null
  if (!is.null(df)) {
    matching_rows <- apply(df, 1, function(row) all(row == new_rr_vec))
    if (any(matching_rows)) {  # Don't append if exact rr already present
      return(df)
    } else { # Rbind if df already exists
      df <- rbind(df, new_rr_vec)
      names(df) <- c("name", "from_deg", "annot", "keytype", "ontology", "species")
      rownames(df) <- NULL
    }
  }
  # Else set df to the new file vector
  else {
    df <- new_rr_vec
    df <- base::t(df)
    df <- as.data.frame(df)
    rownames(df) <- NULL
  }

  return(df) # Return appended df on success

}

#' Remove Enrichment Result from File Table
#'
#' Removes specified enrichment results from the master file tracking table.
#'
#' @param df Existing file tracking dataframe
#' @param rm_vec Dataframe containing enrichment results to remove (must have 'name' column)
#'
#' @return Updated file tracking dataframe with specified enrichment results removed
#'   Returns NULL if df is atomic
#'
#' @examples
#' \dontrun{
#' file_table <- rm_file_rrdf(file_table, file_table[1, ])
#' }
#'
#' @export
rm_file_rrdf <- function(df, rm_vec) {
  #df <- df[df %!in% rm_vec]
  if(!is.atomic(df)){
    df <- df[-which(df$name %in% rm_vec$name), ]
  } else {
    df <- NULL
  }
  return(df)
}

#' Add Cluster Result to File Table
#'
#' Adds a clustering result to the master file tracking table.
#'
#' @param df Existing file tracking dataframe (or NULL for new table)
#' @param clusdf Dataframe containing the cluster result
#' @param name Name identifier for the cluster result
#' @param from_vec Character vector of enrichment result names used for clustering
#'
#' @return Updated file tracking dataframe with columns: name, n_clusters, from
#'   Returns original df if name already exists (prevents duplicates)
#'
#' @examples
#' \dontrun{
#' cluster_data <- data.frame(Cluster = c("C1", "C1", "C2"), Term = c("GO:1", "GO:2", "GO:3"))
#' file_table <- add_file_clusdf(NULL, cluster_data, "cluster1", c("go1", "go2"))
#' }
#'
#' @export
add_file_clusdf <- function(df, clusdf, name, from_vec) {
  # Don't add if name already in df
  if (is.atomic(df) && name %in% df) { # Prevent error in $ operator for atomic vectors
    return(df)
  } else if (!is.atomic(df) && name %in% df$name) {
    return(df)
  }
  from <- paste(from_vec, collapse=", ")
  n_clusters <- nrow(clusdf)

  new_file_vec <- c(name=name,  n_clusters=n_clusters, from=from)

  if (!is.null(df)) { # Rbind if df already exists
    df <- rbind(df, new_file_vec)
    names(df) <- c("name", "n_clusters", "from")
    rownames(df) <- NULL
  } else { # Else set df to the new file vector
    df <- new_file_vec
    df <- base::t(df)
    df <- as.data.frame(df)
    rownames(df) <- NULL
  }

  return(df)

}

#' Remove Cluster Result from File Table
#'
#' Removes specified cluster results from the master file tracking table.
#'
#' @param df Existing file tracking dataframe
#' @param rm_vec Dataframe containing cluster results to remove (must have 'name' column)
#'
#' @return Updated file tracking dataframe with specified cluster results removed
#'   Returns NULL if df is atomic
#'
#' @examples
#' \dontrun{
#' file_table <- rm_file_clusdf(file_table, file_table[1, ])
#' }
#'
#' @export
rm_file_clusdf <- function(df, rm_vec) {
  #df <- df[df %!in% rm_vec]
  if(!is.atomic(df)){
    df <- df[-which(df$name %in% rm_vec$name), ]
  } else {
    df <- NULL
  }
  return(df)
}

#' Add Enrichment Result to Top Term Heatmap Table
#'
#' Adds or updates an enrichment result in the top term heatmap tracking table.
#' If the result already exists, it replaces the existing entry.
#'
#' @param df Existing heatmap tracking dataframe (or NULL for new table)
#' @param name Name identifier for the enrichment result
#' @param value_type Value type to use (Padj or Pvalue)
#' @param value_cutoff P-value cutoff for filtering terms
#' @param top_nterms Number of top terms to display
#'
#' @return Updated heatmap tracking dataframe with columns: name, value_type, value_cutoff, top_nterms
#'   Replaces existing entry if name already present
#'
#' @examples
#' \dontrun{
#' hmap_table <- add_rr_tophmap(NULL, "go1", "Padj", 0.05, 10)
#' }
#'
#' @export
add_rr_tophmap <- function(df, name, value_type, value_cutoff, top_nterms) {
  new_rr_vec <- c(name=name, value_type=value_type, value_cutoff=value_cutoff, top_nterms=top_nterms)
  # If df is null OR is atomic and name already present, replace entire df
  if (is.null(df) || is.atomic(df) && name %in% df) {
    df <- new_rr_vec
    df <- base::t(df)
    df <- as.data.frame(df)
    rownames(df) <- NULL
    return(df)
  }
  # If name already present in df, replace that row with new_rr_vec
  else if (name %in% df$name) {
    df[which(df$name %in% name), ] <- new_rr_vec
    return(df)
  }
  # Else, just rbind
  else {
    df <- rbind(df, new_rr_vec)
    names(df) <- c("name", "value_type", "value_cutoff", "top_nterms")
    rownames(df) <- NULL
    return(df)
  }
}



