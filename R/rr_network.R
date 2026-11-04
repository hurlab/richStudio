#' Create a network plot from enrichment results
#'
#' Thin wrapper around \code{ggnetwork} that generates a gene-concept network
#' from enrichment results. Optionally accepts a DEG data frame for gene-level
#' annotation.
#'
#' This function follows the \code{rr_} naming convention used across richStudio
#' plot functions, where \code{rr} stands for "rich result" (enrichment result).
#' The name is referenced by Shiny UI modules and must not be renamed without
#' updating all call sites.
#'
#' @param rr An enrichment result object compatible with \code{ggnetwork}.
#' @param deg Optional. A DEG data frame or gene vector. When \code{NULL},
#'   gene IDs are the union of the comma-separated genes of all terms in
#'   \code{rr$GeneID}.
#' @return A ggplot network object.
rr_network <- function(rr, deg = NULL) {
  if (is.null(deg)) {
    if (!"GeneID" %in% colnames(rr)) {
      stop("rr must contain a GeneID column when deg is NULL")
    }
    # GeneID holds one comma-joined string per term; ggnetwork needs the genes
    deg <- trimws(unlist(strsplit(as.character(rr$GeneID), ",", fixed = TRUE)))
    deg <- unique(deg[!is.na(deg) & nzchar(deg)])
  }
  net <- ggnetwork(object = rr, gene = deg)
  rr_network_legible(net, rr)
}

# Label size of the network figure in ggplot2 millimetres: 3.2 mm is about 12 px.
network_label_size_mm <- 3.2

# Labels are drawn for this many most significant terms; every node stays drawn.
network_label_count <- 15L

# Legibility changes only: larger labels on the most significant terms, a
# colour-blind-safe (viridis) colour legend and a caption. The node set, the edges
# and the node data are those of the unchanged network; only the colour scale and
# the label layer's text changes (labels of the other terms are blank).
rr_network_legible <- function(net, rr = NULL) {
  if (!inherits(net, "ggplot")) {
    return(net)
  }
  nodes <- net$data
  p_column <- if (is.data.frame(rr)) intersect(c("Padj", "Pvalue"), names(rr))[1L] else NA_character_
  has_p <- is.data.frame(nodes) && all(c("color", "label") %in% names(nodes)) &&
    nrow(nodes) > 0L && !is.na(p_column)
  p <- if (has_p) {
    suppressWarnings(as.numeric(rr[[p_column]][match(nodes$label, rr$Term)]))
  } else {
    numeric()
  }
  for (i in seq_along(net$layers)) {
    if (inherits(net$layers[[i]]$geom, "GeomTextRepel")) {
      net$layers[[i]]$aes_params$size <- network_label_size_mm
      if (has_p && any(!is.na(p)) && nrow(nodes) > network_label_count) {
        keep <- order(p, na.last = TRUE)[seq_len(network_label_count)]
        labels <- net$layers[[i]]$aes_params$label
        if (length(labels) == nrow(nodes)) {
          shown <- rep(FALSE, nrow(nodes))
          shown[keep] <- TRUE
          labels[!shown] <- ""
          net$layers[[i]]$aes_params$label <- labels
        }
      }
    }
  }
  caption <- "Each node is a term; node size grows with the number of genes in the term."
  if (has_p && any(!is.na(p))) {
    colours <- as.character(nodes$color)
    levels_in_use <- unique(colours)
    significance <- -log10(pmax(p, .Machine$double.xmin))
    significance[is.na(significance)] <- min(significance, na.rm = TRUE)
    span <- diff(range(significance))
    scaled <- if (span > 0) (significance - min(significance)) / span else rep(1, length(significance))
    palette <- grDevices::hcl.colors(256L, "viridis")
    # More significant terms are dark, less significant terms bright. Each original
    # colour level keeps one viridis colour (that of its most significant node).
    level_colour <- vapply(
      levels_in_use,
      function(level) {
        best <- max(scaled[colours == level])
        palette[1L + round(255 * (1 - best))]
      },
      character(1)
    )
    most <- levels_in_use[[which.max(vapply(levels_in_use, function(l) max(scaled[colours == l]), numeric(1)))]]
    least <- levels_in_use[[which.min(vapply(levels_in_use, function(l) max(scaled[colours == l]), numeric(1)))]]
    net <- net +
      suppressMessages(ggplot2::scale_colour_manual(
        name = "Node colour",
        values = level_colour,
        breaks = unique(c(most, least)),
        labels = if (identical(most, least)) {
          "Term"
        } else {
          c("More significant term", "Less significant term")
        },
        guide = ggplot2::guide_legend(override.aes = list(size = 4))
      )) +
      ggplot2::guides(
        colour = ggplot2::guide_legend(title = "Node colour", override.aes = list(size = 4)),
        size = "none"
      )
    if (nrow(nodes) > network_label_count) {
      caption <- paste0(
        "Labels shown for the ", network_label_count, " most significant terms. ", caption
      )
    }
  }
  net + ggplot2::labs(caption = caption) + ggplot2::theme(legend.position = "right")
}

