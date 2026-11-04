---
id: "SPEC-WS-013"
title: "Workspace UI/UX restructure"
version: "0.1.0"
status: draft
created: "2026-11-03"
updated: "2026-11-03"
author: "workspace planning team"
priority: P1
phase: "v0.1.7 target"
module: "R/"
lifecycle: spec-anchored
tags: "workspace, usability, accessibility, layout"
---

# SPEC-WS-013 — Workspace UI/UX restructure

Planning-only draft. This existing-style leaf document is the self-contained implementation contract; no implementation/test completion is claimed. Companion umbrella: [SPEC-WORKSPACE-001](SPEC-WORKSPACE-001/plan.md). Problem statement and evidence input: [UX review 2026-11-03](../quality/ux-review-2026-11-03.md) (findings F1-F16, proposals A-E, wireframe). Registration and dependency delta: [amendment 013](SPEC-WORKSPACE-001/amendments/013-registration.md).

## Problem and observable outcome

The engine grew (input review, job registry, projects) while the interface grew by stacking panels onto the original dashboard. Every analysis page opens with a tall active-workspace card and an unstyled job log, so real work starts 450-830 px down; several views say "No data to display" above populated output; copy mixes biology with developer internals; disabled buttons look enabled; focus is invisible on navigation links; help text is below contrast minimums.

After this leaf, a user sees one task-ordered stepper (Data, Enrich, Results, Cluster, Save), one compact context bar for the active dataset with a job badge that opens a slide-over job tray, a Results page that is a master-detail view (term table plus linked figure), an Enrich page that leads with plain-language defaults and keeps the technical review under Advanced, one box style with colour reserved for status, and the High/Medium findings of the review closed with measured evidence. Stored data, numerical results, run records, the project format and route identifiers are unchanged.

Owner decision (2026-11-03): this restructure is scheduled before SPEC-WS-009 and SPEC-WS-010, which build on the new layout.

## Relation to SPEC-WS-008

**Recommendation (adopted for planning; owner may override, see OD-1):** SPEC-WS-008 merges first, after its own independent review against its unchanged REQ-001..005 / AC-001..004, and this leaf's milestone M8 reshapes the 008 explorer into the Results master-detail view. There is no sixth "Explorer" tab after M8: the master-detail replaces the Table/Bar/Dot/Network/Heatmap/Explorer tab set. 008's server logic (stable identity keys, linked selection, evidence-aware missing states, exact-value export) is kept, and its acceptance scenarios must still pass after M8.

Rationale:

1. 008 is implemented on the same base (`081ef06`, branch WT-workspace-results-explorer, commits `a548351`, `fb9e5be`, 7 files +1527/-6 including 475 lines of testthat and 237 lines of browser scenarios). Its scientifically risky part is identity and missingness, not layout; superseding it would discard that work and reopen those risks.
2. This leaf's change to the explorer is presentational (where and how it is shown), not what it computes, so it fits a reshape on top of a reviewed 008.
3. The umbrella dependency chain 008 -> 009/010 stays intact; only 013 is inserted between them.
4. Milestones M1-M7 do not touch the explorer files, so the 008 review latency delays only lock-serialized edits of `R/rr_visualize_tab.R`, `R/clus_visualize_tab.R` and `inst/application/app.R`.

Cost accepted by the recommendation: between the 008 merge and M8 the integration tree shows a sixth "Explorer" tab (selected by default) and the review's explorer concerns (1)-(5). Whether that interim state may be deployed is OD-2.

**Alternative (recorded as open owner decision OD-1):** this leaf supersedes the 008 UI. 008 is re-scoped to its server logic and identity tests (`R/workspace_selection.R`, the non-UI functions of `R/results_explorer.R`, `tests/testthat/test-results-explorer.R`); its `resultsExplorerUI`, the Explorer tab and its browser scenarios are never merged, and M8 builds the master-detail directly and re-proves 008 AC-001..004 in the browser. Effect: no interim sixth tab, but the 008 branch must be re-cut, 008 becomes `partially_superseded_by` this leaf, and 008 browser evidence moves into M8.

## Dependencies and ownership

- Logical prerequisites: SPEC-WS-003, SPEC-WS-004, SPEC-WS-006, SPEC-WS-007, SPEC-WS-008 (under the OD-1 recommendation; under the alternative, the re-scoped 008).
- Downstream: SPEC-WS-009 and SPEC-WS-010 gain SPEC-WS-013 as a logical prerequisite; SPEC-WS-011 gains it in its prerequisite list (see amendment 013).
- One disposable implementer owns this entire leaf in its own fresh worktree; each milestone is independently reviewed, merged and CI-verified before the next milestone's integration.
- Shared targets are exclusive locks, even for nonoverlapping line edits; derive conflicts from the umbrella dispatch.json. No metadata/namespace edits outside this list without registry revision. No `DESCRIPTION`/`NAMESPACE` change is planned.
- Existing test files listed below may change only where a changed id, label or interaction requires it; no assertion is removed or weakened, and every changed assertion is listed with its reason in the recheck record.
- Upstream richR work is separately owned and integrated through an official release, never edited by this consumer leaf.

