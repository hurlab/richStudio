---
id: "SPEC-WS-002"
title: "Design system, accessible components and audited screen handoff"
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

# SPEC-WS-002 — Design system, accessible components and audited screen handoff

Planning-only draft. This existing-style leaf document is the self-contained implementation contract; no implementation/test completion is claimed. Companion umbrella: [SPEC-WORKSPACE-001](SPEC-WORKSPACE-001/plan.md).

## Problem and observable outcome

The app already has blue/teal CSS tokens. A coherent workspace needs a documented extension of that identity and reusable accessible primitives before individual screens diverge.

## Dependencies and ownership

- Logical prerequisites: SPEC-WS-001.
- One disposable implementer owns this entire leaf in its own fresh worktree; independently reviewed before integration.
- Shared targets are exclusive locks, even for nonoverlapping line edits; derive conflicts from the umbrella dispatch.json. No metadata/namespace edits outside this list without registry revision.
- Upstream richR work is separately owned and integrated through an official release, never edited by this consumer leaf.

### Existing targets

- `inst/application/www/custom.css`
- `package.json`
- `package-lock.json`
- `.github/workflows/workspace-quality.yml`

### New targets

- `R/workspace_components.R`
- `docs/design/workspace-design-system.md`
- `docs/design/workspace-screens.md`
- `docs/design/workspace-handoff.md`
- `tests/testthat/test-workspace-components.R`
- `tests/e2e/design-system.spec.ts`

## Technical implementation plan

1. Assign a manager-design specialist to prepare design-system and screen artifacts before production UI coding. Provide empty, populated, busy, failed, imported-only and legacy-session states for Home, intake, result explorer, job panel, figures and save/load.

2. Extend existing --rs-* tokens and Shiny conventions; document typography, spacing, contrast, focus, table density, status semantics, dataset color assignment and reduced-motion behavior. Keep familiar biological terminology.

3. Review high-change choices with the independent reviewer and scientific/QA/security inputs. Record the handoff receipt and component-state inventory. Design-sync capability is optional; if unavailable, versioned local screens/token tables and an explicit missing-sync note are the deliverable.

## Proposed root re-scope and accessibility tooling amendment — pending approval

[002 accessibility tooling amendment](SPEC-WORKSPACE-001/amendments/002-accessibility-tooling.md) proposes bounded COMPONENTS/BROWSER children after the original execution cycle stopped at its five-failure cap, plus one exact development-only dependency, `axe-core` version `4.14.0`, through the existing npm manifest/lockfile. The two existing-target additions above are reserved for this proposal; they authorize no package edits until independent read-only plan-audit PASS and explicit coordinator acceptance/re-dispatch. The amendment supersedes the frozen design handoff's no-new-development-dependency restriction only for this accessibility QA tool after that approval. The four product implementation targets, frozen three design artifacts, four REQs, three ACs, dependency graph and quality thresholds remain unchanged. Historical unexpected-failure count remains5 and that execution cycle is stopped; a corrective scope cycle requires independent plan-audit PASS and explicit coordinator approval. Expected test-first RED is not an unexpected failure.

## Proposed hosted browser binding amendment — pending approval

[Hosted browser environment binding amendment](SPEC-WORKSPACE-001/amendments/002-hosted-browser-binding.md) proposes one existing workflow target for the browser-only environment adapter. The target addition is reserved, not active: local final16 acceptance and packet/readlock termination, independent amendment/metadata PASS, explicit root acceptance, and exclusive ownership reconciliation with001/011 precede application or implementation. Existing accessibility-tooling workflow exclusions are superseded only for that reviewed adapter after acceptance; runner/config/product/npm/dependency/threshold restrictions remain.001 creator history,011 future workflow ownership, all dependency edges, REQs/ACs, stopped histories and current cumulative accounting remain unchanged. Combined source/workflow and process Security review plus separate root release precede commit/push/hosted execution; actual hosted evidence and independent acceptance still gate whole002/003.

## Acceptance recovery and manual-review deferral

