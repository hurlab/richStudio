# SPEC-FIX-005: Async Operations & Memory Optimization

## Problem Statement

### CRIT-005: Blocking Long-Running Operations
Enrichment analysis (5-30s per DEG set) and clustering (10-60s) run synchronously on
the main Shiny thread. While one user runs these operations, ALL other users are blocked
from any interaction.

### HIGH-007: Memory Copies During Clustering
`merge_genesets()` creates 3-4x copies of the original data through:
- `lapply(genesets, normalize_geneset)` creates copy of each geneset
- Sequential `base::merge()` loop creates new dataframe per iteration
- Row-wise `apply()` for GeneID combination creates intermediate copies

## Design

### CRIT-005 Solution: future + promises

**Architecture:**
```
User clicks "Enrich" or "Cluster"
  → Collect all inputs from reactive values (must happen on main thread)
  → Disable button via shinyjs
  → Show notification "Processing..."
  → Launch future::future({...}) with collected inputs
  → Main thread returns to Shiny event loop (unblocked)
  → Background R worker executes heavy computation
  → On completion: promise resolves → update reactive values → re-enable button
  → On error: promise rejects → show error notification → re-enable button
```

**Why this works:**
- All inputs to shiny_enrich() and perform_clustering() are plain R objects
  (character vectors, data frames, parameter lists) - fully serializable
- richR/bioAnno/richCluster are pure R + Rcpp with no session state
- Rcpp .Call bindings work identically in worker processes
- Promise callbacks run in the Shiny session context, so reactive updates work

**Key constraint:** Reactive values cannot be read inside future(). All reactive
inputs must be extracted BEFORE entering the future block.

**Changes required:**
1. DESCRIPTION: Add future, promises to Imports
2. inst/application/app.R: Add `future::plan(multisession, workers = 2)` at startup
3. R/enrich_tab.R: Wrap enrichment loop in future + promise chain
4. R/cluster_tab.R: Wrap clustering in future + promise chain

**Enrichment async pattern (enrich_tab.R):**
```r
observeEvent(input$enrich_deg, {
  req(input$degs_to_enrich)

  # 1. Collect ALL inputs before future (reactive reads happen here)
  deg_inputs <- lapply(input$degs_to_enrich, function(name) {
    x <- u_degdfs[[name]]
    big_df <- u_big_degdf[['df']]
    gene_hdr <- big_df[big_df$name %in% name, "GeneID_header"]
    list(name = name, df = x, gene_header = gene_hdr)
  })
  species <- input$species_select
  anntype <- as.character(input$anntype_select)
  keytype <- as.character(input$keytype_select)
  ontology <- as.character(input$ont_select)
  cutoff <- input$deg_filter_cutoff
  if (is.null(cutoff) || is.na(cutoff)) cutoff <- 0.05

  # 2. Disable button, show notification
  shinyjs::disable("enrich_deg")
  showNotification("Enrichment analysis running in background...",
                   id = "enrich_progress", duration = NULL, type = "message")

  # 3. Launch future (runs in background R process)
  p <- future::future({
    results <- list()
    for (i in seq_along(deg_inputs)) {
      inp <- deg_inputs[[i]]
      x_use <- inp$df

      # Gene filtering (same logic as before, but outside reactive context)
      col_lower <- tolower(colnames(x_use))
      padj_idx <- which(col_lower == "padj")
      pval_idx <- which(col_lower == "pvalue")
      if (length(padj_idx) > 0) {
        padj_col <- colnames(x_use)[padj_idx[1]]
        x_use <- x_use[!is.na(x_use[[padj_col]]) & x_use[[padj_col]] < cutoff, , drop = FALSE]
      } else if (length(pval_idx) > 0) {
        pval_col <- colnames(x_use)[pval_idx[1]]
        x_use <- x_use[!is.na(x_use[[pval_col]]) & x_use[[pval_col]] < cutoff, , drop = FALSE]
      }
      if (nrow(x_use) == 0) x_use <- inp$df

      enriched <- shiny_enrich(x = x_use, header = inp$gene_header,
                               species = species, anntype = anntype,
                               keytype = keytype, ontology = ontology)
      results[[i]] <- list(name = inp$name, result = enriched@result,
                           anntype = anntype, keytype = keytype,
                           ontology = ontology, species = species)
    }
    results
  }, seed = TRUE)

  # 4. Handle promise resolution (runs in session context)
  promises::then(p,
    onFulfilled = function(results) {
      for (res in results) {
        lab <- paste0(res$name, "_enriched")
        u_rrdfs[[lab]] <- res$result
        u_rrnames$labels <- unique(c(u_rrnames$labels, lab))
        u_big_rrdf[['df']] <- add_file_rrdf(u_big_rrdf[['df']],
          name = res$name, annot = res$anntype, keytype = res$keytype,
          ontology = res$ontology, species = res$species, file = FALSE)
      }
      removeNotification("enrich_progress")
      showNotification(paste(length(results), "DEG set(s) enriched successfully!"),
                       type = "message")
    },
    onRejected = function(err) {
      removeNotification("enrich_progress")
      showNotification(paste("Enrichment error:", conditionMessage(err)),
                       type = "error", duration = 10)
    }
  )

  # 5. Re-enable button (in both success and error paths)
  promises::finally(p, function() {
    shinyjs::enable("enrich_deg")
  })

  # Return NULL so Shiny knows this observer is async
  NULL
})
```

