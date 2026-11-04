# Functions to create comprehensive and individual term heatmaps for cluster
# results

# Named constants for heatmap configuration
hmap_round_digits <- 4L
hmap_color_low <- "green"
hmap_color_high <- "red"


# Prepare cluster result for heatmap
hmap_prepare <- function(clustered_gs, gs_names) {
  # Create tibble with Term and AnnotationCluster
  x <- tibble::as_tibble(cbind(
    clustered_gs$AnnotationCluster,
    clustered_gs$Term
  ))
  colnames(x) <- c("Cluster", "Representative_Term")

  # Order clusters numerically
  x <- x[order(as.numeric(x$Cluster)), ]

  # Subset Padj columns of clustered_gs into new df values
  value_cols <- c(paste0("Pvalue_", gs_names), paste0("Padj_", gs_names))
  values <- clustered_gs[, value_cols]

  # Combine Term and Cluster with Padj values
  final_data <- data.frame()
  final_data <- cbind(x, values)

  final_data
}


# Convert display probabilities without altering the source tables.
hmap_numeric_pvalues <- function(values, where) {
  raw <- values
  if (is.factor(values)) {
    values <- as.character(values)
  }
  values <- suppressWarnings(as.numeric(values))
  coerced <- is.na(values) & !is.na(raw) & nzchar(as.character(raw))
  if (any(coerced)) {
    warning(
      sprintf(
        "%s: %d non-numeric value(s) coerced to NA in heatmap data",
        where,
        sum(coerced)
      ),
      call. = FALSE
    )
  }
  invalid <- !is.na(values) & (!is.finite(values) | values < 0 | values > 1)
  if (any(invalid)) {
    warning(
      sprintf(
        "%s: %d probability value(s) outside [0, 1] treated as missing",
        where,
        sum(invalid)
      ),
      call. = FALSE
    )
    values[invalid] <- NA_real_
  }
  values
}

hmap_display_values <- function(values, digits = hmap_round_digits) {
  # The smallest representable positive value keeps an underflowed zero finite.
  # Raw zeros are retained separately and explicitly identified in hover text.
  floor_value <- .Machine$double.xmin * .Machine$double.eps
  if (floor_value == 0) {
    floor_value <- .Machine$double.xmin
  }
  values[!is.na(values) & values == 0] <- floor_value
  scores <- -log10(values)
  if (is.null(digits)) scores else round(scores, digits)
}

hmap_cluster_choices <- function(final_data) {
  ids <- as.character(final_data$Cluster)
  if (anyNA(ids) || any(!nzchar(ids)) || anyDuplicated(ids)) {
    stop(
      "Cluster summary must contain unique, non-missing cluster IDs",
      call. = FALSE
    )
  }
  stats::setNames(
    paste0("cluster:", ids),
    paste0("Cluster ", ids, " | ", final_data$Representative_Term)
  )
}

# Change whether heatmap cells display mean, median, min, or max Pvalue/Padj.
change_finaldata_valueby <- function(
  final_data,
  cluster_list,
  value_by = "mean"
) {
  if (
    length(value_by) != 1L || !value_by %in% c("mean", "median", "min", "max")
  ) {
    stop("Invalid value_by parameter", call. = FALSE)
  }
  new_final_data <- final_data
  value_cols <- intersect(
    grep("^(Pvalue|Padj)", names(cluster_list), value = TRUE),
    names(final_data)
  )
  values <- lapply(
    cluster_list[value_cols],
    hmap_numeric_pvalues,
    where = "change_finaldata_valueby"
  )
  aggregate_value <- function(x) {
    if (!length(x) || all(is.na(x))) {
      return(NA_real_)
    }
    switch(
      value_by,
      mean = mean(x, na.rm = TRUE),
      median = median(x, na.rm = TRUE),
      min = min(x, na.rm = TRUE),
      max = max(x, na.rm = TRUE)
    )
  }
  for (i in seq_len(nrow(final_data))) {
    rows <- !is.na(cluster_list$Cluster) &
      as.character(cluster_list$Cluster) == as.character(final_data$Cluster[i])
    for (column in value_cols) {
      new_final_data[i, column] <- aggregate_value(values[[column]][rows])
    }
  }
  new_final_data
}