#' Compute a weighted term-term similarity network (WIP)
#'
#' Custom implementation of a gene-overlap-based network for enrichment terms.
#' Computes pairwise term similarity weights based on shared genes and their
#' significance. Returns the weight matrix and filtered enrichment data.
#'
#' Note: This function uses \code{my_} prefix as an informal convention
#' for work-in-progress internal helpers. It does not follow the \code{rr_}
#' prefix convention used by the main exported plot functions.
#'
#' @param x A data frame of enrichment results containing columns: Term,
#'   GeneID, Significant, and the column specified by \code{value_type}.
#' @param gene A DEG data frame (with \code{padj} column and gene row names)
#'   or a character vector of gene identifiers.
#' @param top Integer. Maximum number of top terms to include. Default 50.
#' @param value_cutoff Numeric. P-value cutoff for filtering. Default 0.05.
#' @param value_type Character. Column name for significance values.
#'   Default \code{"Padj"}.
#' @param weight_cutoff Numeric. Minimum weight threshold (currently unused
#'   inside this function but reserved for downstream filtering). Default 0.2.
#' @param sep Character. Separator for gene IDs in the GeneID column.
#'   Default \code{","}.
#' @return A list with components: \code{w} (numeric matrix of pairwise
#'   weights), \code{value_col} (named numeric vector of -log10 values),
#'   and \code{x} (filtered enrichment data frame).
my_net <- function(
  x,
  gene,
  top = 50,
  value_cutoff = .05,
  value_type = "Padj",
  weight_cutoff = .2,
  sep = ","
) {
  x <- filter(x, x[, value_type] < value_cutoff)
  x <- arrange(x, value_type) # order by ascending padj/pval

  # Filter out top terms
  if (nrow(x) > top) {
    x <- x[1:top, ]
  }

  # Get gene pvalues if dataframe supplied
  if (is.data.frame(gene)) {
    gene_p <- -log10(gene$padj)
    names(gene_p) <- rownames(gene)
  } else {
    gene_p <- rep(1, length(gene))
    names(gene_p) <- gene
  }
  value_col <- -log10(x[, value_type])
  names(value_col) <- rownames(x)

  go2gen <- strsplit(x = as.vector(x$GeneID), split = sep)
  names(go2gen) <- rownames(x)
  # Keep the richR private provider used by its network implementation.
  gen2go <- utils::getFromNamespace("reverseList", "richR")(go2gen)
  golen <- x$Significant
  names(golen) <- rownames(x)
  gen2golen <- lapply(gen2go, function(x) golen[x])
  gen2gosum <- lapply(gen2golen, function(x) sum(x) / x)
  gen2res <- lapply(gen2gosum, function(x) x / sum(x))
  id <- rownames(x)
  n <- nrow(x)
  w <- matrix(NA, nrow = n, ncol = n)
  colnames(w) <- rownames(w) <- rownames(x)
  for (i in 1:n) {
    ni <- id[i]
    for (j in i:n) {
      nj <- id[j]
      genein <- intersect(go2gen[[ni]], go2gen[[nj]])
      geneup <- sum(
        gene_p[genein] *
          unlist(lapply(
            lapply(
              gen2res[genein],
              "[",
              c(ni, nj)
            ),
            sum
          ))
      )
      genei <- setdiff(go2gen[[ni]], go2gen[[nj]])
      genej <- setdiff(go2gen[[nj]], go2gen[[ni]])
      geneid <- sum(
        gene_p[genei] *
          unlist(lapply(
            lapply(
              gen2res[genei],
              "[",
              ni
            ),
            sum
          ))
      )
      genejd <- sum(
        gene_p[genej] *
          unlist(lapply(
            lapply(
              gen2res[genej],
              "[",
              nj
            ),
            sum
          ))
      )
      gened <- geneup + geneid + genejd
      w[i, j] <- geneup / gened
    }
  }
  colnames(w) <- rownames(w) <- x$Term
  names(value_col) <- x$Term
  rownames(x) <- x$Term

  list(w = w, value_col = value_col, x = x)
}

# Historical inactive example: see the rr_network.R section in
# The reference is in `docs/development/historical-r-examples.md`.
