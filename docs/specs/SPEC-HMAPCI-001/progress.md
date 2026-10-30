# Progress — SPEC-HMAPCI-001

## §E.1 Plan-phase Audit-Ready Signal

_Plan v0.1.0 independently APPROVED; see [the plan review](../../../.moai/reports/heatmap-legibility/hmapci-plan-review-v010.md). This approval covers the plan only._

## §E.2 Run-phase Evidence

### Final hosted evidence backfill — run 41076765375

**Current closure evidence, inspected from retained hosted artifacts.** Canonical
integration-branch run `41076765375`, source
`4bc65b3c9068f07f64e08a1b043a0f8913d469fa`, is **completed / success, 7/7 jobs**:
prepare, diagnostics, scan, negative, resources, browser and full. Final completion
is `2026-10-30T15:58:22Z` (`hosted-41076765375/final-state.json`). This closes the
current hosted acceptance requirement; earlier failed/pending snapshots below
retain their original source/time attribution and are superseded for current status.

Inspected actual artifacts under `.moai/reports/heatmap-portability/hosted-41076765375/`:

- `full/workspace-quality-artifacts/testthat-totals.json`: **263 tests / 3125
  passed assertions, failed 0, errors 0, skipped 0, warnings 0**.
- `full/workspace-quality-artifacts/R-check/richStudio.Rcheck/00check.log`:
  `* checking code files for non-ASCII characters ... OK`, `* DONE`,
  `Status: 5 NOTEs`; **0 errors, 0 warnings**. The five NOTE sections are CRAN
  incoming feasibility, top-level files, dependencies, possible code problems
  and examples; no claim of CRAN publication readiness is made.
- `full/workspace-quality-artifacts/check-profile/receipt.json`: `status: PASS`;
  **14/14 strict/application canaries** completed, execution_failure false and
  intended_diagnostic true. Existing strict gates remain effective.
- `full/workspace-quality-artifacts/coverage-file-totals.csv` sums to
  **8737/9521 covered lines = 91.7655708433988%**; `coverage.xml` independently
  records line-rate `0.917655708433988`; the canonical hosted coverage gate passed. This is
  the final run measurement, not the earlier b7 coverage value.
- `browser/workspace-quality-artifacts/browser-results.json`: **66 expected,
  0 unexpected, 0 skipped, 0 flaky**. Native semantic cell/pixel assertions ran
  on the final candidate. `serve-terminal.json` records configured lifetime1800,
  status−15/signal15, reaped true, error null.
- `diagnostics/workspace-quality-artifacts/lsp-diagnostics.json`: candidate
  errors/warnings/information/hints/lint_errors/total **all 0**; sync PASS,
  release_hold false. `scan/workspace-quality-artifacts/ast-grep.json`:
  **26 executed documents, 0 findings, 0 errors, canary_detected true**.

`full/.../source-digests.json` was compared with current file SHA256 values:
`R/cluster_hmap.R` = `2380f070b6a85421960e9ecd0af29d64e60ee0eca94d7e78852fbedd2c11cf38`;
`R/clus_visualize_tab.R` = `bf5dcb5e0d3eb7715ec9823c40c57fbb9686a7831dcc71be616eb2db568f50fb`;
`DESCRIPTION` = `fadc8cda247581b65ea6015b1aac4e9d984e6afd8f42dabd6c6e23071ced714a`;
runner = `bb9f1e776f58cf5c791b5e77893091828477f25ae58fff5edca404b29a16121d`.
All four match the hosted source receipts. The two representation changes are
separately authorized by SPEC-HMAPPORT-001; original R5 source hashes below remain
historical, and independent installed equivalence preserves their behavior:
31 tests/337 assertions, 92 actual observable comparisons and four scientific
goldens pass, native UI HTML/raw/serialized display bytes identical. Thirteen
diagnostic title Encoding() marks change unknown→UTF-8, explicitly recorded.
Independent `code-review-r1.md` approves the exact portability source and inverse
byte proof; the AST diagnostic's abandoned errors are not product defects.

Attribution: these hosted tests/checks/coverage were executed by GitHub Actions;
this Implementer inspected the retained JSON/CSV/XML/check log using Python,
`tail`, `rg`, and `sha256sum`-equivalent hash computation, and inspected prior
owners' QA/review receipts. No local full suite/check/coverage was rerun. The
canonical integration-branch CI run now owns a **PASS** repository-wide verdict.
Historical −9, old reset terminal status, old MV3/bootstrap and local SIGTRAP
causes remain unproven; final success does not establish those causes. Deployment
is outside this measured closure. Windows/macOS execution was not observed.

Measured candidate: isolated tree `/home/juhur/.moai/worktrees/projects/richStudio/heatmap-ci-stability`, parent HEAD `61dee8615a5c6f3a8831f933efa2bcdddfd61b98`; uncommitted harness diff. Plan review `hmapci-plan-review-v010.md` is APPROVED. Root owns commit/push after independent review.

