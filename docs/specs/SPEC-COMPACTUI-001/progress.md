# Progress — SPEC-COMPACTUI-001

## §E.1 Plan-phase Audit-Ready Signal

_Plan v0.1.0 independently APPROVED; see [the plan review](../../../.moai/reports/layout-density/plan-review-v010.md), SHA256 `4674d3ed391efb0722e214943f46076076a2e076a2550c337c08d6efd51aa59e`. This records plan approval only._

_Current plan v0.1.1 independently APPROVED; see [the amendment review](../../../.moai/reports/layout-density/plan-review-v011.md), SHA256 `7e5c44bafa1e81f9e579b9b6d035744e7eef7a04de1cf253d3336f036b1ffbbf`. This approval covers the narrow single CSS digest refresh and append-only preservation boundary only; no implementation result is asserted. The v0.1.0 approval above remains historical._

## §E.2 Run-phase Evidence

Frozen presentation candidate has scoped local evidence for AC-001–009. AC-010 remains pending hosted CI and final native-zoom guard diagnosis. Evidence is attributed to the [implementer report](../../../.moai/reports/layout-density/impl/report.md), [independent QA report](../../../.moai/reports/layout-density/qa/report.md), [32 authoritative QA cases](../../../.moai/reports/layout-density/qa/authoritative-results.json), and [independent source approval](../../../.moai/reports/layout-density/code-review-r1.md). These are local results, not a repository-wide or deployment verdict.

| Criterion / invariant | Actual Output | Status |
|---|---|---|
| AC-001 | Initial Run bottom526.265625 at1440×900 and1280×720; related controls share visual columns | PASS (local) |
| AC-002 | Matched populated span641.65625 /661.65625 against1044.34375 baseline, below783.2578125;38.56% /36.64% reduction; full review text/values unchanged | PASS (local) |
| AC-003 | All7menus captured at5viewports;15matched before/after pairs; narrow document heights decrease for all7; wide useful result allocations retained; wide full Enrich document increases because full-width results move below compact primary area | PASS (scoped QA) |
| AC-004 |35settled menu captures pass document/control containment;375settings stack;768/1024/1280/1440 remain contained; dynamic hierarchical/DAVID/legacy groups exercised desktop+narrow | PASS (scoped QA) |
| AC-005 |37matched buttons retain font/height; existing entry14px/review14px/label13px/help12px preserved;5viewport preview/commit/keyboard/navigation/resize journeys pass; native200%zoom guard remains separate pending diagnosis | PASS (scoped QA; zoom guard pending under AC-010) |
| AC-006 | Native7module×2namespace interface/caution guards2blocks/59assertions pass; complete review text/digest/defaults retained; preview0.1 stays separate from committed revision1 at0.05; real Reset defaults checked | PASS (scoped QA) |
| AC-007 | Unchanged desktop+narrow upload/commit, safe latched-worker Run/navigation and scientific session save/reload fixtures pass; evidence composes protected fixture journeys, not a new network enrichment/scientific validation | PASS (protected local fixtures) |
| AC-008 | Dense141/GSE366 and400/401/2000row protected cases pass desktop+narrow;18px row pitch/14px labels, values/NA/order and bounded keyboard windows preserved; actual PNG1000×7450 and1000×6890 inspected by QA | PASS (protected local fixtures) |
| AC-009 | Independent source review APPROVED;17non-UI raw spans/AST and all outside-UI bytes exact;155controlcalls/176namespaceoccurrences/44helpnodes preserved; all33777baselineCSSbytes exact prefix; only approved oneCSSdigestliteral refreshed by QA | PASS (independent source evidence) |
| AC-010 |22new +10unchanged protected browser cases pass; primitive guards6pass/2nativezoom Chromium-launch failures awaiting diagnosis; workspace-components R guard DONE; TypeScript exit0; hosted integrationCI unrun | PENDING (hosted + zoom diagnosis) |
| Non-UI bodies / interfaces | Independent native/raw checks verify17non-UI functions including7servers; UI formals and seven actual installed UI bodies match source | PASS |
| CRLF / append-only CSS | Seven CRLF files; old33777-byte CSS prefix exact;28938-byte original-prefix MD5 remains3dc7da1312126fb3a028db075e1c0e60; no primitive font/hit-area overrides appended | PASS |
| Candidate identity | Actual RDB7168c3b08d7865e6e26fd910d2c836162aa25776cd95162a15f9d3f8cea598bd; independently checked source/installed/served CSSb3c1ad641912f6597f5cdc6c2324fb59e66d70c38d2133efbb855cde30d1e78f | PASS |
| Formatting | Air0.12check:6Rfiles pass; Save's sole protected-helper indentation finding is byte-identical to baseline7be. Scratch baseline/candidate diffs retained in impl/format-final; no new formatting difference introduced | BASELINE FINDING (no blanket format PASS) |
| Cleanup | Each QA final phase records signal15/reapedtrue/errornull, PIDgone/port3871free; job fixtures report safe=true/portFreeAfter=true/scratchRemoved=true/ownedPIDsalive=false | PASS (recorded phases) |
| Scope / test integrity |8approved production paths only; all frozen production hashes rechecked stable; QA owns tests and sole CSSdigest refresh; earlier failed trials/collector diagnostics retained without weakening existing assertions | PASS (source scope) |
| Scientific / manuscript / deployment | Protected source digests exact; no manuscript, production data or deployment operation by implementer/QA | PASS (scope only) |