### Existing targets

- `inst/application/app.R`
- `inst/application/www/custom.css`
- `R/workspace_navigation.R`
- `R/workspace_components.R`
- `R/workspace_jobs.R`
- `R/home_tab.R`
- `R/enrich_tab.R`
- `R/input_review.R`
- `R/file_handling.R`
- `R/round_table.R`
- `R/update_tab.R`
- `R/save_tab.R`
- `R/cluster_tab.R`
- `R/cluster_upload_tab.R`
- `R/rr_visualize_tab.R`
- `R/clus_visualize_tab.R`
- `R/rr_bar.R`
- `R/rr_dot.R`
- `R/rr_network.R`
- `R/rr_hmap.R`
- `R/cluster_hmap.R`
- `tests/testthat/test-workspace-navigation.R`
- `tests/testthat/test-workspace-components.R`
- `tests/testthat/test-workspace-jobs.R`
- `tests/testthat/test-input-review.R`
- `tests/e2e/workspace-entry.spec.ts`
- `tests/e2e/job-lifecycle.spec.ts`
- `tests/e2e/input-review.spec.ts`
- `tests/e2e/design-system.spec.ts`
- `tests/e2e/project-roundtrip.spec.ts`

### Prerequisite-created targets

- `R/results_explorer.R` (created by SPEC-WS-008)
- `R/workspace_selection.R` (created by SPEC-WS-008)
- `tests/testthat/test-results-explorer.R` (created by SPEC-WS-008)
- `tests/e2e/results-explorer.spec.ts` (created by SPEC-WS-008)

### New targets

- `R/workspace_shell.R`
- `inst/application/www/workspace-ui.js`
- `tests/testthat/test-workspace-shell.R`
- `tests/testthat/test-ui-copy-and-figures.R`
- `tests/e2e/ui-layout.spec.ts`
- `tests/e2e/ui-accessibility.spec.ts`
- `tests/e2e/ui-flows.spec.ts`
- `docs/quality/ux-review-013-recheck.md`

## Milestones

Ordered smallest-risk first. Each milestone is one mergeable unit: its own commits, scoped local checks, hosted CI on the integration branch, independent review, then merge. A later milestone may refine what an earlier one introduced but must keep its acceptance scenarios passing. Priority labels only; no time estimates.

