---
id: "SPEC-WS-013"
title: "Workspace UI/UX restructure"
version: "0.3.6"
status: draft
created: "2026-11-03"
updated: "2026-11-04"
author: "workspace planning team"
priority: P1
phase: "v0.1.7 target"
module: "R/"
lifecycle: spec-anchored
tier: L
tags: "workspace, usability, accessibility, layout"
---

# SPEC-WS-013 — Workspace UI/UX restructure

Planning-only draft (Tier L; this single leaf document carries the design, research and implementation contract, so no separate design.md or research.md exists). No implementation or test completion is claimed. Companion umbrella: [SPEC-WORKSPACE-001](SPEC-WORKSPACE-001/plan.md). Evidence input: [UX review 2026-11-03](../quality/ux-review-2026-11-03.md) (findings F1-F16, proposals A-E) and [UX re-review on the reconciled tree 2026-11-04](../quality/ux-review-2026-11-04-reconciled.md) (per-finding status and new findings N1-N7). Registration and dependency delta: [amendment 013](SPEC-WORKSPACE-001/amendments/013-registration.md).

## Problem and observable outcome

The engine grew (input review, job registry, projects) while the interface grew by stacking panels onto the original dashboard. The compact-layout line (now merged) did not reach the screens the review criticised: every analysis page still opens with a tall active-workspace card and an unstyled job log, which now also shows on Cluster and Save (N1); several views say "No data to display" above populated output; copy mixes biology with developer internals; disabled buttons look enabled; focus is invisible on navigation links; help text is below contrast minimums.

After this leaf, a user sees one task-ordered stepper (Data, Enrich, Results, Cluster, Save), one compact context bar for the active dataset with a job badge that opens a slide-over job tray, a Results page that is a master-detail view (term table plus linked figure), an Enrich page that leads with plain-language defaults and keeps the technical review under Advanced, one box style with colour reserved for status, and the High/Medium findings F1-F14 and N1-N4 closed with measured evidence. Stored data, numerical results, run records, the project format and route identifiers are unchanged.

Owner decision (2026-11-03): this restructure is scheduled before SPEC-WS-009 and SPEC-WS-010, which build on the new layout.

## Recorded owner decisions

Each row is "owner default applied 2026-11-04; owner may override". An override before the affected milestone starts is a registry revision of this document, not an implementer choice.

| ID | Decision (applied) |
|---|---|
| OD-1 | SPEC-WS-008 merges into the integration branch first, after its own independent review against its unchanged REQ-001..005 / AC-001..004; milestone M8 reshapes the 008 explorer into the Results master-detail view. 008's server logic (stable identity keys, linked selection, evidence-aware missing states, exact-value export) is kept and its scenarios still pass after M8. The alternative (013 supersedes the 008 UI) is not planned. |
| OD-2 | No interim production deploys while this leaf is in progress; one deploy after M8 and the full-suite CI. Production deployment remains the separate user-executed protocol. |
| OD-3 | The Data step is hosted on the existing Manage Files route (`update_tab`), renamed "Data". Uploads (DEG sets, enrichment results) and opening projects/sessions live there; the Enrich page keeps only selection of already-uploaded sets, settings and Run. Resolved 2026-11-04: the enrichment-results importer keeps its own route `cluster_upload_tab` as a Data-step sub-route (plan item 2). |
| OD-4 | When no gene column is recognized at upload, the user picks the gene column; both the pick path and the cancel path are tested (AC-009). |
| OD-5 | No automatic species inference. The last species chosen in the session is remembered and shown in the Enrich summary. |
| OD-6 | The cluster heatmap shows the top 30 clusters by default, with a "Show all" control and an "N of M shown" notice. Display filter only. |
| OD-7 | The non-developer usability check is a manual, owner-run, non-blocking check after M8. It is a recorded gap carried to the umbrella acceptance `docs/specs/SPEC-WORKSPACE-001/acceptance.md` AC-012 (unfamiliar-user task and compatibility gate). It does not gate acceptance of this leaf; SPEC-WS-011 depends on this leaf, not the reverse. |
| OD-8 | "Not recorded" fields collapse into one compact, visible disclosure. This keeps umbrella REQ-002 and SPEC-WS-003 REQ-003 ("show missing metadata as not recorded") satisfied. |

## Reconciled tree: what the merge already provides

Target tree: integration `ab4e509` (deployed compact-workspace line) plus SPEC-WS-008 (OD-1). Symbols cited below were checked by grep on HEAD `9a88ce0`; the whole leaf starts only after 008 merges, because M1-M8 edit `R/rr_visualize_tab.R`, `R/clus_visualize_tab.R` and `inst/application/app.R`, which 008 also changes.

- Already present, so not re-specified: cluster-heatmap labels truncated with an ellipsis, row height 18 px and 400-row keyboard windows with "Rows a-b of N" (`hmap_row_view`, `R/cluster_hmap.R`); Home no longer shows the active-workspace card; Home "Load demo results" lands on Enrichment figures with `go1` active and the cluster-figures selector pre-filled after clustering; Run sits beside the Enrich settings; Save/Load copy for old session files.
- Still open (re-review verdict UNCHANGED): F1, F2, F4, F5, F8-F13, F15, F16, N1-N7, the red/green heatmap scales (`R/rr_hmap.R`, `hmap_color_low/high` in `R/cluster_hmap.R`), the dot-plot title and missing size legend.
- Existing guards that this leaf must keep passing: `tests/testthat/test-baseline-result-figures.R` (exact dot order, colours, hover text), `test-heatmap-legibility.R` and `test-cluster-heatmap-scientific.R` (all rows retained, windows of at most 400 rows), `test-compact-layout.R` and `tests/e2e/compact-layout.spec.ts` (control ids appear exactly once per module), `tests/e2e/heatmap-legibility.spec.ts`. They are lock-list targets; an assertion changes only where a changed id, label or layout requires it, with the reason recorded.

## Dependencies and ownership