# Bound 14px monospace display labels within the 240px label margin, without
# a graphics device or changing source strings.
hmap_axis_labels <- function(final_data) {
  ids <- as.character(final_data$Cluster)
  prefixes <- paste0("Cluster ", ids)
  # Leave one extra column for a wide Unicode character at the excerpt edge.
  # A nine-column budget retains at least eight columns before any ellipsis.
  term_width <- nchar(paste0(final_data$Representative_Term), type = "width")
  excerpt_width <- pmin(9L, term_width) + as.integer(term_width > 9L)
  aliases <- nchar(prefixes, type = "width") + 3L + excerpt_width > 27L
  prefixes[aliases] <- paste0(
    "Display row ",
    rev(seq_along(ids))[aliases]
  )
  labels <- vapply(
    seq_along(ids),
    function(i) {
      separator <- if (aliases[i]) "|" else " | "
      budget <- 27L - nchar(prefixes[i], type = "width") - nchar(separator)
      label <- prefixes[i]
      if (budget >= 1L) {
        term <- paste0(final_data$Representative_Term[i])
        if (nchar(term, type = "width") > budget) {
          # Bound by Unicode characters before measuring display width. No
          # graphics device is opened, including in read-only installations.
          term <- substr(term, 1L, budget - 1L)
          while (nchar(term, type = "width") > budget - 1L) {
            term <- substr(term, 1L, nchar(term) - 1L)
          }
          term <- paste0(term, intToUtf8(8230L))
        }
        label <- paste0(label, separator, term)
      }
      as.character(htmltools::htmlEscape(label))
    },
    character(1)
  )
  list(labels = labels, aliases = aliases, prefixes = prefixes)
}

# Row positions run from the top of the existing reversed category display.
hmap_row_view <- function(plot, rows, start = 1L) {
  starts <- seq.int(1L, max(1L, rows), by = 400L)
  if (length(start) != 1L || is.na(start) || !start %in% starts) {
    start <- 1L
  }
  end <- min(rows, start + 399L)
  visible <- max(1L, end - start + 1L)
  # Plotly omits single-category ticks in a very short drawable band. Keep
  # a compact 90px minimum band, independently of the dataset/note margins.
  height <- max(90L, visible * 18L) + 70L + attr(plot, "hmap_bottom")
  plot$height <- height
  plot$x$layout$height <- height
  plot <- plotly::layout(
    plot,
    yaxis = list(range = c(rows - end - 0.5, rows - start + 0.5)),
    title = list(
      text = paste0(
        attr(plot, "hmap_title"),
        "<br><sup>Rows ",
        start,
        intToUtf8(8211L),
        end,
        " of ",
        rows,
        "</sup>"
      ),
      font = list(size = 16)
    )
  )
  plotly::config(
    plot,
    toImageButtonOptions = list(
      height = height,
      width = 1000,
      scale = 1
    )
  )
}

