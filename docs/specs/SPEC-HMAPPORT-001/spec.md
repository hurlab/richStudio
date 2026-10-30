---
id: SPEC-HMAPPORT-001
title: "ASCII-portable source with identical heatmap Unicode output"
version: "0.1.0"
status: in-progress
created: 2026-10-30
updated: 2026-10-30
author: manager-spec
priority: P1
phase: "v0.1.7 target"
module: "R/"
lifecycle: spec-anchored
tags: "packaging, portability, heatmap"
tier: S
---

# SPEC-HMAPPORT-001

## §A Context and outcome

This is a separate Tier S packaging correction, not another UI iteration.
Integration HEAD08e9471 contains the previously frozen R5 product and CI followup.
The actual hosted41065823052 R-check log, lines55–63, reports the sole warning:
non-ASCII code in R/cluster_hmap.R and R/clus_visualize_tab.R. Source readback
locates three executable literals: decimal codepoint8230 once and8211 twice.
No scientific or layout defect is demonstrated by this warning. The original
full-canary termination cause and browser bootstrap failure remain unproven.

## §B Requirements

- **REQ-001** The correction shall remove the three non-ASCII executable literals
  through ASCII-only base-R runtime character construction, preserving their exact
  displayed Unicode bytes and each source file's CRLF convention.
- **REQ-002** The correction shall preserve axis labels, titles, row-window choices,
  label widths, layout, coordinates, original data, NA/zero semantics, hover,
  ordering, algorithms and public APIs without changing dependencies or limits.
- **REQ-003** The correction shall modify only those three representation
  expressions in the two identified R files; all CI-harness source, focused QA
  files, pins, thresholds and native browser assertions shall remain unchanged.
- **REQ-004** When the new candidate is verified, the native ASCII check shall
  report no non-ASCII executable code in those files, targeted equivalence checks
  shall pass against the immutable installed R5 namespace, and all seven unchanged
  hosted jobs shall pass before completion.

## §3 Inline acceptance criteria

- **AC-001** Given the original source and native ASCII checker, When baseline
  and candidate are inspected, Then the original three executable literals are
  evidenced and the candidate has zero, with CRLF retained and only three
  expression substitutions in the two authorized files.
- **AC-002** Given immutable installed R5 and a freshly loaded candidate namespace,
  When equivalent truncated-label and row-window cases are evaluated, Then axis
  labels, titles and UI choices have identical UTF-8 bytes; raw data, coordinates,
  NA/zero and full hover remain identical, and all four scientific goldens pass.
- **AC-003** Given the same new candidate source, When targeted tests, matrix
  portability checks, independent review and canonical hosted workflow finish,
  Then all required checks and seven jobs pass with unchanged CI/QA hashes,
  gates, pins and browser assertions; remaining failures block closure.

## §C Exclusions

### Out of Scope — Product changes and gate suppression

- A sixth UI iteration, ASCII substitute punctuation, label/layout/science changes.
- Unicode escape literals, ASCII-check suppression or threshold relaxation.
- CI-harness or native Zoom/bootstrap remediation and speculative timeout changes.
- Local full-suite, R CMD check or coverage runs; hosted CI owns those.

## §D Traceability

REQ-001 maps to AC-001/AC-002; REQ-002 to AC-002; REQ-003 to AC-001/AC-003;
REQ-004 to AC-001/AC-002/AC-003. The acceptance sibling is a short review checklist
requested by the orchestrator; these inline ACs are canonical for Tier S.

## HISTORY

| Version | Date | Change |
|---|---|---|
|0.1.0|2026-10-30|Initial narrow packaging-portability draft; three representation edits only.|
