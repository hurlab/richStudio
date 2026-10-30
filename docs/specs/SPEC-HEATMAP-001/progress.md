# Progress — SPEC-HEATMAP-001

## §E.1 Plan-phase Audit-Ready Signal

_Plan v0.1.2 independently APPROVED; see [the amendment review](../../../.moai/reports/heatmap-legibility/plan-review-v012.md). This approval covers the plan only._

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

### Current R5 candidate — complete labels inside the canvas

**Independent evidence backfill, as of 2026-10-30 13:57:02 UTC.** The source is
implemented and integrated: child commit
`47bde252f54cd1a54478e015e3e3abc84667a6c2`, integration merge
`390460288ec06afab90a8d792c321fb6d54c3033`. Fresh `git show -s` inspection verified
both identities. Fresh `sha256sum R/cluster_hmap.R R/clus_visualize_tab.R
DESCRIPTION` at integration HEAD `b7b072fad907d54258b22a0e746348f652ceb665`
matches all three frozen R5 hashes recorded below. Subsequent CI harness work is
tracked separately by SPEC-HMAPCI-001; it does not replace this product baseline.

Independent results were inspected, not rerun by the Implementer during this
backfill:

- `qa/candidate-r5/report.md`, `unit-receipt.json` and
  `snapshot-comparison.json`: QA's installed R5 invocation reports **31 tests,
  337 assertions passed, zero failures/errors/warnings/skips**. All four bundled
  and real-GSE hierarchical/DAVID snapshots pass all 28 exact identity checks
  across source tables, plot data, coordinates, values and hover. This is QA's
  later, differently scoped measurement; the Implementer's earlier 23/208 below
  remains its original attributed baseline.
- The same independent QA report and browser artifacts record **8 passed** at
  the required desktop/narrow viewports, including all row windows, both-edge
  label containment, actual PNG review, keyboard/resize, full 2000-row session
  save/reload, inert labels and visible 2001-row rejection with recovery.
- `qa/empty-state/report.md`, its `browser-results.json` and both per-project
  `empty-state-receipt.json` files add **2 independent GUI controls passed**,
  zero unexpected/skipped/flaky results and no page errors, against the same
  immutable R5 installed namespace. The correctly typed zero-row Empty0 result
  is loaded and explicitly selected at 1280×720 and 375×667: the honest hint is
  visible, viewer/window are hidden and actual canvas/SVG allocations are `[]`.
  Valid10 then recovers 20 exact quantitative cells and 10 readable labels with
  stable selection. Initial no-selection hint/window assertions already exist
  at `tests/e2e/heatmap-legibility.spec.ts:385`; the earlier missing-evidence
  wording for that initial state was too broad. The additional control closes
  the literal empty-data branch, without adding to or relabeling QA's earlier
  31/337 R measurement or eight main GUI cases. `source-unchanged.json` verifies
  all 104 measured tracked files byte-identical; `port-cleanup.json` records
  successful reuse-bind/close on 3891. No product or committed test changed.
- `code-review-r5.md` independently **APPROVED** the exact frozen source and
  verified odd/even Unicode excerpts and both short-term prefix/alias cases.
- `local-sync-r5/lsp-diagnostics.json` reports baseline and candidate totals
  **0**, `status: PASS`, sync `release_hold: false`; its inspected runner log
  says `Actual R JSON-RPC diagnostics and invalid canary verified` and
  `TypeScript membership verified: 11 intended inputs`.
- `security-final-r5/ast-grep.json` records **26/26 executed rule documents,
  0 findings, 0 errors, canary_detected: true**. These are the actual canonical
  receipts, not source-pattern substitutes for verification.

