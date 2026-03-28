# richStudio Project Handoff

## 1. Project Overview

richStudio is an R Shiny application for functional enrichment analysis and gene set clustering. It provides DEG file upload, enrichment analysis (GO, KEGG, Reactome via richR/bioAnno), multiple visualization modes (table, bar, dot, network, heatmap), three clustering algorithms (richR Kappa, Hierarchical via richCluster, DAVID-style), session save/load (RDS/JSON), and export (CSV/TSV/XLSX/ZIP).

- **Last updated:** 2026-03-28 CDT
- **Last coding CLI used:** Claude Code CLI (claude-opus-4-6)
- **Branch:** main
- **Version:** 0.1.6

## 2. Current State

### Phase 1: Critical Bug Fixes — Completed 2026-03-08
- Single-result hierarchical clustering bypass for richCluster::cluster() bug
- DAVID single-result clustering bypass
- richR Kappa suffixed column creation
- Heatmap numeric safety guard (log10 non-numeric)
- File handling robustness (add_file_degdf)
- Save tab setwd() safety (on.exit)
- Duplicate output bindings (rr_visualize_tab.R)
- Dead code removal (cluster_upload_tab.R)

### Phase 2: Visualization Fixes — Completed 2026-03-08
- rr_dot.R: Added missing return(p), fixed dplyr::rename syntax
- rr_bar.R: Fixed dplyr::rename syntax (extra argument)
- rr_network.R: Added return statement for my_net()
- rr_hmap.R: Dynamic value_type in hover text (was hardcoded "P-value")
- rr_column_handling.R: Fixed column selection logic error at line 78
- round_table.R: Vectorized cell-by-cell loops for performance

### Phase 3: Production Readiness — Completed 2026-03-08
- Session-isolated temp directories (tempfile() instead of tempdir())
- Session cleanup handler (onSessionEnded with gc())
- Filename sanitization across all downloadHandlers
- Upload file size validation (100MB limit)
- Temp file cleanup via on.exit(unlink())

### Phase 4: Remaining High-Priority Fixes — Completed 2026-03-08
- Column case sensitivity fix (enrich_tab.R - tolower matching for padj/pvalue)
- Reactive dependency gap fix (clus_visualize_tab.R - added req guards)
- Session ID tracking (app.R - unique session_id with digest)

### Phase 5: Async Operations & Memory Optimization — Completed 2026-03-08
- CRIT-005: Non-blocking enrichment via future::future() + promises::then() (enrich_tab.R)
- CRIT-005: Non-blocking clustering via same async pattern (cluster_tab.R)
- HIGH-007: merge_genesets() memory optimization (rr_cluster.R) - peak memory ~4x to ~2x
- DESCRIPTION: Added future, promises to Imports
- inst/application/app.R: future::plan(multisession, workers = 2) at startup

### Phase 6: Reactive Value Anti-pattern Fix — Completed 2026-01-08
- Eliminated <<- anti-patterns in reactive contexts
- SPEC-REFACTOR-001 created and implemented

### Phase 7: Medium Severity Fixes & Test Suite — Completed 2026-03-09
- **MED-001**: Inconsistent naming — added roxygen2 documentation to all plot functions
- **MED-002**: suppressWarnings — replaced blanket suppression with targeted withCallingHandlers in round_table.R and cluster_hmap.R
- **MED-003**: Magic numbers — extracted regex patterns and numeric constants to named variables in cluster_hmap.R
- **MED-004**: Inefficient string matching — optimized rr_column_handling.R with vectorized match()/%in%
- **MED-005**: Missing empty dataframe validation — added req(nrow(df) > 0) guards in visualization handlers
- **MED-006**: Redundant type coercion — removed unnecessary as.numeric()/as.character() in enrich_tab.R
- **MED-007**: Silent NA creation — added explicit NA checks with warnings in numeric conversions
- **MED-008**: Mixed assignment style — standardized rr_network.R to <- throughout
- **MED-009**: Missing namespace checks — added package:: prefixes for external functions in enrich_tab.R
- **MED-010**: Unreachable code — removed dead code paths in cluster_upload_tab.R
- **MED-011**: clus_intermed accumulation — added cleanup logic in cluster_tab.R
- **MED-012**: File locking — added advisory lock pattern for session save/load in save_tab.R
- **MED-013**: Predictable filenames — session files now include random hash component
- **MED-014**: Sample data contention — accepted as-is (read-only, minimal risk)
- **MED-015**: package.R documentation — complete roxygen2 docs with _PACKAGE pattern
- **NAMESPACE**: Regenerated via roxygen2 — added 7 missing exports (file_handling functions)
- **renv.lock**: Synchronized — added future, globals, listenv, parallelly, roxygen2
- **Test suite**: Rewrote all broken tests — 152 tests pass (0 fail, 0 warn, 0 skip)

