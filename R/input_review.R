# SPEC-WS-004 intake review: upload admission before expensive parsing, truthful
# query-review snapshots, review cards, and transactional enrichment-result import.
# Pure helpers take data and return lists; they never read reactives. Card markup
# uses shiny tags with text children only, so every label and column name is escaped.

# @MX:NOTE: [AUTO] SPEC-WS-004 constant, held for adoption into the 001 resource policy.
# read.delim time grows quadratically with cell length, so longer lines are refused unread.
review_line_bytes_limit <- 262144L

review_policy_message <- "Upload checks unavailable: resource policy missing or invalid"

review_result_roles <- c("Term", "Annot", "Pvalue", "Padj", "GeneID")

# The installed policy, a policy file path, or a policy list; NULL when unusable.
review_resolve_policy <- function(policy = NULL) {
  tryCatch({
    if (is.null(policy)) {
      workspace_resource_policy()
    } else if (is.character(policy)) {
      workspace_resource_policy(policy)
    } else {
      workspace_validate_resource_policy(policy)
    }
  }, error = function(e) NULL)
}

review_reject <- function(message, field = NA_character_) {
  list(ok = FALSE, field = field, message = message, df = NULL)
}

review_limit_failure <- function(metrics, policy) {
  tryCatch({
    workspace_check_resources(metrics, policy)
    NULL
  }, error = function(e) {
    message <- conditionMessage(e)
    review_reject(message, sub("^.*: ", "", message))
  })
}

# Reader seams: the only places an admitted file is parsed.
review_read_text <- function(con, sep, nrows) {
  if (identical(sep, ",")) {
    utils::read.csv(con, nrows = nrows)
  } else {
    utils::read.delim(con, nrows = nrows)
  }
}

review_read_excel <- function(path, n_max) {
  as.data.frame(readxl::read_excel(path, n_max = n_max))
}

review_magic <- function(path) {
  bytes <- readBin(path, "raw", 8L)
  starts <- function(hex) {
    signature <- as.raw(strtoi(hex, 16L))
    length(bytes) >= length(signature) && identical(bytes[seq_along(signature)], signature)
  }
  if (starts(c("50", "4b", "03", "04"))) return("xlsx")
  if (starts(c("d0", "cf", "11", "e0", "a1", "b1", "1a", "e1"))) return("xls")
  if (starts(c("1f", "8b")) || starts(c("42", "5a", "68")) ||
      starts(c("fd", "37", "7a", "58", "5a", "00")) || starts(c("28", "b5", "2f", "fd"))) {
    return("compressed")
  }
  "text"
}

# @MX:ANCHOR: [AUTO] Upload trust boundary for every DEG and enrichment-result file.
# @MX:REASON: Bounds bytes, archive, rows, columns and strings before any parser runs; both result uploaders and the DEG uploader depend on this order.
review_admit_file <- function(path, name, kind = c("deg", "result"), policy = NULL) {
  kind <- match.arg(kind)
  policy <- review_resolve_policy(policy)
  if (is.null(policy)) return(review_reject(review_policy_message, "policy"))
  size <- file.info(path)$size
  if (length(size) != 1L || is.na(size)) return(review_reject("File could not be read", "structure"))
  failure <- review_limit_failure(list(upload_bytes = size), policy)
  if (!is.null(failure)) return(failure)
  magic <- review_magic(path)
  if (identical(magic, "compressed")) return(review_reject("Compressed files are not accepted", "content"))
  ext <- tolower(tools::file_ext(name))
  excel <- c("xls", "xlsx")
  if ((ext %in% excel && !identical(magic, ext)) || (!ext %in% excel && magic %in% excel)) {
    return(review_reject("File content does not match its extension", "content"))
  }
  parsed <- if (magic %in% excel) {
    review_parse_excel(path, magic, size, policy)
  } else {
    review_parse_text(path, policy)
  }
  if (!isTRUE(parsed$ok)) return(parsed)
  review_check_table(parsed$df, parsed$columns, name, kind, policy)
}

