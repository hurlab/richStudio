# SPEC-DEPENDENCY-001 progress

## §E.1 Plan-phase Audit-Ready Signal

Independent plan audit round 2 PASS: .moai/reports/SPEC-DEPENDENCY-001/plan-audit-round2.md, score 1.00, audited HEAD 27aac71c679009c2b61bb2118325dde690994ef1, plan artifact hash ad55b64f9f128e093b11d22bc858f167a9a81cfaee09a8b9284784e493281af3. This records plan readiness only. The subsequent upstream-patch addendum changes plan.md; that historical PASS does not certify the changed artifact content or implementation completion.

Plan delta: the official richR 0.1.5 commit 9be43abdae556d9f1df128149a70721f08ab7d25 replaces the original 0.1.4 pin; AC-007 explicitly covers first/middle dataset removal and AC-009 retains the upstream regression cases. Independent delta audit PASS: .moai/reports/SPEC-DEPENDENCY-001/plan-audit-v015-delta.md, score 1.00, no defects, audited HEAD 27aac71 plus uncommitted SPEC artifacts, combined sorted-concatenation SHA256 1003923a395152194b0cafd1242a7d5160c702b279d29c88ce9b9bfd078c8b77. This certifies the audited plan delta only. Historical run-phase evidence below remains attributed to its recorded 0.1.4 baseline and does not establish acceptance of the new pin.

## §E.2 Run-phase Evidence

Implementation started after plan-auditor PASS. Tests used the installed `richStudio` build and the isolated library `/tmp/richstudio-dependency-adoption-lib-20261020`, with `RENV_CONFIG_AUTOLOADER_ENABLED=FALSE` in each R command.

| AC | Status | Actual output / evidence |
|---|---|---|
| AC-001 | PASS | DESCRIPTION and lockfile pin richR 0.1.5 at `9be43abdae556d9f1df128149a70721f08ab7d25` and richCluster 2.0.1 at `a0d1f630fbe64089ab38516116b78962672e6349`. The lock records match those exact sources; runtime provenance is recorded under AC-002. |
| AC-002 | PASS | Fresh installed identity log `/tmp/richstudio-v015-logs-20261020/identity.log` records richR 0.1.5, richCluster 2.0.1 and bioAnno 0.99.45 under `/tmp/richstudio-dependency-adoption-v015-lib-20261020`. The official richR archive is `/tmp/richstudio-v015-archives-20261020/richR_0.1.5.tar.gz`, SHA256 `0fdca054567c3e6c0ef51512a11ba755ea3694126aa42cbbb051fed3f1b69abf`, matching the official release and immutable DESCRIPTION/lock commit. The richCluster archive SHA256 is `6abe64c1c156368afcd9fbec942fadf80848ba64c00dadeac6b2faff27b73c00`. The worker test records distinct PID and matching richR 0.1.5 path. Installed metadata has empty RemoteSha fields; archive hash plus configured commit pins and install identity establish provenance. |
| AC-003 | PASS | Installed focused integration file `/tmp/richstudio-v015-integration-final.log` asserts exact expected GO (`GO:TEST1`), KEGG (`01100`) and Reactome (`R-HSA-TEST1`) term IDs on app and actual multisession worker routes; each worker record identifies richR 0.1.5 from the isolated v0.1.5 library. |
| AC-004 | PASS | The installed `enrichTabServer` observer publishes a valid typed zero-row Reactome result, preserves typed columns, and records the result in the existing result list without adding biological rows. |
| AC-005 | PASS | Focused tests assert errors for filtered-zero, unmapped-only and malformed inputs, plus actual multisession observer behavior: a first successful job followed by a failed second job leaves the pre-existing displayed results and metadata unchanged and publishes no partial success. |
| AC-006 | PASS | Focused tests invoke the `saveTabServer` download content handler, read back the produced version 1.0 RDS, assert standard/provider columns, types and comma-delimited IDs, then reopen it through the supported loader. A separate version 1.0 legacy fixture also loads through that loader. |
| AC-007 | PASS | Installed richCluster public wrappers are tested with one and multiple datasets. Assertions cover exact non-empty DAVID memberships, hierarchical zero-based TermIndices decoded against the upstream merged frame, exact term memberships, named dataset GeneID/Pvalue values, preserved raw_result and absence of positional metric aliases in published summaries. The v0.1.5 installed regression removes the first and middle datasets, checks exact retained Pvalue/Padj/GeneID values under numeric names `2` and `1`, and verifies excluded membership is absent or NA. |
| AC-008 | PASS | The installed hierarchical tests have a shared term whose raw Pvalue is below cutoff for dataset one and equal to cutoff for dataset two; they assert strict pre-merge exclusion and NA named membership for dataset two. They also assert per-dataset filtered terms, Padj/Pvalue disagreement behavior, first/middle/trailing empty-dataset removal without value reassignment, and public second gate options. DAVID retains terms without an added significance filter. |
| AC-009 | PASS | Installed richR 0.1.5 regressions pass in `/tmp/richstudio-v015-kappa-final.log`: the original 3-row assembly case, the explicit merged-GeneID-union oracle (distinct from `gene=TRUE` and an unrelated background), a balanced two-pair result with exact memberships `A,B` / `C,D` and measured scores `7.5` / `5.5`, and a single-cluster `A,B,C` result with score `7`. Each positive assembly fixture asserts the wrapper output equals the direct explicit-union oracle. The previously failing installed richR 0.1.4 case remains preserved as historical evidence. |
| AC-010 | PASS | `.moai/reports/SPEC-DEPENDENCY-001/numerical-baseline.md` records attributed measured outputs for historical/current standalone richCluster, the richR consumer adapter plus explicit-union oracle, and vendored C++ current output against a source build of original HEAD. Engine-specific memberships and standalone numerical differences are explicit; no universal cross-engine equality is asserted. |

