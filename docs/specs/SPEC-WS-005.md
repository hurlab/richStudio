---
id: "SPEC-WS-005"
title: "Verified explicit enrichment background and upstream compatibility"
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

# SPEC-WS-005 — Verified explicit enrichment background and upstream compatibility

Planning-only draft. This existing-style leaf document is the self-contained implementation contract; no implementation/test completion is claimed. Companion umbrella: [SPEC-WORKSPACE-001](SPEC-WORKSPACE-001/plan.md).

## Problem and observable outcome

Users need to know what universe generated each enrichment result. A background selector is scientifically meaningful only when the exact public richR API and resulting probabilities are verified.

## Dependencies and ownership

- Logical prerequisites: SPEC-WS-004, SPEC-WS-006.
- One disposable implementer owns this entire leaf in its own fresh worktree; independently reviewed before integration.
- Shared targets are exclusive locks, even for nonoverlapping line edits; derive conflicts from the umbrella dispatch.json. No metadata/namespace edits outside this list without registry revision.
- Upstream richR work is separately owned and integrated through an official release, never edited by this consumer leaf.

### Existing targets

- `R/deg_enrich.R`
- `R/enrich_tab.R`
- `DESCRIPTION`
- `renv.lock`
- `docs/DEPENDENCY_RUNTIME.md`

### New targets

- `R/enrichment_background.R`
- `tests/testthat/test-enrichment-background.R`
- `tests/fixtures/workspace/universe-oracle.tsv`

## Technical implementation plan

1. Extend the planning probe: pinned public richR 0.1.5 has explicit universe formals/forwarding in GO/KEGG/enrich methods, and one local generic-route hypergeometric oracle matched; these observations do not establish all-route feature readiness. Start the implementation contract spike: record richR version/commit, method signatures, supported universe behavior, annotation preparation, size filtering and multiple-testing family. Inspect direct GO/KEGG/Reactome and generic routes separately; sibling-source signatures alone do not establish deployed support.

2. Offer a clearly labeled default annotated universe and an optional complete measured/background gene list only after that route passes the scientific oracle. Validate species/keytype, deduplication, mapped intersection and query containment, and show effective universe and excluded counts before running.

3. Use a tiny hand-computable term membership fixture with explicit N,K,n,k and an independent hypergeometric upper-tail result. Check raw probability, adjusted probability, tested term family, denominator changes, duplicate/unmapped handling and each supported annotation route.

4. If the verified public 0.1.5 route cannot satisfy the complete contract, coordinate a separately reviewed official richR release and consumer pin update; no private monkey patch, direct internal engine bypass or statistical approximation. Record remote upstream artifacts as external dependencies, not richStudio-owned edits.

5. Default richR clustering term-union background remains a different documented quantity; this leaf changes enrichment background only.

## GEARS requirements

- **REQ-001** The enrichment result shall identify the effective background source, mapped size, query inclusion rule and annotation identity or explicitly mark unavailable fields.
- **REQ-002** Where a background mode is enabled, the exact installed public enrichment route shall reproduce the independent fixture oracle for raw and adjusted probabilities.
- **REQ-003** When a query/background pair is incompatible, the application shall reject execution with the excluded identifiers/counts and shall not silently replace the universe.
- **REQ-004** When public API support or oracle evidence is absent, the custom-background control shall remain unavailable with a truthful explanation while the verified default route remains usable.
- **REQ-005** The application shall not label a DEG-only list as the complete measured gene universe.

## Binary acceptance scenarios

**AC-001** Given a synthetic term with known N,K,n,k, when the default and explicit-background modes run through public entry points, then reported denominators and raw/adjusted probabilities match the independent oracle within a declared numeric tolerance.

**AC-002** Given duplicated/unmapped background IDs and a query outside the effective universe, when the review card evaluates the pair, then deduplication/intersection counts are correct and incompatible submission is blocked.

**AC-003** Given an unsupported public route, when a user attempts custom background, then the control cannot submit and default enrichment remains available, while this leaf remains unresolved until the required public-route capability passes.

**AC-004** Given the new public richR release is required, when the consumer dependency is updated, then the release asset/commit digest, installed worker namespace, scientific oracle and existing integration regressions all pass.

All requirements must be exercised by the listed scenarios plus scoped tests; verification receipts identify the specific REQ/AC IDs. Disabled controls are valid intermediate/rollback containment only; they do not close the desired capability or justify full-program completion. Required feature criteria remain unresolved until demonstrated or explicitly re-scoped by the user.

## Scoped verification and gate evidence

- Installed-package method/formal inspection and actual calls, not text matching alone.
- Independent phyper oracle and separately derived adjustment-family expectations for GO/KEGG/Reactome fixtures; freeze correction method and filtering order in receipt.
- Regression tests show unchanged verified-default behavior unless an explicitly versioned statistical change is approved and visible.
- Follow the canonical primary-repository quality/harness/LSP policies; record exact snapshot digests in CI. Do not duplicate their numerical thresholds here.
- Report commands, verbatim bounded outputs, commit/runtime baseline, gaps and residual risks. Full-suite phase gates run in clean CI; local checks are scoped to affected behavior.

## Requirement-to-acceptance traceability

| Requirement | Required scenarios |
|---|---|
| REQ-001 | AC-001, AC-002 |
| REQ-002 | AC-001, AC-004 |
| REQ-003 | AC-002 |
| REQ-004 | AC-003 |
| REQ-005 | AC-002 |

## Security and trust boundary

User backgrounds are bounded data-only uploads, never code. Annotation providers use fixed supported routes; do not convert metadata URLs into arbitrary fetch targets. Sensitive gene lists are not included in provider diagnostics or telemetry.

## Rollout and rollback

Disable only the custom-background capability and retain recorded historical outcomes. Reverting dependency pins is separately reviewed with full consumer oracle evidence; never relabel old runs as using a different universe.

## Exclusions

### Out of Scope — Scope discipline

- New enrichment algorithms, GSEA, a private richR fork or applying enrichment-universe semantics to clustering.

## HISTORY

- 2026-10-20: Planning-only draft, authored after repository inspection and Hur Harness team consultation.
