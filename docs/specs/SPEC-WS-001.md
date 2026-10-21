---
id: "SPEC-WS-001"
title: "Measured baseline, scientific fixtures and verification harness"
version: "0.1.2"
status: in-progress
created: "2026-10-20"
updated: "2026-10-21"
author: "workspace planning team"
priority: P1
phase: "v0.1.7 target"
module: "R/"
lifecycle: spec-anchored
tags: "workspace, usability, reproducibility"
---

# SPEC-WS-001 — Measured baseline, scientific fixtures and verification harness

Planning-only draft. This existing-style leaf document is the self-contained implementation contract; no implementation/test completion is claimed. Companion umbrella: [SPEC-WORKSPACE-001](SPEC-WORKSPACE-001/plan.md).

## Problem and observable outcome

The existing installed-package regressions are a useful inherited reference. This initiative needs its own reproducible baseline and browser harness before behavior changes. The original planning snapshot did not run a fresh runtime suite. This bounded amendment responds to actual candidate01 clean-CI package-check/coverage failures and independent QA reproductions; it does not declare G0 passed or infer the pending candidate02 full outcome.

## Dependencies and ownership

- Logical prerequisites: none; first measured baseline.
- One lead implementer owns the unresolved001 contract. The explicitly bounded baseline-remediation child tasks below may use separate fresh worktrees, exclusive write/read locks and independent review. Child completion never approves or partially closes001; all G0 criteria still apply to one final integrated candidate.
- Shared targets are exclusive locks, even for nonoverlapping line edits; derive conflicts from the umbrella dispatch.json. No metadata/namespace edits outside this list without registry revision.
- Upstream richR work is separately owned and integrated through an official release, never edited by this consumer leaf.

### Existing targets

- `DESCRIPTION`
- `.Rbuildignore`
- `tests/testthat.R`
- `src/ClusterExport.cpp`
- `R/RcppExports.R`
- `man/richCluster.Rd`
- `tests/testthat/test-dependency-integration.R`
- `R/package.R`
- `NAMESPACE`
- `R/rr_cluster.R`
- `man/is_richCluster_available.Rd`
- `man/perform_clustering.Rd`
- `src/Makevars`

### New targets

- `.github/workflows/workspace-quality.yml`
- `package.json`
- `package-lock.json`
- `playwright.config.ts`
- `tsconfig.json`
- `tests/e2e/fixtures.ts`
- `tests/e2e/baseline.spec.ts`
- `tests/fixtures/workspace/README.md`
- `tests/fixtures/workspace/annotation.tsv`
- `tests/fixtures/workspace/query.tsv`
- `tests/fixtures/workspace/background.tsv`
- `tests/fixtures/workspace/imported-results.tsv`
- `tests/fixtures/workspace/legacy-session-v1.json`
- `tests/testthat/test-workspace-baseline.R`
- `scripts/test-workspace.sh`
- `scripts/export-workspace-policy.py`
- `docs/quality/workspace-policy-bundle.json`
- `inst/config/workspace-resources.json`
- `R/workspace_resources.R`
- `scripts/measure-workspace-resources.R`
- `tests/testthat/test-workspace-resources.R`
- `docs/quality/workspace-resource-baseline.md`
- `tests/testthat/helper-workspace-baseline-coverage.R`
- `tests/testthat/test-baseline-ui-workflows.R`
- `tests/testthat/test-baseline-result-figures.R`
- `tests/testthat/test-baseline-session-coverage.R`
- `tests/testthat/test-baseline-native-coverage.R`

## Technical implementation plan

1. Record exact Git SHA, R/package identities, worker library paths, OS, fixture digests and commands in one QA evidence ledger. Build/install the package, then test from an external working directory so source-tree loading cannot mask namespace errors.

