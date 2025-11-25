# Tests to compare DAVID clustering to mine

test_david <- function() {
  library(dplyr)
  library(richR)
  
  ## build Annotation package
  # fromKEGG(species="hsa")  # from KEGG
  # fromAnnHub(species="mouse")  # from AnnotationHub
  
  annot_data <- buildAnnot(species="mouse", "SYMBOL", "GO")
  annot_data_df <- annot_data@annot
  write.csv(annot_data_df, "/Users/sarah/Desktop/hurlab/data/richRannot.csv")
  richr_annot <- read.csv("/Users/sarah/Desktop/hurlab/data/richRannot.csv")
  david_annot <- read.table('/Users/sarah/Desktop/hurlab/data/DAVIDKnowledgebase/OFFICIAL_GENE_SYMBOL2GOTERM_BP_DIRECT.txt', sep='\t')
  deg <- read.delim('/Users/sarah/Desktop/hurlab/data/degs/HF_12wk_SCN_vs_WT_12wk_SCN_DE_12_19.txt')
  
  deg <- filter(deg, padj<0.05)
  deg_genes <- deg$geneID
  
  richr_enrich <- richGO(x=deg_genes, godata=richr_annot, ontology="BP")
}
