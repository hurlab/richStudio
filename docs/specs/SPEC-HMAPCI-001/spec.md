---
id: SPEC-HMAPCI-001
title: "Reliable CI harness verification for frozen scientific heatmaps"
version: "0.1.0"
status: draft
created: 2026-10-30
updated: 2026-10-30
author: manager-spec
priority: P1
phase: "v0.1.7 target"
module: "tests/e2e/"
lifecycle: spec-anchored
tags: "CI, lifecycle, scientific-heatmaps, transport"
tier: M
---

# SPEC-HMAPCI-001

## §A Context and outcome

This Tier M followup repairs CI verification around the frozen R5 product from
SPEC-HEATMAP-001. It is a separate harness milestone, not another UI iteration.
Integration baseline: 72d4628557cd79326d58a46bab7e4f2ce45b2d71.
Hosted run41057333122 measured source cbd3eb3 and ended with four successful
jobs and three failed jobs. The existing hosted-browser triage records all eight
new heatmap cases passing, an older narrow-viewport pointer outside the375px
viewport, and a later server reset899.748892seconds after the first R startup log.
The reset's relationship to the900second serve deadline is an inference; the
original terminal exit124 was not retained. It is not evidence of an application crash.

The independently authored ci-triage.md records strict-process termination−9 with13of14
proofs and no application tests reached; its cause remains unobserved. The
90second full-check profile is not authorized to change. The independently authored
ci-browser-lifecycle-triage.md
records initial missing nonce followed by verified matching PID/start identity
and nonce at cleanup; its guard is in tests/e2e/job-lifecycle.spec.ts.
The CI triage also records a Python TLS transport reset. Both reports were read
from .moai/reports/heatmap-legibility during authorship.
These findings are constraints; implementation evidence must be fresh
and retain actual source identity, terminal status and artifact paths.

## §B Requirements

- **REQ-001** The followup shall preserve frozen application source, scientific
  outputs, full hover content, missing/zero semantics, colors, resource limits,
  dependency pins, canonical thresholds and every existing CI job/check.
- **REQ-002** While the browser server is running, the serve harness shall impose
  a finite1800second lifetime, retain owned-process cleanup, and durably record
  startup identity, configured deadline and observed terminal exit status before
  returning failure or success. Missing status shall be reported as unknown.
- **REQ-003** When startup ownership proof is temporarily incomplete, the browser
  fixture shall perform bounded fresh PID/start-identity and nonce revalidation
  before declaring startup failure. A ready listener alone shall not prove ownership.
- **REQ-004** When ownership remains unknown, foreign, inaccessible or inconsistent,
  the fixture shall fail closed, retain diagnostic evidence and refrain from
  signaling that unproven process. Dead processes and PID reuse shall not acquire
  ownership through retries; proven owned startup and cleanup shall remain effective.
- **REQ-005** When a scientific-boundary test targets a heatmap cell, the test shall
  natively scroll its containing region as needed, recompute current coordinates,
  and verify that the pointer and sample patch lie inside the visible clipped
  cell and physical viewport before real hover and screenshot sampling.
- **REQ-006** The scientific-boundary tests shall verify each original semantic
  cell independently at1280×720 and375×667, preserving complete cluster/statistic,
  NA and zero-floor hover assertions and per-cell RGBA comparisons for missing
  grey versus nonmissing values. Tests shall not use forced interaction, stale
  coordinates, empty tooltips or relaxed color assertions as substitutes.
- **REQ-007** When a dependency download fails because of a transport interruption,
  the preparation harness shall retry that download at most three total attempts,
  with bounded waits and per-attempt receipts. Other failures shall not receive
  transport retries.
- **REQ-008** When downloaded bytes are available, the preparation harness shall
  verify their existing pinned SHA256 before installation. Digest mismatch shall
  fail immediately without retry or installation; installation failure shall not
  trigger download or installation retries.
- **REQ-009** The preparation harness shall durably record package identity, URL,
  attempt number, observed transport outcome and digest-verification outcome
  before a possible terminal failure, without substituting partial bytes for a
  verified archive.
- **REQ-010** The followup shall retain the90second full-check profile and all
  canonical gates. An unchanged full-canary retry may gather evidence, but an
  unexplained−9 shall remain an explicit unresolved observation rather than an
  invented defect attribution or authorization to alter its deadline.
- **REQ-011** The verification shall exercise controlled ownership transitions,
  timeout termination and transport/digest failures without unbounded load or
  signaling foreign processes, and shall retain reproducible receipts.
- **REQ-012** When the candidate is published for validation, all seven hosted
  workspace jobs shall pass against the same candidate source with no skipped,
  disabled or weakened checks before this followup is declared complete.

## §C Constraints and exclusions

No application-source edit is authorized. Changes are limited to CI wrappers,
browser fixtures, scientific-boundary test mechanics, dependency-download handling,
focused regression tests and this SPEC's artifacts. Product hashes must be measured
before and after implementation. No new runtime package is required.

### Out of Scope — Product and speculative remediation

- A sixth UI iteration, statistical changes, new heatmap features or publication figures.
- Changing the90second full-check deadline, installed resource limits or canonical gates.
- Treating the original reset as proven exit124, or attributing−9 to load without evidence.
- Ignoring a live unknown process, weakening nonce proof, or retrying hash/install failures.
- Unrelated refactoring, pin changes, broad retry policies or masking failed CI jobs.

## §D Traceability and completion

All requirements map to binary scenarios in acceptance.md. Completion requires
independent plan approval before implementation, focused regression evidence,
independent code review and a fresh all-seven hosted result. A remaining unexplained
full-job failure blocks completion even when its cause is outside the permitted fix.

## HISTORY

| Version | Date | Change |
|---|---|---|
|0.1.0|2026-10-30|Separate bounded CI-harness followup for frozen R5 product; initial draft.|