2. Introduce a pinned TypeScript/Chromium CLI suite and a clean CI runner; own tsconfig.json with strict noEmit checking and explicit inclusion of playwright.config.ts and tests/e2e/**/*.ts. Run npx --no-install tsc --noEmit --project tsconfig.json and assert the resolved file list includes the config, fixtures and every current browser spec, rather than accepting an empty typecheck. Reuse existing testthat files without rewriting them. Check existing framework availability before adding dependencies. Add a policy exporter that reads the allowlisted canonical quality/harness/gate/security/LSP files from the primary repository, generates the reviewed tracked docs/quality/workspace-policy-bundle.json with source-relative paths, exact UTF-8 content and SHA256 digests, and checks that only intended non-secret policy content is exported. This is an automatically generated versioned snapshot, not a second manually maintained threshold definition. Regenerate and review it before the release candidate whenever source policies change. The exporter recursively resolves enabled gate rule/config references, including .moai/config/astgrep-rules/sgconfig.yml, referenced ruleDirs and all required rule assets, storing their canonical relative paths and content digests. Export a dependency inventory and fail on any missing enabled dependency, unexpected symlink or out-of-root production rule reference. Classify optional rule-self-test fixtures separately: the currently distributed sgconfig testConfigs path is not a scan dependency; if rule self-tests become a required gate their fixture closure must also be available, never silently skipped. Hosted CI verifies bundle digests, dependency inventory and schema, materializes canonical relative paths in an isolated policy root, and invokes configured tools with explicit isolated-root rules/config paths. For example, resolve the bundled rules directory into the supported moai --rules-dir argument and pin the ast-grep config path under that root; validate actual supported CLI flags at preparation. Run tools against the candidate code tree while all policy references resolve from the materialized policy root. No ambient primary-machine assets may satisfy a missing file. Record bundle digest and original source digests with every result. Missing bundle, malformed digest, unsupported tool or unresolved LSP policy/tooling disposition blocks G0; no threshold defaults or primary-machine absolute paths are allowed. Provision the actual R check/coverage/diagnostic and browser tools in CI from pinned manifests; archive their versions and gate outputs.

3. Create small synthetic annotation/query/background and imported-result fixtures with manually derived expected statistics, plus data-only legacy JSON. Real provider calls are a separate opt-in check; deterministic CI does not depend on annotation network availability. Generate a trusted legacy RDS fixture during the compatibility test rather than checking executable or opaque R objects into source.


4. Produce the application resource policy before 004/006/007 consume it. The001 implementer owns inst/config/workspace-resources.json and R/workspace_resources.R; QA owns measurement and security reviews trust-boundary limits. scripts/measure-workspace-resources.R measures bounded synthetic small/representative upper-size inputs and records bytes/rows/columns/strings, decoded table memory, archive expansion/member count/depth, table/graph render sizes, worker admission/history retention, and temporary-disk cleanup. Run serially with externally bounded processes and framework cleanup, no unbounded contention. Record exact runtime/fixtures, peak-memory/disk observations and justified safety headroom in docs/quality/workspace-resource-baseline.md. Select/review actual limits only from these observations and target-host constraints; do not invent numbers in this planning document. The loader validates schema and finite positive limits, resolves the installed config, and fails closed on absent/invalid policy.004/006/007 depend on G0 acceptance of this artifact;011 repeats/refines the same measurements, not first creates them. Boundary tests cover at/above configured limits.

## Bounded baseline-remediation amendment — pending independent plan audit

This amendment authorizes only the target-declared work below **after independent plan-audit PASS**.001 remains unresolved;002 stays blocked until the complete G0 gate passes. No new SPEC node, partial approval, milestone-dependency language, quality waiver or downstream cycle is introduced. The prior exclusion against arbitrary runtime repairs is retained with these explicit documentation, equivalent-import, portable-build and test exceptions.

### Mechanical premise and limits

Actual candidate01 full CI at source519dbfff67e013fe361c13a99c64687feb4d1917 recorded62 installed tests/408 assertions passing with zero failures, but R CMD check recorded2 errors/7 warnings/5 notes and full coverage832/3900 lines. The full job exited1. The example error is undefined termNames in the generated richCluster example; the check test has three failures at test-dependency-integration.R:127, asserting a worker package-parent substring occurs in library paths. These raw receipts remain under `.moai/reports/SPEC-WORKSPACE-001/implementation/ci/candidate-01/full/`; passing installed tests do not imply passing package check.

