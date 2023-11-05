# 
# # Toy example for heatmaply with explicit column display
# library(heatmaply)
# 
# # Define input data
# df <- data.frame(
#   "col1"=c(1, 45, 6, 23, 4, 77, 8, 10, 28),
#   "col2"=c(5, 35, 6, 99, 2, 13, 4, 65, 8),
#   "col3"=c(5, 45, 2, 44, 44, 44, 2, 10, 28),
#   "col4"=c(1, 4, 6, 3, 4, 99, 28, 11, 30),
#   "col5"=c(7, 35, 2, 3, 3, 90, 32, 13, 8),
#   "col6"=c(1, 4, 6, 2, 4, 7, 8, 10, 28),
#   "cluster"=c(2, 4, 4, 5, 5, 6, 1, 3, 3) # this column defines which cluster a row belongs to
# )
# 
# hm <- heatmaply(
#   df[, setdiff(colnames(df), "cluster")], # pass data except cluster column
#   row_side_colors=data.frame("cluster"=df$cluster, check.names=FALSE), # Set row_side_colors to the cluster column. Need to pass as a named data frame, otherwise the column gets named to "row_side_columns"
#   cellnote=df, # Specify cellnote to show values as text in cells (can disable if you don't want this)
#   plot_method="plotly" # If you don't do this, the cluster names doesn't work properly for some reason
# )
# 
# print(hm)

# My own data
# clusty_annot <- melted_chmap_data %>%
#   distinct(Cluster, Term) %>%
#   arrange(Cluster)
# 
# clusty <- cluster_hmap[, !(colnames(cluster_hmap) %in% c("Cluster", "Term"))]
# clusty <- apply(clusty, c(1, 2), function(x) -log10(x))
# #clusty <- apply(clusty, 2, function(x) replace_na(x, 0))
# rownames(clusty) <- clusty_annot$Term
# 
# my_hm <- heatmaply(
#   clusty, 
#   row_side_colors=data.frame("Cluster"=clusty_annot$Cluster, check.names=FALSE),
#   cellnote=clusty,
#   plot_method='plotly',
#   cluster_rows=FALSE, cluster_cols=FALSE,
#   Rowv=FALSE,
#   Colv=FALSE,
#   main=paste0("-log10(", value_type, ") by Term")
# )
# 
# print(my_hm)




# Testing ComplexHeatmap for cluster row annotations

# library(ComplexHeatmap)
# library(InteractiveComplexHeatmap)
# 
# clusty_annot <- melted_chmap_data %>%
#   distinct(Cluster, Term) %>%
#   arrange(Cluster)
# 
# clusty <- cluster_hmap[, !(colnames(cluster_hmap) %in% c("Cluster", "Term"))]
# clusty <- apply(clusty, c(1, 2), function(x) -log10(x))
# clusty <- apply(clusty, 2, function(x) replace_na(x, 0))
# 
# 
# col_fun <- colorRamp2(c(0, max(melted_chmap_data$value, na.rm=TRUE)), c("white", "purple"))
# #col_fun(seq(-3, 3))
# 
# rownames(clusty) <- cluster_hmap$Term
# la <- ComplexHeatmap::rowAnnotation(Cluster=clusty_annot$Cluster, name="Cluster", show_annotation_name=TRUE)
# ch <- ComplexHeatmap::Heatmap(as.matrix(clusty), name="Test", col=col_fun, cluster_rows=FALSE,
#                               cluster_columns=FALSE, left_annotation=la)
# 
# ch <- draw(ch)
# htShiny(ch)



# ignore from here on...
# diff_la = rowAnnotation(Cluster=anno_empty(border = FALSE, 
#                                       width =  unit(60, "mm")))
# diff_ch <- ComplexHeatmap::Heatmap(as.matrix(clusty), name="Test", col=col_fun, cluster_rows=FALSE, 
#                                          cluster_columns=FALSE, left_annotation=diff_la)
# for(i in 1:length(clusty_annot$Cluster)) {
#   decorate_annotation("Cluster", slice = i, {
#     grid.rect(x = 0, width = unit(2, "mm"), gp = gpar(fill = i, col = NA), just = "left")
#     grid.text(paste(clusty_annot$Cluster[i], collapse = "\n"), x = unit(4, "mm"), just = "left")
#   })
# }



# Trying to get cluster annotation...
# g <- ggplot(melted_chmap_data, 
#             aes(x=variable, y=Term, fill=value)) +
#   geom_tile() + 
#   labs(title=paste0("-log10(", value_type, ") by Term"),
#        x="Geneset",
#        y="Term",
#        fill=paste0("-log10(", value_type, ")"))
# g2 <- ggplot(melted_chmap_data, 
#              aes(x=1, y=Term, fill=Cluster)) +
#   geom_tile() + 
#   labs(x="", y="Cluster", fill="Cluster") +
#   theme(axis.text.x = element_blank(), axis.text.y = element_blank())
# g_final <- plot_grid(
#   g2, g,
#   ncol=2,
#   align = "hv"
#   #rel_widths = c(1, 1)
# )
# layout <- c(
#   area(t=1, l=1, b=4, r=10),
#   area(t=1, l=10, b=4, r=11)
# )
# g + g2 + plot_layout(design=layout) +
#   plot_annotation(title = paste0("-log10(", value_type, ") by Term"), 
#                   theme = theme(plot.title = element_text(hjust = 0.5))) +  
#   plot_layout(guides = "collect")
# 
#