| Scenario / invariant | Actual Output | Status |
|---|---|---|
| AC-001 frozen product and gates | `frozen-invariants.log`: application R/src/inst/DESCRIPTION/NAMESPACE unchanged; pinned URL/SHA tables and all workflow configuration identical except archive Python and the prepare-only focused-control hook; three released product hashes match. | PASS |
| AC-002 recoverable ownership proof | Actual extracted fixture helper and fixture closure: delayed nonce admitted only on matching fresh PID/start/group+nonce; real owned subprocess cleanup succeeds. `controls-wired/ownership-results.json`: 9/9 subcases passed. | PASS |
| AC-003 unsafe ownership proof | Persistent foreign, permission, reused PID and dead-owner controls fail; actual cleanup spy signals are empty. QA found empty-list/dead-owner admission in round1; round2 requires proven live owner before readiness and before use. | PASS |
| AC-004 viewport/pixels | Final hosted browser66expected/0unexpected/0skipped/0flaky; existing semantic cells, hover, RGBA and native region-scroll assertions pass. Earlier freeze pending status is historical. | PASS |
| AC-005 finite serve evidence | Same `serve_watchdog` path: controlled timeout status124 and normal status7, real identity/start/group receipts and reaped child. Production call fixed1800; no production override. | PASS |
| AC-006 transport recovery | Actual workflow Python: reset/TLS EOF/timeout→valid recover; three interrupted attempts stop; verified digest precedes one installation; durable per-attempt receipts. | PASS |
| AC-007 integrity/hard failures | HTTP/certificate/digest/install controls each stop without retry; digest mismatch never installs. Focused transport matrix: 10/10 scenarios passed. | PASS |
| AC-008 unchanged full profile | Full `check_profile()` source compared byte-for-byte with parent HEAD; timeout90 remains. Original hosted−9 cause is still unobserved; no local full suite/check/coverage run. | PASS |
| AC-009 same-source hosted closure | Canonical run41076765375 completed success7/7 at source4bc65b3c9068f07f64e08a1b043a0f8913d469fa; final full/check/coverage artifacts pass. | PASS |
| TDD evidence | Before edits QA retained `ownership-red.log`, `baseline-scientific.log`, `transport-watchdog-red.log`; own `impl/lifecycle-red.log` shows original one-read failure. After fix `controls-wired.log`: Ran3 tests / OK. | PASS |
| Type/syntax baseline | Baseline and final `tsc --noEmit --project tsconfig.json` exit0, empty logs. `bash -n` and embedded workflow/watchdog Python parse exit0; `git diff --check` exit0. | PASS |
| Application-source exclusion | No R/, src/, inst/, DESCRIPTION or NAMESPACE diff. Source hashes: cluster_hmap45916b7eaba82461bcfede67bdd85bae9a05e9dfe589abf00e45288c50bb4dd1; clus_visualizef480db19cc719047da55d51092ad288959dcf9ffbe2ee10ee1a07c3e0df80722; DESCRIPTIONfadc8cda247581b65ea6015b1aac4e9d984e6afd8f42dabd6c6e23071ced714a. | PASS |

Focused command: `python3 /home/juhur/.moai/worktrees/projects/richStudio/heatmap-legibility/scripts/test-ci-harness-regressions.py --tree /home/juhur/.moai/worktrees/projects/richStudio/heatmap-ci-stability --artifacts /home/juhur/.moai/worktrees/projects/richStudio/heatmap-ci-stability/.moai/reports/heatmap-ci-stability/impl/controls-wired`.

Observed output:

```text
test_actual_fixture_proof_and_cleanup (__main__.Ownership.test_actual_fixture_proof_and_cleanup) ... ok
test_controlled_transport_integrity_and_install_matrix (__main__.Transport.test_controlled_transport_integrity_and_install_matrix) ... ok
test_same_owned_path_timeout_and_normal_terminal_status (__main__.Watchdog.test_same_owned_path_timeout_and_normal_terminal_status) ... ok
Ran 3 tests in 1.204s
OK
```

Verbatim owned RED output:

```text
FAIL delayed nonce must revalidate same identity before failing: Unknown process joined owned fixture group (pid 100, start same-start, state R)
```

Gaps: actual corrected browser outcome, independent Reviewer/Security verdicts, lint/coverage and repository-wide verdict are not established by these scoped checks. The integration branch CI run owns the repository-wide test verdict; that verdict is **PENDING** at this report time. The original−9 cause and old reset terminal status remain unobserved. A prior hosted8/8 heatmap PASS is not reused as this candidate's verification.

## §E.3 Run-phase Audit-Ready Signal