Independent QA subsequently reproduced the published example error unchanged. A controlled library-symlink counterexample loaded correct richR0.1.5, produced old_predicate=false and canonical_package_predicate=true, and cleaned the owned worker. This proves that substring predicate can reject a correct origin; it does **not** prove the alias mechanism caused the actual CI failures. Separate parent/worker instrumentation calibration observed instrumented package identities and two helper hits in both; no instrumentation defect was reproduced. Coverage therefore needs meaningful existing-behavior characterization rather than assumed denominator/instrumentation repairs. Evidence: the retained `qa/ci01-classification/report.md` and `qa/ci01-classification/{example.stderr.log,library-alias-counterexample.json,calibration-identity.json,calibration-coverage.rds}` in the same implementation report directory.

Candidate02 full-suite/check/coverage outcome is unknown at amendment preparation and must be attributed only after actual receipt. Its independently reported narrow-viewport navigation case is diagnosed/fixed within the already-owned tests/e2e/fixtures.ts scope, with actual trace evidence. No conclusion about its cause or full gate is asserted here.

### Exact child ownership, prerequisites and locks

These are implementation sub-tasks of the single001 node, not lifecycle states or additional feature requirements. Only declared production files may change, and only as the explicitly bounded documentation, equivalent import-binding and portable build-metadata changes below. R/rr_cluster.R and src/ClusterExport.cpp changes are documentation comments only; no runtime function/native algorithm change is authorized. Future feature-source files remain read dependencies, not repair permission.

| Child / role | Exclusive write targets | Prerequisites | Locked read/compatibility dependencies |
|---|---|---|---|
| B0 — QA fixture/instrumentation implementer | tests/testthat/helper-workspace-baseline-coverage.R | Frozen current001 fixture/runner/policy candidate | Existing annotation/query/background/import fixtures; R/workspace_resources.R; DESCRIPTION; NAMESPACE |
| B1 — documentation/generator implementer | src/ClusterExport.cpp (documentation comments only); R/RcppExports.R (generated docs); man/richCluster.Rd (generated docs) | Independently verified example reproduction and frozen generation toolchain | src/RcppExports.cpp byte preservation; all exported wrapper names/formals/registration; NAMESPACE snapshot owned by B7 |
| B2 — worker-test implementer | tests/testthat/test-dependency-integration.R | Frozen installed dependencies; B0 helper if reused | R/deg_enrich.R; R/workspace_resources.R; scripts/test-workspace.sh; parent/worker namespace and library receipts |
| B3 — UI characterization implementer | tests/testthat/test-baseline-ui-workflows.R | B0 and B7 reviewed/integrated | R/home_tab.R; R/runApp.R; R/cluster_upload_tab.R; R/enrich_tab.R; R/rr_column_handling.R; R/file_handling.R; R/cluster_tab.R; R/update_tab.R |
| B4 — figure/result characterization implementer | tests/testthat/test-baseline-result-figures.R | B0 and B7 reviewed/integrated | R/clus_visualize_tab.R; R/rr_visualize_tab.R; R/rr_bar.R; R/rr_dot.R; R/rr_hmap.R; R/rr_network.R; R/cluster_hmap.R; R/round_table.R |
| B5 — session characterization implementer | tests/testthat/test-baseline-session-coverage.R | B0 reviewed/integrated | R/save_tab.R; R/file_handling.R |
| B6 — public/native characterization implementer | tests/testthat/test-baseline-native-coverage.R | B0, B1, B8 and B9 reviewed/integrated | R/rr_cluster.R; R/RcppExports.R; src/ClusterExport.cpp; src/RcppExports.cpp; src/ClusterList.cpp; src/ClusterList.h; src/ClusterManager.cpp; src/ClusterManager.h; src/DistanceMatrix.cpp; src/DistanceMatrix.h; src/DistanceMetric.cpp; src/DistanceMetric.h; src/MergeStrategy.cpp; src/MergeStrategy.h; src/SeedMap.cpp; src/SeedMap.h; src/StringUtils.cpp; src/StringUtils.h |

