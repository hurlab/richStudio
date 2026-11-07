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

- Live run (lead, 2026-11-07 UTC; headless browser, direct over Tailscale, no tunnel). Deployed release `/opt/richStudio/releases/richStudio-94d6e6f4fd44fb8fa460f1dbed89cf43858e69f6-20261107T010654Z`, previous release `846f0b9` kept. Owner deploy output: `VERIFY PASS`, `Live process environment: 1 process(es) scanned, none carry RICHSTUDIO_ANNOTATION_TEST*`, `DEPLOY COMPLETE`. Preflight of 94d6e6f ended `PREFLIGHT PASS` (KEGG floors 3302/112, 3195/112, 2277/77 and 979/62 pass; cache pre-warm 15 of 15 from disk; fixture 298 rows with `GO:0097193` first).
- AC-028 yeast run (20 yeast gene names, species `yeast`, `org.Sc.sgd.db`, not pre-installed): the install row went Starting (2 s), Downloading (4 s), Installing (6 s), Verifying (12 s), Done (16 s), and the analysis started automatically. `INSTALLED.tsv` has the row `org.Sc.sgd.db	3.22.0	...	2026-11-07T01:20:43Z`; the installer status shows `state=completed`; no staging directory was left.
- That first analysis failed with "Invalid keytype: SYMBOL": `org.Sc.sgd.db` has no SYMBOL keytype and SYMBOL is the UI default. This is not an M2 defect. Rerun with keytype GENENAME succeeded in 16 s.
- Dropdown (lead, same session): 12 uninstalled species carry "installs on first use, about N MB"; `sco` and `toxoplasma` are absent.
- Lead verification of 94d6e6f: R suite 4733 tests, 0 failed, 2 known errors; Python suites 20 and 55 OK; browser gate 189 passed and 3 failed (`design-system.spec.ts:803` twice, the known WSL zoom gap, and `ui-accessibility.spec.ts:279` narrow, a timeout that passed on rerun, 6 of 6).

## Follow-up (not part of M2)

- A per-species default gene ID type: the UI defaults to SYMBOL, which species such as yeast (`org.Sc.sgd.db`) do not offer, so the first run of such a species fails with "Invalid keytype: SYMBOL" until the user picks another type.