## 3. Execution Plan Status

| Phase | Status | Last Updated |
|-------|--------|-------------|
| Phase 1: Critical Bug Fixes | Completed | 2026-03-08 |
| Phase 2: Visualization Fixes | Completed | 2026-03-08 |
| Phase 3: Production Readiness | Completed | 2026-03-08 |
| Phase 4: Remaining High Fixes | Completed | 2026-03-08 |
| Phase 5: Async & Memory | Completed | 2026-03-08 |
| Phase 6: Reactive Refactor | Completed | 2026-01-08 |
| Phase 7: Medium Fixes & Tests | Completed | 2026-03-09 |
| Phase 8: Second Review Round | Completed | 2026-03-10 |
| Phase 9: UI/UX Modernization | Completed | 2026-03-28 |
| Phase 10: UI Audit & Polish (v0.1.6) | Completed | 2026-03-28 |

All Critical (CRIT-001 through CRIT-007), High (HIGH-001 through HIGH-011), and Medium (MED-001 through MED-015) issues are resolved.

### Phase 8: Second Review Round Fixes — Completed 2026-03-10
- **A1**: Added missing `digest` dependency to DESCRIPTION Imports
- **A2**: Removed `library(knitr)` from round_table.R (bad practice in package code)
- **A3**: Added missing `slice_head` to dplyr importFrom in NAMESPACE
- **B1**: Added NULL guard for `u_big_degdf[['df']]` in enrich_tab.R async handler
- **B2**: Fixed division-by-zero risk in rr_bar.R and rr_dot.R (Annotated=0 case)
- **B3**: Fixed ineffective session cleanup (was assigning NULL to local vars, not reactive objects)
- **B4**: Removed 7 unused `dataTableProxy()` variables across 5 files
- **B5**: Added error for invalid `view` parameter in rr_bar.R
- **B6**: Removed dead test file (compare_david_clustering.R)

### Phase 9: UI/UX Modernization — Completed 2026-03-28
- CSS design token system (23 variables), consistent component styling
- Sidebar flexbox layout with sticky footer (Hur Lab link always visible)
- Landing page condensed to single viewport (3-column layout)
- Fixed logo SVG truncation, bookmark button restyled as menu item
- Deduplicated box headings on visualization tabs
- Fixed "Not currently supported" help text on cluster visualize

### Phase 10: UI Audit & Polish (v0.1.6) — Completed 2026-03-28
- Breadcrumb navigation in top navbar showing current section/page
- Favicon icon in sidebar logo via CSS pseudo-element
- Fixed browser tab title (was showing raw HTML)
- Empty-state placeholders on visualization pages when no data loaded
- Standardized all page titles to h2 with consistent 22px/700 sizing
- Cluster tab: changed from solidHeader box to plain h2 + box layout
- Consistent h4 sizing (16px/600) inside box bodies across all pages
- Tightened home page bottom spacing and empty-state padding
- Version bumped to 0.1.6

## 4. Outstanding Work

### Remaining Items
- **MED-014**: Sample data contention — accepted risk (read-only access, no fix needed)
- **CI/CD**: No GitHub Actions or CI pipeline configured (recommended for production)

