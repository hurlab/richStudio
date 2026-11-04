# Heatmap post-deployment verification — 2026-10-30

## Claim

The deployed application source `4bc65b3c9068f07f64e08a1b043a0f8913d469fa`
passes the observed native/runtime and four scoped public-browser journeys.
Independent [native audit](../../.moai/reports/deploy-recovery/post-deploy-20261030/native-audit.md)
is APPROVED; the [public-browser report](../../.moai/reports/deploy-recovery/post-deploy-20261030/browser/report.md)
records PASS. This report inspects their actual evidence; it does not rerun deployment.

## Evidence

Actual reviewer commands included bounded read-only BatchMode SSH/Python queries,
verified-TLS curl to `https://hurlab.med.und.edu/richStudio/`, and:

```sh
timeout --kill-after=10s 600s node .moai/reports/deploy-recovery/post-deploy-20261030/browser/e2e/live-public.cjs
```

Native SSH/curl and browser command exited0. The actual deployment log ends:

```text
HTTP 200, error-page matches 0
DEPLOY COMPLETE
Release: 4bc65b3c9068f07f64e08a1b043a0f8913d469fa
```

Live symlink and marker identify the new release ending `20261030T221806Z`;
shiny-server is active and the previous 7317862 release is retained. Curl records
`http_code: 200`, `ssl_verify_result: 0`; the browser observes actual Shiny connected.
Private namespace receipt passes with R 4.6.1, richStudio 0.1.6, richR 0.1.5,
richCluster 2.0.1 and bioAnno 0.99.45, plus three DLLs within the new private library.
Independent `/proc` proof shows service ancestry 2098720→2098717→MainPID2098605;
worker 2098720 maps new-release richStudio/richR/richCluster native libraries.
Its PAM user-session cgroup does not negate that observed ancestry. Other orphan
R processes were excluded; standalone namespace loading is not service proof.

Original full 256-file comparison remains `all_match: false`: its sole missing
path is `logs/PROJECT_LOG_2026-H1.md`. Actual deployment removes/recreates writable
runtime logs. The qualified immutable comparison excludes exactly that historical
operational log archive: 255 files match, no other mismatch. Both original and
qualified receipts are preserved; no application/scientific path was excluded.

| Public journey | Actual result |
|---|---|
| Connection | HTTP200 and Shiny connected |
| Bundled hierarchical | 141 rows/282 cells/108 NA; exact frozen coordinates/values/masks |
| Bundled DAVID | 139 rows/278 cells/105 NA; exact frozen coordinates/values/masks |
| Valid Maximum2000 saved session | 4000 trace cells/1000 NA retained; first/last 400-row windows and two real PNG downloads pass |

Both methods and the 2000-row fixture were measured at 1280×720 and 375×667:
18px row pitch, 14px font, keyboard End/Home edges, contained figure overflow and
no body horizontal overflow. Fixture IDs are `3*i+2`: first window 6002…4805,
last 1202…5; they are not the SPEC's original 1…2000 example. Both downloaded PNGs
are 1000×7450, byte-identical, and honestly show Rows 1601–2000 of 2000, not all rows.
Actual full image, exact-pixel crops and narrow UI screenshot were visually
inspected: full first/last labels and complete NA/zero note, without observed clipping.
Browser log ends `LIVE_DEPLOYED_HEATMAP_PUBLIC_PASS`; receipt has page/console
errors[], browser_closedtrue and all four specifically observed original owned
processes gone. This is specific PID/start proof, not a universal reaping claim.
The 26-file browser artifact manifest inventories actual outputs and review derivatives.

## Baseline-attribution

Integration tree `/home/juhur/.moai/worktrees/projects/richStudio/heatmap-legibility`,
HEAD `82482c3dfd425a19774fe8ff57980d49438092d1`; browser session 22:30:27–22:31:18UTC.
Live release: `/opt/richStudio/releases/richStudio-4bc65b3c9068f07f64e08a1b043a0f8913d469fa-20261030T221806Z`.
Application 4bc differs from external deployment-tool c149/script42bcb1 and wrapper 894ec812.
Native audit SHA256: `d7830f62778f50d6740423c48ec141bb035ced3a0c6ce982f9dc9285f69a068c`.
Browser report SHA256: `33817d2964af33c311e127d5a6b0898aec953b455da589659ebd1188ff61a757`.
Recorded Chromium 141.0.7390.37/Playwright 1.56.1 uses one headless browser/worker.
Historical 731 public traces are numerical expectations, not a fresh baseline run;
actual new public method traces match them exactly. Prior hosted 7/7 belongs to 4bc,
not a new CI execution during this public check. Runtime/JSON/report paths are
under `.moai/reports/deploy-recovery/post-deploy-20261030/` in this tree.

## Gaps

No fresh full suite, coverage, dependency closure, all 66 hosted journeys, native zoom,
cross-browser run, stress/multi-user concurrency test or real rollback was executed.
Only first/last of five 2000-row windows were visited. Invalid-policy rejection and
all other product workflows were not repeated. Browser source identity depends on
separate native SSH proof; no manuscript/journal print claim follows from this check.

## Residual-risk

These point-in-time sessions do not establish continuous uptime or every input.
The tracked historical log omission is explicit. Keep prior release and deployment
logs; any later release requires fresh identity/runtime/UI verification. No old
one-time deployment wrapper, production mutation or failure injection was run by
this documentation task. Immutable manuscript assets and completed SPECs are untouched.
