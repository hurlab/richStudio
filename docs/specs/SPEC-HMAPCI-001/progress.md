# Progress — SPEC-HMAPCI-001

## §E.1 Plan-phase Audit-Ready Signal

_Plan v0.1.0 independently APPROVED; see [the plan review](../../../.moai/reports/heatmap-legibility/hmapci-plan-review-v010.md). This approval covers the plan only._

## §E.2 Run-phase Evidence

Measured candidate: isolated tree `/home/juhur/.moai/worktrees/projects/richStudio/heatmap-ci-stability`, parent HEAD `61dee8615a5c6f3a8831f933efa2bcdddfd61b98`; uncommitted harness diff. Plan review `hmapci-plan-review-v010.md` is APPROVED. Root owns commit/push after independent review.

| Scenario / invariant | Actual Output | Status |
|---|---|---|
| AC-001 frozen product and gates | `frozen-invariants.log`: application R/src/inst/DESCRIPTION/NAMESPACE unchanged; pinned URL/SHA tables and all workflow configuration identical except archive Python and the prepare-only focused-control hook; three released product hashes match. | PASS |
| AC-002 recoverable ownership proof | Actual extracted fixture helper and fixture closure: delayed nonce admitted only on matching fresh PID/start/group+nonce; real owned subprocess cleanup succeeds. `controls-wired/ownership-results.json`: 9/9 subcases passed. | PASS |
| AC-003 unsafe ownership proof | Persistent foreign, permission, reused PID and dead-owner controls fail; actual cleanup spy signals are empty. QA found empty-list/dead-owner admission in round1; round2 requires proven live owner before readiness and before use. | PASS |
| AC-004 viewport/pixels | Existing four semantic cells, Cluster/NA/zero-floor hover assertions and RGBA comparisons preserved; native region scroll and per-cell viewport screenshots implemented. Fresh installed-app browser verification is QA-owned and pending at freeze. | PENDING |
| AC-005 finite serve evidence | Same `serve_watchdog` path: controlled timeout status124 and normal status7, real identity/start/group receipts and reaped child. Production call fixed1800; no production override. | PASS |
| AC-006 transport recovery | Actual workflow Python: reset/TLS EOF/timeout→valid recover; three interrupted attempts stop; verified digest precedes one installation; durable per-attempt receipts. | PASS |
| AC-007 integrity/hard failures | HTTP/certificate/digest/install controls each stop without retry; digest mismatch never installs. Focused transport matrix: 10/10 scenarios passed. | PASS |
| AC-008 unchanged full profile | Full `check_profile()` source compared byte-for-byte with parent HEAD; timeout90 remains. Original hosted−9 cause is still unobserved; no local full suite/check/coverage run. | PASS |
| AC-009 same-source hosted closure | All seven integration-branch workspace jobs are required on one published candidate SHA. No hosted run is claimed here. | PENDING |
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
run_complete_at: null
run_commit_sha: PENDING_ROOT_COMMIT
run_status: focused-controls-passed-browser-and-review-pending
ac_pass_count: 7
ac_fail_count: 0
ac_pending_count: 2
preserve_list_post_run_count: 3
l44_pre_commit_fetch: PENDING_ROOT
l44_post_push_fetch: PENDING_ROOT
new_warnings_or_lints_introduced: null
cross_platform_build:
  linux: scoped-types-and-syntax-pass
  windows: not-run
  macos: not-run
total_run_phase_files: 6
m1_to_mN_commit_strategy: root-explicit-path-commit-after-independent-review
```

## §E.4 Sync-phase Audit-Ready Signal

```yaml
sync_complete_at: null
sync_commit_sha: pending-backfill
sync_status: local-ready-hosted-full-and-browser-retry-pending
documentation: docs/quality/heatmap-legibility-20261030.md
ac_source: docs/specs/SPEC-HMAPCI-001/acceptance.md
tier: M
b12_self_test_a: not-run-no-CHANGELOG-emission
b12_self_test_b: not-run-no-CHANGELOG-emission
b12_self_test_c: not-run-no-CHANGELOG-emission
changelog_entry_position: none
frontmatter_status_transitions:
  completed: not-applied-hosted-CI-pending
local_evidence:
  controls: 21-cases-9-ownership-10-transport-2-watchdog
  local_GUI: six-passed
  frozen_application: 52-files-unchanged
  invariants: strict90-all11pins-seven-jobs-unchanged
  code_review: approved-exact-frozen-candidate
  scoped_security: no-open-Critical-High-Medium
hosted_evidence:
  run: 41065823052
  source_sha: b7b072fad907d54258b22a0e746348f652ceb665
  documentation_head: 08e947173b56160510adad1a36e4c02296fb570d
  source_equivalence: only-progress-metadata-commits-after-hosted-source
  passed_jobs: prepare-diagnostics-negative-resources-scan
  full: in-progress
  browser_first_attempt: 65-passed-1-failed-zero-skipped-flaky
  browser_failure: unchanged-desktop-MV3-worker-wait-before-native-zoom-proof
  prepare_controls: three-groups-zero-failures-errors-skips
  canonical_LSP: candidate-all-zero-sync-PASS-release_hold-false
  serve_terminal: configured1800-status-minus15-signal15-reapedtrue-errornull
canary_compliance_check:
  controlled_watchdog: normal7-timeout124-both-reaped
  hosted_canonical_gates: passed-diagnostics-negative-scan
  assertions_and_pins: unchanged
remaining_gaps:
  hosted_full: pending
  same_SHA_browser_retry: authorized-only-after-first-run-terminal
  hosted_MV3_cause: unknown
  local_probe: SIGTRAP-before-launch-acceptance-not-native-zoom-PASS
  historical_minus9_and_old_reset_terminal_exit: unknown
  deployment: candidate-not-verified
```

Observed independent evidence is under `.moai/reports/heatmap-ci-stability/`:
`code-review-r1.md`, `security/postfix-r1.md`, `qa/report.md`,
`native-zoom-triage.md`, `native-zoom-local/report.md` and
`hosted-41065823052/{current-state.json,prepare,diagnostics,browser}`.
The prepare job invokes `python3 scripts/test-ci-harness-regressions.py --tree
<absolute-candidate-tree> --artifacts <evidence-directory>`: its actual hosted
summary reports tests3/failures0/errors0/skips0/passedtrue. Hosted diagnostics
run `bash scripts/test-workspace.sh diagnostics sync`; JSON reports candidate
all0, syncPASS and release_holdfalse. Browser command remains canonical
`npx --no-install playwright test`; first JSON records65expected/1unexpected,
zero skips/flaky. Actual serve−15 is teardown, not timeout124. These stored
results were inspected by documentation, not rerun. Current application hashes
match frozen R5; final all-seven success and exact-source retry remain required.