Installed package build: `R CMD INSTALL --preclean -l /tmp/richstudio-dependency-adoption-v015-lib-20261020 .` completed with `* DONE (richStudio)` in `/tmp/richstudio-v015-install-final.log`. Exact integration command: `R_LIBS_USER=/tmp/richstudio-dependency-adoption-v015-lib-20261020:/tmp/richstudio-dependency-adoption-lib-20261020:/home/juhur/R/x86_64-pc-linux-gnu-library/4.6 RENV_CONFIG_AUTOLOADER_ENABLED=FALSE Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-dependency-integration.R", package="richStudio", load_package="installed", reporter="summary")'`; `/tmp/richstudio-v015-integration-final.log` ends `══ DONE ═` and all worker routes report v0.1.5 from the new isolated library. The parallel kappa command using the analogous `test_file("tests/testthat/test-dependency-kappa.R", ...)` passes in `/tmp/richstudio-v015-kappa-final.log`. Root's broader affected dependency, file-management and reactive-values tests pass in `/tmp/richstudio-v015-final-scoped-root.log`; its existing kappa and clustering-state regressions pass in `/tmp/richstudio-v015-existing-clustering-root.log`, both exit 0. Installed UI construction and server start/close pass in `/tmp/richstudio-v015-ui-smoke.log`. The two Shiny/DT import-replacement warnings match measured original-HEAD baseline logs `/tmp/richstudio-vendored-head-baseline-install-20261020.log` and `/tmp/richstudio-numerical-vendored-head-20261020.log`. The existing C++11 SystemRequirements warning also appears in the source-built original-HEAD install log. Current changed-source/test hash binding is recorded in `/tmp/richstudio-consumer-audit-round4-binding-20261020.txt`.

## §E.3 Run-phase Audit-Ready Signal

```yaml
run_status: in_progress
run_commit_sha: pending (no commit requested in this worktree)
ac_pass_count: 10
ac_fail_count: 0
run_complete_at: null
preserve_list_post_run_count: 0
l44_pre_commit_fetch: not_applicable
l44_post_push_fetch: not_applicable
new_warnings_or_lints_introduced: null
warning_lint_note: "Combined warning/lint status remains unknown because default lintr reports 26 style findings on changed lines; strict changed-line text attribution overstates newly introduced diagnostics where existing naming/return conventions remain consistent. Lintr reported zero warning/error diagnostics. Two observed Shiny/DT import-replacement warnings match the measured original-HEAD baseline."
default_lintr_style_findings: 26
default_lintr_warning_error_diagnostics: 0
changed_executable_line_coverage_percent: 91
all_instrumented_package_coverage_percent: 20.04
configured_overall_coverage_target_met: false
cross_platform_build:
  status: not_run
total_run_phase_files: 13
m1_to_mN_commit_strategy: no commits; root integration owns branch operations
```

Run phase evidence records all ten ACs passing on the scoped installed tests. Covr measured 91/100 (91%) of added/changed executable R lines and 776/3,872 (20.04%) of all instrumented source/native executable lines. The configured overall 85% target is not established by this selected test subset. Default lintr reports 26 style findings on changed lines, zero warning/error diagnostics, and zero exact diagnostic-text matches against original HEAD; these are style findings, not verified functional regressions, and remain reported without source cleanup to preserve repository API/file conventions. Details are in `.moai/reports/SPEC-DEPENDENCY-001/quality-measurement.md`. The namespace roclet ran with roxygen2 8.1.1; the generated diff had unrelated import reformatting and a generated DESCRIPTION config entry, so `NAMESPACE` was restored to its existing style with only the intended `importFrom(richR,richCluster)` removal and DESCRIPTION retained its existing RoxygenNote. The observed Shiny/DT import-replacement warnings match the source-built original-HEAD baseline. No full package suite or deployment was run.

## §E.4 Sync-phase Audit-Ready Signal

_<pending sync-phase>_