| B7 — package import/generator implementer | R/package.R (import annotations only); NAMESPACE (generated) | Frozen installed Shiny/DT/richR/dplyr/plotly public identities; direct installed-module failure and binding evidence | All existing package exports/formals; DT current winning bindings; public richR::ggnetwork, dplyr::distinct, plotly::plotlyOutput/renderPlotly; B1/B8 generator snapshots |
| B8 — R documentation/generator implementer | R/rr_cluster.R (documentation comments only); man/is_richCluster_available.Rd; man/perform_clustering.Rd (generated) | Actual codoc/usage warning and frozen generation toolchain | R/rr_cluster.R parsed expressions/body/formals unchanged; public defaults/arguments; NAMESPACE snapshot owned by B7 |
| B9 — platform/build implementer | src/Makevars; DESCRIPTION (verified test later/withr declarations and supported compiler metadata only) | Frozen native source/object inventory; actual build warning receipt | All native source/body/registration; R/RcppExports.R public ABI; dependency pins/Remotes; compiler/toolchain identities |

Every writer excludes overlapping readers/writers until its diff is independently reviewed and integrated. B1/B7/B8 generator runs serialize on generated metadata snapshots even where only byte-identical side effects are expected; no unassigned generated file may change. B1 and B8 documentation and B9 build complete before B6 consumes the public/native snapshot. B7 import/generator closure completes before B3/B4 actual installed UI/module/render probes; controlled function-copy experiments cannot satisfy this barrier. B3/B4/B5/B6 have distinct test write files and may run only within actual agent capacity once B0 is available. Shared helper changes go through B0's owner; no concurrent helper edits. B9 exclusively owns the bounded DESCRIPTION changes; the001 lead retains runner/config and browser fixture ownership. Their changes are serialized against dependent readers. B9 may declare the mechanically verified direct test dependencies later and withr without removing valid application dependencies or altering pins. B5 independent-review F2 and direct withr:: calls establish the withr declaration gap; no package-check failure attributed to it was reproduced. Root/lead owns dispatch and exact snapshot integration; QA owns unified baseline/evidence; an independent reviewer approves each child diff; security reviews any new worker/session fixture cleanup boundary. No self-review or unbounded background verification.

### Permitted correction and characterization contract

- **B1:** define tiny deterministic termNames/geneIDs/pValues in the actual documentation source; regenerate with established Rcpp/roxygen tooling. Preserve native algorithm, public richCluster name, formal names/order, registration and non-documentation wrapper semantics. src/RcppExports.cpp must remain byte-identical; NAMESPACE changes only through B7, and B1/B8 generator runs preserve that approved snapshot. Other generated outputs require an exact reviewed amendment before changes. Do not use donttest/dontrun/skip to hide a failing runnable example. Installed examples and R CMD check must execute it successfully.
- **B2:** record parent/worker PID, package versions, normalized package paths, all library paths and relevant environment before comparison. Replace the mechanically disproven substring assumption with strict canonical per-library package resolution that recognizes valid aliases while still rejecting a wrong package origin/version. Keep distinct-worker, exact engine version, intended loaded namespace, GO/KEGG/Reactome dispatch, numerical result and saved-table assertions. Include valid-alias and wrong-origin/version negative cases; diagnose real CI context instead of asserting that the counterexample establishes its cause.
- **B7:** in the already-owned R/package.R import annotations and generated NAMESPACE, resolve the measured duplicate Shiny/DT imports and add only verified public richR::ggnetwork, dplyr::distinct and plotly::plotlyOutput/renderPlotly bindings. Plotly additions are conditional on the reproducible direct installed-module initialization errors documented by B4, not a claim that deployed runApp was broken. Before/after installed-package checks must prove dataTableOutput and renderDataTable remain the currently winning DT functions with identical formals; preserve all public exports/argument names, other used bindings and dependency pins. Regenerate, never hand-edit NAMESPACE. Require actual external-CWD installed namespace UI construction, module initialization, real rendered/network/heatmap probes using valid explicit gene inputs and generator replay; compare functions/data/results before/after and retain diagnostics. Controlled function-copy public-binding probes are investigative evidence only. No private richR:::reverseList import, my_net repair, science/algorithm change or broad namespace cleanup is authorized. The default comma-input ggnetwork and top-term substring-retention counterexamples remain retained under008/009; do not alter expectations or add expected-error coverage tricks to call them fixed. B4 remains held until B7 integrates and its supported assertions are rerun against that actual installed namespace.