Implementer first6desktop cases passed; independent authoritative QA adds22newcases (15originalEnrich +5seven-menu +2dynamic) and10unchanged protected regressions. The initial wrong-subtree implementation trial and QA collector-authoring errors remain separately retained diagnostics. The current primitive run is explicitly6passed/2failed, not8passed; native Chromium launch failures need root/QA diagnosis. Root canonical tooling evidence under tooling/{prepare,scan,diagnostics} records prepare exit0 with12TypeScript inputs and5policy tests, scanner26documents/0findings/0errors with negative canary true, and actual JSON-RPC baseline/candidate diagnostics over27Rfiles each: candidate total0, runPASS/syncPASS/hasregressionfalse, TypeScript exit0. These are root-executed scoped checks, not a full repository test verdict. No local full-suite R tests, package check or coverage was run. Integration-branch hosted CI owns the repository-wide verdict: **PENDING**. No deployment verdict is asserted.

## §E.3 Run-phase Audit-Ready Signal

```yaml
run_complete_at: null
run_commit_sha: pending-root-commit
run_status: scoped-local-evidence-complete-final-guards-pending
ac_pass_count: 9
ac_fail_count: 0
ac_pending_count: 1
ac_scope: observed-local-evidence-not-hosted-completion
preserve_list_post_run_count: 17
l44_pre_commit_fetch: pending-root-git-owner
l44_post_push_fetch: pending-root-git-owner
new_warnings_or_lints_introduced: 0 # root actual27file baseline/candidate JSON-RPC comparison
lsp_run: PASS
lsp_sync: PASS
lsp_has_regression: false
scan: twenty-six-documents-zero-findings-zero-errors-negative-canary-true
prepare: PASS-twelve-typescript-inputs-five-policy-tests
formatting: six-R-files-pass; Save-protected-helper-identical-baseline-finding
cross_platform_build:
  linux: fresh-R-CMD-INSTALL-PASS
  macos: pending-hosted-CI
  windows: pending-hosted-CI
total_run_phase_files: 10 # implementer-owned eight production + two SPEC evidence/status files
m1_to_mN_commit_strategy: root-owned-explicit-path-commits-no-implementer-commit
candidate_manifest: .moai/reports/layout-density/impl/source-identity.json
candidate_runtime: .moai/reports/layout-density/impl/runtime-identity.json
candidate_qa: .moai/reports/layout-density/qa/authoritative-results.json
candidate_browser_cases: 32-passed # twenty-two new and ten unchanged protected
primitive_browser_cases: six-passed-two-native-zoom-launch-failed-pending-diagnosis
primitive_R_guard: DONE
repository_wide_verdict_owner: integration-branch-hosted-CI
repository_wide_verdict: PENDING
```

