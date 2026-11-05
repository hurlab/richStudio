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

Tree: `2676c53` plus the M1 working-tree changes (commit sha in the lead report). Environment as in M0 (R 4.6.2, shiny 1.14.0, Chromium 147.0.7727.15, Playwright 1.59.1 library borrowed from another project because this worktree has no `node_modules`; `axe-core` there is 4.13.0, not the 4.14.0 the specs pin). Browser specs ran through `playwright test` with the CI-equivalent environment (candidate library installed from the tree, `WORKSPACE_INSTALLED_LIBRARY`, `WORKSPACE_RUNS_ROOT`, scratch `TMPDIR`, scrubbed `R_*` variables).

### Changes

- F2 / N6: each Enrichment-figures view (Table, Bar, Dot, Network, Heatmap) hides its empty state while the selected result has rows (`shinyjs` show/hide from the server); the enrichment heatmap gets an empty state (`hmap_empty`) and its boxes appear only when a heatmap exists; empty-state texts name a next action.
- F1 / N1: the job panel is a native `<details>` disclosure (summary line "Analysis jobs: N"), collapsed by `workspace-ui.js` while no job is queued or running and opened for a new run, hidden by CSS (`:not(:has(.rs-job))`) with no jobs, compact flex rows with a textual state, run settings in a closed `<details>`, run ids neutral. The four outputs are `suspendWhenHidden = FALSE`, otherwise a collapsed panel never rendered its first row. Without the script or the stylesheet the panel is open and readable (the `job-lifecycle` fixture app loads neither).
- F4 / OD-8: disabled controls get opacity 0.5 and `cursor: not-allowed`; the two header actions share one visible hint and carry it as `title` and `aria-describedby`; unrecorded metadata sits in one closed `<details>` ("N not recorded") and each field inside keeps the text "Not recorded".
- F10: `:focus-visible` outlines (3 px, dark blue on light surfaces, white in the sidebar), a solid ring on text inputs; one polite job-status region (`#jobs-jobs_announce`, set explicitly); the other job outputs and the explorer selection output are set to `aria-live="off"` because Shiny otherwise adds `aria-live="polite"` to every bound output; the explorer panel's own `aria-live` is removed.
- F11: help text 13 px / `#475569`; sidebar section headers and footer 13 px / `#cbd5e1`.
- F13 / F12: opaque notifications, error notifications removed on navigation, non-error notifications hidden after 5 s, narrow menu closes after a destination is chosen (closing is instant, opening keeps its slide, because the existing specs read the menu position right after a click).
- All CSS is appended after the pinned SPEC-WS-002 marker; the original CSS bytes are unchanged (`test-workspace-components.R` pins their md5).

### Acceptance (new automated tests; both Playwright projects pass, testthat passes)

| AC | Tests |
|---|---|
| AC-001 | `ui-flows.spec.ts` "AC-001 server-driven empty states" (empty workspace: one empty state with a next action in each of Table, Bar Plot, Dot Plot, Network, Heatmap; populated: none; cluster figures after a clustering result and a chosen cluster); `test-results-explorer.R` "AC-001 each result view hides its empty state..." and "...empty states name a next action" |
| AC-002 | `ui-flows.spec.ts` "AC-002 compact job panel" (390x844: collapsed height at most 64 px on Enrich, Results, Cluster, Cluster figures and Save; expanding shows 2 rows with a textual state, settings closed, run ids not danger-coloured); `test-workspace-components.R` "AC-002 ..." (disclosure, row markup) |
| AC-003 | `ui-accessibility.spec.ts` "AC-003 ..." (disabled opacity/cursor/reason, one hint, "3 not recorded" disclosure); `test-workspace-navigation.R` "AC-003 ..." (two tests) and `test-workspace-components.R` "AC-003 a grouped disabled action..." |
| AC-004 | `ui-accessibility.spec.ts` "AC-004 visible focus" (sidebar links, Bookmark, button, text inputs: outline style, width, contrast from computed colours) |
| AC-005 | `ui-accessibility.spec.ts` "AC-005 text size and contrast" (all 8 routes) |
| AC-006 | `ui-accessibility.spec.ts` "AC-006 ..." (exactly one non-off `aria-live` inside the job panel; no server-sent or app-authored `role="log"`; every other live node listed by origin) and `test-workspace-components.R` / `test-results-explorer.R` "AC-006 ..." |
| AC-007 | `ui-flows.spec.ts` "AC-007 menu and notifications" (three tests: menu closes within 1 s, error cleared on navigation, success toast opaque, clear of "Download Project" and gone within 6 s) |

Live nodes the AC-006 test lists as not app-authored job status: Shiny output/input binding polite, the Shiny notification panel, DataTables `role="status"` info and processing nodes, plotly, selectize, the selectize accessibility plugin's 50 body-level `role="log"` announcers (no id, no class, not in the served HTML), and the Home Quick Start result message (`role="status"`, app-authored, not job status).

### After measurements (same method and rows as M0; CSS px; before values from M0)

| Row | 1440x900 before | 1440x900 after | 390x844 before | 390x844 after |
|---|---|---|---|---|
| Job panel height (1 failed enrichment + 1 clustering) | 375 | 42 (collapsed) | 475 | 42 (collapsed) |
| Page content start (below card and panel) | 832 | 374 | 1025 | 467 |
| Active-workspace card height | 366 | 241 | 418 | 293 |
| Home page height | 1631 | 1172 | 2761 | 2202 |
| Data (Manage Files) page height | 1484 | 1026 | 2436 | 1878 |
| Enrich page height | 3291 | 2835 | 4690 | 4137 |
| Results page height (default tab) | 4270 | 3811 | 6109 | 5554 |
| Cluster page height | 2409 | 1954 | 3695 | 3166 |
| Cluster figures page height | 2858 | 2399 | 3749 | 3196 |
| Save page height | 1787 | 1333 | 2842 | 2312 |
| Cluster form heading top | 842 | 384 | 1035 | 477 |
| Enrich Run button top | 1529 | 1073 | 2551 | 1998 |
| DEG upload control group top | 1048 | 591 | 1241 | 684 |
| Results term table top (Explorer tab) | 1954 | 1495 | 3592 | 3038 |
| Results loader group top | 998 | 541 | 1191 | 634 |
| Data page first control top | 1036 | 578 | 1229 | 671 |
| Importer group top | 969 | 510 | 1162 | 603 |
| Save project link top | 1420 | 965 | 1669 | 1117 |
| Network image top (Network tab) | 1511 | 877 | 3030 | 2300 |
| Network empty-state box (visible?) | visible, top 1336 | not visible | visible, top 2854 | not visible |

