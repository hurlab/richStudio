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