## §E.4 Sync-phase Audit-Ready Signal

```yaml
sync_complete_at: null
sync_commit_sha: pending-backfill
sync_status: local-evidence-retained-owner-policy-v012-public15-pass-native-receipts-pass
documentation: docs/quality/compact-workspace-layout-20261030.md
ac_source: docs/specs/SPEC-COMPACTUI-001/acceptance.md
tier: M
b12_self_test_a: not-run-no-CHANGELOG-emission
b12_self_test_b: not-run-no-CHANGELOG-emission
b12_self_test_c: not-run-no-CHANGELOG-emission
changelog_entry_position: none
frontmatter_status_transitions:
  completed: not-applied-no-status-transition-by-documentation
local_evidence:
  baseline: 7beaa52b3081721689586211f2d5fe530cc810ba
  candidate_head: 7355100cffd15d2999fde130bc85dfab8f78926e-plus-eight-frozen-production-edits
  new_browser_cases: 22-PASS
  unchanged_protected_browser_cases: 10-PASS
  primitive_browser_cases: six-PASS-two-native-Chromium-SIGTRAP-before-page
  primitive_component_R: 138-assertions-PASS
  rendered_control_R: two-blocks-59-assertions-PASS
  final_local_ledger: 40-cases-38-PASS-two-native-launch-FAIL
  QA_evidence_artifacts: 450
  cleanup: 16-recorded-PIDs-gone-two-ports-rebind-pass-failed-scratch-retained
  non_UI_definitions: 17-byte-exact-including-seven-servers
  installed_RDB_sha256: 7168c3b08d7865e6e26fd910d2c836162aa25776cd95162a15f9d3f8cea598bd
  CSS_sha256: b3c1ad641912f6597f5cdc6c2324fb59e66d70c38d2133efbb855cde30d1e78f
  preserved_complete_CSS_prefix: 33777-bytes
  canonical_LSP: 27-R-files-per-stage-candidate-all-zero-sync-PASS-release_hold-false
  formatter: baseline-identical-protected-Save-helper-indentation-Air-exit1
  AST: 26-documents-zero-findings-errors-canarytrue
canary_compliance_check:
  exact_CSS_digest_refresh: one-authorized-literal-no-assertion-relaxation
  control_help_and_science: preserved-source-and-scoped-runtime-evidence
post_deployment_evidence:
  public_browser: 15-PASS-zero-unexpected-skipped-flaky-console-page-errors
  public_cleanup: 30-specific-descendant-identities-and-three-workers-gone
  native_source: 275-tracked-274-immutable-match-one-explicit-runtime-log-exclusion
  native_installed_UI: seven-bodies-and-formals-equal
  independent_native_checks: PASS-bounded-machine-receipts
  owner_deployment: observed-e8fef99-live-active-public-CSS-b3
  production_scientific_full_suite_native_zoom: not-rerun
remaining_gaps:
  native_200_percent_zoom: unobserved-local-pre-page-SIGTRAP
```

This draft inspects actual `.moai/reports/layout-density/{impl/report.md,qa/report.md,
code-review-r1.md,security-final-r1.md}` and local tooling receipts. It records
32authoritative compact/protected cases separately from primitive6PASS/2launch
failures. Desktop primary-span reductions do not claim a reduced full Enrich
page: its wide populated document grows1831→2429px because previews remain below.
SPECv0.1.2 supersedes the historical v0.1.1 GitHub-CI prerequisite: no request,
run, review or wait is authorized. Scoped local checks and exact-candidate server
preflight are the gates; local native-zoom failures retain their actual status.
The owner executed deployment separately; current public/native audit evidence
is tracked in docs/quality/compact-workspace-post-deployment-20261030.md.
Root owns the final evidence/status decision.
No completion transition or commit is performed by this draft documentation task.
