# Dependency runtime: SPEC-DEPENDENCY-001

The migration targets official hurlab richR 0.1.5 and standalone richCluster 2.0.1. Installed consumer acceptance AC-001–AC-010 passed scoped verification under R 4.6.1. Independent consumer review returned PASS-WITH-DEBT; full-suite/overall-coverage/LSP gates and production execution remain unverified.

## Exact source identities

| Package | Version | Repository | Commit | Source archive SHA256 |
|---|---|---|---|---|
| richR | 0.1.5 | hurlab/richR | `9be43abdae556d9f1df128149a70721f08ab7d25` | `0fdca054567c3e6c0ef51512a11ba755ea3694126aa42cbbb051fed3f1b69abf` |
| richCluster | 2.0.1 | hurlab/richCluster | `a0d1f630fbe64089ab38516116b78962672e6349` | `6abe64c1c156368afcd9fbec942fadf80848ba64c00dadeac6b2faff27b73c00` |
| bioAnno | 0.99.45 | guokai8/bioAnno | `3c8936033b806b9f40c7028faa80e4971f6d0859` | `ddab5c458aee07253aedf26d137caeeb6e548538c1ef14f1d0cb27d4d1dc9da9` |

bioAnno's lockfile revision is unchanged. DESCRIPTION records version floors and full-commit Remotes for richR and richCluster; renv.lock records their source pins. The targeted lock update adds standalone richCluster and its previously absent dependency records: data.tree, dotCall64, fields, maps, networkD3 and spam. The historical R 4.5.2/Bioconductor 3.22 lockfile baseline is retained. This task does not establish that its entire package closure restores under R 4.6.1/Bioconductor 3.23.

## Isolated local verification

The implementation worktree is `.moai/worktrees/dependency-adoption` on `WT-dependency-adoption`, initially based on `27aac71c679009c2b61bb2118325dde690994ef1`. The implementation was committed as `8d3dcfee405b8f79abb771337fa5425fe3c3e7d2`; this identifies the source baseline, not a later documentation-sync commit or proof of push/deployment. Current verification uses the new front library `/tmp/richstudio-dependency-adoption-v015-lib-20261020`, followed by the protected 0.1.4 baseline library `/tmp/richstudio-dependency-adoption-lib-20261020` for other dependencies and the existing R 4.6 user library. All three pinned packages were source-installed into the new front library; do not overwrite the old baseline. Set both environment variables in the **same invocation** as each R command:

```bash
R_LIBS_USER=/tmp/richstudio-dependency-adoption-v015-lib-20261020:/tmp/richstudio-dependency-adoption-lib-20261020:/home/juhur/R/x86_64-pc-linux-gnu-library/4.6 \
RENV_CONFIG_AUTOLOADER_ENABLED=FALSE \
Rscript --vanilla -e 'cat(R.version.string, "\n"); print(.libPaths()); for (p in c("richR", "richCluster", "bioAnno", "Rcpp")) cat(p, as.character(packageVersion(p)), find.package(p), "\n")'
```

The new identity log records richR 0.1.5, richCluster 2.0.1 and bioAnno 0.99.45 resolving from the new task library under R 4.6.1; the Rcpp 1.1.2 overlay remains available from the protected fallback library. The Rcpp overlay resolves the observed `VECTOR_PTR` symbol failure with the pre-existing site Rcpp 1.1.0; it is local verification setup, not an unrelated lockfile refresh. Other packages may resolve from existing user/system libraries; their actual paths appear in the identity log. No shared library was modified.

The hashes above identify these exact downloads; they do not apply interchangeably to other archive endpoints or formats:

- richR release-built R source package: `https://github.com/hurlab/richR/releases/download/v0.1.5/richR_0.1.5.tar.gz`.
- richCluster GitHub commit archive: `https://api.github.com/repos/hurlab/richCluster/tarball/a0d1f630fbe64089ab38516116b78962672e6349`.
- bioAnno GitHub commit archive: `https://api.github.com/repos/guokai8/bioAnno/tarball/3c8936033b806b9f40c7028faa80e4971f6d0859`.

The richR 0.1.5 release asset is 2,769,042 bytes. Verify each download's SHA256 before installation. The richR release asset is an R-built source tarball and can be passed directly to R CMD INSTALL:

```bash
R_LIBS_USER=/tmp/richstudio-dependency-adoption-v015-lib-20261020:/tmp/richstudio-dependency-adoption-lib-20261020:/home/juhur/R/x86_64-pc-linux-gnu-library/4.6 \
RENV_CONFIG_AUTOLOADER_ENABLED=FALSE \
R CMD INSTALL --library=/tmp/richstudio-dependency-adoption-v015-lib-20261020 /absolute/path/to/verified-source.tar.gz
```

