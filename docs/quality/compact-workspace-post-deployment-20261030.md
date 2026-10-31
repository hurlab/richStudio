# Compact workspace post-deployment check — 2026-10-30

## Claim

The owner-executed deployment published application source
`e8fef99a07b744dfdfcbb69f226e3a624fdce51e`. The actual public browser report
records 15 passed cases across three viewports, with console/page errors 0.
Independent [native source checks](../../.moai/reports/layout-density/post-deploy/native/release-file-checks.json),
[namespace/UI checks](../../.moai/reports/layout-density/post-deploy/native/namespace-check.json)
and [worker observations](../../.moai/reports/layout-density/post-deploy/native/worker-observation.json)
PASS within their bounded scope; no broader native-audit conclusion is inferred.
No SPEC completion transition is made by this report.
[Current SPEC v0.1.2](../specs/SPEC-COMPACTUI-001/spec.md) replaces GitHub CI with
scoped local verification and exact-candidate server preflight. No CI was
requested, run, reviewed or awaited for this documentation task.

## Evidence

Documentation inspected actual root, browser and native receipts under
`.moai/reports/layout-density/post-deploy/`, without rerunning a server command.
Root's deployment log ends:

```text
HTTP 200, error-page matches 0
DEPLOY COMPLETE
Release: e8fef99a07b744dfdfcbb69f226e3a624fdce51e
```

The live symlink/marker agree; shiny-server is active and previous 4bc is retained.
Root's landing/CSS HTTP receipts record 200/TLS verify 0. The public CSS response
is 34803 bytes, SHA256
`b3c1ad641912f6597f5cdc6c2324fb59e66d70c38d2133efbb855cde30d1e78f`.

[Public QA](../../.moai/reports/layout-density/post-deploy/browser/report.md) ran:

```sh
timeout --kill-after=10s 480s ./node_modules/.bin/playwright test --config=.moai/reports/layout-density/post-deploy/browser/public.config.ts
```

Exit 0, terminal `15 passed`; JSON expected 15/unexpected 0/skipped 0/flaky 0.
The five unchanged compact test bodies run at 1440×900, 1280×720 and 375×667:
initial Run/columns; populated review/span; preview/commit-keyboard-navigation-
resize state; all seven menus/readability/cautions; dynamic methods/Reset.
Actual Shiny is connected in all 15 runtime receipts; no local server/tunnel,
new enrichment/clustering, heatmap exports or scientific retuning was performed.

| Public metric |1440×900|1280×720|375×667|
|---|---:|---:|---:|
| Initial Run bottom, px |526.265625|526.265625|1178.03125|
| Populated primary span, px |641.65625|661.65625|962.34375|
| Document width, px |1440|1280|375|
| Input/review font |14px|14px|14px|

Desktop fields form columns; narrow fields stack with ordinary vertical scrolling.
Full matched review digest 34ff201542ea, 31 genes/48 exclusions and distinct preview/
commit cutoffs remain correct. QA retained 36 screenshots/21 menu PNG-JSON pairs,
actually inspected eight wide/narrow screenshots, and inventories 120 evidence files.
Cleanup verifies 30 specific descendant PID/start identities gone plus three local
worker PIDs absent; it does not claim global process reaping or kill production R.

Native `release-file-checks.json` measures 275 tracked paths, 274 immutable files
all SHA256-matching, no other missing/mismatched/symlink/nonroot/runtime-writable
immutable files. The sole excluded tracked path is `logs/PROJECT_LOG_2026-H1.md`,
absent because deployment recreates writable runtime logs. Logs are writable;
immutable code remains root-owned/nonwritable. These are this release's measured
counts, not the earlier 255-file comparison. Private-library/env/archive pins pass.
`namespace-check.json` records R 4.6.1, richStudio 0.1.6, richR 0.1.5, richCluster 2.0.1,
bioAnno 0.99.45 from the new private library, all Built R 4.6.1, and seven UI function
body/formals comparisons true. Root's actual worker ancestry 2320774→2320770→
MainPID2320697 maps richStudio/richCluster/richR DLLs under the new release with
application cwd; PAM user-session cgroup alone is not treated as disproof.

## Baseline-attribution

Documentation tree `/home/juhur/.moai/worktrees/projects/richStudio/compact-workspace-layout`,
initial HEAD `f9b25fb9caa3ded52d234cb1d7b8eb3cc820342f`; application identity is
`e8fef99a07b744dfdfcbb69f226e3a624fdce51e`, distinct from documentation commits.
Release `/opt/richStudio/releases/richStudio-e8fef99a07b744dfdfcbb69f226e3a624fdce51e-20261031T012242Z`.
Public Chromium 141.0.7390.37/Playwright 1.56.1 uses one worker/zero retries;
results timestamp 2026-10-31T01:33:19.523Z. The first case includes a bounded hold
for worker ancestry observation, not an application-performance measurement.
[Local evidence](compact-workspace-layout-20261030.md) retains 38 PASS/2 native
pre-page-zoomFAIL. Server preflight/public smoke do not turn those into passes.

## Gaps

No new full R suite, coverage, inference, native 200% zoom, heavy heatmap exports,
scientific backend revalidation, all-device/cross-browser test, stress/concurrency
or real rollback/failure injection was performed. Only measured states/viewports
are covered. The wide complete Enrich page remains taller 1831→2429px because
preview/results follow the compact primary area; no total-page reduction is claimed.

## Residual-risk

Point-in-time public/native results do not prove every input or continuous uptime.
Retain exact source identity, local failed-launch receipts and previous release.
The one-time deployment wrapper has been consumed and must not be blindly rerun.
Documentation made no production, source, manuscript or SPEC-status change.
