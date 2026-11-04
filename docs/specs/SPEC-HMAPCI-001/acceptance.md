# Acceptance — SPEC-HMAPCI-001 v0.1.0

## §D Acceptance scenarios

- **AC-001 — Frozen product.** Given the recorded R5 source hashes and unchanged
  policies/pins, When the followup diff is reviewed, Then application hashes,
  scientific assertions, resource/gate thresholds and job membership are identical.
- **AC-002 — Recoverable proof transition.** Given an owned process whose nonce
  is initially missing, When fresh proof becomes valid within three observations
  and2seconds, Then startup succeeds only after matching PID/start identity and
  nonce are observed together, and real owned cleanup terminates and reaps it.
- **AC-003 — Unsafe proof transitions.** Given controlled dead, reused-PID,
  persistent foreign/unknown and permission-failure cases, When proof retries
  finish, Then they fail with durable identity/nonce receipts, never report
  readiness as ownership, and no unproven target receives a signal. A changed
  identity cannot borrow an earlier nonce.
- **AC-004 — Viewport and pixels.** Given the unchanged four semantic boundary
  cells in both1280×720 and375×667 views, When each is natively scrolled into view,
  Then fresh pointer and RGBA-patch coordinates fall within its visible clipped
  area and physical viewport; real hover proves the original full assertions and
  independently sampled RGBA retains all missing/value-color checks.
- **AC-005 — Finite server and terminal evidence.** Given a controlled short
  canary using the same serve termination/reporting path, When its finite deadline
  expires, Then a durable receipt records configured lifetime, owned identity and
  actual timeout exit124, cleanup reaps owned children and the wrapper propagates
  failure. A controlled normal exit records its actual distinct status. Production
  configuration remains finite1800seconds and full-check remains90seconds.
- **AC-006 — Transport recovery.** Given a controlled connection reset followed
  by a valid pinned archive, When the download runs, Then it succeeds within at
  most three total transport attempts, writes each attempt receipt and verifies
  SHA256 before exactly one installation. Three interrupted attempts fail with
  receipts and no installation.
- **AC-007 — Hard integrity failure.** Given completed bytes with wrong SHA256,
  an HTTP/certificate-validation failure, or a controlled installation failure,
  When the corresponding phase fails, Then it fails without retrying that
  nontransport failure; wrong bytes never install and installation is never
  retried. Failure receipts survive the terminal failure.
- **AC-008 — Unchanged full profile.** Given the original unobserved−9cause,
  When an unchanged full-canary retry or hosted full job is assessed, Then the
 90second check profile and gates are unchanged, actual observed exit evidence
  is retained and any unresolved failure remains explicit rather than waived.
- **AC-009 — Hosted closure.** Given a single published candidate SHA, When the
  canonical workspace workflow finishes, Then all seven jobs pass with no
  disabled/skipped/weakened checks, all original and new scientific cases remain
  enabled, receipts are available and independent review has approved the diff.

## §D.1 Traceability

| Requirement | Acceptance |
|---|---|
|REQ-001|AC-001, AC-004, AC-009|
|REQ-002|AC-005|
|REQ-003|AC-002, AC-003|
|REQ-004|AC-002, AC-003|
|REQ-005|AC-004|
|REQ-006|AC-004|
|REQ-007|AC-006, AC-007|
|REQ-008|AC-006, AC-007|
|REQ-009|AC-006, AC-007|
|REQ-010|AC-008|
|REQ-011|AC-002, AC-003, AC-005, AC-006, AC-007|
|REQ-012|AC-009|

## §D.2 Quality and definition of done

All scenarios are mandatory. Use bounded controlled subprocesses with guaranteed
cleanup; no background load and no local full suite. Run focused tests and syntax/
type checks appropriate to edited files, then let hosted CI perform the full suite.
Preserve installed canonical LSP/AST thresholds and gate configuration. Reports
must distinguish observed status from inference, identify tree/SHA, and list gaps.
An unresolved hosted full-job failure blocks closure; retrying unchanged is
evidence collection, not proof of correction.