- **B8:** align documentation exactly with the existing is_richCluster_available require_package/package_version formals/defaults and perform_clustering raw_genesets parameter. Modify only roxygen comments in R/rr_cluster.R and regenerate the two named Rd files. Compare parsed code/function bodies/formals before/after and require equality; do not fix NSE/naming/style diagnostics or modify clustering logic here. Generator replay, codoc and Rd usage checks must demonstrate closure of the measured warnings.
- **B9:** replace only GNU/nonportable Makevars discovery/forced optimization metadata with portable declarative package build metadata. Use R's default object discovery only if its actual object inventory equals the current intended native source closure; otherwise declare a portable literal object list. Preserve required include/link behavior, registration and all native source algorithms. Remove project-forced nonportable O2 flags rather than disabling compilation checks; retain compiler defaults and capture actual compiler commands/object/native symbol inventories. Build before/after on supported R/toolchains and run the three public clustering routes/ABI fixtures with recorded expected values. DESCRIPTION may declare verified later and withr direct test use and align obsolete C++11 metadata only after supported compilation proves the actual requirement; do not impose an unverified newer minimum, change algorithms or introduce a native port. Preserve all other dependency pins, package API and meaningful comments.
- **B0/B3–B6:** characterize existing supported input/error/state/result semantics with deterministic data and real assertions. Cover supported UI/module workflows, import normalization, clustering state/methods, plot row/value selection, session persistence and public native options/edge invariants. Do not implement future workspace features, mirror source control flow, simply execute lines, delete untested code, hide branches, add broad mocks or alter scientific expectations to obtain coverage. A discovered runtime failure requires separate reproduction and an exact audited source-target amendment; it is not automatically authorized here.
- **Instrumentation:** the coverage runner must retain source SHA/digests, policy/denominator, installed instrumented richStudio parent and actual worker package/library identities and calibration hits. Do not infer missing instrumentation from low coverage or substitute a coverage denominator excluding modules/native code. Preserve raw coverage object/XML and per-file totals.
- **Verification:** each child runs affected tests with external timeout and cleanup guarantees locally. Actual complete tests, package check, examples and full-package coverage run only in clean CI against one integrated candidate. Apply the canonical snapshot's required full-coverage target (the candidate01 receipt records85) without lowering it or hard-coding a new policy; missing tools/skips/failed required checks keep G0 open. New tests must satisfy the canonical per-change requirements as well. No partial child pass closes001.

### Acceptance binding and gate preservation

The existing six REQ declarations and five AC scenarios below are unchanged. B0–B9 and their receipts are a concrete execution/ownership expansion for REQ-001/002/004 and AC-001/002; they do not replace any criterion. AC-001's full suite and actual installed identity must now be demonstrated together with successful required package check/examples and canonical full coverage; AC-002 still proves failures propagate. AC-003/004/005 browser, policy/typecheck and resource obligations remain mandatory. No canonical policy, result semantics, public ABI or denominator changes are authorized. The sole explicit application-versus-CRAN-submission check-profile decision below requires independent plan review; no other check disabling or suppression is authorized.

### Narrow remote-only application-check profile — confirming plan review required

