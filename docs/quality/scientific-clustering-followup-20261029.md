# Scientific clustering and figure follow-up — 2026-10-29

The application changes address missing heatmap statistics, repeated representative labels and result-selection resets. The corrected source and regression tests are pushed on `WT-scientific-heatmap-adoption`; the current candidate is `73178628106d9b160831d476f80171e4f4d0bf61`, with scientific GUI/figure baseline57b5a15, API-compatible652e498, LSP-cleanup83c32a6 and CI-tool correction8d36448. The baseline was `666c120034bb95764cee085a097903afe3c1da56`.

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
| Server final source preflight |Exact7317862 source rebuilt;193R4.6 namespaces,94tests/1175assertions,0fail/error/warning/skip, Shiny app construction and both real GSE engines PASS; live release untouched |
| Earlier isolated-library check |193namespaces from private copied R4.6 dependencies plus base, new application source build; dependency source rebuild and independent OS were not claimed |
| API/UI compatibility correction |33affected tests/409assertions pass on652e498; exact provider error/newline restored and guidance retained only in GUI |
| Hosted652e498 quality |Run40966347363: all7jobs PASS;249tests/2987passed,0failure/error/warning/skip; Rcheck0E/0W/5N; coverage5041/5615=89.78% |
| Latest7317862 quality |Run40994809432: all7jobs PASS;253tests/3007passed,0failure/error/warning/skip; application Rcheck0E/0W/5N; coverage8560/9312=91.92% |
| Latest7317862 browser and sync |58GUI journeys PASS,0skip/flaky/retry;8independent saved-data readbacks PASS; actual LSP0total, syncPASS, release_hold=false |

The two real-data engines reproduce hierarchical366clusters/1432unique term labels/1559memberships and DAVID254/1266/1636. Final summary matrices retain977and5missing cells respectively, with zero duplicate cluster-coordinate keys. The separate server scientific-baseline installation at57b5a15 also reproduced these real GSE63310 counts, missing masks and zero collisions from the six checksum-verified inputs (`SERVER_NATIVE_PUBLIC_CASE_PASS`); the live release was unchanged. The heatmap/visualization files and clustering algorithm/parameter bodies are unchanged in652e498, as mechanically checked separately. The actual final3 package RDB SHA256 was `66d124befb7cf44cd584fb958fd7f79095a32d5ed0d785ea5328f7aff43a47f3`; all47 frozen application source hashes match57b5a15.

The first hosted browser attempt recorded57PASS/1FAIL. All eight new scientific journeys passed. The failure occurred before the existing worker-stop test body, in the fixture process ownership check; cleanup verified no live remaining processes, free port and removed scratch. A bounded local surrogate probe recorded0nonce failures in240samples across30launches. This does not establish the cause of the hosted failure. The guard remains intact and the failure evidence is retained.

## Manuscript figures

Seven refreshed sets are stored locally in `.moai/reports/manuscript-figures-20261029/`:300dpi PNG, vector PDF/SVG, an assembled seven-page atlas, exact panel tables, source manifest, reproducible scripts and three independent reviews. The original differential, enrichment and clustering result objects and167original source files remain byte-identical. No inference, sample rule, threshold, gene-set universe or clustering parameter was retuned.

Review corrected the unqualified QC sample-exclusion statement and explicitly distinguished detail values from full original ORA tables from method-filtered summary values. Sample labels are dark, and both descriptive summary panels share colour limits0..3.430803752471614. Independent checks confirm all288summary cells, IDs, ranks and missing masks. Means of term-adjusted p-values are descriptive, not cluster-level FDR. No material review finding remains in the inspected scope; a journal-specific reduction/print proof was not supplied or claimed.

## LSP sync recovery

The earlier652e498 hosted receipt passed run policy but recorded43warnings and2405informational diagnostics, leaving sync FAIL. The user then explicitly requested that this hold be resolved.

The actual frozen-package JSON-RPC command `bash scripts/test-workspace.sh diagnostics sync`, with baseline652e498, now exits zero. It reproduced all2448 baseline diagnostics and measured zero candidate errors, warnings, information or hints across27Rfiles. Both canonical run and sync assessments are PASS; `release_hold` is false. The runner still checks installed namespace origin, missing/wrong-stage namespace negatives, an invalid R canary and intended TypeScript membership. Canonical thresholds and these checks were retained.

Repairs resolve missing widget/JavaScript providers and the existing richR private network helper, make data-mask column references explicit, and remove unused lazy wrapper bindings after callsite checks. Style cleanup retains published R/Rcpp names and named arguments through an exact-name allowlist; private names follow snake_case. The existing magrittr pipe convention preserves the declared R4.0 minimum. No linter was disabled. Source strings were checked through constant-folded AST comparisons, and inactive examples remain in `docs/development/historical-r-examples.md` with source pointers.