| Acceptance | Independent evidence inspected | As-of status |
|---|---|---|
| AC-001 | QA actual 141/366-row geometry at both viewports; 14px ticks, 18px pitch within subpixel rounding, both label edges contained, no document overflow. | PASS |
| AC-002 | QA 400/401/2000-row native windows, complete trace membership, first/last access and exact saved-session round trip. | PASS |
| AC-003 | QA keyboard edges, native navigation and desktop/mobile resizing retain the selected result and containment. | PASS |
| AC-004 | QA/reviewer original-ID/term preservation, distinct aliases and minimum Unicode excerpts; real hover and individual choices. | PASS |
| AC-005 | Four exact scientific snapshots, missing/zero tests, inert marker probes and actual note/axis/PNG nonintersection review. | PASS |
| AC-006 | Existing no-selection, 1/2/10-row, reset/selection/formula checks plus the two actual Empty0 selection/no-allocation/Valid10-recovery controls above. | PASS |
| AC-007 | QA actual normal/last-window camera downloads, full-height dimensions and reviewed bounds; all-row saved-session identity and reload pass. | PASS |
| AC-008 | QA visible policy-plus-one rejection, hidden navigation, connected-session recovery; direct early-admission regression passes. | PASS |
| AC-009 | Exact bundled/real hierarchical/DAVID tables/data/values/hover, ID/missingness behavior and full session restoration pass. | PASS |
| AC-010 | Final hosted41076765375 completed success7/7; full263/3125, Rcheck0errors/0warnings/5NOTEs, coverage91.76557%, LSP0 and AST26/0/0. | PASS |

The first hosted run `41057333122`, source `cbd3eb3`, ended with four successful
jobs and three failed jobs (`hosted-41057333122/final-state.json`). The new heatmap
browser cases passed; that does not certify the entire workflow. The separate
CI SPEC records a TLS transport failure, strict-process return -9 without a
proven cause, and older browser/lifecycle observations. The server reset's
relationship to a 900-second deadline remains an inference; the original exit
124 was not retained. No application full-suite verdict is inferred from these
failures. Fresh `gh run view 41065823052 --repo hurlab/richStudio --json
headSha,status,conclusion,jobs` reports source `b7b072f`: diagnostics, prepare,
negative and resources are successful; full, browser and scan remain
`in_progress`. There is no overall conclusion. **The hosted full-suite/package-check/coverage
verdict remains PENDING; this backfill does not mark the SPEC complete.**

**Historical implementer freeze claim.** R5 was frozen for independent final review/QA. Reflection before the
last allowed retry: earlier geometry checked label width and matrix-side bounds,
but missed Plotly's left tick padding. A236px text width was below the240px
column limit yet extended4.82px left of the canvas. R5 changes exactly two
compact-label budget constants from28to27columns. The compact alias delimiter,
eight-column Unicode excerpt minimum, one-character-term guard, all original
IDs/terms/trace cells and physical sizing remain intact. A longer ID may now use
its allowed display alias to keep the full meaningful term excerpt inside the
actual canvas; its full original ID remains in hover/choices/trace keys.

**Evidence.** The actual installed immutable R4 and fresh R5 widgets were opened
in the bundled Plotly2.25.2 renderer at640px width. Every SVG tick label was
measured against both canvas edges, and the actual native camera action downloaded
PNGs. `impl/r5/geometry-and-png.json` records:

| Actual installed widget | Minimum label left relative to canvas | Maximum text width | Right edge relative to canvas | Actual camera PNG |
|---|---|---|---|---|
| R4 normal141, reproduced failure |−4.815643px|236.015625px|231.199982px|1000×2788|
| R5 normal141 |+3.621857px|227.578125px|231.199982px|1000×2788|
| R5 last400of2000unique101-character IDs, A+wide-Unicode term |+15.043732px|216.15625px|231.199982px|1000×7450|

The normal trace retains282cells; the2000-ID trace retains4000cells with400active
SVG ticks in its last logical window. The aliased excerpt is
`Display row 2000|A中中中中…`, whose retained term has nine display columns before
ellipsis. All labels fit completely inside the left canvas edge and stop before
the matrix at240px. Actual camera downloads are `impl/r5/normal-r4.png`,
`normal-r5.png` and `alias-r5.png`. The viewed bottom-row comparison
`actual-png-bottom-row-comparison.png`, cropped from those actual downloads,
visibly confirms R4 clips the leading C in Cluster while R5 retains the whole
prefix. This establishes PNG text containment beyond a width-only inference.

Fresh installed R5 tests used the original two scoped files plus the current
independent parent QA legibility file, including both15/16-character one-letter
cases and the Unicode/single-row regressions (`impl/r5/tests.log`):

```text
   tests   passed   failed   errors warnings  skipped
      23      208        0        0        0        0
R/cluster_hmap.R STYLE_TOTAL 0
R/clus_visualize_tab.R STYLE_TOTAL 0
```