The reviewed master incoming-FALSE proposal is rejected by actual PREP: strict no-exercises warned, while master-FALSE silently passed that same package. Preserve the original raw profile attempt, blocker and stale unresolved-list receipts as historical evidence; do not rewrite or relabel them. The latest frozen PREP runner SHA256 `bab42edd5d8327cd253cf0e152194685b6f8b63e3c84e8cae5d377bd760543fe` adds the bounded local URL companion and remains default-profile blocked. Prior runner fc0aebf3 and its rejected master-FALSE evidence remain retained unchanged. This planning revision does not authorize a source/default switch before confirming independent plan-audit PASS and root review.

The supported proposed application profile is exactly `args=c("--no-manual", "--as-cran")`, `error_on="warning"`, master `_R_CHECK_CRAN_INCOMING_=TRUE` and narrow `_R_CHECK_CRAN_INCOMING_REMOTE_=FALSE`. Both strict/narrow proof profiles retain explicit `_R_CHECK_OVERWRITE_REGISTERED_S3_METHODS_=TRUE` and `_R_CHECK_AUTOCONF_=TRUE`, matching the measured PREP controls. Master TRUE preserves the original direct check_incoming code-exercise/S3/autoconf branches; do not revive master FALSE or build a new research framework. Keep canonical coverage target, full unmodified R/native denominator, diagnostics and all other gates unchanged. No waiver or CRAN-submission readiness claim is permitted.

**Exact intentional scope:** exclude external CRAN repository availability/strong-dependency publication eligibility and external URL/DOI/arXiv/ORCID/ROR liveness only. Preserve local parsing/syntax, Rd databases/local URI validation, code, example, test and build controls. Do not claim all documentation checks are identical: remote documentation/identifier liveness is explicitly outside this application gate. Valid pinned GitHub dependencies/Remotes remain unchanged; any remaining local package warning still fails under error_on="warning" and needs its actual scoped disposition, not suppression.

**D1 local URL preservation — bounded companion inside the existing runner:** remote FALSE omits not only external liveness but installed tools local literal-space and canonical CRAN/R-project URL predicates inside a remote-guarded call. Keep the external exclusions exact and preserve these omitted local findings using the installed source expressions, not a copied checker. The runner may evaluate only fixed expressions4,9,10,12,13,14,15,18,23,24 from the exact installed tools function, supplying .gather, .check_http_B, mirror data and original URL/HTTP eligibility setup. Do not replay HTTP/FTP/header/network branches, fork the checker, modify tools, or introduce an AST/research framework. Guard exact R/tools version, complete source bodies and fixed shapes, mirror bytes, formatter, actual URL enumerator and original severity-wrapper digests; an unknown value/error fails PREP and holds G0.

Enumerate the actual candidate source URL database with its source snapshot/hash and From attribution; retain the complete before/added/combined findings and visible original formatter output. Preserve real-source NOTE classification from the original incoming wrapper: zero findings may be CLEAN; findings must be visibly emitted and produce PASS_WITH_NOTES with their count/status. Under unchanged error_on="warning", original local URL NOTEs remain nonblocking; this is not clean output, and no existing WARNING/ERROR may be downgraded. Fatal guard/execution errors or missing observations remain blocking. Expected synthetic canary findings are separate from the real-source finding disposition, never counted as application cleanliness.

The retained PREP/url-companion evidence supplies actual RED remote-FALSE omission and ten real-source-URL-database controls: four valid/no-findings and six intended local findings (spaces, canonical CRAN forms/mirror exception, canonical R-project). Final frozen Git source e2a8ac9f had5 records/3 unique URLs/0 findings, CLEAN. A separate actual-input literal-space invocation visibly emitted the original NOTE and recorded PASS_WITH_NOTES/findings1/nonblocking_under_error_on_warning; this proves notes are surfaced without inventing stricter severity. Source/version/body-shape guard negatives failed as intended. These are focused companion results only: no new fourteen-case package-check run or full application check was performed. Every later composed source must receive fresh enumeration; the five-record snapshot is not attributed to B1 or a future candidate.

