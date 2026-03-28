#' Create a bar plot from enrichment results
#'
#' Generates an interactive bar plot (via plotly) from a functional enrichment
#' result dataframe. Can display either rich scores or -log10 transformed
#' p-values for the top enriched terms.
#'
#' This function follows the \code{rr_} naming convention used across richStudio
#' plot functions, where \code{rr} stands for "rich result" (enrichment result).
#' The name is referenced by Shiny UI modules and must not be renamed without
#' updating all call sites.
#'
#' @param x A data frame of enrichment results containing columns: Term,
#'   Significant, Annotated, and the column specified by \code{value_type}.
#' @param top Integer. Maximum number of top terms to display. Default 25.
#' @param pvalue Numeric. P-value cutoff for filtering terms. Default 0.05.
#' @param value_type Character. Column name for significance values, typically
#'   \code{"Padj"} or \code{"Pvalue"}. Default \code{"Padj"}.
#' @param view Character. Plot view mode: \code{"rich"} for rich score or
#'   \code{"value"} for -log10 transformed significance values. Default
#'   \code{"rich"}.
#' @return A plotly bar plot object.
rr_bar <- function(x, top=25, pvalue=0.05, value_type="Padj", view="rich") {
  
  x <- filter(x, x[, value_type]<pvalue)
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

  # view rich score
  if (view == "rich") {
    p <- plot_ly(
      data = x, 
      x = ~rich,
      y = ~Term,
      type = 'bar',
      text = ~rich,
      hoverinfo = ~paste0(Term, "<br>", "Rich score: ", rich)
    ) %>%
      layout(
        title = "Rich Score for Enriched Terms",
        xaxis = list(title = "Rich Score"),
        yaxis = list(title = "Term", categoryorder = "trace", nticks = top)
      )
  }
  # view -log10(value_type)
  else if (view == "value") {
    p <- plot_ly(
      data = x, 
      x = ~final_value,
      y = ~Term,
      type = 'bar',
      text = ~final_value
    ) %>%
      layout(
        title = paste0("-log10(", value_type, ") for Enriched Terms"),
        xaxis = list(title = paste0("-log10(", value_type, ")")),
        yaxis = list(title = "Term", categoryorder = "trace", nticks = top)
      )
  } else {
    stop("Invalid view parameter: '", view, "'. Must be 'rich' or 'value'.")
  }
  return(p)

}