**Clustering async pattern (cluster_tab.R):**
Same structure: collect inputs → disable button → future({perform_clustering(...)})
→ then(update reactive values) → finally(re-enable button)

### HIGH-007 Solution: Optimize merge_genesets()

**Current problem (rr_cluster.R merge_genesets()):**
```r
# Copy 1: normalize each geneset
genesets <- lapply(genesets, normalize_geneset)
# Copy 2: rename columns (modifies copies)
for (i in ...) colnames(genesets[[i]]) <- ...
# Copy 3+: sequential merge loop
for (i in 2:length(genesets)) {
  merged_gs <- base::merge(merged_gs, genesets[[i]], by = 'Term', all = TRUE)
}
# Copy 4: row-wise apply for GeneID
merged_gs$GeneID <- apply(..., 1, function(x) paste(unique(...)))
```

**Optimized approach:**
1. Normalize in-place (modify the list elements directly, avoid lapply copy)
2. Replace sequential merge loop with Reduce(merge, ...)
3. Replace row-wise apply for GeneID with vectorized paste + strsplit
4. Drop intermediate geneset copies after merge

```r
merge_genesets <- function(genesets) {
  # Normalize in-place (modify list elements)
  for (i in seq_along(genesets)) {
    genesets[[i]] <- normalize_geneset(genesets[[i]])
  }

  # Rename columns with geneset suffix
  for (i in seq_along(genesets)) {
    cols <- colnames(genesets[[i]])
    term_idx <- which(cols == 'Term')
    cols[-term_idx] <- paste(cols[-term_idx], names(genesets)[i], sep = "_")
    colnames(genesets[[i]]) <- cols
  }

  # Single-pass merge using Reduce (avoids sequential copy chain)
  if (length(genesets) == 1) {
    merged_gs <- genesets[[1]]
  } else {
    merged_gs <- Reduce(function(a, b) base::merge(a, b, by = 'Term', all = TRUE),
                        genesets)
  }

  # Free original geneset copies
  rm(genesets)

  # Vectorized GeneID combination (avoid row-wise apply)
  geneid_cols <- grep("^GeneID_", colnames(merged_gs), value = TRUE)
  if (length(geneid_cols) > 0) {
    merged_gs$GeneID <- do.call(paste, c(merged_gs[geneid_cols], sep = ","))
    merged_gs$GeneID <- gsub("NA,|,NA", "", merged_gs$GeneID)
    merged_gs$GeneID <- gsub("^,|,$", "", merged_gs$GeneID)
    # Deduplicate genes per row
    merged_gs$GeneID <- vapply(strsplit(merged_gs$GeneID, ","), function(x) {
      paste(unique(x[x != "" & x != "NA"]), collapse = ",")
    }, character(1))
  }

  # ... rest of function (Annot, Pvalue, Padj combination) ...
}
```

**Memory reduction:**
- Before: ~4x peak memory (normalize copies + merge copies + apply intermediates)
- After: ~2x peak memory (Reduce creates fewer intermediates, rm frees early)

## Verification Plan
1. Parse check: All modified files must parse without error
2. Manual test: Start app, upload DEG, run enrichment → verify UI stays responsive
3. Manual test: Run clustering → verify UI stays responsive during computation
4. Manual test: Two browser tabs simultaneously → verify no cross-session blocking
5. Memory check: Run clustering on large dataset, monitor peak RSS

## Files Modified
- DESCRIPTION (add future, promises)
- inst/application/app.R (future::plan setup)
- R/enrich_tab.R (async enrichment)
- R/cluster_tab.R (async clustering)
- R/rr_cluster.R (merge_genesets optimization)
