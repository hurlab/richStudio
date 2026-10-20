---
id: "SPEC-WS-004"
title: "Intake validation and truthful scientific query preview"
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

# SPEC-WS-004 — Intake validation and truthful scientific query preview

Planning-only draft. This existing-style leaf document is the self-contained implementation contract; no implementation/test completion is claimed. Companion umbrella: [SPEC-WORKSPACE-001](SPEC-WORKSPACE-001/plan.md).

## Problem and observable outcome

Upload, preprocessing and scientific settings currently occupy one large surface. Query construction can prefer Padj then Pvalue, and a preview filter must not be mistaken for a committed scientific selection.

## Dependencies and ownership

- Logical prerequisites: SPEC-WS-001, SPEC-WS-003.
- One disposable implementer owns this entire leaf in its own fresh worktree; independently reviewed before integration.
- Shared targets are exclusive locks, even for nonoverlapping line edits; derive conflicts from the umbrella dispatch.json. No metadata/namespace edits outside this list without registry revision.
- Upstream richR work is separately owned and integrated through an official release, never edited by this consumer leaf.

### Existing targets

- `R/enrich_tab.R`
- `R/cluster_upload_tab.R`
- `R/rr_visualize_tab.R`
- `R/rr_column_handling.R`
- `R/file_handling.R`

### New targets

- `R/input_review.R`
- `tests/testthat/test-input-review.R`
- `tests/e2e/input-review.spec.ts`

## Technical implementation plan

1. Introduce a review card showing immutable source identity, chosen columns, organism/identifier/database/ontology, exact query rule, submitted count and recognized/unmatched/excluded counts when actually available. Preview and committed preprocessing states receive separate labels and versions.

2. Offer deterministic suggested column mappings, but require explicit resolution for ambiguous raw-versus-adjusted p-values, identifiers and duplicate semantic mappings. Preserve extra provider columns/raw data for export.

3. Integrate the same candidate-validation and transactional-commit adapter into BOTH actual enrichment-result uploaders: R/cluster_upload_tab.R and the independent direct-plot upload observer in R/rr_visualize_tab.R. Do not assume helpers intercept a route that still reads and publishes its own file. Keep imported enrichment as a separate validated route. Validate probability ranges, numeric types, duplicate IDs, delimiter conventions and required membership columns before mutating stores. Never silently synthesize missing Padj from Pvalue.

4. Mapping counts may need annotation loading. Show pending/not available until measured, distinguish unavailable provenance from invalid input, and revalidate a versioned submission snapshot immediately before execution.

## GEARS requirements

- **REQ-001** When submission is requested, the review card shall display the effective query rule, retained-gene count and all scientific input settings used by that run before dispatch.
- **REQ-002** When preview filtering changes, the application shall identify it as preview and shall not modify the stored query until an explicit commit action.
- **REQ-003** When column meaning is ambiguous, input is malformed or zero query genes remain, submission shall stop with a field-specific explanation while preserving previous data.
- **REQ-004** When enrichment results are imported, the application shall retain original values and additional columns and distinguish raw p-values, adjusted p-values and unavailable statistics.
- **REQ-005** When mapped/unmapped counts are not measured, the UI shall mark them unavailable and shall not present inferred totals as measured mapping evidence.

## Binary acceptance scenarios

**AC-001** Given Padj and Pvalue columns with different memberships, when the effective rule is reviewed and submitted, then preview count, submitted IDs and recorded rule agree exactly.

**AC-002** Given an adjusted-p-value-only import, when the mapping is confirmed, then no raw-p-value column is invented and an incompatible clustering option explains its missing input.

**AC-003** Given invalid probabilities, missing IDs, duplicate mappings or an empty filtered query, when upload or Run is attempted, then each actual uploader produces specific diagnostics and preserves all previous result tables, names, selections and workspace metadata.

**AC-004** Given a preview-only filter, when the user exports the stored input without committing it, then the original stored rows are exported and the preview is labeled separately.

All requirements must be exercised by the listed scenarios plus scoped tests; verification receipts identify the specific REQ/AC IDs. Disabled controls are valid intermediate/rollback containment only; they do not close the desired capability or justify full-program completion. Required feature criteria remain unresolved until demonstrated or explicitly re-scoped by the user.

## Scoped verification and gate evidence

- Unit fixtures for NA/blank/duplicates/case/delimiters, zero rows, Padj priority, explicit raw selection and ambiguous header matches.
- Shiny tests assert actual run_enrichment_jobs input IDs match the review snapshot.
- Browser tests independently submit valid, malformed and ambiguous-column fixtures through both the clustering uploader and the direct-plot uploader; each must preserve prior data on rejection, and valid direct plotting still requires neither enrichment nor clustering.
- Follow the canonical primary-repository quality/harness/LSP policies; record exact snapshot digests in CI. Do not duplicate their numerical thresholds here.
- Report commands, verbatim bounded outputs, commit/runtime baseline, gaps and residual risks. Full-suite phase gates run in clean CI; local checks are scoped to affected behavior.

## Requirement-to-acceptance traceability

| Requirement | Required scenarios |
|---|---|
| REQ-001 | AC-001 |
| REQ-002 | AC-004 |
| REQ-003 | AC-003 |
| REQ-004 | AC-002, AC-003 |
| REQ-005 | AC-001, AC-003 |

## Security and trust boundary

File extensions are hints only; load the accepted001 application resource configuration/loader and bound bytes/rows/columns/strings before expensive parsing. Missing/invalid policy blocks submission. Escape imported labels/text and reject non-data objects. Scientific validation is distinct from upload trust validation.

## Rollout and rollback

Retain raw uploads and old completed results. Revert review adapters without rewriting original files; failed/partial validation must be transactional.

## Exclusions

### Out of Scope — Scope discipline

- Using a DEG-only upload as the measured background, silently changing current engine defaults, or claiming automatic species/identifier inference is definitive.

## HISTORY

- 2026-10-20: Planning-only draft, authored after repository inspection and Hur Harness team consultation.
