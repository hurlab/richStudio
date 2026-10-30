# Plan — SPEC-HMAPCI-001 v0.1.0

## §A Context and decisions

High priority: preserve ownership safety first. Startup proof retry is a bounded
re-observation of the same candidate identity, not a relaxation of proof.
Use at most three fresh observations, no more than500ms between observations
and at most2seconds total additional proof wait. Each observation reads fresh
PID/start identity and nonce; never reuse a nonce from a different identity.
Persistent unknown/permission failure must fail and retain evidence, never signal.

High priority: preserve native scientific test behavior. Scroll the actual
horizontal region for each target cell, then measure the intersection of cell,
clipper and physical viewport. Sample RGBA from a new screenshot at that cell's
fresh position. Keep the existing four semantic cell expectations in both views.

Medium priority: increase only the serve watchdog from900to1800seconds, leaving
the job's finite90minute deadline and all individual test timeouts unchanged.
Record the wrapper's actual terminal status before its failure can exit the shell.
Use a controlled short canary to exercise the same termination/reporting path;
do not wait1800seconds locally or introduce a production timeout override.

Medium priority: transport retry is per archive, three attempts maximum.
Use the standard library and existing pins. Retry interrupted network/TLS reads,
connection resets and connection timeout only; do not retry HTTP errors,
certificate-validation errors, malformed requests, digest mismatch or install
failure. Bound each existing120second transport attempt and waits to at most
two seconds between attempts. Write attempt receipts incrementally, including
failure, before moving to verification/installation. Existing artifact upload
must retain receipts on failure.

## §B Known issues and evidence gaps

Read .moai/reports/heatmap-legibility/qa/hosted-41057333122-triage.md.
Read .moai/reports/heatmap-legibility/ci-triage.md and
.moai/reports/heatmap-legibility/ci-browser-lifecycle-triage.md, both verified
present and read during authorship. The lifecycle guard is in job-lifecycle.spec.ts,
not fixtures.ts; fix the verified guard rather than inventing a fixture defect.
Original−9cause and reset terminal status are unobserved; changes must
not claim to establish either retrospectively. All-eight new-case hosted PASS
does not replace all-seven job completion.

## §C Targets and ownership

| Target | Permitted change |
|---|---|
|scripts/test-workspace.sh|Finite1800second serve lifetime and durable terminal receipt; preserve full-check90seconds and cleanup.|
|tests/e2e/job-lifecycle.spec.ts|Bounded fresh ownership proof revalidation at the verified guard with unchanged proof and no-signal invariants.|
|tests/e2e/fixtures.ts|Only shared proof support demonstrated necessary by the existing lifecycle guard; no unrelated fixture changes.|
|tests/e2e/scientific-heatmaps.spec.ts|Per-cell native scrolling, fresh visible hover coordinates and RGBA sampling only.|
|.github/workflows/workspace-quality.yml|Bounded transport-only retry, unchanged SHA256/pins, durable failure receipts.|
|scripts/test-ci-harness-regressions.py|Focused controlled regression harness, if needed after checking existing patterns; standard library, no runtime dependency.|
|tests/e2e/ci-harness-regressions.spec.ts|Focused ownership/viewport canaries only if existing tests cannot cover them simply.|
|docs/specs/SPEC-HMAPCI-001/|SPEC owner bodies; Implementer E2/E3; Docs E4/status at close.|

No root handoff/log edits by SPEC owner. Root owns those. No product source,
lockfiles or dependency manifests are permitted. Run source changes in the
root-coordinated isolated integration context after independent plan approval.
Do not revert other agents' edits.

## §D Milestone and dependency order

1. **High — Independent plan review and baseline capture.** Resolve/read triage
   reports; capture branch/SHA and frozen product hashes; reproduce focused
   existing failures/canaries and write failing regressions with cleanup bounds.
2. **High — Ownership and viewport corrections.** Implement minimal fixes;
   prove nonce transitions and unchanged full scientific expectations.
3. **Medium — Watchdog receipts and transport handling.** Implement bounded
   changes with short controlled terminal/transport canaries.
4. **High — Independent review and hosted closure.** Run targeted checks,
   unchanged canonical diagnostics and frozen hash comparison; push through root
   and require all seven hosted jobs on the same SHA. No local full suite.

## §E Self-verification

Trace every requirement to acceptance.md; keep original proof and scientific
assertions. Record actual terminal codes including timeout124, real owned cleanup,
and failure receipts. Inspect successful and failing artifacts. Security checks
must establish no signal reached foreign processes and no unverified archive
reached installation. Attribute every measurement to its tree/SHA.

## §F Risks and rollback

A PID can be reused during revalidation: compare start identity every observation
and fail on mismatch. Scrolling can invalidate coordinates: recompute per cell,
including screenshot patch bounds. Shell exit propagation can suppress receipts:
persist receipt before returning captured nonzero status. Broad exception catches
can accidentally retry digest/install failures: keep transport phase separate.

Rollback only this followup's explicit CI/test paths; preserve R5 product and
other sessions' edits. No state migration or pin rollback is involved.