review_parse_excel <- function(path, format, size, policy) {
  unreadable <- review_reject("File structure could not be read", "structure")
  if (identical(format, "xlsx")) {
    entries <- tryCatch(utils::unzip(path, list = TRUE), error = function(e) NULL)
    if (is.null(entries)) return(unreadable)
    failure <- review_limit_failure(list(archive_bytes = size, archive_members = nrow(entries),
      archive_expanded_bytes = sum(as.numeric(entries$Length))), policy)
    if (!is.null(failure)) return(failure)
  }
  header <- tryCatch(review_read_excel(path, n_max = 0), error = function(e) NULL)
  if (is.null(header)) return(unreadable)
  failure <- review_limit_failure(list(columns = ncol(header)), policy)
  if (!is.null(failure)) return(failure)
  df <- tryCatch(review_read_excel(path, n_max = policy$limits$rows + 1), error = function(e) NULL)
  if (is.null(df)) return(unreadable)
  failure <- review_limit_failure(list(rows = nrow(df)), policy)
  if (!is.null(failure)) return(failure)
  list(ok = TRUE, df = df, columns = ncol(header))
}

# Field counting with the reader's own rules over a bounded physical-line window.
# Every read opens its own raw connection, so R never decompresses or reuses one.
review_count_fields <- function(lines, sep) {
  con <- textConnection(lines)
  on.exit(close(con), add = TRUE)
  tryCatch(suppressWarnings(utils::count.fields(con, sep = sep, quote = "\"", comment.char = "",
                                                blank.lines.skip = TRUE)),
           error = function(e) NA_integer_)
}

review_parse_text <- function(path, policy) {
  rows <- policy$limits$rows
  rows_failure <- review_reject("Workspace resource limit exceeded: rows", "rows")
  lines <- local({
    con <- file(path, "rt", raw = TRUE)
    on.exit(close(con), add = TRUE)
    readLines(con, n = rows + 3L, warn = FALSE)
  })
  if (length(lines) > rows + 2L) return(rows_failure)
  if (any(nchar(lines, type = "bytes") > review_line_bytes_limit)) {
    return(review_reject("Line too long", "line_bytes"))
  }
  nonblank <- nzchar(lines)
  if (!any(nonblank)) return(review_reject("File is empty", "empty"))
  if (sum(nonblank) > rows + 1L) return(rows_failure)
  tab_counts <- review_count_fields(lines, "\t")
  comma_counts <- review_count_fields(lines, ",")
  sep <- if (!is.na(comma_counts[1]) && !is.na(tab_counts[1]) && comma_counts[1] > tab_counts[1]) "," else "\t"
  counts <- if (identical(sep, ",")) comma_counts else tab_counts
  if (!length(counts) || anyNA(counts)) return(review_reject("File structure could not be read", "structure"))
  header <- counts[1]
  data <- counts[-1]
  columns <- if (length(data) && all(data == header + 1L)) header else max(counts)
  failure <- review_limit_failure(list(columns = columns), policy)
  if (!is.null(failure)) return(failure)
  con <- file(path, "rt", raw = TRUE)
  on.exit(close(con), add = TRUE)
  df <- tryCatch(review_read_text(con, sep, nrows = rows + 1L), error = function(e) NULL)
  if (is.null(df)) return(review_reject("File structure could not be read", "structure"))
  failure <- review_limit_failure(list(rows = nrow(df)), policy)
  if (!is.null(failure)) return(failure)
  list(ok = TRUE, df = df, columns = columns)
}

review_text_cells <- function(x) {
  if (!(is.character(x) || is.factor(x))) return(NULL)
  x <- as.character(x)
  x[!is.na(x)]
}

review_identifier_overflow <- function(x, limit) {
  tokens <- unlist(strsplit(x, "[,;/]", useBytes = TRUE))
  any(nchar(tokens, type = "bytes") > limit)
}