# Create the cluster summary heatmap using cluster IDs, not representative
# names.
comprehensive_hmap <- function(
  final_data,
  cluster_list,
  value_type = "Padj",
  value_by = "mean"
) {
  if (length(value_type) != 1L || !value_type %in% c("Pvalue", "Padj")) {
    stop("Invalid value_type parameter", call. = FALSE)
  }
  workspace_check_resources(list(render_rows = nrow(final_data)))
  if (!nrow(final_data)) {
    return(NULL)
  }
  choices <- hmap_cluster_choices(final_data)
  axis <- hmap_axis_labels(final_data)
  new_final_data <- change_finaldata_valueby(final_data, cluster_list, value_by)
  value_cols <- grep(
    paste0("^", value_type, "(_|$)"),
    names(new_final_data),
    value = TRUE
  )
  subsetted <- new_final_data[,
    c("Cluster", "Representative_Term", value_cols),
    drop = FALSE
  ]
  names(subsetted) <- sub(paste0("^", value_type, "_"), "", names(subsetted))
  melted_data <- reshape2::melt(
    subsetted,
    id.vars = c("Cluster", "Representative_Term")
  )
  numeric_ids <- suppressWarnings(as.numeric(as.character(melted_data$Cluster)))
  ordering <- if (anyNA(numeric_ids)) {
    as.character(melted_data$Cluster)
  } else {
    numeric_ids
  }
  melted_data <- melted_data[order(ordering), ]
  melted_data$raw_value <- hmap_numeric_pvalues(
    melted_data$value,
    "comprehensive_hmap"
  )
  melted_data$value <- hmap_display_values(melted_data$raw_value)
  if (all(is.na(melted_data$value))) {
    melted_data$value <- I(melted_data$value)
  }
  melted_data$cluster_key <- paste0("cluster:", melted_data$Cluster)
  description <- ifelse(
    is.na(melted_data$raw_value),
    "Not available",
    ifelse(
      melted_data$raw_value == 0,
      paste0("0 (display floor; -log10 = ", melted_data$value, ")"),
      paste0("-log10(", value_type, "): ", melted_data$value)
    )
  )
  melted_data$hover <- paste0(
    "Cluster ",
    melted_data$Cluster,
    "<br>",
    melted_data$Representative_Term,
    "<br>",
    description
  )
  alias_index <- match(melted_data$cluster_key, unname(choices))
  aliased <- axis$aliases[alias_index]
  melted_data$hover[aliased] <- paste0(
    axis$prefixes[alias_index[aliased]],
    "<br>",
    melted_data$hover[aliased]
  )
  # Rotated, fixed-size dataset ticks have a predictable vertical footprint.
  # Reserve their full band plus the axis title before the explanation band.
  dataset_width <- max(nchar(levels(melted_data$variable), type = "width"))
  note_offset <- min(
    860L,
    max(120L, ceiling(dataset_width * 7.2 / sqrt(2)) + 70L)
  )
  bottom <- note_offset + 60L
  plot <- plot_ly(
    data = melted_data,
    x = ~variable,
    y = ~cluster_key,
    z = ~value,
    type = "heatmap",
    colors = c(hmap_color_low, hmap_color_high),
    text = ~hover,
    hoverinfo = "text",
    hoverongaps = TRUE,
    colorbar = list(title = paste0("-log10(", value_type, ")"))
  ) %>%
    layout(
      title = paste0("-log10(", value_type, ") by Cluster"),
      xaxis = list(
        title = list(text = "Geneset", standoff = 20),
        tickangle = -45,
        tickfont = list(size = 12, family = "monospace"),
        automargin = FALSE
      ),
      yaxis = list(
        title = "",
        categoryorder = "array",
        categoryarray = unname(choices),
        tickmode = "array",
        tickvals = unname(choices),
        ticktext = axis$labels,
        tickfont = list(size = 14, family = "monospace"),
        automargin = FALSE,
        fixedrange = TRUE
      ),
      plot_bgcolor = "#eeeeee",
      annotations = list(list(
        text = paste0(
          "Grey cells: no available value; zero p-values ",
          "use a display floor",
          if (any(axis$aliases)) {
            paste0(
              "<br>Display row aliases identify long IDs; hover for full IDs."
            )
          } else {
            ""
          }
        ),
        x = 0,
        y = 0,
        yshift = -note_offset,
        yanchor = "top",
        xref = "paper",
        yref = "paper",
        showarrow = FALSE,
        xanchor = "left",
        font = list(size = 11)
      )),
      margin = list(l = 240, r = 95, t = 70, b = bottom)
    )
  attr(plot, "hmap_bottom") <- bottom
  attr(plot, "hmap_title") <- paste0("-log10(", value_type, ") by Cluster")
  hmap_row_view(plot, nrow(final_data))
}

