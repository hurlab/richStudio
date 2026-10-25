# Verified explicit enrichment background (SPEC-WS-005).
#
# The default universe is the annotation universe: the genes the selected annotation
# source assigns to at least one term (for GO, the requested ontology only). An explicit
# background is intersected with that annotation by richR, so it is reported as
# "measured and annotated", never as the complete measured gene list. A custom
# background is offered only when the installed public richR routes forward `universe`
# AND reproduce an independent hypergeometric oracle.

# Public richR entry points that must forward an explicit universe.
enrichment_background_routes <- c("enrich", "richGO", "richKEGG")

# Memoised oracle self-check result (one per session; the installed richR cannot change).
.enrichment_background_state <- new.env(parent = emptyenv())

# Independent upper-tail hypergeometric oracle (base R only, no richR).
# terms: named list of term -> member genes; returns one row per term with a query gene.
enrichment_background_oracle <- function(terms, query, universe, padj.method = "BH") {
  universe <- unique(as.character(universe))
  universe <- universe[!is.na(universe) & !review_is_blank(universe)]
  universe <- universe[universe %in% unlist(terms)]
  query <- unique(as.character(query))
  query <- query[query %in% universe]
  N <- length(universe)
  n <- length(query)
  K <- vapply(terms, function(t) length(intersect(t, universe)), integer(1))
  k <- vapply(terms, function(t) length(intersect(t, query)), integer(1))
  tested <- names(k)[k > 0L]
  p <- stats::phyper(k[tested] - 1L, K[tested], N - K[tested], n, lower.tail = FALSE)
  data.frame(term = tested, N = N, K = unname(K[tested]), n = n, k = unname(k[tested]),
             p = unname(p), padj = stats::p.adjust(p, padj.method), stringsAsFactors = FALSE)
}

# Routes of `ns` that do not take an explicit universe.
enrichment_background_missing_routes <- function(ns) {
  Filter(function(fn) {
    !exists(fn, envir = ns, inherits = FALSE) ||
      !"universe" %in% names(formals(get(fn, envir = ns)))
  }, enrichment_background_routes)
}

# Whether the custom-background control may be offered. Checks the installed public
# routes' formals and replays a tiny oracle through the public generic route; any
# failure leaves the control unavailable with a truthful reason.
enrichment_background_capability <- function(refresh = FALSE) {
  if (!refresh && !is.null(.enrichment_background_state$capability)) {
    return(.enrichment_background_state$capability)
  }
  verdict <- tryCatch({
    if (!requireNamespace("richR", quietly = TRUE)) {
      list(available = FALSE, reason = "richR is not installed.")
    } else {
      missing_routes <- enrichment_background_missing_routes(asNamespace("richR"))
      if (length(missing_routes)) {
        list(available = FALSE, reason = sprintf(
          "The installed richR %s does not accept an explicit universe in: %s.",
          as.character(utils::packageVersion("richR")), paste(missing_routes, collapse = ", ")))
      } else if (!enrichment_background_selfcheck()) {
        list(available = FALSE, reason = sprintf(
          "The installed richR %s did not reproduce the independent hypergeometric check.",
          as.character(utils::packageVersion("richR"))))
      } else {
        list(available = TRUE, reason = NULL)
      }
    }
  }, error = function(e) {
    list(available = FALSE, reason = "The explicit-background check could not run.")
  })
  .enrichment_background_state$capability <- verdict
  verdict
}

# Replays a 5-term fixture through richR::enrich with and without a universe.
enrichment_background_selfcheck <- function(tolerance = 1e-12) {
  g <- function(i) paste0("g", i)
  terms <- list(T1 = g(1:5), T2 = g(3:11), T3 = g(12:14), T4 = g(15:20), T5 = g(16:18))
  query <- g(c(1, 2, 3, 12))
  universe <- c(g(c(1:9, 11:14)), "g1", "ghostU1")
  long <- data.frame(GeneID = unlist(terms), Term = rep(names(terms), lengths(terms)),
                     stringsAsFactors = FALSE)
  one <- function(universe) {
    res <- suppressWarnings(suppressMessages(richR::enrich(
      x = query, object = long, universe = universe, pvalue = 1, minSize = 1,
      minGSSize = 1, maxSize = 500, maxGSSize = 500, keepRich = TRUE, padj.method = "BH")))
    res@result
  }
  agree <- function(universe) {
    expected <- enrichment_background_oracle(terms, query, if (is.null(universe)) unlist(terms) else universe)
    got <- one(universe)
    got <- got[match(expected$term, got$Annot), , drop = FALSE]
    nrow(got) == nrow(expected) && !anyNA(got$Pvalue) &&
      isTRUE(all.equal(expected$p, got$Pvalue, tolerance = tolerance)) &&
      isTRUE(all.equal(expected$padj, got$Padj, tolerance = tolerance))
  }
  isTRUE(agree(NULL)) && isTRUE(agree(universe))
}

# Pasted/uploaded background text -> identifiers, bounded by the input-review policy.
enrichment_background_admit_text <- function(text) {
  admitted <- review_admit_text(text, "background")
  if (!isTRUE(admitted$ok)) return(list(ok = FALSE, message = admitted$message, ids = character()))
  list(ok = TRUE, message = NULL, ids = admitted$tokens)
}

