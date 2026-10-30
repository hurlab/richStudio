# Manuscript figure refresh — 2026-10-30

## Claim

[SPEC-FIGREFRESH-001](../specs/SPEC-FIGREFRESH-001/spec.md) is completed: seven
existing figure sets were refreshed from unchanged canonical scientific results,
reviewed independently from three angles, reproduced offline and packaged with
an exhaustive final manifest. This is a presentation refresh, not new inference,
a biological discovery or evidence of algorithmic accuracy.

The final bundle contains seven 300-dpi PNGs, seven vector PDFs, seven SVGs and a
seven-page atlas, with source tables, canonical results, scripts, captions,
execution/environment provenance and current independent reviews. It is stored
under `.moai/reports/manuscript-figures-20261030/` in the integration worktree.
The archive is `.moai/reports/richStudio-manuscript-figures-20261030.tar.gz`.

## Evidence

Documentation inspected actual generation, review and final packaging records;
it did not rerender figures, rerun inference or repeat application tests.

- Generation and clean-copy reproduction ran the rendering-only entry point
  under `unshare -Urn` with external networking denied. Both verified the actual
  current installed namespace before rendering. Output includes
  `CURRENT_QUALIFIED_FUNCTION_IDENTITIES_PASS 7`,
  `SCIENTIFIC_TABLES_BYTE_EXACT 11`,
  `SEVEN_FIGURE_SETS_AND_ATLAS_CREATED 21` and
  `CLEAN_OFFLINE_REPRODUCTION_EXACT_TABLES_AND_SCIENTIFIC_TRACES_PASS`.
- Independent data review verified all 11 scientific CSVs byte-exact against the
  original sibling bundle, all 219 original files unchanged,49 frozen assets and
  67 inputs unchanged. Seven qualified function identities and all 3720 scientific
  display cells match canonical values/traces; full 7440 Pvalue/Padj mean positions
  were checked directly. Package version alone was not used as source proof.
- Independent methods review checked saved results, sample selection, membership
  means, ranking, method-specific filtering, captions and atlas text. Independent
  visual review actually inspected all 7 primary PNGs,7 atlas page rasterizations
  and7 independently rasterized SVGs:21 visual inspections. No verified material
  data, methods or visual/interpretive finding remains open.
- All three actual reports state APPROVED: `review/data-integrity.md`,
  `review/methods.md` and `review/visual-interpretation.md`. Original 20261029
  reviews remain historical and were not substituted for these new reviews.

The independent final packaging audit ran:

```sh
python3 .moai/reports/manuscript-finalization/final-audit-check.py
```

Its final second-pass result is APPROVED. Relevant actual output:

```text
manifest_members: 342
manifest_exhaustive: true
bundle_files: 343
archive_payload_files: 343
archive_exact_byte_identities: true
archive_safe_paths_types_no_links: true
archive_bytes: 140982334
frozen_primary_assets: 49
old_inventory_exact: 219
science_csv_exact: 11
stale_readme_packaging_text: false
```

The auditor streamed all 343 payloads, checked safe paths/types/no links and exact
path/hash equality, and rechecked final identities after verification. SHA256SUMS
covers 342 files and excludes itself; the archive includes those 342 plus SHA256SUMS.
A first-pass stale packaging sentence was corrected by root, then manifest/archive
were rebuilt and the full independent audit repeated. Those earlier identities
remain historical. No frozen primary asset changed during that correction.

Final identities from the actual receipt and independently approved audit:

| Artifact | Size or SHA256 |
|---|---|
| Archive size | 140982334 bytes |
| Archive SHA256 | `b5e59be8426abc6093440dc4363cf8138cf6042a33a5e720541b8e667dd99bb3` |
| SHA256SUMS SHA256 | `2e25e121f8c73420110d5722119ff34ab79ac0c3a0cd700baacbc52f56ae1c8a` |
| Final audit report SHA256 | `e9f650e387dce561c66762da3251132608c291899d274fb2c0ac97437178bd8f` |

The documentation run freshly read `receipt.json`, `final-audit-checks.json` and
`final-audit.md` under `.moai/reports/manuscript-finalization/`, and executed
`sha256sum .moai/reports/manuscript-finalization/final-audit.md`; output matched
the final audit identity above. Archive payload verification is attributed to
the independent auditor, not claimed as a documentation rerun.

## Baseline-attribution

Documentation integration tree:
`/home/juhur/.moai/worktrees/projects/richStudio/heatmap-legibility`, measured
HEAD `96e89cfe3b9cacad2efa6a96f218c340b456892a`. Generation used the separate
`manuscript-refresh` worktree; final delivery was copied and independently audited
in the integration tree. Original inputs/approved historical bundle remain in
`scientific-heatmap-adoption/.moai/reports/manuscript-figures-20261029`.

Current application source is `4bc65b3c9068f07f64e08a1b043a0f8913d469fa`.
The recorded R4.6.1 environment loaded the qualified current package, RDB SHA256
`5e1ca7d3b14e514fa0d33e4313c54e897965cce288fd24c9afbd3aaba8b7d99f`.
Original inference dates remain separate from new rendering date 20261030.
Existing hosted run 41076765375 passed 7/7 on application source 4bc65b3; it is not
a fresh full-suite result for documentation commits or the figure refresh.

## Gaps

No current server deployment/runtime, new data acquisition, external annotation
refresh or new biological validation was measured by this task. A target journal's
reduction dimensions and physical print proof were not supplied. Rendering
requires the recorded external installed R environment; bundled data/scripts do
not imply a self-contained R installation. Universal editor/font compliance and
binary-identical graphics across rendering devices are not certified.

## Residual-risk

Descriptive means of per-term BH values are not cluster-level FDR. Hierarchical
and DAVID filters/memberships differ; common colours do not create an equal-feature
accuracy comparison. Full-ORA detail missingness differs from filtered summaries;
coverage is not accuracy. Scientific tables and traces reproduce exactly in the
recorded environment; graphics metadata may vary. First generation/reviewer-tool
diagnostics remain transparent nonmaterial history in the bundle reports. Any
later final-bundle modification invalidates these exact manifest/archive identities
and requires renewed scoped verification.
