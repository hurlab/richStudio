# Function to enrich DEG sets


# deg2 <- read.delim('/Users/sarahhong/Desktop/Hur Lab/enrichment-analysis/data/degs/HF_12wk_SCN_vs_WT_12wk_SCN_DE_12_19.txt')

## build Annotation package
# fromKEGG(species="hsa")  # from KEGG
# fromAnnHub(species="human")  # from AnnotationHub

# x: deg to analyze
# header: name of vector in question
shiny_enrich <- function(x, header, species, anntype, keytype, ontology) {
  header <- grep(header, colnames(x), ignore.case=TRUE, value=TRUE) # grab case-insensitive header
  x <- x[, header]
  x <- as.character(x)
  annot_data <- buildAnnot(species=species, keytype=keytype, anntype=anntype)
  
  if (anntype == "GO") {
    return(richGO(x=x, godata=annot_data, ontology=ontology))
  } else if (anntype == "KEGG") {
    return(richKEGG(x=x, kodata=annot_data, ontology=ontology))
  } else {
    return(enrich(x=x, annot=annot_data))
  }
  
}

# deg2_test <- shiny_enrich(deg2, 'geneID', 'mouse',  "GO", "SYMBOL", "BP")
# no need to support david/msigdb at moment
