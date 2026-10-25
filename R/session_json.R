# Session JSON reader/writer
#
# The one writer shared by the Save tab and scripts/convert-trusted-session.R,
# and the one reader behind the Load tab. Uploaded session files are JSON only;
# nothing in this file deserializes R objects.
#
# Data frames are written as column lists (the long-standing layout), plus a
# top-level `df_schema` that records each data frame's row count, column names,
# column classes, factor levels and character row names. The schema is what
# makes the round trip lossless (types, zero-row tables, non-syntactic names);
# files without it (older saves) load through the legacy as.data.frame() path.

session_json_sections <- c("degdfs", "rrdfs", "clusdfs", "cluslists")

session_json_columns <- c("degnames", "rrnames", "clusnames")

# Doubles carrying NaN/Inf cannot be plain JSON numbers; such a column is written
# as strings with 17 significant digits, which still reads back bit-identical.
session_json_encode_column <- function(x) {
  if (is.factor(x)) {
    return(list(data = as.character(x), class = "factor", levels = levels(x)))
  }
  if (is.logical(x)) return(list(data = x, class = "logical"))
  if (is.integer(x)) return(list(data = x, class = "integer"))
  if (is.double(x)) {
    if (any(is.nan(x) | is.infinite(x))) {
      out <- sprintf("%.17g", x)
      out[is.na(x) & !is.nan(x)] <- NA_character_
      return(list(data = out, class = "double"))
    }
    return(list(data = x, class = "double"))
  }
  list(data = as.character(x), class = "character")
}

session_json_encode_df <- function(df) {
  if (!is.data.frame(df)) return(list(data = df, schema = NULL))
  encoded <- lapply(df, session_json_encode_column)
  levels_by_position <- list()
  for (i in seq_along(encoded)) {
    if (!is.null(encoded[[i]]$levels)) {
      levels_by_position[[as.character(i)]] <- encoded[[i]]$levels
    }
  }
  schema <- list(
    nrow = nrow(df),
    names = names(df),
    classes = vapply(encoded, function(e) e$class, character(1), USE.NAMES = FALSE),
    levels = levels_by_position
  )
  if (.row_names_info(df) > 0L) schema$row_names <- rownames(df)
  data <- lapply(encoded, function(e) e$data)
  names(data) <- names(df)
  list(data = data, schema = schema)
}

#' Write a session list as lossless JSON
#'
#' @param session_data Session list (version, labels, data-frame sections).
#' @param file Output path.
#' @return `file`, invisibly.
#' @noRd
session_json_write <- function(session_data, file) {
  json_data <- session_data
  schema <- list()
  for (section in session_json_sections) {
    items <- session_data[[section]]
    if (is.null(items)) next
    encoded <- lapply(items, session_json_encode_df)
    json_data[[section]] <- lapply(encoded, function(e) e$data)
    schema[[section]] <- Filter(Negate(is.null), lapply(encoded, function(e) e$schema))
  }
  json_data$df_schema <- schema
  jsonlite::write_json(json_data, file, auto_unbox = TRUE, pretty = TRUE,
                       digits = I(17), na = "null")
  invisible(file)
}

# A column read back by jsonlite may be a vector, an empty list, or (for a
# column of only nulls) a logical vector; normalise to a plain vector.
session_json_flatten <- function(v) {
  if (is.list(v)) {
    if (!length(v)) return(NULL)
    v <- unlist(lapply(v, function(e) if (is.null(e)) NA else e))
  }
  v
}

session_json_decode_column <- function(v, class, levels) {
  v <- session_json_flatten(v)
  switch(class,
    logical = as.logical(v),
    integer = as.integer(v),
    double = as.numeric(v),
    factor = factor(as.character(v), levels = levels),
    as.character(v)
  )
}

session_json_decode_df <- function(raw, schema) {
  if (is.null(schema)) return(as.data.frame(raw))
  col_names <- as.character(unlist(schema$names))
  classes <- as.character(unlist(schema$classes))
  n <- as.integer(schema$nrow)
  if (length(n) != 1L || is.na(n) || length(col_names) != length(classes) ||
      length(raw) != length(col_names)) {
    stop("Invalid session file format", call. = FALSE)
  }
  columns <- lapply(seq_along(col_names), function(i) {
    col <- session_json_decode_column(
      raw[[i]], classes[[i]], as.character(unlist(schema$levels[[as.character(i)]]))
    )
    if (length(col) != n) stop("Invalid session file format", call. = FALSE)
    col
  })
  row_names <- if (is.null(schema$row_names)) .set_row_names(n) else
    as.character(unlist(schema$row_names))
  structure(columns, names = col_names, class = "data.frame", row.names = row_names)
}

#' Read a session JSON file
#'
#' @param path Path to a `.json` session file.
#' @return The session list, with data-frame sections restored as data frames.
#' @noRd
session_json_read <- function(path) {
  session_data <- jsonlite::read_json(path, simplifyVector = TRUE)
  if (!is.list(session_data)) stop("Invalid session file format", call. = FALSE)
  schema <- session_data$df_schema
  for (section in session_json_sections) {
    items <- session_data[[section]]
    session_data[[section]] <- structure(
      lapply(names(items), function(nm) session_json_decode_df(items[[nm]], schema[[section]][[nm]])),
      names = names(items)
    )
  }
  for (column in session_json_columns) {
    if (is.list(session_data[[column]]) && !length(session_data[[column]])) {
      session_data[[column]] <- character()
    }
  }
  session_data$df_schema <- NULL
  session_data
}

# TRUE when a file starts like a serialized R object (plain, gzip, bzip2, xz).
# Only the leading bytes are inspected; the file is never deserialized.
session_json_looks_like_rds <- function(path) {
  head <- readBin(path, what = "raw", n = 3L)
  if (length(head) < 2L) return(FALSE)
  chars <- rawToChar(head[head != as.raw(0L)])
  identical(head[1:2], as.raw(c(0x1f, 0x8b))) || startsWith(chars, "BZh") ||
    identical(head[1:2], as.raw(c(0xfd, 0x37))) ||
    substr(chars, 1L, 2L) %in% c("X\n", "A\n", "B\n") || startsWith(chars, "RDX")
}