`scrollWidth` equals the viewport width on every page at both sizes (no horizontal overflow). Run ids are `rgb(30, 41, 59)` / `rgb(71, 85, 105)` after, `rgb(199, 37, 78)` before. The card and the first-content offsets still exceed the M5/M6/M7/M8 targets (300/420 px); those milestones remove the card.

### N6

The plot already rendered at M0; the defect was the never-hidden static empty state above it. After M1 the Network tab with `go1` selected shows no empty-state box (`empty_state_visible: false`) and the 738 x 400 figure starts at 877 px instead of 1511 px at 1440x900. No engine or `rr_network` change was made.

### Commands and results

- Scoped testthat (load_all, dev library): `test-workspace-components.R`, `test-workspace-navigation.R`, `test-results-explorer.R`, `test-workspace-jobs.R`, `test-compact-layout.R`, `test-ui-baseline.R`, `test-baseline-result-figures.R`, `test-heatmap-legibility.R`, `test-cluster-heatmap-scientific.R`: no failure or error lines in the summary reporter output.
- Playwright with the CI-equivalent environment, both projects: `ui-accessibility.spec.ts` + `ui-flows.spec.ts` + `job-lifecycle.spec.ts`: 26 passed, exit 0. A wider run of `results-explorer`, `compact-layout`, `workspace-entry`, `project-roundtrip`, `clustering-roundtrip`, `heatmap-legibility`, `input-review`, `landing-ui`, `scientific-heatmaps`, `baseline`: 61 passed, 9 failed; the 3 narrow-project failures (`clustering-roundtrip.spec.ts:159`, `heatmap-legibility.spec.ts:379`, `scientific-heatmaps.spec.ts:348`) were caused by the new menu auto-close racing the specs' menu handling, fixed by the instant-close CSS above and re-run green (narrow, with `ui-flows` and `project-roundtrip`: 10 passed). The remaining 6 failures are environmental: `workspace-entry.spec.ts:205` (axe-core 4.13.0 present, 4.14.0 pinned; both projects) and `baseline.spec.ts:25` / `:51` (missing `resources/render.json`, produced by the gate's resource-measurement step; both projects).

### Changed existing-test assertions

None changed or removed. New tests only (added to `test-workspace-components.R`, `test-workspace-navigation.R`, `test-results-explorer.R`, new `ui-accessibility.spec.ts` and `ui-flows.spec.ts`). `results-explorer.spec.ts` is unchanged: the explorer live-region absence is asserted in `ui-accessibility.spec.ts`.

### M1 follow-up (lead verification fixes)

