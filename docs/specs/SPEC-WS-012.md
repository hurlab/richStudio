---
id: SPEC-WS-012
title: "Safe legacy session bridge and migration gate"
version: "0.1.0"
status: draft
created: 2026-10-20
updated: 2026-10-20
author: workspace planning team
priority: P1
phase: "v0.1.7 target"
module: "R/"
lifecycle: spec-anchored
tags: "legacy, session, security, migration"
---

# SPEC-WS-012 — Safe legacy session bridge and migration gate

Planning-only draft. Split from 007 after independent audit D4 so one unresolved conversion architecture cannot indefinitely block additive metadata/exploration/figures. No isolation probe, infrastructure installation or legacy conversion was executed in this planning task.

## Problem and observable outcome

The current browser RDS loader is an observed deserialization boundary. Keeping it unchanged during additive workspace improvements preserves interaction but does not establish safety. A changed format/default or replacement loader needs a proven restricted bridge and a complete nondeveloper restoration path, not an optimistic subprocess assumption or an untested command-line fallback.

## Dependencies and ownership

- Logical prerequisites: SPEC-WS-001, SPEC-WS-006, SPEC-WS-007.
- One platform/deployment implementer owns this leaf in a fresh worktree; security independently reviews confinement evidence, QA verifies data restoration, and product/orchestrator records interaction acceptance. No agents run privileged deployment commands.
- 012 does not block008/009/010;011 final release requires012 accepted. A hold outcome is an architectural decision, not full acceptance of the bridge or full-program completion.
- Shared targets are exclusive locks derived from dispatch.json; bridge work cannot race007/008/009 edits of app/save files.

### Existing targets

- `R/save_tab.R`
- `inst/application/app.R`

### Prerequisite-created targets

- `docs/PROJECT_FORMAT.md` (created by SPEC-WS-007)

### New targets

- `R/legacy_session_bridge.R`
- `scripts/probe-legacy-isolation.sh`
- `scripts/convert-trusted-session.R`
- `tests/security/legacy-isolation-probe.R`
- `tests/testthat/test-legacy-session-bridge.R`
- `tests/e2e/legacy-session-restore.spec.ts`
- `docs/quality/legacy-bridge-decision.md`

## Technical implementation plan

1. Complete a separately reviewable discovery phase before committing to bridge or default-format rollout implementation. The infrastructure owner is the designated deployment/platform implementer for this task, with security as independent decision reviewer and product/orchestrator owning the user-experience disposition. No production infrastructure is installed during planning. Candidate mechanism is Linux bubblewrap using a private user/mount/PID/IPC/UTS/network namespace, an allowlisted read-only R/runtime bind mount, an isolated empty home/environment, no host credentials, a generated private output directory and resource controls enforced by the target runner/cgroup or supported service manager. An unprivileged container may be evaluated as the second candidate configuration only if already available and equally constrained; ordinary callr/future/subprocess execution is not a candidate sandbox. Do not assume the host supports unprivileged namespaces, bubblewrap, cgroups or a service manager permission.

2. Future 012 discovery execution starts with read-only probes of OS/kernel, executable/version presence, user-namespace availability, installed service/cgroup capabilities, serving identity permissions and intended runtime paths; no privileged installation or host-policy mutation. Then run only harmless synthetic canaries in a disposable unprivileged directory: deny network access, deny read of a synthetic credential sentinel outside the allowlist, deny write to an outside sentinel, allow only the intended output, enforce child count/memory/CPU/output bounds and terminate/clean all children. The probe script never opens a real secret or executes a malicious RDS. A maximum of two candidate configurations and five total probe/revision cycles bounds discovery; after the budget, produce an unresolved outcome instead of more infrastructure experimentation. This attempt budget is not an application quota or time estimate.

3. docs/quality/legacy-bridge-decision.md records measured capabilities/canary output and one independently reviewed outcome: proceed with proven browser bridge; explicitly accept a tested trusted-local migration route with its bench-user cost; or hold/re-scope import migration while legacy requirements remain open. Exercise representative controlled1.0 structures (DEG, enrichment with provider extras, single/multiple clusters, zero-result tables, Unicode/duplicate labels and missing provenance). A nondeveloper task must begin from an existing saved file, restore the analysis, locate matching results/settings, reopen it and explain unavailable provenance without editing R code, learning shell syntax or losing the original. Local migration is accepted only after that complete task succeeds and the product owner records the changed interaction; otherwise hold it. Keep discovery results separate from scientific/CI claims. Discovery completion means a usable decision, not that bridge implementation is complete.


4. Only after the independently reviewed discovery outcome supports a route, implement the minimum bridge and adapters. Browser upload goes to the restricted disposable conversion boundary, which emits only bounded data-only JSON/tables validated by 007 before atomic state swap. Use001 application resource policy and 006 owned-work generation guards. Converter input/output paths are generated and constrained; no provider/network calls, inherited credentials or uploaded recipe execution. A local converter fallback requires explicit product acceptance of its tested user interaction; do not silently turn browser compatibility into a shell task.

