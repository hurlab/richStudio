# Progress — SPEC-DEPLOYRECOVERY-001

## §E.1 Plan-phase Audit-Ready Signal

_Plan v0.1.0 independently APPROVED; see [the plan review](../../../.moai/reports/deploy-recovery/plan-review.md), SHA256 `511ab0967c082635090e99ee5ebfacd13e73e010ca676c970124c113bef80bae`. This records plan approval only._

## §E.2 Run-phase Evidence

Actual source failure controls and preservation evidence are in ignored
`.moai/reports/deploy-recovery/impl/{report.md,red.log,green.log,portable.log,preservation.json}`.
These initial implementation records are source mocks, not live recovery or an
independent verdict. Final independent review and remote preparation results are
recorded below with their own actor attribution.

| Acceptance | Actual output | Status |
|---|---|---|
| AC-001 | Actual-source restart/health/inactive publication failures restore previous link, restart once, active/HTTP verify, preserve original17/1 exits. | PASS scoped controls |
| AC-002 | Injected link/move/restart/inactive/HTTP/error-page/transport recovery failures explicitly name stage, retain17, skip unsafe later stages/cleanup and never claim success. | PASS scoped controls |
| AC-003 | Exit23 immediately after mock live mv before SWAPPED still recovers; detected third/unreadable target never replaced/restarted. | PASS scoped controls |
| AC-004 | Ordinary17/23 and INT130/TERM143 survive successful/failed recovery; trap cleanup runs once. | PASS scoped controls |
| AC-005 | Preswitch failure11 has no restore/restart; success alone prints DEPLOY COMPLETE and cleans own mock build. | PASS scoped controls |
| AC-006 | Restart timeout210s+kill5s, active probe5s+kill5s, curl max30s,20attempts; negative active/HTTP/error/transport cannot verify, tests use no actual waits. | PASS scoped controls |
| AC-007 | Prefix12508bytes/e0445f321483bb1435cbe03770e22bab9c2cfeae68fec44d11e1d0e6c6fca050 exact; archive pins and protected application/CI/test paths unchanged; legacy regex exact. | PASS scoped preservation |
| AC-008 | Root activation.json records fresh server11-method controls exit0, syntax and actual script/test/wrapper hashes, preserved prefix, CI/preflight/recovery pins and atomic re-enable last. Independent remote-review.md APPROVED after fresh readonly SSH verifies the installed hashes/guards/current731 active/no new run. | PASS remote preparation |

Initial RED before production edits:10 methods/15 failures. Final GREEN:11methods
(17mocked publication scenarios+1native grep guard),18controls allpass. Copied
standalone --script execution outside Git also passes. A caught accidental extra
legacy-regex backslash has its own native RED and exact baseline restoration proof;
no protected guard is weakened. Shellcheck/Bash LSP/linecoverage were not available
or measured; native Bash syntax and Python AST pass. No full R checks/tests,
package installation, server command, sudo, deployment or live failure injection
was performed by this Implementer. Root and the independent remote reviewer
performed the separately attributed server observations below.

Application source/previous CI7of7 attribution remains4bc65b3/run41076765375.
No repository-wide CI was run or queued for this deployment-tool correction;
change-scoped Bash/Python controls own its verification. Historical application
CI does not certify this new tool or actual server recovery. Independent source
and focused QA are APPROVED in code-review-r1.md/qa-r1.md (11native methods,
18controls plus9independent fault controls). Security-final.md is independently
APPROVED and records three additional concurrent-target probes and wrapper guards.

Root measured fresh server controls (server/results/controls.log:11tests,OK,exit0)
and prepared the exact server script/test/wrapper before atomically re-enabling
the same command. server/results/activation.json identifies tool commitc149d312
and application4bc65b3 separately. ScriptSHA42bcb1a3f7d5a6b3f5bfcc354afcc9647d941a828f989f1f1088b897fd26bed6,
testSHA4242fcc461de527c509450867237d038070b3487dba805a6dd519fb72f5ae5f5,
wrapperSHA894ec812a46a353145c7ed310ff1409c94e28ff17c8a89eac3f1d035a882ed4e.
The full12508byte prefix matches the actual old server backup; old application
CI/preflight pins remain4bc, recovery-check.ok pins42bcb1. Independent
remote-review.md APPROVED (SHA256ccb5da0b760442b50d2c5a58a1fdf58fe98c7bdc4f681cc7b2af909b523062f3)
then verifies these identities and syntax through fresh readonly SSH, observed
JSON all_checks_passed=true. This Implementer inspected those actual receipts;
it did not perform or impersonate the remote operations. Live release remains731
and shiny-server active; new run directory absent. The command is prepared and
re-enabled, but privileged publication and real production recovery are not claimed.

## §E.3 Run-phase Audit-Ready Signal

