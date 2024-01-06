# Functions to create uploaded file dataframe

# df <- data.frame() # for testing
# new_df <- read.delim("data/degs/HF_12wk_DRG_vs_WT_12wk_DRG_DE_12_19.txt")
# name <- "HF_12wk_DRG_vs_WT_12wk_DRG_DE_12_19.txt"
# df <- add_file_degdf(df, name, new_df)

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
  
  # If one GeneID column matched
  if (length(geneIDmatches) == 1) {
    geneIDcol <-  names(new_df[geneIDmatches])
    num_genes <- length(new_df[, geneIDcol]) # Count # genes
    
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
    return(df) # Return appended df on success
  } else {
    return(geneIDmatches) # Return list of possible geneID col matches if multiple/none
  }
}

rm_file_degdf <- function(df, rm_vec) {
  #df <- df[df %!in% rm_vec]
  if(!is.atomic(df)){
    df <- df[-which(df$name %in% rm_vec$name), ]
  } else {
    df <- NULL
  }
  return(df)
}

# Add enrichment result to rr_list
# @param file: Whether rr to append comes from a file or from RichStudio enrichment
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

rm_file_rrdf <- function(df, rm_vec) {
  #df <- df[df %!in% rm_vec]
  if(!is.atomic(df)){
    df <- df[-which(df$name %in% rm_vec$name), ]
  } else {
    df <- NULL
  }
  return(df)
}


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

rm_file_clusdf <- function(df, rm_vec) {
  #df <- df[df %!in% rm_vec]
  if(!is.atomic(df)){
    df <- df[-which(df$name %in% rm_vec$name), ]
  } else {
    df <- NULL
  }
  return(df)
}


# Add rr to top term hmap table
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



