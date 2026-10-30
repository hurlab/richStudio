# Scientific clustering and figure follow-up — 2026-10-29

The application changes address missing heatmap statistics, repeated representative labels and result-selection resets. The corrected source and regression tests are pushed on `WT-scientific-heatmap-adoption`; the current API-compatible candidate is `652e49876adac2bd8c1bc4ddb91970eec9b764a8`, following scientific GUI/figure baseline57b5a15. The baseline was `666c120034bb95764cee085a097903afe3c1da56`.

## Changes

- Cluster summary coordinates and individual selection use actual cluster IDs. Repeated representative terms and noncontiguous IDs remain distinct.
- Missing probabilities stay NA/null; p=1 remains a transformed score0. Raw p=0 has a finite display-only floor, explained in actual hover text. The underlying tables remain unchanged.
- All-missing individual and summary heatmaps render without inventing statistical zero values.
- Individual-choice updates have a separate observer. Switching to DAVID no longer resets the result selector to the first hierarchical result. The old behavior was reproduced in actual browser input values and an independent MockShinySession probe.
- Backend labels distinguish compiled richCluster methods from legacy richR. Errors from the legacy enrichment-score path remain explicit, with no automatic algorithm substitution.

## richCluster adoption assessment

richCluster2.0.1 was already used for hierarchical and DAVID-style clustering. Its2.0.0 scientific fixes, including Kappa shared-gene and full-universe handling, are present. The examined local richCluster `R/`, `src/` and `NAMESPACE` match public pin `a0d1f630fbe64089ab38516116b78962672e6349`; no new dependency-version upgrade is claimed by this follow-up.

The legacy GUI choice calls `richR::richCluster`, which is a different implementation. Its large public-case enrichment-score rejection is not silently bypassed. The corrected compiled engines are usable on the actual public-case data. Their effective input handling differs: hierarchical retains the established strict per-input raw Pvalue<0.1 filter, while DAVID has no equivalent filter. This follow-up neither tunes thresholds nor presents the methods as an equal-feature accuracy benchmark.

## Observed verification

| Evidence | Measured result and attribution |
|---|---|
| Final3 scoped installed-package tests |62tests,773assertions,0fail/error/warning/skip, before adding the six causal-selector assertions |
| Updated local heatmap/selector suite |70assertions,0fail/error/warning/skip; selector regression fails on the old installation and passes after repair |
| Final local browser |8journeys PASS on one final3 installation: desktop+narrow saved-boundary, synthetic upload/compute, real GSE63310 upload/compute, bundled data |
| Independent GUI readback |8actual saved/downloaded artifact checks PASS; raw inputs, memberships, missing masks and independent member-mean Padj values match traces |
| Server final source preflight |Exact652e498 source rebuilt;193R4.6 namespaces,90tests/1155assertions,0fail/error/warning/skip, Shiny app construction PASS; live release untouched |
| Earlier isolated-library check |193namespaces from private copied R4.6 dependencies plus base, new application source build; dependency source rebuild and independent OS were not claimed |
| API/UI compatibility correction |33affected tests/409assertions pass on652e498; exact provider error/newline restored and guidance retained only in GUI |
| Hosted652e498 quality |Run40966347363: all7jobs PASS;249tests/2987passed,0failure/error/warning/skip; Rcheck0E/0W/5N; coverage5041/5615=89.78% |

The two real-data engines reproduce hierarchical366clusters/1432unique term labels/1559memberships and DAVID254/1266/1636. Final summary matrices retain977and5missing cells respectively, with zero duplicate cluster-coordinate keys. The separate server scientific-baseline installation at57b5a15 also reproduced these real GSE63310 counts, missing masks and zero collisions from the six checksum-verified inputs (`SERVER_NATIVE_PUBLIC_CASE_PASS`); the live release was unchanged. The heatmap/visualization files and clustering algorithm/parameter bodies are unchanged in652e498, as mechanically checked separately. The actual final3 package RDB SHA256 was `66d124befb7cf44cd584fb958fd7f79095a32d5ed0d785ea5328f7aff43a47f3`; all47 frozen application source hashes match57b5a15.

