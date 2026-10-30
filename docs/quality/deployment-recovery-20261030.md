# Deployment recovery preparation — 2026-10-30

## Claim

[SPEC-DEPLOYRECOVERY-001](../specs/SPEC-DEPLOYRECOVERY-001/spec.md) is completed
for its eight bounded code, controlled-test and exact remote-preparation criteria.
Independent source/QA, security and fresh remote-read reviews are APPROVED.
This prepares the corrected owner command; it does not establish privileged
publication, real production rollback or new-release UI health.

The [deployment script](../../scripts/deploy-r46-release.sh) now restores its
captured previous release after a failed publication, restarts the restored
service and verifies active service/healthy HTTP before reporting recovery.
Every recovery stage is checked. Foreign/unreadable targets are refused; original
failure or catchable INT/TERM status survives both successful and failed cleanup.
Cleanup runs once, with finite service/HTTP waits and retained release evidence.

## Evidence

Documentation inspected the actual [source review](../../.moai/reports/deploy-recovery/code-review-r1.md),
[QA report](../../.moai/reports/deploy-recovery/qa-r1.md),
[security review](../../.moai/reports/deploy-recovery/security-final.md),
[remote review](../../.moai/reports/deploy-recovery/remote-review.md),
implementation report and activation/server-control receipts. It did not rerun
services, deploy or impersonate an independent reviewer.

Actual source-review commands:

```sh
bash -n scripts/deploy-r46-release.sh
python3 scripts/test-deploy-recovery.py
python3 .moai/reports/deploy-recovery/qa-r1-extra.py
```

Native syntax exits0. The [focused standard-library test](../../scripts/test-deploy-recovery.py)
executes the literal production publication tail with link/service/HTTP/sleep/
cleanup commands mocked, each child bounded by an outer 5s timeout. Recorded output:

```text
Ran 11 tests in 0.188s
OK
INDEPENDENT_ADDITIONAL_CONTROLS 9 PASS
```

The 11 methods cover 18 controls, including 17 publication scenarios and the native
literal-dot legacy runtime guard. A standalone outside-Git invocation also passes.
Nine independent QA fault controls and three independent security fault probes
pass separately; these are not added into a purported unique aggregate count.
Security also checks actual wrapper guards with bounded mocks and the non-root
privilege rejection. No real service or foreign process was targeted by tests.

Implementation evidence records native Python AST parse success and:

```text
PREFIX_IDENTICAL 12508 e0445f321483bb1435cbe03770e22bab9c2cfeae68fec44d11e1d0e6c6fca050
PINS_AND_LEGACY_GUARD_BASELINE_IDENTICAL True
PROTECTED_SOURCE_CHANGES []
```

The unchanged prefix includes archive pins, checkout/build and preflight. Native
controls verify original 17/23 and 130/143 exit statuses, stage-order enforcement,
no false recovery/deployment completion, and refusal on detected foreign changes.
Restart uses timeout 210s/kill-after 5s, active probes 5s/kill-after 5s, curl max-time 30
and at most 20 health attempts with 3s intervals. These are configured bounds,
not measured production-recovery duration.

Root staged the exact script/test remotely and actually ran the 11-method suite.
[Server controls](../../.moai/reports/deploy-recovery/server/results/controls.log)
end `Ran 11 tests in 0.685s` / `OK`, exit0; the log SHA is
`1ceee6109e4d51cff6d3cb1eb3896e32a7cad382b684b62208a97d473a336828`.
Root then activated the exact script, recovery-check receipt and guarded wrapper
last. [Activation receipt](../../.moai/reports/deploy-recovery/server/results/activation.json)
records `wrapper_reenabled: true` and `deployment_executed: false`.

Independent remote review subsequently executed:

```sh
ssh -o BatchMode=yes -o ConnectTimeout=10 juhur@100.94.67.89 'python3 -'
```

Its retained read-only Python uses bounded queries and syntax checks, never sudo,
publication or service mutation. SSH exit0/stderr empty. Actual observations:
server script/test/wrapper hashes match, Bash syntax 0, prefix 12508 byte-identical
to the old server backup, CI/preflight pins 4bc, recovery pin 42bcb1, all 7 historical
application jobs successful, wrapper guards valid, previous 731 release active,
new run directory absent and `all_checks_passed: true`. Root's server-test result
was hash-verified by that reviewer, not rerun. The same prepared command now uses
run ID `heatmap-4bc65b3-recovery-20261030` and the corrected pinned script.

## Baseline-attribution

Measured documentation tree:
`/home/juhur/.moai/worktrees/projects/richStudio/deploy-rollback-recovery`,
HEAD/tool commit `c149d3120d345754dcddbc52ba67f97e1391d4f1`.
The preserved tool baseline is `96fac4f597d4842cdab62047eb629827ecd180b9`.

| Component | SHA256 |
|---|---|
| Deployment script | `42bcb1a3f7d5a6b3f5bfcc354afcc9647d941a828f989f1f1088b897fd26bed6` |
| Focused test | `4242fcc461de527c509450867237d038070b3487dba805a6dd519fb72f5ae5f5` |
| Prepared wrapper | `894ec812a46a353145c7ed310ff1409c94e28ff17c8a89eac3f1d035a882ed4e` |
| Actual old server script backup | `7f3d1614f17c2a93f849f428c7a683dad847d01795e8928b060f45cb24c6b390` |

Application candidate remains `4bc65b3c9068f07f64e08a1b043a0f8913d469fa`.
Its existing CI run 41076765375 passed 7/7. The previous retained preflight build
`/home/juhur/richStudio-r46-preflight.20261030T180441Z` has that exact repo HEAD;
its existing build evidence is retained because the full prefix is identical, not
claimed as a newly executed corrected-tool preflight. The independent point-in-time
server observation was Hurlab.und.nodak.edu/100.94.67.89, old live 7317862/active.
Application identity and deployment-tool identity are deliberately distinct.

## Gaps

No new repository-wide tool CI was run or queued; no new local full R suite,
package check, coverage or full preflight was run for this shell-only correction.
Shellcheck/bash-language-server are unavailable; native Bash syntax, Python AST
and actual-source controlled execution provide the recorded scoped checks.
No shell coverage or aggregate LSP total is asserted. No sudo authentication,
real publication/failure injection, live rollback, new private release library
or post-publication Shiny UI/image-download behavior was tested by this task.

## Residual-risk

SIGKILL and host failure cannot invoke shell traps. Readlink ownership checks
are fail-closed observations, not atomic compare-and-swap or universal exclusion
of another privileged actor. Mocks do not exhaust OS scheduling or real service/
network behavior. The observed old live identity is a point-in-time guard; the
wrapper must refuse changed identities. Active service and healthy HTTP remain
narrower than full application verification. Retain old/new releases and logs,
and measure deployed identity and public UI after any authenticated publication.
