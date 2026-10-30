# Verification checklist — SPEC-DEPLOYRECOVERY-001 v0.1.0

Tier S canonical Given–When–Then criteria are inline in spec.md §3. This requested
sibling does not add criteria or implementation obligations.

- AC-001: restart/health-triggered failed publication restores and verifies old service.
- AC-002: every recovery-stage failure is explicit, bounded and never false-success.
- AC-003: the actual live-switch boundary and detected foreign targets are safe.
- AC-004: original ordinary failure or catchable interruption status survives cleanup.
- AC-005: no failure recovery before publication or on successful publication.
- AC-006: inactive service, bad HTTP and error-page controls cannot pass verification.
- AC-007: exact preflight prefix, pins and protected application/CI/scientific bytes remain.
- AC-008: independent approval and remote script/wrapper pins precede re-enabling.

No production fault, sudo command or real service mutation belongs in these tests.
Real post-deployment confirmation remains a distinct observed operational record.
