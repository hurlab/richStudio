# richStudio Project Handoff

## 1. Project Overview

richStudio is an R Shiny application for functional enrichment analysis and gene set clustering. It provides DEG file upload, enrichment analysis (GO, KEGG, Reactome via richR/bioAnno), multiple visualization modes (table, bar, dot, network, heatmap), three clustering algorithms (richR Kappa, Hierarchical via richCluster, DAVID-style), session save/load (RDS/JSON), and export (CSV/TSV/XLSX/ZIP).

- **Last updated:** 2026-05-19 08:17 CDT
- **Last coding CLI used:** Claude Code CLI (claude-opus-4-7, 1M context)
- **Branch:** main (synced with origin/main at commit 7535bc2)
- **Version:** 0.1.6

## 2. Current State

### Phases 1-11: Application Development — All Completed

All application development phases (Critical Bug Fixes, Visualization Fixes, Production Readiness, Remaining High Fixes, Async & Memory, Reactive Refactor, Medium Fixes & Tests, Second Review Round, UI/UX Modernization, UI Audit & Polish v0.1.6, Code Review Bug Fixes) are complete. See previous PROJECT_HANDOFF.md versions and PROJECT_LOG.md for details.

### Phase 12: Deployment Infrastructure — Completed in Session 2026-03-29 21:24 CDT
- Fixed renv library directory hash mismatch after directory rename (richStudio_3 to richStudio)
- Renamed `renv/library/richStudio_3-cb61d1cc` to `renv/library/richStudio-29a8d641`
- Fixed Shiny Server running as wrong user (`shiny` instead of `juhur`) via `/srv/shiny-server/` symlinks
- Removed stale symlinks in `/srv/shiny-server/` so `location /richStudio` block handles requests
- Updated all stale `richStudio_3` references in nginx configs and app.R
- Verified renv activation with system R and all packages loadable

### Phase 13: Manuscript & Documentation Suite — Completed in Session 2026-03-29 21:24 CDT

#### BMC Bioinformatics Full Research Article
- **Status:** Completed, 3 review rounds passed (Conditional PASS)
- **File:** `inst/manuscript/richStudio_BMC_Bioinformatics.md` and `.docx`
- ~3,900 words main text, 291-word abstract, 27 references (all verified)
- 7 figures (multi-panel), 3 tables
- Competitive analysis: 10 tools compared including simplifyEnrichment, EnrichmentMap, clusterProfiler treeplot()
- Funding: R01DK130913 (NIDDK), P20GM113123 (NIGMS/CDA Core UND)

#### Application Note
- **Status:** Completed, revised to match writing standards
- **File:** `inst/manuscript/richStudio_ApplicationNote.md` and `.docx`
- 5 verified references, proper competitive positioning vs Metascape

#### User Manual
- **Status:** Completed (HTML + DOCX; PDF pending LaTeX installation)
- **File:** `inst/manuscript/richStudio_UserManual.md`, `.html`, `.docx`
- 905 lines, 11 sections + 3 appendices
- All parameters documented with defaults and ranges

#### Figures
- **Status:** 18 screenshots captured from live app
- **Location:** `inst/manuscript/figures/`
- **Pending:** Figure 1A (architecture diagram) needs manual creation

#### Review Reports
- `inst/manuscript/review_round1.md` — 3 critical, 8 major (all resolved)
- `inst/manuscript/review_round2.md` — 3 critical, 8 major (all resolved)
- `inst/manuscript/review_round3.md` — Conditional PASS (2 minor, both resolved)
- `inst/manuscript/competitive_analysis.md` — 13 tools benchmarked with verified refs

### UI Fix — Completed in Session 2026-03-29 21:24 CDT
- Updated About box Team section to single line (no "(Lead)" label)

### Code Fix — Completed in Session 2026-03-29 21:24 CDT
- Added `.xlsx` to accepted file types in `enrich_tab.R` and `cluster_upload_tab.R`
- Added Kai Guo as author in DESCRIPTION