# Character columns holding at least one cell over the per-cell string limit.
review_cell_overflow <- function(df, limit) {
  over <- vapply(df, function(x) {
    cells <- review_text_cells(x)
    length(cells) > 0L && any(nchar(cells, type = "bytes") > limit)
  }, logical(1))
  names(df)[over]
}

review_check_table <- function(df, columns, name, kind, policy) {
  limits <- policy$limits
  if (!is.data.frame(df) || ncol(df) > columns) {
    return(review_reject("Workspace resource limit exceeded: columns", "columns"))
  }
  for (column in names(df)) {
    if (!is.atomic(df[[column]])) {
      return(review_reject(paste("Unsupported cell types in column", column), "cell_types"))
    }
  }
  limit <- limits$string_bytes
  string_failure <- function(where) {
    review_reject(sprintf("Workspace resource limit exceeded: string_bytes (%s)", where), "string_bytes")
  }
  if (any(nchar(name, type = "bytes") > limit)) return(string_failure("label"))
  if (any(nchar(names(df), type = "bytes") > limit)) return(string_failure("column name"))
  per_identifier <- character()
  decoded <- 0
  for (column in names(df)) {
    cells <- review_text_cells(df[[column]])
    if (is.null(cells)) next
    decoded <- decoded + sum(nchar(cells, type = "bytes"))
    if (!any(nchar(cells, type = "bytes") > limit)) next
    # Result membership columns are bounded per identifier; until the mapping is
    # known every character column of a result file gets that provisional bound.
    if (identical(kind, "result") && !review_identifier_overflow(cells, limit)) {
      per_identifier <- c(per_identifier, column)
      next
    }
    return(string_failure(paste("column", column)))
  }
  failure <- review_limit_failure(list(decoded_bytes = decoded), policy)
  if (!is.null(failure)) return(failure)
  list(ok = TRUE, field = NA_character_, message = NULL, df = df, per_identifier = per_identifier)
}

review_split_genes <- function(text) {
  tokens <- unlist(strsplit(text, "[[:space:],;]+"))
  tokens[nzchar(tokens)]
}

review_admit_text <- function(text, label, policy = NULL) {
  policy <- review_resolve_policy(policy)
  if (is.null(policy)) return(review_reject(review_policy_message, "policy"))
  failure <- review_limit_failure(list(upload_bytes = sum(nchar(text, type = "bytes"))), policy)
  if (!is.null(failure)) return(failure)
  tokens <- review_split_genes(text)
  if (!length(tokens)) return(review_reject("No genes found in the pasted text", "empty"))
  failure <- review_limit_failure(list(rows = length(tokens)), policy)
  if (!is.null(failure)) return(failure)
  limit <- policy$limits$string_bytes
  if (any(nchar(c(label, tokens), type = "bytes") > limit)) {
    return(review_reject("Workspace resource limit exceeded: string_bytes", "string_bytes"))
  }
  list(ok = TRUE, field = NA_character_, message = NULL, tokens = tokens)
}

# Selector choices: recognized columns first, then the rest labeled for confirmation.
review_column_choices <- function(first, others) {
  others_named <- if (length(others)) {
    stats::setNames(others, paste(others, "(Role confirmed by user)"))
  } else {
    character()
  }
  c(stats::setNames(first, first), others_named)
}

review_cutoff_value <- function(x) {
  if (is.null(x) || length(x) != 1L || is.na(x)) 0.05 else x
}

# Explicit rule from the Preprocess selectors; NULL means the default (legacy) rule.
review_rule_from_inputs <- function(p_col, role) {
  if (is.null(p_col) || !nzchar(p_col) || identical(p_col, "__default__")) return(NULL)
  if (identical(p_col, "__none__")) return(list(column = NA_character_, role = "none"))
  list(column = p_col, role = if (is.null(role) || !nzchar(role)) "adjusted" else role)
}

