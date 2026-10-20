---
id: SPEC-WS-011
title: "Integrated usability, accessibility and release verification"
version: "0.1.0"
status: draft
created: 2026-10-20
updated: 2026-10-20
author: workspace planning team
priority: P1
phase: "v0.1.7 target"
module: "R/"
lifecycle: spec-anchored
tags: "workspace, usability, release"
---

# SPEC-WS-011 — Integrated usability, accessibility and release verification

Planning-only draft. Companion umbrella: [SPEC-WORKSPACE-001](SPEC-WORKSPACE-001/plan.md).

## Problem and observable outcome

Feature-level tests do not establish that users can finish the connected workflow or explain what was analyzed. Release needs current scientific, runtime, usability, accessibility and security evidence, with gaps stated separately.

## Dependencies and ownership

- Logical prerequisites: SPEC-WS-001, SPEC-WS-002, SPEC-WS-003, SPEC-WS-004, SPEC-WS-005, SPEC-WS-006, SPEC-WS-007, SPEC-WS-008, SPEC-WS-009, SPEC-WS-010, SPEC-WS-012.
- One implementer owns this leaf in a fresh worktree; independent reviewer, persistent QA and security roles gate integration. Existing production fixes discovered here require an explicit target-registry update and corrective leaf before dispatch.
- Locks include prerequisite-created workflow/config files; no parallel writer may update them.

### Existing targets

- `README.md`
- `INSTRUCTION.md`

### Prerequisite-created targets

- `.github/workflows/workspace-quality.yml` (created by SPEC-WS-001)
- `playwright.config.ts` (created by SPEC-WS-001)

### New targets

- `tests/e2e/workspace-journeys.spec.ts`
- `tests/e2e/workspace-accessibility.spec.ts`
- `tests/e2e/workspace-security.spec.ts`
- `docs/WORKSPACE_GUIDE.md`
- `docs/WORKSPACE_RELEASE_CHECKLIST.md`

## Technical implementation plan

1. Exercise all four Home entries: gene lists to enrichment to figure; imported results directly to figures; optional clustering and named comparisons; current and legacy session reopen. Navigation during work, interrupted jobs and old-generation callbacks are mandatory paths.
2. Observe unfamiliar representative users completing these tasks and explaining input, query/background, statistic and saved state. Record participant context/count, completion, assistance, comprehension and blocking errors. Team opinions and screenshots are not user-study findings. A blocking task failure requires correction and observed retest before its route ships.
3. Run automated CLI accessibility checks plus manual keyboard, focus restoration, zoom, narrow-screen/table and reduced-motion checks. Review disabled controls, missing states, contrast and non-color identity cues.
4. Run complete installed-package R tests/check and coverage in clean CI, along with pinned Chromium journeys. Snapshot canonical quality/harness/LSP/security policy and digests; do not copy their threshold numbers here. Missing tooling is an explicit gap, never a pass. Scope local tests to changed behavior.
5. Repeat and, with reviewed evidence, refine the 001 measured resource baseline/configuration using identical representative fixtures/runtime before and after for time, memory and responsiveness. The limits/config/loader already exist before 004/006/007;011 is not their first producer. Do not invent a performance target from one historical run. Keep provider-network checks separate from deterministic CI.
6. Publish the reviewed candidate, migration instructions, rollback receipt and all limitations. Stage with server-compatible R and installed libraries. Agent prepares and reviews deployment only; user executes the established privileged command; retrieve actual result/worker/library evidence afterward. Do not auto-deploy as part of this planning request.

## GEARS requirements

- **REQ-001** When release is evaluated, every required leaf acceptance criterion shall have exact-commit measured evidence and an independent review disposition before publication.
- **REQ-002** The release gate shall block on failed required tests, unresolved Critical/High security findings or absent scientific oracle evidence for an enabled capability.
- **REQ-003** When an unfamiliar-user task fails in a blocking way, the team shall correct and retest it before presenting the affected route as ready.
- **REQ-004** The report shall distinguish scoped local, clean CI, manual accessibility, user-study, staging and deployed observations and identify unobserved surfaces.
- **REQ-005** The release procedure shall preserve the prior release and legacy project files and shall require actual post-run live commit/worker/library evidence before claiming deployment.
- **REQ-006** When changed project import is evaluated, the application shall require representative legacy RDS and JSON analyses to be restored without silent data/result loss through the accepted safe bridge before publication and shall hold changed format rollout when that evidence is absent.

## Binary acceptance scenarios

**AC-001** Given a complete candidate, when the clean CI gate runs, then all required tests pass with exact-commit test/check/coverage artifacts and policy-derived gate results.

**AC-002** Given unfamiliar representative users, when they perform the five umbrella task journeys, then completion, assistance, comprehension and errors are recorded, and each blocking task issue has a resolved observed retest.

**AC-003** Given a failed background oracle, unsafe legacy bridge or unresolved Critical/High security finding, when release is evaluated, then the candidate is blocked and the failing requirement remains open.

**AC-004** Given a user-executed staged deployment, when actual logs and live processes are retrieved, then commit, installed worker libraries, startup, core browser paths and preserved rollback location are recorded before any deployed claim.

**AC-005** Given desktop, narrow-screen and zoomed browser states, when keyboard/manual and automated checks run, then all primary tasks remain accessible and every confirmed blocker has a regression case.

## Scoped verification and gate evidence

- Full installed R suite/check, namespace-worker tests, policy-derived coverage and Chromium CLI in the clean gate runner; retain verbatim outputs, counts/skips, commit and runtime.
- Chromium desktop 1280x720 and mobile 375x667; web-first assertions and role/label/test-ID locators; no CSS/XPath, hard sleeps or Playwright MCP.
- Review numerical exports against source result values; perform legacy/current save/load and invalid-import atomicity tests.
- No authentication tests are invented for this account-free app. Real annotation/provider smoke and server R compatibility remain separate explicit evidence.

## Requirement-to-acceptance traceability

| Requirement | Required scenarios |
|---|---|
| REQ-001 | AC-001 |
| REQ-002 | AC-003 |
| REQ-003 | AC-002 |
| REQ-004 | AC-001, AC-004, AC-005 |
| REQ-005 | AC-004 |
| REQ-006 | AC-003 |

## Security and trust boundary

Security auditor closes cumulative findings for session isolation, owned jobs, bounded input/archive handling, safe legacy bridge, escaping, safe export paths and secret-free artifacts. Use synthetic data, no destructive production attacks or unmanaged load. Participant notes are consented and de-identified.

## Rollout and rollback

Release the coherent reviewed workspace only after gates. A disabled optional custom-background or Stop capability is documented as unavailable, never passed functionality. New format adoption has its own legacy compatibility hold. Preserve the old protected app and old-format originals; perform app-scoped rollback only with explicit user-authorized privileged execution. No backup/worktree disposal before remote integration.

## Exclusions

### Out of Scope — Release discipline

- Automatic production deployment, accounts, cloud storage or new authentication.
- Claiming universal accessibility, scientific equivalence across algorithms, or user-study success from team opinion.

## HISTORY

- 2026-10-20: Planning-only integrated release contract.
