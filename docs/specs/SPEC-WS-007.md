---
id: "SPEC-WS-007"
title: "Additive reproducible manifest, project writer and safe JSON adapters"
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

# SPEC-WS-007 — Additive reproducible manifest, project writer and safe JSON adapters

Planning-only draft. This existing-style leaf document is the self-contained implementation contract; no implementation/test completion is claimed. Companion umbrella: [SPEC-WORKSPACE-001](SPEC-WORKSPACE-001/plan.md).

## Problem and observable outcome

Session1.0 already stores results, and ZIP export already exists. The additive manifest/project writer and safe JSON adapters must explain results and preserve data without changing the existing RDS format/parser or browser entry route; its state application joins the common validated atomic commit. SPEC-WS-012 separately resolves that loader trust boundary and legacy migration; its unresolved status does not prevent additive exploration/figure work from consuming the metadata adapter.

## Dependencies and ownership

- Logical prerequisites: SPEC-WS-006.
- One disposable implementer owns this entire leaf in its own fresh worktree; independently reviewed before integration.
- Shared targets are exclusive locks, even for nonoverlapping line edits; derive conflicts from the umbrella dispatch.json. No metadata/namespace edits outside this list without registry revision.
- Upstream richR work is separately owned and integrated through an official release, never edited by this consumer leaf.

### Existing targets

- `R/save_tab.R`
- `inst/application/app.R`

### New targets

- `R/project_manifest.R`
- `R/project_import.R`
- `tests/testthat/test-project-manifest.R`
- `tests/testthat/test-project-import.R`
- `tests/e2e/project-roundtrip.spec.ts`
- `docs/PROJECT_FORMAT.md`

## Technical implementation plan

1. Add a versioned data-only JSON manifest and table files to a project ZIP. Define stable dataset/run/term/cluster IDs, source digests, source/committed filter revisions, columns, species/keytype, effective parameters, background identity/counts, annotation provider/release/build/digest when available, raw versus adjusted statistics and correction family, engine/app/R versions and result relationships.

2. Typed absence distinguishes not_recorded, not_supplied, not_tested and not_significant; do not serialize missing adjusted p-values as zero or infer organism/annotation release. Immutable numerical results are distinct from display settings and methods text.

3. Validate complete bounded archives, schemas, cross-references and table types into temporary data-only structures before one transactional workspace swap. Failed imports leave the existing workspace and jobs intact; successful swap first invalidates old job generations.

4. Preserve the existing RDS format/parser and browser entry route in this leaf; this is compatibility containment, not a statement that the current trust boundary is safe. Preserve controlled legacy JSON1.0 through a validated data-only adapter and regression fixtures. New manifest/table writing, methods text and safe JSON adapters may integrate behind additive controls, but do not switch the public default format or remove the existing loading route. SPEC-WS-012 independently owns the safe legacy bridge, representative RDS restoration and changed-default rollout gate. This leaf can be fully accepted for its additive scope and unlock008/009 even while012 remains unresolved. The overall accepted legacy/security requirement stays open until 012 completes.

5. Every supported load, including current legacy RDS and JSON, must build a fully validated candidate and apply it through the same atomic state commit; after successful validation, invalidate006 generations immediately before the swap. A malformed legacy candidate leaves data, selections and active jobs untouched. This does not make the preceding ordinary RDS deserialization safe;012 replaces that trust boundary. Add pending-worker tests for successful and failed legacy RDS/JSON load.

6. Use generated file IDs inside archives with human labels in the manifest. Reject traversal, absolute paths, symlinks, duplicate/ambiguous names, archive bombs and unsupported future major versions before state mutation. Import never sources scripts, evals expressions or executes a bundled analysis recipe.

7. Generate a plain-language methods summary from recorded parameters only. A recipe, if exported, is inert human-reviewed text; rerunning requires explicit validated application actions. No new persistent server storage or cloud sharing.

## GEARS requirements

