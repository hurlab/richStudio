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
run_commit_sha: 96e89cfe3b9cacad2efa6a96f218c340b456892a
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

```yaml
sync_complete_at: 2026-10-30T18:23:37Z
sync_commit_sha: 06a20a02512b39317fabe7159ed18fd77f9ea899
sync_status: completed-six-acceptances-three-reviews-final-package-audit-approved
documentation: docs/quality/manuscript-figures-20261030.md
ac_source: docs/specs/SPEC-FIGREFRESH-001/acceptance.md
tier: M
b12_self_test_a: not-run-no-CHANGELOG-emission
b12_self_test_b: not-run-no-CHANGELOG-emission
b12_self_test_c: not-run-no-CHANGELOG-emission
changelog_entry_position: none
frontmatter_status_transitions:
  status: in-progress-to-implemented-to-completed
  updated: 2026-10-30
source_attribution:
  application: 4bc65b3c9068f07f64e08a1b043a0f8913d469fa
  run_commit: 96e89cfe3b9cacad2efa6a96f218c340b456892a
  existing_application_CI: seven-of-seven-run-41076765375-not-rerun
review_evidence:
  independent_angles: data-integrity-methods-scientific-interpretation-visual-APPROVED
  actual_visual_inspections: seven-PNG-seven-atlas-pages-seven-SVG
  scientific_CSV: eleven-byte-exact
  original_files: 219-unchanged
  frozen_assets_and_inputs: 49-and-67-unchanged
  runtime: seven-qualified-functions-3720-display-cells-exact
  clean_offline_reproduction: scientific-tables-and-traces-exact-all-exports-regenerated
  final_packaging_audit: APPROVED-second-pass
final_delivery_identity:
  manifest_members: 342
  bundle_and_archive_payload_files: 343
  archive_bytes: 140982334
  archive_sha256: b5e59be8426abc6093440dc4363cf8138cf6042a33a5e720541b8e667dd99bb3
  SHA256SUMS_sha256: 2e25e121f8c73420110d5722119ff34ab79ac0c3a0cd700baacbc52f56ae1c8a
  final_audit_sha256: e9f650e387dce561c66762da3251132608c291899d274fb2c0ac97437178bd8f
canary_compliance_check:
  no_new_inference_or_network_acquisition: verified-in-generation-entry-point-and-reviews
  archive_payloads: exact-safe-paths-types-no-links
  immutable_bundle: not-edited-by-documentation-sync
remaining_gaps:
  journal_specific_reduction_and_physical_print: not-supplied
  current_server_deployment: not-measured
  universal_graphics_binary_reproduction: not-promised
```

Documentation read actual generation, three independent review reports and
`.moai/reports/manuscript-finalization/{receipt.json,final-audit.md,final-audit-checks.json}`.
The independent packaging command was
`python3 .moai/reports/manuscript-finalization/final-audit-check.py`; its observed
output records manifest_exhaustive=true, archive_exact_byte_identities=true,
archive_safe_paths_types_no_links=true and343payload files. It streams archive
members and rehashes every payload. These are inspected independent results,
not a new execution by documentation. Final audit SHA was freshly measured with
`sha256sum`; final identity is recorded above. Root owns the sync commit and its
subsequent SHA metadata update; this field does not cite a future commit.
No immutable bundle/archive, source, inference, previous completed SPEC or
production state was changed in this sync.
