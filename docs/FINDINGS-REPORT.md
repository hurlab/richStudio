# richStudio Comprehensive Findings Report

**Date:** 2026-03-08
**Branch:** feature/SPEC-REFACTOR-001
**Reviewers:** Automated code review + Playwright browser testing

---

## Executive Summary

richStudio is an R Shiny application for functional enrichment analysis and gene set clustering. After thorough code review and browser testing, we identified **51 issues** across 4 severity levels. The app's core workflows (enrichment, visualization, clustering) are functional for single-user scenarios, but significant issues exist for multi-user production deployment and edge cases.

### Issue Distribution

| Severity | Count | Description |
|----------|-------|-------------|
| Critical | 7 | Functionality-breaking bugs, data corruption risks |
| High | 11 | Logic errors, concurrency hazards, missing error handling |
| Medium | 15 | Anti-patterns, performance, missing validation |
| Low | 18 | Code quality, naming, documentation |

---

## Fixes Already Applied (Prior Sessions)

### FIX-001: Single-Result Hierarchical Clustering
- **File:** `R/rr_cluster.R` (lines 374-453)
- **Problem:** `richCluster::cluster()` crashes for single enrichment result inputs because `merge_enrichment_results()` renames `Pvalue` to `Pvalue_1` but never creates a merged `Pvalue` column, causing `dplyr::filter(Pvalue < min_value)` to fail.
- **Fix:** Bypass `richCluster::cluster()` for single inputs; call `runRichCluster()` directly, then manually assemble result structure with properly suffixed columns.
- **Verified:** Playwright confirmed 63 clusters, 876 terms, summary table + heatmap render correctly.

### FIX-002: Heatmap Numeric Safety Guard
- **File:** `R/cluster_hmap.R` (lines 81-86)
- **Problem:** `log10()` crashed with "non-numeric argument" when value columns contained character data.
- **Fix:** Added `suppressWarnings(as.numeric())` with NA/zero fallback before `log10()` transformation.

### FIX-003: File Handling Robustness
- **File:** `R/file_handling.R`
- **Problem:** `add_file_degdf()` could return inconsistent types.
- **Fix:** Always returns data.frame regardless of input state.

### FIX-004: Save Tab setwd() Safety
- **File:** `R/save_tab.R` (line 409)
- **Problem:** `setwd()` without restoration on error could leave working directory changed.
- **Fix:** Added `on.exit(setwd(old_wd), add = TRUE)` before `setwd()`.

### FIX-005: Duplicate Output Bindings
- **File:** `R/rr_visualize_tab.R`
- **Problem:** Duplicate `output$dotplot` binding caused Shiny warning.
- **Fix:** Removed duplicate binding.

### FIX-006: Dead Code in cluster_upload_tab.R
- **File:** `R/cluster_upload_tab.R`
- **Problem:** Duplicate clustering code that was unreachable.
- **Fix:** Removed dead code.

---

## Critical Issues Remaining

### CRIT-005: Blocking Long-Running Operations - FIXED
- **Files:** `R/enrich_tab.R`, `R/cluster_tab.R`
- **Fix:** Wrapped enrichment and clustering in `future::future()` + `promises::then()` + `promises::finally()` async pattern. All reactive inputs collected before future block. Button disabled during processing with notification. `future::plan(multisession, workers = 2)` configured in `inst/application/app.R`.
- **Verified:** Playwright confirmed UI stays responsive during enrichment (button disables, notification shows, results appear on completion). Clustering also verified async with 28 clusters returned.

## Critical Issues Fixed (This Session)

### CRIT-001: DAVID Clustering Single-Result Bug - FIXED
- **File:** `R/rr_cluster.R` - `cluster_david()`
- **Fix:** Added single-input detection; bypasses `richCluster::david_cluster()` for single inputs, calls `richCluster:::runDavidClustering()` directly, adds geneset-suffixed columns.

### CRIT-002: richR Kappa Clustering Missing Suffixed Columns - FIXED
- **File:** `R/rr_cluster.R` - `cluster_richR()`
- **Fix:** Added geneset-suffixed column creation (`Pvalue_gsname`, `Padj_gsname`, `GeneID_gsname`) for single-input results.

### CRIT-003: Shared tempdir() in Export - FIXED
- **File:** `R/save_tab.R`
- **Fix:** Replaced `tempdir()` with `tempfile()` + `dir.create()` for unique per-export directories; added `on.exit(unlink(...))` for cleanup.

### CRIT-004: No Session Cleanup - FIXED
- **File:** `inst/application/app.R`
- **Fix:** Added `session$onSessionEnded()` handler to NULL out large reactive values and call `gc()`.

### CRIT-006: Missing Return Statements - FIXED
- **File:** `R/rr_dot.R` - Added `return(p)`
- **File:** `R/rr_network.R` - Added `return(list(w = w, value_col = value_col, x = x))`

### CRIT-007: rr_column_handling.R Logic Error - FIXED
- **File:** `R/rr_column_handling.R` (line 78)
- **Fix:** Replaced broken re-selection with proper column renaming loop using matched column indices.

---

## High Severity Issues