| Milestone | Scope (findings / proposals) | Target files | Acceptance |
|---|---|---|---|
| M1 Presentation quick wins (High) | F2 server-driven empty states incl. heatmap; F1 job panel styling of existing markup (compact rows, settings collapsed, collapsed when idle); F4 real disabled style and missing metadata collapsed into one "not recorded" disclosure; F10 focus-visible outlines and solid input focus ring, one job-status live region; F11 help/sidebar/footer text contrast; F13 solid toasts, errors cleared on navigation, success auto-hide; F12 narrow menu closes after navigation | `R/rr_visualize_tab.R`, `R/clus_visualize_tab.R`, `R/workspace_components.R`, `R/workspace_navigation.R`, `R/workspace_jobs.R`, `inst/application/www/custom.css`, `inst/application/www/workspace-ui.js`, `inst/application/app.R`, `tests/testthat/test-workspace-components.R`, `tests/testthat/test-workspace-navigation.R`, `tests/e2e/ui-accessibility.spec.ts`, `tests/e2e/ui-flows.spec.ts`, `docs/quality/ux-review-013-recheck.md` | AC-001, AC-002, AC-003, AC-004, AC-005, AC-006, AC-007 |
| M2 Copy and validation quick wins (High) | F9 table display labels, em-dash for unknown, 3 significant figures, no rownames, column widths; F5 gene-column validation at upload with a report of what was detected, full install command in a copyable block, Retry hidden for environment failures; F15 question-style labels, keytype wording, slider minimum | `R/round_table.R`, `R/rr_visualize_tab.R`, `R/clus_visualize_tab.R`, `R/update_tab.R`, `R/file_handling.R`, `R/enrich_tab.R`, `R/input_review.R`, `R/workspace_jobs.R`, `tests/testthat/test-ui-copy-and-figures.R`, `tests/testthat/test-workspace-jobs.R`, `tests/testthat/test-input-review.R`, `tests/e2e/ui-flows.spec.ts`, `tests/e2e/input-review.spec.ts`, `docs/quality/ux-review-013-recheck.md` | AC-008, AC-009, AC-010 |
| M3 One visual system (Medium) | D one box style, one accent, semantic status colours from existing `--rs-*` tokens; F8 box title/header consistency; F16 no `transition: all`, empty Home status strip removed, submenu icon alignment | `inst/application/www/custom.css`, `R/workspace_components.R`, `R/home_tab.R`, `R/workspace_navigation.R`, `R/enrich_tab.R`, `R/update_tab.R`, `R/save_tab.R`, `R/cluster_tab.R`, `R/cluster_upload_tab.R`, `R/rr_visualize_tab.R`, `R/clus_visualize_tab.R`, `tests/e2e/design-system.spec.ts`, `tests/e2e/ui-layout.spec.ts`, `docs/quality/ux-review-013-recheck.md` | AC-011, AC-012 |
| M4 Figure legibility (High) | F7 sequential colour-blind-safe heatmap scale, top-30 cluster default with show-all, row-height scaling, truncated labels with full hover text, sorted bars, colour and size legends, truthful titles/axis labels, legible network labels with legend | `R/rr_bar.R`, `R/rr_dot.R`, `R/rr_network.R`, `R/rr_hmap.R`, `R/cluster_hmap.R`, `R/rr_visualize_tab.R`, `R/clus_visualize_tab.R`, `tests/testthat/test-ui-copy-and-figures.R`, `docs/quality/ux-review-013-recheck.md` | AC-013 |
| M5 Context bar and job tray (proposal B) | Single context bar (dataset switcher, recorded metadata chips, job badge) on analysis pages replacing the active-workspace card; slide-over job tray replacing the inline job log (completes F1, F4; F12 collapse on narrow); context-bar actions pass the active result (F3 part) | `R/workspace_shell.R`, `R/workspace_navigation.R`, `R/workspace_components.R`, `R/workspace_jobs.R`, `inst/application/app.R`, `inst/application/www/custom.css`, `inst/application/www/workspace-ui.js`, `tests/testthat/test-workspace-shell.R`, `tests/testthat/test-workspace-navigation.R`, `tests/testthat/test-workspace-jobs.R`, `tests/e2e/job-lifecycle.spec.ts`, `tests/e2e/workspace-entry.spec.ts`, `tests/e2e/ui-layout.spec.ts`, `tests/e2e/ui-accessibility.spec.ts`, `docs/quality/ux-review-013-recheck.md` | AC-014, AC-015, AC-016 |
| M6 Task stepper and information architecture (proposal A) | Five-step stepper with per-step status and next action, never gating; flat task-ordered navigation (F14); dead cluster-upload sub-tab removed; one primary "Save project" with JSON session under Advanced and one name everywhere; Bookmark out of primary navigation (F15); cross-step handoffs: success state with next action after loading data, active dataset as default selection, "View cluster figures" after clustering, heatmap selector defaults (F3) | `R/workspace_shell.R`, `R/workspace_navigation.R`, `inst/application/app.R`, `R/home_tab.R`, `R/save_tab.R`, `R/update_tab.R`, `R/enrich_tab.R`, `R/cluster_tab.R`, `R/rr_visualize_tab.R`, `R/clus_visualize_tab.R`, `inst/application/www/custom.css`, `tests/testthat/test-workspace-shell.R`, `tests/testthat/test-workspace-navigation.R`, `tests/e2e/workspace-entry.spec.ts`, `tests/e2e/project-roundtrip.spec.ts`, `tests/e2e/ui-flows.spec.ts`, `tests/e2e/ui-layout.spec.ts`, `docs/quality/ux-review-013-recheck.md` | AC-017, AC-018, AC-019 |
| M7 Enrich progressive disclosure (proposal E) | Single-column Enrich in three parts (Gene lists, Settings, Review and run) with plain-language defaults summary, Adjust, sticky Run and summary; the 004 review card under Advanced; developer terms replaced; species default from recorded metadata or session choice (F6); one gene-list table driving the preview instead of two stacked boxes (F8) | `R/enrich_tab.R`, `R/input_review.R`, `inst/application/www/custom.css`, `tests/testthat/test-input-review.R`, `tests/e2e/input-review.spec.ts`, `tests/e2e/ui-layout.spec.ts`, `tests/e2e/ui-flows.spec.ts`, `docs/quality/ux-review-013-recheck.md` | AC-020, AC-021 |
| M8 Results master-detail (proposal C, reshapes 008) | Term table (master) with linked figure (detail), plot type as a segmented control, figure settings collapsed above the figure, selected-term detail in plain language with technical identifiers under Details, cross-dataset values from 008, "Cluster these results"; no Explorer tab; linked-term panel on Cluster figures only when a term is selected; no extra live region; long labels not clipped | `R/results_explorer.R`, `R/workspace_selection.R`, `R/rr_visualize_tab.R`, `R/clus_visualize_tab.R`, `inst/application/www/custom.css`, `tests/testthat/test-results-explorer.R`, `tests/e2e/results-explorer.spec.ts`, `tests/e2e/ui-layout.spec.ts`, `docs/quality/ux-review-013-recheck.md` | AC-022, AC-023, AC-024 |

