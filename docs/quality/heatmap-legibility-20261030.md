# Cluster heatmap readability — 2026-10-30

## Claim

The R5 candidate implements the presentation changes specified in [SPEC-HEATMAP-001](../specs/SPEC-HEATMAP-001/spec.md). This report records a candidate awaiting hosted closure; it does not certify release or deployment. The separately reviewed [SPEC-HMAPCI-001](../specs/SPEC-HMAPCI-001/spec.md) repairs the CI harness while preserving the frozen application.

The summary heatmap uses at least 18px per row and 14px row-axis text. Its focusable region, named **Cluster heatmap**, scrolls within the smaller of 720px and 70% of the browser height. Figure overflow stays inside that region. Use Tab to focus the region and native keyboard scrolling to explore its rows.

For results above 400 rows, the native **Cluster row window** dropdown selects consecutive windows of at most 400 rows. The title identifies the logical range and total. Windows follow the existing top-to-bottom display order: with original categories 1–2000, rows 1–400 show IDs 2000–1601 and rows 1601–2000 show IDs 400–1. Selecting another result resets the window and scroll position. The dropdown is hidden for results of at most 400 rows and empty selections.

Compact labels retain a `Cluster <original ID>` prefix and representative-term excerpt. If that prefix leaves insufficient space, `Display row <r>` identifies the stable position in the complete rendered order. A notice explains aliases; cell hover maps each alias to its complete original ID and term. The labels are presentation text, not replacement scientific identifiers.

The camera download includes the entire selected logical window, even after scrolling, with the row range/total and existing missing/zero explanation. For more than 400 rows it is a partial-result image. Use the existing tabular or saved-session exports for all result rows. Plot/image dimensions remain bounded by 8192px. The installed render-row policy remains authoritative, currently 2000 rows; oversized requests receive a visible resource-limit response and can be followed by a valid selection in the same session.

The intended numerical and public-interface contract is unchanged. All trace rows remain present while windows change visibility. The measured golden comparisons below support exact preservation for their four fixtures; they do not establish equivalence for every possible input.

## Evidence

R5 source review approves source integration with final gates open. R2 security
review closes the direct-import issue through `tools:::.check_packages_used(dir=getwd())`:
`R2_UNDECLARED_IMPORTS_ZERO`. This is R2 evidence, not a fresh R5 security run.

These documentation-preparation commands inspect stored QA results; the author
did not rerun the R or browser tests.

```bash
sed -n '1,36p' .moai/reports/heatmap-legibility/qa/candidate-r5/unit-and-golden.log
tail -n 18 .moai/reports/heatmap-legibility/qa/candidate-r5/unit-and-golden.log
cat .moai/reports/heatmap-legibility/qa/candidate-r5/snapshot-comparison.json
tail -n 6 .moai/reports/heatmap-legibility/qa/candidate-r5/browser.log
sha256sum R/cluster_hmap.R R/clus_visualize_tab.R DESCRIPTION
tail -n 8 .moai/reports/heatmap-legibility/security-final-r5/ast-grep.json
```

The installed R5 log records 31 tests, 337 assertions, 337 passed and zero
failures, errors, warnings or skips. Its final output is verbatim:
`IMMUTABLE_BASELINE_COMPARISON_PASS`.

The JSON records `true` for each of `summary`, `details`, `plot_data`, `x`, `y`,
`z` and `hover` in all four full golden comparisons:

| Fixture and method | Rows | Cells | Missing cells |
|---|---:|---:|---:|
| Bundled hierarchical | 141 | 282 | 108 |
| Bundled DAVID | 139 | 278 | 105 |
| GSE63310 hierarchical | 366 | 2196 | 977 |
| GSE63310 DAVID | 254 | 1524 | 5 |

The final R5 static-scan JSON records `"executed_documents": 26`,
`"findings": 0`, `"errors": 0`, `"blocking": true` and `"canary_detected": true`.

Final canonical R5 LSP evidence in `local-sync-r5/lsp-diagnostics.json` records
`R --slave -e 'languageserver::run()'`: baseline and candidate each have zero
errors, warnings, information, hints and total diagnostics. Status and sync are
`PASS`, `release_hold` is `false`; `tsc --noEmit --project tsconfig.json` exits 0.
`cat .moai/reports/heatmap-legibility/local-sync-r5/runner.log` reports
`TypeScript membership verified: 11 intended inputs` and
`Actual R JSON-RPC diagnostics and invalid canary verified`.
The measured source is `390460288ec06afab90a8d792c321fb6d54c3033`, with numerical
baseline `73178628106d9b160831d476f80171e4f4d0bf61`; the three source hashes below
remain unchanged at the subsequent documentation/status commit.
The orchestrator records exit0 for the environment-scrubbed, explicitly supplied
R libraries invocation of `timeout --kill-after=10s 1200s bash scripts/test-workspace.sh diagnostics sync`;
`local-sync-r5/runtime.txt` records library provenance.