5. Preserve original1.0 files and all current data/results. JSON1.0 remains data-only. Supported RDS1.0 fixtures include DEG/extra result columns, multiple/empty/single clustering structures, Unicode/duplicate labels and missing settings/provenance. Successful restoration preserves exact numerical values, references and historical metadata availability without recomputation; unsupported structures reject before current-state mutation. Future active worker handles/closures are never restored.

6. Change the public default/import route only after bridge confinement, safe data validation and representative nondeveloper restoration pass. If discovery fails or requires unavailable infrastructure, record hold/re-scope with concrete capabilities/owner needed; keep new-default rollout held, preserve prior supported release/migration phase and mark accepted legacy/security scope unresolved. Do not indefinitely hold008/009, whose additive007 metadata/writer contract is independent. Infrastructure creation or privileged target-host configuration requires its own concrete reviewed/user-executed operation, not implicit permission from this plan.

## GEARS requirements

- **REQ-001** When discovery starts, the owner shall evaluate at most two candidate configurations and five total probe/revision cycles and record capability, confinement and restoration evidence before bridge implementation.
- **REQ-002** Where a browser legacy bridge is enabled, it shall deny network/credential access and writes outside its generated output, enforce configured resource bounds and emit only validated data-only state.
- **REQ-003** When a supported legacy analysis is restored, the bridge shall preserve exact data/results and mark unavailable metadata not recorded without recomputation or recipe execution.
- **REQ-004** When safe isolation or a usable fallback is unproven, changed legacy/default-format rollout shall remain held and the full bridge requirement shall remain unresolved without blocking additive exploration.
- **REQ-005** When the public import/default change is evaluated, the team shall require a security-approved route and a completed nondeveloper restoration task with explicit product acceptance of any changed interaction.

## Binary acceptance scenarios

**AC-001** Given the installed target environment and candidate budget, when read-only capabilities and harmless synthetic canaries are evaluated, then the decision artifact records all measurements and a proceed, explicitly accepted fallback or hold disposition without exceeding the budget or installing infrastructure.

**AC-002** Given a proposed browser bridge and synthetic outside credential/write/network sentinels, when conversion runs, then outside reads/writes/network attempts are denied, only generated data output is returned, process/memory/CPU/output bounds are enforced and every child/output is cleaned. Ordinary child-process execution without this evidence fails acceptance.

**AC-003** Given controlled representative1.0 RDS and JSON analyses, when a nondeveloper begins from the saved file, follows the accepted UI/support path, locates matching data/results/settings and reopens the converted project, then numerical values/relationships survive, missing provenance is explicit, the original remains available, no R code or shell syntax is required unless an explicitly accepted tested alternative is recorded, and no recipe executes.

**AC-004** Given exhausted discovery or failed confinement/usability, when rollout is evaluated, then changed default/import stays held,012 and full-program legacy scope remain unresolved, and 008/009 may still integrate against the reviewed007 additive adapter.

**AC-005** Given an invalid bridge result while a valid workspace/job is active, when candidate validation fails, then all current state and job generations remain unchanged; a valid bridge result invalidates only immediately before the successful atomic state swap.

## Requirement-to-acceptance traceability

| Requirement | Required scenarios |
|---|---|
| REQ-001 | AC-001 |
| REQ-002 | AC-002, AC-005 |
| REQ-003 | AC-003 |
| REQ-004 | AC-004 |
| REQ-005 | AC-002, AC-003 |

## Scoped verification and gate evidence

- Future read-only capability report, safe synthetic isolation test output and complete decision artifact precede implementation of an enabled bridge; missing/unsupported capabilities are gaps, not passes.
- Use controlled RDS fixtures generated from known data only. No real secrets, malicious RDS, destructive production tests, background load or privileged canary execution.
- Test denied network, outside read/write, output allowlist and configured resource boundaries in a disposable environment with guaranteed cleanup; process separation alone does not close security acceptance.
- Installed package adapters and browser restoration cover exact values, empty/multiple cluster structures, failed validation atomicity and 006 stale-job guard integration.
- Representative nondeveloper usability task is observed and documented; a hold decision does not satisfy AC-002/003 or close the implementation feature.

## Security and trust boundary

Untrusted RDS is handled before deserialization by an independently verified restriction boundary; validation afterward is necessary but insufficient. Required namespaces/resource controls and runtime binds must be proven on the target serving identity. No speculative infrastructure, arbitrary URL, credential mount or shared conversion service is introduced. Review any required infrastructure change separately before its user-executed privileged setup.

## Rollout and rollback

Keep007 additive metadata/writers available regardless of bridge outcome. Preserve the existing RDS format/parser and user entry until replacement is proven, explicitly retaining its unresolved trust risk; all candidate application continues through 007 validation and 006 generation-safe atomic commit. Hold changed default/new public migration on failure; preserve old files and prior supported release. On a deployed bridge regression, disable it and revert the app-scoped release through the user-executed protocol rather than silently falling back to unsafe deserialization.

## Exclusions

### Out of Scope — Boundary discipline

- Installing container infrastructure during planning, assuming ordinary subprocesses are sandboxes, or claiming arbitrary RDS is safe after schema checks.
- Silently removing browser legacy compatibility, introducing accounts/cloud services or counting a hold outcome as completed saving functionality.

## HISTORY

- 2026-10-20: Added independently executable legacy/security contract after plan-audit D4;007 remains an atomic additive producer for exploration.
