# Acceptance — SPEC-COMPACTUI-001 v0.1.1

- **AC-001 — Initial desktop Enrich.** Given settled empty-selection review state,
  closed popups, matched sidebar state and bodyScrollTop0 at1440×900 and1280×720,
  When the candidate renders, Then the Run Enrichment action is visible and fully
  inside each viewport, the annotation/keytype/ontology/species fields use at
  least two nonoverlapping visual columns, and all existing configuration/review
  content remains present in its logical workflow. A floating/overlaid Run,
  hidden content or duplicate control does not satisfy this criterion.
  Covers REQ-001 and REQ-003.
- **AC-002 — Populated density with content preserved.** Given the retained
  built-in demo state deg_mouse1 previewed and selected, GO/SYMBOL/BP/human,
  empty default cutoff, adjusted rule<0.05,31 kept/submitted/distinct genes,
 48 excluded and review digest34ff201542ea without commit/Run, When the same
  candidate state renders at each desktop size, Then primary span is at most
 0.75 times that viewport's unrounded1044.34375px baseline, and the complete
  normalized review/help text, input values, eligibility and typography match.
  Primary span is configuration-card top through Run bottom; total document
  height is excluded. Covers REQ-002 and REQ-007.
- **AC-003 — Other workflow menus.** Given before/after captures for Enrichment
  figures, Upload files, Cluster, Cluster figures, Manage Files and Save/Load
  with matching data/visible controls, When a panel is modified, Then a measured
  unused vertical gap decreases or field width utilization/group alignment
  improves, with readable controls, help and results retained. An unchanged
  already compact panel has an explicit measured rationale. Useful existing
  two/three/four-column groups remain available. Covers REQ-004.
- **AC-004 — Responsive fit.** Given the seven menus at375×667,768×1024,
 1024×768 and both desktop sizes, When initial/populated controls, long selected
  values, Selectize popups and conditional groups are displayed, Then primary
  fields stack in one column at375px, fit their actual containers at other sizes
  and produce no document horizontal overflow, overlap or clipped labels/values.
  Accessible inner scrolling for genuinely wide tables/figures is permitted.
  Covers REQ-003 and REQ-005.
- **AC-005 — Typography and keyboard.** Given matched baseline control metrics,
  When keyboard focus moves through the compact forms and the viewport changes,
  Then existing font sizes and minimum control hit areas are not reduced,
  focus remains visible, tab/reading order follows the visual workflow and
  selected values remain reachable and retained without a mouse.
  Covers REQ-006.
- **AC-006 — Binding and review contracts.** Given matched baseline/candidate
  module controls and empty, previewed, committed and validation-message states,
  When values and dynamic parameter choices change, Then identifiers,
  multiplicities, choices/defaults, labels/help/warnings, preview-versus-commit
  state and Run eligibility match their prior contracts, with no duplicate
  module control IDs or new bindings. No content is hidden to meet a metric.
  Covers REQ-007.
- **AC-007 — Working workflow after reflow.** Given the actual installed
  candidate and established local cached/fixture worker, When a user uploads,
  previews/commits, selects, runs, views and saves/restores a test result through
  the real UI, Then the completed result and committed input snapshot are
  preserved, navigation/resizing retain selections and stored values/NA/order
  match the fixture. The controlled worker is explicitly attributed rather
  than claimed as a new network enrichment or scientific validation.
  Covers REQ-006, REQ-007 and REQ-008.
- **AC-008 — Scientific views remain readable and exact.** Given the existing
  scientific/heatmap fixtures, When relevant views and camera/saved exports are
  checked at desktop and narrow sizes, Then values/IDs/order/NA and all-row stored
  results match baseline, the accepted18px/14px cluster geometry and400-row
  navigation remain within the unchanged installed2000-row policy, the selected
  logical-window PNG stays complete/bounded and no table/plot is made illegible
  or clipped by compact-form styling. Covers REQ-008.
- **AC-009 — Presentation-only source boundary.** Given frozen source/function
  manifests at7beaa52 and the approved file list, When the diff is independently
  checked, Then changes are limited to static UI declarations, scoped CSS and
  owned regression/evidence artifacts; every other function body and public
  signature, scientific renderer, dependency/policy/CI configuration, app wiring, prior
  completed SPEC and immutable manuscript asset is unchanged. Home, sidebar,
  job and dialog behavior retains its existing contract. The candidate CSS begins
  with the entire unchanged baseline file; original-prefix MD5
  3dc7da1312126fb3a028db075e1c0e60 and all workspace-primitive source/tests remain
  unchanged. Only the reviewed custom.css full-digest literal may change in
  tests/e2e/design-system.spec.ts, with its other pins/assertions/behavior exact.
  Covers REQ-009.
- **AC-010 — Evidence and unchanged gates.** Given baseline and freshly installed
  candidate identities, When scoped local checks, independent review and
  published-source hosted quality gates finish, Then actual commands/results,
  screenshot pairs, geometry, binding/source guards and runtime/CSS identity
  establish all criteria without relaxed assertions/policies. The authorized
  one-literal CSS digest refresh follows independent preservation/identity review
  and exact installed/source/served CSS agreement, with old/new hashes retained.
  No local full
  R suite/check/coverage is run and no deployment claim precedes observed
  publication. Covers REQ-010.

## Definition of done and evidence

All ten criteria are required. Capture the actual baseline/candidate tree,
installed package/RDB and served CSS identity, browser/font/viewport/state,
commands plus output, before/after measurements and independent verdicts.
Use unrounded metrics for thresholds and retain original failed checks.

Tests must operate on real rendered controls and workflow outcomes, not mirror
an implementation class or pretend that a screenshot alone proves state/data.
Keep original transient/open-popup baseline captures distinguishable from settled
comparison states. Browser errors, cleanup, gaps and residual risk are explicit.
A new scientific inference, typography reduction or altered backend expectation
does not count as a density improvement.
