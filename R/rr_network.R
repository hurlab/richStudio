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
#'   gene IDs are the union of the comma-separated genes of all terms in
#'   \code{rr$GeneID}.
#' @return A ggplot network object.
rr_network <- function(rr, deg=NULL) {
  if (is.null(deg)) {
    if (!"GeneID" %in% colnames(rr)) {
      stop("rr must contain a GeneID column when deg is NULL")
    }
    # GeneID holds one comma-joined string per term; ggnetwork needs the genes
    deg <- trimws(unlist(strsplit(as.character(rr$GeneID), ",", fixed=TRUE)))
    deg <- unique(deg[!is.na(deg) & nzchar(deg)])
  }
  return(ggnetwork(object=rr, gene=deg))
}
