# Functions to round off decimal places in dataframe tables
library(knitr)


# n_dec <- function(x) {
#   x <- unlist(strsplit(as.character(x), "\\."))
#   x <- unlist(strsplit(x[2], ""))
#   count <- 0
#   for (i in seq_along(x)) {
#     count <- count+1
#   }
#   return(count)
# }

format_cells <- function(x, n) {
  if (abs(x) < 1e-5 || abs(x) > 1e+5) {
    #return(format(x, scientific=TRUE, digits=n))
    return(sprintf(paste0("%.", n, "e"), x))
  } else {
    # tmp <- signif(as.numeric(x), digits=n)
    # n <- n_dec(tmp)
    # return(format(x, scientific=FALSE, digits=n))
    #return(format(signif(x, digits=n), scientific=FALSE))
    return(signif(x, digits=n))
    #return(as.numeric(sprintf(paste0("%.", n, "f"), as.numeric(x))))
  }
}

round_tbl <- function(df, n) {
  for (i in 1:nrow(df)) {
    for (j in 1:ncol(df)) {
      suppressWarnings({
        if ( !is.na(df[i, j]) && !is.na(as.numeric(df[i, j])) ) {
          df[i, j] <- as.character(format_cells(as.numeric(df[i, j]), n))
        }
      })
    }
  }
  return(df)
}

# Try
# x2 <- read.delim("data/clustered_data.txt")
# x2 <- round_tbl(x2, 3)
#
# df <- read.delim("data/try-this/GO_HF12wk_vs_WT12wk.txt")
# df <- round_tbl(df, 3)



# Old code
# x <- 3.14159e-3
# x <- signif(x, digits=3)
# x <- as.numeric(formatC(x, format="f"))
# e_count <- function(x) {
#   if (grepl("e", x, fixed=TRUE)) {
#     x <- unlist(strsplit(as.character(x), "e"))
#     return(as.numeric(x[2]))
#   } else {
#     return(0)
#   }
# }

# df <- read.delim("data/try-this/GO_HF12wk_vs_WT12wk.txt")
# n <- 3
# round_table <- function(df, n) {
#   nums <- which(vapply(df, is.numeric, FUN.VALUE=logical(1)))
#   for (col in nums) {
#     df[col] <- lapply(df[col], function(x) {
#       if (abs(e_count(x)) >= 5) {
#         x <- formatC(x, digits = n, format="e")
#       } else {
#         x <- formatC(x, format="f")
#       }
#       return(x)
#     })
#   }
#
#   return(df)
# }
#
# x <- 3.14159e-3


# round_tbl <- function(df, n) {
#   # nums <- vapply(df, is.numeric, FUN.VALUE=logical(1))
#   # df[, nums] %>%
#   #   mutate(across(df[, nums], function(x) format_cells(x=x, n=n)))
#
#
#   #lapply(df[, nums], function(x) format_cells(x, n))
#
#   nums <- which(vapply(df, is.numeric, FUN.VALUE=logical(1)))
#   for (col in nums) {
#     #df[col] <- lapply(df[col], function(x) format_cells(x, n))
#     df[col] %>%
#       dplyr::mutate(function(x) format_cells(x=x, n=n))
#   }
#   return(df)
# }


# df <- round_tbl(df, 3)

# df <- sapply(df, function(x) format_cells(x, 3))

