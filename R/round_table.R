# Functions to round off decimal places in dataframe tables


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
  df[] <- lapply(df, function(col) {
    numeric_col <- withCallingHandlers(
      as.numeric(col),
      warning = function(w) {
        if (grepl("NAs introduced by coercion", conditionMessage(w)))
          invokeRestart("muffleWarning")
      }
    )
    # Detect values that were non-NA strings but became NA after conversion
    coerced_na <- is.na(numeric_col) & !is.na(col) & nzchar(as.character(col))
    if (any(coerced_na)) {
      n_bad <- sum(coerced_na)
      sample_vals <- utils::head(unique(as.character(col[coerced_na])), 3)
      warning(
        sprintf("round_tbl: %d non-numeric value(s) could not be converted (e.g., %s)",
                n_bad, paste(sQuote(sample_vals), collapse = ", ")),
        call. = FALSE
      )
    }
    is_numeric <- !is.na(numeric_col) & !is.na(col)
    col[is_numeric] <- vapply(
      numeric_col[is_numeric],
      function(x) as.character(format_cells(x, n)),
      character(1)
    )
    col
  })
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

