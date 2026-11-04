# SPEC-WS-013 recheck record

Companion of [SPEC-WS-013](../specs/SPEC-WS-013.md) (v0.3.1). One section per milestone: measured before and after values, commands and CI run ids, changed existing-test assertions with their reasons, and gaps. The "before" values below come from M0 and are the baseline every later section compares against.

## M0 - baseline capture (no behaviour change)

### Measured tree and environment

| Item | Value (observed in this run) |
|---|---|
| Tree measured | worktree `.moai/worktrees/projects/richStudio/ws-ui-redesign`, branch `WT-workspace-ui-redesign`, HEAD `8a2d19d34539722cc743084adbe00e4abd033aa6` |
| `R/` and `inst/` against `8a2d19d` | unchanged (`git diff --name-only 8a2d19d HEAD -- R inst` prints nothing) |
| R | 4.6.2 (2026-10-29), dev library `~/.local/share/richStudio/rlib-r46-ci` |
| shiny | 1.14.0 (the version used by hosted CI and the live host, which is the compatibility target of the SPEC) |
| later / richR | 1.4.8 / 0.1.5 |
| Browser | Playwright 1.59.1 library (throwaway scripts outside the repository), Chromium 147.0.7727.15, headless |
| App served | `R CMD INSTALL --library=<scratch>/lib .` of this tree, then `shiny::runApp(system.file("application", package = "richStudio", lib.loc = <scratch>/lib), port = 3871)` |
| Hosted CI | disabled on this repository; the full-suite gate is run locally by the lead (not by M0) |

### Goldens (files under `tests/fixtures/ui-baseline/`)

| File | Content | sha256 (first 16) |
|---|---|---|
| `figure-values.json` | built plot objects for the bundled demo (go1, go2, kegg1 and a richR clustering of go1+go2): bars (Padj/rich and Pvalue/value, top 25), dots (Padj, Pvalue, top 30), network nodes (colour, size, shape, alpha; layout x/y excluded), top-term enrichment heatmaps, cluster summary heatmaps and per-cluster term heatmaps (Padj, Pvalue); values as text with 17 significant digits, keyed by term (or `term \| dataset` for heatmap cells), never by position; bar/dot order recorded separately | `1e36c2682b3bb37b` |
| `demo-downloads.json` | files written by the real download handlers (`cluster_upload_tab_server$download_rr`, `saveTabServer$export_rr` csv/tsv with safe and exact export, `export_clus`): handler file name, bytes, sha256, line count, first three lines (original column names, full precision) | `a3eccbb34e8a1f6a` |
| `input-revision.json` | SPEC-WS-004 `review_resolve` snapshot for the three demo gene lists at cutoff 0.05 with fixed settings (human, GO, SYMBOL, BP): gene column, query rule, counts, source digest, revision digest, submitted genes (count, head, sha256), review items | `66aa088fca322a94` |
| `project-baseline.zip` | project written by `project_write` from the demo session (3 gene lists, 3 results, one clustering, tracking tables) with a fixed `created` timestamp and no run records | `922f767d5adc204c` |

Determinism: `tests/testthat/helper-ui-baseline.R` computes every golden from existing package functions only (`workspace_cluster_compute` with fixed richR parameters, `rr_bar`, `rr_dot`, `rr_network`, `add_topterm_gs`, `topterm_hmap`, `comprehensive_hmap`, `cluster_hmap`, `review_resolve`, `project_write`). Checked by generating the four files twice in separate R processes, once with `LC_ALL=en_US.UTF-8`: the three JSON files were byte-identical, and the four zip members (`manifest.json`, `methods.md`, `tables.json`, `tracking.json`) had identical sha256 in both runs. The zip container bytes differ only by member modification times, so the test compares members, not the container: `tables.json` and `tracking.json` as sha256, `manifest.json` as parsed content with `versions` and `files` removed (versions follow the toolchain, not the saved data). Keyed lists are ordered with `order(method = "radix")` so the file does not depend on the collation locale (a first draft using the default order failed under the testthat locale; fixed before commit). The network layout coordinates come from a random layout and are deliberately not part of the golden.

Known sensitivities (residual risk): `source_digest`/`digest` in `input-revision.json` come from `digest::digest()` over the R object and may change with an R or digest serialization change, not with the data; the richR clustering is deterministic on this machine (two runs identical) but is an engine output, so a richR upgrade can change it.

### N6 reproduction (Network tab blank after demo load)

Steps (1440x900, fresh page, tree above): open `/`; click "Load demo results" (`#home-load_demo`); the app lands on Enrichment figures (`#shiny-tab-rr_visualize_tab`); click the "Network" tab inside "Enrichment Result Visualization"; wait 6 s.

Observed at 1440x900 (after the demo load alone, no jobs):