# Query review snapshot. The default rule reproduces the legacy worker rule exactly:
# the first column named padj (adjusted), else pvalue (raw), else no filter, compared
# with !is.na(x) & x < cutoff and no numeric check.
review_resolve <- function(df, gene_header = NULL, gene_col = NULL, rule = NULL, cutoff = 0.05,
                           name = "", settings = NULL) {
  fail <- function(field, message) list(ok = FALSE, field = field, message = message)
  columns <- colnames(df)
  cutoff <- review_cutoff_value(cutoff)
  if (!is.null(gene_col) && length(gene_col) == 1L && !is.na(gene_col) && nzchar(gene_col)) {
    if (!gene_col %in% columns) return(fail("gene_col", paste("Gene column", gene_col, "was not found")))
  } else {
    gene_col <- query_gene_column(df, gene_header)
    if (is.na(gene_col)) return(fail("gene_col", "Gene identifier column was not found."))
  }
  note <- NULL
  if (is.null(rule)) {
    lower <- tolower(columns)
    if (any(lower == "padj")) {
      column <- columns[which(lower == "padj")[1]]
      role <- "adjusted"
    } else if (any(lower == "pvalue")) {
      column <- columns[which(lower == "pvalue")[1]]
      role <- "raw"
    } else {
      column <- NA_character_
      role <- "none"
    }
    if (!is.na(column) && !is.numeric(df[[column]])) note <- "Column is not numeric; compared as before"
  } else if (identical(rule$role, "none")) {
    column <- NA_character_
    role <- "none"
  } else {
    column <- rule$column
    role <- rule$role
    if (!role %in% c("adjusted", "raw")) {
      return(fail("p_role", "Choose whether the p-value column is adjusted or raw"))
    }
    if (is.null(column) || length(column) != 1L || !column %in% columns) {
      return(fail("p_col", paste("P-value column", column, "was not found")))
    }
    if (identical(column, gene_col)) return(fail("p_col", "Gene column and p-value column must differ"))
    values <- df[[column]]
    if (!is.numeric(values)) return(fail("p_col", paste("Column", column, "is not numeric")))
    present <- values[!is.na(values)]
    if (any(present < 0 | present > 1)) {
      return(fail("p_col", paste("Column", column, "has values outside [0, 1]")))
    }
    if (!is.numeric(cutoff) || cutoff <= 0 || cutoff > 1) {
      return(fail("cutoff", "Cutoff must be greater than 0 and at most 1"))
    }
  }
  p <- if (is.na(column)) NULL else df[[column]]
  keep <- if (is.null(p)) rep(TRUE, nrow(df)) else (!is.na(p) & p < cutoff)
  ids <- as.character(df[[gene_col]])[keep]
  blank <- is.na(ids) | !nzchar(trimws(ids))
  submitted <- ids[!blank]
  if (!length(submitted)) return(fail("submitted", paste("No genes remain after the rule for", name)))
  distinct <- length(unique(submitted))
  counts <- list(
    kept = as.integer(sum(keep)), submitted = length(submitted), distinct = distinct,
    excluded = c(p_missing = if (is.null(p)) 0L else as.integer(sum(is.na(p))),
                 p_cutoff = if (is.null(p)) 0L else as.integer(sum(!is.na(p) & !keep)),
                 id_blank = as.integer(sum(blank))),
    duplicates = length(submitted) - distinct
  )
  query_rule <- list(gene_col = gene_col, column = column, role = role, cutoff = cutoff)
  source_digest <- digest::digest(df)
  list(ok = TRUE, field = NA_character_, message = NULL, gene_col = gene_col,
       query_rule = query_rule, submitted = submitted, counts = counts, note = note,
       source_digest = source_digest,
       digest = digest::digest(list(source_digest, query_rule, submitted, settings)))
}

review_rule_text <- function(rule) {
  if (identical(rule$role, "none")) return("No p-value filter (all rows)")
  sprintf("%s < %s (%s)", rule$column, format(rule$cutoff), rule$role)
}