A fresh candidate installation preserves all18exported signatures. Both actual GSE63310 engine outputs are identical to the source-verified652e498 installation: full summary/detail tables, heatmap coordinates, values and missing masks; checksum-verified inputs remain unchanged. Independent structural review found no material regression and verified all42removed returns were function-tail expressions. Installed-candidate149tests/1944assertions,8scientificGUI journeys and8independent actual saved-data checks pass. The eight component-design GUI journeys also pass after the source digest correction described below. Final hosted7317862 validation now completes7/7successfully. The older652CI result is not evidence for these newer source changes.

The initial83hosted attempt exposed a verified tooling mismatch: languageserver0.3.16 supplies inline text to lintr3.4.0 without enabling project-settings parsing, leaving53informational diagnostics despite .lintr being present. Official-source0.3.20 reads those settings; its SHA25680be3dc71a5219cfb98d930e9eac01c968aa2d151cd10bad7ce3ec198fa6d4a6 is now pinned in CI. Fresh configured/bad-name/wrong-pipe/syntax-error canaries and full local JSON-RPC diagnostics pass under that exact official source. The same83browser attempt had50PASS/8FAIL at a stale component-source freeze hash after formatting. One digest was updated only after direct baseline-to-current AST verification; all six frozen members, assertions and safety guards remain. Old failing receipts are retained; that obsolete full run was cancelled to avoid duplicate compute.

Actual hosted8d36448 diagnostics now measure0errors/0warnings/0information/0hints, syncPASS and release_hold=false. Server8d36448 preflight94tests/1175assertions and193R4.6namespaces pass, with Shiny construction and both checksum-verified real GSE engines. The8dbrowser run subsequently recorded57PASS/1startup ownership-guard failure. Controlled owned-zombie processes reproduce a false-positive class in both fixture guards. Commit7317862 adds a second identity check after environment reads: only confirmed absence/death of the same PID/start/group is omitted, while alive unknown processes, nonce/read errors and identity replacement remain rejected. Thirty extracted-source transition canaries, real-process positive/negative probes, four modal/worker-stop GUI journeys and an independent peer review pass. The earlier hosted PID state was not recorded, so the exact hosted cause is not claimed. Old8dfull was superseded after successor CI started.

Latest7317862 CI40994809432 completes7/7jobs successfully:253tests/3007passed,0failure/error/warning/skip, application R CMD check0E/0W/5N and coverage8560/9312=91.92%. Browser58PASS with0skip/flaky/retry and8independent hosted saved-data checks PASS. Actual diagnostics0/syncPASS/release_hold=false. Its application R/src/inst/DESCRIPTION/NAMESPACE remain identical to tested83/8d. Exact731server preflight94tests/1175assertions/193namespaces and both real GSE engines PASS; no live switch has occurred.

 Actual diagnostics and scoped proofs are retained under `.moai/reports/lsp-sync-cleanup/`.

## Deployment verified — 2026-10-30

The owner executed the prepared7317862wrapper. The live target is `/opt/richStudio/releases/richStudio-73178628106d9b160831d476f80171e4f4d0bf61-20261030T045606Z`, with `.release-commit`73178628106d9b160831d476f80171e4f4d0bf61. shiny-server is active; internal and publicHTTP responses are200. A fresh process resolves R4.6.1 and richStudio0.1.6/richR0.1.5/richCluster2.0.1 from the actual release library. All113selected source/config/test hashes match the hosted CI candidate with0drift.

The actual public Shiny browser session loads bundled GO1/GO2/KEGG1 tables and completes GO1/GO2 hierarchical and DAVID clustering. Hierarchical produces141clusters/282cells/108missing; DAVID139/278/105. Both plots have unique coordinates and retained result selections, with0browser page errors. All282hierarchical cell values and NA positions match the hosted CI trace. These are functional smoke measurements with the established method-specific input filtering. Both screenshots were inspected; row labels overlap when this many clusters are shown together, leaving a presentation/readability follow-up.

The first ad-hoc verification reader assumed a nested Plotly matrix and failed on flat trace data. Its log is retained; the corrected reader uses the existing CI flat/matrix handling and waits for the selected result's cluster count and3stable frames. No product code was changed by this check. The browser context closed after completed jobs.

The prior253CI tests,58CI GUI journeys and94server-preflight tests remain validation evidence, not a claim that those full suites ran again on production. Formal release/tag/archive publication is still separate. The owner authentication/deployment step is completed; the old guarded deployment command should not be repeated.

Fresh post-deployment evidence: `.moai/reports/lsp-sync-cleanup/post-deploy-20261030/report.md`, runtime/source/trace receipts and two screenshots. Complete CI evidence: `.moai/reports/lsp-sync-cleanup/final-evidence-summary.json` and [hosted run40994809432](https://github.com/hurlab/richStudio/actions/runs/40994809432). Earlier scientific/figure evidence remains under `.moai/reports/scientific-heatmap-adoption/`.
