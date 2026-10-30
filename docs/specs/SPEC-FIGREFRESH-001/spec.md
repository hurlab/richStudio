---
id: SPEC-FIGREFRESH-001
title: "Versioned manuscript figure refresh from frozen canonical results"
version: "0.1.0"
status: draft
created: 2026-10-30
updated: 2026-10-30
author: manager-spec
priority: P1
phase: "v0.1.7 target"
module: ".moai/reports/"
lifecycle: spec-anchored
tags: "manuscript, figures, provenance, presentation"
tier: M
---

# SPEC-FIGREFRESH-001

## §A Approved scope and baseline

The user authorized finalization/deployment followed by manuscript figure refresh.
This Tier M deliverable reuses the approved scientific design and existing canonical
inference, changing presentation only. The bioinfo-pipeline-harmonizer skill's
provenance, fresh-destination, reproducibility and independent-review constraints
apply. The requested artifact is a manuscript figure bundle, not a slide deck.

Source bundle, read during planning:
`/home/juhur/.moai/worktrees/projects/richStudio/scientific-heatmap-adoption/.moai/reports/manuscript-figures-20261029`.
Its seven-row figure_source_manifest.csv identifies canonical differential.rds,
enrichment.rds and clustering.rds, associated panel tables and two figure scripts.
Its README states the previous aggregation implementation was57b5a159; the refresh
must use the validated current4bc65b3 library and separately record this provenance
change. Source equivalence is an assertion to verify, not assumed from versions.

## §B Requirements

- **REQ-001** The refresh shall create a new self-contained20261030 bundle only
  after verifying its destination is absent and nonoverlapping with the original.
  Every original file and its content hash shall remain unchanged.
- **REQ-002** The refresh shall reuse the exact canonical inference inputs,
  membership records, panel selection, ranking, thresholds, methods, missing masks,
  probabilities and summary statistics from the approved20261029 bundle without
  inference reruns, sample changes, network data acquisition or additional claims.
- **REQ-003** Before rendering, the refresh shall freeze an input manifest and
  verify the actual installed current library against source4bc65b3 using source
  and installed-function identities plus a saved runtime application trace on
  those same canonical inputs. Package version alone shall not establish identity.
- **REQ-004** When current application rendering data are derived, the refresh
  shall compare scientific tables and runtime trace fields with the frozen
  canonical expectations, preserving IDs, values, ordering and NA/zero meanings.
  Any scientific mismatch shall stop publication rather than revise inference.
- **REQ-005** The refresh shall rerender exactly the existing seven figure sets
  as PNG at300dpi and vector PDF/SVG, with readable nonoverlapping labels,
  unclipped notes/axes/legends, consistent scientific color semantics and an
  updated seven-page atlas. All plotted terms and display subsets shall remain
  traceable to full canonical results and be accurately identified in captions.
- **REQ-006** The bundle shall include all canonical results, source tables,
  rendering scripts, input/source/installed-library manifests, execution logs,
  sessionInfo, captions, atlas, README and file digests needed for offline
  reproduction, with bundle-relative operational references and no external
  symlink dependencies. Original inference provenance shall remain distinguished
  from the new rendering date and current application source.
- **REQ-007** The review shall include three independent angles: data integrity/
  provenance, methods/statistics, and topic-matched scientific interpretation/
  visual readability. Every figure and caption shall be inspected with findings
  verified against ground truth and recorded in a persistent review ledger;
  unresolved material findings shall block final delivery.
- **REQ-008** When the refresh is finalized, a clean rendering-only invocation
  shall reproduce its scientific tables exactly and regenerate all exports from
  bundled inputs without inference/network access, while verification confirms
  original bundle hashes and validated application source remain unchanged.

## §C Constraints and exclusions

### Out of Scope — Scientific and application changes

- Differential-expression, enrichment or clustering inference reruns and retuning.
- New datasets, extra scientific claims, extra panels or changed selection/ranking.
- Application code, deployed source, CI thresholds, package pins or runtime changes.
- Overwriting previous bundles, manuscript text rewriting or an unrequested deck.
- Declaring visual or scientific review complete without actual artifact inspection.

## §D Traceability and completion

REQ-001→AC-001; REQ-002/004→AC-002; REQ-003→AC-003;
REQ-005→AC-004; REQ-006/008→AC-005; REQ-007→AC-006.
Independent plan approval precedes generation. This plan does not assert that a
current-source trace, new exports or deliverable review has already succeeded.

## HISTORY

| Version | Date | Change |
|---|---|---|
|0.1.0|2026-10-30|Initial presentation-only refresh plan from frozen inference; no generation.|