AC-025 (preservation) and AC-026 (source and test hygiene) bind every milestone.

## Technical implementation plan

1. **Shell and routes.** The stepper and the context bar are rendered from existing Shiny/shinydashboard building blocks and the existing navigation adapter. Existing `tabName` route strings (`home_tab`, `enrich_tab`, `rr_visualize_tab`, `cluster_upload_tab`, `cluster_tab`, `clus_visualize_tab`, `update_tab`, `save_tab`) and the `a[href="#shiny-tab-<route>"]` anchors stay valid, so bookmarks and the existing browser helpers keep working. Step-to-route mapping is a display adapter; which route hosts the Data step is OD-3.
2. **Context and jobs.** The context bar reads the existing active-result state; switching the dataset there updates the same state that Results and Cluster defaults read. Recorded metadata appears as chips; missing metadata is not shown as individual "Not recorded" rows but is still reported explicitly through one compact disclosure, which keeps umbrella REQ-002 and SPEC-WS-003 REQ-003 satisfied. The job tray renders the existing job registry (states, Retry/Stop offers, acknowledgement rules from SPEC-WS-006) without changing them; existing output ids (`jobs-jobs_list`, `jobs-jobs_status`, `jobs-jobs_time`, `jobs-jobs_announce`) and the `Analysis jobs` region label are kept inside the tray. "Dismiss" hides a row for the session only; it never deletes a run record or changes what a saved project contains.
3. **Empty states.** Empty-state elements are rendered by the server only when the corresponding table or plot has no rows, replacing the static always-present elements (including the missing heatmap empty state).
4. **Copy.** Developer vocabulary leaves default views. Required replacements are verified by the banned-term list in AC-020; suggested wording: "Commit input revision" -> "Use these settings"; "Preview - not committed" -> "Preview (settings not yet applied)"; "Stored rows" -> "Rows in file"; "P-value role" -> "P-value used for the cutoff"; "Source digest" -> shown only under Advanced as "File fingerprint"; "keytype" -> "Gene ID type". Wording changes do not change the SPEC-WS-004 semantics: "Use these settings" applies exactly what "Commit input revision" applied.
5. **Tables.** Display labels, rounding and em-dash are display formatting only; downloads and saved projects keep the original column names and full-precision values.
6. **Figures.** Legibility defaults only: palette, label truncation with hover, sort order, legends, titles that name the plotted variables, row-height scaling and the top-30 cluster default with show-all (OD-6). Palettes come from base R or packages already in `DESCRIPTION` (for example `grDevices::hcl.colors(n, "viridis")` or the ggplot2 viridis scales); no plotted value is recomputed. Figure controls, export and provenance stay with SPEC-WS-009.
7. **Upload validation.** A gene list is accepted silently only when a column is recognized as gene identifiers by the existing recognition rules; otherwise the upload does not add a dataset and either asks the user to choose the gene column or rejects with a report of the detected columns and row count (OD-4 selects which; never silent acceptance). Environment failures (for example a missing `org.*.eg.db` annotation package) are classified as non-retryable, show the complete remediation command as copyable text, and are never executed by the app.
8. **Enrich defaults.** The settings summary is generated from the effective settings the SPEC-WS-004 review would apply, never hard-coded. Species defaults to the species recorded for the selected gene lists, else the last species chosen in this session, else the existing default shown explicitly as a default in the summary. Inference of species from identifier patterns is not part of this leaf (OD-5).
9. **Results master-detail.** Built on the 008 explorer (OD-1 recommendation): the term table is the master; the figure is the detail and uses the existing figure modules through adapters, keeping their namespaced input ids bound so SPEC-WS-009 and saved display settings keep working. Desktop: table and figure side by side; narrow: figure above table.
10. **Text encoding.** R sources stay ASCII-only; non-ASCII glyphs (check mark, caret, middle dot, em-dash) are written as `\u` escapes in R strings or as CSS escapes. `inst/application/www/workspace-ui.js` is ASCII-only, uses no `eval`, and never writes user-provided text through `innerHTML`.
11. **Recheck record.** `docs/quality/ux-review-013-recheck.md` gets one section per milestone: measured before/after values for every acceptance measurement touched, the commands and CI run ids that produced them, the list of changed existing-test assertions with reasons, and gaps.

## GEARS requirements

