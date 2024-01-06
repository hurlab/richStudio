# devtools::install_github("guokai8/richR")
# library(richR)
# 
# 
# hsaro <- buildAnnot(species="human", keytype="SYMBOL", anntype="Reactome")
# hsakm <- buildAnnot(species="human", keytype="SYMBOL", anntype="KEGGM")
# 
# hsako <- buildAnnot(species="human", keytype="SYMBOL", anntype="KEGG")
# geneko1 <- sample(unique(hsako$GeneID),1000)
# geneko2 <- sample(unique(hsako$GeneID),1000)
# 
# resko1 <- richKEGG(geneko1, hsako)
# resko2 <- richKEGG(geneko2, hsako)
# reskobar <- ggbar(resko1)
# compare_res <- compareResult(list(S1=resko1,S2=resko2))
# 
# 
# hsago <- buildAnnot(species="human", keytype="SYMBOL", anntype="GO")
# genego1 <- sample(unique(hsago$GeneID),1000)
# genego2 <- sample(unique(hsago$GeneID),1000)
# 
# deg <- c("SOD1", "SOD2", "SOD3", "CAT")
# 
# resgo1 <- enrich(deg, hsago)
# resro <- enrich(deg, hsaro)
# 
# 
# res.hsako.ori <- richKEGG(deg, hsako)
# 
# res.lst <- list(res.hsaro, res.hsago, res.hsakm, res.hsako, res.hsago.ori, res.hsako.ori)
# result_list <- list(res.hsako, res.hsago)
# lapply(res.lst, function(x) nrow(x))
# 
# dot_compare <- comparedot(compareResult((result_list), top=10))