review_snapshot_items <- function(snapshot) {
  if (!isTRUE(snapshot$ok)) return(list(tags$li(snapshot$message)))
  counts <- snapshot$counts
  list(
    tags$li(paste("Source digest:", substr(snapshot$source_digest, 1L, 12L))),
    tags$li(paste("Gene column:", snapshot$gene_col)),
    tags$li(paste("Rule:", review_rule_text(snapshot$query_rule))),
    tags$li(paste("Rows kept:", counts$kept)),
    tags$li(paste("Submitted genes:", counts$submitted)),
    tags$li(paste("Distinct genes:", counts$distinct)),
    tags$li(sprintf("Excluded: p missing %d, p \u2265 cutoff %d, blank/missing ID %d",
                    counts$excluded[["p_missing"]], counts$excluded[["p_cutoff"]],
                    counts$excluded[["id_blank"]])),
    tags$li(paste("Duplicates (information):", counts$duplicates)),
    if (!is.null(snapshot$note)) tags$li(snapshot$note)
  )
}

review_preview_card <- function(snapshot) {
  tags$ul(class = "review-preview-snapshot", review_snapshot_items(snapshot))
}

review_setting_text <- function(value) {
  if (is.null(value) || !length(value) || is.na(value[[1]]) || !nzchar(value[[1]])) "Not set" else
    as.character(value[[1]])
}

# Review card shown above Run: one entry per selected gene list.
review_deg_card <- function(entries, settings) {
  if (!length(entries)) return(tags$p("Select gene lists to review them before Run."))
  tags$div(class = "review-card", lapply(entries, function(entry) {
    status <- if (isTRUE(entry$committed)) {
      sprintf("Committed revision %d", entry$revision)
    } else {
      "Default rule (not customized)"
    }
    tags$div(class = "review-card-entry",
      tags$h5(entry$name),
      tags$ul(
        tags$li(paste("Gene list:", entry$name)),
        tags$li(status),
        if (isTRUE(entry$changed)) {
          tags$li(sprintf("Input changed since commit for %s; review again", entry$name))
        },
        review_snapshot_items(entry$snapshot),
        tags$li(paste("Species:", review_setting_text(settings$species))),
        tags$li(paste("Identifier type:", review_setting_text(settings$keytype))),
        tags$li(paste("Annotation:", review_setting_text(settings$anntype))),
        tags$li(paste("Ontology:", review_setting_text(settings$ontology))),
        tags$li("Mapped / unmapped: Not available (not measured)")
      ))
  }))
}

# ---- enrichment-result import ------------------------------------------------

review_suggestions <- function(columns) {
  dictionary <- list(Term = expanded_col_dictionary$Term, Annot = expanded_col_dictionary$ID,
                     Pvalue = expanded_col_dictionary$Pvalue, Padj = expanded_col_dictionary$Padj,
                     GeneID = expanded_col_dictionary$GeneID)
  lapply(dictionary, function(terms) {
    columns[tolower(columns) %in% tolower(terms) & !columns %in% review_result_roles]
  })
}

review_delimiters <- function(x) {
  x <- as.character(x)
  x <- x[!is.na(x)]
  kinds <- c(",", ";", "/")
  kinds[vapply(kinds, function(kind) any(grepl(kind, x, fixed = TRUE)), logical(1))]
}

