# Progress — SPEC-DEPLOYRECOVERY-001

## §E.1 Plan-phase Audit-Ready Signal

_Plan v0.1.0 independently APPROVED; see [the plan review](../../../.moai/reports/deploy-recovery/plan-review.md), SHA256 `511ab0967c082635090e99ee5ebfacd13e73e010ca676c970124c113bef80bae`. This records plan approval only._

## §E.2 Run-phase Evidence

Actual source failure controls and preservation evidence are in ignored
`.moai/reports/deploy-recovery/impl/{report.md,red.log,green.log,portable.log,preservation.json}`.
These are source mocks, not live recovery or an independent verdict.

| Acceptance | Actual output | Status |
|---|---|---|
| AC-001 | Actual-source restart/health/inactive publication failures restore previous link, restart once, active/HTTP verify, preserve original17/1 exits. | PASS scoped controls |
| AC-002 | Injected link/move/restart/inactive/HTTP/error-page/transport recovery failures explicitly name stage, retain17, skip unsafe later stages/cleanup and never claim success. | PASS scoped controls |
| AC-003 | Exit23 immediately after mock live mv before SWAPPED still recovers; detected third/unreadable target never replaced/restarted. | PASS scoped controls |
| AC-004 | Ordinary17/23 and INT130/TERM143 survive successful/failed recovery; trap cleanup runs once. | PASS scoped controls |
| AC-005 | Preswitch failure11 has no restore/restart; success alone prints DEPLOY COMPLETE and cleans own mock build. | PASS scoped controls |
| AC-006 | Restart timeout210s+kill5s, active probe5s+kill5s, curl max30s,20attempts; negative active/HTTP/error/transport cannot verify, tests use no actual waits. | PASS scoped controls |
| AC-007 | Prefix12508bytes/e0445f321483bb1435cbe03770e22bab9c2cfeae68fec44d11e1d0e6c6fca050 exact; archive pins and protected application/CI/test paths unchanged; legacy regex exact. | PASS scoped preservation |
| AC-008 | Parent must independently approve, transfer/test candidate, verify remote hashes/new wrapper pin and expected live/candidate before re-enable. No remote operation here. | PENDING root remote proof |

Initial RED before production edits:10 methods/15 failures. Final GREEN:11methods
(17mocked publication scenarios+1native grep guard),18controls allpass. Copied
standalone --script execution outside Git also passes. A caught accidental extra
legacy-regex backslash has its own native RED and exact baseline restoration proof;
no protected guard is weakened. Shellcheck/Bash LSP/linecoverage were not available
or measured; native Bash syntax and Python AST pass. No full R checks/tests,
package installation, server command, sudo, deployment or live failure injection.

Application source/previous CI7of7 attribution remains4bc65b3/run41076765375.
Repository-wide verdict for this new tool change is pending CI; scoped mock success
must not be described as actual server recovery. Independent source review and
remote AC008 are still pending.

## §E.3 Run-phase Audit-Ready Signal

```yaml
run_complete_at: 2026-10-30T21:58:16Z
run_commit_sha: pending-root-commit
run_status: controlled-source-recovery-pass-independent-and-remote-gates-pending
cycle_type: tdd
ac_pass_count: 7
ac_fail_count: 0
ac_pending_count: 1
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
  new_tool_repository_wide_ci: pending
remote_reenable: pending-root-approved-hash-and-tests
m1_to_mN_commit_strategy: root-owned-explicit-scoped-files
```

## §E.4 Sync-phase Audit-Ready Signal

_<pending sync-phase>_
