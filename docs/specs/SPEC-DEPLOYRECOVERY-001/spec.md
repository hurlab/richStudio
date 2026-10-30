---
id: SPEC-DEPLOYRECOVERY-001
title: "Verified service recovery after a failed release publication"
version: "0.1.0"
status: draft
created: 2026-10-30
updated: 2026-10-30
author: manager-spec
priority: P1
phase: "v0.1.7 target"
module: "scripts/deploy-r46-release.sh"
lifecycle: spec-anchored
tags: "deployment, recovery, service, safety"
tier: S
---

# SPEC-DEPLOYRECOVERY-001

## §A Context and outcome

The current publication script restores the captured previous app symlink after
a failed publication, but its recovery path does not restart or verify the
service. The orchestrator's controlled execution of the actual recovery block
recorded two mocked symlink operations and no service restart. This SPEC covers
that bounded operational correction; it does not certify a real recovery yet.

The source baseline is96fac4f597d4842cdab62047eb629827ecd180b9 in the isolated
deploy-rollback-recovery worktree. Application candidate4bc65b3 and its existing
CI/server preflight receipts remain separately attributed evidence. The user
requested that the observed gap be fixed, verified and independently reviewed.

## §B Requirements

- **REQ-001** When publication fails after this deployment has made its candidate
  live, the recovery shall restore the captured previous release, restart the
  service and verify the restored service before reporting recovery success.
- **REQ-002** When a restoration, restart or recovery check fails, the recovery
  shall report the failed stage without reporting success, retain the releases
  and evidence, and terminate without recursive cleanup or unbounded retries.
- **REQ-003** When publication is interrupted at the live-switch boundary, the
  recovery shall identify whether its candidate became live even before the
  ordinary success state was recorded. When a different actor's third release
  is detected, the recovery shall stop without replacing it or restarting it.
- **REQ-004** When a failed deployment finishes, the process shall retain its
  original nonzero exit status despite recovery outcomes. When a catchable INT
  or TERM interrupts publication, the process shall use the same recovery path
  and retain a nonzero interruption status.
- **REQ-005** While publication has not changed the live release, the recovery
  shall perform no restoration or service restart. When publication succeeds,
  the deployment shall retain its existing successful publish behavior and
  shall not invoke failure recovery.
- **REQ-006** The recovery shall bound service and HTTP verification, require an
  active service and a successful response without the existing app error-page
  marker, and distinguish verified recovery from failed or unverified recovery
  in its output without the obsolete R4.5-only interpretation.
- **REQ-007** The correction shall preserve the script bytes through the
  preflight exit, candidate checkout/build/verification behavior, archive pins,
  application/scientific source, CI policies and previously completed SPECs.
- **REQ-008** Before the prepared deployment command is re-enabled, the change
  shall pass controlled actual-source failure tests and independent review,
  and its server copy and wrapper pin shall match the approved script hash.
  Prior CI/preflight results shall not be presented as new live recovery proof.

## §3 Inline acceptance criteria

- **AC-001** Given mocked actual-source publication with a candidate already
  live, When its restart fails or its publish health check fails, Then the
  captured previous release is restored, its service is restarted, and verified
  recovery is reported only after active-service and healthy-HTTP checks pass.
- **AC-002** Given the same failure path, When link restoration, recovery restart
  or restored-service verification fails, Then the failed stage is explicit,
  no recovery-success or deployment-complete message appears, no unsafe later
  stage executes, and cleanup terminates within the documented bounds.
- **AC-003** Given interruption immediately after the live switch but before its
  ordinary success marker, When recovery observes its candidate, Then it still
  restores the captured release; When it observes an unexpected third release,
  Then it changes no link and performs no service restart.
- **AC-004** Given injected ordinary failures and catchable INT/TERM, When cleanup
  succeeds or fails, Then the original ordinary nonzero status or the
  interruption status remains the final status and cleanup runs at most once.
- **AC-005** Given a failure before live publication or a successful deployment,
  When the script exits, Then failure recovery makes no link/service mutation;
  successful publication alone retains its deployment-complete result.
- **AC-006** Given injected inactive-service, HTTP failure and app error-page
  responses, When recovery checks run, Then they never produce a success result
  and their attempts and subprocess deadlines remain finite without real waits
  or real service operations in the test harness.
- **AC-007** Given the frozen baseline and corrected candidate, When bytes,
  pins and source paths are compared, Then the complete prefix through preflight
  exit and protected app/CI/scientific files remain identical; only the approved
  post-preflight recovery/publish region and focused test source may differ.
- **AC-008** Given independently approved tests and script hashes, When the
  orchestrator prepares the server command, Then syntax checks, remote copy hash,
  wrapper hash pin, old-live-release guard and exact candidate identity agree.
  Any missing result blocks re-enabling; no live recovery or deployment is claimed
  until separately observed on the server.

## §C Exclusions

### Out of Scope — Deployment redesign and application changes

- New release-management frameworks, dependencies, lock services or CI jobs.
- Statistical, clustering, UI, manuscript, package-pin or application changes.
- Real failure injection, service restarts or publication during unit tests.
- Sudo authentication bypass, uncatchable SIGKILL recovery or universal race immunity.
- Reusing the old unsafe wrapper without an approved new hash and current guards.

## §D Traceability

REQ-001→AC-001; REQ-002→AC-002; REQ-003→AC-003;
REQ-004→AC-004; REQ-005→AC-005; REQ-006→AC-006;
REQ-007→AC-007; REQ-008→AC-008. These inline criteria are canonical for Tier S.
The acceptance sibling is only the orchestrator-requested verification checklist.

## HISTORY

| Version | Date | Change |
|---|---|---|
|0.1.0|2026-10-30|Bounded automatic recovery after observed incomplete rollback; draft only.|
