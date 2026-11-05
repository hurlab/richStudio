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
rr_dot <- function(x, top = 30, value_cutoff = 0.05, value_type = "Padj") {
  x <- filter(x, x[, value_type] < value_cutoff)
  x <- arrange(x, .data[[value_type]]) # order by ascending padj/pval

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

  x$Term <- factor(x$Term, levels = x$Term[order(x$final_value)])

  sizeref <- 2. * max(x$Significant) / (8.**2)
  value_name <- paste0("-log10(", value_type, ")")
  plot_height <- rr_term_plot_height(nrow(x))
  p <- plot_ly(
    data = x,
    height = plot_height,
    x = ~rich,
    y = ~Term,
    type = "scatter",
    mode = "markers",
    showlegend = FALSE,
    marker = list(
      size = ~Significant,
      sizeref = sizeref,
      sizemin = 4,
      color = ~final_value,
      colorbar = list(title = paste0("Colour: ", value_name))
    ),
    text = ~ paste0(
      Term,
      "<br>",
      "-log10(",
      value_type,
      "): ",
      final_value,
      "<br>",
      "Gene number: ",
      Significant
    ), # Customize hover text
    hoverinfo = "text"
  )
  p <- p %>%
    layout(
      title = paste0(
        "Enriched terms: rich score, dot size = gene number, colour = ",
        value_name
      ),
      xaxis = list(title = "Rich score (significant genes / annotated genes)"),
      yaxis = rr_term_axis(levels(x$Term)),
      margin = list(b = 110, l = 80),
      annotations = list(list(
        text = paste0(
          "Size legend: dot size = number of significant genes (",
          min(x$Significant, na.rm = TRUE),
          " to ",
          max(x$Significant, na.rm = TRUE),
          " genes)"
        ),
        x = 0,
        y = -0.24,
        xref = "paper",
        yref = "paper",
        xanchor = "left",
        yanchor = "top",
        showarrow = FALSE,
        font = list(size = 12)
      ))
    )

  rr_apply_plot_height(p, plot_height)
}