Final `qa/candidate-r5/browser-results.json` records `expected: 8`, `skipped: 0`, `unexpected: 0`, `flaky: 0`, with `errors: []`; the terminal log says `8 passed`. Command: `npx --no-install playwright test --config=.moai/reports/heatmap-legibility/qa/candidate-r5.config.ts`. All eight Chromium cases passed at 1280×720 and 375×667, covering dense/real data, keyboard windows, camera export, complete saved-session reload, missing/hostile labels, resize and recoverable policy-plus-one rejection.

The final R5 QA report verifies native downloaded PNGs at 1000×6890 and
1000×7450 on both viewports: complete leading labels, logical rows and NA/zero
note. Shutdown leaves no listener and a successful reuse-bind. Later
`qa/empty-state/report.md` records 2/2 desktop/narrow empty-data controls:
no plot allocation for Empty0, then Valid10 recovery with 20 cells/10 labels;
104 measured files stay unchanged. Initial no-selection is also already asserted.

The CI followup's independent code/security reviews approve the bounded repair.
Local QA records 21 controlled cases (9 ownership, 10 transport, 2 watchdog),
three groups with zero failures/errors/skips, plus six actual GUI cases passed.
Canonical focused entry point:
`python3 scripts/test-ci-harness-regressions.py --tree <absolute-candidate-tree> --artifacts <evidence-directory>`.
Its prepare-job invocation exercises the same owned runner. Nonce observations
require fresh identity; unsafe ownership fails without signaling. Transport retries
are bounded and exclude HTTP/certificate/digest/install failures. The same
1800-second serve path records actual terminal status; controlled normal7 and
timeout124 cases both reap children. All 11 archive pins, strict-check90 and
seven jobs remain unchanged; QA records 52 frozen application files unchanged.

Fresh downloaded hosted run **41065823052** uses source **b7b072f**.
`current-state.json` records prepare/diagnostics/negative/resources/scan success,
full in progress and browser failure. Prepare's `regression-summary.json` says
`tests: 3`, `failures: 0`, `errors: 0`, `skips: 0`, `passed: true`.
Hosted diagnostics record candidate errors/warnings/information/hints/total0,
sync `PASS`, `release_hold: false`; artifact source-head matches b7b072f.
Browser JSON records expected65/unexpected1/skipped0/flaky0. Its actual
`serve-terminal.json` records configured1800, terminal_status−15, signal15,
reapedtrue, errornull: normal Playwright teardown, not a reached deadline.

Independent `native-zoom-triage.md` attributes the sole hosted failure to the
unchanged desktop MV3 worker wait (10000ms), before native zoom assertions.
Narrow actual native zoom1→2→1 passes. Cause remains unknown. The triage permits
one same-SHA failed-job retry only after run termination, retaining the first
result. A separate single local probe exits on SIGTRAP before persistent-context
acceptance; it proves neither native zoom success nor the hosted cause. Its
owned cleanup is verified and 117 measured files remain unchanged.

## Baseline-attribution

Documentation and fresh source hashes were measured in `/home/juhur/.moai/worktrees/projects/richStudio/heatmap-legibility`, branch `WT-heatmap-legibility`. Initial documentation reads used HEAD `3904602`; the current read measured HEAD `08e947173b56160510adad1a36e4c02296fb570d`. Product/test/harness bytes match hosted source `b7b072fad907d54258b22a0e746348f652ceb665`; subsequent commits change progress metadata only.

```text
45916b7eaba82461bcfede67bdd85bae9a05e9dfe589abf00e45288c50bb4dd1  R/cluster_hmap.R
f480db19cc719047da55d51092ad288959dcf9ffbe2ee10ee1a07c3e0df80722  R/clus_visualize_tab.R
fadc8cda247581b65ea6015b1aac4e9d984e6afd8f42dabd6c6e23071ced714a  DESCRIPTION
```

QA used the immutable implementation-worktree installation
`.moai/reports/heatmap-legibility/impl/library-r5/richStudio` with R 4.6.1,
package version 0.1.6 and package RDB SHA256
`90760e1b7138d34c6227bd97e21cb8de65ca78f3ccfd88a513fdfc530ec547e8`.
Ignored integration artifacts are under `.moai/reports/heatmap-legibility/`:
`qa/candidate-r5/`, `code-review-r5.md` and `security/r2-review.md`.

## Gaps

- Run41065823052 full-job outcome and the authorized same-SHA browser retry are
  not terminal in this snapshot. Five successful jobs are not all-seven closure.
- The first browser failure's worker lifecycle/cause remains unobserved. The
  earlier run41057333122 ended four jobs passed/three failed; its unexplained−9
  cause and old server-reset terminal exit remain historical gaps.
- No candidate deployment verification or completed SPEC status is claimed.

## Residual-risk

Controlled ownership/transport tests do not exhaust OS scheduling or real network
failures. The local SIGTRAP and hosted MV3 wait are different observed phases;
neither warrants a speculative source or timeout change. Final same-source hosted
success is required with every native-zoom/identity/restore assertion retained.