- **REQ-001** The workspace shall present the analysis as five ordered steps (Data, Enrich, Results, Cluster, Save), each with a status derived from workspace contents and a next action, and shall let the user open any step directly without completing earlier steps.
- **REQ-002** While an analysis page (Data, Enrich, Results, Cluster) is shown, the workspace shall show exactly one context bar naming the active dataset with a switcher, its recorded metadata, one explicit disclosure of metadata that was not recorded and a job badge, in place of the active-workspace card and the inline job log.
- **REQ-003** When a job is queued, running or finished, its status shall be available in a slide-over job tray with one row per job (textual status, type, inputs, time and the actions the job registry offers), with settings behind a disclosure, and the tray shall not open by itself.
- **REQ-004** When job state changes, exactly one polite live region shall announce the change.
- **REQ-005** When the Results step is opened with at least one result, the workspace shall show a master-detail view in which the term table and the figure share one linked selection and the plot type is chosen by one segmented control, with no separate Explorer tab.
- **REQ-006** The workspace shall use one box style and one accent colour, and shall reserve the danger colour for destructive or error states and the success colour for success states.
- **REQ-007** When the Enrich step is opened, it shall lead with a plain-language summary of the effective settings with an Adjust control, keep the technical review under Advanced and keep the Run action and settings summary visible without scrolling.
- **REQ-008** When a table or figure has at least one row to show, no empty-state message shall be visible for it; when it has none, an empty state shall name the next available action.
- **REQ-009** When data are loaded or a result becomes active, the workspace shall confirm success with a next action and use the active dataset as the default selection on the Enrich, Results and Cluster steps; when clustering completes, it shall offer to open the cluster figures for that result.
- **REQ-010** When an uploaded gene list has no column recognized as gene identifiers, the workspace shall not add a dataset silently and shall report the detected columns; when an analysis fails for an environment reason, it shall show the complete remediation command and shall not offer Retry.
- **REQ-011** The workspace shall show figures with sequential colour-blind-safe scales, colour and size legends, titles and axis labels that name the plotted variables, sorted bars and legible labels, without changing plotted values.
- **REQ-012** The workspace shall show table columns with display labels, unknown values as an em-dash and p-values to three significant figures, while downloads and saved projects keep original column names and full-precision values.
- **REQ-013** The workspace shall give every focusable control a visible focus indicator, render disabled controls distinguishably with a stated reason, and show help, sidebar and footer text at a contrast ratio of at least 4.5:1.
- **REQ-014** When the user navigates on a narrow screen, the navigation menu shall close; notifications shall be opaque, error notifications shall clear on navigation and success notifications shall hide automatically.
- **REQ-015** The workspace shall use one name ("project") for saved analyses, offer one primary save action with the JSON session under Advanced, and shall not show unsupported-feature tabs or repository file paths in user-facing text.
- **REQ-016** The restructure shall not change stored data, numerical results, run records, the project format, job lifecycle semantics or route identifiers, and shall keep the behaviours listed under "Keep" in the UX review.

## Binary acceptance scenarios

Browser scenarios run in both Playwright projects (`chromium-desktop`, `chromium-narrow`) with no `test.skip`/`test.fixme`; layout measurements set the viewport explicitly to 1440x900 in the desktop project and 390x844 in the narrow project (the shared `playwright.config.ts` viewports are not changed by this leaf). "Populated" means after "Load demo results" (and, where stated, a completed demo clustering job). Server logic is covered by testthat.

**AC-001 (F2)** Given the populated workspace, when each of Table, Bar, Dot, Network and Heatmap (enrichment) and the cluster figures are shown with at least one row, then no visible element contains "No data to display" or another empty-state text; given an empty workspace, each of those views (including the heatmap) shows one empty state naming a next action.

**AC-002 (F1, M1 scope)** Given two finished jobs and none running, when any analysis page loads at 390x844, then the job panel's rendered height is at most 64 px until expanded, each job is one row with a textual status, run settings are inside a collapsed disclosure, and run ids are not rendered in the danger colour.

**AC-003 (F4)** Given the empty workspace, when the header actions are disabled, then each visible disabled control (`:disabled` or `aria-disabled="true"`) has computed opacity at most 0.6 and `cursor: not-allowed`, exposes its reason through `title` or `aria-describedby`, and the hint text appears once; given a result with three unrecorded metadata fields, no "Not recorded" row is visible by default and one disclosure lists the three fields when opened.

**AC-004 (F10, REQ-013)** Given keyboard navigation, when focus reaches each sidebar or stepper link, the Bookmark control, a button and a text input, then the focused element's computed `outline-style` is not `none`, `outline-width` is at least 2 px, and the outline colour has a contrast ratio of at least 3:1 against the adjacent background (computed in the test from computed colours).

**AC-005 (F11, REQ-013)** Given every page, when help text (`.help-block`, `helpText` output), sidebar section headers and the footer are measured, then each has computed font size at least 13 px and a WCAG contrast ratio of at least 4.5:1 against its effective background.

**AC-006 (F10, REQ-004)** Given the populated workspace with a running job, when the DOM is inspected, then exactly one app-authored element carries `aria-live` for job status, no app-authored element carries `role="log"`, and every other live node found is listed in the test with its origin (Shiny notification panel or a named third-party widget); an unlisted live node fails the test.

