# Functions to round off decimal places in dataframe tables

format_cells <- function(x, n) {
  if (abs(x) < 1e-5 || abs(x) > 1e+5) {
    #return(format(x, scientific=TRUE, digits=n))
    return(sprintf(paste0("%.", n, "e"), x))
  } else {
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

