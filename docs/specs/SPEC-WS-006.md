---
id: "SPEC-WS-006"
title: "Persistent run status, owned jobs and stale-result protection"
version: "0.1.0"
status: draft
created: "2026-10-20"
updated: "2026-10-23"
author: "workspace planning team"
priority: P1
phase: "v0.1.7 target"
module: "R/"
lifecycle: spec-anchored
tags: "workspace, usability, reproducibility"
---

# SPEC-WS-006 — Persistent run status, owned jobs and stale-result protection

Planning-only draft. This existing-style leaf document is the self-contained implementation contract; no implementation/test completion is claimed. Companion umbrella: [SPEC-WORKSPACE-001](SPEC-WORKSPACE-001/plan.md).

## Problem and observable outcome

Enrichment and clustering already use future/promises. The improvement is a truthful persistent job panel and lifecycle safety when users navigate, delete inputs, replace datasets or load another session.

## Dependencies and ownership

- Logical prerequisites: SPEC-WS-004.
- One disposable implementer owns this entire leaf in its own fresh worktree; independently reviewed before integration.
- Shared targets are exclusive locks, even for nonoverlapping line edits; derive conflicts from the umbrella dispatch.json. No metadata/namespace edits outside this list without registry revision.
- Upstream richR work is separately owned and integrated through an official release, never edited by this consumer leaf.

### Existing targets

- `inst/application/app.R`
- `R/enrich_tab.R`
- `R/cluster_tab.R`
- `R/update_tab.R`
- `R/save_tab.R` (amendment 006: load-commit and record hooks only; validated-load semantics remain SPEC-WS-007)

### New targets

- `R/workspace_jobs.R`
- `R/run_records.R`
- `tests/testthat/test-workspace-jobs.R`
- `tests/e2e/job-lifecycle.spec.ts`

## Technical implementation plan

1. Keep existing asynchronous engines. Persistent means during the current session and in saved project metadata, not a new database. Saved queued/running records reopen as interrupted historical records; never serialize worker handles/promises or claim resumed computation. Introduce session-owned job records with immutable input/settings snapshots, run ID, input revision, workspace generation, lifecycle state, start/end timestamps and result reference. Rendering reads state; callbacks apply a result only when owner, generation, input revision and run ID still authorize it.

2. Use explicit queued/running/succeeded/failed/cancel-requested/cancelled/detached states as warranted by actual backend behavior. Show elapsed time and genuine emitted stages only; opaque engine calls get indeterminate progress.

3. Capability-probe worker-specific cancellation in the installed future backend. Enable Stop only when owned worker termination can be acknowledged without harming another job/session. Otherwise provide explicit detach/ignore-result behavior with truthful continued-running and resource consequences; never relabel it cancelled.

4. Increment invalidation generations only after a delete/replacement has been validated and accepted, immediately before its successful state change; for load, fully validate the candidate first, then invalidate immediately before the successful atomic load state swap. Failed imports, cancelled file pickers and rejected replacement/deletion requests leave the current generation, jobs and workspace untouched. The existing session load in `R/save_tab.R` calls the session job registry's generation commit after its current checks and immediately before its first store assignment; SPEC-WS-007 later replaces those checks with its validated load path without removing the call. Session close invalidates owned work during cleanup. An obsolete callback may finish logging its own job but cannot mutate current data or success notifications. Load the reviewed001 application resource configuration through its installed loader and enforce worker admission/history bounds; avoid unbounded workers per click.

5. Define failure as retaining previous valid results. A retry gets a new run ID; a duplicate label never overwrites a historical run. Publish a versioned read-only run record adapter for manifest and result leaves.

## GEARS requirements

- **REQ-001** While work is active, the panel shall display its run identity, submitted settings, elapsed time and actual state across navigation.
- **REQ-002** When a worker completes after cancellation, replacement, deletion, retry or session load, its callback shall not change the current workspace data or claim a current success.
- **REQ-003** Where Stop is enabled, cancellation shall terminate only the owned computation and report cancelled only after backend acknowledgement.
- **REQ-004** When cancellation is unsupported, the UI shall explicitly distinguish detaching a result from stopping computation.
- **REQ-005** When a run fails, the application shall retain previous valid results and provide an actionable, escaped error summary without internal secrets.

## Binary acceptance scenarios

**AC-001** Given a delayed deterministic worker, when its dataset is deleted/replaced or another session is loaded before completion, then its callback cannot add data, selection or a success notification to the new workspace.

**AC-002** Given two independent Shiny sessions with active jobs, when one session requests Stop, then the other job continues and only an acknowledged owned termination is labeled cancelled.

**AC-003** Given an opaque long-running engine, when the user navigates away and back, then the panel remains visible with elapsed time and no fabricated percentage/stage.

**AC-004** Given a failed job and successful predecessor, when Retry is selected, then the predecessor persists and retry has a new identity with captured settings.

All requirements must be exercised by the listed scenarios plus scoped tests; verification receipts identify the specific REQ/AC IDs. Disabled controls are valid intermediate/rollback containment only; they do not close the desired capability or justify full-program completion. Required feature criteria remain unresolved until demonstrated or explicitly re-scoped by the user.

## Scoped verification and gate evidence

- Use cleanup-guaranteed controllable workers/latches and bounded timeout fixtures; never spawn unbounded background load.
- testServer tests for duplicate clicks, out-of-order completion, delete/replace/load/close races, failure/partial batch outcome and unsupported cancel.
- Browser tests observe real running state and valid completion across navigation; separate worker-PID ownership/termination tests prove cancellation rather than trusting panel text.
- Follow the canonical primary-repository quality/harness/LSP policies; record exact snapshot digests in CI. Do not duplicate their numerical thresholds here.
- Report commands, verbatim bounded outputs, commit/runtime baseline, gaps and residual risks. Full-suite phase gates run in clean CI; local checks are scoped to affected behavior.

## Requirement-to-acceptance traceability

| Requirement | Required scenarios |
|---|---|
| REQ-001 | AC-003 |
| REQ-002 | AC-001, AC-004 |
| REQ-003 | AC-002 |
| REQ-004 | AC-002, AC-003 |
| REQ-005 | AC-004 |

## Security and trust boundary

All job stores belong to the Shiny session. Job records, handles, captured inputs and results stay session-owned. The only process-level state is a bounded, in-memory admission queue of the R process, which holds, for dispatch only, references to the owning sessions' job registries, and a queue version counter; neither is persisted, and another session can observe only counts (the number of entries ahead of its own queued job, and the queue length when the queue is full). Worker handles are not loaded from projects; cancel accepts validated owned run IDs only. Worker input is validated data snapshots, not arbitrary expressions from uploads. Logs exclude raw data and access tokens.

## Rollout and rollback

Drain/detach new jobs before switching back to legacy observers. Retain recorded completed results and generation guards until all old callbacks are inert; do not remove stale-result protection during a UI rollback.

## Exclusions

### Out of Scope — Scope discipline

- A distributed scheduler, shared user job database, invented progress percentages or killing all R processes to implement cancellation.

## HISTORY

- 2026-10-20: Planning-only draft, authored after repository inspection and Hur Harness team consultation.
- 2026-10-23: Amendment 006 adds `R/save_tab.R` (load-commit and run-record hooks only) and states the session ownership of job records next to the in-process admission queue; no REQ or AC text changes.
