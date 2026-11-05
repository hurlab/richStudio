# Amendment 013 — Register SPEC-WS-013 (workspace UI/UX restructure)

**Status: planning registration, draft.** No implementation is authorized by this record; SPEC-WS-013 is dispatched only through the normal dependency/lock rules after independent plan audit.

## Owner decision (2026-11-03)

1. A workspace UI/UX restructure leaf, SPEC-WS-013, is added from the hands-on review `docs/quality/ux-review-2026-11-03.md` (integration tree `081ef06`).
2. It is scheduled **before** SPEC-WS-009 and SPEC-WS-010, so both build on the new layout.

Owner defaults applied 2026-11-04 (the owner may override; recorded as OD-1..OD-8 inside SPEC-WS-013): 008 merges first and 013 milestone M8 reshapes its UI (OD-1); no interim production deploys (OD-2); the Data step is hosted on the Manage Files route renamed "Data" (OD-3); the user picks the gene column when none is recognized (OD-4); no species inference, last species remembered per session (OD-5); cluster heatmap top 30 with show-all (OD-6); the non-developer check is manual, owner-run and non-blocking, carried to umbrella AC-012 (OD-7); not-recorded fields collapse into one visible disclosure (OD-8).

## Changes

1. `docs/specs/SPEC-WS-013.md`: new leaf, status draft.
2. `docs/specs/SPEC-WORKSPACE-001/dispatch.json`: new node `SPEC-WS-013` (depends on 003, 004, 006, 007, 008; 36 existing, 14 new and 4 prerequisite-created targets, revised 2026-11-04 to add the reconciled-line guard tests and the M0 baseline fixtures; priority High; lane implementation). `depends_on` of `SPEC-WS-009` and `SPEC-WS-010` gains `SPEC-WS-013` at the end; `SPEC-WS-011` gains it after `SPEC-WS-012`. No other node, field or ordering changes.
3. `docs/specs/SPEC-WS-009.md`, `SPEC-WS-010.md`, `SPEC-WS-011.md`: the "Logical prerequisites" line gains SPEC-WS-013, `updated` is 2026-11-03, one HISTORY line. No REQ or AC text changes.
4. `docs/specs/SPEC-WORKSPACE-001/plan.md`: one contracts-table row, four graph edges and a dated registration section. `spec.md`: completion-contract leaf count and one HISTORY line.

## Boundaries kept

Statistics, engines, background semantics, job lifecycle rules, run records, the project format and route identifiers are unchanged by SPEC-WS-013. Figure controls/export stay with 009, clustering chooser/comparison with 010, the release audit and usability study with 011, the legacy bridge with 012. SPEC-WS-013 shares targets with 002-010 and 012; locks serialize writers exactly as for every other leaf.