### Phase 14: Code Review & Fix (4-Agent Harness) — Completed in Session 2026-03-30 22:10 CDT
- **Issues found:** 3 confirmed real bugs, 4 security gaps (2 fixed, 2 accepted)
- **CRITICAL fix:** Added Excel (.xls/.xlsx) file reading via `readxl::read_excel()` with tryCatch error handling in 3 files (enrich_tab.R, cluster_upload_tab.R, rr_visualize_tab.R)
- **HIGH fix:** Removed debug `std::cout` statements from C++ production loop (ClusterManager.cpp)
- **LOW fix:** Added missing file size validation in rr_visualize_tab.R upload handler
- **LOW fix:** Added `!is.na()` guard to file size checks in all 3 upload handlers
- **MEDIUM fix:** Added `sanitize_filename()` to download handler in clus_visualize_tab.R
- **HIGH fix:** Added type validation after `readRDS()` in save_tab.R to guard against deserialization attacks
- **Security baseline:** No hardcoded secrets. All dependencies current. RDS now validated post-deserialize.
- **Verification:** All R files parse clean, C++ braces balanced, app loads successfully via browser

### Phase 15: Senior-Architect Review + Multi-Round Harness — In Progress (Sessions 2026-05-17 → 2026-05-19)
- **Review scope:** 21 R files (5757 LOC), 9 C++ files (987 LOC), inst/application/app.R, NAMESPACE/DESCRIPTION, 5 test files, 3 manuscript files
- **Method:** 4 parallel domain agents (security, performance, quality, functional gap) + per-bundle 3-round review-revise harness
- **Findings:** 8 security + 16 performance + 20 quality (TRUST 5) + 18 functional-gap = ~58 raw, deduplicated to ~50 distinct items, grouped into 8 SPEC bundles
- **Bundle B1 (SPEC-QUICK-001) complete (2026-05-17):** commit 774d019 — dead-code/debug stub removal, -110 / +1 lines across 6 R files
- **Bundle B2 (SPEC-CRAN-001) complete (2026-05-17):** commit 5305d49 — CRAN NAMESPACE hygiene, dropped tidyverse umbrella, added 13 missing importFroms (including the critical `shinyjqui::jqui_resizable` bare call that would have caused R CMD check ERROR), inline-comment magic-0.5 defaults in rr_cluster.R
- **Deployment tooling complete (2026-05-18):** commit 7535bc2 — `scripts/deploy.sh`, `scripts/rollback.sh`, `scripts/preview-deploy.sh` (git-based deploy with hardlinked PREV snapshots, auto-rollback on mid-deploy failure, curl smoke test, configurable retention). DEPLOYMENT.md restructured with 5-tier safety checklist and risk-by-change-type table.
- **All commits pushed to origin/main (2026-05-18):** 5 commits this phase — 774d019 (B1), 5305d49 (B2), 0748e67 (Phase 15 docs), 4eb9f96 (MoAI 0.33.0 template sync), 7535bc2 (deploy tooling). Local tree clean. Server deploy intentionally deferred per user direction — bundle B1-B5 into one coordinated update later.

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
| Phase 11: Code Review Bug Fixes | Completed | 2026-03-28 |
| Phase 12: Deployment Infrastructure | Completed | 2026-03-29 |
| Phase 13: Manuscript & Documentation Suite | Completed | 2026-03-29 |
| Phase 14: Code Review & Fix (4-Agent Harness) | Completed | 2026-03-30 |
| Phase 15: Senior-Architect Review + Harness B1+B2 + Deploy Tooling | In Progress (B1, B2, tooling done; B3-B8 + deploy pending) | 2026-05-19 |

## 4. Outstanding Work

### Active Items

- **User Manual PDF**: Requires LaTeX installation to generate PDF from markdown. HTML and DOCX versions are ready.
  - Status: Not started
  - Last updated: 2026-03-29 21:24 CDT
  - Ref: Session 2026-03-29

- **Figure 1A Architecture Diagram**: Manual workflow/architecture schematic needed (richR/bioAnno/richCluster integration diagram).
  - Status: Not started
  - Last updated: 2026-03-29 21:24 CDT
  - Ref: Session 2026-03-29

- **Web-accessible documentation**: User manual HTML not yet linked from the Shiny app or served via nginx.
  - Status: Not started
  - Last updated: 2026-03-29 21:24 CDT
  - Ref: Session 2026-03-29