- Logical prerequisites: SPEC-WS-003, SPEC-WS-004, SPEC-WS-006, SPEC-WS-007, SPEC-WS-008 (merged first, OD-1).
- Downstream: SPEC-WS-009 and SPEC-WS-010 gain SPEC-WS-013 as a logical prerequisite; SPEC-WS-011 lists it (see amendment 013).
- One disposable implementer owns this entire leaf in its own fresh worktree; each milestone is independently reviewed, merged and CI-verified before the next milestone's integration.
- Shared targets are exclusive locks, even for nonoverlapping line edits; the lock list is `SPEC-WORKSPACE-001/dispatch.json` node `SPEC-WS-013` and must equal the union of the milestone file lists below. No `DESCRIPTION`/`NAMESPACE` change is planned.
- Existing test files may change only where a changed id, label or interaction requires it; no assertion is weakened, an assertion is removed only for a control the SPEC itself removes or moves (REQ-015, M6: the `rr_text`, `rrtext_name`, `upload_rrtext`, `clus_files`, `clustext_name`, `upload_clustext` ids and the moved Results-loader ids asserted in `test-compact-layout.R`), and every changed or removed assertion is listed with its reason in the recheck record.
- The SPEC-WS-002 pinned digests (the `test-workspace-components.R` md5 and the `design-system.spec.ts` sha256 map) may be re-pinned only by a milestone that intentionally changes those inputs, with before/after values recorded in the recheck record.
- Upstream richR work is separately owned and integrated through an official release, never edited by this consumer leaf.

### Existing targets (on the reconciled tree)

- `inst/application/app.R`, `inst/application/www/custom.css`
- `R/workspace_navigation.R`, `R/workspace_components.R`, `R/workspace_jobs.R`, `R/home_tab.R`, `R/enrich_tab.R`, `R/input_review.R`, `R/file_handling.R`, `R/round_table.R`, `R/update_tab.R`, `R/save_tab.R`, `R/cluster_tab.R`, `R/cluster_upload_tab.R`, `R/rr_visualize_tab.R`, `R/clus_visualize_tab.R`, `R/rr_bar.R`, `R/rr_dot.R`, `R/rr_network.R`, `R/rr_hmap.R`, `R/cluster_hmap.R`
- `tests/testthat/test-workspace-navigation.R`, `test-workspace-components.R`, `test-workspace-jobs.R`, `test-input-review.R`, `test-baseline-result-figures.R`, `test-heatmap-legibility.R`, `test-cluster-heatmap-scientific.R`, `test-compact-layout.R`, `test-baseline-ui-workflows.R` (shared with completed leaves SPEC-WS-001 and SPEC-WS-003; only display-label assertions may change, each recorded with its reason)
- `tests/e2e/workspace-entry.spec.ts`, `job-lifecycle.spec.ts`, `input-review.spec.ts`, `design-system.spec.ts`, `project-roundtrip.spec.ts`, `compact-layout.spec.ts`, `heatmap-legibility.spec.ts`

### Prerequisite-created targets (created by SPEC-WS-008)

- `R/results_explorer.R`, `R/workspace_selection.R`, `tests/testthat/test-results-explorer.R`, `tests/e2e/results-explorer.spec.ts`

### New targets

- `R/workspace_shell.R`, `inst/application/www/workspace-ui.js`
- `tests/testthat/test-workspace-shell.R`, `test-ui-copy-and-figures.R`, `test-ui-baseline.R`, `helper-ui-baseline.R`
- `tests/e2e/ui-layout.spec.ts`, `ui-accessibility.spec.ts`, `ui-flows.spec.ts`
- `tests/fixtures/ui-baseline/figure-values.json`, `demo-downloads.json`, `input-revision.json`, `project-baseline.zip`
- `docs/quality/ux-review-013-recheck.md`

## Milestones

Each milestone is one mergeable unit: its own commits, scoped local checks, hosted CI on the integration branch, independent review, then merge. A later milestone may refine what an earlier one introduced but must keep its acceptance scenarios passing. Order is smallest-risk first and dependency-correct: no milestone's acceptance needs a later milestone (the Data step, OD-3, is built in M6, so every Data-page clause is checked in M6, not M5). Priority labels only; no time estimates. Abbreviations in the file lists: `T:` is `tests/testthat/`, `E:` is `tests/e2e/`, `W:` is `inst/application/www/`, `rec` is `docs/quality/ux-review-013-recheck.md`.

