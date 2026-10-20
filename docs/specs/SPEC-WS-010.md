---
id: "SPEC-WS-010"
title: "Clustering chooser and named run comparison"
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

# SPEC-WS-010 — Clustering chooser and named run comparison

Planning-only draft. This existing-style leaf document is the self-contained implementation contract; no implementation/test completion is claimed. Companion umbrella: [SPEC-WORKSPACE-001](SPEC-WORKSPACE-001/plan.md).

## Problem and observable outcome

Three clustering routes already exist with different significance and background policies. A chooser should explain these differences and support comparisons without presenting different engines as numerically interchangeable.

## Dependencies and ownership

- Logical prerequisites: SPEC-WS-006, SPEC-WS-008.
- One disposable implementer owns this entire leaf in its own fresh worktree; independently reviewed before integration.
- Shared targets are exclusive locks, even for nonoverlapping line edits; derive conflicts from the umbrella dispatch.json. No metadata/namespace edits outside this list without registry revision.
- Upstream richR work is separately owned and integrated through an official release, never edited by this consumer leaf.

### Existing targets

- `R/cluster_tab.R`

### New targets

- `R/clustering_review.R`
- `R/run_comparison.R`
- `tests/testthat/test-run-comparison.R`
- `tests/e2e/clustering-comparison.spec.ts`

## Technical implementation plan

1. Present each existing engine with its method, required columns, effective significance/background behavior and captured parameter values. Preserve hierarchical strict per-dataset raw-Pvalue filtering, DAVID no extra significance filter and richR term-union gene background unless separately versioned scientific work changes them.

2. Give each run a stable ID and editable human name; reruns create new immutable results. Duplicate display names are allowed only when identity remains unambiguous.

3. Compare selected runs side by side with input identity, database/species/keytype, term filtering, algorithm/versions/parameters and cluster membership summary. Different input universes/annotations receive explicit comparability warnings.

4. Do not compare arbitrary cluster numbers as if they denote the same biological group. Use term membership overlap for descriptive comparison and disclose incomplete membership/provenance; do not introduce new statistical scoring algorithms. Require species/keytype/annotation compatibility before gene-overlap comparison; unknown legacy/import context cannot establish comparability. A mean/min adjusted-value summary remains a descriptive summary and must not be labeled a new combined significance test.

## GEARS requirements

- **REQ-001** When clustering submission is requested, the chooser shall display the selected engine and effective filtering/background semantics before dispatch.
- **REQ-002** When clustering is rerun, the application shall create a distinct named run without overwriting earlier results.
- **REQ-003** When runs are compared, the view shall expose differing input identities, provenance, parameters and versions before presenting membership differences.
- **REQ-004** The comparison shall not assert numerical equivalence across engines or align clusters only by their numeric labels.

## Binary acceptance scenarios

**AC-001** Given hierarchical, DAVID and richR fixture runs, when each review card is checked, then its displayed policy and actual submitted inputs match the existing verified semantics.

**AC-002** Given two runs with the same display name, when both are saved/reopened and compared, then their IDs and results remain distinct.

**AC-003** Given runs with different annotation/input provenance, when comparison is opened, then the differences are visible, unknown/incompatible gene-overlap comparisons are unsupported and descriptive p-value summaries are not labeled combined significance tests.

**AC-004** Given reordered numeric cluster labels with identical term membership, when the comparison is rendered, then descriptive membership alignment is stable and numeric labels alone do not drive matching.

All requirements must be exercised by the listed scenarios plus scoped tests; verification receipts identify the specific REQ/AC IDs. Disabled controls are valid intermediate/rollback containment only; they do not close the desired capability or justify full-program completion. Required feature criteria remain unresolved until demonstrated or explicitly re-scoped by the user.

## Scoped verification and gate evidence

- Scientific fixture tests preserve existing engine policy and explicit term-union oracle.
- Unit tests for named run identity, unsupported comparisons, absent provenance and term-membership alignment.
- Browser one/multiple dataset chooser, rerun, save/open comparison and no-clustering figure route regression.
- Follow the canonical primary-repository quality/harness/LSP policies; record exact snapshot digests in CI. Do not duplicate their numerical thresholds here.
- Report commands, verbatim bounded outputs, commit/runtime baseline, gaps and residual risks. Full-suite phase gates run in clean CI; local checks are scoped to affected behavior.

## Requirement-to-acceptance traceability

| Requirement | Required scenarios |
|---|---|
| REQ-001 | AC-001 |
| REQ-002 | AC-002 |
| REQ-003 | AC-003 |
| REQ-004 | AC-004 |

## Security and trust boundary

Run names are escaped display text; comparison accepts project-local owned IDs. Bound comparison sizes and do not deserialize engine handles from saved projects.

## Rollout and rollback

Disable comparison/chooser presentation while retaining existing public engine adapters and all completed runs. Never rerun or renumber saved clusters during rollback.

## Exclusions

### Out of Scope — Scope discipline

- New clustering methods, claiming cross-engine numerical equivalence or changing existing significance semantics as a UI side effect.

## HISTORY

- 2026-10-20: Planning-only draft, authored after repository inspection and Hur Harness team consultation.