[002 acceptance recovery amendment](SPEC-WORKSPACE-001/amendments/002-acceptance-recovery.md) sets out whole 002 acceptance on independently accepted hosted run 39664812571 at `2442363`, including independent inspection of its layout and 100% zoom screenshots and of its measured 200% zoom layout receipts, together with the previously accepted AC-001 design inventory review and local browser milestone. It is effective on root's publication receipt. By program-owner decision, the direct human keyboard/focus/200% zoom/contrast/reduced-motion review required by the verification text below is a mandatory SPEC-WS-011 release-gate hold; 011 planning must read that amendment. The same-SHA negative alias requirement of the [check-warning portability amendment](SPEC-WORKSPACE-001/amendments/002-check-warning-portability.md) is superseded for 002 acceptance by the in-run negative job. REQs, ACs, targets, dependency graph and quality thresholds remain unchanged; the lifecycle `status` field is updated separately in a sync phase.

## GEARS requirements

- **REQ-001** The design handoff shall cover each primary route and its empty, running, failed and completed states before those screens enter implementation.
- **REQ-002** The UI components shall expose visible labels, keyboard focus, semantic status text and non-color state cues.
- **REQ-003** While the viewport is narrow or the browser is zoomed, primary actions shall remain reachable and data tables shall have labeled contained overflow.
- **REQ-004** Where motion is present, the interface shall respect reduced-motion preferences.

## Binary acceptance scenarios

**AC-001** Given the approved handoff inventory, when the reviewer checks each planned screen, then every route has states, component references and an explicit handoff receipt.

**AC-002** Given a keyboard-only user, when all component actions are traversed and activated, then focus is visible and returned after dialogs with no trap.

**AC-003** Given Given 375x667 and200% zoom scenarios, when primary cards/forms render, then actions remain reachable and only intentionally scrollable tables overflow.

All requirements must be exercised by the listed scenarios plus scoped tests; verification receipts identify the specific REQ/AC IDs. Disabled controls are valid intermediate/rollback containment only; they do not close the desired capability or justify full-program completion. Required feature criteria remain unresolved until demonstrated or explicitly re-scoped by the user.

## Scoped verification and gate evidence

- Component unit tests for labels/IDs, unique namespaces and status text.
- CLI accessibility checks plus manual keyboard/focus/zoom/contrast/reduced-motion review; automated scanning alone does not establish accessibility.
- Compare desktop and narrow-screen screenshots to reviewed artifacts without asserting pixel identity across operating systems.
- Follow the canonical primary-repository quality/harness/LSP policies; record exact snapshot digests in CI. Do not duplicate their numerical thresholds here.
- Report commands, verbatim bounded outputs, commit/runtime baseline, gaps and residual risks. Full-suite phase gates run in clean CI; local checks are scoped to affected behavior.

## Requirement-to-acceptance traceability

| Requirement | Required scenarios |
|---|---|
| REQ-001 | AC-001 |
| REQ-002 | AC-002 |
| REQ-003 | AC-003 |
| REQ-004 | AC-002, AC-003 |

## Security and trust boundary

Escape dataset names and provider text; icons cannot substitute for labels. Documentation/screens contain synthetic data. External links use appropriate target/rel handling.

## Rollout and rollback

Retain original CSS token values as a reviewed reference. Roll back the scoped token/component commit and keep legacy modules available until screen-specific gates pass.

## Exclusions

### Out of Scope — Scope discipline

- A frontend framework rewrite, mandatory design-sync availability, logo redesign or unreviewed global CSS replacement.

## HISTORY

- 2026-10-20: Planning-only draft, authored after repository inspection and Hur Harness team consultation.

- 2026-10-21: Proposed hosted browser environment binding amendment reserves one existing workflow target; no ownership or execution activates before its explicit local-evidence, lock, independent-review and root-acceptance prerequisites.

- 2026-10-21: Acceptance recovery amendment records whole 002 acceptance, the manual-review deferral to the 011 release gate, the negative-alias supersession and measured-layout evidence for the 200% zoom state; REQs, ACs and targets are unchanged.