| Milestone | Scope (findings / proposals) | Target files | Acceptance |
|---|---|---|---|
| M0 Baseline capture (no behaviour change) | Before any change, in commits of their own that precede M1: golden figure values for the demo results, the demo-result downloads as the handlers write them (original names, full precision), the SPEC-WS-004 input revision and query snapshot for fixed inputs, a project saved at the baseline, the reproduction of N6, and the "before" browser measurements (page heights, job-panel height, first-content offsets) | `T:helper-ui-baseline.R`, `T:test-ui-baseline.R`, `tests/fixtures/ui-baseline/figure-values.json`, `tests/fixtures/ui-baseline/demo-downloads.json`, `tests/fixtures/ui-baseline/input-revision.json`, `tests/fixtures/ui-baseline/project-baseline.zip`, `rec` | AC-027 |
| M1 Presentation quick wins (High) | F2 server-driven empty states incl. heatmap; F1/N1 job panel styling of existing markup (compact rows, settings collapsed, collapsed when idle, on every page incl. Cluster and Save); F4 real disabled style and unrecorded metadata collapsed into one visible "not recorded" disclosure; F10 focus-visible outlines and solid input focus ring, one job-status live region (removes the 008 explorer `aria-live` region); F11 text contrast; F13 solid toasts, errors cleared on navigation, success auto-hide; F12 narrow menu closes after navigation | `R/rr_visualize_tab.R`, `R/clus_visualize_tab.R`, `R/workspace_components.R`, `R/workspace_navigation.R`, `R/workspace_jobs.R`, `R/results_explorer.R`, `W:custom.css`, `W:workspace-ui.js`, `inst/application/app.R`, `T:test-workspace-components.R`, `T:test-workspace-navigation.R`, `T:test-results-explorer.R`, `E:ui-accessibility.spec.ts`, `E:ui-flows.spec.ts`, `E:results-explorer.spec.ts`, `rec` | AC-001, AC-002, AC-003, AC-004, AC-005, AC-006, AC-007 |
| M2 Copy and validation quick wins (High) | F9 table display labels, em-dash for unknown, 3 significant figures, no rownames, column widths; F5/N7 gene-column validation in the upload observer with the pick/cancel paths and a report of what was detected; N4 full install command in a copyable block, Retry hidden for environment failures; N3 short plain-language refusal message for old session files with the conversion steps in an expandable block; F15 question-style labels, keytype wording, slider minimum | `R/round_table.R`, `R/rr_visualize_tab.R`, `R/clus_visualize_tab.R`, `R/update_tab.R`, `R/file_handling.R`, `R/enrich_tab.R`, `R/input_review.R`, `R/workspace_jobs.R`, `R/save_tab.R`, `T:test-ui-copy-and-figures.R`, `T:test-workspace-jobs.R`, `T:test-input-review.R`, `E:ui-flows.spec.ts`, `E:input-review.spec.ts`, `rec`, `R/cluster_tab.R`, `R/cluster_upload_tab.R`, `R/results_explorer.R`, `W:custom.css`, `W:workspace-ui.js`, `E:design-system.spec.ts`, `T:test-compact-layout.R`, `T:test-baseline-ui-workflows.R` | AC-008, AC-009, AC-010, AC-028 |
| M3 One visual system (Medium) | D one box style, one accent, semantic status colours from existing `--rs-*` tokens; F8 box title/header consistency; F16 no `transition: all`, empty Home status strip removed, submenu icon alignment | `W:custom.css`, `R/workspace_components.R`, `R/home_tab.R`, `R/workspace_navigation.R`, `R/enrich_tab.R`, `R/update_tab.R`, `R/save_tab.R`, `R/cluster_tab.R`, `R/cluster_upload_tab.R`, `R/rr_visualize_tab.R`, `R/clus_visualize_tab.R`, `E:design-system.spec.ts`, `E:ui-layout.spec.ts`, `rec`, `T:test-workspace-components.R` | AC-011, AC-012 |
| M4 Figure legibility (High) | F7 residual on the reconciled tree: sequential colour-blind-safe heatmap scale (enrichment and cluster), top-30 cluster default with show-all and an "N of M shown" notice (OD-6), colour and size legends (bar order is already by plotted value and stays as pinned by `test-baseline-result-figures.R`), truthful dot-plot title and axis labels, enrichment-heatmap labels truncated with full hover text, legible network labels with legend; N6 network plot investigate-and-fix | `R/rr_bar.R`, `R/rr_dot.R`, `R/rr_network.R`, `R/rr_hmap.R`, `R/cluster_hmap.R`, `R/rr_visualize_tab.R`, `R/clus_visualize_tab.R`, `T:test-ui-copy-and-figures.R`, `T:test-baseline-result-figures.R`, `T:test-heatmap-legibility.R`, `T:test-cluster-heatmap-scientific.R`, `E:heatmap-legibility.spec.ts`, `E:ui-flows.spec.ts`, `rec` | AC-013, AC-029 |
| M5 Context bar and job tray (proposal B) | Single context bar (dataset switcher, recorded metadata chips, one "not recorded" disclosure, job badge) on the Enrich, Results and Cluster pages replacing the active-workspace card; slide-over job tray replacing the inline job log (completes F1, N1, F4; F12 collapse on narrow); the context-bar "Cluster" action passes the active result (F3 part) | `R/workspace_shell.R`, `R/workspace_navigation.R`, `R/workspace_components.R`, `R/workspace_jobs.R`, `inst/application/app.R`, `W:custom.css`, `W:workspace-ui.js`, `T:test-workspace-shell.R`, `T:test-workspace-navigation.R`, `T:test-workspace-jobs.R`, `T:test-compact-layout.R`, `E:job-lifecycle.spec.ts`, `E:workspace-entry.spec.ts`, `E:ui-layout.spec.ts`, `E:ui-accessibility.spec.ts`, `E:compact-layout.spec.ts`, `rec`, `E:ui-flows.spec.ts`, `E:design-system.spec.ts` (frozen custom.css sha256 re-pin only) | AC-014, AC-015, AC-016 |
| M6 Task stepper, Data step and information architecture (proposal A) | Five-step stepper with per-step status and next action, never gating; Data step on the `update_tab` route (OD-3) hosting the DEG upload, the Results-page "Load enrichment result" box (moved here, ids kept) and project open, context bar added there, with the importer route `cluster_upload_tab` as its sub-route; flat task-ordered navigation (F14); the inert "Text input" tabs and the dead "Load cluster result" panel removed (REQ-015); the importer file upload is kept; one primary "Save project" with JSON session under Advanced and one name everywhere; Bookmark out of primary navigation (F15) and into a "Share link" control in the page footer; cross-step handoffs: success state with next action after loading data, active dataset as default selection, "View cluster figures" after clustering, heatmap selector defaults (F3) | `R/workspace_shell.R`, `R/workspace_navigation.R`, `inst/application/app.R`, `R/home_tab.R`, `R/save_tab.R`, `R/update_tab.R`, `R/enrich_tab.R`, `R/cluster_tab.R`, `R/cluster_upload_tab.R`, `R/rr_visualize_tab.R`, `R/clus_visualize_tab.R`, `W:custom.css`, `T:test-workspace-shell.R`, `T:test-workspace-navigation.R`, `T:test-compact-layout.R`, `E:workspace-entry.spec.ts`, `E:project-roundtrip.spec.ts`, `E:input-review.spec.ts`, `E:ui-flows.spec.ts`, `E:ui-layout.spec.ts`, `E:compact-layout.spec.ts`, `rec`, `E:ui-accessibility.spec.ts`, `E:scientific-heatmaps.spec.ts`, `E:heatmap-legibility.spec.ts`, `E:clustering-roundtrip.spec.ts`, `E:landing-ui.spec.ts`, `T:test-baseline-session-coverage.R`, `E:design-system.spec.ts` (custom.css digest re-pin only) | AC-017, AC-018, AC-019 |
| M7 Enrich progressive disclosure (proposal E) | Single-column Enrich in three parts (Gene lists, Settings, Review and run) with plain-language defaults summary, Adjust, sticky Run and summary; the 004 review card under Advanced and in plain register (N5); developer terms replaced; species default from recorded metadata or the session's last choice (F6, OD-5); one gene-list table driving the preview instead of two stacked boxes (F8) | `R/enrich_tab.R`, `R/input_review.R`, `W:custom.css`, `T:test-input-review.R`, `T:test-compact-layout.R`, `E:input-review.spec.ts`, `E:ui-layout.spec.ts`, `E:ui-flows.spec.ts`, `E:compact-layout.spec.ts`, `rec` | AC-020, AC-021 |
| M8 Results master-detail (proposal C, reshapes 008) | Term table (master) at the top of the page, with linked figure (detail), plot type as a segmented control, figure settings collapsed above the figure with Top/Custom heatmap choices inside them (N2), selected-term detail in plain language with technical identifiers under Details, cross-dataset values from 008, "Cluster these results"; no Explorer tab; linked-term panel on Cluster figures only when a term is selected; no extra live region; long labels not clipped | `R/results_explorer.R`, `R/workspace_selection.R`, `R/rr_visualize_tab.R`, `R/clus_visualize_tab.R`, `W:custom.css`, `T:test-results-explorer.R`, `T:test-compact-layout.R`, `E:results-explorer.spec.ts`, `E:ui-layout.spec.ts`, `E:compact-layout.spec.ts`, `rec` | AC-022, AC-023, AC-024 |

AC-025 (preservation) and AC-026 (source and test hygiene) bind every milestone. The non-developer check (OD-7) is outside the milestones.

## Technical implementation plan