- **Bioconductor submission**: Planned after publication. Currently distributed via GitHub only.
  - Status: Not started
  - Last updated: 2026-03-29 21:24 CDT
  - Ref: Session 2026-03-29

- **CI/CD**: No GitHub Actions or CI pipeline configured.
  - Status: Not started
  - Last updated: 2026-03-28

- **renv R 4.6 rebuild**: System R was upgraded 4.5 → 4.6 between 2026-03-29 and 2026-05-17. Existing renv library at `renv/library/richStudio-29a8d641/R-4.5/` is stale; system R cannot resolve any packages. Required before running `testthat::test_dir()`, `R CMD check --as-cran`, or rebuilding the deployed Shiny app.
  - Status: Not started
  - Last updated: 2026-05-17
  - Suggested command: `Rscript -e 'renv::restore()'` (will recompile against R 4.6; takes ~20-40 min)

- **Phase 15 outstanding bundles**: 6 remaining SPEC bundles from the senior-architect review.
  - **SPEC-STYLE-001 (B6) — recommended next**: Style + extract `sniff_delimiter` utility, document `u_` prefix, internal `format_cells` alternative comments. Low risk. ~1 hour.
  - **SPEC-SEC-001 (B3)**: Security hardening — path traversal in `export_all` ZIP loop (HIGH; deployment-critical), content-based file validation, nested RDS validation, `setBookmarkExclude`. ~2 hours.
  - **SPEC-PERF-R-001 (B4)**: R reactive performance — heatmap caching, observer decomposition, debounce, rbind-in-loop, network term-count guard. Severity: MED. ~2 hours.
  - **SPEC-PERF-CPP-001 (B5)**: C++ performance refactor — upper-triangle distance matrix (200 MB → 100 MB at n=5000), pre-cache per-term gene sets (eliminates 25M re-allocations), int-overflow guard. **Requires `R CMD INSTALL` to verify**; depends on renv R-4.6 rebuild. Severity: CRITICAL for the manuscript's "scales to 5000+ terms" claim. ~3 hours.
  - **SPEC-FUNC-001 (B7)**: Functional-gap code-side fixes — port network plot to plotly, expand Reactome species, set `shiny.maxRequestSize = 100MB`. Per user decision 2026-05-17. ~4 hours.
  - **SPEC-TEST-001 (B8)**: Test foundation rebuild — depends on B5 stability and renv R-4.6 rebuild. Decompose 4 monolithic server functions (327–467 LOC), add shinytest2 integration tests, add C++ direct tests. Severity: CRITICAL for journal submission credibility. ~6 hours.
  - Status: Not started
  - Last updated: 2026-05-19
  - Ref: Sessions 2026-05-17, 2026-05-19

- **SPEC-CRAN-002 (architectural decision)**: 6 packages in DESCRIPTION Imports are used only via `library()` in `inst/application/app.R` — `shinyWidgets`, `ggplot2`, `data.table`, `config`, `digest`, `bioAnno`. Per CRAN policy these must either have NAMESPACE coverage (`@import pkg`) or move to `Suggests` with `requireNamespace()` guards. Triggers CRAN NOTEs in current state.
  - Status: Not started
  - Last updated: 2026-05-17

- **Coordinated B1–B5 server deploy**: Deferred per user direction (2026-05-18). B1+B2 changes are pushed to GitHub origin/main (commit 7535bc2) but NOT deployed to hurlab.med.und.edu/richStudio/ yet. The live deployment is still on pre-Phase-15 code (last server sync 2026-05-10 via smart-rsync). Deploy after completing B3, B4, B5 in one event using `scripts/deploy.sh` with Tier 2 (staging slot) safety since the deploy will include `src/*.cpp` changes from B5 and `renv.lock` changes from CRAN compliance fixes.
  - Status: Not started (blocked on B3/B4/B5 completion)
  - Last updated: 2026-05-19
  - Ref: Session 2026-05-18

- **Server migration to git-based deploy**: One-time setup required to convert the server's `/srv/shiny-server/richStudio` from rsync-copy to a git checkout. Procedure documented in DEPLOYMENT.md under "One-Time Setup". Without this, `scripts/deploy.sh` will fail its precondition check.
  - Status: Not started
  - Last updated: 2026-05-19
  - Ref: Session 2026-05-18

