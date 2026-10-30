# Cluster heatmap readability — 2026-10-30

## Claim

The R5 candidate implements the presentation changes specified in [SPEC-HEATMAP-001](../specs/SPEC-HEATMAP-001/spec.md). This report records a candidate awaiting hosted closure; it does not certify release or deployment. The separately reviewed [SPEC-HMAPCI-001](../specs/SPEC-HMAPCI-001/spec.md) repairs the CI harness; [SPEC-HMAPPORT-001](../specs/SPEC-HMAPPORT-001/spec.md) makes three source expressions ASCII-portable with identical output bytes.

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
baseline `73178628106d9b160831d476f80171e4f4d0bf61`. The original R5 hashes
are superseded only by the approved portability substitutions described below.
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

The independently approved portability source commit `88f3857` replaces exactly
three quoted literals in two R files with base `intToUtf8(8230L)` once and
`intToUtf8(8211L)` twice. Inverse byte proof reconstructs the baseline exactly;
CRLF is retained. Native ASCII RED becomes `character(0)` GREEN. Fresh installed
QA records31tests/337assertions, zero failures/errors/warnings/skips and four
goldens exact. All92 actual data/layout/config/choices/JSON comparisons pass,
including identical label/title/hover bytes and real native Shiny HTML without
ID normalization. Thirteen added title `Encoding()` diagnostics change unknown
to UTF-8; stored input, visible text/raw bytes and serialized JSON do not change.
Raw AST equivalence is not claimed: constructor nodes intentionally differ.
Five harness/QA files stay unchanged. Evidence: `heatmap-portability/qa/report.md`
and `code-review-r1.md`; approved proof is exact edits, native parse and runtime
output identity, not the abandoned diagnostic probe's three script errors.

Latest hosted run **41076765375**, source **4bc65b3**, records six successful jobs:
prepare, diagnostics, scan, negative, resources and browser. **Full remains active.**
`current-state.json` and downloaded prepare/diagnostics/scan source-head/digests
match current two R files, DESCRIPTION and runner. Prepare controls report
`tests: 3`, `failures: 0`, `errors: 0`, `skips: 0`, `passed: true` (21 scenarios).
Diagnostics candidate errors/warnings/information/hints/total are0; sync `PASS`,
`release_hold: false`. AST reports26documents/0findings/0errors/canarytrue.
Browser JSON records **expected66/unexpected0/skipped0/flaky0/errors[]**.
Both unchanged MV3 native-zoom cases pass with actual native proof attachments;
no bootstrap-source or deadline change was made. Serve terminal records
configured1800/status−15/signal15/reapedtrue/errornull: normal teardown.

Historical run41065823052 at b7b072f ended five jobs successful/two failed.
Its full artifacts record263Rtests/3125assertions, zero failures/errors/warnings/
skips, strict profile14/14PASS and coverage91.77607% against85%. Package check
ended0errors/1warning/5notes; the sole warning identified the three non-ASCII
literals in our two R files. This source compatibility issue required the new
candidate; it was not attributed to the environment. Historical browser65/1
failed before zoom proof at the unchanged desktop10000ms MV3 worker wait;
its cause remains unknown. Latest66/0 is fresh evidence, not a rewrite of65/1.
The distinct one-shot local SIGTRAP occurred before persistent-context acceptance;
owned cleanup and117unchanged files were verified, native zoom unobserved locally.

## Baseline-attribution

Documentation and fresh source hashes were measured in `/home/juhur/.moai/worktrees/projects/richStudio/heatmap-legibility`, branch `WT-heatmap-legibility`. Initial documentation reads used HEAD `3904602`; the current read measured HEAD `d613889e761c1717a8745f8781b599b80cd694c5`. Product/test/harness bytes match active hosted source `4bc65b3c9068f07f64e08a1b043a0f8913d469fa`; the committed tail changes documentation only.

```text
2380f070b6a85421960e9ecd0af29d64e60ee0eca94d7e78852fbedd2c11cf38  R/cluster_hmap.R
bf5dcb5e0d3eb7715ec9823c40c57fbb9686a7831dcc71be616eb2db568f50fb  R/clus_visualize_tab.R
fadc8cda247581b65ea6015b1aac4e9d984e6afd8f42dabd6c6e23071ced714a  DESCRIPTION
```

Original R5 QA used the immutable implementation-worktree installation
`.moai/reports/heatmap-legibility/impl/library-r5/richStudio` with R 4.6.1,
package version 0.1.6 and package RDB SHA256
`90760e1b7138d34c6227bd97e21cb8de65ca78f3ccfd88a513fdfc530ec547e8`.
Portability QA freshly installed `heatmap-r-portability/.moai/reports/heatmap-portability/impl/library-new/richStudio`, RDB SHA256 `5e1ca7d3b14e514fa0d33e4313c54e897965cce288fd24c9afbd3aaba8b7d99f`. Its observable equivalence attributes earlier R5 measurements to the three-expression correction; it does not pretend those earlier GUI runs used the new namespace.
Ignored integration artifacts are under `.moai/reports/heatmap-legibility/`:
`qa/candidate-r5/`, `code-review-r5.md` and `security/r2-review.md`.

## Gaps

- Latest run41076765375 full R/package/coverage job remains active; six successful
  jobs are not all-seven closure. Earlier full results are historical only.
- Historical MV3 bootstrap and local SIGTRAP causes remain unknown. First run
  41057333122 ended four jobs passed/three failed; original strict−9 cause and
  old reset's terminal exit remain unobserved.
- No candidate deployment measurement or completed SPEC status is claimed.

## Residual-risk

Controlled tests do not exhaust OS scheduling or real network failures. The
three-expression correction has exact installed observable identity, including
transparent diagnostic encoding differences. Final full-job success on the latest
source remains required; no gate, pin, native assertion or timeout is relaxed.