- `design-system.spec.ts` pins sha256 digests of `R/workspace_components.R`, `inst/application/www/custom.css` and `tests/testthat/test-workspace-components.R`; M1 intentionally changed these frozen design-system inputs, so the three digests were re-pinned (reason recorded here; no assertion weakened).
- F4 disabled style reworked without opacity (the SPEC-WS-002 contrast guard refuses opacity, and scoping the rule away from the fixture would bypass it): disabled controls use explicit tokens, background `rgb(226, 232, 240)` (`--rs-border`), text `rgb(71, 85, 105)`, border `rgb(100, 116, 139)`, opacity 1, `cursor: not-allowed`, no shadow, and no hover change. `custom.css` digest in `design-system.spec.ts` re-pinned once more for this reason. `ui-accessibility.spec.ts` asserts those disabled colours and that the disabled header action's background and text colour differ from an enabled button's (`#rr_visualize-rr_load`, attached as `enabled-vs-disabled-colours`). Before: the same controls were drawn at opacity 0.5 over their enabled colours (`.btn` default 0.65).
- AC-004: the sidebar link's outline was read while the earlier `transition: all` rule was still animating it (width 0 px at read time under the pinned Chromium); the focus-visible rule now sets `transition: none`, so the indicator is complete at once.
- `workspace-ui.js` no longer auto-hides notifications whose id starts with `shiny-notification-job-` (a running job's persistent progress notification); `ui-flows.spec.ts` asserts such a notification is still present after more than 6 s.

### Gaps

- The browser specs were written before the implementation but their first execution was against the implemented tree, so no browser RED output was captured (testthat RED was captured: the new tests failed before the change).
- `axe-core` 4.14.0 (pinned) is not installed here, so `workspace-entry` M15 and any `design-system` axe checks were not run; `baseline.spec.ts` needs the gate's resource measurements. The lead's full gate covers them.
- Full R suite and full browser suite were not run (lead's gate). No CI run exists (hosted CI disabled).
- AC-002 was measured with one failed enrichment and one succeeded clustering as the two finished jobs; the failed job's Retry button sits inside the collapsed panel until it is opened (job-lifecycle specs do not click Retry).
- AC-006: the 50 selectize-plugin `role="log"` nodes are third-party; the test pins them by position (body child, no id, no class), not by plugin name.
- Contrast and focus were measured on the routes and controls named in the tests, not on every control in the app.

## M2 - copy and validation quick wins

Tree: `cbb46e3` plus the M2 working-tree changes. Pinned toolchain (`node_modules` of the reconcile worktree: @playwright/test 1.56.1, axe-core 4.14.0).

### Changes

- F9 / AC-008: `workspace_display_dt()` (`R/round_table.R`) shows data frames with display labels (for example `from_deg` as "Source gene list", `GeneID_header` as "Gene ID column", `Representative_Term` as "Representative term", `Padj` as "Adjusted p-value"), an em-dash for unknown cells (`?`, `NA`, `NULL`, empty), p-value columns to three significant figures and the row-name column hidden (hidden, not dropped, so the editable tables' cell-edit column indexes are unchanged). Formatting is done by DT column renderers, so numeric columns still sort as numbers and the stored data frames, downloads and projects are untouched (the M0 download golden is re-checked in `test-ui-copy-and-figures.R`). Applied to the Enrichment-figures result list and Table tab, the Cluster figures list and details table, and the Enrich gene-list, result-list and preview tables (the two Enrich preview tables keep the file's own column names, `labels = FALSE`). CSS keeps long cells inside the table width.
- F5 / N7 / OD-4 / AC-009: `deg_detect_gene_column()` (`R/file_handling.R`) recognises a column by the existing `possible_gene_id` name pattern without the first-column fallback; `add_file_degdf` is unchanged. The upload observer in `R/enrich_tab.R` adds a recognised list and confirms "Added <file>: gene column <col>, <n> rows."; for an unrecognised list it adds nothing, reports the detected columns and row count, and opens a prompt (pick the column, or Cancel). Pick adds exactly one dataset with the chosen column renamed `GeneID`; Cancel adds nothing.
- N4 / AC-010: a missing-package error keeps the install line in the run record's `error_summary`; `workspace_jobs_environment_failure()` classifies it and yields the complete command (built from the package name when the message has none); the job status shows the message plus the command in a copyable `code.rs-job-command` with a Copy button (`workspace-ui.js`, text copied from `data-copy`, never written as HTML); `workspace_jobs_retry_offered()` returns FALSE for it and is unchanged otherwise; the notification no longer advises Retry for it.
- N3 / AC-028: the `.rds` refusal is three short sentences (nothing was loaded; open a `.json` session or a project `.zip` instead; convert once on your own computer) with the conversion steps (download the repository ZIP, unzip, run `Rscript scripts/convert-trusted-session.R my-session.rds my-session.json` from inside the folder, needs R and jsonlite, upload the `.json`) in a closed `<details>` with a Copy button. It is an error notification, so it clears on navigation (M1).
- F15: "View rich score or p-value?" is "Show rich score or p-value", "View Padj or Pvalue?" is "P-value type", the term-count sliders start at 1, "Select keytype" is "Select gene ID type", and the two help dialogs use the display labels.

### Acceptance (new automated tests)

| AC | Tests |
|---|---|
| AC-008 | `test-ui-copy-and-figures.R` "AC-008 ..." (5 tests: labels and untouched data, p-value formatting, hidden row-name column and renderers, module tables, M0 download golden); `ui-flows.spec.ts` "AC-008 table display" (1440x900: no raw header names, no empty row-name header, no "?" cell, p-values with at most 3 significant figures, "Adjusted p-value" header inside the table width) |
| AC-009 | `test-input-review.R` "AC-009 ..." (5 tests: report, pick, cancel with the Save summary, valid list, detection); `ui-flows.spec.ts` "AC-009 gene-column validation" |
| AC-010 | `test-workspace-jobs.R` "AC-010 ..." (4 tests: classification, summary, Retry offered, message and command block); `ui-flows.spec.ts` "AC-010 environment failure" |
| AC-028 | `test-ui-copy-and-figures.R` "AC-028 ..."; `ui-flows.spec.ts` "AC-028 old session file" (at most 3 sentences, steps closed then open, command and Copy, gone after navigation) |

### Changed existing-test assertions

- `test-compact-layout.R`: the pinned Enrich label "Select keytype" is now "Select gene ID type" (F15 keytype wording; this file is outside the M2 list but the label change requires it).
- `test-input-review.R` case 3: the hostile-name `.xlsx` fixture's gene column is renamed from `<b>x</b>` to `<b>x</b> gene` so it is still a recognised gene column under OD-4; every assertion is unchanged.
- `design-system.spec.ts`: the frozen digest of `inst/application/www/custom.css` is re-pinned (M2 appends table and command styles; the file is a frozen design-system input).
- No assertion was removed or weakened.

### Verification

Full browser gate (`scripts/test-workspace.sh browser`, CI environment, pinned toolchain): `4 failed`, `110 passed (15.9m)`; the failures were `design-system.spec.ts:803` in both projects (native-zoom launch only) and `ui-flows.spec.ts:205` AC-008 in both projects. The AC-008 failure was a race in the new test (it read the Results tables before they rendered); the test now polls for them, and `ui-flows.spec.ts -g AC-008` then passed in both projects. No product file changed after that gate run.

### Gaps

- The implementation was written before its tests this time, so no RED output was captured for M2 (the tests were then run against the finished code).
- AC-008 was finished on the files outside the original M2 list at the lead's direction (`R/cluster_tab.R`, `R/cluster_upload_tab.R`, `R/results_explorer.R`): the Cluster-page summary and details tables and the importer-page tables use `workspace_display_dt`; the Explorer table keeps its labels and `formatSignif` and gains an em-dash for unknown text cells. Changed existing assertion: `test-baseline-ui-workflows.R` expected the raw header `Representative_Term` on the Cluster summary table and now expects the label "Representative term".
- Missing-package classification matches on the message text ("is required", "no package called", "is not installed", "not available"), not on a condition class.
- The AC-010 browser test relies on the annotation package being absent in the test environment (it asserts a failed run with an install command).

## M3 - one visual system

Tree: `8c275a5` plus the M3 working-tree changes. Pinned toolchain.

### RED (captured before the implementation, against the M2 tree)

`tests/e2e/ui-layout.spec.ts` run alone: `8 failed` (all four tests in both projects). Excerpts:

```
AC-011  distinct box header styles: ["rgb(15, 111, 197)|...|rgb(255, 255, 255)","rgb(23, 162, 184)|...|rgb(255, 255, 255)","rgba(0, 0, 0, 0)|...|rgb(30, 41, 59)","rgb(240, 247, 255)|..." (6 in all)
        Expected: 1   Received: 6
AC-012  custom.css has no transition: all     Received: 9 x "transition: all"
AC-012  empty Home strip                      Received: ["div#home-demo_status.shiny-text-output shiny-bound-output recalculating"]
AC-012  reduced motion                        Received: [".main-sidebar: 0.3s, 0.3s", ".content-wrapper: 0.3s, 0.3s", ".sidebar-menu > li > a: 0.2s" (x3), ".sidebar-menu .treeview-menu > li > a: 0.2s" (x3)]
```

(Full excerpt kept in the session scratchpad as `m1/red3-excerpt.txt`.)

### Changes

- D / F8 / AC-011: appended CSS gives every box, whatever status or `solidHeader` it was built with (including plain boxes), the same header background (`--rs-primary-lighter`), header border, title font, size, weight and colour (`--rs-primary-dark`) and the one primary top border. The `btn-action-hero` blue-to-teal gradient is now solid primary. "Load Session" is `btn-primary` instead of the green `btn-success`; red stays on `btn-danger` (Remove/Delete) and error notifications. The inline `.box-title { font-size: 20px }` style in `R/rr_visualize_tab.R` is removed.
- F16 / AC-012: the nine `transition: all var(--rs-transition)` rules in the pre-marker CSS are now `color, background-color, border-color, box-shadow` (the M1 focus rule's `transition: none` still wins). The empty Home result message no longer renders as a bordered strip (plain text in `.home-status`; an empty text output loses its border and padding but is not hidden: a first version used `display: none` and, because Shiny does not render hidden outputs, left them empty forever and broke the clustering, heatmap and project specs). Submenu icons share the top-level icon width and margin (appended rule). A `prefers-reduced-motion` block removes the transitions of the sidebar (including `body.sidebar-open .main-sidebar`), content, header, menu links, boxes, buttons and notifications.

### Acceptance (new automated tests, both projects pass)

| AC | Tests |
|---|---|
| AC-011 | `ui-layout.spec.ts` "AC-011 one box style and semantic colours" (all 8 routes in a populated workspace: one computed header background/border/title font, one top border; every element whose background or border equals `--rs-danger` or `--rs-success` is inside a named destructive, error or success class or role) |
| AC-012 | `ui-layout.spec.ts` "custom.css has no transition: all", "an empty Home renders no empty bordered status strip", "with reduced motion the menu and notification transitions last at most 0.01 s" |

### Lead-approved scope addition: pinned CSS digest

`tests/testthat/test-workspace-components.R` pins the md5 of the CSS before the SPEC-WS-002 marker ("original CSS bytes precede additive scoped workspace rules"). F16 requires editing that region (nine `transition: all` rules), so the digest in that test was re-pinned, and nothing else in the test changed: before `3dc7da1312126fb3a028db075e1c0e60`, after `5f71dabdcf3df0ea8d7f66367f463678`. This file is outside the M3 row; the lead approved the addition and will amend the SPEC row. `design-system.spec.ts` frozen sha256 digests of `custom.css` and `test-workspace-components.R` were re-pinned for the same reason (computed from the new file contents). The pre-marker edit is limited to the nine transition values; all other M3 CSS is appended.

### Changed existing-test assertions

Only the two digest values above (md5 in `test-workspace-components.R`, sha256 entries in `design-system.spec.ts`). No assertion removed or weakened.

### Gaps

- The box-style check measures header and top-border computed styles on the routes and boxes present in the populated workspace; `tabBox`/`nav-tabs-custom` widgets are not box headers and were not unified.
- Red and green are checked by exact equality with `--rs-danger` / `--rs-success`; tints (`--rs-danger-light`, `--rs-success-light`) and text colours are not part of the AC-011 check.
- The submenu icon alignment has no automated assertion (AC-012 does not name it); it is an appended CSS rule.

## M4 - figure legibility

Tree: `8fd0085` plus the M4 working-tree changes. Pinned toolchain.

### RED (captured before the implementation)

The new testthat tests were written first and run with the `R/` changes stashed (`test-ui-copy-and-figures.R` and `test-heatmap-legibility.R`): 11 failures or errors, one per missing behaviour, for example `object 'hmap_colors' not found`, `unused argument (top_n = 30)`, the heatmap colour stops not viridis, tick labels not truncated, network label size `7.6 < 10` px, and `object 'hmap_label_limit' not found`. Excerpt kept in the session scratchpad as `m4-red-excerpt.txt`. Two of the RED errors (title read from the unbuilt plot, `layout$title$text` on a string) were defects in my first test code and were corrected afterwards; the other failures are the intended ones.

### Changes (display only; no plotted value is recomputed)

- Heatmap scale: enrichment (`custom_hmap`, `topterm_hmap`) and cluster summary heatmaps use `hmap_colors` (`grDevices::hcl.colors(9, "viridis")`); the cluster term heatmap (`cluster_hmap`, heatmaply) passes viridis explicitly. The red-to-green `hmap_color_low/high` constants are gone.
- OD-6: `comprehensive_hmap(..., top_n = NULL)`; with `top_n = 30` the clusters are ordered by significance (smallest p in any dataset; the display counts from the top of the reversed axis, so the most significant cluster is the last category) and `hmap_row_view(limit = )` shows the first 30 with the title "30 of N shown, most significant first". The built figure keeps every row (all N clusters x datasets). Default `top_n` is NULL, so the existing 400-row windows are unchanged. In the app, Cluster figures shows the top 30 by default, a "Show all clusters" checkbox and the notice "30 of N shown (most significant first)" / "All N clusters shown"; "Show all" restores the 400-row windows (the window selector appears only then); the checkbox resets on a new selection. No control appears for 30 or fewer clusters.
- Dot plot: title "Enriched terms: rich score, dot size = gene number, colour = -log10(Padj)", x axis "Rich score (significant genes / annotated genes)", colour bar "Colour: -log10(Padj)", and a size legend annotation "Size legend: dot size = number of significant genes (min to max genes)". Trace data, marker sizes and `sizeref` are unchanged (the `test-baseline-result-figures.R` pins pass unchanged). Bars are unchanged (already ordered by the plotted value).
- Enrichment-heatmap tick labels are cut at 40 characters with an ellipsis (hover text keeps the full term; the categories themselves are untouched).
- Network: label size 3.2 mm (about 12 px, was 2 mm about 7.6 px), a "Node colour" legend (More / Less significant term, taken from the result's p-value column) and a caption (node size grows with the number of genes in the term); the default size legend is hidden. Nodes, edges and data are those of the unchanged `richR::ggnetwork` output.
- N6 / AC-029: no engine change. The M0 reproduction named the root cause (a never-hidden static empty state above a figure that renders); M1's server-driven empty state fixed it. The browser test now verifies it at both sizes.

### Acceptance (new automated tests)

| AC | Tests |
|---|---|
| AC-013 | `test-ui-copy-and-figures.R` "AC-013 ..." (viridis scale on all heatmaps, top 30 with every row kept, bars ordered and equal to the M0 golden order, dot plot title/axes/size legend, truncated heatmap labels with full hover text, network label size and colour legend); `test-heatmap-legibility.R` "SPEC-WS-013 OD-6 a display limit ..." (401 clusters: top 30 shown, all 401 rows kept, unlimited figure still "Rows 1-400 of 401"); `test-ui-baseline.R` (M0 figure goldens, keyed by term, unchanged); `heatmap-legibility.spec.ts` (the existing 400-row window checks now run after "Show all clusters", with the "30 of N shown" notice asserted first) |
| AC-029 | `test-ui-copy-and-figures.R` "AC-013 and AC-029 network nodes exist ..." (each demo result builds at least one node, equal to the golden node count); `ui-flows.spec.ts` "AC-029 network figure" (1440x900 and 390x844: image at least 200 x 200 px within 10 s, empty state not visible, the figure is the element at its own centre) |

### Changed existing-test assertions

- `heatmap-legibility.spec.ts` `select()`: for results with more than 30 clusters it now asserts the notice "30 of N shown", ticks "Show all clusters" and waits for "All N clusters shown" before the existing checks (they assert full 400-row windows, which OD-6 moved behind "Show all"); no assertion removed or weakened.
- `test-heatmap-legibility.R`, `test-baseline-result-figures.R`, `test-cluster-heatmap-scientific.R`: only the new test was added to the first; the others are unchanged and pass.

### M4 follow-up (lead verification of the screenshots)

- Dot and bar plots: the height grows with the displayed terms (`rr_term_plot_height()`: 160 px plus 18 px per term, minimum 400 px, so 610 px for 25 terms and 1060 px for 50); the widget element is resized to it (`onRender`); y-axis tick labels are truncated at 40 characters (full term in the hover text) and the left margin is automatic. Tests: `test-ui-copy-and-figures.R` "AC-013 dot and bar plot heights grow with the number of displayed terms" (25 and 50 terms, both plots, truncation and hover text); `ui-flows.spec.ts` "M4 y-axis term labels" (1440x900, dot and bar: no two adjacent tick labels overlap, by bounding boxes).
- Network: only the 15 most significant terms (by Padj, else Pvalue) are labelled, the caption says so, and every node is still drawn; node colours use a viridis scale (dark = more significant) set through the colour scale, so the node data (and the M0 golden) is unchanged. Test: `test-ui-copy-and-figures.R` "AC-013 network: only the 15 most significant terms are labelled ...".
- Screenshots re-taken: `scratchpad/m4-shots/*-v2.png`.
- Full browser gate after the follow-up (CI environment, pinned toolchain): `2 failed`, `126 passed (16.1m)`; the failures are `design-system.spec.ts:803` in both projects (native-zoom launch only).

### Gaps

- The cluster term heatmap (`cluster_hmap`) already used heatmaply's viridis default; it now passes it explicitly. The dot plot's colour scale is plotly's default sequential scale (the SPEC asks viridis for the heatmaps).
- Network node colours are now a viridis scale applied through the plot's colour scale (the node data still carries richR's original colours).
- Row significance for the top-30 ordering is the smallest p-value across datasets of the displayed value (mean/median/min/max as chosen), not a separate statistic.
- `scientific-heatmaps.spec.ts` and `clustering-roundtrip.spec.ts` (not in the M4 list) were not edited and pass in the full gate with the default top 30.
- Full browser gate (CI environment, pinned toolchain): `2 failed`, `124 passed (16.6m)`; the failures are `design-system.spec.ts:803` in both projects (native-zoom launch only).
- Screenshots (1440x900): `scratchpad/m4-shots/` (`1-enrichment-heatmap.png`, `2-cluster-heatmap-top30.png`, `3-cluster-heatmap-show-all.png`, `4-dot-plot.png`, `5-network.png`), taken from a 39-cluster session built from go1, go2 and kegg1.

## M5 - context bar and job tray

Decisions
- One context bar (dataset switcher, recorded-metadata chips, one "N not recorded" disclosure, job badge, Cluster/Create-figure actions) replaces the active-workspace card on Enrich, Enrichment figures and Cluster. Home and Save get none: the card previously shown on Home is removed. The bar renders only when results or jobs exist.
- Jobs live in a slide-over tray (`#jobs-tray`) opened only from the job badge; Escape or the close button returns focus to the badge. The M1 auto-open/auto-collapse script is removed. The job markup and ids are unchanged inside the tray; the one polite job-status live region (AC-006) and the persistent `job-*` notification rule are kept.
- A running job stays visible without opening the tray: the badge reads "1 job running" / "2 jobs finished" (lead condition).
- The context-bar Cluster action selects the active result in the Cluster result selector before routing (AC-014).
- On narrow viewports the bar keeps switcher, "not recorded" trigger, badge and a Details toggle in one row; name, chips and actions open with Details. The open state survives server rebuilds of the bar (`workspace-ui.js`), and `summary`/`actions` use `suspendWhenHidden = FALSE` because `display: contents` reads as hidden to Shiny.
- "Dismiss" for the bar was not implemented.
- Unused after this change, left in place: the card-specific rules in `custom.css` and `workspace_jobs_ui`'s old inline-disclosure behaviour (summary text writer in `workspace-ui.js` still maintains the tray summary).

Changed or removed assertions (reason)
- `test-workspace-navigation.R`: the header markup assertion `aria-label="Active workspace"` became `class="rs-workspace rs-context-bar"` (card replaced by the bar). The Cluster action previously sent no input message; it now sends exactly one (`cluster-selected_rrs`), so `expect_length(..., 0L)` became an identical-ids assertion and the "own select" allow-list gained `cluster-selected_rrs` (AC-014).
- `ui-flows.spec.ts`: the AC-002 inline-panel test (collapsed height <= 64 px on every page) is replaced by AC-015 tray assertions (no inline log, badge text, per-row textual state, run settings closed, run ids not red); the AC-010 test only opens the tray through the badge before reading the install command (lead-approved scope addition).
- `job-lifecycle.spec.ts`: the fixture UI now carries the badge and styles; jobs are read after `openTray`; AC-015 test added (badge text, tray closed by itself, focus, Escape).
- `workspace-entry.spec.ts`, `ui-accessibility.spec.ts`: on a narrow viewport the header actions sit behind the Details toggle, so the specs call `openContext` before touching `#workspace-create_figure` / `#workspace-cluster_results` (no assertion changed otherwise).
- `design-system.spec.ts` (frozen digests): `inst/application/www/custom.css` re-pinned `d4ffa69a...` -> `df2f13a6...` because M5 appended the context-bar/tray block after the SPEC-WS-002 marker; the pre-marker region md5 `5f71dabdcf3df0ea8d7f66367f463678` is unchanged.

RED
- `scratchpad/m5-red-testthat.txt` (test-workspace-shell.R and navigation failures) and `scratchpad/m5-red-e2e.txt` (7 desktop failures: job-lifecycle, ui-accessibility, ui-flows AC-015, ui-layout AC-014 x2 and AC-016 x2) were captured before any implementation.


M5 follow-up (lead verification of 505773e)

- Defect: the 390x844 context bar was 102 px tall once a job existed (limit 64); the AC-014 test never measured the bar with the badge showing. RED: the new test `AC-014 context bar with a job at 390x844` failed on 505773e with `Expected: <= 64 / Received: 102` (`scratchpad/m5b/red-e2e.txt`, both projects); the desktop twin (54 px) passed.
- Fix: on narrow viewports the bar tightens its gaps (6 px), the switcher shrinks to a 64 px minimum, the badge and the Details toggle use 4x6 px padding at 12 px text and keep a 36 px hit area. Measured at 390x844 with "1 job finished": switcher 96, trigger 85, badge 93, toggle 56 px, one row, bar 54 px. The badge text is unchanged ("1 job finished"/"1 job running"). The test also measures the bar with the badge words of other mixes (lead addition): "1 job running" (what one running plus two finished jobs says), "2 jobs running" and the queue mix. The queue mix initially wrapped (86 px, RED), so with running plus queued jobs the badge now reads "2 running, 1 queued" with `aria-label="2 running, 1 queued jobs"` (the name starts with the visible words); gaps went to 4 px and badge/toggle padding to 4x5 px. The mixes were measured by writing each text into the badge, not by running real jobs.
- Toggle looked disabled: the `btn btn-default` classes pull in `.btn-default { color/border !important }`; the toggle no longer carries them and is styled by its own rule (text `--rs-text`, border `--rs-text-secondary`, no opacity). Asserted in the same test (`rgb(30, 41, 59)` / `rgb(100, 116, 139)`).
- Tray status duplication: RED `ui-flows.spec.ts` AC-015 test found 5 visible status words for 2 jobs (`scratchpad/m5b/red-e2e.txt`). `jobs_announce` is now visually hidden with the `rs-sr-only` pattern (kept as the one polite live region, not display:none); each `jobs_status` paragraph is visually hidden unless it carries a note or an error, and then only its status word is hidden. The tray names each job's status once (asserted: 2 visible status words for 2 jobs; announce box width <= 2 px).
- Dismiss: finished rows (succeeded, failed, cancelled, interrupted) of the session's own runs get a Dismiss button; it hides the row, its status paragraph and its share of the badge count for the session. It is a view setting in `workspace_jobs_server` (a reactiveVal), so the registry is untouched and a page reload shows nothing dismissed. Not offered for queued/running/stop-requested/detached rows, for imported rows, or for superseded rows (existing assertions R13e and R28 require those rows to carry no buttons, so they were not changed). Tests: three `test_that` blocks in `test-workspace-shell.R` (finished-only offer, hidden row and count, last row removes the badge) and the Dismiss steps in the `ui-flows.spec.ts` AC-015 test.
- Changed assertions: none removed; added assertions only. `design-system.spec.ts` custom.css digest re-pinned a second time, `df2f13a6...` -> `8f1f9883...`, because the narrow bar rules, the toggle styling and `.rs-sr-only` were added after the marker; the pre-marker md5 stays `5f71dabdcf3df0ea8d7f66367f463678`.

Verification
- Full testthat (installed candidate, CI library): `RESULT files 35 tests 4224 failed 0 errors 0 skipped 0` (the two `test-dependency-integration.R` environment errors did not occur in this run).
- Full browser gate (fresh scratch, pinned toolchain): `6 failed`, `134 passed (19.1m)`. `design-system.spec.ts:803` fails in both projects (native-zoom launch only). `baseline.spec.ts:25` and `:51` failed in both projects only because this scratch had no `resources/render.json` (the CI `resource_measurements render` pre-step was not run); after running that step they pass (`8 passed`).
- Screenshots (1440x900 and 390x844, tray closed and open): `scratchpad/m5-shots/`.

Follow-up verification
- Full testthat (final build, CI library): `RESULT files 35 tests 4245 failed 0 errors 0 skipped 0`.
- Full browser gate via `scripts/test-workspace.sh browser` in a fresh scratch (render pre-step included): `2 failed`, `142 passed (18.2m)`; the failures are `design-system.spec.ts:803` in both projects (native-zoom launch only).
- Screenshots regenerated in `scratchpad/m5-shots/` (1440x900 and 390x844: Enrich, Enrichment figures and Cluster with the tray closed and open; 390x844 Cluster with Details open).

## M6 - task stepper, Data step and information architecture

Decisions
- The stepper (`workspace_stepper_ui`/`workspace_stepper_content`) sits above the context bar on every page. Five steps in order (Data, Enrich, Results, Cluster, Save), each a native button with a textual status (`workspace_step_status`, derived from the counts of gene lists, imported results, results made by enrichment and cluster results), the next action in its `title` and in text read by assistive technology, and `aria-current="step"` on the current one. Every step opens whatever the status says; a click calls the sidebar anchor of its route. At 390x844 one "Step N of 5: Name" disclosure replaces the list (custom.css shows one of the two).
- Navigation is one flat list in task order: Home, Data (`update_tab`), Upload files (`cluster_upload_tab`, the importer sub-route, kept as a sidebar anchor and with its caption because `baseline.spec.ts` clicks a link named "Upload files"), Enrich, Enrichment figures, Cluster, Cluster figures, Save. No collapsible groups, no section headers. Route `tabName` strings are unchanged.
- Data (`update_tab`, `updateTabUI(data_step = TRUE)`) hosts the DEG upload (`enrich_upload_box_ui`), the "Load enrichment result" box with its input review (`rr_load_box_ui`) and "Open project" (`save_open_project_ui`), each under its own module namespace so every id is unchanged, above the existing rename/remove boxes. The module UI functions keep their default output (`enrich_tab_ui(upload = TRUE)`, `saveTabUI(open_project = TRUE)`, `updateTabUI(data_step = FALSE)`) so the per-module control contract in `test-compact-layout.R` is unchanged; `app.R` composes the Data step by passing `upload = FALSE`, `open_project = FALSE`, `data_step = TRUE`. `rr_vis_tab_ui` loses the loader outright (REQ-015 moves it).
- The context bar also shows on Data. Home "Upload gene lists" now opens Data and "Open saved analysis" became "Open project" and opens Data, because both controls live there.
- Removed (REQ-015): the three inert "Text input" tabs (`rr_text`, `rrtext_name`, `upload_rrtext` in the Results page and the importer; `rr_text`, `clustext_name`, `upload_clustext` in Cluster figures) and the whole "Load cluster result" panel (`clus_files`) from Cluster figures. The importer keeps its file upload. The working DEG "Text input" tab stays (it has observers) and now sits on Data.
- Save: one primary "Save project" (the project download), project name field (default `richstudio_project_<time>_<id>`, so the download name matches `^richstudio_project_.*\.zip$`), and the JSON session (download and load) under an "Advanced: JSON session" disclosure. "Bookmark" left the sidebar; a "Share link" bookmark button sits in the page footer.
- Handoffs (REQ-009): a "Loaded N results" / "Loaded N gene lists" notification with a next action (Cluster these results / Go to Enrich) whenever data are added; a dataset switch in the context bar sets the Cluster and Results selectors to it (a dataset made active by the demo load does not, so the existing flows that pick results by hand are unchanged); opening Enrich with an empty selection selects the gene list the active result came from; a "Clustering finished" notification with "View cluster figures", which opens Cluster figures with the new result selected; the enrichment heatmap result selector defaults to the first result when nothing is selected.

RED (run on b08dbad)
- testthat: `scratchpad/m6/red-testthat-shell.txt` (10+ failures/errors: step status, stepper content, flat sidebar, Data step composition, no inert tabs, Save step) and `scratchpad/m6/red-testthat.txt` (compact-layout and navigation assertions edited first).
- Browser: `scratchpad/m6/red-e2e.txt`: 8 desktop failures for AC-017 (2), AC-018 (2), AC-019 (4).

Changed or removed existing assertions (reason)
- `test-compact-layout.R`: removed `rr_files`, `rr_load`, `rr_text`, `rrtext_name`, `upload_rrtext` from the Results contract, `rr_text`, `rrtext_name`, `upload_rrtext` from the importer contract and `clus_files`, `rr_text`, `clustext_name`, `upload_clustext` from the Cluster figures contract (the controls the SPEC removes or moves, REQ-015/M6). `rr_files` and `rr_load` stay in the importer contract.
- `test-workspace-navigation.R`: Home action label "Open saved analysis" -> "Open project", and the Home actions "Upload gene lists" and "Open project" now navigate to `update_tab` (their controls live on Data); the sidebar caption test lost the two group tabNames and now expects the flat captions (Data, Save) and no `menu-open`; the "routes every action through the sidebar" test also allows the Results selectors that a dataset switch now sets (AC-018).
- `ui-flows.spec.ts`: the loaders are clicked on Data (`#enrich-deg_load`, `#rr_visualize-rr_load`, project open), the AC-009 list-of-sets checks visit Enrich for the list (the list box stays on Enrich), the AC-028 test opens the Advanced disclosure, the success-toast overlap check measures the Data step's primary action (`#save-load_project`) instead of the former Save-page button, and the AC-001 populated test now expects the heatmap selector to default to `go1` instead of choosing it.
- `ui-layout.spec.ts`: the AC-011 test loads the demo gene lists from Data.
- `workspace-entry.spec.ts`: Home entries and labels follow the table above (the open-project landing is the Data step's project file control); the Save route caption regexp is `/Save/`.
- `compact-layout.spec.ts`: `demo()` loads the demo gene lists from Data, then returns to Enrich. `input-review.spec.ts`: the Home "Upload gene lists" entry lands on Data, and the two results-loader checks run on Data. `project-roundtrip.spec.ts`: opening a project happens on Data, the Save summaries are read on Save.
- `design-system.spec.ts`: custom.css digest re-pinned (before `8f1f9883...`, after `e8345029`)... because M6 appended the stepper, flat-navigation, footer and Data-step rules after the SPEC-WS-002 marker.

Removed ids (REQ-015) and the contract line adjusted for each
| Removed id | Module namespace | REQ-015 item | `test-compact-layout.R` contract line |
|---|---|---|---|
| `rr_text`, `rrtext_name`, `upload_rrtext` | `rr_visualize` | inert "Text input" tab in `rr_vis_tab_ui` | removed from the `rr_visualize` ids |
| `rr_text`, `rrtext_name`, `upload_rrtext` | `cluster_upload` | inert "Text input" tab in `cluster_upload_tab_ui` | removed from the `cluster_upload` ids |
| `clus_files`, `rr_text`, `clustext_name`, `upload_clustext` | `clus_visualize` | the dead "Load cluster result" panel (file upload and Text input tab) | removed from the `clus_visualize` ids |
| `rr_files`, `rr_load` | `rr_visualize` | not removed: the moved Results loader; now rendered on Data with the same ids | removed from the `rr_visualize` ids only because `rr_vis_tab_ui` no longer renders them; the composed-UI test asserts each appears exactly once |

`cluster_upload-rr_files` and `cluster_upload-rr_load` stay in `cluster_upload_tab_ui` (importer). A testthat test (`each moved control appears exactly once in the composed app UI`) asserts the moved ids once and the removed ids zero times.

Out-of-list edits (lead-approved), navigation step only before the same click on the same id
| File:line | Old path | New path | Reason |
|---|---|---|---|
| `ui-accessibility.spec.ts` AC-003 test | Results route, click `#rr_visualize-rr_load` | Data route, same click | the Results loader moved to Data |
| `ui-accessibility.spec.ts` AC-015 test | Enrich route, click `#enrich-deg_load` | Data route, same click, then the Enrich route for the unchanged selection steps | the DEG upload moved to Data |
| `scientific-heatmaps.spec.ts` `loadSession` | Save route, `#save-load_session_file` | same, Advanced `<details>` opened first | JSON session is under Advanced |
| `scientific-heatmaps.spec.ts` `downloadSession`, `heatmap-legibility.spec.ts` (second edit), `clustering-roundtrip.spec.ts` (download step) | Save route, click `#save-download_session` | same, Advanced `<details>` opened first | the JSON session download is under Advanced |
| `heatmap-legibility.spec.ts` `load` | same | same | same |
| `clustering-roundtrip.spec.ts` `loadSessionFile` | same | same | same |
| `landing-ui.spec.ts` | test "analysis menus start expanded and toggle independently": expected two treeview groups, each toggling independently, then a click on the Enrich link | replaced by "the navigation is one flat list in task order with no collapsible group": no `li.treeview` or `.treeview-menu` or collapse toggle, every route link visible, links in task order | AC-019/F14 removes collapsible groups |
| `test-baseline-session-coverage.R:276` | `"Save &amp; Load Analysis Session"` | `"<h2>Save project</h2>"` (fixed) plus `expect_no_match` of the old string | REQ-015 one name "project" |

Verification
- Full testthat (CI library): `RESULT files 35 tests 4368 failed 0 errors 0 skipped 0`.
- Full browser gate via `scripts/test-workspace.sh browser` in a fresh scratch (render pre-step included): `2 failed`, `158 passed (18.7m)`; the failures are `design-system.spec.ts:803` in both projects (native-zoom launch only).
- Layout measured with a populated workspace and a finished job: DEG upload control top 292 px at 1440x900 (limit 300) and 329 px at 390x844 (limit 420) after a final tightening of the stepper button height and the Data heading margins, no horizontal overflow.
- Screenshots in `scratchpad/m6-shots/` (1440x900 and 390x844): Home empty, Data empty and populated, Enrich, Results, Cluster, Cluster figures, Save, and the narrow stepper open.

M6 fixes (lead review of the first M6 commit)
- RED (`scratchpad/m6f/red-e2e.txt`, three tests under "M6 fixes" in `ui-flows.spec.ts`): Save project background `rgb(226, 232, 240)` instead of the primary colour `rgb(15, 111, 197)`; the Advanced summary `::before` content was `none`; one clustering job did not give exactly one clustering notification.
- Fixes: `.btn.btn-default.btn-primary` now wins over the global `.btn-default` !important rule (Save project and Rename DEG are primary); the Advanced summary shows a chevron (closed `\25B8`, open `\25BE`, 36 px hit area kept); the cluster step raises the single finished-clustering notice (counts, result name, "View cluster figures"), and the navigation handoff no longer raises a second one (it only remembers the result to open).
- `custom.css` digest re-pinned again: `673316b6...` -> `91e8527e...`.
- Verification: full testthat `RESULT files 35 tests 4368 failed 0 errors 0 skipped 0`; full browser gate via `scripts/test-workspace.sh browser`: `2 failed`, `164 passed (18.9m)` (only `design-system.spec.ts:803` in both projects). AC-019 upload top with a finished job: 292 px at 1440x900, 329 px at 390x844. Screenshots regenerated in `scratchpad/m6-shots/`.

## M7 - Enrich progressive disclosure

Not started.

## M8 - Results master-detail

Not started.


Open point for the SPEC owner: AC-003 literally requires a disabled control's computed opacity of at most 0.6. That clause conflicts with the SPEC-WS-002 guard (no opacity), so the implemented test asserts explicit colours instead; AC-003's wording needs a registry revision.
