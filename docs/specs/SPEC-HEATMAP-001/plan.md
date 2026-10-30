# Implementation plan — SPEC-HEATMAP-001

## §A Context and baseline

Integration worktree:
`/home/juhur/.moai/worktrees/projects/richStudio/heatmap-legibility`,
branch`WT-heatmap-legibility`, initial HEAD
`dab528d64d65d68f305f11f02c5909e7abf94949`. The orchestrator created a fresh
MoAI worktree, advanced it to remote-default`c422c77`, then fast-forwarded the
already deployed scientific dependency branch. The primary checkout is untouched.

Read source evidence: R/clus_visualize_tab.R uses an800px summary output;
R/cluster_hmap.R supplies all full labels and already includes full terms and
missing/zero explanations in hover text. The shared cluster-choice helper also
serves individual-cluster selection, so globally shortening its names would change
an unrelated UI contract. Current summary source has no direct render-row
admission check; the installed policy value alone does not establish enforcement.

Supplied production evidence under the scientific-heatmap-adoption worktree's
`.moai/reports/lsp-sync-cleanup/post-deploy-20261030/` captures the141/139 row
crowding. It is prior evidence, not a fresh baseline from this SPEC agent.
QA must reproduce the baseline and retain the source/runtime attribution.

The primary project product/structure/tech context files are absent, mechanically
checked during planning. Existing DESCRIPTION, versioned SPECs, installed resource
policy and application source supply available context. Primary quality.yaml
selects TDD; interview.decision_gate is off, so no decision index is created.

## §B UX and resource decisions

1. Normal results up to 400 rows use the full matrix with 18px minimum row pitch,
   a compact minimum useful plot height, and a native scroll region bounded by
   min(720px,70vh). Use readable fixed-size text rather than shrinking text to fit.
2. Results above 400 rows retain every trace/data row but expose an explicitly
   identified row window of at most 400. Use existing Plotly category-axis
   visibility and a standard keyboard-operable row-window control; avoid custom
   virtual-scroll machinery or a new client-side dataset copy. Initial window
   follows the existing displayed top-to-bottom row order, not a new scientific
   sort. Number logical positions over that full rendered order before slicing.
   Ascending category IDs 1..2000 render top-to-bottom2000..1: native dropdown
   windows "Rows 1–400 of 2000", "Rows 401–800 of 2000", through "Rows 1601–2000
   of 2000" display respectively2000..1601,1600..1201 and400..1. Do not reorder
   categoryarray or source data to make these positions match raw IDs. For401rows
   the second window contains only logical row401.
3. The physical plot and exported current-view image stay within 8192pixels per
   dimension. At400×18px plus fixed label/title margins this leaves headroom for
   a bounded plot; do not allocate 2000×22px. Controls expose all admitted rows.
4. Shorten only plot-axis display labels; keep the full names generated for
   individual choices unchanged. Use a `Cluster <original ID>` prefix when the
   original ID fits. Otherwise use `Display row <r>` from its one-based position
   in the complete rendered order, computed once before windowing. This distinct
   prefix namespace cannot collide with normal "Cluster ..." labels; the row
   position supplies uniqueness without hashes, dependencies or source-ID edits.
   Show a notice when aliases are used, and include both alias and full original
   ID in each aliased cell hover so the mapping is available on demand. Full
   original ID/term remain in hover, chooser and trace keys. Do not reject
   otherwise accepted 101character IDs merely to satisfy a display-width bound.
   Use safe Unicode-aware display-width shortening for term text, bound the
   label column at 240px, and contain narrow-screen horizontal figure overflow.
5. State the row range/total visibly and in windowed exports; retain full
   tabular/session exports. Camera export captures the entire logical row window (the complete matrix for
   at most 400 rows), independent of the native scroll position; it does not crop
   to the currently visible CSS scroll viewport. Windowed exports must not be
   labeled as full-result figures. Reuse existing export controls.
6. Admit row count through the installed shared resource helper before expensive
   figure preparation. The current 2000/2001boundary is exercised without changing
   policy values. The rejection is intentional enforcement for the previously
   unguarded summary path, not evidence it already existed.
7. The window control is native Shiny selectInput(selectize=FALSE), with the
   exact label "Cluster row window". Hide it for at most 400 rows/empty states;
   reset to the first logical window on result changes. The figure scroll wrapper
   is focusable (tabindex=0), has role=region and the exact accessible name
   "Cluster heatmap", with a visible keyboard-focus indicator.
8. Re-anchor the existing NA/zero explanatory annotation using a fixed pixel
   offset and adequate fixed margins rather than the current y=-0.18 paper
   offset, which grows with the drawable plot height. The whole note must remain
   inside both live SVG/plot bounds and the actual exported image. Retain its
   existing scientific wording and 11px text; wrapping is allowed without changing
   meaning. The 14px minimum belongs to row-axis ticks only.
9. Use scoped container styling and existing native Shiny/Plotly controls. Prefer
   local/scoped styles over touching the globally frozen design stylesheet.
   Preserve module IDs and avoid new dependencies or native R pipes.