Air0.12 `format --check` and CRLF-aware diff check exited0. R5's product diff from
approved R4 is exactly the two27-column constants in R/cluster_hmap.R. No
integration-tree, R4 installation, test, SPEC body or other product file changed.

**Baseline-attribution.** This round measured child HEAD
`45c7a05ac5248233328671f709220aa11d066c65` (parent-authorized R4 commit) plus the
uncommitted two-constant fix. Branch remains WT-heatmap-legibility-impl.
Fresh installed package:
`/home/juhur/.moai/worktrees/projects/richStudio/heatmap-legibility-impl/.moai/reports/heatmap-legibility/impl/library-r5/richStudio`.
R/cluster_hmap.R SHA256:
`45916b7eaba82461bcfede67bdd85bae9a05e9dfe589abf00e45288c50bb4dd1`.
R/clus_visualize_tab.R and DESCRIPTION retain hashes
`f480db19cc719047da55d51092ad288959dcf9ffbe2ee10ee1a07c3e0df80722` and
`fadc8cda247581b65ea6015b1aac4e9d984e6afd8f42dabd6c6e23071ced714a`.
All R commands scrubbed profile/environment/site-library variables in the same
compound invocation, disabled renv autoloading and loaded the installed candidate
before supplied dependency libraries. Browser processes closed in finally blocks.

**Historical freeze gaps (superseded by the attributed backfill above).** Independent final code/security/Shiny QA, canonical JSON-RPC zero-LSP
and hosted CI verdicts remain their owners' pending measurements. The standalone
installed-widget browser/PNG check does not claim the complete application
acceptance matrix. Hosted integration-branch CI (`main`) owns the repository-wide
suite/check/coverage verdict, **PENDING** at this report time. No R5 commit,
staging, push or status transition was performed by the Implementer.

**Residual-risk.** Final QA must attribute complete browser/keyboard/resize,
scientific-golden and saved-session evidence to these frozen R5 hashes; prior R4
or R3 acceptance observations alone cannot close the new candidate.

### Historical R4 candidate — superseded by R5 below

**Claim.** R4 changes only the compact-label term guard from `budget >= 2L` to
`budget >= 1L`. Reflection before retry: the prior cases covered long excerpts,
Unicode boundaries and active single rows, but omitted a whole nonblank term
that exactly fits one remaining display column. The ellipsis logic and alias
reservation are unchanged; original source values and scientific order remain.

**Evidence.** The exact reviewer fixture, Cluster `1234567890123456` and term
`A`, was run against the immutable installed R3 before editing. The failing
assertion is retained in `impl/r4/red.log`:

```text
$labels
[1] "Cluster 1234567890123456"
$aliases
[1] FALSE
Error: grepl(" | A", y$labels, fixed = TRUE) is not TRUE
```

A distinct fresh installed R4 package produced (`impl/r4/tests.log`):

```text
ONE-CHARACTER FITTING TERM: Cluster 1234567890123456 | A PASS
   tests   passed   failed   errors warnings  skipped
      22      196        0        0        0        0
R/cluster_hmap.R STYLE_TOTAL 0
R/clus_visualize_tab.R STYLE_TOTAL 0
```

QA added the independently owned one-character regression after that scoped run
started. The final updated parent legibility file was therefore rerun separately
against the same immutable R4 installation (`impl/r4/qa-final-file.log`):

```text
   tests   passed   failed   errors warnings  skipped
      10      112        0        0        0        0
```

This final file covers original term/key/hover retention as well as visible
fitting term text. The unchanged other two scoped files passed in the first R4
run. Air0.12 check and CRLF-aware diff check exited0. No R3 installation, QA file,
SPEC body or other product source was edited in this round.

**Baseline-attribution.** Child HEAD remains
`58619449b5658423fa975155486af7ba64ae53de` plus uncommitted authorized source.
Fresh installed namespace:
`/home/juhur/.moai/worktrees/projects/richStudio/heatmap-legibility-impl/.moai/reports/heatmap-legibility/impl/library-r4/richStudio`.
R/cluster_hmap.R SHA256:
`fbb6b9dbc2c0cc83a0e6fb8fda1735d5de6baa11290a48e7da95897f4ce10966`.
Other two source hashes retain R2/R3 values. R invocations scrubbed profile,
environment and site-library variables in the same compound command and used
this installed namespace before the supplied dependency libraries.

