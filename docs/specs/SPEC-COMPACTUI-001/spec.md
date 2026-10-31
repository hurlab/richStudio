---
id: SPEC-COMPACTUI-001
title: "Compact responsive analysis forms without changing analysis behavior"
version: "0.1.2"
status: in-progress
created: 2026-10-30
updated: 2026-10-30
author: manager-spec
priority: P1
phase: "v0.1.7 target"
module: "R/*_tab.R, inst/application/www/custom.css"
lifecycle: spec-anchored
tags: "layout, forms, responsive, density"
tier: M
---

# SPEC-COMPACTUI-001

## §A Outcome and measured baseline

The user requests less wasted vertical space on Enrich and the other workflow
menus, with related controls arranged in two or more columns where useful.
This is a presentation correction using the existing Shiny dashboard and theme.

Planning tree: isolated `compact-workspace-layout`, branch
`WT-compact-workspace-layout`, baseline
`7beaa52b3081721689586211f2d5fe530cc810ba`.
An executed Git comparison confirms that its R and application CSS bytes equal
the deployed application source4bc65b3. QA measured the actual public application;
these are QA observations, not browser runs performed by the SPEC author.

| Matched state | Viewport | Observed baseline |
|---|---|---|
| Settled initial Enrich, empty-selection review banner visible |1440×900|Run bottom1243.03px;343.03px below the viewport.|
| Same settled initial state |1280×720|Run bottom1243.03px;523.03px below the viewport.|
| Built-in DEG demo, deg_mouse1 previewed and selected for Run; no commit or Run |Both desktop viewports|Enrich card top545.078125px; Run bottom1589.421875px; primary span1044.34375px.|

The populated comparison retains GO/SYMBOL/BP/human, an empty default cutoff,
adjusted p-value rule<0.05,31 kept/submitted/distinct genes and48 excluded rows;
its review digest is34ff201542ea. It is a layout fixture, not a new inference.
The primary span is the Enrich configuration card's top through Run's bottom.
Total page height includes real previews/results and is not the density target.
QA retains corrected settled/closed-dropdown screenshots and earlier transient
captures separately under `.moai/reports/layout-density/baseline/`.

Scope covers Enrich, Enrichment figures, Upload files for clustering, Cluster,
Cluster figures, Manage Files and Save/Load. Existing compact groups may remain;
a route being in scope does not require an unnecessary structural rewrite.

## §B Requirements

- **REQ-001** While the settled initial Enrich view is at body scroll position0,
  the interface shall display the complete Run Enrichment action inside both
  the1440×900 and1280×720 viewports, with configuration and review content retained.
- **REQ-002** When the matched populated Enrich state is displayed, the interface
  shall reduce the primary configuration span by at least25% at each desktop
  viewport against its retained baseline, without omitting review/help content.
- **REQ-003** While the desktop Enrich form is displayed, its annotation source,
  keytype, ontology and species controls shall occupy at least two nonoverlapping
  visual columns. Other related field groups shall use available width where
  useful and retain existing useful two-, three- or four-column groups.
- **REQ-004** The seven workflow menus shall use consistent compact form/card
  spacing and aligned controls, with measured improvements in modified panels
  and readable existing compact panels retained.
- **REQ-005** When available width changes, the interface shall adapt its primary
  field groups to readable single-column flow at375×667 and remain usable at
 768×1024,1024×768 and both desktop sizes, without document horizontal overflow,
  overlapping controls, clipped labels or inaccessible selected values.
- **REQ-006** The interface shall retain control typography and minimum hit areas,
  visible keyboard focus and operative keyboard paths, with reading/tab order
  following the visible workflow. Navigation and resizing shall retain selections.
- **REQ-007** The interface shall retain every existing form binding, default,
  label, help message, validation/review disclosure, preview-versus-commit state
  and Run eligibility. It shall not duplicate module controls or conceal critical
  content to meet a density measurement.