## §C Target files and ownership

| Target | Intended minimal change |
|---|---|
|R/cluster_hmap.R|Presentation sizing/compact tick labels and bounded default window; preserve all source/trace values and hover semantics; enforce resource admission.|
|R/clus_visualize_tab.R|Bounded, named, focusable figure region; reactive height/window controls and reset behavior; explicit current-view export scope.|
|tests/testthat/test-heatmap-legibility.R|New meaningful layout, boundary, Unicode/security-display and data-preservation regressions.|
|tests/testthat/test-cluster-heatmap-scientific.R|Only necessary assertions that existing scientific/boundary behavior is preserved; do not weaken them.|
|tests/e2e/heatmap-legibility.spec.ts|Targeted actual installed-browser regression for 141/366 rows, policy boundary and desktop/mobile navigation/export.|
|docs/specs/SPEC-HEATMAP-001/|Plan artifacts and phase-owned evidence/status changes.|
|PROJECT_HANDOFF.md, PROJECT_LOG.md|Orchestrator records decisions, dispatch, measured results and remaining gaps.|

A small dedicated scoped stylesheet/client hook may be used only when the existing
widget cannot honor sizing/reset without it; add the exact target to the run
evidence before editing. No change to global custom.css, dependency manifests or
CI gates is planned. A necessary existing frozen-source change requires explicit
source-equivalence review and manifest refresh; never bypass a guard.

## §D Dependency graph and dispatch

One implementation milestone is sufficient; source/UI changes conflict and must
not be split between concurrent writers.

`SPEC draft → independent Reviewer plan approval + QA baseline + Security baseline
→ Implementer (R/UI + focused regressions) → independent Reviewer code approval
→ QA targeted R/Playwright + Security delta → source commit/push → full hosted CI
→ documentation sync`

Reviewer, QA and Security roles retain context across gates. Concurrency follows
available slots; idle persistent roles remain available. Implementer owns only the
dispatched source/test files and must not revert another actor's changes. The
orchestrator never implements and reviews the same change.

## §E Pre-flight and validation

- Record exact source HEAD/status, installed candidate path, R/dependency versions
  and baseline screenshot dimensions before implementation measurements.
- Use1,2,141,366,400,401 and the installed policy limit/limit-plus-one cases.
  Include empty selections, all-NA rows, raw zero, duplicate representative names,
  noncontiguous IDs, two accepted 101character IDs differing only at the final
  character, long Unicode/HTML-like names and multiple datasets. Check the long-ID
  aliases remain distinct and stable across windows with full original IDs intact.
- Establish failing large-label geometry before implementation; compare canonical
  source/trace values and NA masks rather than expecting only shape equality.
- Exercise actual installed UI at 1280×720 and 375×667. Measure row pitch, tick font,
  bounding boxes, scroll dimensions, document overflow and first/last row access.
  Assert current row range and result selection after a stable rendered state.
  For the 2000 row fixture verify exact top-to-bottom ID sets for the first, next
  and last windows and keyboard access through the named native dropdown.
  Verify the NA/zero annotation bounding box stays fully inside the plot at141,
  366and400visible rows and in a small plot, and inspect its exported bounds.
- Test export using the actual camera/download action and inspect the artifact's
  dimension, row-range statement and data selection. Retest save/load and all-row
  result export preservation where those existing paths are exercised.
- Run scoped tests locally. Full suite/check/coverage belong in CI under AGENTS;
  apply the unchanged canonical policy and actual zero-diagnostic sync runner.
  Prior CI253 tests/3007 assertions and 58 journeys are historical comparison evidence,
  not a freshly executed baseline for this worktree.
- Record command plus bounded output, source/runtime attribution, gaps and residual
  risk. Independent review must verify no scientific reordering/value mutation,
  new executable-label sink or silent row omission.

## §F Milestones

### High — Establish the interaction and invariants

Add the failing readable-row/resource-boundary/browser regressions and exact
scientific trace comparisons. Implement the normal scroll view and bounded large
window together, with compact safe axis labels, keyboard/focus support and honest
export scope. Reuse the installed policy and existing UI conventions.

### High — Verify and close

Review the combined diff, run targeted installed R/browser/security checks, then
push for all required hosted jobs and actual LSP sync. Fix confirmed regressions
without weakening assertions or gates. Record final evidence and lifecycle changes
through their owning roles.

## §G Rollback

Revert only this SPEC's source/UI commit(s), preserving the deployed scientific
baseline, data files, saved sessions, policy limits and independently authored
work. No state/data migration is introduced. Re-run affected checks after rollback.
Deployment remains a separately verified step; do not remove an unintegrated
worktree that holds the only source copy.

## §H Cross-references

- spec.md REQ-001–REQ-012; acceptance.md AC-001–AC-010.
- docs/specs/SPEC-WORKSPACE-001: visualization/resource/evidence constraints.
- docs/quality/scientific-clustering-followup-20261029.md: prior numerical,
  CI and deployment evidence.
- inst/config/workspace-resources.json: installed resource-policy source.

