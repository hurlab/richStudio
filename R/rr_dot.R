# Function to create dot plot from enrichment result


# x: rich result dataframe
rr_dot <- function(x, top=30, value_cutoff=0.05, value_type="Padj") {
  
  x <- filter(x, x[, value_type]<value_cutoff) 
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
  
}

