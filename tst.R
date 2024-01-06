# Testing filtering deg set so padj < .1

# deg <- read.delim("data/degs/HF_12wk_DRG_vs_WT_12wk_DRG_DE_12_19.txt")
# deg <- dplyr::filter(deg, padj < .1)
# write.table(deg, "data/degs/filtered/HF_12wk_DRG_vs_WT_12wk_DRG_DE_12_19.txt", sep="\t", row.names = FALSE)
# 
# deg2 <- read.delim("data/degs/HF_36wk_SCN_vs_WT_36wk_SCN_DE_12_19.txt")
# deg2 <- dplyr::filter(deg2, padj < .1)
# write.table(deg2, "data/degs/filtered/HF_36wk_SCN_vs_WT_36wk_SCN_DE_12_19.txt", sep="\t", row.names = FALSE)
# 
# deg3 <- read.delim("data/degs/WT_36wk_SCN_vs_WT_12wk_SCN_DE_12_19.txt")
# deg3 <- dplyr::filter(deg3, padj < .1)
# write.table(deg3, "data/degs/filtered/WT_36wk_SCN_vs_WT_12wk_SCN_DE_12_19.txt", sep="\t", row.names = FALSE)
# 
# 
# dim(deg)