### Accepted Risks (no action needed)
- **MED-014**: Sample data contention — accepted (read-only access, minimal risk)

## 5. Risks, Open Questions, and Assumptions

### Directory rename residue — Resolved
- **Status:** Resolved
- **Date opened:** 2026-03-29
- **Resolution:** Renamed renv library directory, fixed nginx configs, removed stale symlinks. App confirmed running correctly.

### Shiny Server user context — Resolved
- **Status:** Resolved
- **Date opened:** 2026-03-29
- **Resolution:** Removed `/srv/shiny-server/richStudio` and `/srv/shiny-server/RichStudio` symlinks so requests route to the explicit `location /richStudio` block which runs as `juhur`, not `shiny`.

### richR/richCluster package stability — Open
- **Status:** Open
- **Default assumption:** These packages are stable for current use cases. Single-input edge cases bypassed with direct internal function calls.

### Bioconductor annotation package availability — Open
- **Status:** Open
- **Default assumption:** org.Hs.eg.db, org.Mm.eg.db must be pre-installed. App shows informational messages if missing.

### Manuscript reference accuracy — Mitigated
- **Status:** Mitigated
- **Date opened:** 2026-03-29
- **Resolution:** 3 rounds of review caught fabricated author names in 4 references; all corrected via PubMed/DOI verification. All 27 references now verified.

## 6. Verification Status

### Verified
| Feature | Method | Result | Date |
|---------|--------|--------|------|
| All R files parse (21/21) | Rscript -e "parse()" | All OK | 2026-03-09 |
| Unit test suite | testthat::test_dir() | 152 pass, 0 fail | 2026-03-09 |
| App startup after rename | renv::restore() + system R | All packages load | 2026-03-29 |
| Shiny Server serving as juhur | Browser + log check | Confirmed running | 2026-03-29 |
| renv activation (system R) | /usr/lib/R/bin/R source("renv/activate.R") | Library path correct | 2026-03-29 |
| BMC manuscript review | 3 review rounds | Conditional PASS (resolved) | 2026-03-29 |
| Application Note review | 1 review round | All issues fixed | 2026-03-29 |
| No stale richStudio_3 refs | grep -r richStudio_3 (excl logs) | Only in PROJECT_LOG.md (historical) | 2026-03-29 |
| Code review: R parse (21/21) | Rscript -e "parse()" per file | All PASS | 2026-03-30 |
| Code review: C++ syntax | Brace balance check | 10 open / 10 close | 2026-03-30 |
| Code review: App smoke test | Playwright browser navigate | Home page renders, title "richStudio" | 2026-03-30 |
| Code review: Package loading | system R requireNamespace() | shiny, readxl, plotly, richR, DT, future all TRUE | 2026-03-30 |
| Code review: No debug output | grep cout ClusterManager.cpp | Zero matches | 2026-03-30 |
| Code review: xlsx handling | Grep readxl::read_excel in R/ | Present in all 3 upload handlers | 2026-03-30 |
| Security: Secret scan | grep password/secret/api_key/token | No hardcoded secrets found | 2026-03-30 |
| Security: Dependency versions | renv.lock audit | shiny 1.12.1, jsonlite 2.0.0, openssl 2.3.4 (all current) | 2026-03-30 |
| Phase 15 B1+B2 R parse | Rscript -e "parse()" per file | 21/21 OK after both commits | 2026-05-17 |
| Phase 15 B1+B2 test file parse | Rscript -e "parse()" per test file | 5/5 OK | 2026-05-17 |
| Phase 15 B1 review | 3-round harness (regression, completeness, final gate) | All PASS, High confidence | 2026-05-17 |
| Phase 15 B2 review | 3-round harness (CRAN compliance, runtime regression, final gate) | All PASS after 1 revise cycle (caught missed shinyjqui+tibble+tidyr+richR+shinyjs hidden drift) | 2026-05-17 |
| Phase 15 NAMESPACE/package.R alignment | Cross-check all @importFrom directives | Aligned; 55 importFrom lines in NAMESPACE | 2026-05-17 |
| Deploy scripts syntax | bash -n on all 3 scripts | All PASS | 2026-05-18 |
| GitHub sync state | git rev-list --count HEAD...origin/main | 0/0 (fully synced at 7535bc2) | 2026-05-19 |

