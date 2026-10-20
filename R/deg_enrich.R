# Function to enrich DEG sets


# deg2 <- read.delim('/Users/sarahhong/Desktop/Hur Lab/enrichment-analysis/data/degs/HF_12wk_SCN_vs_WT_12wk_SCN_DE_12_19.txt')

## build Annotation package
# fromKEGG(species="hsa")  # from KEGG
# fromAnnHub(species="human")  # from AnnotationHub

# x: deg to analyze
# header: name of vector in question
shiny_enrich <- function(x, header, species, anntype, keytype, ontology,
                         annotation_builder = richR::buildAnnot) {
  header <- grep(header, colnames(x), ignore.case=TRUE, value=TRUE) # grab case-insensitive header
  if (length(header) == 0) {
    stop("Gene identifier column was not found.", call. = FALSE)
  }
  x <- as.character(x[[header[1]]])
  x <- x[!is.na(x) & nzchar(trimws(x))]
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
    x_use <- inp$df
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
    if (nrow(x_use) == 0) {
      stop("No query genes remain after input filtering for '", inp$name, "'.", call. = FALSE)
    }

    enriched <- shiny_enrich(
      x = x_use, header = inp$gene_header, species = species,
      anntype = anntype, keytype = keytype, ontology = ontology,
      annotation_builder = annotation_builder
    )
    results[[i]] <- list(
      name = inp$name,
      result = enriched@result,
      anntype = anntype,
      keytype = keytype,
      ontology = ontology,
      species = species
    )
  }
  results
}

# deg2_test <- shiny_enrich(deg2, 'geneID', 'mouse',  "GO", "SYMBOL", "BP")
# no need to support david/msigdb at moment
