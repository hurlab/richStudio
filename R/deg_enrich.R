# Function to enrich DEG sets


# deg2 <- read.delim('/Users/sarahhong/Desktop/Hur Lab/enrichment-analysis/data/degs/HF_12wk_SCN_vs_WT_12wk_SCN_DE_12_19.txt')

## build Annotation package
# fromKEGG(species="hsa")  # from KEGG
# fromAnnHub(species="human")  # from AnnotationHub

# Gene identifier column: the exact header name first, then the first
# case-insensitive pattern match (the legacy rule). NA when nothing matches.
query_gene_column <- function(x, header) {
  if (length(header) != 1L || is.na(header) || !nzchar(header)) return(NA_character_)
  header <- as.character(header)
  columns <- colnames(x)
  if (header %in% columns) return(header)
  matches <- tryCatch(grep(header, columns, ignore.case = TRUE, value = TRUE),
                      error = function(e) character())
  if (length(matches)) matches[[1]] else NA_character_
}

# Query identifiers exactly as submitted: the gene column's values without NA or
# blank entries, in source order, case unchanged, not deduplicated.
query_gene_ids <- function(x, header) {
  column <- query_gene_column(x, header)
  if (is.na(column)) {
    stop("Gene identifier column was not found.", call. = FALSE)
  }
  ids <- as.character(x[[column]])
  ids[!is.na(ids) & nzchar(trimws(ids))]
}

# x: deg to analyze
# header: name of vector in question
shiny_enrich <- function(x, header, species, anntype, keytype, ontology,
                         annotation_builder = richR::buildAnnot) {
  x <- query_gene_ids(x, header)
  if (length(x) == 0) {
    stop("No query genes remain after input filtering.", call. = FALSE)
  }
  annot_data <- annotation_builder(species=species, keytype=keytype, anntype=anntype)

  if (anntype == "GO") {
    return(richR::richGO(x=x, godata=annot_data, ontology=ontology))
  } else if (anntype == "KEGG") {
    return(richR::richKEGG(x=x, kodata=annot_data, ontology=ontology))
  } else {
    return(richR::enrich(x=x, object=annot_data))
  }
}

# Run the app's enrichment worker synchronously so its input and result handling
# can be exercised with deterministic annotation fixtures. The Shiny observer
# calls this function inside its existing future.
run_enrichment_jobs <- function(deg_inputs, cutoff, species, anntype, keytype,
                                ontology, annotation_builder = richR::buildAnnot) {
  results <- vector("list", length(deg_inputs))
  for (i in seq_along(deg_inputs)) {
    inp <- deg_inputs[[i]]
    rule <- inp$query_rule
    x_use <- inp$df
    if (!is.null(rule)) {
      # A reviewed rule is authoritative: its own column and cutoff, never `cutoff`.
      if (!identical(rule$role, "none")) {
        p <- x_use[[rule$column]]
        x_use <- x_use[!is.na(p) & p < rule$cutoff, , drop = FALSE]
      }
      header <- rule$gene_col
    } else {
      col_lower <- tolower(colnames(x_use))
      padj_idx <- which(col_lower == "padj")
      pval_idx <- which(col_lower == "pvalue")
      if (length(padj_idx) > 0) {
        padj_col <- colnames(x_use)[padj_idx[1]]
        x_use <- x_use[!is.na(x_use[[padj_col]]) & x_use[[padj_col]] < cutoff, , drop = FALSE]
      } else if (length(pval_idx) > 0) {
        pval_col <- colnames(x_use)[pval_idx[1]]
        x_use <- x_use[!is.na(x_use[[pval_col]]) & x_use[[pval_col]] < cutoff, , drop = FALSE]
      }
      header <- inp$gene_header
    }
    if (nrow(x_use) == 0) {
      stop("No query genes remain after input filtering for '", inp$name, "'.", call. = FALSE)
    }
    if (!is.null(rule) && !identical(query_gene_ids(x_use, header), as.character(inp$ids))) {
      stop("Submitted genes differ from the reviewed snapshot for ", inp$name, call. = FALSE)
    }

    enriched <- shiny_enrich(
      x = x_use, header = header, species = species,
      anntype = anntype, keytype = keytype, ontology = ontology,
      annotation_builder = annotation_builder
    )
    result <- list(
      name = inp$name,
      result = enriched@result,
      anntype = anntype,
      keytype = keytype,
      ontology = ontology,
      species = species
    )
    if (!is.null(rule)) {
      result$query_rule <- rule
      result$n_submitted <- length(inp$ids)
      result$revision_digest <- inp$revision_digest
    }
    results[[i]] <- result
  }
  results
}

# deg2_test <- shiny_enrich(deg2, 'geneID', 'mouse',  "GO", "SYMBOL", "BP")
# no need to support david/msigdb at moment