For the two GitHub commit archives, extract each into its own temporary directory and pass the extracted package-root directory (the directory containing DESCRIPTION) to the same `R CMD INSTALL --library=...` command. Do not treat a GitHub repository archive as interchangeable with an R-built source package. Archive download, extraction and identity checking must finish before installation.

Install required dependencies into that task library first. Do not copy compiled packages between R versions. Source-archive installation can leave `RemoteSha` fields empty in the installed DESCRIPTION, so version/path output must be paired with verified archive hashes and installation logs; version equality alone does not prove origin. An initial failed attempt activated an ignored, worktree-local renv bootstrap; it was not evidence of a successful dependency installation or a full restore.

## Local CI-matching R library

Local runs must resolve the same package versions as CI and the live server (R 4.6.1, Bioconductor 3.23, Posit PPM noble binaries); a stale user library once passed tests on shiny 1.12 that broke on shiny 1.14. The dedicated library lives at `~/.local/share/richStudio/rlib-r46-ci`, outside git and outside `~/R`; override the location with `RICHSTUDIO_DEV_RLIB`.

- `scripts/build-dev-rlib.sh` installs the full dependency closure of `DESCRIPTION` (plus the CI tools) into that library, then richR 0.1.5, bioAnno and richCluster from the pinned archives listed above. It aborts on any sha256 mismatch and only fills what is missing, so re-running is safe.
- `scripts/dev-r.sh <command...>` runs a command with the library first on `R_LIBS_USER`/`R_LIBS`, `RENV_CONFIG_AUTOLOADER_ENABLED=FALSE`, and prints an identity line (R, shiny, later, richR) to stderr.

```bash
scripts/dev-r.sh Rscript --vanilla -e 'pkgload::load_all("."); testthat::test_file("tests/testthat/test-workspace-jobs.R")'
```

Tests that start worker processes (`test-dependency-integration.R`) need richStudio installed rather than `load_all`ed: `scripts/dev-r.sh R CMD INSTALL --no-docs --library=<temp-lib> .`, then put `<temp-lib>` ahead of the dev library in `R_LIBS_USER`/`R_LIBS` and run `testthat::test_file(..., package = "richStudio", load_package = "installed")`. The system site libraries stay on the search path behind the dev library; the identity line shows which library wins.

## Consumer compatibility policy

These are the migration's implementation and acceptance targets; the SPEC's executable gates determine whether they pass:

- GO, KEGG and Reactome use explicit richR namespaces. Reactome uses `richR::enrich(x=..., object=...)` in both app and worker execution paths.
- An input filtered to zero query genes is an explicit failure. A valid analysis retaining zero terms remains a typed empty result. Neither case restores unfiltered input or fabricates biological rows.
- Existing result-column meanings, extra provider columns, comma-delimited GeneID membership and supported save/reopen behavior remain covered by consumer tests.
- Hierarchical clustering filters each normalized dataset using strict raw `Pvalue < min_value`, drops empty datasets, and calls the public standalone entry point with `filter_on="Pvalue"`, `min_value=1` and `gene_delim=","`. This preserves app policy rather than inheriting standalone 2.0.1's adjusted-p-value default.
- DAVID uses its public entry point without adding a significance threshold. Both standalone methods require one- and multiple-dataset coverage and correct dataset membership.
- The richR Kappa option uses `gene=NULL`, deriving the union of comma-delimited input term genes. It does not treat `TRUE` as a gene-background flag.

Keep three baselines separate: `richR::richCluster`, standalone richCluster's hierarchical/DAVID engines, and richStudio's own exported wrapper/native implementation. Standalone 2.0.0 corrected numerical clustering behavior; do not promise universal equality to historical outputs or silently recompute saved results.

New GSEA, explicit-background controls, diagnostics dashboards, batch-status UX and provenance/session-format features are outside this migration.

## Evidence and remaining gates

Current source-archive hashes, installation output and runtime identities are recorded in `/tmp/richstudio-v015-logs-20261020/{archive-sha256,install,identity}.log`. The read logs record the table's three hashes, successful source installation and `EXIT_STATUS=0`; all three pinned package paths point to `/tmp/richstudio-dependency-adoption-v015-lib-20261020`. These temporary paths are session evidence, not durable release artifacts. Original 0.1.4 identity/install logs and the old library remain protected as the failed historical baseline.

The [official-release SPEC delta audit](../.moai/reports/SPEC-DEPENDENCY-001/plan-audit-v015-delta.md) returned PASS. Final [independent consumer review](../.moai/reports/SPEC-DEPENDENCY-001/consumer-audit-v015-final.md) returned **PASS-WITH-DEBT**, accepting all ten ACs and closing F1–F7 on hash-bound installed evidence. The auditor's fresh R attempt could not create a temporary file; its verdict used inspected, bound execution artifacts and independent byte/source checks, not a fresh auditor test run. Producer CI was not counted as consumer acceptance.

Root's scoped invocation used the library prefix above with `RENV_CONFIG_AUTOLOADER_ENABLED=FALSE` and:

