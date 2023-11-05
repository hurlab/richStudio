# Code from Dr. Junguk Hur


library(dplyr)
library(stringdist)

expand_dictionary_terms <- function(terms) {
  variations <- list(
    function(x) gsub("-", " ", x),    # Replace '-' with ' '
    function(x) gsub("-", ".", x),    # Replace '-' with '.'
    function(x) gsub(" ", ".", x),    # Replace ' ' with '.'
	function(x) gsub(" ", "", x),     # Replace ' ' with '.'
    function(x) gsub("\\.", " ", x),  # Replace '.' with ' '
    function(x) gsub("\\.", "-", x),  # Replace '.' with '-'
    function(x) gsub("-", "_", x)     # Replace '-' with '_'
  )
  expanded <- lapply(terms, function(term) {
    variants <- lapply(variations, function(f) f(term))
    unique(c(term, variants))
  })
  
  unlist(expanded)
}

expand_dictionary <- function(dictionary) {
  lapply(dictionary, expand_dictionary_terms)
}

# Sample dictionary
col_dictionary <- list(
  ID = c("ID", "identifier", "pathway ID", "identity"),
  Term = c("Term", "name", "description", "pathway"),
  Pvalue = c("Pvalue", "P-value", "Nominal p-value"),
  Padj = c("Padj", "P-adjusted", "Adjusted p-value", "Corrected", "Corrected Pvaue", "Benjamini-Hochberg", "BH corrected p-value", "BH Pvalaue", "FDR", "False Discovery Rate", "Q-value"),
  GeneID = c("GeneID", "gene list")
)

# Expand the dictionary
expanded_col_dictionary <- expand_dictionary(col_dictionary)
# expanded_col_dictionary


best_match <- function(target, candidates) {
  distances <- stringdist::stringdistmatrix(target, candidates)
  best_candidate <- candidates[which.min(distances[, 1])]
  return(best_candidate)
}

select_required_columns <- function(df) {
  
  matched_columns <- sapply(names(expanded_col_dictionary), function(required) {
    potential_matches <- expanded_col_dictionary[[required]]
    found_cols <- base::intersect(names(df), potential_matches)
    
    if (length(found_cols) == 1) {
      return(found_cols)
    } else if (length(found_cols) > 1) {
      return(best_match(required, found_cols))
    } else {
      # If no exact match is found, use partial matching
      best_candidate <- best_match(required, names(df))
      if (min(stringdist::stringdistmatrix(required, best_candidate)) <= 4) {
        return(best_candidate)  # Only allow matches with a small distance
      } else {
        return(NA)
      }
    }
  }, USE.NAMES = TRUE)
  
  # Subset the dataframe based on matched columns
  df_selected <- df %>%
    dplyr::select(all_of(matched_columns[!is.na(matched_columns)]))
  
  # Add columns that couldn't be matched as empty columns
  for(col in names(matched_columns)[is.na(matched_columns)]) {
    df_selected[[col]] <- NA
  }
  
  # Identify the correct standard names for the matched columns
  # Replace the matched columns in df_selected with their correct standard names
  correct_names <- names(matched_columns)
  df_selected <- df[, unlist(matched_columns, use.names = FALSE)]
  names(df_selected) <- correct_names
  
  return(df_selected)
}


# Example
# user_df <- data.frame(name = letters[1:5], Pvalue = runif(5),
#                       `Q-value` = runif(5), `gene list` = paste(sample(letters, 5), collapse = ","))
# user_df2 <-  data.frame(`geneID` = paste(sample(letters, 5), collapse = ","), baseMean=runif(5),
#                         log2FoldChange=runif(5), lfcSE=runif(5), stat=runif(5), pvalue=runif(5), padj=runif(5))
# 
# result_df <- select_required_columns(user_df)
# result_df_bad <- select_required_columns(user_df2) # why?
# 
# print(result_df)