## 5. Risks, Open Questions, and Assumptions

### Multi-user concurrency under heavy load — Mitigated
- **Status:** Mitigated
- **Resolution:** future::plan(multisession, workers = 2) handles async. For heavy production load, deploy with ShinyProxy or Shiny Server for full isolation.

### richR/richCluster package stability — Open
- **Status:** Open
- **Default assumption:** These packages are stable for current use cases. Single-input edge cases bypassed with direct internal function calls.

### Bioconductor annotation package availability — Open
- **Status:** Open
- **Default assumption:** org.Hs.eg.db, org.Mm.eg.db must be pre-installed. App shows informational messages if missing.

## 6. Verification Status

### Verified
| Feature | Method | Result | Date |
|---------|--------|--------|------|
| All R files parse (21/21) | Rscript -e "parse()" | All OK | 2026-03-09 |
| Unit test suite | testthat::test_dir() | 152 pass, 0 fail, 0 warn | 2026-03-09 |
| App startup | devtools::load_all + source app.R | ui and server objects created | 2026-03-09 |
| Home page renders | Playwright snapshot | All navigation visible | 2026-03-09 |
| Enrichment tab renders | Playwright snapshot | Full UI with all controls | 2026-03-09 |
| HTTP health check | curl localhost:3839 | HTTP 200 | 2026-03-09 |
| Async enrichment | Playwright browser test | 118 GO BP terms returned | 2026-03-08 |
| Async clustering | Playwright browser test | 28 clusters returned | 2026-03-08 |
| End-to-end flow | Playwright browser test | Enrichment to clustering | 2026-03-08 |
| 17 core features | Playwright browser test | All pass | 2026-03-08 |
| NAMESPACE exports | roxygen2::roxygenise() | All functions exported | 2026-03-09 |
| renv sync | renv::snapshot() | All deps recorded | 2026-03-09 |

## 7. Restart Instructions

**Starting point:** All severity levels resolved. App is production-ready with comprehensive test coverage.

**Recommended next actions:**
1. Merge feature/SPEC-REFACTOR-001 to main
2. Consider adding GitHub Actions CI for automated testing
3. Consider adding Dockerfile for containerized deployment

**Key files for context:**
- `docs/FINDINGS-REPORT.md` — Complete 51-issue catalogue with fix status
- `docs/specs/SPEC-FIX-006-test-suite-rewrite.md` — Test rewrite design spec
- `docs/specs/SPEC-FIX-007-medium-severity-items.md` — Medium severity fixes spec
- `R/rr_cluster.R` — Most complex file, core clustering logic
- `R/enrich_tab.R` — Enrichment module with async pattern
- `R/cluster_tab.R` — Clustering module with async pattern

**Last updated:** 2026-03-09 CDT

## Key Files
- `inst/application/app.R` — Main entry point
- `R/rr_cluster.R` — Core clustering logic (most complex)
- `R/cluster_tab.R` — Clustering UI/server module
- `R/clus_visualize_tab.R` — Cluster visualization module
- `R/enrich_tab.R` — Enrichment analysis module
- `R/cluster_hmap.R` — Cluster heatmap functions
- `R/save_tab.R` — Session save/load with file locking
- `R/file_handling.R` — File tracking functions (7 exported functions)
- `R/package.R` — Package documentation (_PACKAGE pattern)
- `tests/testthat/` — 6 test files, 152 test cases
- `docs/FINDINGS-REPORT.md` — Complete findings with 51 issues catalogued

## Dependencies
- richR, richCluster (custom packages for enrichment/clustering)
- Bioconductor annotation packages (org.Hs.eg.db, org.Mm.eg.db) must be pre-installed
- future, promises, globals, listenv, parallelly (async operations)
- shinydashboard, DT, plotly, heatmaply, reshape2, stringdist, writexl, jsonlite, zip
- testthat, devtools, roxygen2 (development)