**Source/version anchored evidence:** PREP report/experimental-narrow-summary.json and adjacent experimental-narrow-remote artifacts record installed R4.6.1 tools source-body digests, exact environments, result RDS, intended diagnostics and section inventories. The observed .check_packages source independently parses master/remote and calls the incoming helper with localOnly=!remote; the helper's localOnly return precedes remote repository/eligibility checks, while external URL/identifier checks use its remote flag. These exact source/version records define the supported proof; a new R/tools body requires the same bounded local verification, not an assumption that counts alone establish equivalence.

**Mandatory fourteen outcomes:** actual authorized experimental evidence measured valid SUCCESS under strict and narrow profiles, then intended rejection under BOTH for six invalid cases: code, documentation, example, test, build and no-exercises. That is seven cases times two profiles. Each valid control must succeed with required sections executed; each invalid must be rejected for its intended defect with section/diagnostic/exit retained. Warning-only documentation/no-exercises can have R CMD check status0 yet still be rejected by unchanged rcmdcheck error_on="warning"; never confuse status0 with successful acceptance. Unrelated setup/network failure, unavailable tool, timeout, skipped section or missing observation is not proof. The recorded pairs have equal normalized section lists (valid/code/doc/example/test48, build12, no-exercises47); this is canary evidence, not a blanket identical-documentation claim or full application check.

Root-authorized PREP experiment exited0 with all14 expected outcomes, but remains experimental until this exact plan choice is confirmed and independently reviewed. Actual default-profile implementation, fresh installed identities, paired controls and clean integrated CI still govern acceptance. Missing intended outcomes or loss of any preserved local/code/doc/example/test/build control keeps PREP/G0 held; no weaker standard-profile fallback or extra check-disabling variable is allowed. The existing001 runner owner implements only this narrow switch within its declared source path after approval, retaining original/master-FALSE raw evidence and new proof side by side.

Candidate01 warning categories retain exact owners: duplicate/import additions B7; codoc/usage B8; portable build flags/Makevars and verified direct test later/withr metadata B9. The new scope addresses external publication/availability only; no remaining code/doc/build/test warning is claimed solved by this plan. G0 stays OPEN and002 stays blocked until one actual integrated candidate satisfies all gates. Later G5 diagnostic cleanup, private my_net helper and deferred scientific counterexamples remain outside001 implementation scope.

## GEARS requirements

- **REQ-001** The verification harness shall record the exact measured source, installed package origins, commands, exit codes, pass/fail/skip totals and retained artifacts.
- **REQ-002** When a required test is skipped, unavailable or fails, the gate shall remain incomplete rather than report success.
- **REQ-003** The browser suite shall run via Playwright CLI with accessible locators and web-first assertions on desktop and narrow-screen viewports.
- **REQ-004** When the baseline is measured, the harness shall characterize enrichment, all three clustering routes, raw/adjusted threshold semantics and version1.0 session data without imposing old-engine numerical equivalence.
- **REQ-005** When isolated gate preparation runs, the harness shall verify the policy dependency closure and typecheck every intended browser-test input before reporting readiness.
- **REQ-006** When G0 is evaluated, the baseline shall include a measured, reviewed application resource configuration and validated loader before its consumers dispatch.

## Binary acceptance scenarios

**AC-001** Given the clean baseline commit and pinned fixtures, when the QA command installs and tests the app, then the receipt identifies exact package paths and full-suite totals with no source-only substitute.

**AC-002** Given a deliberately broken fixture expectation, when the CI workflow runs, then the job fails and retains its diagnostic artifacts.

**AC-003** Given a Chromium run at 1280x720 and 375x667, when navigation and fixture upload complete, then the suite asserts visible state using roles/labels/test IDs without hard sleeps.

**AC-004** Given a bundle missing a referenced enabled rule or an empty TypeScript file set, when clean preparation runs, then it fails before a gate can pass; a complete bundle resolves all required assets from the isolated root and typechecks the intended config/fixtures/specs.