| Element | Observation |
|---|---|
| `#rr_visualize-select_net` | value `go1`, options `["go1"]` (selected by default) |
| `#rr_visualize-net_empty` (static `.empty-state`) | visible, text "No data to display Select an enrichment result and configure options above.", box 739 x 176 px, page offset top 950 px; it is never hidden |
| `#rr_visualize-network` (plot output) | box 739 x 400 px, page offset top 1126 px; no `shiny-output-error` class |
| `img` inside `#rr_visualize-network` | present after about 6 s: displayed 738 x 400 (natural 738 x 400), `src` is `data:image/png;base64,...` (190,318 characters); decoded PNG has 2,957 distinct colours and 63,792 of 295,200 pixels non-white (50 nodes with labels and edges visible, see screenshot review below) |
| Viewport | 900 px tall: the empty-state box starts at 950 px and the image at 1126 px, so neither is in the first viewport; page scroll height 1630 px |

Observed at 390x844: same structure; empty state top 2369 px (176 x 340), plot output top 2545 px (340 x 400), PNG 340 x 400 with 38,991 non-white pixels; scroll width 390 (no horizontal overflow).

Root cause: the plot does render and is not blank. The static "No data to display" empty-state box in `rr_vis_tab_ui` (`R/rr_visualize_tab.R`, `div(id = ns("net_empty"), class = "empty-state", ...)`) stays visible above a populated figure (finding F2, not a network render failure), and the figure sits 176 px lower, at about 1126 px from the top, outside the first viewport at both sizes; node labels in the PNG are about 5-6 px tall. The earlier N6 observation ("only the empty state and a blank 400 px area") is explained by the first viewport showing the empty-state box and the plot being below it (and, in the first seconds, the output carrying the `recalculating` class with no `img` yet). So the milestone M4 fix for AC-029 is the combination of the M1 server-driven empty state (F2) and legible, larger network labels with a legend (REQ-011); no engine or `rr_network` change is indicated by this reproduction. The testthat side already shows the built network has 50 nodes for each of go1, go2 and kegg1 (`figure-values.json`, `network_has_nodes`).

Reproduction files are throwaway and not in the repository (Playwright scripts and screenshots `n6-img-1440.png`, `n6-scrolled-1440.png`, `n6-img-390.png` in the session scratchpad `m0/` directory).

### "Before" browser measurements

Method: Playwright, headless Chromium, viewport set explicitly (1440x900 and 390x844), page offsets read from `getBoundingClientRect().top + scrollY` after navigating each tab by clicking its sidebar anchor and scrolling to the top. State: "Load demo results" (go1, go2, kegg1), "Load demo" gene lists on Enrich (deg_mouse1..3), one enrichment run of `deg_mouse1` (human, GO, SYMBOL, BP) which fails with `Package 'org.Hs.eg.db' is required. Install it with:` (the install command is not shown), then one clustering of go1+go2 (default hierarchical method, name `clus1`) which succeeds. So the job panel holds one failed enrichment row (with Retry) and one succeeded clustering row. Values are CSS pixels.

Common to every page (including Home): the "Active workspace" card sits at top 71 px, height 366 px (1440) / top 112 px, height 418 px (390); the "Analysis jobs" section sits below it at top 457 px, height 375 px (1440) / top 550 px, height 475 px (390), so page content starts at 832 px (1440) / 1025 px (390). The panel is an expanded inline list: no collapse control, settings lines for each run expanded, run ids (`code`) in the danger colour `rgb(199, 37, 78)` (4 of 4 `code` elements). Note: the SPEC says Home no longer shows the active-workspace card; on this tree the card is visible on Home too (observed top 71 px, height 366 px).

Document scroll height (page height), and horizontal overflow (`scrollWidth` equals the viewport width on every page at both sizes: no overflow):

| Page (route) | 1440x900 | 390x844 |
|---|---|---|
| Home (`home_tab`) | 1631 | 2761 |
| Data = Manage Files (`update_tab`) | 1484 | 2436 |
| Enrich (`enrich_tab`), with demo gene lists | 3291 | 4690 |
| Enrich before any job exists (demo gene lists loaded) | 2719 | 3858 |
| Results = Enrichment figures (`rr_visualize_tab`), default tab | 4270 | 6109 |
| Results, Table tab | 2331 | 3882 |
| Results, Network tab | 2016 | 3467 |
| Upload files (importer, `cluster_upload_tab`) | 2375 | 3616 |
| Cluster (`cluster_tab`) | 2409 | 3695 |
| Cluster figures (`clus_visualize_tab`) | 2858 | 3749 |
| Save (`save_tab`) | 1787 | 2842 |

(The Table and Network tab rows are the same Results page with another inner tab selected; the page-height clauses of AC-020 refer to the Enrich row, with the job rows listed.)

Job panel height after one failed enrichment and one clustering: 375 px (1440x900), 475 px (390x844), identical on every page; AC-002 requires at most 64 px collapsed.