**Gaps.** Independent final code/security/browser/export/golden acceptance,
canonical zero-diagnostic JSON-RPC sync and hosted CI remain their owners'
pending verdicts. Hosted integration-branch CI (`main`) owns the repository-wide
suite/check/coverage verdict, **PENDING** at report time. No commit, staging,
push or status transition was performed.

**Residual-risk.** This one-character guard correction does not re-establish all
Shiny/browser acceptance criteria; independent QA must attribute its final
results to the accepted frozen source. Prior R3 runtime evidence is historical.

### Historical R3 candidate — superseded by R4 below

**Claim.** R3 is frozen for independent review and QA. Reflection before this
retry: the R2 eight-column reservation overlooked a wide Unicode glyph at the
excerpt boundary, and the increased note margin left only30px of drawable space
in a nominal280px single-row figure. Exact trace/range checks did not establish
actual active SVG tick rendering. R3 uses the compact `|` alias delimiter and
reserves an extra Unicode boundary column for normal labels, while retaining
28 total monospace display columns. It gives small logical windows a90px minimum
drawable band independently of bottom margins. Larger windows retain18px row
pitch and all scientific/category/trace data remain unchanged.

**Evidence.** Before edits, installed R2 reproduced the reviewer probe:
`Display row 2000 | A中中中…` (seven term display columns). Actual bundled
Plotly2.25.2 browser probes rendered no single-row SVGticks at drawable bands
30/50/60/65/70/75/80px, and rendered the identical category/range/tick text at90px
and150px. The measured sweep is `impl/r3/axis-sweep.json`; the initial pre-edit
probe output is retained in the tool transcript. QA also reproduced these RED
boundaries against the immutable R2 install and owns the added regression tests.

Fresh installed R3 checks used the original two scoped files and the explicit
amended parent legibility-test path. Observed output (`impl/r3/tests.log`):

```text
   tests   passed   failed   errors warnings  skipped
      22      196        0        0        0        0
```

The actual installed-widget browser probe (`impl/r3/installed-browser-probe.json`)
observed:

| Probe | Actual SVG ticks | Drawable band / physical height | Trace cells |
|---|---|---|---|
| Single cluster5 | 1: Cluster5 prefix plus term |90px /340px|2|
|401rows, final one-row window |1: Cluster5 prefix plus term|90px /340px|802|
|2000unique101-character IDs, last400logical rows |400, including Display row2000 with full A中中中中中 term |7200px /7450px|4000|

The2000-ID probe's maximum measured label width was221.71875px, within240px.
This probe used the actual saved installed widget and its bundled Plotly renderer;
it is separate from QA's complete Shiny/keyboard/export journeys. Source style
classification (`impl/r3/style.log`) reports0findings for both R files. Air0.12
check and CRLF-aware diff check exited0. R2 library/logs remain immutable.

**Baseline-attribution.** Child HEAD remains
`58619449b5658423fa975155486af7ba64ae53de` plus authorized uncommitted source.
Fresh package path:
`/home/juhur/.moai/worktrees/projects/richStudio/heatmap-legibility-impl/.moai/reports/heatmap-legibility/impl/library-r3/richStudio`.
R/cluster_hmap.R SHA256:
`f72fcebd2d54c12180e2993d5726f5d7888e62c66b8f8aa87e6d6139b56017c1`.
R/clus_visualize_tab.R and DESCRIPTION retain R2 hashes
`f480db19cc719047da55d51092ad288959dcf9ffbe2ee10ee1a07c3e0df80722` and
`fadc8cda247581b65ea6015b1aac4e9d984e6afd8f42dabd6c6e23071ced714a`.
Every R measurement used the fresh installed namespace with scrubbed environment
and the supplied dependency libraries; no mixed-source evaluation established a
completion claim.

**Gaps.** Final independent Shiny browser/PNG/scientific-golden/security/code
review, canonical zero-diagnostic JSON-RPC sync and hosted CI remain pending.
No full-criterion AC-001–AC-010 closure is asserted by these scoped measurements.
Hosted integration-branch CI (`main`) owns the repository-wide suite/check/coverage
verdict, **PENDING** at report time. No commit/stage/push or status transition has
been performed by the Implementer.

**Residual-risk.** Full application row-window interaction and all actual camera
artifacts require QA re-verification against these frozen R3 hashes. The scoped
browser probes establish active ticks and the specific Unicode geometry, not the
entire application acceptance matrix.