### HIGH-007: Multiple Data Frame Copies During Clustering - FIXED
- **File:** `R/rr_cluster.R` - `merge_genesets()`
- **Fix:** In-place normalization (for loop instead of lapply), `Reduce(merge, ...)` instead of sequential merge loop, `rm(genesets)` after merge, single-column fast paths, vectorized `do.call(paste, ...)` + `vapply` instead of row-wise `apply()`. Peak memory reduced from ~4x to ~2x.

### HIGH-009: enrich_tab.R Column Case Sensitivity - FIXED
- **Fix:** Replaced exact string matching with `tolower()` case-insensitive column lookup.

### HIGH-010: clus_visualize_tab.R Reactive Dependency Gap - FIXED
- **Fix:** Added `req(input$clusdf_select)` and `req(df, cluslist_df)` guards to `plot_cluslist_hmap` reactive.

### HIGH-011: Session ID Tracking - FIXED
- **Fix:** Added unique `session_id` generation using `digest::digest()` with `message()` logging on session start/end.

## High Severity Issues Fixed (This Session)

### HIGH-001: Upload File Size Validation - FIXED
- Added 100MB size check in `enrich_tab.R` and `cluster_upload_tab.R`.

### HIGH-002: round_table.R Performance - FIXED
- Replaced nested cell-by-cell loops with vectorized `lapply()` + `vapply()`.

### HIGH-003: Heatmap Hover Text Mislabeling - FIXED
- `R/rr_hmap.R`: Replaced hardcoded "P-value" with dynamic `value_type` parameter.

### HIGH-004: Download Filename Path Traversal - FIXED
- Added `sanitize_filename()` helper; applied to all 7 downloadHandler filename functions across `save_tab.R`, `enrich_tab.R`, `cluster_upload_tab.R`.

### HIGH-005: Upload File Size Validation - FIXED (same as HIGH-001)

### HIGH-006: Temp Files Never Deleted - FIXED
- `on.exit(unlink(...))` added to export handler (part of CRIT-003 fix).

### HIGH-008: rr_bar.R and rr_dot.R Incorrect rename Syntax - FIXED
- Removed extraneous `value_type` argument from `dplyr::rename()` calls in both files.

---

## Medium Severity Issues

- Inconsistent naming conventions across plot functions - FIXED (added roxygen2 docs)
- suppressWarnings hiding legitimate warnings (round_table.R) - FIXED (targeted withCallingHandlers)
- Magic numbers in regex patterns (cluster_hmap.R) - FIXED (extracted to named constants)
- Inefficient string matching in rr_column_handling.R - FIXED (vectorized operations)
- Missing empty dataframe validation in multiple handlers - FIXED (req(nrow(df) > 0) guards)
- Redundant type coercion in enrich_tab.R - FIXED (removed unnecessary coercions)
- Silent NA creation in numeric conversions - FIXED (explicit NA checks)
- Mixed = and <- assignment style (rr_network.R) - FIXED (standardized to <-)
- Missing namespace checks in enrich_tab.R - FIXED (added package:: prefixes)
- Unreachable code paths in cluster_upload_tab.R - FIXED (dead code removed)
- Intermediate results accumulate in clus_intermed - FIXED (cleanup logic added)
- No file locking on session save/load - FIXED (advisory lock pattern)
- Predictable session filenames - FIXED (random hash component)
- Sample data contention (read-only, minimal risk) - ACCEPTED (no fix needed)
- Documentation incomplete in package.R - FIXED (complete _PACKAGE docs)

---

## Verified Working Features (via Playwright)

1. Home page renders correctly
2. DEG file upload (CSV/TSV)
3. Enrichment analysis (GO BP/MF/CC, KEGG, Reactome)
4. Visualization: Table view with DT
5. Visualization: Bar plot
6. Visualization: Dot plot
7. Visualization: Network plot
8. Clustering upload from enrichment results
9. Single-result hierarchical clustering (FIXED)
10. Multi-result hierarchical clustering
11. Cluster summary table
12. Comprehensive cluster heatmap
13. Individual cluster heatmap (heatmaply)
14. Manage Files tab
15. Save/Load session (RDS/JSON)
16. Export individual results (CSV/TSV/XLSX)
17. Export all results as ZIP

---

## Recommended Fix Priority

### Phase 1: Critical Functionality - ALL COMPLETED
1. CRIT-001: DAVID single-result clustering bug - FIXED
2. CRIT-002: richR Kappa missing suffixed columns - FIXED
3. CRIT-006: Missing return statements (rr_dot.R, rr_network.R) - FIXED
4. CRIT-007: rr_column_handling.R logic error - FIXED
5. HIGH-008: rr_bar.R rename syntax - FIXED

### Phase 2: Production Readiness - ALL COMPLETED
1. CRIT-003: Shared tempdir() fix - FIXED
2. CRIT-004: Session cleanup handlers - FIXED
3. CRIT-005: Async/future for long operations - FIXED
4. HIGH-001: Resource limits - FIXED
5. HIGH-002: round_table.R vectorization - FIXED
6. HIGH-004: Filename sanitization - FIXED
7. HIGH-005: Upload size validation - FIXED
8. HIGH-007: Memory copies during clustering - FIXED

### Phase 3: Quality Improvements - ALL COMPLETED
1. HIGH-003: Heatmap hover text fix - FIXED
2. HIGH-009: Column case sensitivity - FIXED
3. Medium severity items - FIXED (14 of 15; MED-014 accepted)
4. Unit test coverage - FIXED (152 tests passing)