**AC-007 (F12, F13, REQ-014)** Given the narrow project, when the menu is opened and a destination is chosen, then within 1 s the menu is not visible and the destination is active; given an error notification, when the user navigates to another step, then it is gone; given a success notification, then it is gone within 6 s; every notification has computed background alpha 1 and, at 390x844, does not overlap the current page's primary action.

**AC-008 (F9, REQ-012)** Given the populated Results and Cluster tables, when they render, then none of the raw names `GeneID_header`, `num_genes`, `has_expr_data`, `from_deg`, `Representative_Term`, `n_terms`, `min_pvalue` is visible as a header, no row-name column is shown, unknown cells show an em-dash rather than "?", and p-value cells show three significant figures; testthat proves the display formatter keeps the underlying values and that the download handlers write the original names and full-precision values byte-identically to the pre-change output for the demo results.

**AC-009 (F5 validation, REQ-010)** Given a two-line text file whose header is not a recognized gene-identifier column (the review's `this.is.not` case), when it is uploaded as a gene list, then the set of gene lists is unchanged until the user acts, and a message names the detected columns and row count; given a valid demo gene list, then a confirmation names the detected gene column and row count.

**AC-010 (F5 environment failure, REQ-010)** Given an enrichment failure caused by a missing annotation package, when its job row and message render, then the full install command appears untruncated in a copyable code element, Retry is not offered, and testthat proves the failure classification and that the retry-offer rule returns FALSE for environment failures and is unchanged for other failures.

**AC-011 (D, F8, REQ-006)** Given every page in the populated workspace, when box headers are measured, then all non-status box headers share one computed background colour, border and title font; every visible element whose computed background or border colour equals `--rs-danger` is a destructive action or an error state (named in the test by class or role), and every element using `--rs-success` is a success state.

**AC-012 (F16)** Given `custom.css`, when it is scanned, then it contains no `transition: all`; given Home in an empty workspace, then no empty bordered status strip is rendered; given emulated `prefers-reduced-motion: reduce`, then tray, menu and notification transitions have computed duration at most 0.01 s.

**AC-013 (F7, REQ-011)** Given the demo results and a demo clustering result, when testthat inspects the built figure objects, then the heatmaps use a sequential viridis-family scale and no red-to-green scale; the cluster heatmap shows the 30 most significant clusters by default with an option for all, and its height grows with row count at no less than 18 px per row; bars are ordered by the plotted value; dot plots have a size legend and a title and axis labels that name the plotted variables (no "-log10(Padj)" title over a Rich Score axis); network nodes have a colour legend and label font size at least 10 px; labels longer than the truncation limit are truncated with the full label in hover text; and the plotted numeric values equal those built before the change for the same inputs.

**AC-014 (B context bar, REQ-002)** Given the populated workspace at 1440x900 and 390x844, when each analysis step is shown, then exactly one context bar is present, its height is at most 56 px (desktop) and 64 px (narrow, collapsed), it names the active dataset, it shows no "Not recorded" chip, the former active-workspace card is absent, and the context bar is absent on Home and Save; switching the dataset in the context bar changes the default selection on Results and Cluster.

**AC-015 (B job tray, REQ-003)** Given the populated workspace with one running and two finished jobs, when the job badge is activated, then a tray opens showing three rows with textual status, focus moves into the tray, Escape closes it and returns focus to the badge, and the tray had not opened by itself; existing job-lifecycle scenarios (Stop/acknowledgement, Retry, timing) pass through the tray with no weakened assertion.

**AC-016 (layout, F12)** Given the populated workspace, when each analysis step loads, then the top of its primary action or primary content (Data: upload control; Enrich: Run; Results: term table; Cluster: Run clustering) is within 300 px of the viewport top at 1440x900 and within 420 px at 390x844, and `document.documentElement.scrollWidth` does not exceed the viewport width at 390x844 on any step.

**AC-017 (A stepper, REQ-001)** Given any workspace state, when the stepper renders, then it shows the five steps in order with a textual status each, every step can be opened by click and by keyboard regardless of status, and imported results open Results without Enrich; testthat proves the step-status function for empty, gene-lists-only, imported-results-only, enriched and clustered states; at 390x844 the stepper renders as one compact "Step N of 5" control.

**AC-018 (F3, REQ-009)** Given an empty workspace, when demo data are loaded, then a success notification with a next action appears; when Enrich opens, the gene-list selection defaults to the active dataset; when "Cluster" is activated from the context bar with active result `go1`, then the Cluster step opens with `go1` selected; when a clustering job completes, then a "View cluster figures" action opens Cluster figures with that result selected; and the heatmap result selector defaults to an existing result.

**AC-019 (F14, F15, REQ-015)** Given the navigation, when it renders, then there are no collapsed navigation groups, no visible text "not yet supported", no visible text containing `docs/` or `.md`, Bookmark is not in the primary navigation, Home says "Open project", the Save step has one primary "Save project" action whose download name matches `^richstudio_project_.*\.zip$`, and the JSON session save is inside an Advanced disclosure; the project round-trip scenarios pass unchanged in behaviour.

**AC-020 (E, F6, REQ-007)** Given the Enrich step in default state with demo gene lists, when it renders, then none of "Commit input revision", "Source digest", "Stored rows", "P-value role", "Preview - not committed", "keytype" is visible; a settings summary in plain language with an Adjust control is visible; the Run action and summary remain in the viewport while scrolling the full page at both viewports; and the page's scroll height before expanding Adjust or Advanced is at most 1350 px at 1440x900 and 2110 px at 390x844.

**AC-021 (E semantics, F8)** Given the same inputs, when "Use these settings" is applied, then the recorded input revision and query snapshot are identical to what "Commit input revision" produced before the change (testthat on the SPEC-WS-004 review functions); given gene lists with recorded species, then the species default equals the recorded species and the summary states it; given no recorded species, the summary marks the species as a default; and gene lists and enrichment results on Enrich appear in one table that drives the preview.

**AC-022 (C master-detail, REQ-005)** Given the populated Results step, when it renders, then there is no tab named "Explorer" and no Table/Bar/Dot/Network/Heatmap tab set; a term table and a figure are side by side at 1440x900 and the figure is above the table at 390x844; the plot type is one segmented control whose options are reachable by keyboard; figure settings are collapsed by default.

**AC-023 (008 preserved through M8)** Given the 008 acceptance scenarios AC-001..004, when they run against the master-detail view, then all pass in both projects: sorting the table and selecting a term highlights the same namespace-qualified term and member genes in table and figure; not-tested and not-significant states have different textual cues; imported results without clusters can be plotted and exported with exact values.

**AC-024 (M8 detail, REQ-004)** Given a selected term, when its detail renders, then the visible labels are plain language (term name, term ID, member genes, values in other datasets) and "Result ID"/"Annotation namespace" appear only inside a Details disclosure; the Cluster figures page shows no linked-term paragraph until a term is selected; no y-axis tick label's bounding box extends outside the plot container; and AC-006 still passes.

**AC-025 (preservation, REQ-016)** Given each merged milestone, when hosted CI runs, then the existing testthat suite and the existing browser specs pass in both projects (project round-trip, job lifecycle, input review, workspace entry, design system, baseline); Home still offers its four Quick Start entry points and the example-data note; the Cluster form keeps its method choices, helper text and Reset; the invalid-project error text including its "changes nothing" statement is unchanged; route `tabName` strings are unchanged; and a project saved at any milestone opens at every other milestone with identical data and results.

**AC-026 (hygiene)** Given the leaf's changed files, when checked, then every file under `R/` and `inst/application/www/workspace-ui.js` is ASCII-only (testthat scan), the new browser specs contain no `test.skip`/`test.fixme`/`test.only`, every `pkg::` call added by this leaf names a package listed in `DESCRIPTION` Imports or Suggests (testthat scan), and each changed existing-test assertion is listed with its reason in `docs/quality/ux-review-013-recheck.md`.

All requirements must be exercised by the listed scenarios plus scoped tests; verification receipts identify the specific REQ/AC IDs. Disabled controls are valid intermediate/rollback containment only; they do not close the desired capability or justify full-program completion. Required feature criteria remain unresolved until demonstrated or explicitly re-scoped by the user.

## Scoped verification and gate evidence

- Per milestone: scoped testthat files for the changed modules, the new and changed browser specs in both projects, then hosted CI (`.github/workflows/workspace-quality.yml`) on the integration branch for the full suite; record run ids, pass/fail/skip totals and bounded outputs in the recheck record.
- Compatibility target is shiny 1.14 as used in CI and on the live host; a local run on another shiny version is not acceptance evidence.
- Layout, contrast, focus and live-region facts are measured in the browser from computed styles and bounding boxes, not inferred from CSS text.
- Figure acceptance compares built plot objects before and after for identical inputs; display changes must not change data values.
- Follow the canonical primary-repository quality/harness/LSP policies; record exact snapshot digests in CI. Do not duplicate their numerical thresholds here.
- Report commands, verbatim bounded outputs, commit/runtime baseline, gaps and residual risks. Full-suite phase gates run in clean CI; local checks are scoped to affected behavior.
- **Gap (owner item OD-7):** automated checks do not show that non-developers can finish the connected task. At least one observed session with a user unfamiliar with richStudio (upload or demo -> enrich -> results -> cluster -> save -> reopen) is required before this leaf is reported as accepted; until then the usability outcome is a recorded gap, and the observation feeds SPEC-WS-011 AC-012.

## Requirement-to-acceptance traceability

| Requirement | Required scenarios |
|---|---|
| REQ-001 | AC-017 |
| REQ-002 | AC-003, AC-014 |
| REQ-003 | AC-002, AC-015 |
| REQ-004 | AC-006, AC-024 |
| REQ-005 | AC-022, AC-023 |
| REQ-006 | AC-011, AC-012 |
| REQ-007 | AC-020, AC-021 |
| REQ-008 | AC-001 |
| REQ-009 | AC-018 |
| REQ-010 | AC-009, AC-010 |
| REQ-011 | AC-013 |
| REQ-012 | AC-008 |
| REQ-013 | AC-003, AC-004, AC-005 |
| REQ-014 | AC-007, AC-016 |
| REQ-015 | AC-019 |
| REQ-016 | AC-021, AC-023, AC-025, AC-026 |

| Finding / proposal | Milestone | Scenarios |
|---|---|---|
| F1 | M1, M5 | AC-002, AC-015 |
| F2 | M1 | AC-001 |
| F3 | M5, M6 | AC-014, AC-018 |
| F4 | M1, M5 | AC-003, AC-014 |
| F5 | M2 | AC-009, AC-010 |
| F6 | M7 | AC-020, AC-021 |
| F7 | M4 | AC-013 |
| F8 | M3, M7 | AC-011, AC-021 |
| F9 | M2 | AC-008 |
| F10 | M1 | AC-004, AC-006 |
| F11 | M1 | AC-005 |
| F12 | M1, M5 | AC-007, AC-016 |
| F13 | M1 | AC-007 |
| F14 | M6 | AC-019 |
| F15 (Low) | M2, M6 | AC-019, AC-020 |
| F16 (Low) | M3 | AC-012 |
| A / B / C / D / E | M6 / M5 / M8 / M3 / M7 | AC-017 / AC-014, AC-015 / AC-022..024 / AC-011 / AC-020, AC-021 |

## Open owner decisions

| ID | Decision | Planned default | Why open |
|---|---|---|---|
| OD-1 | Relation to SPEC-WS-008 | 008 merges first; M8 reshapes its UI | Alternative: 013 supersedes 008's UI and 008 is re-scoped to server logic (see "Relation to SPEC-WS-008") |
| OD-2 | Deploy interim states | Not decided | Whether integration states between milestones (notably 008 merged before M8, M5 before M6) may be deployed to the live host or held until M8 |
| OD-3 | Data step host route | Not decided | Extend the Manage Files route with upload, or move upload out of Enrich; route names are preserved either way |
| OD-4 | Unrecognized gene column | Ask the user to choose the column | Alternative: reject with the detected-columns report; both satisfy "never silent" |
| OD-5 | Species inference from identifiers | Excluded | Umbrella excludes silent metadata inference; a visible suggestion would need explicit authorization |
| OD-6 | Cluster heatmap default size | Top 30 clusters plus show-all | Display filter only; owner confirms the number |
| OD-7 | Non-developer check | Required before acceptance | Who observes, which user, which task set |
| OD-8 | Not-recorded display | One disclosure in the context bar | Removing not-recorded display entirely would require amending umbrella REQ-002 and SPEC-WS-003 REQ-003 |

No new package dependency is planned. If implementation finds one necessary (for example a direct `viridisLite::` call), it is a dependency decision requiring a registry revision before use, not an implementer choice.

## Security and trust boundary

Dataset names, term labels, file names and error text are rendered as text in the context bar, tray, stepper and notifications, never as HTML. The remediation command is displayed and copied as text and never executed by the app. `workspace-ui.js` handles only display state (menu, tray, notification dismissal), uses no `eval` and never inserts user-provided text through `innerHTML`. No new input path, file format or server endpoint is added.

## Rollout and rollback

Each milestone merges separately and reverts separately; none changes stored data, the project format or route identifiers, so reverting a milestone needs no data migration and projects saved before, during and after open in every state. Old figure modules stay reachable through adapters until M8 replaces the tab set; reverting M8 restores the tab set from the 008 state. Production deployment remains the separate user-executed protocol.

## Exclusions

### Out of Scope — Product scope

- New analysis features, statistical or engine changes, new defaults for thresholds, background or correction semantics.
- Figure export, figure provenance and consistent figure controls (SPEC-WS-009); clustering chooser and run comparison (SPEC-WS-010); release-level accessibility audit and usability study (SPEC-WS-011); legacy session bridge (SPEC-WS-012).

### Out of Scope — Technology and format

- Migrating away from shinydashboard, a new UI framework, dark mode, internationalization or new package dependencies.
- Any change to the project file format, run records, job lifecycle rules or route identifiers.

## HISTORY

- 2026-11-03: Planning-only draft from the hands-on UX review of integration tree 081ef06 (F1-F16, proposals A-E) and code reading of the unmerged SPEC-WS-008 branch; scheduled before SPEC-WS-009/010 by owner decision.