### Historical R2 candidate — superseded by R3 below

**Claim.** R2 is ready for independent review and installed-browser QA under the
parent SPEC v0.1.2 amendment. Before retrying, the Implementer reflected on four
R1 verification gaps: package metadata was not checked, the compact-prefix budget
could exhaust the term excerpt, note-in-canvas did not establish nonintersection
with rotated axis text, and a direct R resource failure did not establish a
visible recoverable Shiny response. The revised candidate addresses each gap:

- DESCRIPTION declares only already mandatory htmltools/htmlwidgets Imports,
  after reading the SPEC owner's amended scope. No version pin or lock changed.
- Normal prefixes reserve eight term display columns (or the whole shorter term)
  before ellipsis; display aliases supply room when needed. Full IDs, terms,
  source tables and scientific trace data retain their prior identity.
- Fixed-angle, fixed-size dataset ticks/title receive a separate pixel band above
  the unchanged explanation. The row-height calculation includes that bottom
  margin; maximum allocated plot height is 8190px and camera width remains1000px.
- Resource admission failures render through a text-safe Shiny alert, with no
  error thrown through the visibility observer. Invalid window UI stays hidden;
  choosing a valid result reuses the connected session. The direct heatmap gate
  still rejects before aggregation.

**Evidence.** A new install was built at `impl/library-r2`, leaving R1 immutable.
The actual installed test run used the two original scoped files plus the amended
parent `tests/testthat/test-heatmap-legibility.R` by explicit absolute path.
Observed command output (`impl/r2/tests.log`):

```text
   tests   passed   failed   errors warnings  skipped
      20      177        0        0        0        0
```

The amended parent test was first run against the immutable R1 install. Actual
RED output before R2 edits, retained verbatim in `impl/r2/red.log`:

```text
── 1. Failure ('test-heatmap-legibility.R:183:3'): long fitting IDs leave a visi
Expected `all(grepl("Shared", labels, fixed = TRUE))` to be TRUE.
Differences:
`actual`:   FALSE
`expected`: TRUE
```

`tools:::.check_packages_used(package="richStudio")` against the R2 installed
namespace no longer reports undeclared htmltools/htmlwidgets use. Its remaining
output is the prior unused-Imports note (`impl/r2/dependencies.log` and `.rds`):

```text
Namespaces in Imports field not imported from:
  ‘bioAnno’ ‘config’ ‘data.table’ ‘ggplot2’ ‘Rcpp’
  All declared Imports should be used.
R/cluster_hmap.R STYLE_TOTAL 0
R/clus_visualize_tab.R STYLE_TOTAL 0
```

The separate installed `shiny::testServer` probe selected2001rows, inspected the
resource alert, selected a valid two-row result in the same session and checked
that the rejected stored result still had2001rows (`impl/r2/recovery.log`):

```text
INSTALLED RESOURCE REJECTION ALERT + SAME-SESSION VALID-RESULT RECOVERY PASS
```

That separate2001-row probe also emitted Shiny's existing advisory that the
individual-cluster selector has many options. It is not hidden or counted as a
warning-free browser test; the scoped suite above had zero warnings.
Air0.12.0 `format --check` and `git -c core.whitespace=cr-at-eol diff --check`
both exited0. R files retain CRLF; DESCRIPTION retains LF.

**Baseline-attribution.** All R2 checks measured child HEAD
`58619449b5658423fa975155486af7ba64ae53de` plus these uncommitted files, installed at
`/home/juhur/.moai/worktrees/projects/richStudio/heatmap-legibility-impl/.moai/reports/heatmap-legibility/impl/library-r2/richStudio`.
SHA256 R/cluster_hmap.R:
`de60be325feefde433dcbf0ce8aeffb9094fe20d5c7da1aeb192068dd27ed3da`;
R/clus_visualize_tab.R:
`f480db19cc719047da55d51092ad288959dcf9ffbe2ee10ee1a07c3e0df80722`;
DESCRIPTION:
`fadc8cda247581b65ea6015b1aac4e9d984e6afd8f42dabd6c6e23071ced714a`.
R invocations scrubbed profile/environment/site-library variables in the same
compound call, disabled renv autoloading and selected this installed library
before the supplied dependency libraries. Original R1 installation is unchanged.