- **REQ-001** When a project is saved, its manifest shall preserve scientific inputs, effective parameters, provenance availability, versions and typed relationships needed to interpret each saved result.
- **REQ-002** When legacy1.0 JSON data are opened through the validated adapter, the application shall preserve data and mark absent metadata not recorded without recomputation.
- **REQ-003** When a bundle is invalid or unsupported, import shall reject it before changing current workspace data or invalidating its running jobs.
- **REQ-004** When a valid project is opened, the application shall atomically replace state and reject all late callbacks from the prior workspace.
- **REQ-005** The additive project adapters shall not execute imported scripts, expressions or recipes and shall preserve the existing RDS format/parser and entry route while routing every supported candidate through common transactional validation and generation-safe atomic commit;012 separately gates the safer parser/isolation replacement.
- **REQ-006** When methods text is exported, it shall distinguish recorded facts, inferred display labels and unavailable provenance.

## Binary acceptance scenarios

**AC-001** Given current results and populated metadata, when a project is saved and reopened, then table numeric values, IDs, relationships, settings and typed missingness round-trip exactly.

**AC-002** Given a controlled session1.0 JSON and a baseline RDS-branch regression fixture, when the data-only JSON adapter is exercised and the unchanged legacy branch is characterized, then JSON result tables survive with absent provenance marked not recorded, the RDS format/parser and default remain compatible, both legacy RDS and JSON candidates use the new transactional application/generation guard, and RDS safety/migration remains assigned to012.

**AC-003** Given malicious archive paths, duplicate names, oversized expansion, unknown major version or broken references, when import is attempted, then validation fails with no workspace/job mutation and no code execution.

**AC-004** Given a valid load while an old worker is pending, when load completes and the old result arrives, then only loaded results remain and no previous generation callback changes state for BOTH supported legacy RDS and JSON as well as current safe bundles; malformed candidates leave the prior job generation and state intact.

**AC-005** Given project labels containing slashes, HTML or spreadsheet formula prefixes, when the bundle/methods/table export is inspected, then paths are generated safe IDs, UI text is escaped and human-readable spreadsheet-safe export is distinguished from exact-value data tables.

All requirements must be exercised by the listed scenarios plus scoped tests; verification receipts identify the specific REQ/AC IDs. Disabled controls are valid intermediate/rollback containment only; they do not close the desired capability or justify full-program completion. Required feature criteria remain unresolved until demonstrated or explicitly re-scoped by the user.

## Scoped verification and gate evidence

- Serialization/schema property tests for NaN/NA/empty tables, Unicode labels, numeric labels, duplicates, zero results and optional metadata.
- Transactional import tests with malformed/traversal/link/bomb fixtures created safely in temporary directories and no real exploit execution.
- Browser safe JSON/project save/new-session/open roundtrip and characterization of the unchanged legacy route; representative RDS migration usability belongs to012. Independently inspect the ZIP contents and recompute manifest digests.
- Follow the canonical primary-repository quality/harness/LSP policies; record exact snapshot digests in CI. Do not duplicate their numerical thresholds here.
- Report commands, verbatim bounded outputs, commit/runtime baseline, gaps and residual risks. Full-suite phase gates run in clean CI; local checks are scoped to affected behavior.

## Requirement-to-acceptance traceability

| Requirement | Required scenarios |
|---|---|
| REQ-001 | AC-001 |
| REQ-002 | AC-002 |
| REQ-003 | AC-003 |
| REQ-004 | AC-004 |
| REQ-005 | AC-003 |
| REQ-006 | AC-001, AC-002 |

## Security and trust boundary

RDS is a deserialization boundary, not a safe interchange format. This leaf does not add an RDS converter or claim the unchanged loader is safe;012 owns that separate risk and release gate. No changed default-format or public legacy import rollout occurs here. Load001 reviewed resource policy through its installed loader; enforce compressed/uncompressed bytes, entries, nesting, rows and columns with at/above-limit tests. Missing/invalid policy blocks import. No arbitrary provider URLs or filesystem paths are dereferenced from provenance.

## Rollout and rollback

Keep original legacy files, version adapters and a data-only export compatible with the prior supported tables. Disable new bundle import on a security failure without discarding existing results; never downgrade provenance or rewrite historical numerical outputs.

## Exclusions

### Out of Scope — Scope discipline

- Automatic execution of recipes, secure handling claims for arbitrary RDS, hosted accounts/storage, or silently filling missing legacy metadata.

## HISTORY

- 2026-10-20: Planning-only draft, authored after repository inspection and Hur Harness team consultation.
