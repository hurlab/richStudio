# Compact workspace layout — 2026-10-30 draft

## Claim

The frozen candidate for [SPEC-COMPACTUI-001](../specs/SPEC-COMPACTUI-001/spec.md)
reduces primary-form spacing across seven workflow menus while retaining controls,
review/help content, typography and scientific behavior in scoped checks.
Independent source/security reviews approve the frozen presentation scope.
This is a draft local-evidence report: hosted seven-job CI, final audit and
production deployment remain pending. No SPEC completion is claimed.

Enrich places upload/configuration alongside each other on desktop, related
annotation fields in columns, and previews/results full-width below. Narrow
fields stack. Manage Files pairs related selectors/names; other routes retain
useful existing groups with scoped spacing. No cloned controls, hidden warnings,
smaller typography, floating Run action or scientific-plot shrink is introduced.

## Evidence

Documentation inspected actual implementation, independent QA, source/security
reviews and local tool receipts under `.moai/reports/layout-density/`; it did
not rerun tests. Scoped commands include:

```sh
Rscript --vanilla .moai/reports/layout-density/impl/preserve.R
Rscript --vanilla .moai/reports/layout-density/impl/runtime-identity.R
bash .moai/reports/layout-density/qa/run-focused.sh regressions --grep 'DEG preview and commit are labelled|dense bundled-size|all admitted rows|saved scientific boundary|panel survives navigation'
./node_modules/.bin/tsc --noEmit --pretty false
```

Recorded output includes `PRESERVATION PASS: 17 non-UI definitions; seven UI
control/help expression inventories`, `IDENTITY PASS`, `10 passed` protected
regressions and TypeScript exit0. Actual `qa/authoritative-results.json` contains
**32 passed cases: 22 new plus 10 unchanged protected**. The final local ledger
contains 40 cases: 38 passed and two native-zoom launch failures;450 retained
artifacts are inventoried. Final QA report SHA256 is
`fefe0e5b89a8afdb3b831c1f313d388d7b57c93bf577062f64fc7c8197b7c906`. Tests cover all seven menus
at 1440×900,1280×720, 375×667, 768×1024 and 1024×768; 35 settled menu captures pass
control/document bounds. All seven wide and seven narrow captures were visually
inspected; other viewports have retained screenshots and mechanical bounds.

| Matched metric, CSS pixels | Baseline | Candidate |
|---|---:|---:|
| Initial Run bottom, both desktop sizes |1243.03125|526.265625|
| Populated primary span,1440 |1044.34375|641.65625 (38.56% reduction)|
| Populated primary span,1280 |1044.34375|661.65625 (36.64% reduction)|
| Populated Enrich full document,1440 |1831|2429|
| Populated Enrich full document,375 |3849|3653|
| Cluster figures full document,1440 /375 |1727 /2179|1611 /2050|
| Manage Files full document,1440 /375 |1014 /1690|900 /1533|
| Save/Load full document,1440 /375 |1047 /1677|957 /1530|

The wide Enrich page is longer because real files/preview move below the compact
primary area; no total-page reduction is claimed. Initial Run visibility and
populated primary-span reduction are distinct criteria. Matched populated state
retains full review text/digest 34ff201542ea, GO/SYMBOL/BP/human, 31 kept/submitted/
distinct genes and 48 exclusions. No one of 37 matched buttons shrinks in font/height.
Preview versus committed revision, keyboard focus, navigation/resize selections,
method-specific dynamic controls and Reset defaults pass their scoped journeys.

Protected checks retain Dense141/GSE366 values/NA and 18px row pitch/14px labels;
400/401/2000 windows preserve full traces and save/reload. Actual PNGs 1000×6890
and 1000×7450retain logical full-window labels/axes/notes and were inspected.
Safe Run uses a fixed-result isolated worker fixture, not new network inference.

Primitive-browser JSON separately records **6 expected/2 unexpected/0 skip/0 flaky**:
two unchanged native Chromium zoom cases hit SIGTRAP before page acceptance.
No native 200% pass or failure cause is inferred. Existing component R output
contains 138 passing assertions; the new rendered-control suite has two passing
blocks/59 assertions. Independent cleanup finds 16 recorded PIDs gone and 3871/3872
reuse-binds pass. Failed native scratch is retained with safe=false; no third
native retry or successful launch is implied. Successful phases retain their
own reaped=true receipts.
Local tooling diagnostics record candidate errors/warnings/information/hints/
total 0 over 27 R files per stage, sync PASS/release_hold false; AST 26 documents/
0findings/0errors/canarytrue. Prepare passes 12 TypeScript inputs/five policy tests.
Air exit 1 retains the same unchanged Save-helper indentation suggestion in both
baseline and candidate; it is not reported as a clean formatter pass.

## Baseline-attribution

Tree `/home/juhur/.moai/worktrees/projects/richStudio/compact-workspace-layout`,
HEAD 7355100cffd15d2999fde130bc85dfab8f78926e plus eight frozen production edits.
Baseline 7beaa52b3081721689586211f2d5fe530cc810ba has the deployed 4bc UI/CSS bytes.
Only seven static UI definitions and appended scoped CSS change; 17 non-UI
functions, including seven servers, and protected science/helpers remain exact.
Complete 33777-byte CSS prefix is unchanged; 1026 bytes are appended. The authorized
existing-test exception replaces exactly one full-CSS digest literal; assertions,
primitive rules, policies and dependency pins are preserved.

Installed candidate RDB SHA256:
`7168c3b08d7865e6e26fd910d2c836162aa25776cd95162a15f9d3f8cea598bd`.
Source/installed/served CSS SHA256:
`b3c1ad641912f6597f5cdc6c2324fb59e66d70c38d2133efbb855cde30d1e78f`.
R 4.6.1, Playwright 1.56.1, one headless Chromium worker/no retries. Numerical
baselines, corrected settled captures and current installed identities retain
separate original receipts; historical/transient failures are not overwritten.

## Gaps

Same-source seven-job hosted CI and final independent audit are outstanding.
Local native zoom remains unobserved after the pre-page crashes. No fresh local
full R suite/package check/coverage, production deployment or new inference was
performed. Hidden combinations and universal browser/device coverage are not
exhaustively verified. Earlier implementation duplicate-subtree and QA generic
collector mistakes were corrected with retained failed histories, not weakened
control/primitive assertions; final evidence is attributed separately.

## Residual-risk

Scoped CSS and preserved source do not prove every future dynamic input or data
size. Native DataTables retains its own controls/scrollers. Keep the frozen source
and exact CSS identity through publication and hosted checks; later source changes
need renewed scoped verification. The candidate's local improvements and approvals
do not establish production behavior or all-ten-criterion completion.