1. **Baseline first (D2, verification-claim-integrity §2.3).** M0 writes the goldens with `T:helper-ui-baseline.R` (figure values from the built plot objects as text with 17 significant digits; downloads as the original column names and full-precision values; the input revision/snapshot returned by the SPEC-WS-004 review functions for fixed inputs) and commits them, with the project saved at the baseline, before any file under `R/` or `inst/` changes. `T:test-ui-baseline.R` proves M0 reproduces the goldens from the untouched tree and is the guard that AC-008, AC-013, AC-021 and AC-025 compare later outputs against.
2. **Shell and routes.** The stepper and the context bar are rendered from existing Shiny/shinydashboard building blocks and the existing navigation adapter (`workspace_sidebar_menu`, `workspace_navigate`, `workspace_header_ui`/`workspace_header_server` in `R/workspace_navigation.R`; the new `R/workspace_shell.R`). Existing `tabName` route strings (`home_tab`, `enrich_tab`, `rr_visualize_tab`, `cluster_upload_tab`, `cluster_tab`, `clus_visualize_tab`, `update_tab`, `save_tab`) and the `a[href="#shiny-tab-<route>"]` anchors stay valid. Step-to-route mapping is a display adapter: Data is `update_tab` (renamed "Data"), and `cluster_upload_tab` stays a real tab item holding the enrichment-results importer as a Data-step sub-route, reached by a flat navigation item directly under Data and by a link on the Data page; the stepper marks Data active on either route. Its input ids (`cluster_upload-rr_files`) and behaviour are unchanged, so `input-review.spec.ts:98-100` (clicks the `cluster_upload_tab` anchor, asserts that tab is active), `workspace-entry.spec.ts` and `clustering-roundtrip.spec.ts` pass unchanged. The DEG uploader and the moved Results loader keep their namespaced ids (`enrich-deg_files`, `rr_visualize-rr_files`).
3. **Context and jobs.** The context bar reads the existing active-result state; switching the dataset there updates the state Results and Cluster defaults read. Missing metadata is not shown as individual "Not recorded" rows by default but stays explicit through one visible disclosure whose trigger reads "N not recorded"; the field rows keep the text "Not recorded" once per unrecorded field, so the counts asserted by `T:test-workspace-navigation.R` (`ws3_count(html, "Not recorded")` equal to 1, 3 and 3 at lines 415, 432, 453), `T:test-workspace-components.R:55` and `E:design-system.spec.ts:685` still hold (re-pointed at the context bar after M5, never lowered). The job tray renders the existing registry from `workspace_jobs_ui`/`workspace_jobs_server` (states, Retry/Stop offers via `workspace_jobs_retry_offered`, acknowledgement rules from SPEC-WS-006) without changing them; output ids `jobs-jobs_list`, `jobs-jobs_status`, `jobs-jobs_time`, `jobs-jobs_announce` and the `Analysis jobs` region label are kept inside the tray. "Dismiss" hides a row for the session only.
4. **Empty states.** Server-rendered only when the corresponding table or plot has no rows, replacing the static "No data to display" elements in `rr_vis_tab_ui` and adding the missing heatmap state.
5. **Copy.** Required replacements are verified by the banned-term list in AC-020 ("Commit input revision" -> "Use these settings"; "Preview - not committed" -> "Preview (settings not yet applied)"; "Stored rows" -> "Rows in file"; "P-value role" -> "P-value used for the cutoff"; "Source digest" -> "File fingerprint" under Advanced; "keytype" -> "Gene ID type"). Semantics of SPEC-WS-004 do not change.
6. **Tables and figures.** Display labels, rounding and em-dash are display formatting in `round_tbl`/`format_cells`; downloads and saved projects keep original names and full precision. Figure changes are legibility defaults only; no plotted value is recomputed; palettes come from base R (`grDevices::hcl.colors(n, "viridis")`; base-R packages need no DESCRIPTION entry) or ggplot2. The top-30 cluster default is a display window: the built object keeps every row (the existing `test-heatmap-legibility.R` row-retention guard) and "Show all" restores the existing 400-row windows.
7. **Upload validation.** Lives in the DEG upload observer in `R/enrich_tab.R` (`observeEvent(input$deg_files, ...)`), with an optional pure detection helper added to `R/file_handling.R`. "Recognized" means a column matches the existing `possible_gene_id` name pattern of `add_file_degdf`, without that function's first-column fallback. `add_file_degdf` is not modified (its exported fallback is pinned by `test-baseline-session-coverage.R`, which stays untouched and outside the lock list). When nothing is recognized the observer does not call the helper: it asks the user to pick a column (OD-4) and, on pick, passes the data with the chosen column renamed `GeneID`; on cancel nothing is added. Environment failures (for example a missing `org.*.eg.db` package, today summarized by `workspace_jobs_error_summary`) are classified non-retryable, show the complete remediation command as copyable text, and are never executed by the app.
8. **Enrich defaults.** The summary is generated from the effective settings the SPEC-WS-004 review (`review_resolve`, `review_snapshot_items`, `review_preview_card`) would apply. Species: recorded species, else the last session choice, else the existing default shown as a default (OD-5).
9. **Results master-detail.** Built on the 008 explorer; the term table is the master, the figure the detail via adapters that keep the existing namespaced figure input ids bound. Desktop side by side; narrow figure above table.
10. **Text encoding.** R sources and `W:workspace-ui.js` stay ASCII-only (non-ASCII glyphs as `\u` escapes); `workspace-ui.js` uses no `eval` and never writes user text through `innerHTML`.
11. **Recheck record.** `rec` has one section per milestone: measured before/after values (before values come from M0), commands and CI run ids, changed existing-test assertions with reasons, and gaps.

## GEARS requirements

