# SPEC-WS-014 M2 record

Runtime auto-install of allowlisted species annotation packages (REQ/AC-WS-014-018..030).

## Implementation map

| Piece | Where |
|---|---|
| Allowlist reader, resolver, presence and library checks, status reader, detached launcher, decision rules, request records, Stop/Retry/Dismiss, dropdown choices, provenance helper | `R/annotation_packages.R` |
| Run gate: the job admission is one closure that starts now, or when the install finishes; dropdown choices from the allowlist | `R/enrich_tab.R` |
| Install row in the tray (shares the `jobs_list` output, so the tray keeps one polite region), badge counts an install as a job, Stop/Retry/Dismiss actions | `R/workspace_jobs.R` |
| Additive `annotation$packages` | `R/enrichment_background.R` |
| Tests | `tests/testthat/test-annotation-packages.R`, `tests/testthat/helper-annotation-repo.R`, `tests/e2e/annotation-install.spec.ts` with `tests/e2e/annotation-app.R` |

## Notes on changes to existing behaviour

- The species dropdown now comes from the allowlist: `sco` and `toxoplasma` are no longer offered, and an available species that is not installed carries "installs on first use, about N MB". The default (`human`) and every other value are unchanged.
- With `RICHSTUDIO_ANNOTATION_LIB` unset the Run observer behaves exactly as before (no resolver, no install row); the shipped host sets it through the release `.Renviron`.
- The tray's `jobs_list` output now also carries the install rows, so the existing output ids and the single polite live region are unchanged; `test-workspace-components.R` (exactly one polite region, three quiet outputs) passes unchanged.
- The job badge counts a waiting annotation install as a running job and a finished one as finished, so the badge that opens the tray exists while only an install is on the board.
- No existing assertion was changed. The existing background-record key tests pass unchanged because `annotation$packages` is omitted when no annotation package is installed (the test environment has none).
- Left unchanged on purpose (separate polish item): after a run the gene-list selection is cleared and Run stays clickable with nothing selected.

## Host acceptance (lead, after the M2 deploy)

AC-028: run yeast (SYMBOL, GO, `org.Sc.sgd.db`, about 15 MB, not pre-installed) through the live browser; the row shows installing and then done, the enrichment completes with result rows, `INSTALLED.tsv` has an `org.Sc.sgd.db` row with version and sha256, and `stat -c '%U' <lib>/org.Sc.sgd.db` prints `juhur`.

- Commands and outputs: PENDING-LEAD
