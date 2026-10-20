---
id: "SPEC-WS-003"
title: "Actionable Home, active workspace and navigation continuity"
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

# SPEC-WS-003 — Actionable Home, active workspace and navigation continuity

Planning-only draft. This existing-style leaf document is the self-contained implementation contract; no implementation/test completion is claimed. Companion umbrella: [SPEC-WORKSPACE-001](SPEC-WORKSPACE-001/plan.md).

## Problem and observable outcome

Home Quick Start cards are static, and separate Visualize labels do not communicate their input context. Users need meaningful starting routes and persistent context without a forced sequence.

## Dependencies and ownership

- Logical prerequisites: SPEC-WS-002.
- One disposable implementer owns this entire leaf in its own fresh worktree; independently reviewed before integration.
- Shared targets are exclusive locks, even for nonoverlapping line edits; derive conflicts from the umbrella dispatch.json. No metadata/namespace edits outside this list without registry revision.
- Upstream richR work is separately owned and integrated through an official release, never edited by this consumer leaf.

### Existing targets

- `R/home_tab.R`
- `inst/application/app.R`

### New targets

- `R/workspace_navigation.R`
- `tests/testthat/test-workspace-navigation.R`
- `tests/e2e/workspace-entry.spec.ts`

## Technical implementation plan

1. Turn Home into four accessible actions: gene lists, imported enrichment, saved analysis and bundled demo. Keep package links/citations/About below the entry actions.

2. Add a compact active-workspace header and context-aware next actions above the existing modules. Preserve existing module namespaces and use adapters for navigation; do not rename input IDs indiscriminately.

3. Relabel duplicate navigation destinations to identify enrichment figures versus cluster figures. A new Data/Enrichment/Clustering/Figures shell is a later view of the same adapters only if the reviewed prototype/usability evidence supports it.

4. Define navigation as selection of an existing object/route, never implicit execution or filtering. Unsupported actions are disabled with an explanation or link to the supported route.

## GEARS requirements

- **REQ-001** When a Home action is activated, the workspace shall open its intended route with the selected data context intact.
- **REQ-002** The navigation shall allow imported enrichment to bypass enrichment and allow figures before clustering.
- **REQ-003** While an analysis is active, the header shall identify the selected dataset/run, organism and identifier type or explicitly show not recorded.
- **REQ-004** When users navigate away and return, the application shall retain valid input selections without rerunning an analysis.

## Binary acceptance scenarios

**AC-001** Given a fresh workspace, when each of the four entry actions is used, then the correct route opens and demo data load only after the demo action.

**AC-002** Given imported enrichment without DEG data, when Create figure is activated, then an enrichment plot is available without running enrichment or clustering.

**AC-003** Given a completed enrichment run, when the user opens clustering and returns, then the original result/run selection and settings remain selected.

All requirements must be exercised by the listed scenarios plus scoped tests; verification receipts identify the specific REQ/AC IDs. Disabled controls are valid intermediate/rollback containment only; they do not close the desired capability or justify full-program completion. Required feature criteria remain unresolved until demonstrated or explicitly re-scoped by the user.

## Scoped verification and gate evidence

- testServer navigation adapter and preserved-selection tests.
- CLI entry paths including legacy load redirect, imported-only plotting and keyboard navigation.
- Check zero network analysis requests occur merely from navigating.
- Follow the canonical primary-repository quality/harness/LSP policies; record exact snapshot digests in CI. Do not duplicate their numerical thresholds here.
- Report commands, verbatim bounded outputs, commit/runtime baseline, gaps and residual risks. Full-suite phase gates run in clean CI; local checks are scoped to affected behavior.

## Requirement-to-acceptance traceability

| Requirement | Required scenarios |
|---|---|
| REQ-001 | AC-001 |
| REQ-002 | AC-002 |
| REQ-003 | AC-001, AC-003 |
| REQ-004 | AC-003 |

## Security and trust boundary

Navigation context uses validated stable object IDs, not HTML/paths supplied by labels. Never expose another Shiny session through a shared global selected-object variable.

## Rollout and rollback

Gate the new shell/context header behind one release switch with the old menu route retained. Disabling the switch preserves object stores and completed results.

## Exclusions

### Out of Scope — Scope discipline

- Mandatory wizard steps, automatic enrichment after upload, user accounts or cloud workspaces.

## HISTORY

- 2026-10-20: Planning-only draft, authored after repository inspection and Hur Harness team consultation.
