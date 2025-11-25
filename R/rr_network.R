
# Test
# deg1 <- read.delim("data/degs/HF_12wk_DRG_vs_WT_12wk_DRG_DE_12_19.txt")
# deg1_enriched <- shiny_enrich(deg1, 'geneID', 'mouse',  "GO", "SYMBOL", "BP")
# net <- ggnetwork(deg1_enriched, deg1)
# plotly_net <- ggplotly(net)
# print(plotly_net)

rr_network <- function(rr, deg=NULL) {
  if (is.null(deg)) {
    return(ggnetwork(object=rr, gene=rr$GeneID))
  } else {
    return(ggnetwork(object=rr, gene=deg))
  }
  
}

# My implementation of Kai's network script (WIP)
my_net <- function (x, gene, top=50, value_cutoff=.05, value_type='Padj', 
                    weight_cutoff=.2, sep=',') {
  
  x <- filter(x, x[, value_type]<value_cutoff) 
  x <- arrange(x, value_type) # order by ascending padj/pval
  
  # Filter out top terms
  if (nrow(x) > top) {
    x <- x[1:top, ]
  }
  
  # Get gene pvalues if dataframe supplied
  if (is.data.frame(gene)) {
    gene_p <- -log10(gene$padj)
    names(gene_p) <- rownames(gene)
  } else {
    gene_p <- rep(1, length(gene))
    names(gene_p) <- gene
  }
  value_col <- -log10(x[, value_type])
  names(value_col) <- rownames(x)
  
  go2gen <- strsplit(x = as.vector(x$GeneID), split = sep)
  names(go2gen) <- rownames(x)
  gen2go <- reverseList(go2gen)
  golen <- x$Significant
  names(golen) <- rownames(x)
  gen2golen <- lapply(gen2go, function(x) golen[x])
  gen2gosum <- lapply(gen2golen, function(x) sum(x)/x)
  gen2res <- lapply(gen2gosum, function(x) x/sum(x))
  id <- rownames(x)
  n = nrow(x)
  w <- matrix(NA, nrow = n, ncol = n)
  colnames(w) <- rownames(w) <- rownames(x)
  for (i in 1:n) {
    ni <- id[i]
    for (j in i:n) {
      nj <- id[j]
      genein = intersect(go2gen[[ni]], go2gen[[nj]])
      geneup <- sum(gene_p[genein] * unlist(lapply(lapply(gen2res[genein],
                                                          "[", c(ni, nj)), sum)))
      genei <- setdiff(go2gen[[ni]], go2gen[[nj]])
      genej <- setdiff(go2gen[[nj]], go2gen[[ni]])
      geneid <- sum(gene_p[genei] * unlist(lapply(lapply(gen2res[genei],
                                                         "[", ni), sum)))
      genejd <- sum(gene_p[genej] * unlist(lapply(lapply(gen2res[genej],
                                                         "[", nj), sum)))
      gened <- geneup + geneid + genejd
      w[i, j] <- geneup/gened
    }
  }
  colnames(w) <- rownames(w) <- x$Term
  names(value_col) = x$Term
  rownames(x)<-x$Term
}


# net1 <- ggnetwork(deg1_enriched, weightcut=.2)
# net2 <- ggnetwork(deg1_enriched, weightcut=.5)