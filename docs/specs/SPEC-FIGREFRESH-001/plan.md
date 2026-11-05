# Plan — SPEC-FIGREFRESH-001 v0.1.0

## §A Presentation decisions and boundaries

Reuse the existing seven figure stems and approved scientific story:
01_sample_qc, 01_voom_qc, 03_go_bp_comparison, 04_cluster_coverage,
04_cluster_term_detail, 05_cluster_summary_hierarchical and
05_cluster_summary_david. Preserve the current largest24 summary selection,
top24 GO comparison, detail subset disclosure and all ranking rules.
The app supports every admitted cluster; that does not authorize changing the
manuscript's approved display subset. Use current validated4bc65b3 for runtime
equivalence and render provenance, not new inference.

Read the old bundle's README, captions, manifest, canonical results, scripts,
review ledger and panel-table definitions before generation. Preserve explanatory
distinctions: descriptive means are not cluster-level FDR; hierarchical/DAVID
memberships/filters differ; missing cells remain missing; coverage is not accuracy.
Only date/provenance and objectively supported presentation corrections may change
caption text. Do not add biological claims.

## §B Fresh destination and ownership

Proposed output in the integration worktree:
`.moai/reports/manuscript-figures-20261030/`.
Fail if it already exists, is a symlink or overlaps the original. Do not remove,
merge into or silently rename an existing destination. Report collision to root
for a separately approved version suffix. Snapshot the complete original file
inventory/digests, verify its existing SHA256SUMS, then copy needed files into the
new independent bundle; preserve original bytes and record new destination copies.
No live hardlinks or symlinks to the original.

| Target | Authorized scope |
|---|---|
|New20261030 bundle analysis/scripts/|Rendering-only entry point and minimal presentation adjustments derived from existing scripts; inference scripts preserved as provenance, never invoked.|
|New bundle analysis/output/figures/|Exactly seven PNG/PDF/SVG figure sets with newdate naming.|
|New bundle analysis/output/tables/ and data/|Canonical copies and exact-equality receipts; no scientific recomputation or retuning.|
|New bundle metadata, atlas and review/|Updated captions/manifest/README, execution/source receipts, immutable input manifest, hashes and independent ledger.|
|docs/specs/SPEC-FIGREFRESH-001/|SPEC bodies; Implementer E2/E3, Docs E4/status.|

Application repository source, older reports and root handoff/log are not owned by
this task. Root controls deployment/finalization; this SPEC permits no deployment.

## §C Ordered milestones

1. **High — Independent plan approval and input preflight.** Confirm new directory
   safety; hash all original files and freeze the figure→table→canonical-RDS map.
   Locate the actually installed4bc65b3 library, record path, source commit,
   installed function digests and sessionInfo. Do not install or fetch packages.
2. **High — Runtime equivalence.** Execute only the existing current-app summary/
   plotting transformation on frozen canonical results. Save actual trace fields,
   full data/masks/IDs and comparisons with independently read canonical tables.
   This is a display calculation, not an enrichment/clustering inference rerun.
   Stop on a scientific mismatch; do not reinterpret it as a permitted correction.
3. **Medium — Presentation rerender.** Reuse old rendering scripts in the new
   bundle; adapt only label placement, figure dimensions/margins and date/
   provenance so the same scientific panels read clearly. Preserve all rows/terms
   of each approved subset. Save source diff and execution log, render seven
  300dpi PNG plus PDF/SVG exports, update atlas/captions/source manifest.
4. **High — Independent three-angle review and delivery.** Inspect every PNG,
   vector export and atlas page; verify data/methods/interpretation in separate
   independent reviews. Resolve verified presentation findings, rereview changed
   assets, perform clean rendering-only reproduction, then finalize hashes.

## §D Evidence and portability

Reuse the existing rendering entry point, not run_all.R or inference steps.
Require set.seed/sessionInfo discipline where relevant; preserve existing seeds.
Record current application trace provenance separately from canonical inference
run provenance and rendering timestamps. Source/installed identity must identify
the exact functions actually called, since package0.1.6 alone is insufficient.

All operational asset references in the new manifest must resolve inside the new
bundle. Historical source paths may be retained as provenance labels but must not
be required to reproduce. Keep complete canonical tables/results available even
when a figure displays a declared subset. Exclude only the digest manifest itself
from its self-referential hash list and document this choice. Verify full digest
coverage and unchanged original inventory after final review.

Reproduction must establish exact scientific table/trace equality; graphics bytes
may contain device metadata, so record their actual hashes without promising
cross-device byte-identical PDFs. Compare semantic plotting values and visually
inspect final output. No new code-only or implementation-mirror tests are needed.

## §E Risks and rollback

Current library unavailable or mismatch: stop, report evidence gap to root, do
not silently use a historical library. Table mismatch: freeze receipts and request
scientific triage outside this presentation-only scope. Unreadable labels:
adjust presentation within the same subset, then inspect all changed exports.
Rollback means withhold the new bundle; preserve the old deliverable and app.
