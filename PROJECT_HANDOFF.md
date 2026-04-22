# richStudio Project Handoff

## 1. Project Overview

richStudio is an R Shiny application for functional enrichment analysis and gene set clustering. It provides DEG file upload, enrichment analysis (GO, KEGG, Reactome via richR/bioAnno), multiple visualization modes (table, bar, dot, network, heatmap), three clustering algorithms (richR Kappa, Hierarchical via richCluster, DAVID-style), session save/load (RDS/JSON), and export (CSV/TSV/XLSX/ZIP).

- **Last updated:** 2026-03-30 22:10 CDT
- **Last coding CLI used:** Claude Code CLI (claude-opus-4-6)
- **Branch:** main
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

### Not Yet Verified
- User manual accuracy (not independently reviewed against live app)
- PDF generation (requires LaTeX)
- Figure quality for print publication (screenshots may need higher DPI)
- Playwright CLI E2E test suite (not yet created; user prefers CLI over MCP)

## 7. Restart Instructions

**Starting point:** Application is deployed and running at hurlab.med.und.edu/richStudio/. All manuscripts are draft-complete with 3 review rounds passed. Documentation suite is generated.

**Recommended next actions:**
1. Create Figure 1A architecture diagram (manual creation, not automatable)
2. Install LaTeX and generate user manual PDF: `sudo apt install texlive-latex-base texlive-fonts-recommended && pandoc richStudio_UserManual.md -o richStudio_UserManual.pdf`
3. Make user manual web-accessible (copy HTML to `inst/application/www/` or serve via nginx)
4. Add in-app help pages linking to the user manual
5. Final author review of both manuscripts before journal submission
6. Consider GitHub Actions CI for automated testing

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

**Last updated:** 2026-03-30 22:15 CDT
