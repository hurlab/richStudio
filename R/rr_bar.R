# Function to create bar plot from enrichment result

# example
# x <- read.delim("data/try-this/GO_HF12wk_vs_WT12wk.txt")
# y <- read.delim("data/try-this/GO_WT36wk_vs_WT12wk.txt")
# xylist <- list(x, y)

# testnetmap <- ggnetwork(x, gene=x$GeneID)
# ggtestnetmap <- ggplotly(testnetmap)

# ggdot <- ggdot(x)


# x: rich result dataframe
rr_bar <- function(x, top=25, pvalue=0.05, value_type="Padj", view="rich") {
  
  x <- filter(x, x[, value_type]<pvalue)
  x <- arrange(x, value_type) # order by ascending padj/pval
  
  if (nrow(x) >= top) {
    x <- x[1:top, ]
  }
  
  # rename padj/pval col to "final_value"
  suppressWarnings({
    x <- dplyr::rename(x, final_value = any_of(value_type), value_type)
  })
  
  x$final_value <- -log10(as.numeric(x$final_value))
  x$final_value <- round(x$final_value, 4)
  
  x$rich <- as.numeric(x$Significant)/as.numeric(x$Annotated)
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
  }
  return(p)
  
}