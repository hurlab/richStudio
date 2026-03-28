#' Create a dot plot from enrichment results
#'
#' Generates an interactive dot plot (via plotly) from a functional enrichment
#' result dataframe. Dot size encodes the number of significant genes and
#' color encodes the -log10 transformed significance value.
#'
#' This function follows the \code{rr_} naming convention used across richStudio
#' plot functions, where \code{rr} stands for "rich result" (enrichment result).
#' The name is referenced by Shiny UI modules and must not be renamed without
#' updating all call sites.
#'
#' @param x A data frame of enrichment results containing columns: Term,
#'   Significant, Annotated, and the column specified by \code{value_type}.
#' @param top Integer. Maximum number of top terms to display. Default 30.
#' @param value_cutoff Numeric. P-value cutoff for filtering terms.
#'   Default 0.05.
#' @param value_type Character. Column name for significance values, typically
#'   \code{"Padj"} or \code{"Pvalue"}. Default \code{"Padj"}.
#' @return A plotly scatter plot object.
rr_dot <- function(x, top=30, value_cutoff=0.05, value_type="Padj") {
  
  x <- filter(x, x[, value_type]<value_cutoff) 
  x <- arrange(x, value_type) # order by ascending padj/pval
  
  if (nrow(x) >= top) {
    x <- x[1:top, ]
  }
  
  # rename padj/pval col to "final_value"
  suppressWarnings({
    x <- dplyr::rename(x, final_value = any_of(value_type))
  })
  
  x$final_value <- -log10(as.numeric(x$final_value))
  x$final_value <- round(x$final_value, 4)
  
  annotated <- as.numeric(x$Annotated)
  annotated[annotated == 0] <- NA
  x$rich <- as.numeric(x$Significant) / annotated
  x$rich <- round(x$rich, 4)
  
  x$Term <- factor(x$Term,levels=x$Term[order(x$final_value)])
  
  p <- plot_ly(
    data = x,
    x = ~rich,
    y = ~Term,
    type = 'scatter',
    mode = 'markers',
    marker = list(
      size = ~Significant, 
      sizeref = 2.*max(x$Significant)/(8.**2),
      sizemin = 4,
      color = ~final_value, 
      colorbar = list(title = paste0("-log10(", value_type, ")"))
    ),
    text = ~paste0(Term, "<br>", "-log10(", value_type, "): ", final_value, "<br>", "Gene number: ", Significant),  # Customize hover text
    hoverinfo = "text"
  ) %>% 
    layout (
      title = paste0("-log10(", value_type, ") for Enriched Terms"),
      xaxis = list(title = "Rich Score"),
      yaxis = list(title = "Term", categoryorder = "trace", tickmode = "linear", nticks = top)
    )

  return(p)
}