### Not Yet Verified
- User manual accuracy (not independently reviewed against live app)
- PDF generation (requires LaTeX)
- Figure quality for print publication (screenshots may need higher DPI)
- Playwright CLI E2E test suite (not yet created; user prefers CLI over MCP)
- **testthat::test_dir() under R 4.6** — blocked by renv lockfile drift (built against R 4.5). Last verified pass was 152 / 0 fail on 2026-03-09 under R 4.5. Re-baseline pending `renv::restore()` against R 4.6.
- **R CMD check --as-cran** — never run end-to-end; blocked by same renv drift. Will surface any remaining NAMESPACE NOTEs (especially the 6 packages flagged in SPEC-CRAN-002).
- **`scripts/deploy.sh` end-to-end** — scripts pass `bash -n` syntax check but have not been executed against a live server. First-run will be the coordinated B1-B5 deploy event.
- **B1 + B2 in live deployment** — code pushed to GitHub but not yet deployed to hurlab.med.und.edu/richStudio/. Live app is still on pre-Phase-15 code.

## 7. Restart Instructions

**Starting point (2026-05-19 08:17 CDT):**
- Local working tree at `/home/juhur/PROJECTS/20_libs/richStudio` is clean and fully synced with `origin/main` at commit `7535bc2`.
- Phase 15 Senior-Architect Review is IN PROGRESS. B1 (dead-code) and B2 (NAMESPACE hygiene) bundles complete locally and on GitHub but NOT yet on the live server.
- Live app at `hurlab.med.und.edu/richStudio/` is still on the pre-Phase-15 codebase (last rsync 2026-05-10). Users are not yet affected by Phase 15 changes.
- The user has chosen: continue harness bundles B6 → B3 → B4 → B5 → B7 → B8 (style → security → R perf → C++ perf → functional gap → tests), then ONE coordinated server deploy via `scripts/deploy.sh` with Tier 2 staging-slot safety.

**Recommended next actions, in order:**

1. **(Highest priority) Resume Phase 15 harness with Bundle B6 — SPEC-STYLE-001.**
   Scope: Extract shared `sniff_delimiter()` utility into `R/file_handling.R` (eliminates the triplicated CSV/TSV probe in `enrich_tab.R`, `cluster_upload_tab.R`, `rr_visualize_tab.R`). Document the `u_` reactive-prefix convention in `R/package.R` roxygen. Clean up the remaining `format_cells` internal alternative comments in `R/round_table.R` that were deferred from B1.
   Risk: Low. Expected ~1 hour with the 3-round review-revise harness.

