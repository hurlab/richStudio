# Progress — SPEC-FIGREFRESH-001

## §E.1 Plan-phase Audit-Ready Signal

_Plan v0.1.0 independently APPROVED; see [the plan review](../../../.moai/reports/manuscript-figures-20261030-review/plan-review.md). This approval covers the plan only; generation has not started._

## §E.2 Run-phase Evidence

Presentation-only generation and clean offline reproduction completed in the isolated
`manuscript-refresh` worktree. Evidence: ignored bundle
`.moai/reports/manuscript-figures-20261030/review/generation.md` and sibling
`.moai/reports/manuscript-refresh-implementation/{render,reproduction}.log`.
No application source, old bundle, inference or production deployment was modified.

| Acceptance | Actual output | Status |
|---|---|---|
| AC-001 | Old manifest218/218, all219 old paths/content hashes unchanged before/after; fresh independent copy, zero symlinks/shared file inodes. | PASS (scoped generation) |
| AC-002 | Eleven new scientific CSV tables byte-exact; direct full canonical means and current Plotly raw/score/NA checks pass for366/254clusters and2196/1524cells; originals/67frozen inputs unchanged. | PASS (scoped generation) |
| AC-003 | Four validated source hashes, seven qualified installed function formals/bodies; actual library/RDB/function/input/source receipts and full canonical runtime traces captured before rendering. | PASS (scoped generation) |
| AC-004 | All21PNG/PDF/SVG exports and7-page atlas exist; seven PNGpHYs read300dpi. Independent visual reviewer actually inspected all7primaryPNGs,7atlas rasterizations and7SVG rasterizations; PDFbounds0out-of-pagewords, atlas/single-PDFtext7/7equal, SVGexternalreferences0; final current-assets review APPROVED. | PASS |
| AC-005 | New clean copied bundle regenerated all exports/11tables/current traces under `unshare -Urn`; exact CSV/summary/plot_data/x/y/z/text comparisons pass. Root finalization receipt records342manifestmembers/343bundlefiles, all343archivepayloadsverified,140982334bytes and finalarchiveSHA below; external recorded installed environment remains required. | PASS |
| AC-006 | Actual current-artifact data-integrity.md,methods.md andvisual-interpretation.md each APPROVED their separate scope; root closed the current review ledger without changing49frozen primaryassets. Historical20261029 reviews remain separately labeled. | PASS |

The first runtime-probe attempt failed before rendering because the new verification
script converted doubles through character, changing one mean by−8.6736173798840355e−19.
Its original log and separate reproducer are retained. The probe now retains doubles;
no source value, tolerance, helper or canonical expectation changed. Both final offline
invocations pass exact comparisons. Graphics-device metadata need not be byte-identical;
scientific tables and trace values are the reproduction contract.

Baseline: application source4bc65b3, initial worktreeHEAD9fa4f0a, R4.6.1,
`heatmap-r-portability/.../impl/library-new/richStudio` RDB
`5e1ca7d3b14e514fa0d33e4313c54e897965cce288fd24c9afbd3aaba8b7d99f`.
Hosted41076765375 owns the existing application-wide7/7PASS verdict; this agent
ran no local full suite/check/coverage. Specific-journal print reduction and
current production deployment remain unobserved by this task.

### Independent review and root finalization closure

The Implementer read the three actual current-bundle reports:
`review/data-integrity.md`, `review/methods.md` and
`review/visual-interpretation.md`. Data review independently checked all7440
Pvalue/Padj mean positions,3720scientific display cells,11byte-exact CSVs,
seven qualified function identities and the clean-copy trace equality. Methods
review independently checked the nine-sample design,24-term GO selection,
full-ORA detail/method-filtered summary distinction, shared descriptive-summary
scale, four successful coverage runs and two preserved legacy errors. Visual
review actually opened all seven PNGs, seven atlas rasterizations and seven
native-rasterized SVGs; no material finding remained within their recorded scope.
These are the independent reviewers' measurements, not reruns by this Implementer.

Root's final packaging measurement was read directly from integration-tree
`.moai/reports/manuscript-finalization/receipt.json`: source4bc65b3,
342manifestmembers,343bundlefiles,343archivepayloadsverified,
49frozenprimaryassets,219originalfilesunchanged,0externallinks,
all_checks_passed=true. Root's finalized delivery bundle resides under the
integration worktree, separately from this Implementer's generation tree.

- Archive: `.moai/reports/richStudio-manuscript-figures-20261030.tar.gz`
- Size:140982334bytes
- Archive SHA256:`b5e59be8426abc6093440dc4363cf8138cf6042a33a5e720541b8e667dd99bb3`
- Final SHA256SUMS digest:`2e25e121f8c73420110d5722119ff34ab79ac0c3a0cd700baacbc52f56ae1c8a`

This metadata closure attributes archive verification to root; it does not claim
that this Implementer executed that packaging check. A separately assigned final
packaging auditor owns its own additional verdict. No frozen bundle file was
changed by this E2/E3 update. Journal-specific print proofs and current production
deployment remain outside the figure-deliverable evidence.

## §E.3 Run-phase Audit-Ready Signal

```yaml
run_complete_at: 2026-10-30T18:21:24Z
run_commit_sha: pending-root-commit
run_status: all-six-acceptances-pass-independent-three-angle-review-approved
ac_pass_count: 6
ac_fail_count: 0
ac_pending_count: 0
preserve_list_post_run_count: 219
new_warnings_or_lints_introduced: none-observed-in-successful-render-logs
cross_platform_build:
  status: not-rerun-application-source-unchanged
  hosted_application_verdict: PASS-run-41076765375-source-4bc65b3
m1_to_mN_commit_strategy: root-owned-explicit-path-metadata-integration
independent_reviews: APPROVED-data-integrity-methods-domain-visual
```

## §E.4 Sync-phase Audit-Ready Signal

_<pending sync-phase>_