**Gaps.** Current full-criterion AC-001–AC-010 verdicts remain pending independent
QA/review; the R/probe checks establish only their observed subclauses. In
particular actual PNG note nonintersection, mobile/desktop geometry, reconnect
behavior in a browser and camera whole-window dimensions belong to QA. Canonical
zero-diagnostic JSON-RPC sync and repository-wide hosted CI verdict are pending.
Hosted integration-branch CI (`main`) owns the repository-wide suite/check/coverage
verdict, **PENDING** at this report time. No commit/stage/push was performed.

**Residual-risk.** The explicit28-column monospace budget and dataset annotation
band still require actual font/export geometry verification; installed R tests
alone cannot prove their rendered bounds. The R1 code-review findings should be
closed by their independent owners against these R2 hashes.

### Historical R1 evidence — superseded by current R2 above

### Claim

The implementation candidate is ready for independent review and installed-browser
QA. Display allocation uses at most 400 visible categories, 18px row pitch, 14px
monospace tick text and a native bounded figure viewport. Every scientific trace
row remains present. Resource admission precedes aggregation. No public interface,
dependency, global stylesheet or policy changed. No dedicated CSS/client file was
needed: scoped styles and a fixed client sizing/scroll-reset hook reside in
R/clus_visualize_tab.R. No result string enters that client hook.

### Evidence

Installed scoped command (after a fresh `R CMD INSTALL --no-multiarch
--no-test-load --library=.moai/reports/heatmap-legibility/impl/library .`):
`testthat::test_dir("tests/testthat", filter =
"^(heatmap-legibility|cluster-heatmap-scientific|lsp-warning-regressions)$",
package = "richStudio", load_package = "installed", reporter = "summary",
stop_on_failure = TRUE)`.
Every R invocation scrubbed `R_PROFILE_USER R_ENVIRON_USER R_LIBS_SITE` in the
same compound invocation and set `RENV_CONFIG_AUTOLOADER_ENABLED=FALSE` plus the
candidate/dependency library paths. Observed output:

```text
   tests   passed   failed   errors warnings  skipped
      19      171        0        0        0        0
```

The original pre-edit RED invocation was observed before any source mutation:
6 feature failures, 71 passing assertions, 0 errors and warnings. Its verbatim
failure text is preserved in the Implementer tool transcript; an unchanged
installed-baseline rerun retained the same verbatim output in
`.moai/reports/heatmap-legibility/impl/red.log`:

```text
RED tests 6 passed 71 failed 6 errors 0 warnings 0
```

Final candidate logs: `.moai/reports/heatmap-legibility/impl/tests.log`,
`test-results.csv`, `install.log` and `style.log`. Source-only style findings,
classified separately from package-context object-usage diagnostics:

```text
R/cluster_hmap.R STYLE_TOTAL 0
R/clus_visualize_tab.R STYLE_TOTAL 0
```

Air 0.12.0 `format --check R/cluster_hmap.R R/clus_visualize_tab.R` exited 0;
`git -c core.whitespace=cr-at-eol diff --check` exited 0. Both modified R files
retain their original CRLF line endings.

| Criterion | Actual Output | Status |
|---|---|---|
| AC-001 | Scientific cells retained for 1/2/141/366/400/401/2000; installed browser geometry pending. | PENDING QA |
| AC-002 | Default 401/2000 views have numeric range spanning 400 with unchanged categoryarray/full traces; interactive window QA pending. | PENDING QA |
| AC-003 | Focusable named native region and native dropdown implemented; actual keyboard/resize QA pending. | PENDING QA |
| AC-004 | Long Unicode shortening, full original chooser/hover strings and distinct long-ID labels pass installed R tests; rendered label QA pending. | PENDING QA |
| AC-005 | Missing/zero/data-preservation tests pass without warnings; browser marker/note geometry QA pending. | PENDING QA |
| AC-006 | Existing selected-result stability test passes; empty/small/browser reset QA pending. | PENDING QA |
| AC-007 | Bounded full-logical-window camera dimensions configured; actual downloaded artifact QA pending. | PENDING QA |
| AC-008 | Installed policy+1 test rejects before mocked preparation is reached; policy unchanged. | PASS (scoped R) |
| AC-009 | Existing scientific heatmap tests and exact fixture cells pass; independent real/bundled baseline comparison pending. | PENDING QA |
| AC-010 | Air and source style pass; actual JSON-RPC diagnostics, independent security/review and hosted CI pending. | PENDING |
| Invariant: no source table/value/NA/zero mutation | Exact fixture values and original input object checks pass for admitted boundary counts. | PASS (scoped R) |
| Invariant: every scientific trace row retained | Full coordinate/trace counts and unchanged categoryarray pass, including 2000 rows. | PASS (scoped R) |
| Invariant: reviewed scope and verification gates preserved | Only owned R files changed; no new dependency, policy or global stylesheet. | PASS (diff inspection) |