# Create a term heatmap. New UI selections use IDs; legacy representative names
# remain accepted, selecting all matching clusters as in older saved sessions.
cluster_hmap <- function(
  cluster_list,
  term_vec,
  final_data,
  value_type = "Padj"
) {
  if (length(value_type) != 1L || !value_type %in% c("Pvalue", "Padj")) {
    stop("Invalid value_type parameter", call. = FALSE)
  }
  choices <- hmap_cluster_choices(final_data)
  id_selection <- paste0("cluster:", final_data$Cluster) %in% term_vec
  legacy_selection <- final_data$Representative_Term %in%
    setdiff(term_vec, unname(choices))
  ids <- final_data$Cluster[id_selection | legacy_selection]
  selected <- cluster_list[cluster_list$Cluster %in% ids, , drop = FALSE]
  if (!nrow(selected)) {
    stop("No matching clusters selected", call. = FALSE)
  }
  selected <- selected[order(match(selected$Cluster, ids)), , drop = FALSE]
  value_cols <- grep(
    paste0("^", value_type, "(_|$)"),
    names(selected),
    value = TRUE
  )
  if (!length(value_cols)) {
    stop("No probability columns available", call. = FALSE)
  }
  values <- as.data.frame(lapply(
    selected[value_cols],
    hmap_numeric_pvalues,
    where = "cluster_hmap"
  ))
  names(values) <- sub(paste0("^", value_type, "_"), "", names(values))
  raw_values <- as.matrix(values)
  clusty <- matrix(
    hmap_display_values(as.vector(raw_values), digits = NULL),
    nrow = nrow(raw_values),
    dimnames = list(NULL, names(values))
  )
  labels <- as.character(selected$Term)
  if (anyDuplicated(labels)) {
    labels <- paste0("Cluster ", selected$Cluster, " | ", labels)
  }
  rownames(clusty) <- make.unique(labels)
  notes <- matrix(
    ifelse(
      is.na(raw_values),
      "Not available",
      ifelse(raw_values == 0, "0 (display floor)", as.character(raw_values))
    ),
    nrow = nrow(raw_values),
    dimnames = dimnames(clusty)
  )
  notes <- matrix(
    paste0(
      "Term: ",
      rownames(clusty)[row(clusty)],
      "<br>Analysis: ",
      colnames(clusty)[col(clusty)],
      "<br>",
      value_type,
      ": ",
      notes,
      "<br>-log10(",
      value_type,
      "): ",
      clusty
    ),
    nrow = nrow(clusty),
    dimnames = dimnames(clusty)
  )
  # heatmaply cannot infer a color domain when every cell is missing.
  # AsIs keeps plotly from mapping the NA matrix through a numeric palette.
  if (all(is.na(clusty))) {
    return(
      plotly::plot_ly(
        x = colnames(clusty),
        y = rownames(clusty),
        z = I(clusty),
        text = notes,
        type = "heatmap",
        hoverinfo = "text",
        hoverongaps = TRUE,
        showscale = FALSE
      ) %>%
        layout(
          title = "No available values",
          plot_bgcolor = "#eeeeee",
          xaxis = list(title = "Analysis"),
          yaxis = list(title = "Term")
        )
    )
  }
  heatmaply(
    clusty,
    row_side_colors = data.frame(
      "Cluster" = as.character(selected$Cluster),
      check.names = FALSE
    ),
    custom_hovertext = notes,
    plot_method = "plotly",
    cluster_rows = FALSE,
    cluster_cols = FALSE,
    Rowv = FALSE,
    Colv = FALSE,
    main = paste0("-log10(", value_type, ") by Term"),
    key.title = paste0("-log10(", value_type, ")"),
    na.value = "#eeeeee"
  )
}
