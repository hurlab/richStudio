---
id: "SPEC-WS-008"
title: "Unified result exploration and linked multi-dataset selection"
version: "0.1.0"
status: draft
created: "2026-10-20"
updated: "2026-10-20"
author: "workspace planning team"
priority: P1
phase: "v0.1.7 target"
module: "R/"
lifecycle: spec-anchored
tags: "workspace, usability, reproducibility"
---

# SPEC-WS-008 — Unified result exploration and linked multi-dataset selection

Planning-only draft. This existing-style leaf document is the self-contained implementation contract; no implementation/test completion is claimed. Companion umbrella: [SPEC-WORKSPACE-001](SPEC-WORKSPACE-001/plan.md).

## Problem and observable outcome

Results and their next actions are spread across existing modules. A shared result-first view can improve continuity while preserving unclustered and imported-result routes.

## Dependencies and ownership

- Logical prerequisites: SPEC-WS-003, SPEC-WS-004, SPEC-WS-007.
- One disposable implementer owns this entire leaf in its own fresh worktree; independently reviewed before integration.
- Shared targets are exclusive locks, even for nonoverlapping line edits; derive conflicts from the umbrella dispatch.json. No metadata/namespace edits outside this list without registry revision.
- Upstream richR work is separately owned and integrated through an official release, never edited by this consumer leaf.

### Existing targets

- `inst/application/app.R`
- `R/rr_visualize_tab.R`
- `R/clus_visualize_tab.R`

### New targets

- `R/results_explorer.R`
- `R/workspace_selection.R`
- `tests/testthat/test-results-explorer.R`
- `tests/e2e/results-explorer.spec.ts`

## Technical implementation plan

1. Add a shared explorer above existing visual modules through adapters. Show run/dataset summary, readable table labels, exact-value download and contextual View results/Create figure/Cluster/Run again actions.

2. Define immutable source row keys using dataset/run plus qualified term ID and annotation namespace/context, not row numbers, bare term IDs or labels. Check species/keytype/annotation compatibility before cross-dataset gene-overlap comparisons; unknown imported context produces an explicitly unsupported comparison, never an assumed match. Linked selection highlights term, cluster and member genes without modifying the underlying results; selection survives sort/filter where the selected key remains visible.

3. Assign deterministic dataset order/colors from stable IDs within a project, surviving rename, reorder, filtering and save/reopen and pair colors with text/symbol cues. Preserve extra provider fields and immutable raw_result.

4. Render not_tested/not_significant/not_supplied/not_recorded distinctly in comparisons; absent exported rows do not automatically mean tested and nonsignificant. Only available test-family provenance supports that inference.

5. After completion compact settings rather than burying results. Failed/empty states explain available next actions without silently rerunning work.

## GEARS requirements

- **REQ-001** When a result completes or is imported, the explorer shall lead with its summary and valid next actions without requiring clustering.
- **REQ-002** When a term or cluster is selected, linked tables/figures shall identify the same stable biological/result identity after sorting or filtering.
- **REQ-003** The dataset order and identity cues shall remain consistent across views of the same project.
- **REQ-004** When dataset comparison has absent information, the explorer shall distinguish unavailable/not-tested/not-significant states only to the degree supported by recorded evidence.
- **REQ-005** The explorer shall preserve original numerical values and source/provider columns while formatting display precision.

## Binary acceptance scenarios

**AC-001** Given the same result in table and plot, when the table is sorted and a term selected, then the correct source term and its member genes are highlighted in both views.

**AC-002** Given identical term labels with different source IDs/runs, when one is selected, then only that namespace-qualified identity is selected, incompatible species/keytype/annotation comparisons are unsupported, and raw data stay unchanged.

**AC-003** Given one dataset did not test a term and another tested it nonsignificant, when the comparison is opened, then the two states have different textual cues and are not both plotted as zero.

**AC-004** Given imported enrichment without clusters, when results are opened, then the user can make a figure and export exact values directly.

All requirements must be exercised by the listed scenarios plus scoped tests; verification receipts identify the specific REQ/AC IDs. Disabled controls are valid intermediate/rollback containment only; they do not close the desired capability or justify full-program completion. Required feature criteria remain unresolved until demonstrated or explicitly re-scoped by the user.

## Scoped verification and gate evidence

- Identity/selection unit tests for duplicate labels, numeric labels, empty/single/multiple datasets and retained extra columns.
- Browser result-first success/empty/failure states and sorting/filtering linked selections.
- Compare pre/post raw_result digests and exported full-precision values.
- Follow the canonical primary-repository quality/harness/LSP policies; record exact snapshot digests in CI. Do not duplicate their numerical thresholds here.
- Report commands, verbatim bounded outputs, commit/runtime baseline, gaps and residual risks. Full-suite phase gates run in clean CI; local checks are scoped to affected behavior.

## Requirement-to-acceptance traceability

| Requirement | Required scenarios |
|---|---|
| REQ-001 | AC-004 |
| REQ-002 | AC-001, AC-002 |
| REQ-003 | AC-001 |
| REQ-004 | AC-003 |
| REQ-005 | AC-001, AC-004 |

## Security and trust boundary

Render imported terms as text, escape tooltip HTML and use validated project-local IDs in linking. Selection must stay session-local and never form executable selectors from labels.

## Rollout and rollback

Keep old tables/visual modules accessible through adapters. Disable the explorer view without changing stored numerical results or IDs; selection state is disposable display state.

## Exclusions

### Out of Scope — Scope discipline

- Recomputing statistics during table filtering, inferring nonsignificance from missing rows, or a new clustering engine.

## HISTORY

- 2026-10-20: Planning-only draft, authored after repository inspection and Hur Harness team consultation.