review_validate_result <- function(df, label, existing_labels, roles, limit) {
  messages <- character()
  if (label %in% existing_labels) messages <- c(messages, paste("A result named", label, "already exists"))
  if (!"Term" %in% roles) {
    messages <- c(messages, "Term column is required")
  } else {
    term <- as.character(df$Term)
    blank <- is.na(term) | !nzchar(trimws(term))
    if (any(blank)) messages <- c(messages, sprintf("Term is blank in %d row(s)", sum(blank)))
  }
  if (!any(c("Pvalue", "Padj") %in% roles)) messages <- c(messages, "At least one of Pvalue or Padj is required")
  for (role in intersect(c("Pvalue", "Padj"), roles)) {
    values <- df[[role]]
    if (is.logical(values) && all(is.na(values))) next
    if (!is.numeric(values)) {
      messages <- c(messages, paste("Column", role, "is not numeric"))
    } else if (any(values[!is.na(values)] < 0 | values[!is.na(values)] > 1)) {
      messages <- c(messages, paste("Column", role, "has values outside [0, 1]"))
    }
  }
  key <- if ("Annot" %in% roles) "Annot" else if ("Term" %in% roles) "Term" else NULL
  if (!is.null(key)) {
    values <- as.character(df[[key]])
    duplicated_values <- unique(values[duplicated(values) & !is.na(values)])
    if (length(duplicated_values)) {
      messages <- c(messages, sprintf("Duplicate %s values: %s", key,
                                      paste(utils::head(duplicated_values, 3L), collapse = ", ")))
    }
  }
  if ("GeneID" %in% roles) {
    genes <- as.character(df$GeneID)
    blank <- is.na(genes) | !nzchar(trimws(genes))
    if (any(blank)) messages <- c(messages, sprintf("GeneID is blank in %d row(s)", sum(blank)))
    if (length(review_delimiters(genes)) > 1L) messages <- c(messages, "GeneID uses mixed delimiters")
    cells <- review_text_cells(df$GeneID)
    if (length(cells) && review_identifier_overflow(cells, limit)) {
      messages <- c(messages, "Column GeneID has an identifier over the string limit")
    }
  }
  over <- setdiff(review_cell_overflow(df, limit), if ("GeneID" %in% roles) "GeneID")
  c(messages, sprintf("Column %s exceeds the string limit", over))
}

# Validate an admitted result table. Without a mapping, a file whose present roles
# are all exact canonical columns imports unchanged; otherwise it waits for an
# explicit mapping. No Pvalue is ever derived from Padj or the reverse.
review_import <- function(df, label, existing_labels, mapping = NULL, policy = NULL) {
  policy <- review_resolve_policy(policy)
  if (is.null(policy)) {
    return(list(status = "rejected", df = NULL, messages = review_policy_message,
                source_name_map = character()))
  }
  limit <- policy$limits$string_bytes
  columns <- names(df)
  suggestions <- review_suggestions(columns)
  rejected <- function(messages) {
    list(status = "rejected", df = NULL, messages = messages, source_name_map = character(),
         suggestions = suggestions)
  }
  if (is.null(mapping)) {
    exact <- review_result_roles[review_result_roles %in% columns]
    missing <- setdiff(review_result_roles, exact)
    renames <- missing[vapply(suggestions[missing], length, integer(1)) > 0L]
    gene_like <- setdiff(review_cell_overflow(df, limit), "GeneID")
    if ("Term" %in% exact && !length(renames) && !length(gene_like)) {
      messages <- review_validate_result(df, label, existing_labels, exact, limit)
      if (length(messages)) return(rejected(messages))
      return(list(status = "imported", df = df, messages = character(), source_name_map = character(),
                  suggestions = suggestions))
    }
    messages <- c(
      if (!"Term" %in% exact) "Choose the column that holds Term",
      if (length(renames)) paste("Confirm the suggested column for", paste(renames, collapse = ", ")),
      sprintf(paste("Column %s looks like a gene list; map it as GeneID, or Import will refuse the",
                    "file because the column exceeds the string limit"), gene_like)
    )
    return(list(status = "pending", df = NULL, messages = messages, source_name_map = character(),
                suggestions = suggestions))
  }
  mapping <- mapping[!is.na(mapping) & nzchar(mapping) & names(mapping) %in% review_result_roles]
  messages <- character()
  absent <- setdiff(unname(mapping), columns)
  messages <- c(messages, sprintf("Column %s was not found", absent))
  twice <- unique(mapping[duplicated(mapping)])
  messages <- c(messages, sprintf("Column %s is mapped to more than one role", twice))
  # A role left unmapped keeps its exact canonical column, if the file has one.
  for (role in setdiff(review_result_roles, names(mapping))) {
    if (role %in% columns && !role %in% mapping) mapping[[role]] <- role
  }
  for (role in names(mapping)) {
    source <- mapping[[role]]
    if (!identical(source, role) && role %in% columns && !role %in% mapping) {
      messages <- c(messages, sprintf("Cannot rename %s to %s: column %s already exists", source, role, role))
    }
  }
  if (length(messages)) return(rejected(messages))
  renamed <- df
  names(renamed)[match(unname(mapping), names(df))] <- names(mapping)
  messages <- review_validate_result(renamed, label, existing_labels, names(mapping), limit)
  if (length(messages)) return(rejected(messages))
  list(status = "imported", df = renamed, messages = character(),
       source_name_map = mapping[mapping != names(mapping)], suggestions = suggestions)
}