# Genes the annotation assigns to a term; GO is scoped to the requested ontology.
enrichment_background_annotation_ids <- function(annot, anntype, ontology) {
  df <- if (methods::is(annot, "Annot")) annot@annot else annot
  if (!is.data.frame(df) || !"GeneID" %in% names(df)) return(character())
  if (identical(anntype, "GO") && "ONTOLOGYALL" %in% names(df) && !is.null(ontology) && nzchar(ontology)) {
    df <- df[!is.na(df$ONTOLOGYALL) & df$ONTOLOGYALL == ontology, , drop = FALSE]
  }
  ids <- as.character(df$GeneID)
  unique(ids[!review_is_blank(ids)])
}

# Pure review of one (background, query) pair against the annotation universe.
# Identifier matching is exact and case-sensitive, as in richR.
enrichment_background_review <- function(universe, query, annotation_ids) {
  universe <- as.character(universe)
  blank <- review_is_blank(universe)
  valid <- universe[!blank]
  unique_ids <- unique(valid)
  unmapped <- unique_ids[!unique_ids %in% annotation_ids]
  effective <- unique_ids[unique_ids %in% annotation_ids]
  query <- unique(as.character(query))
  query <- query[!review_is_blank(query)]
  query_unmapped <- query[!query %in% annotation_ids]
  excluded <- query[query %in% annotation_ids & !query %in% effective]
  query_effective <- setdiff(query, c(query_unmapped, excluded))
  problems <- character()
  if (!length(effective)) {
    problems <- c(problems, "The background has no genes in the selected annotation.")
  }
  if (length(excluded)) {
    problems <- c(problems, sprintf(
      "%d query gene(s) are annotated but missing from the background: %s",
      length(excluded), enrichment_background_ids_text(excluded)))
  }
  if (!length(effective) || !length(query_effective)) {
    if (!length(excluded)) problems <- c(problems, "No query gene remains in the effective universe.")
  }
  list(
    original_count = length(universe), blank_count = sum(blank),
    unique_count = length(unique_ids), duplicate_count = length(valid) - length(unique_ids),
    unmapped_count = length(unmapped), effective_count = length(effective),
    annotation_count = length(annotation_ids),
    query_count = length(query), query_unmapped_count = length(query_unmapped),
    query_excluded_count = length(excluded), query_excluded_ids = excluded,
    query_effective_count = length(query_effective),
    ok = !length(problems), problems = problems
  )
}

enrichment_background_ids_text <- function(ids, limit = 10L) {
  shown <- utils::head(ids, limit)
  paste0(paste(shown, collapse = ", "), if (length(ids) > limit) sprintf(" (+%d more)", length(ids) - limit) else "")
}

# Stable identity of an explicit background (order- and duplicate-insensitive).
enrichment_background_digest <- function(ids) {
  ids <- as.character(ids)
  digest::digest(sort(unique(ids[!review_is_blank(ids)])), algo = "sha256")
}

# Card lines for one reviewed pair; shown before Run.
enrichment_background_review_lines <- function(review) {
  c(sprintf("Background: %d submitted, %d blank, %d duplicate, %d not annotated",
            review$original_count, review$blank_count, review$duplicate_count, review$unmapped_count),
    sprintf("Effective universe (measured and annotated): %d of %d annotated genes",
            review$effective_count, review$annotation_count),
    sprintf("Query: %d genes, %d not annotated, %d outside the background, %d tested",
            review$query_count, review$query_unmapped_count, review$query_excluded_count,
            review$query_effective_count))
}

# Background identity recorded on a result (counts and a digest, never the gene lists).
# Fields richR does not report stay NA and are named in `unavailable`.
enrichment_background_record <- function(enriched, background = NULL, annotation_ids = NULL,
                                         species = NA_character_, anntype = NA_character_,
                                         keytype = NA_character_, ontology = NA_character_) {
  meta <- tryCatch(richR::enrichmentInfo(enriched), error = function(e) NULL)
  bg <- meta$background
  inp <- meta$input
  explicit <- !is.null(background) && identical(background$mode, "explicit")
  pick <- function(x) if (is.null(x) || !length(x)) NA else x[[1]]
  record <- list(
    mode = if (explicit) "explicit" else "annotation",
    source = if (explicit) "Explicit background (measured and annotated)" else
      "Annotation universe (genes annotated in the selected source)",
    background_digest = if (explicit) enrichment_background_digest(background$ids) else NA_character_,
    submitted_count = if (explicit) length(background$ids) else NA_integer_,
    mapped_size = pick(meta$testing$effective_N),
    unique_count = pick(bg$unique_count), duplicate_count = pick(bg$duplicate_count),
    invalid_count = pick(bg$invalid_count), unmapped_count = pick(bg$unmapped_count),
    query_effective = pick(meta$testing$effective_n),
    query_unmapped_count = length(inp$unmapped_ids),
    query_excluded_count = length(inp$excluded_by_universe_ids),
    query_rule = if (explicit) {
      "Query genes outside the effective universe block the run."
    } else {
      "Query genes without annotation are dropped; the universe is the annotation."
    },
    annotation = list(species = species, anntype = anntype, keytype = keytype, ontology = ontology,
                      annotation_genes = if (is.null(annotation_ids)) NA_integer_ else length(annotation_ids),
                      richR = tryCatch(as.character(utils::packageVersion("richR")), error = function(e) NA_character_))
  )
  not_applicable <- c("annotation", "unavailable", if (!explicit) c("background_digest", "submitted_count"))
  record$unavailable <- names(Filter(function(x) length(x) == 1L && is.na(x),
                                     record[setdiff(names(record), not_applicable)]))
  record
}