```yaml
run_complete_at: "2026-10-30T15:58:22Z" # Final hosted completion; original source commit retained below.
run_commit_sha: eb62cb59bcc65ee039c660bb738cedfc65717668
run_status: final-hosted-seven-jobs-success-and-acceptance-pass
hosted_run: 41076765375
hosted_source_sha: 4bc65b3c9068f07f64e08a1b043a0f8913d469fa
ac_pass_count: 9
ac_fail_count: 0
ac_pending_count: 0
preserve_list_post_run_count: 3
l44_pre_commit_fetch: root-managed-not-observed-by-this-backfill
l44_post_push_fetch: root-managed-not-observed-by-this-backfill
new_warnings_or_lints_introduced: 0-final-hosted-test-Rcheck-and-canonical-LSP
cross_platform_build:
  linux: hosted-seven-jobs-pass
  windows: not-run
  macos: not-run
total_run_phase_files: 6
m1_to_mN_commit_strategy: root-explicit-path-commit-after-independent-review
```

## §E.4 Sync-phase Audit-Ready Signal

```yaml
sync_complete_at: 2026-10-30T18:05:05Z
sync_commit_sha: 8500d2d8aeee964e49c829842e4f56c378858bde
sync_status: completed-all-seven-hosted-jobs-pass
documentation: docs/quality/heatmap-legibility-20261030.md
ac_source: docs/specs/SPEC-HMAPCI-001/acceptance.md
tier: M
b12_self_test_a: not-run-no-CHANGELOG-emission
b12_self_test_b: not-run-no-CHANGELOG-emission
b12_self_test_c: not-run-no-CHANGELOG-emission
changelog_entry_position: none
frontmatter_status_transitions:
  status: in-progress-to-implemented-to-completed
  updated: 2026-10-30
local_evidence:
  scoped_result: 21-controls-six-GUI-independent-code-security-approved
  source_portability: exactly-three-intToUtf8-substitutions-CRLF-preserved
  runtime_equivalence: 92-actual-output-checks-identical
  explicit_diagnostic_difference: 13-title-Encoding-marks-unknown-to-UTF8
  source_AST_identity: not-claimed-constructor-nodes-intentionally-change
  harness_and_gates: five-files-all11pins-strict90-seven-jobs-unchanged
hosted_evidence:
  run: 41076765375
  source_sha: 4bc65b3c9068f07f64e08a1b043a0f8913d469fa
  documentation_head: 790c45d13dc0e993f79167ae435ef7c44f08945c
  source_equivalence: committed-tail-documentation-only
  passed_jobs: prepare-diagnostics-scan-negative-resources-browser-full
  full_R: 263-tests-3125-assertions-zero-failures-errors-warnings-skips
  package_check: zero-errors-zero-warnings-five-NOTEs
  coverage: 8737-of-9521-lines-91.76557084-percent-target85
  strict_profile_canaries: 14-of-14-PASS
  source_digest_audit: 64-files-match-zero-mismatches
  browser: 66-expected-zero-unexpected-skipped-flaky-errors
  both_unchanged_MV3_native_zoom_cases: passed-actual-native-proof
  prepare_controls: three-groups-zero-failures-errors-skips
  canonical_LSP: candidate-all-zero-sync-PASS-release_hold-false
  AST: 26-documents-zero-findings-errors-canarytrue
  serve_terminal: configured1800-status-minus15-signal15-reapedtrue-errornull
canary_compliance_check:
  canonical_negative_and_scan: passed
  prepare_controlled_scenarios: 21-passed
  assertions_pins_deadlines: unchanged
remaining_gaps:
  historical_minus9_old_reset_exit_MV3_and_local_SIGTRAP_causes: unknown
  deployment: no-current-candidate-measurement
```

Evidence read from `.moai/reports/heatmap-portability/qa/report.md`,
`code-review-r1.md` and `hosted-41076765375/`. Actual commands include native
`tools:::.check_package_ASCII_code()`, scoped `Rscript --vanilla` comparisons,
`python3 scripts/test-ci-harness-regressions.py --tree <candidate-tree> --artifacts
<evidence-directory>`, `bash scripts/test-workspace.sh diagnostics sync` and
canonical `npx --no-install playwright test`. Stored output: ASCII character(0),
31tests/337assertions all-pass,92observable checks/four goldens exact, hosted
three control groups0fail/error/skip, LSPcandidate all0/syncPASS and browser
66expected/0unexpected/0skip/0flaky/errors[]. These were inspected independently,
not rerun by documentation. Fresh prepare/diagnostics/scan artifact digests match
both current R files, DESCRIPTION and runner. Earlier b7 full measurements and
R5 GUI/PNG evidence retain their original source attribution; installed
byte-equivalence supports the representation-only correction. Final independent
`final-ci-audit.md` is APPROVED: all seven jobs succeeded at source4bc65b3,
263tests/3125assertions all-pass, package0errors/0warnings/5NOTEs,
coverage8737/9521=91.76557084% against85%,14/14strict-profile canaries and
64matching source digests. Historical denominator differences do not establish
coverage non-regression. Five NOTEs and deployment/publication gaps remain
explicit. Sync SHA is deliberately pending-backfill until the root-owned commit;
this document does not attempt to cite its own future commit hash.