review_availability <- function(df) {
  columns <- names(df)
  lines <- c(
    if ("Pvalue" %in% columns) "Raw p-values: provided" else
      "Raw p-values: not provided. Hierarchical clustering requires raw p-values (column Pvalue).",
    if ("Padj" %in% columns) "Adjusted p-values: provided" else "Adjusted p-values: not provided",
    if ("GeneID" %in% columns) "Gene membership: provided" else
      "Gene membership: not provided. Clustering needs gene membership (column GeneID)."
  )
  if ("GeneID" %in% columns) {
    other <- setdiff(review_delimiters(df$GeneID), ",")
    if (length(other)) {
      lines <- c(lines, sprintf("Clustering reads comma-separated genes; this file uses '%s'",
                                paste(other, collapse = "', '")))
    }
  }
  lines
}

review_imported_card <- function(labels, rrdfs, maps) {
  labels <- labels[vapply(labels, function(label) !is.null(rrdfs[[label]]), logical(1))]
  if (!length(labels)) return(tags$p("No enrichment results imported yet."))
  tags$ul(class = "imported-results", lapply(labels, function(label) {
    map <- maps[[label]]
    tags$li(label, tags$ul(
      lapply(review_availability(rrdfs[[label]]), tags$li),
      lapply(names(map), function(role) tags$li(sprintf("%s: Mapped from %s", role, map[[role]])))
    ))
  }))
}

review_move_record <- function(records, old_name, new_name) {
  if (identical(old_name, new_name)) return(invisible(NULL))
  records[[new_name]] <- records[[old_name]]
  records[[old_name]] <- NULL
  invisible(NULL)
}