**AC-005** Given representative bounded fixtures, when resource measurement and review complete, then the documented runtime observations justify each configured input/archive/worker/history/render limit, the installed loader reads them, and at/above-limit tests demonstrate enforcement before 004/006/007 dispatch.

All requirements must be exercised by the listed scenarios plus scoped tests; verification receipts identify the specific REQ/AC IDs. Disabled controls are valid intermediate/rollback containment only; they do not close the desired capability or justify full-program completion. Required feature criteria remain unresolved until demonstrated or explicitly re-scoped by the user.

## Scoped verification and gate evidence

- Run existing affected tests first; measure the clean full R suite/check and coverage in CI, never infer them from six deployed files.
- Run installed namespace enrichment/worker and three-engine clustering fixture tests; record any pre-existing failure separately and block the relevant surface until resolved.
- Run headless Chromium smoke, inspect artifacts, and test one intentionally failing harness assertion before removing that deliberate failure.
- Follow the canonical primary-repository quality/harness/LSP policies; record exact snapshot digests in CI. Do not duplicate their numerical thresholds here.
- Report commands, verbatim bounded outputs, commit/runtime baseline, gaps and residual risks. Full-suite phase gates run in clean CI; local checks are scoped to affected behavior.

## Requirement-to-acceptance traceability

| Requirement | Required scenarios |
|---|---|
| REQ-001 | AC-001 |
| REQ-002 | AC-002 |
| REQ-003 | AC-003 |
| REQ-004 | AC-001 |
| REQ-005 | AC-004 |
| REQ-006 | AC-005 |

## Security and trust boundary

Synthetic fixtures only. No patient data, secrets or browser storage in committed traces. Limit artifact access and redact temporary/server paths where needed. Provider credentials are not introduced.

## Rollout and rollback

Keep workflow additions isolated; revert the harness commit without touching runtime modules. A failed baseline blocks later feature implementation. The independently audited bounded documentation/test remediation above may proceed within unresolved001; arbitrary production runtime repairs remain excluded; only the declared equivalent imports/build metadata and documentation/tests are permitted. Revert each child independently without deleting original failing receipts or claiming a partial G0 pass.

## Exclusions

### Out of Scope — Scope discipline

- Runtime redesign, production deployment or claims that historical deployment tests constitute this baseline.
- Production R/native algorithm repairs, API/formal renaming, broad diagnostic cleanup/suppressions, deleted code, changed denominators or skipped examples/checks; only the explicitly declared documentation/generated documentation, behavior-equivalent duplicate-import correction, portable build metadata and test-only characterization/worker assertion work are added by this amendment. CRAN publication is not an application release criterion; only its incoming suitability component is explicitly scoped as stated above.

## HISTORY

- 2026-10-20: Planning-only draft, authored after repository inspection and Hur Harness team consultation.

- 2026-10-20: Bounded G0 ownership amendment v0.1.1 proposed after actual candidate01 check/coverage failures and independent QA example/alias/instrumentation probes; child execution requires independent plan-audit PASS. Six REQs/five ACs and the twelve-leaf dependency graph remain unchanged; candidate02 full outcome not inferred.

- 2026-10-20: Pre-audit bounded revision assigns all measured check-warning classes,40 exact writer targets and B7/B8/B9 import/docs/build owners; explicitly selects the application check profile with only CRAN incoming suitability scoped, preserving all original REQ/AC/gate thresholds and pending independent audit.

- 2026-10-21: v0.1.2 proposed narrow remote-only profile after actual master-FALSE PREP rejection and14 intended experimental outcomes; bounded B7 public imports/direct installed-module proof added. Forty targets, ten children, original six REQs/five ACs and twelve-node DAG remain unchanged; independent confirming plan review required before any source/default switch.

- D1-only confirming revision: preserve omitted local URL findings through the exact guarded installed-source companion and original NOTE acceptance; add only verified direct withr test dependency alongside later in B9. Prior profile/B7 boundaries,40 writers,10 children,6 REQs/5 ACs and12-node DAG unchanged; no source/default switch before confirming plan audit and root review.