- **REQ-001** The workspace shall present the analysis as five ordered steps (Data, Enrich, Results, Cluster, Save), each with a status derived from workspace contents and a next action, and shall let the user open any step directly without completing earlier steps.
- **REQ-002** While an analysis page (Data, Enrich, Results, Cluster) is shown, the workspace shall show exactly one context bar naming the active dataset with a switcher, its recorded metadata, one visible disclosure of metadata that was not recorded and a job badge, in place of the active-workspace card and the inline job log.
- **REQ-003** When a job is queued, running or finished, the workspace shall list it in a slide-over job tray with one row per job (textual status, type, inputs, time and the actions the job registry offers), with settings behind a disclosure; the tray shall not open by itself, and no page shall render an expanded inline job log.
- **REQ-004** When job state changes, exactly one polite live region shall announce the change.
- **REQ-005** When the Results step is opened with at least one result, the workspace shall show a master-detail view in which the term table and the figure share one linked selection and the plot type is chosen by one segmented control, with no separate Explorer tab and no more than two levels of tabs.
- **REQ-006** The workspace shall use one box style and one accent colour, and shall reserve the danger colour for destructive or error states and the success colour for success states.
- **REQ-007** When the Enrich step is opened, it shall lead with a plain-language summary of the effective settings with an Adjust control, show the input review in plain language with technical identifiers under Advanced, and keep the Run action and settings summary visible without scrolling.
- **REQ-008** When a table or figure has at least one row to show, no empty-state message shall be visible for it; when it has none, an empty state shall name the next available action.
- **REQ-009** When data are loaded or a result becomes active, the workspace shall confirm success with a next action and use the active dataset as the default selection on the Enrich, Results and Cluster steps; when clustering completes, it shall offer to open the cluster figures for that result.
- **REQ-010** When an uploaded gene list has no column recognized as gene identifiers, the workspace shall not add a dataset until the user picks the gene column, shall leave the gene lists unchanged if the user cancels, and shall report the detected columns; when an analysis fails for an environment reason, the workspace shall show the complete remediation command and shall not offer Retry.
- **REQ-011** The workspace shall show figures with sequential colour-blind-safe scales, colour and size legends, titles and axis labels that name the plotted variables, sorted bars, legible labels and a visible network figure whenever the result has terms, without changing plotted values.
- **REQ-012** The workspace shall show table columns with display labels, unknown values as an em-dash and p-values to three significant figures, while downloads and saved projects keep original column names and full-precision values.
- **REQ-013** The workspace shall give every focusable control a visible focus indicator, render disabled controls distinguishably with a stated reason, and show help, sidebar and footer text at a contrast ratio of at least 4.5:1.
- **REQ-014** When the user navigates on a narrow screen, the navigation menu shall close; notifications shall be opaque, error notifications shall clear on navigation and success notifications shall hide automatically.
- **REQ-015** The workspace shall use one name ("project") for saved analyses, offer one primary save action with the JSON session under Advanced, shall not show any panel or tab described as "not yet supported" or "currently not available" (the inert "Text input" tabs in `rr_vis_tab_ui`, `cluster_upload_tab_ui` and `clus_vis_tab_ui` and the whole "Load cluster result" panel in `clus_vis_tab_ui`, none of which has a server observer) or repository file paths in user-facing text, and shall keep the working enrichment-results importer (file upload in `cluster_upload_tab_ui`) with its route and behaviour.
- **REQ-016** The restructure shall not change stored data, numerical results, run records, the project format, job lifecycle semantics or route identifiers, and shall keep the behaviours listed under "Keep" in the UX review.
- **REQ-017** When a project or session file is refused, the workspace shall show a short plain-language message stating that nothing was loaded and what the user can do next, with the technical conversion steps in an expandable block, and the message shall clear on navigation.

## Binary acceptance scenarios

Browser scenarios run in both Playwright projects (`chromium-desktop`, `chromium-narrow`) with no `test.skip`/`test.fixme`; layout measurements set the viewport explicitly to 1440x900 (desktop) and 390x844 (narrow) without changing the shared `playwright.config.ts`. "Populated" means after "Load demo results" (and, where stated, a completed demo clustering job). Server logic is covered by testthat. "Baseline goldens" are the M0 files under `tests/fixtures/ui-baseline/`.

**AC-001 (F2, REQ-008)** Given the populated workspace, when each of Table, Bar, Dot, Network and Heatmap (enrichment) and the cluster figures are shown with at least one row, then no visible element contains "No data to display" or another empty-state text; given an empty workspace, each of those views (including the heatmap) shows one empty state naming a next action.

**AC-002 (F1, N1, M1 scope)** Given two finished jobs and none running, when each of Enrich, Results, Cluster, Cluster figures and Save loads at 390x844, then the job panel's rendered height is at most 64 px while collapsed, expanding it shows each job as one row with a textual status, run settings are inside a collapsed disclosure, and run ids are not rendered in the danger colour. From M5 the inline panel no longer exists; this scenario is superseded by AC-015, which asserts that no page renders an inline job log and that tray rows meet the same row, status and colour rules.

**AC-003 (F4, OD-8, REQ-013)** Given the empty workspace, when the header actions are disabled, then each visible disabled control (`:disabled` or `aria-disabled="true"`) has computed background colour and text colour both different from an enabled button's, `cursor: not-allowed` and computed opacity 1 (no opacity below 1, following the SPEC-WS-002 design-system opacity guard in `E:design-system.spec.ts`), shows no hover change, exposes its reason through `title` or `aria-describedby`, and the hint text appears once; given a result with three unrecorded metadata fields, then no "Not recorded" row is visible by default, one disclosure trigger is visible by default whose accessible name states "3 not recorded", opening it lists the three fields, and the existing assertions `ws3_count(html, "Not recorded")` (1, 3, 3 in `T:test-workspace-navigation.R`), `T:test-workspace-components.R` "Not recorded" and `E:design-system.spec.ts` first `dd` "Not recorded" pass without being lowered.

**AC-004 (F10, REQ-013)** Given keyboard navigation, when focus reaches each sidebar link (and, from M6, each stepper link), the Bookmark control (where present), a button and a text input, then the focused element's computed `outline-style` is not `none`, `outline-width` is at least 2 px, and the outline colour has a contrast ratio of at least 3:1 against the adjacent background (computed in the test from computed colours).

**AC-005 (F11, REQ-013)** Given every page, when help text (`.help-block`, `helpText` output), sidebar section headers and the footer are measured, then each has computed font size at least 13 px and a WCAG contrast ratio of at least 4.5:1 against its effective background.

**AC-006 (F10, REQ-004)** Given the populated workspace with a running job, when the DOM is inspected (Results explorer included, since 008 is merged), then exactly one app-authored element carries `aria-live` for job status, no app-authored element carries `role="log"`, and every other live node found is listed in the test with its origin (Shiny notification panel or a named third-party widget); an unlisted live node, including the 008 explorer selection region, fails the test.

**AC-007 (F12, F13, REQ-014)** Given the narrow project, when the menu is opened and a destination is chosen, then within 1 s the menu is not visible and the destination is active; given an error notification, when the user navigates to another step, then it is gone; given the success notification raised by opening a saved project (the existing "Project opened successfully!" notification), then it is gone within 6 s; every notification has computed background alpha 1 and, at 390x844, does not overlap the current page's primary action.