### Baseline-attribution

Measured tree:
`/home/juhur/.moai/worktrees/projects/richStudio/heatmap-legibility-impl`,
branch `WT-heatmap-legibility-impl`, HEAD
`58619449b5658423fa975155486af7ba64ae53de` plus uncommitted owned implementation.
Installed package:
`/home/juhur/.moai/worktrees/projects/richStudio/heatmap-legibility-impl/.moai/reports/heatmap-legibility/impl/library/richStudio`.
Source SHA256: R/cluster_hmap.R
`0af0a6031ff5e5da2af79e794522e1c2b6f9e806b9465899c4ce42f7b07eb016`;
R/clus_visualize_tab.R
`79f5e60b95c88bcdf02451cdaee6b26051fbca33044c953c8045c1ee09b04e42`.

### Gaps

Independent browser/export/scientific baseline comparisons and security/code review
remain unobserved by the Implementer. Source style counts are not a zero-LSP
claim. Canonical actual JSON-RPC sync diagnostics run on the integration candidate.
No commit/staging/push was authorized for this agent; draft-to-in-progress status
transitions remain for the authorized first run-phase commit. Repository-wide
suite/check/coverage verdict belongs to the hosted CI run on the integration
branch (`main`) and is **PENDING** at this report time.

### Residual-risk

Browser rendering, focus/scroll behavior and actual camera artifacts require the
independent QA checks before closure. Row labels use bounded monospace display
width to avoid graphics devices and release-directory output; rendered font
fallback and note bounds still require actual browser measurement.


## §E.3 Run-phase Audit-Ready Signal

```yaml
run_complete_at: "2026-10-30T15:58:22Z" # Final hosted completion; original source commit retained below.
run_commit_sha: 47bde252f54cd1a54478e015e3e3abc84667a6c2
integration_commit_sha: 390460288ec06afab90a8d792c321fb6d54c3033
evidence_inspected_at: "2026-10-30T13:57:02Z"
run_status: final-hosted-seven-jobs-success-and-acceptance-pass
hosted_run: 41076765375
hosted_source_sha: 4bc65b3c9068f07f64e08a1b043a0f8913d469fa
ac_pass_count: 10
ac_fail_count: 0
ac_pending_count: 0
preserve_list_post_run_count: 2
l44_pre_commit_fetch: root-managed-not-measured-by-this-backfill
l44_post_push_fetch: root-managed-not-measured-by-this-backfill
new_warnings_or_lints_introduced: 0-final-hosted-test-Rcheck-and-canonical-LSP
cross_platform_build:
  local_installed_candidate: pass
  hosted_ci: PASS-run-41076765375-seven-jobs
product_source_file_count: 3
total_run_phase_files: null # Whole run-phase attribution is root-managed, not remeasured here.
m1_to_mN_commit_strategy: root-managed-recorded-R4-and-R5-source-commits-no-git-policy-verdict-by-backfill
```

## §E.4 Sync-phase Audit-Ready Signal

```yaml
sync_complete_at: 2026-10-30T18:05:05Z
sync_commit_sha: 8500d2d8aeee964e49c829842e4f56c378858bde
sync_status: completed-all-seven-hosted-jobs-pass
documentation: docs/quality/heatmap-legibility-20261030.md
ac_source: docs/specs/SPEC-HEATMAP-001/acceptance.md
tier: M
b12_self_test_a: not-run-no-CHANGELOG-emission
b12_self_test_b: not-run-no-CHANGELOG-emission
b12_self_test_c: not-run-no-CHANGELOG-emission
changelog_entry_position: none
frontmatter_status_transitions:
  status: in-progress-to-implemented-to-completed
  updated: 2026-10-30
local_evidence:
  scoped_result: 31-tests-337-assertions-four-goldens-eight-main-GUI-two-empty-GUI-all-pass
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
