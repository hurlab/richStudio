#' Create a network plot from enrichment results
#'
#' Thin wrapper around \code{ggnetwork} that generates a gene-concept network
#' from enrichment results. Optionally accepts a DEG data frame for gene-level
#' annotation.
#'
#' This function follows the \code{rr_} naming convention used across richStudio
#' plot functions, where \code{rr} stands for "rich result" (enrichment result).
#' The name is referenced by Shiny UI modules and must not be renamed without
#' updating all call sites.
#'
#' @param rr An enrichment result object compatible with \code{ggnetwork}.
#' @param deg Optional. A DEG data frame or gene vector. When \code{NULL},
#'   gene IDs are taken from \code{rr$GeneID}.
#' @return A ggplot network object.
rr_network <- function(rr, deg=NULL) {
  if (is.null(deg)) {
    return(ggnetwork(object=rr, gene=rr$GeneID))
  } else {
    return(ggnetwork(object=rr, gene=deg))
  }
  
}

#' Compute a weighted term-term similarity network (WIP)
#'
#' Custom implementation of a gene-overlap-based network for enrichment terms.
#' Computes pairwise term similarity weights based on shared genes and their
#' significance. Returns the weight matrix and filtered enrichment data.
#'
#' Note: This function uses \code{my_} prefix as an informal convention
#' for work-in-progress internal helpers. It does not follow the \code{rr_}
#' prefix convention used by the main exported plot functions.
#'
#' @param x A data frame of enrichment results containing columns: Term,
#'   GeneID, Significant, and the column specified by \code{value_type}.
#' @param gene A DEG data frame (with \code{padj} column and gene row names)
#'   or a character vector of gene identifiers.
#' @param top Integer. Maximum number of top terms to include. Default 50.
#' @param value_cutoff Numeric. P-value cutoff for filtering. Default 0.05.
#' @param value_type Character. Column name for significance values.
#'   Default \code{"Padj"}.
#' @param weight_cutoff Numeric. Minimum weight threshold (currently unused
#'   inside this function but reserved for downstream filtering). Default 0.2.
#' @param sep Character. Separator for gene IDs in the GeneID column.
#'   Default \code{","}.
#' @return A list with components: \code{w} (numeric matrix of pairwise
#'   weights), \code{value_col} (named numeric vector of -log10 values),
#'   and \code{x} (filtered enrichment data frame).
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
  n <- nrow(x)
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
  names(value_col) <- x$Term
  rownames(x) <- x$Term

  return(list(w = w, value_col = value_col, x = x))
}


# net1 <- ggnetwork(deg1_enriched, weightcut=.2)
# net2 <- ggnetwork(deg1_enriched, weightcut=.5)