# Acceptance checklist — SPEC-HMAPPORT-001 v0.1.0

Canonical Tier S Given/When/Then scenarios AC-001 through AC-003 are inline in
spec.md §3. This requested companion adds no new acceptance contract.

- AC-001: native ASCII baseline/candidate evidence; exactly three substitutions;
  CRLF and all other source bytes retained.
- AC-002: fresh namespace versus immutable installed R5; identical Unicode bytes
  for labels/titles/UI choices and unchanged data, coordinates, NA/hover;
  four scientific goldens pass.
- AC-003: focused and portability checks, unchanged CI/QA digests, independent
  approval and fresh all-seven hosted PASS on one candidate.

Retain command/output, tree/SHA attribution and explicit gaps. No local full
suite/check/coverage and no skipped or weakened hosted gates.