- **REQ-008** The interface shall retain scientific values, IDs, order, missingness
  and export semantics, readable tables/plots and the accepted cluster heatmap
  behavior:18px row pitch,14px labels,400-row windows through the installed
 2000-row policy, full selected-window PNGs and complete stored results.
- **REQ-009** The correction shall remain confined to the approved presentation
  surfaces, preserving server/computation bodies, public signatures, dependencies,
  resource policies and the existing Home/navigation/job/dialog behavior.
- **REQ-010** Before completion, the correction shall have source-attributed,
  installed-candidate before/after evidence, independent review, meaningful
  workflow/layout regression checks, scoped local verification and exact-source
  server preflight. GitHub CI is not a verification or deployment prerequisite.

## §C Constraints and exclusions

Use the existing theme and native Shiny/dashboard capabilities. Preserve the
existing base font sizes and control minimums; typography reduction, hidden
warnings, floating Run overlays or cloned desktop/mobile controls are not
substitutes for compact layout. A results section may require ordinary vertical
scrolling; wide tables/figures may retain their own accessible horizontal scroller.

Only static UI declarations in the seven tab files and scoped presentation CSS
are authorized production changes. Existing server/helper bodies, dynamic
calculation bodies, scientific renderers, app wiring and dependency metadata
remain unchanged. Preserve existing R newline conventions and ASCII-portable
new source text. Verification receipts must distinguish changed presentation
identity from preserved non-UI behavior; no unlisted production file is authorized.

Compact CSS shall be appended after the complete existing stylesheet, preserving
all baseline CSS bytes and the original prefix MD5
`3dc7da1312126fb3a028db075e1c0e60`. Existing workspace primitive rules, computed
typography/hit-area contracts and assertions remain unchanged. The sole
existing-test exception is the reviewed
refresh of the exact full-CSS digest literal in tests/e2e/design-system.spec.ts;
all its other pins, assertions and behavior remain unchanged. The refresh requires
independent candidate identity/preservation proof, not a relaxed expected hash.

### Out of Scope — New behavior or visual redesign

- New analysis methods, statistical changes, inference reruns or default changes.
- New frameworks, packages, density modes, onboarding features or navigation redesign.
- Hiding help/review state, replacing complete labels with inaccessible truncation,
  shrinking scientific plots or changing heatmap calculations to save space.
- Live CSS injection, unverified production replacement, real failure injection,
  local full R suite/check/coverage or weakened local assertions and preservation
  or resource guards.
- Requesting, running, reviewing or awaiting GitHub CI for this work.
- Rewriting prior completed SPECs, deployment tools or manuscript deliverables.

## §D Traceability and completion

REQ-001→AC-001; REQ-002→AC-002; REQ-003→AC-001/AC-004;
REQ-004→AC-003; REQ-005→AC-004; REQ-006→AC-005/AC-007;
REQ-007→AC-002/AC-006/AC-007; REQ-008→AC-007/AC-008;
REQ-009→AC-009; REQ-010→AC-010.

The existing independent plan approval remains recorded. The user's standing
override replaces the hosted-CI prerequisite with scoped local verification and
exact-candidate server preflight; this policy amendment requires no additional
plan/review/confirmation gate. The agent prepares and verifies the guarded
deployment script, and the owner executes it on the server. No GitHub CI receipt
or ci.ok guard is required; local/preflight/recovery/version/host guards remain.
Completion still requires actual evidence for the criteria. Failed or unobserved
local checks, including native-zoom execution gaps, retain their actual status;
server preflight does not turn them into passes. Screenshots alone or script
preparation do not establish that production has changed.

## HISTORY

| Version | Date | Change |
|---|---|---|
|0.1.0|2026-10-30|Initial measured compact-layout plan; no implementation.|
|0.1.1|2026-10-30|Authorize the necessary single full-CSS digest literal refresh; preserve append-only CSS, original-prefix and workspace-primitive guards; density targets unchanged.|
|0.1.2|2026-10-30|Apply the user's standing override: scoped local verification and exact-source server preflight replace GitHub CI; agent prepares the script and owner executes it; local gaps and all density/preservation targets remain honest and unchanged.|
