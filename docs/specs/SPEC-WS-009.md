---
id: "SPEC-WS-009"
title: "Consistent figure controls and provenance-aware export"
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

# SPEC-WS-009 — Consistent figure controls and provenance-aware export

Planning-only draft. This existing-style leaf document is the self-contained implementation contract; no implementation/test completion is claimed. Companion umbrella: [SPEC-WORKSPACE-001](SPEC-WORKSPACE-001/plan.md).

## Problem and observable outcome

Bar, dot, heatmap and network outputs already exist. Users need consistent controls and enough exported context to reproduce the figure without treating visual filtering as a change to analysis.

## Dependencies and ownership

- Logical prerequisites: SPEC-WS-007, SPEC-WS-008.
- One disposable implementer owns this entire leaf in its own fresh worktree; independently reviewed before integration.
- Shared targets are exclusive locks, even for nonoverlapping line edits; derive conflicts from the umbrella dispatch.json. No metadata/namespace edits outside this list without registry revision.
- Upstream richR work is separately owned and integrated through an official release, never edited by this consumer leaf.

### Existing targets

- `R/rr_visualize_tab.R`
- `R/clus_visualize_tab.R`
- `R/rr_bar.R`
- `R/rr_dot.R`
- `R/rr_hmap.R`
- `R/rr_network.R`
- `R/cluster_hmap.R`
- `R/save_tab.R`

### New targets

- `R/figure_settings.R`
- `tests/testthat/test-figure-settings.R`
- `tests/e2e/figure-export.spec.ts`

## Technical implementation plan

1. Standardize source/run selection, statistic label, top-N/filter, dataset order/colors, size/label controls and reset behavior through a small shared settings adapter. Reuse current plot functions; preserve specific controls that matter for each plot.

2. Show preview/display filters separately from committed analysis inputs. Preserve raw/adjusted p-value labels, transformations and missing-state legend; avoid converting an absent p-value to zero.

3. Export the figure, full-precision data used, machine-readable display settings and recorded source-run/provenance metadata. Text-safe labels and generated archive filenames follow007.

4. Unavailable controls are visibly disabled with a supported-route explanation. Compare existing layouts and remove duplicated controls only after parity tests, not by rewriting all plotting code.

## GEARS requirements

- **REQ-001** The equivalent controls shall use consistent labels, defaults and dataset identity cues across supported figure types.
- **REQ-002** When a display setting changes, the underlying analysis result and recorded scientific parameters shall remain unchanged.
- **REQ-003** When a figure is exported, its associated data/settings shall identify the source run, statistic, transform, order, filters and provenance availability.
- **REQ-004** When requested statistics or capabilities are unavailable, the figure shall explain the limitation rather than fabricate values or a working control.

## Binary acceptance scenarios

**AC-001** Given a multi-dataset result, when bar/dot/heatmap/network views are opened, then dataset order/colors and raw/adjusted statistic labels agree where applicable.

**AC-002** Given a top-N display filter, when the figure/data bundle is exported, then its settings identify the filter and underlying full result is unchanged.

**AC-003** Given an unsupported control or missing statistic, when the user reaches that view, then the limitation is explained and no placeholder value is inserted.

**AC-004** Given a saved figure specification and unchanged source run, when it is reopened, then plotted rows, numeric values and settings match while platform-dependent raster rendering is not claimed identical.

All requirements must be exercised by the listed scenarios plus scoped tests; verification receipts identify the specific REQ/AC IDs. Disabled controls are valid intermediate/rollback containment only; they do not close the desired capability or justify full-program completion. Required feature criteria remain unresolved until demonstrated or explicitly re-scoped by the user.

## Scoped verification and gate evidence

- Unit tests for settings normalization, row selection, transforms, empty/single results and exact numeric export.
- CLI browser tests for each supported figure and saved specification replay.
- Inspect export data/settings independently; visual snapshots complement numerical assertions and accessibility review.
- Follow the canonical primary-repository quality/harness/LSP policies; record exact snapshot digests in CI. Do not duplicate their numerical thresholds here.
- Report commands, verbatim bounded outputs, commit/runtime baseline, gaps and residual risks. Full-suite phase gates run in clean CI; local checks are scoped to affected behavior.

## Requirement-to-acceptance traceability

| Requirement | Required scenarios |
|---|---|
| REQ-001 | AC-001 |
| REQ-002 | AC-002 |
| REQ-003 | AC-002, AC-004 |
| REQ-004 | AC-003 |

## Security and trust boundary

Escape labels in plot tooltips, validate finite dimensions/size and bound graph nodes/edges using measured resource policy. No arbitrary HTML templates or executable graphics from uploads.

## Rollout and rollback

Retain original plotting functions and an adapter bypass until parity gates pass. Roll back display defaults independently; preserve saved historical settings and exact underlying values.

## Exclusions

### Out of Scope — Scope discipline

- New visualization algorithms, publication guarantees without artifact review, or silently changing analysis thresholds through plot controls.

## HISTORY

- 2026-10-20: Planning-only draft, authored after repository inspection and Hur Harness team consultation.