2. **Then B3 — SPEC-SEC-001 (security hardening).**
   The deployment-critical bundle. Specifically:
   - Path traversal in `R/save_tab.R::export_all` ZIP loop (lines 435, 447, 459): wrap each `paste0(name, ".csv")` in `sanitize_filename()`.
   - Add `detect_file_format()` content-sniffing helper to `R/file_handling.R` (combines with B6's `sniff_delimiter`).
   - Extend RDS validation in `R/save_tab.R::load_session` observer to assert `is.list()` and `inherits(x, "data.frame")` on every nested entry.
   - Add `setBookmarkExclude()` calls in each module server for large reactiveValues stores.
   - Add explicit `nchar(lab) <= 255` length cap.

3. **Then B4 — SPEC-PERF-R-001 (R reactive performance).** Heatmap `bindCache`, top-terms debounce, observer split, rbind-in-loop fix, network term-count guard.

4. **Then run `renv::restore()` against R 4.6** (~20-40 min). This is a hard prerequisite for B5 (needs `R CMD INSTALL`) and B8 (needs `testthat` + `shinytest2`). Should also enable `R CMD check --as-cran` for the first end-to-end CRAN compliance verification.

5. **Then B5 — SPEC-PERF-CPP-001 (C++ refactor).** Upper-triangle distance matrix, pre-cache per-term gene sets, integer-overflow guard. Verify with `R CMD INSTALL` + benchmark.

6. **Then B7 — SPEC-FUNC-001 (functional gap closure).** Port `R/rr_network.R` from static ggplot to `plotly::ggplotly()`; expand Reactome species support; add `options(shiny.maxRequestSize = 100*1024^2)` in `inst/application/app.R`.

7. **Then B8 — SPEC-TEST-001 (test foundation rebuild).** Decompose the 4 monolithic server functions, add `shinytest2` integration tests for each module, add C++ direct tests via `.Call('_richStudio_richCluster', ...)`.

8. **Then coordinated server deploy event:**
   - One-time server setup per `DEPLOYMENT.md` "One-Time Setup" section (convert `/srv/shiny-server/richStudio` from rsync-copy to git checkout). Requires SSH + sudo on the server.
   - `scripts/preview-deploy.sh` to confirm exactly what will deploy.
   - `scripts/deploy.sh` — auto PREV snapshot + git fetch + reset --hard + renv::restore + Rcpp::compileAttributes + restart + curl smoke test.
   - If anything misbehaves: `scripts/rollback.sh` for instant rollback to most recent PREV snapshot.

9. **Pre-publication tasks (parallel track):** Figure 1A architecture diagram, user manual PDF (needs LaTeX), in-app help link, final author review.

**Critical context for the next agent:**
- The cross-validation step (running an independent skeptical reviewer against the original audit findings) caught real defects: B1 dropped one false-positive finding (T-18 launch_richStudio docs), B2 caught a CRAN-blocker bare-call (`shinyjqui::jqui_resizable`) the original audit missed. KEEP the 3-round review-revise harness for every bundle.
- The original code-review found ~58 raw items deduplicated to ~50. After B1+B2 work, the validated set is in the SPEC docs at `.moai/specs/SPEC-QUICK-001/spec.md` and `.moai/specs/SPEC-CRAN-001/spec.md` (gitignored — not in the repo). Findings for B3-B8 are listed in the assistant message at the start of this session's harness work (search PROJECT_LOG.md for "P-01" / "SEC-01" / "T-01" / "G-01" tables).
- The renv lockfile is the single biggest blocker to verification. Re-baselining it under R 4.6 unlocks `testthat`, `R CMD check --as-cran`, and full `scripts/deploy.sh` runs.

**Key NEW files added 2026-05-18:**
- `scripts/deploy.sh` — git-based deploy with PREV snapshot + smoke test + auto-rollback
- `scripts/rollback.sh` — instant rollback from PREV snapshot
- `scripts/preview-deploy.sh` — dry-run preview of pending deploy
- `DEPLOYMENT.md` — restructured with 5-tier safety checklist and risk-by-change-type table

**Key manuscript files:**
- `inst/manuscript/richStudio_BMC_Bioinformatics.md` — Full research article (BMC Bioinformatics Software Article)
- `inst/manuscript/richStudio_ApplicationNote.md` — Application note
- `inst/manuscript/richStudio_UserManual.md` — User manual
- `inst/manuscript/figures/` — 18 figure screenshots + manifest
- `inst/manuscript/competitive_analysis.md` — Detailed tool comparison
- `inst/manuscript/review_round*.md` — Review reports (3 rounds)

**Key code files:**
- `inst/application/app.R` — Main entry point
- `R/rr_cluster.R` — Core clustering logic
- `R/enrich_tab.R` — Enrichment module (accepts .xlsx now)
- `R/cluster_upload_tab.R` — Cluster upload module (accepts .xlsx now)
- `R/save_tab.R` — Session save/load with file locking
- `DESCRIPTION` — Package metadata (Kai Guo added as author)

**Author affiliations (for all manuscripts):**
1. Junguk Hur — Dept. Biomedical Sciences, UND, Grand Forks, ND 58202
2. Sarah Hong — Dept. Biomedical Informatics, Columbia University, NY 10032
3. Jane Kim — Dept. Biomedical Sciences, UND, Grand Forks, ND 58202
4. Kai Guo — Dept. Neurology, University of Michigan, Ann Arbor, MI 48109; NeuroNetwork for Emerging Therapies, University of Michigan

**Funding:** R01DK130913 (NIDDK), P20GM113123 (NIGMS/CDA Core UND)

**Last updated:** 2026-05-19 08:17 CDT