```yaml
run_complete_at: 2026-10-30T21:58:16Z
run_commit_sha: c149d3120d345754dcddbc52ba67f97e1391d4f1
run_status: eight-acceptances-pass-source-security-and-remote-preparation-approved
cycle_type: tdd
ac_pass_count: 8
ac_fail_count: 0
ac_pending_count: 0
controlled_unittest_methods: 11
controlled_publication_scenarios: 17
native_legacy_guard_controls: 1
script_sha256: 42bcb1a3f7d5a6b3f5bfcc354afcc9647d941a828f989f1f1088b897fd26bed6
test_sha256: 4242fcc461de527c509450867237d038070b3487dba805a6dd519fb72f5ae5f5
preflight_prefix_byte_identical: true
preflight_prefix_bytes: 12508
preflight_prefix_sha256: e0445f321483bb1435cbe03770e22bab9c2cfeae68fec44d11e1d0e6c6fca050
legacy_pgrep_guard_byte_identical: true
protected_application_ci_paths_unchanged: true
new_warnings_or_lints_introduced: not-measured-by-LSP-native-syntax-pass
cross_platform_build:
  status: scoped-linux-bash-python-controls-pass
  application_ci: historical-PASS-run41076765375-source4bc65b3
  new_tool_repository_wide_ci: not-run-not-queued-change-scoped-checks
remote_reenable: verified-root-activation-and-independent-readonly-SSH
remote_review_sha256: ccb5da0b760442b50d2c5a58a1fdf58fe98c7bdc4f681cc7b2af909b523062f3
wrapper_sha256: 894ec812a46a353145c7ed310ff1409c94e28ff17c8a89eac3f1d035a882ed4e
publication_executed: false
final_remote_evidence_recorded_at: 2026-10-30T22:05:03Z
m1_to_mN_commit_strategy: root-owned-explicit-scoped-files
```

## §E.4 Sync-phase Audit-Ready Signal

```yaml
sync_complete_at: 2026-10-30T22:05:34Z
sync_commit_sha: d6344982e96e38f4d8d10ae897a1b31d64d13878
sync_status: completed-eight-bounded-acceptances-source-security-remote-approved
documentation: docs/quality/deployment-recovery-20261030.md
ac_source: docs/specs/SPEC-DEPLOYRECOVERY-001/spec.md
tier: S
b12_self_test_a: not-run-no-CHANGELOG-emission
b12_self_test_b: not-run-no-CHANGELOG-emission
b12_self_test_c: not-run-no-CHANGELOG-emission
changelog_entry_position: none
frontmatter_status_transitions:
  status: in-progress-to-implemented-to-completed
  updated: 2026-10-30
source_attribution:
  tool_commit: c149d3120d345754dcddbc52ba67f97e1391d4f1
  application: 4bc65b3c9068f07f64e08a1b043a0f8913d469fa
  script_sha256: 42bcb1a3f7d5a6b3f5bfcc354afcc9647d941a828f989f1f1088b897fd26bed6
  test_sha256: 4242fcc461de527c509450867237d038070b3487dba805a6dd519fb72f5ae5f5
  wrapper_sha256: 894ec812a46a353145c7ed310ff1409c94e28ff17c8a89eac3f1d035a882ed4e
scoped_evidence:
  native_methods: 11-PASS-18-controls
  independent_QA: nine-additional-fault-controls-PASS-not-disjoint-total
  independent_security: three-additional-fault-probes-PASS-not-disjoint-total
  server_staged_actual_methods: 11-PASS-exit0
  native_static: Bash-syntax-and-Python-AST-PASS
  preflight_prefix: 12508-bytes-exact-e0445f321483bb1435cbe03770e22bab9c2cfeae68fec44d11e1d0e6c6fca050
  protected_application_pins_CI: unchanged
  independent_remote_preparation: APPROVED-fresh-readonly-SSH
  guarded_wrapper: activated-last-exact-script-and-recovery-receipt
  observed_old_live: 73178628106d9b160831d476f80171e4f4d0bf61-active
  new_run_directory: absent-at-independent-observation
canary_compliance_check:
  original_exit_status: preserved-in-successful-and-failed-mock-recovery
  foreign_or_unreadable_target: refused-no-overwrite-or-restart
  catchable_interrupts: bounded-once-only-INT-TERM-cleanup
  application_CI: historical-seven-of-seven-source4bc-not-tool-CI
remaining_gaps:
  new_tool_repository_wide_CI: not-run-not-queued
  fresh_full_preflight: not-run-existing-build-evidence-retained-identical-prefix
  privileged_publication_and_real_live_recovery: not-run
  SIGKILL_host_failure_and_universal_synchronization: not-guaranteed
  post_publication_UI_runtime: not-measured
```

Actual commands and bounded output are in the linked quality report and
`.moai/reports/deploy-recovery/{code-review-r1.md,qa-r1.md,security-final.md,remote-review.md}`.
The fresh independent SSH read verifies the actual server script/test/wrapper
hashes, old live guard, CI/preflight/recovery pins and absent new run directory.
Root's actual staged server log ends11tests/OK; independent remote review
verified its hash without claiming a rerun. Original preflight evidence is retained
because the entire prefix is byte-identical, not relabeled a fresh full preflight.
Root owns the sync commit and subsequent SHA metadata update. No production
publication, real failure injection or application-wide verification is implied.