First-content offsets (page offset of the top edge, px; the SPEC's "before" figure for Cluster was "about 830 px"):

| Element (acceptance clause) | 1440x900 | 390x844 |
|---|---|---|
| Cluster form heading "Cluster Enrichment Results" (AC-016) | 842 | 1035 |
| Enrich box heading "Enrich" | 857 | 1500 |
| Enrich "Run" button `#enrich-enrich_deg` (AC-020), with the two job rows listed | 1529 | 2551 |
| Enrich "Run" button before any job exists (gene lists loaded, job panel empty) | 957 | 1719 |
| Enrich DEG upload control group `enrich-deg_files` (Data content today, AC-019) | 1048 | 1241 |
| Enrich first DataTable (`enrich-deg_list_table`) | 1695 | 2751 |
| Results heading "Enrichment Result Visualization" (AC-022) | 862 | 2237 |
| Results term table in the default Explorer tab (`rr_visualize-ex_table`, AC-022) | 1954 | 3592 |
| Results term table in the Table tab (`rr_visualize-rr_table`) | 1325 | 2772 |
| Results left-column list of loaded results (`rr_visualize-rr_list_table`, not the term table) | 1673 | 1866 |
| Results loader group `rr_visualize-rr_files` (to move to Data, AC-019) | 998 | 1191 |
| Data page ("Manage Files") heading | 842 | 1035 |
| Data page first control (`update-rename_deg_select`) | 1036 | 1229 |
| Importer `cluster_upload-rr_files` group (AC-019) | 969 | 1162 |
| Save heading "Save & Load Analysis Session" | 842 | 1035 |
| Save "Save project" download link `#save-download_project` (AC-019) | 1420 | 1669 |
| Save JSON session download `#save-download_session` | 1195 | 1408 |
| Cluster figures heading "Cluster Result Visualization" | 862 | 1689 |
| Network tab: empty-state box top / image top (N6, AC-029) | 1336 / 1511 | 2854 / 3030 |
| Network image box | 739 x 400 | 340 x 400 |

Against the acceptance thresholds: AC-019 upload control (within 300 / 420 px) is 1048 / 1241 today; AC-020 Run (within 300 / 420 px) is 1529 / 2551 today; AC-022 term table (within 300 / 420 px) is 1954 / 3592 in the Explorer tab today. The full measurement was run three times; the page heights, job-panel heights and the table tops printed in each run were identical between runs (the later runs only added table ids to the script).

### Commands and verbatim results (M0)

Commands run in this tree:

- `scripts/dev-r.sh Rscript --vanilla -e 'pkgload::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-ui-baseline.R")'`
- `git diff --name-only 8a2d19d HEAD -- R inst`
- `python3 -I .moai/reports/SPEC-WS-013/lockcheck.py`

`lockcheck.py` reports the six new M0 files as "new already on disk" because they now exist; its RESULT line is the verdict.

Verbatim results (this run, tree `8a2d19d` plus the M0 files): `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 35 ]` for `test-ui-baseline.R`; `git diff --name-only 8a2d19d HEAD -- R inst` printed nothing (0 lines); `lockcheck.py` printed `lock 54 duplicates 0` and `RESULT OK`. Temporary note: `R CMD INSTALL` of the tree regenerated `R/RcppExports.R` (whitespace-only roxygen differences); it was restored with `git checkout -- R/RcppExports.R` before the commit and is not part of M0.

### Changed existing-test assertions (M0)

None. M0 adds files only and changes no file under `R/` or `inst/`.

### Gaps (M0)

- Hosted CI is disabled; no CI run id exists for M0. The full test suite was not run by this milestone (scoped run of `test-ui-baseline.R` only; the full suite is run locally by the lead).
- The "before" browser values are one run per viewport on a single machine with a single R session serving the app; no repeat-variance was measured. Layout numbers can move by a few pixels with fonts and the headless Chromium build.
- The job panel was measured after one failed enrichment and one hierarchical clustering. A running job, two finished jobs of the same type and a failed environment error with a very long command were not separately measured.
- The Data step does not exist yet (OD-3, M6): "Data" figures above are for the existing Manage Files route plus the DEG upload control that lives on Enrich today.
- Heights and offsets were read from computed geometry; contrast, focus and live-region baselines (AC-004 to AC-006) were not captured in M0 because the M0 table row lists page heights, job-panel height and first-content offsets only.
- N6 root cause rests on one reproduction per viewport plus pixel statistics and a visual read of the decoded PNG; the PNG was found non-blank.

## M1 - presentation quick wins

Not started.

## M2 - copy and validation quick wins

Not started.

## M3 - one visual system

Not started.

## M4 - figure legibility

Not started.

## M5 - context bar and job tray

Not started.

## M6 - task stepper, Data step and information architecture

Not started.

## M7 - Enrich progressive disclosure

Not started.

## M8 - Results master-detail

Not started.