```r
testthat::test_dir("tests/testthat", package="richStudio", load_package="installed",
  filter="^(dependency-integration|dependency-kappa|file-management|reactive-values)$",
  reporter="summary", stop_on_failure=TRUE)
```

`/tmp/richstudio-v015-final-scoped-root.log` ends with `══ DONE` and records separate parent/worker processes resolving richR 0.1.5 for GO, KEGG and Reactome. `/tmp/richstudio-v015-existing-clustering-root.log` likewise ends with `══ DONE` for clustering-state and kappa; the implementation owner recorded exit 0 for both commands. Final acceptance includes named dataset columns, nonempty memberships/indices, strict per-dataset filtering, first/middle filtered-dataset identity mapping, observer valid-empty/rejection behavior, and the actual application writer/reopen plus legacy loading. `/tmp/richstudio-v015-ui-smoke.log` records installed UI construction and server initialization/closure. These are local consumer checks, not browser end-to-end or server deployment evidence.

The [focused quality report](../.moai/reports/SPEC-DEPENDENCY-001/quality-measurement.md) measures changed executable R-line coverage at **91/100 (91%)**. The selected-test package/native coverage is **776/3,872 (20.04%)**; that subset does not measure the full-suite overall target. Default lintr reports 26 changed-line style findings and zero warning/error findings on those lines; this is not an LSP gate result or proof of 26 regressions. Nine changed executable lines were not hit. Shiny/DT import and C++11 SystemRequirements warnings have original-HEAD counterparts; this is not a warning-free run.

The [numerical baseline report](../.moai/reports/SPEC-DEPENDENCY-001/numerical-baseline.md) now records all three engine identities. On one two-dataset Jaccard fixture, source-built standalone 1.0.2 and 2.0.1 grouped `{term-a, term-b, term-c}` and `{term-d}`, while off-diagonal values changed (`0.428571` to `0.75` for term-a/term-b), diagonal sentinels changed (`-99` to `1`), and merged genes became deduplicated unions. Original-HEAD and current richStudio vendored-engine source builds returned identical objects on their separate fixture. A successful unequal-size richR 0.1.4 fixture and its consumer adapter matched the explicit gene-union oracle. These measured baselines fill the historical-comparison requirement without asserting universal equality. The unequal-size richR comparison remains attributed to its actual 0.1.4 execution; final 0.1.5 acceptance separately covers the retained regression and union oracle.

Preserved 0.1.4 failure history: `/tmp/richr-consumer-cluster-fixture.log` records `EXACT_CONSUMER_CLUSTER_ERROR=arguments imply differing number of rows: 4, 0`; `/tmp/richr-namespace-only-integration.log` records missing kegg/path warnings and absent KEGG Level columns until attachment. The richR session executed those independent probes; this documentation task read their scripts/logs. These inherited-behavior findings are not established new-release regressions. The original AC-009 regression was retained and passes under installed 0.1.5 alongside the separate discriminating union oracle, balanced and single-clique fixtures; the old failure history is not overwritten.

The official 0.1.5 direct probes in `/tmp/richstudio-v015-oracles-root.log` returned balanced-group scores `7.5` and `5.5` and single-clique score `7`; final installed consumer tests also passed these expectations and the union-background contract. No private monkey patch or new analysis feature is included.

No full historical-lock restore, full package suite/check, full-suite overall coverage, LSP gate, browser end-to-end session, cross-platform consumer run or server deployment is established by these local probes. Upstream release/review/CI evidence is separate and does not close consumer acceptance.

## Deployment boundary

The development machine is the home computer. The measured target is Tailscale `100.94.67.89`, hostname `Hurlab.und.nodak.edu`, app `/home/juhur/shinyapps/richStudio`, baseline `fc124971b004fcbc24a212a40636d34cc57fd587`, R 4.5.2. Reverify identity and baseline before upload or execution; those observations are not permanent authorization to substitute another host or revision.

Follow [the dependency deployment procedure](DEPENDENCY_DEPLOYMENT.md): prepare the shell script, independently review it and review the finished script again, then upload it over Tailscale. Only the user executes sudo. Provide the exact reviewed script path, sudo command and private server temporary log/exit-status paths after staging. Retrieve and inspect those files after execution before claiming deployment. No local deployment or agent-run sudo is authorized; the existing project deployment gates remain in force.

Final [0.1.5 script safety review](../.moai/reports/SPEC-DEPENDENCY-001/deployment-audit-v015-final.md) returned **PASS** for exact script SHA256 `106a1d9b05f5302e94e188a3b50a0c82aed052303a3db89c17bb92a4d605cda5`, closing the obsolete-pin debt from round 3. Host permissions, R 4.5.2 execution, worker startup and real rollback remain unobserved. No upload or sudo execution has occurred at documentation preparation. Upload follows final documentation sync and push; script safety does not establish deployment.
