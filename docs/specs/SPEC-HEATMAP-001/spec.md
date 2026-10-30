---
id: SPEC-HEATMAP-001
title: "Readable cluster summary heatmaps without changing results"
version: "0.1.1"
status: draft
created: 2026-10-30
updated: 2026-10-30
author: manager-spec
priority: P1
phase: "v0.1.7 target"
module: "R/"
lifecycle: spec-anchored
tags: "heatmap, readability, plotly, accessibility"
tier: M
---

# SPEC-HEATMAP-001

## §A Context and outcome

The cluster summary view puts every full representative-term label into a fixed
800px plot. Supplied production screenshots show crowded labels for 141/139 clusters.
Current source inspection confirms that fixed height and the complete tick-label
list. The user authorized planning, independent review and implementation through
Hur Harness without another routine approval pause.

The outcome is readable exploration of every admitted cluster with bounded display
allocation. Display navigation and shorter axis labels must leave the scientific
result unchanged. This is a Tier M, single-milestone UI fix with coordinated R,
browser and regression-test changes. The target is the next patch after package
version0.1.6; a version bump is not part of this SPEC.

## §B Requirements

- **REQ-001** The summary view shall preserve every admitted cluster, original
  cluster IDs and display ordering, dataset coordinates, exact underlying
  probabilities, transformed values, missing masks, zero-display semantics,
  representative names and method-specific statistical policy.
- **REQ-002** When a nonempty result contains at most 400 clusters, the summary
  view shall expose the complete matrix in a scrollable figure with at least 18 CSS
  pixels per cluster row and row-axis tick text at least 14 CSS pixels high,
  without adjacent row-label overlap. The existing explanatory annotation may
  retain its 11px font; the row-axis font minimum does not apply to that note.
- **REQ-003** While a heatmap is displayed, its scroll viewport shall be no taller
  than 720 CSS pixels or 70% of the browser viewport height, whichever is smaller,
  and its physical plot dimensions shall not exceed 8192 CSS pixels on either axis.
  The page shall not acquire horizontal overflow at 1280×720 or 375×667; any
  necessary figure overflow shall remain inside the labeled figure region.
- **REQ-004** When a result exceeds 400 clusters but remains within the installed
  render-row policy, the view shall provide a native dropdown named
  "Cluster row window" for consecutive, nonoverlapping windows of at most 400 logical rows.
  Logical rows shall count from the top of the existing rendered order, without
  changing that order or trace membership. Every cluster shall remain reachable
  with the same minimum row spacing and14px row-axis text, and the view shall
  state its displayed row range and total. The dropdown shall be hidden for results of at most 400 rows.
- **REQ-005** The axis labels shall use an unambiguous cluster-ID prefix and a
  compact single-line representative name within a label column no wider than
  240 CSS pixels, without covering the matrix. When an original ID cannot fit,
  the view shall use the unique display-only alias `Display row <r>`, where r is
  its one-based position in the complete top-to-bottom rendered order. Normal
  labels shall use the distinct `Cluster <original ID>` prefix. Aliases shall
  remain stable across windows, with a visible explanatory notice and alias-to-
  full-ID mapping in cell hover. Full original IDs and terms shall remain in
  hover, individual choices and trace coordinates; label width shall not cause
  an otherwise accepted ID to be rejected or rewritten.
- **REQ-006** When users hover a cell, the view shall retain the complete original
  cluster ID, representative term and the existing statistic, missing-value and
  zero-floor explanations. The existing missing/zero explanatory note shall fit
  fully inside the rendered figure and exported image at every supported height;
  its position shall not move farther away in proportion to plot height.
  Untrusted labels shall remain inert display text, and shortening a display
  label shall not modify the original stored string.
- **REQ-007** When keyboard users focus the figure or row-window control, a
  visible focus indicator shall identify the target; the focusable figure region
  shall have the accessible name "Cluster heatmap" and the native dropdown shall
  have the name "Cluster row window". Keyboard operation shall reach the first
  and last admitted cluster without a mouse. View navigation shall not rerun clustering or change result membership.
- **REQ-008** When the selected result changes, the view shall reset its row
  window and scroll position to the first displayed rows of the new result,
  maintain the selected result, and avoid stale limits or leftover event handlers.
  Changing a statistic or aggregation shall retain existing calculation semantics.
- **REQ-009** When no usable result is selected, the view shall retain an honest
  empty state without allocating a large plot or showing invalid navigation.
  Small results shall remain readable in a compact figure instead of requiring
  the previous fixed800px content height.
- **REQ-010** When the current heatmap view is downloaded, the exported image
  shall preserve the displayed values, labels, missingness, explanatory annotation
  and logical row window, identify any partial row range and total, and remain within the 8192pixel dimension bound.
  Existing tabular and saved-session exports shall retain all result rows.
- **REQ-011** When a result exceeds the installed render-row policy, the view
  shall reject figure allocation with a clear resource-limit message before
  constructing an oversized plot; it shall not silently truncate clusters,
  report an invented successful empty result, or raise the policy limit.
- **REQ-012** The change shall preserve public interfaces, installed-package
  execution, current save/load compatibility and the project's unchanged
  verification policy, including zero total candidate LSP diagnostics.

## §C Constraints and exclusions

The approved policy currently admits2000render rows. Its installed value remains
authoritative;2001is the current policy-plus-one negative test, not a new limit.
The 400 row view window and 8192pixel display bound constrain presentation, not the
scientific result. All-cluster trace data and existing result/session exports stay
complete, including when only one row window is on screen. For original ascending
categories 1 through 2000, the preserved rendered order is 2000 down to 1: logical
rows 1–400 display IDs 2000–1601, rows 401–800 display 1600–1201, and rows 1601–2000
display 400–1. These row positions are presentation coordinates, never new
scientific cluster IDs.

### Out of Scope — Scientific and workflow changes

- Changing clustering algorithms, thresholds, filtering, gene universes, rankings,
  significance corrections, result tables or numerical display transformations.
- Replacing the plotting library, adding dependencies, changing public APIs or
  raising the declared R 4.0 minimum.
- Redesigning other application routes, repairing unrelated workspace-header state,
  altering formal release governance or silently deploying an unverified candidate.
- Adding dataset pagination or top-N filtering that discards clusters, or promising
  a full-result image when the camera export contains only a labeled row window.
- Revising the separately reviewed manuscript-figure bundle.

## §D Traceability and acceptance

The binary acceptance scenarios are in acceptance.md. Every requirement is mapped
there. Implementation touch points, dependency order and rollback are in plan.md.
No acceptance scenario is marked passed by authoring this document.

## HISTORY

| Version | Date | Author | Change |
|---|---|---|---|
|0.1.0|2026-10-30|manager-spec|Initial Tier M draft for the user-authorized readable, bounded cluster summary view.|
|0.1.1|2026-10-30|manager-spec|Plan review r2: top-to-bottom window numbering, long-ID display aliases, stable accessible controls and bounded explanatory-note placement.|