# Shared intake for both enrichment-result uploaders: admission, immediate import of
# exact files, one pending confirmation card at a time, and the Imported results card.
# Stores change only on a successful import; a rejection leaves them untouched.
review_result_intake <- function(input, output, session, u_rrnames, u_rrdfs, u_big_rrdf) {
  ns <- session$ns
  intake <- reactiveValues(queue = list(), status = character(), card_messages = character())
  maps <- reactiveValues()

  existing_labels <- function() {
    unique(c(u_rrnames$labels, names(shiny::reactiveValuesToList(u_rrdfs))))
  }
  publish <- function(label, df, map) {
    u_rrdfs[[label]] <- df
    u_rrnames$labels <- c(u_rrnames$labels, label)
    u_big_rrdf[['df']] <- add_file_rrdf(df = u_big_rrdf[['df']], name = label, file = TRUE)
    maps[[label]] <- map
  }
  notify <- function(label, messages) {
    showNotification(paste0(label, ": ", paste(messages, collapse = "; ")), type = "error")
  }

  observeEvent(input$rr_files, {
    files <- input$rr_files
    status <- character()
    for (i in seq_along(files$name)) {
      label <- files$name[i]
      admitted <- review_admit_file(files$datapath[i], label, "result")
      if (!isTRUE(admitted$ok)) {
        status <- c(status, paste0(label, " was not imported: ", admitted$message))
        notify(label, admitted$message)
        next
      }
      result <- review_import(admitted$df, label, existing_labels())
      if (identical(result$status, "imported")) {
        publish(label, result$df, character())
        status <- c(status, paste(label, "imported"))
      } else if (identical(result$status, "pending")) {
        intake$queue <- c(intake$queue, list(list(label = label, df = admitted$df,
          messages = result$messages, suggestions = result$suggestions)))
        status <- c(status, paste(label, "waits for column confirmation"))
      } else {
        status <- c(status, paste0(label, " was not imported: ", paste(result$messages, collapse = "; ")))
        notify(label, result$messages)
      }
    }
    intake$status <- status
  })

  observeEvent(input$intake_import, {
    queue <- intake$queue
    req(length(queue) > 0L)
    current <- queue[[1]]
    mapping <- vapply(review_result_roles, function(role) {
      value <- input[[paste0("intake_map_", role)]]
      if (is.null(value)) "" else as.character(value)
    }, character(1))
    names(mapping) <- review_result_roles
    result <- review_import(current$df, current$label, existing_labels(), mapping = mapping)
    if (identical(result$status, "imported")) {
      publish(current$label, result$df, result$source_name_map)
      intake$queue <- queue[-1]
      intake$card_messages <- character()
      intake$status <- paste(current$label, "imported")
    } else {
      intake$card_messages <- result$messages
      notify(current$label, result$messages)
    }
  })

  observeEvent(input$intake_discard, {
    req(length(intake$queue) > 0L)
    intake$status <- paste(intake$queue[[1]]$label, "discarded")
    intake$queue <- intake$queue[-1]
    intake$card_messages <- character()
  })

  output$intake_status <- renderUI({
    status <- intake$status
    if (length(status)) tags$ul(class = "intake-status", lapply(status, tags$li))
  })

  output$intake_pending <- renderUI({
    queue <- intake$queue
    if (!length(queue)) return(NULL)
    current <- queue[[1]]
    columns <- names(current$df)
    selectors <- lapply(review_result_roles, function(role) {
      suggested <- current$suggestions[[role]]
      exact <- if (role %in% columns) role else character()
      first <- unique(c(exact, suggested))
      others <- setdiff(columns, first)
      choices <- c(stats::setNames("", "(not mapped)"), review_column_choices(first, others))
      selected <- if (length(exact)) exact else if (length(suggested) == 1L) suggested else ""
      selectInput(ns(paste0("intake_map_", role)), role, choices = choices, selected = selected)
    })
    tags$div(class = "intake-pending",
      tags$h4(paste("Confirm columns for", current$label)),
      tags$ul(lapply(current$messages, tags$li)),
      if (length(intake$card_messages)) {
        tags$ul(class = "intake-errors", lapply(intake$card_messages, tags$li))
      },
      selectors,
      actionButton(ns("intake_import"), "Import"),
      actionButton(ns("intake_discard"), "Discard"),
      if (length(queue) > 1L) {
        tags$p(paste("Queued:", paste(vapply(queue[-1], function(item) item$label, character(1)),
                                      collapse = ", ")))
      })
  })

  output$imported_results_card <- renderUI({
    labels <- as.character(u_rrnames$labels)
    rrdfs <- lapply(stats::setNames(labels, labels), function(label) u_rrdfs[[label]])
    review_imported_card(labels, rrdfs, shiny::reactiveValuesToList(maps))
  })

  list(maps = maps)
}

# Upload-tab panel for the shared result intake (status, pending card, imported card).
review_result_intake_ui <- function(ns) {
  box(title = "Imported results", width = NULL,
    uiOutput(ns("intake_status")),
    uiOutput(ns("intake_pending")),
    uiOutput(ns("imported_results_card"))
  )
}