**AC-008 (F9, REQ-012)** Given the populated Results and Cluster tables, when they render, then none of the raw names `GeneID_header`, `num_genes`, `has_expr_data`, `from_deg`, `Representative_Term`, `n_terms`, `min_pvalue` is visible as a header, no row-name column is shown, unknown cells show an em-dash rather than "?", p-value cells show three significant figures, and the `p.adjust` column lies within the visible table width at 1440x900; testthat proves the display formatter keeps the underlying values and that the download handlers write the original names and full-precision values equal to `demo-downloads.json`.

**AC-009 (F5, N7, OD-4, REQ-010)** Given a two-line text file whose header is not a recognized gene-identifier column (the review's `this.is.not` case), when it is uploaded as a gene list, then the set of gene lists is unchanged and a message names the detected columns and row count; given the user picks a column in the prompt, then exactly one dataset is added with that column as its gene column and a confirmation names the column and row count; given the user cancels, then the gene lists and the Save summary are unchanged (the file is never listed as a valid DEG set); given a valid demo gene list, then a confirmation names the detected gene column and row count.

**AC-010 (N4, REQ-010)** Given an enrichment failure caused by a missing annotation package, when its job row and message render, then the full install command appears untruncated in a copyable code element, the message does not tell the user to use Retry, Retry is not offered, and testthat proves the failure classification and that `workspace_jobs_retry_offered` returns FALSE for environment failures and is unchanged for other failures.

**AC-011 (D, F8, REQ-006)** Given every page in the populated workspace, when box headers are measured, then all non-status box headers share one computed background colour, border and title font; every visible element whose computed background or border colour equals `--rs-danger` is a destructive action or an error state (named in the test by class or role), and every element using `--rs-success` is a success state.

**AC-012 (F16)** Given `custom.css`, when it is scanned, then it contains no `transition: all`; given Home in an empty workspace, then no empty bordered status strip is rendered; given emulated `prefers-reduced-motion: reduce`, then the menu and notification transitions (and the tray from M5) have computed duration at most 0.01 s.

**AC-013 (F7, OD-6, REQ-011)** Given the demo results and a demo clustering result, when testthat inspects the built figure objects, then the heatmaps (enrichment and cluster) use a sequential viridis-family scale and no red-to-green scale; the cluster heatmap shows the 30 most significant clusters by default with a "Show all" option and an "N of M shown" notice while the built object still contains every row and the 400-row windows of `test-heatmap-legibility.R` still pass; bars are ordered by the plotted value; dot plots have a size legend and a title and axis labels that name the plotted variables (no "-log10(Padj)" title over a Rich Score axis); network nodes have a colour legend and label font size at least 10 px; enrichment-heatmap labels longer than the truncation limit are truncated with the full label in hover text; the plotted numeric values equal `figure-values.json` (compared keyed by term, not by position), and bars stay ordered by the plotted value as already pinned by `test-baseline-result-figures.R`.

**AC-014 (B context bar, REQ-002, F3 part)** Given the populated workspace at 1440x900 and 390x844, when each of Enrich, Results and Cluster is shown, then exactly one context bar is present, its height is at most 56 px (desktop) and 64 px (narrow, collapsed), it names the active dataset, it shows no "Not recorded" chip, its "not recorded" disclosure trigger is visible, and the former active-workspace card is absent; the context bar is absent on Home and Save; and given active result `go1`, when "Cluster" is activated from the context bar, then the Cluster step opens with `go1` selected. (The Data page is checked in AC-019, after M6 creates it.)

**AC-015 (B job tray, REQ-003)** Given the populated workspace with one running and two finished jobs, when the job badge is activated, then a tray opens showing three rows with textual status, focus moves into the tray, Escape closes it and returns focus to the badge, and the tray had not opened by itself; no page renders an expanded inline job log; existing job-lifecycle scenarios (Stop/acknowledgement, Retry, timing) pass through the tray with no weakened assertion.

**AC-016 (layout, F12, M5 scope)** Given the populated workspace with the former active-workspace card and inline job log gone (M5), when Cluster loads, then the top of its form heading is within 200 px of the viewport top at 1440x900 and within 260 px at 390x844 (fixed values: the AdminLTE header plus the 56/64 px context bar plus page padding; before M5 the heading sat about 830 px down), and `document.documentElement.scrollWidth` does not exceed the viewport width at 390x844 on Enrich, Results and Cluster. The Cluster form itself is unchanged (Keep list, AC-025). The Enrich Run position is checked in AC-020 (M7) and the Results first table in AC-022 (M8); Data and Save are checked in AC-019.

**AC-017 (A stepper, REQ-001)** Given any workspace state, when the stepper renders, then it shows the five steps in order with a textual status each, every step can be opened by click and by keyboard regardless of status, and imported results open Results without Enrich; testthat proves the step-status function for empty, gene-lists-only, imported-results-only, enriched and clustered states; at 390x844 the stepper renders as one compact "Step N of 5" control.

**AC-018 (F3, REQ-009)** Given the populated workspace, when the dataset is switched in the context bar, then the default selection on Results and Cluster changes to it; given an empty workspace, when demo data are loaded, then a success notification with a next action appears; when Enrich opens, the gene-list selection defaults to the active dataset; when a clustering job completes, then a "View cluster figures" action opens Cluster figures with that result selected; and the enrichment heatmap result selector defaults to an existing result.

**AC-019 (F14, F15, REQ-015, OD-3)** Given the navigation, when it renders, then there are no collapsed navigation groups, no visible text "not yet supported" or "currently not available" on any of Home, Data (including the `cluster_upload_tab` importer), Enrich, Results, Cluster, Cluster figures and Save, the Results-page "Load enrichment result" box is gone from Results and present on Data, the inert "Text input" tabs are absent everywhere, no visible text containing `docs/` or `.md`, Bookmark is not in the primary navigation (a "Share link" control in the footer instead), Home says "Open project", the Data step is the `update_tab` route titled "Data" with the upload control for DEG sets, the enrichment-results importer and the project-open control, its upload control top is within 300 px of the viewport top at 1440x900 and 420 px at 390x844 with no horizontal overflow, the context bar is present on it, the Save step has one primary "Save project" action whose download name matches `^richstudio_project_.*\.zip$` and the JSON session save is inside an Advanced disclosure; the `cluster_upload_tab` anchor still opens a tab whose `tabName` is `cluster_upload_tab` containing the importer, and the stepper shows Data active there; the "Load cluster result" panel is absent from Cluster figures while `cluster_upload-rr_files` still accepts an enrichment-result file; and the project round-trip and clustering round-trip scenarios pass unchanged in behaviour.

**AC-020 (E, F6, N5, REQ-007)** Given the Enrich step in default state with demo gene lists, when it renders, then none of "Commit input revision", "Source digest", "Stored rows", "P-value role", "Preview - not committed", "keytype" is visible; the input review shows no raw bullet lists of digests or counts outside an Advanced or Details disclosure; a settings summary in plain language with an Adjust control is visible; the Run action and summary remain in the viewport while scrolling the full page at both viewports, and the Run and summary bar is top-sticky within the Enrich column, so its top is within 300 px of the viewport top at 1440x900 and within 420 px at 390x844 both when the page is first shown and at any scroll position; and the page's scroll height before expanding Adjust or Advanced is at most 1350 px at 1440x900 and 2110 px at 390x844.

**AC-021 (E semantics, F8, OD-5)** Given the same inputs, when "Use these settings" is applied, then the recorded input revision and query snapshot equal `input-revision.json` (testthat on the SPEC-WS-004 review functions); given gene lists with recorded species, then the species default equals the recorded species and the summary states it; given no recorded species and a species chosen earlier in the session, then the summary shows that choice; given neither, the summary marks the species as a default; and gene lists and enrichment results on Enrich appear in one table that drives the preview.

**AC-022 (C master-detail, N2, REQ-005)** Given the populated Results step, when it renders, then there is no tab named "Explorer" and no Table/Bar/Dot/Network/Heatmap tab set; there are at most two levels of tabs; the term table top is within 300 px of the viewport top at 1440x900 and 420 px at 390x844 with no loader box above it; a term table and a figure are side by side at 1440x900 and the figure is above the table at 390x844; the plot type is one segmented control whose options are reachable by keyboard; figure settings are collapsed by default.

**AC-023 (008 preserved through M8)** Given the 008 acceptance scenarios AC-001..004, when they run against the master-detail view, then all pass in both projects: sorting the table and selecting a term highlights the same namespace-qualified term and member genes in table and figure; not-tested and not-significant states have different textual cues; imported results without clusters can be plotted and exported with exact values.

**AC-024 (M8 detail, REQ-004)** Given a selected term, when its detail renders, then the visible labels are plain language (term name, term ID, member genes, values in other datasets) and "Result ID"/"Annotation namespace" appear only inside a Details disclosure; the Cluster figures page shows no linked-term paragraph until a term is selected; no y-axis tick label's bounding box extends outside the plot container; and AC-006 still passes.

**AC-025 (preservation, REQ-016)** Given each merged milestone, when hosted CI runs, then the existing testthat suite and the existing browser specs pass in both projects (project round-trip, job lifecycle, input review, workspace entry, design system, baseline, compact layout, heatmap legibility, clustering round-trip, scientific heatmaps); Home still offers its four Quick Start entry points and the example-data note; the Cluster form keeps its method choices, helper text and Reset; the invalid-project error text including its "changes nothing" statement is unchanged; route `tabName` strings are unchanged; the project saved at the baseline (`tests/fixtures/ui-baseline/project-baseline.zip`) opens at the milestone with data and results equal to the baseline, and a project saved at the milestone and reopened at the same milestone round-trips identically.

**AC-026 (hygiene)** Given the leaf's changed files, when checked, then every file under `R/` and `inst/application/www/workspace-ui.js` is ASCII-only (testthat scan), the new browser specs contain no `test.skip`/`test.fixme`/`test.only`, every `pkg::` call added by this leaf names a package listed in `DESCRIPTION` Imports or Suggests or a base-R package (`base`, `stats`, `utils`, `graphics`, `grDevices`, `methods`) (testthat scan; no DESCRIPTION change), the set of files changed by the leaf is a subset of the `dispatch.json` lock list, and each changed existing-test assertion is listed with its reason in `rec`.

**AC-027 (baseline, M0)** Given the tree before any M1 change, when M0 is committed, then `T:test-ui-baseline.R` passes by reproducing every golden from the untouched `R/` and `inst/` sources, `git log` shows the M0 commit(s) as ancestors of the first M1 commit with no `R/` or `inst/` file in them, and `rec` holds the N6 reproduction steps and the "before" browser measurements.

**AC-028 (N3, REQ-017)** Given an `.rds` session file is chosen on Save/Load, when it is refused, then the visible message is at most 3 sentences, says nothing was loaded, offers a next step that does not require running a script, the conversion command is inside an expandable block with a copy control, and the message is gone after navigating to another step.

**AC-029 (N6, REQ-011)** Given the demo enrichment results, when the Network view is opened at 1440x900 and 390x844, then the network figure is visible (rendered image bounding box at least 200x200 px, not covered by any empty-state element) within 10 s, and testthat proves the built network has at least one node for the demo results; the reproduction recorded in M0 names the root cause (empty-state overlay, plot render failure or other) and the fix is verified against that reproduction.

All requirements must be exercised by the listed scenarios plus scoped tests; verification receipts identify the specific REQ/AC IDs. Disabled controls are valid intermediate/rollback containment only; they do not close the desired capability or justify full-program completion.

## Scoped verification and gate evidence

- Per milestone: scoped testthat files for the changed modules, the new and changed browser specs in both projects, then hosted CI (`.github/workflows/workspace-quality.yml`) on the integration branch for the full suite; record run ids, pass/fail/skip totals and bounded outputs in the recheck record.
- Compatibility target is shiny 1.14 as used in CI and on the live host; a local run on another shiny version is not acceptance evidence.
- Layout, contrast, focus and live-region facts are measured in the browser from computed styles and bounding boxes, not inferred from CSS text.
- Figure acceptance compares built plot objects with the M0 goldens; display changes must not change data values.
- Lock-list consistency is script-checked at each milestone (`jq` over `dispatch.json` against the milestone file lists).
- Follow the canonical primary-repository quality/harness/LSP policies; record exact snapshot digests in CI. Do not duplicate their numerical thresholds here.
- Report commands, verbatim bounded outputs, commit/runtime baseline, gaps and residual risks. Full-suite phase gates run in clean CI; local checks are scoped to affected behavior.
- **Gap (OD-7, non-blocking):** automated checks do not show that non-developers can finish the connected task. After M8 the owner runs one observed session with a user unfamiliar with richStudio (upload or demo -> enrich -> results -> cluster -> save -> reopen); the result is recorded and carried to umbrella AC-012. Until then the usability outcome is a recorded gap that does not block acceptance of this leaf.

## Requirement-to-acceptance traceability

| Requirement | Required scenarios |
|---|---|
| REQ-001 | AC-017 |
| REQ-002 | AC-003, AC-014, AC-019 |
| REQ-003 | AC-002, AC-015 |
| REQ-004 | AC-006, AC-024 |
| REQ-005 | AC-022, AC-023 |
| REQ-006 | AC-011, AC-012 |
| REQ-007 | AC-020, AC-021 |
| REQ-008 | AC-001 |
| REQ-009 | AC-018 |
| REQ-010 | AC-009, AC-010 |
| REQ-011 | AC-013, AC-029 |
| REQ-012 | AC-008 |
| REQ-013 | AC-003, AC-004, AC-005 |
| REQ-014 | AC-007, AC-016 |
| REQ-015 | AC-019 |
| REQ-016 | AC-021, AC-023, AC-025, AC-026, AC-027 |
| REQ-017 | AC-028 |

| Finding / proposal | Milestone | Scenarios |
|---|---|---|
| F1, N1 | M1, M5 | AC-002, AC-015 |
| F2 | M1 | AC-001 |
| F3 | M5, M6 | AC-014, AC-018 |
| F4 | M1, M5 | AC-003, AC-014 |
| F5, N7 | M2 | AC-009 |
| N4 | M2 | AC-010 |
| N3 | M2 | AC-028 |
| F6 | M7 | AC-020, AC-021 |
| F7 | M4 | AC-013 |
| N6 | M0, M4 | AC-027, AC-029 |
| F8 | M3, M7 | AC-011, AC-021 |
| F9 | M2 | AC-008 |
| F10 | M1 | AC-004, AC-006 |
| F11 | M1 | AC-005 |
| F12 | M1, M5 | AC-007, AC-016 |
| F13 | M1 | AC-007 |
| F14 | M6 | AC-019 |
| F15 (Low) | M2, M6 | AC-019, AC-020 |
| F16 (Low) | M3 | AC-012 |
| N2 | M8 | AC-022 |
| N5 | M7 | AC-020 |
| A / B / C / D / E | M6 / M5 / M8 / M3 / M7 | AC-017 to AC-019 / AC-014, AC-015 / AC-022 to AC-024 / AC-011 / AC-020, AC-021 |

No new package dependency is planned. If implementation finds one necessary (for example a direct `viridisLite::` call), it is a dependency decision requiring a registry revision before use, not an implementer choice.

## Security and trust boundary

Dataset names, term labels, file names and error text are rendered as text in the context bar, tray, stepper and notifications, never as HTML. The remediation command is displayed and copied as text and never executed by the app. `workspace-ui.js` handles only display state (menu, tray, notification dismissal), uses no `eval` and never inserts user-provided text through `innerHTML`. No new input path, file format or server endpoint is added; the column-pick prompt reuses the existing upload path.

## Rollout and rollback

Each milestone merges separately and reverts separately; none changes stored data, the project format or route identifiers, so reverting a milestone needs no data migration and projects saved before, during and after open in every state. Old figure modules stay reachable through adapters until M8 replaces the tab set; reverting M8 restores the tab set from the 008 state. No interim production deploy (OD-2); production deployment remains the separate user-executed protocol.

## Exclusions

### Out of Scope — Product scope

- New analysis features, statistical or engine changes, new defaults for thresholds, background or correction semantics.
- Automatic species or identifier-type inference.
- Figure export, figure provenance and consistent figure controls (SPEC-WS-009); clustering chooser and run comparison (SPEC-WS-010); release-level accessibility audit and usability study (SPEC-WS-011); legacy session bridge (SPEC-WS-012).

### Out of Scope — Technology and format

- Migrating away from shinydashboard, a new UI framework, dark mode, internationalization or new package dependencies.
- Any change to the project file format, run records, job lifecycle rules or route identifiers.
- Removing the enrichment-results importer (`cluster_upload_tab_ui`) or changing its input ids.

## HISTORY

- 2026-11-03: Planning-only draft from the hands-on UX review of integration tree 081ef06 (F1-F16, proposals A-E) and code reading of the unmerged SPEC-WS-008 branch; scheduled before SPEC-WS-009/010 by owner decision.
- 2026-11-05 (v0.3.6): M6 row adds lead-approved, mechanical test files with no assertion weakened: `ui-accessibility.spec.ts`, `scientific-heatmaps.spec.ts`, `heatmap-legibility.spec.ts`, `clustering-roundtrip.spec.ts` (navigation-only steps before unchanged clicks on moved ids), `landing-ui.spec.ts` (collapsible-groups test replaced by the flat-navigation test AC-019 requires), `test-baseline-session-coverage.R` (heading assertion becomes "Save project" under REQ-015) and `design-system.spec.ts` (custom.css digest re-pin only, twice). Record of changes: `docs/quality/ux-review-013-recheck.md` M6 section.
- 2026-11-05 (v0.3.5): M5 row amended to record two files touched with lead approval: `ui-flows.spec.ts` (AC-002 inline-panel test replaced by AC-015 tray assertions; AC-010 test opens the tray via the job badge; tray single-status and Dismiss steps added) and `design-system.spec.ts` (frozen custom.css sha256 re-pin only; pre-marker md5 unchanged). M5 implemented "Dismiss" for finished own-run rows only (imported and superseded rows carry no buttons, per existing SPEC-WS-006 assertions R13e/R28), and the narrow badge uses the short form "N running, M queued" with a full aria-label.
- 2026-11-04 (v0.3.4): M3 file list includes `test-workspace-components.R` (re-pin of the pre-marker CSS digest after removing `transition: all`); re-pin rule for SPEC-WS-002 digests added.
- 2026-11-04 (v0.3.3): M2 file list and lock list extended to the implemented scope (Cluster and Results tables for AC-008, custom.css digest re-pin, label assertions in test-compact-layout.R and test-baseline-ui-workflows.R).
- 2026-11-04 (v0.3.2): AC-003 disabled state restated without opacity (explicit colour tokens, opacity 1) to follow the SPEC-WS-002 opacity guard.
- 2026-11-04 (v0.3.1): iter-3 fixes: Cluster layout clause rebound to the form heading with fixed thresholds; context-bar default-selection clause moved to AC-018 (M6); assertion removal allowed for controls the SPEC removes; Enrich sticky edge stated.
- 2026-11-04 (v0.3.0): iter-2 fixes: AC-016 split and rebound to the milestones that move each page (Enrich to M7, Results to M8); base-R packages allowed; inert Text-input tabs removed and AC-019 sweep scoped; `cluster_upload_tab` kept as a real Data sub-route; upload validation placed in the upload observer, `add_file_degdf` untouched; AC-004, AC-002, AC-013 clarified.
- 2026-11-04: Revised after plan-audit iteration 1 (FAIL 0.76, defects D1-D14) and re-based on the reconciled tree (UX re-review N1-N7): owner decisions OD-1..OD-8 recorded; M0 baseline capture added; Data step (OD-3) moved into M6 so M5 needs nothing later; 008 live region handled in M1; REQ-017, AC-027..029 added; lock list extended with the reconciled-line guard tests and the baseline fixtures; `tier: L` set.