The first hosted browser attempt recorded57PASS/1FAIL. All eight new scientific journeys passed. The failure occurred before the existing worker-stop test body, in the fixture process ownership check; cleanup verified no live remaining processes, free port and removed scratch. A bounded local surrogate probe recorded0nonce failures in240samples across30launches. This does not establish the cause of the hosted failure. The guard remains intact and the failure evidence is retained.

## Manuscript figures

Seven refreshed sets are stored locally in `.moai/reports/manuscript-figures-20261029/`:300dpi PNG, vector PDF/SVG, an assembled seven-page atlas, exact panel tables, source manifest, reproducible scripts and three independent reviews. The original differential, enrichment and clustering result objects and167original source files remain byte-identical. No inference, sample rule, threshold, gene-set universe or clustering parameter was retuned.

Review corrected the unqualified QC sample-exclusion statement and explicitly distinguished detail values from full original ORA tables from method-filtered summary values. Sample labels are dark, and both descriptive summary panels share colour limits0..3.430803752471614. Independent checks confirm all288summary cells, IDs, ranks and missing masks. Means of term-adjusted p-values are descriptive, not cluster-level FDR. No material review finding remains in the inspected scope; a journal-specific reduction/print proof was not supplied or claimed.

## LSP sync recovery

The earlier652e498 hosted receipt passed run policy but recorded43warnings and2405informational diagnostics, leaving sync FAIL. The user then explicitly requested that this hold be resolved.

The actual frozen-package JSON-RPC command `bash scripts/test-workspace.sh diagnostics sync`, with baseline652e498, now exits zero. It reproduced all2448 baseline diagnostics and measured zero candidate errors, warnings, information or hints across27Rfiles. Both canonical run and sync assessments are PASS; `release_hold` is false. The runner still checks installed namespace origin, missing/wrong-stage namespace negatives, an invalid R canary and intended TypeScript membership. Canonical thresholds and these checks were retained.

Repairs resolve missing widget/JavaScript providers and the existing richR private network helper, make data-mask column references explicit, and remove unused lazy wrapper bindings after callsite checks. Style cleanup retains published R/Rcpp names and named arguments through an exact-name allowlist; private names follow snake_case. The existing magrittr pipe convention preserves the declared R4.0 minimum. No linter was disabled. Source strings were checked through constant-folded AST comparisons, and inactive examples remain in `docs/development/historical-r-examples.md` with source pointers.

A fresh candidate installation preserves all18exported signatures. Both actual GSE63310 engine outputs are identical to the source-verified652e498 installation: full summary/detail tables, heatmap coordinates, values and missing masks; checksum-verified inputs remain unchanged. Independent structural review found no material regression and verified all42removed returns were function-tail expressions. Scoped runtime tests and a new hosted CI run remain pending at this entry. The older652CI result is not evidence for these newer source changes. Actual diagnostics and scoped proofs are retained under `.moai/reports/lsp-sync-cleanup/`.

## Deployment and remaining action

Server deployment is authorized after validation. The live target was mechanically observed at666c120. SSH works, but sudo requires interactive password authentication. The prepared final wrapper is `/home/juhur/richStudio-deploy-scientific-652e498/deploy.sh`; it checks the exact preflight and CI SHA, the unchanged current release, and the reviewed deployment-script hash before the existing immutable-release/atomic-symlink workflow runs. The CI gate is only marked ready after observed successful quality results.

No live switch, formal release/tag or public archive has occurred in this follow-up. After the owner authenticates the prepared sudo invocation, verify the actual live release/build identity, HTTP health and targeted GUI behavior. The newer LSP candidate requires its own successful CI and matching server preflight before deployment. Formal release/archive remains a separate final step.

Local evidence root (gitignored): `.moai/reports/scientific-heatmap-adoption/`, including `progress.md`, `e2e/final3-all/execution-receipt.json`, `server-final/final-preflight-receipt.json`, earlier failed artifacts and figure bundle receipt. Hosted run: https://github.com/hurlab/richStudio/actions/runs/40966347363 .
