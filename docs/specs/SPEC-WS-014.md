---
id: "SPEC-WS-014"
title: "Species annotation packages: deploy-time library and guarded runtime install"
version: "0.3.0"
status: draft
created: "2026-11-06"
updated: "2026-11-06"
author: "workspace planning team"
priority: P0
phase: "v0.1.7 target"
module: "R/, scripts/, inst/"
lifecycle: spec-anchored
tier: L
tags: "deployment, annotation, enrichment, reproducibility, security"
---

# SPEC-WS-014 — Species annotation packages: deploy-time library and guarded runtime install

Planning-only draft (Tier L; this single leaf document carries the design, research and implementation contract, so no separate design.md or research.md exists; the audit accepted that convention, D17). No implementation or test completion is claimed. Companion umbrella: [SPEC-WORKSPACE-001](SPEC-WORKSPACE-001/plan.md). Related: [SPEC-WS-013](SPEC-WS-013.md) (job tray, "Copy command" panel), [SPEC-WS-005](SPEC-WS-005.md) (background record and annotation identity).

**Revision note (v0.3.0, 2026-11-06).** Resolves plan-audit iteration 2 (FAIL 0.83, D21-D34; `.moai/reports/SPEC-WS-014/plan-audit-iter2.md`). The hand-built mkdir/tombstone lock and the Rscript-as-process-supervisor are replaced by two simpler, kernel-backed parts: a kernel `flock(2)` lock on a fixed lock file, and a small bash supervisor (`annotation-install.sh`) that owns signals, child pids, exit codes, heartbeat and the status file, with the base-R worker (`annotation-install.R`) doing the package logic. All stale-lock, takeover and owner-matching machinery is deleted. The status-file contract is specified (D24).

**Id convention.** Requirement and scenario ids appear in short form (`REQ-004`, `AC-004`) inside this document; the full form in other documents is `REQ-WS-014-004` and `AC-WS-014-004`.

**Revision note (v0.2.0, 2026-11-06).** Resolves plan-audit iteration 1 (FAIL, defects D1-D20; `.moai/reports/SPEC-WS-014/plan-audit-iter1.md`) and records the owner decisions of 2026-11-06 and the lead's host measurements. Main design changes: the install runs in a separate detached Rscript process and never in the 2-worker future pool (D7); the lock is rename-takeover with process identity (pid plus start time) and a deadline (D3); verification and a post-swap smoke run in the release's real environment (D5); provenance is an additive sub-field of the existing `background$annotation` record, no format change (D4); a live host acceptance for a real runtime install is added (D6); the test transport and seams are declared and gated (D1, D2); thresholds and caps are fixed by data files and a pre-merge measurement step (D9).

## Problem and observable outcome

Live richStudio (release `141e095`, host hurlab) cannot run a new human GO enrichment: the run fails with "Package 'org.Hs.eg.db' is not installed". The sealed, root-owned release library does not contain the organism annotation packages, because the deploy script installs only what the DESCRIPTION files declare and no DESCRIPTION declares them. The deploy preflight never builds a real annotation and never reads the release's real environment, so it passed while analysis was broken.

After this leaf:

- **M1 (restore analysis, then redeploy):** a persistent annotation library, separate from the sealed release library, exists on the host with human, mouse, rat, zebrafish and C. elegans organism packages and `reactome.db` pre-installed; every release finds it through its `.Renviron`; verification builds real annotations and a tiny real enrichment in the release's real environment, before the symlink swap and again after it, and fails closed. M1 also ships the single installer implementation (a base-R script) that M2 reuses.
- **M2 (no more manual installs):** when a user runs an enrichment for an available species whose package is not installed, the app starts the installer as a detached process, shows an "installing annotation" state, continues the analysis automatically on success, and on failure shows the reason and the manual command. Installed package names and versions are recorded in the result's existing background record.

## Measured baseline

Measured by the lead on 2026-11-06 unless marked. **(source read)** = read from source by the author or auditor and not executed; such items are hypotheses until a check runs them.

| # | Fact | Source |
|---|---|---|
| B1 | Release `141e095` runs on host hurlab with Bioconductor 3.23. Host R is 4.6.2: `dpkg` upgraded `r-base-core` 4.6.1 -> 4.6.2 on 2026-11-05 18:39 local, after the `141e095` deploy. | lead, host |
| B2 | A live browser run of 20 human SYMBOLs failed with: "Package 'org.Hs.eg.db' is not installed. Install it in R with: BiocManager::install('org.Hs.eg.db')". | lead, live browser |
| B3 | The release library `/opt/richStudio/releases/<release>/renv/library/release-r46` (root-owned, sealed; set by the release `.Renviron` `R_LIBS_USER`; `.Rprofile` sources `renv/activate.R`) lacks `org.Hs.eg.db`, `org.Mm.eg.db`, `org.Rn.eg.db` and `reactome.db`; `GO.db` and `KEGGREST` are present. | lead, host |
| B4 | `richR::buildAnnot(species = "human", keytype = "SYMBOL", anntype = "GO")` fails in that library. | lead, host |
| B5 | `scripts/deploy-r46-release.sh` (about lines 140-175) installs only Depends/Imports/LinkingTo of the richR, bioAnno, richCluster and richStudio DESCRIPTIONs; no DESCRIPTION declares an organism package; only `install_dependencies.R` (lines 79-87) lists `org.Hs.eg.db` and `org.Mm.eg.db`. | lead; re-read |
| B6 | `--preflight` never builds a real annotation. `verify_release` (script lines 185-207) runs with `R_ENVIRON_USER=/dev/null`, `R_PROFILE_USER=/dev/null` and its own `R_LIBS_USER`, so it never exercises the staged `.Renviron` that shiny-server reads; `wait_for_app` checks only HTTP 200 and no error page, which the broken `141e095` passed. The old R 4.3 library had `org.Hs.eg.db`; it was lost in the R 4.6 move. | lead; auditor read |
| B7 | Shiny Server: `location /richStudio` has `app_dir /home/juhur/shinyapps/richStudio` (symlink to the release) and `run_as juhur`; the app process runs as juhur; the full deploy runs under sudo. Bioconductor 3.23 annotation repository reachable from the host (HTTP 200). Whether the shiny-server service sandbox (systemd `ProtectHome`, `ReadWritePaths`) allows writes under `/home/juhur/.local/share` is **not measured**; AC-001 records it, AC-028 proves it. | lead |
| B8 | The Enrich species dropdown (`R/enrich_tab.R`, about lines 185-222) offers 20 values: human, mouse, rat, zebrafish, fly, celegans, yeast, chicken, bovine, pig, canine, xenopus, rhesus, arabidopsis, anopheles, ecoli, malaria, chipm, toxoplasma, sco. | lead; re-read |
| B9 | **(source read)** richR 0.1.6 `.species_table()` (`R/species.R`) maps species to organism packages (full list in the allowlist below) and to a Reactome species name that is NA for anopheles, ecoli, ecsakai, streptomyces and toxoplasma, and a KEGG code that is NA for toxoplasma. The dropdown value `sco` is not a table key (the key is `streptomyces`), so `.getdbname("sco")` stops with "database error!". Verified by the auditor against tag v0.1.6. | richR v0.1.6 |
| B10 | **(source read)** `buildAnnot`: GO and builtin KEGG load the organism package with `requireNamespace` at call time in the worker; live KEGG/KEGGM use `KEGGREST`; Reactome needs `reactome.db` and, when the keytype is not ENTREZID, the organism package through `idconvert()`. The `Annot` metadata `provider_package` is the organism package for GO/KEGG and only `reactome.db` for Reactome. It carries no `Built` field. | richR `R/makeAnnot.R` |
| B11 | The app classifies missing-package failures only by text (`workspace_jobs_is_missing_package`: contains "package" and one of "is required / no package called / is not installed / not available", `R/workspace_jobs.R` lines 139-185). Analysis runs as futures (`workspace_jobs_future`, line 16; `R/enrich_tab.R` ~1281/~1468; worker `run_enrichment_jobs`, `R/deg_enrich.R:71`). `inst/application/app.R:52` sets `future::plan(future::multisession, workers = 2)`, shared by all sessions. | lead; auditor |
| B12 | The project manifest writes `annotation_provenance` as absent ("not recorded", `R/project_manifest.R:304`); the result's background record (`enrichment_background_record`, `R/enrichment_background.R:181-215`) already carries a nested `annotation` object (species, anntype, keytype, ontology, annotation_genes, richR version), and `project_background_encode`/`decode` round-trip nested named values generically. | author, source |
| B13 | Bioconductor 3.23 annotation index (`https://bioconductor.org/packages/3.23/data/annotation/src/contrib/PACKAGES`) and HTTP HEAD `Content-Length`, measured 2026-11-06: every package listed in the allowlist below has an `MD5sum` field; `org.Tgondii.eg.db` and `org.Sco.eg.db` are **not in the index**. Pre-install set is 650,940,605 bytes (about 651 MB) compressed; the whole available allowlist is 924,799,222 bytes (about 882 MB). Installed sizes are **not measured** (M1 measures them before merge, AC-008). | lead, host |

Not measured, therefore not assumed: installed size per package; download time; whether `setsid`, `flock` (lead-measured present: `/usr/bin/flock`, util-linux 2.39.3), GNU `timeout` (9.4) and `curl` exist on the host (AC-006 runs `command -v setsid flock timeout curl`); the shiny-server `KillMode` (whether a service restart kills a detached installer; `systemctl show shiny-server -p KillMode` is recorded in AC-001).

## Recorded owner decisions (binding)

| ID | Decision |
|---|---|
| D1 | Missing species annotation is installed automatically at runtime, with the safeguards below (owner's choice over deploy-only). |
| D2 | Two milestones: M1 restores live analysis and is redeployed first; M2 follows. |
| D3 | Persistent annotation library separate from the sealed release library, per R minor and Bioconductor version; appended after the release library; allowlist only; installs only from the pinned Bioconductor version's official repository over https. |
| D4 | Runtime install in the background, single-flight across R processes through a kernel lock, with timeouts; "installing annotation" UI state; automatic continuation; failure shows reason and manual command; installed package name and version recorded in result provenance. |
| D5 | M1 pre-installs `org.Hs.eg.db`, `org.Mm.eg.db`, `org.Rn.eg.db`, `org.Dr.eg.db` (zebrafish), `org.Ce.eg.db` (celegans) and `reactome.db`. |
| D6 | Preflight and verification build a real GO annotation for each of the five pre-installed species plus Reactome, run one tiny real enrichment, and fail closed. |
| D7 | OD-1, OD-2, OD-4, OD-5, OD-6, OD-8, OD-9 accepted as recommended (table at the end). OD-3: time limits doubled to 1200 s per download, 1200 s per install, 2400 s overall. OD-7: accepted; see OD-11 for how the detached-process design settles it. |

## Design

### Annotation library location and search order

- Path (OD-1): `/home/juhur/.local/share/richStudio/annotation/r<R minor>-bioc<Bioc version>` (today `r4.6-bioc3.23`; the last path component is one segment carrying both versions). Reason: the app runs as juhur (B7), so the path is writable without privilege; it is outside every release directory, so release switches and rollbacks never touch it; an R or Bioconductor upgrade starts an empty, ABI-consistent library. The deploy creates it as juhur, mode 0755, never under `/opt/richStudio/releases`.
- The path is never derived from request, upload, URL or session input. The deploy writes it once as `RICHSTUDIO_ANNOTATION_LIB` in the release `.Renviron`.
- Search order: the release `.Renviron` sets `R_LIBS_USER=<release lib>:<annotation lib>`, so release packages always win, and futures workers (child R processes) inherit it. The app never prepends or reorders `.libPaths()`.
- **Enforcement lives in the deploy** (REQ-015): ownership, mode, path shape and package provenance are checked there. The app can neither un-add a library the `.Renviron` already added nor stop a worker from reading it (D11), so the app-side rule is narrower: detect a library that fails the same checks, show a warning, and **refuse to install** into it (REQ-025). It never mutates `.libPaths()`.

### Allowlist, resolver and verification data

One tracked file `inst/extdata/annotation-allowlist.tsv` is the single source for the deploy and the app. Columns: `species`, `package`, `kind` (`organism` or `reactome`), `status` (`available` or `unavailable`), `preinstall` (`yes`/`no`), `est_mb` (compressed tarball, rounded up), `inst_mb` (installed size, measured by M1 before merge), `reactome_supported` (`yes`/`no`, from the pinned richR table), `reason` (non-empty for `unavailable`). The single `reactome` row has `species = *`. Initial contents (versions and sizes measured by the lead on 2026-11-06, B13; the index may move, so the installer reads the version from the index at install time):

| species | package | version | tarball bytes | est_mb | status | preinstall | reactome_supported |
|---|---|---|---|---|---|---|---|
| human | org.Hs.eg.db | 3.23.1 | 103790170 | 99 | available | yes | yes |
| mouse | org.Mm.eg.db | 3.23.0 | 93064586 | 89 | available | yes | yes |
| rat | org.Rn.eg.db | 3.23.0 | 63231272 | 61 | available | yes | yes |
| zebrafish | org.Dr.eg.db | 3.22.0 | 37088314 | 36 | available | yes | yes |
| celegans | org.Ce.eg.db | 3.22.0 | 20210171 | 20 | available | yes | yes |
| * | reactome.db | 1.96.0 | 333556092 | 319 | available | yes | n/a |
| fly | org.Dm.eg.db | 3.22.0 | 30795390 | 30 | available | no | yes |
| yeast | org.Sc.sgd.db | 3.22.0 | 14692159 | 15 | available | no | yes |
| chicken | org.Gg.eg.db | 3.22.0 | 18925940 | 19 | available | no | yes |
| bovine | org.Bt.eg.db | 3.22.0 | 22107500 | 22 | available | no | yes |
| pig | org.Ss.eg.db | 3.23.0 | 21095881 | 21 | available | no | yes |
| canine | org.Cf.eg.db | 3.22.0 | 31486753 | 31 | available | no | yes |
| xenopus | org.Xl.eg.db | 3.23.0 | 26784081 | 26 | available | no | yes |
| rhesus | org.Mmu.eg.db | 3.23.0 | 26436460 | 26 | available | no | yes |
| arabidopsis | org.At.tair.db | 3.22.0 | 40776760 | 39 | available | no | yes |
| anopheles | org.Ag.eg.db | 3.22.0 | 4332328 | 5 | available | no | no |
| ecoli | org.EcK12.eg.db | 3.22.0 | 6196560 | 6 | available | no | no |
| malaria | org.Pf.plasmo.db | 3.22.0 | 2790246 | 3 | available | no | yes |
| chipm | org.Pt.eg.db | 3.23.0 | 27438559 | 27 | available | no | yes |
| toxoplasma | org.Tgondii.eg.db | n/a | n/a | n/a | unavailable (not in the Bioconductor 3.23 annotation index) | no | no |
| sco | none | n/a | n/a | n/a | unavailable (dropdown value has no richR species key; `org.Sco.eg.db` not in the index) | no | no |
| streptomyces | org.Sco.eg.db | n/a | n/a | n/a | unavailable (not in the index) | no | no |
| ecsakai | org.EcSakai.eg.db | n/a | n/a | n/a | unavailable (not offered by the dropdown; not confirmed in the index) | no | no |

The **resolver** is `(species, anntype, keytype) -> needed packages or a refusal`: GO and KEGG need the organism package; Reactome needs `reactome.db` and, when the keytype is not ENTREZID, the organism package; an `unavailable` species, a species without a row, or Reactome for a `reactome_supported = no` species is refused with a named reason. Names are accepted only by exact match against the file and must also match `^[A-Za-z][A-Za-z0-9.]*$`. A unit test asserts the file against the pinned richR table and the dropdown values.

`inst/extdata/annotation-verify-floors.tsv` holds the verification **floors** (`species`, `anntype`, `min_genes`, `min_terms`): GO >= 5000 genes and >= 1000 terms for each of human, mouse, rat, zebrafish, celegans; Reactome >= 1000 genes and >= 100 terms for the same five; builtin KEGG for human >= 3000 genes and >= 100 terms. They are **floors that catch an empty or broken annotation, not expected values**. Before merge the lead confirms each floor is at most 50% of the count measured on the host with the pinned richR (recorded in the deploy record, AC-012); the actual counts are recorded for later tightening. Because the floors are a data file, a wrong floor is corrected without touching the script, and the numbers exist before the merge they gate (D9).

### Installer: bash supervisor plus base-R worker

Two files in `inst/annotation/` are the only installer, shared by the deploy (M1) and the app (M2): `annotation-install.sh` (a small bash supervisor) and `annotation-install.R` (the base-R worker; no new package dependency). The supervisor is invoked as `annotation-install.sh <package> [<package> ...]` with names only (never a URL or path from the caller); the library path comes from `RICHSTUDIO_ANNOTATION_LIB`. The deploy runs it in the foreground and reads its exit code; the app launches it detached (`setsid bash annotation-install.sh ...`, `system2(wait = FALSE)`; see Runtime flow).

**Supervisor (bash)**

1. Takes the lock: `exec 9>"$LOCK"; flock -n 9 || exit 75`. Exit 75 means `busy`: another installer holds the library; the loser writes nothing (it never touches the status file or staging).
2. Writes the status file (below) with its own pid `$$`, state `running`, phase `starting`, and the 2400 s deadline.
3. Removes every `<lib>/.staging-*` directory. This is safe without an age rule because the lock is held, so no other writer exists (D14).
4. Installs the packages one at a time. For each package it runs the worker phases `prepare`, `download`, `install`, `validate`, `finalize`, each as `timeout --signal=TERM --kill-after=30 <limit> Rscript annotation-install.R <phase> <package> &` followed by `wait $!`, so it knows the child's pid and exit status. The limit for `download`, `install` and `validate` is `min(1200, remaining)`, for `prepare` and `finalize` `min(120, remaining)`, where `remaining` is the 2400 s deadline minus now; a spent deadline ends the run with `timed_out`. GNU `timeout` runs the worker in its own process group and signals that group, so `curl` and `R CMD INSTALL` die with the phase.
5. While it waits (`sleep 10 & wait` ticks) it updates the `heartbeat` field of the status file.
6. Maps worker exit codes to reason codes: 0 ok; 10 `no_network`; 11 `checksum_mismatch`; 12 `not_enough_disk`; 13 `dependency_missing`; 14 `entry_invalid`; 15 `index_no_md5`; 16 `unavailable`; 20 package already present and valid (skip to the next package); 124 or 137 (timeout, or killed after the grace) `timed_out`; any other code `internal_error`.
7. `trap` on TERM, INT and HUP (the children run in the background and the supervisor sits in `wait`, so the trap fires): it forwards TERM to the running phase's process group, waits up to the 30 s grace, escalates to KILL, removes the staging directory, writes the terminal status `stopped`, and exits 130.
8. On every other end it removes its staging directory, writes the terminal status (`completed` or `failed` with the reason code) and exits 0 (completed) or 1 (failed). The lock is released when the process exits.

**Lock.** One fixed file, `<annotation parent>/r<R minor>-bioc<Bioc version>.lock` (a regular file next to the library, inside `/home/juhur/.local/share/richStudio/annotation/`), one lock per library so only one install runs at a time; the deploy and the app use the same file. The lock is the kernel `flock(2)` on descriptor 9, held for the supervisor's whole life. The kernel releases it on any exit, including SIGKILL, so there is **no stale detection, no pid or start-time matching, no takeover, no tombstone and no lock directory**. Children inherit descriptor 9 on purpose: if the supervisor is SIGKILLed while a worker is still running, the orphaned worker keeps the lock until it ends (at most the phase limit plus the 30 s grace), so an orphan can never write into staging while another installer runs; when nothing holds the descriptor the lock is free at once. The status file's pid, package and deadline are informational only and are never used for mutual exclusion.

**Worker (base R).** `prepare`: validate the package name against the allowlist and the library path against the deploy checks; if the entry already exists, verify `DESCRIPTION`/version/load and exit 20 for a valid entry or 14 for an invalid one (it is never replaced or deleted, D14); check the free-space floor and the size cap; fetch and parse the pinned index; require an `MD5sum` (15 otherwise); write the plan (version, md5, url) into `<lib>/.staging-<pkg>-<token>/plan`. `download`: `curl --fail --proto '=https' --proto-redir '=https' --max-redirs 3 --max-time 1200 --write-out '%{url_effective}'`; the final-URL host must be `bioconductor.org` (D19); the MD5 is compared to the index and the SHA-256 recorded. `install`: `R CMD INSTALL --library=<staging>/lib <tarball>`. `validate`, in a fresh process still in staging: `DESCRIPTION` `Package` and `Version` as expected, `requireNamespace()` with `lib.loc = <staging>/lib`, and a real probe (an organism package: `AnnotationDbi::keys(<pkg>, keytype = "ENTREZID")` is non-empty; `reactome.db`: `reactomePATHID2EXTID` is non-empty). `finalize`: atomic same-filesystem rename of the package directory into the library (never onto an existing entry), then write `INSTALLED.tsv` (package, version, sha256, md5, source_url, installed_at) by temporary file and rename (REQ-009).

Limits (owner decision OD-3): 1200 s per download, 1200 s per install, 2400 s overall deadline, 30 s TERM-to-KILL grace. Free-space floor 2 GiB; library size cap = `max(5 GiB, 2 x sum(inst_mb of every available allowlist row))` computed from the data file (OD-5), so the number is derived from the M1 measurement yet checkable before merge (AC-008).

### Status file (D24)

- Path: `<annotation parent>/r<R minor>-bioc<Bioc version>.status`, one per library, overwritten when a new supervisor starts (the previous run's final state is kept until then). Writer: the supervisor only, by writing `<status>.tmp.<pid>` in the same directory and `mv -f` onto the status path, so a reader never sees a partial file. Format: `key=value` lines, UTF-8, values with no newline.
- Fields: `schema` (`1`); `pid` (supervisor pid, integer); `request` (opaque token `[A-Za-z0-9]{8,32}` passed by the launcher through `RICHSTUDIO_ANNOTATION_REQUEST`; informational); `packages` (comma list); `current` (package being processed or empty); `phase` (enum `starting | preparing | downloading | installing | validating | finalizing | done`); `state` (enum `running | completed | failed | stopped`); `reason` (empty unless `failed`, else a reason code); `started`, `deadline`, `heartbeat`, `updated` (epoch seconds).
- Terminal states are `completed`, `failed` and `stopped`; `running` is the only non-terminal state. Reason codes: `no_network`, `timed_out`, `checksum_mismatch`, `not_enough_disk`, `dependency_missing`, `entry_invalid`, `index_no_md5`, `unavailable`, `internal_error`, and `interrupted` (derived by the reader, never written: see below).
- Readers are the app's session observers (Runtime flow). A reader treats a status as live only when `state=running` and `/proc/<pid>/cmdline` of that pid contains `annotation-install.sh`; `state=running` with a dead or different pid means the supervisor was killed (SIGKILL, service restart) and the reader reports `failed` with reason `interrupted`; the next supervisor sweeps the leftover staging when it takes the lock.
- The heartbeat is informational ("last activity N s ago"); a stalled heartbeat releases nothing, because the lock follows the process.


### Runtime flow (M2)

1. When Run is pressed, the observer calls the resolver and checks the needed packages against the library directory: an entry counts as present only if `<lib>/<pkg>/DESCRIPTION` is readable with the expected `Package` field; a directory that exists but fails that check is reported as `entry_invalid` with a message naming the path for the owner to remove (the app never deletes it) (D25). No package is loaded and `.libPaths()` is not changed.
2. Nothing missing: the run starts exactly as today. Refused (unavailable species or annotation type): refused before any job starts. Missing and available: the observer stores the already-reviewed run request (the SPEC-WS-004 review snapshot taken at Run) in the session, shows the "installing annotation" row and launches `setsid bash annotation-install.sh <packages>` with `system2(wait = FALSE)` using absolute paths (`Sys.which("setsid")`, the supervisor from `system.file("annotation", package = "richStudio")`) and an explicit environment (`RICHSTUDIO_ANNOTATION_LIB`, `R_LIBS_USER`, `RICHSTUDIO_RSCRIPT=file.path(R.home("bin"), "Rscript")`, `RICHSTUDIO_ANNOTATION_REQUEST`), so a different `PATH` under shiny-server cannot matter (D27). **The install never runs in the future pool**, and no waiting session holds a worker (D7). If another supervisor already holds the lock, the launched one exits 75 and the session simply watches the status file; `flock -n` decides, not the app.
3. Every 2 s (`invalidateLater(2000)`, no waiting future, no sleep) each session reads the status file once and applies this table to its own needed packages:

| Status read | Session action |
|---|---|
| no file, or terminal state that does not leave the session's missing set present | launch a supervisor (step 2) |
| `running`, live pid, `packages` covers the session's missing set | show "installing" with the phase text |
| `running`, live pid, `packages` does not cover it | show "waiting for another installation"; when the status turns terminal, launch a supervisor for the session's own packages |
| `completed`, and the resolver now finds every needed package present | continue: start the stored enrichment job |
| `failed`, `stopped` or `interrupted` for this session's request | show the failure (reason message, manual command) and keep the request on the row for Retry |
| `completed` but a needed package is still missing | treat as `failed` with `internal_error` |

4. Retry on a failed row launches a new supervisor; the lock decides whether it can run. Dismiss discards the retained request.
5. Stop on the install row of this session: the app reads `pid` from the status file, verifies that `/proc/<pid>/cmdline` contains `annotation-install.sh`, sends SIGTERM to that pid only (never to an unverified pid), and if the status is still `running` after 45 s sends SIGKILL to the verified pid; in the TERM case the supervisor's trap does the cleanup (staging removed, terminal status `stopped`); after SIGKILL the lock follows the process and the next installer sweeps staging.
6. The job-tray row for the install is a registry record driven by the status file; it is not a future. The SPEC fixes the observable row, not the mechanism.

Failure reason messages (REQ-022): fixed plain text for `no_network`, `timed_out`, `checksum_mismatch`, `not_enough_disk`, `dependency_missing`, `entry_invalid`, `index_no_md5`, `unavailable`, `internal_error` and `interrupted`; where useful the manual `BiocManager::install("<pkg>")` command is shown in the "Copy command" panel. The panel is fed from a structured failure (reason code plus command), not from the text classifier (D15); the text classifier remains for failures raised by richR.


### Test transport and seams (D1, D2)

Production constants: repository `https://bioconductor.org/packages/3.23/data/annotation`, allowlist `inst/extdata/annotation-allowlist.tsv`, downloader `curl` (used inside the worker; the supervisor, `flock` and `timeout` are never replaced). A single test-only configuration is honoured only when **both** environment variables are set: `RICHSTUDIO_ANNOTATION_TEST_MODE=1` and `RICHSTUDIO_ANNOTATION_TEST_CONFIG=<path to a dcf file>`. The file may name: a local `file://` repository, an alternate allowlist file, a **fake downloader** executable (invoked instead of `curl`; it can sleep, fail, refuse, log every call to a shared file, report a final URL, and serve a pre-built tarball), shortened phase limits and deadline (the clock seam) and a free-space override. Neither variable can be set from the UI, a request, an upload or the project file; the deploy never sets them; verification and the post-swap smoke fail when either appears in the release `.Renviron` or in the live app process environment (`/proc/<pid>/environ`); with `TEST_CONFIG` set but `TEST_MODE` unset the installer prints the production plan (`--print-plan`) and ignores the file (AC-010). CI needs no internet: slow, refused and failing downloads, request counting and MD5 mismatches are all produced by the fake downloader, and the local repository holds tiny source packages named from the alternate allowlist. The e2e app launcher `tests/e2e/annotation-app.R` (test-only, not shipped) wires the existing `enrichment_runner` and `annotation_builder` parameters to stubs, so a tiny fake `org.*` package never has to support a real `buildAnnot`.

### Deploy, verification and smoke (M1)

- A single function writes the release `.Renviron` (`RENV_CONFIG_AUTOLOADER_ENABLED=FALSE`, `R_LIBS_USER=<release lib>:<annotation lib>`, `RICHSTUDIO_ANNOTATION_LIB=<annotation lib>`); the finalize step, the preflight and the tests all use it, so the bytes can be compared exactly (D5).
- `ensure_annotation_library` (idempotent, as juhur): create the library (0755), run the installer for every `preinstall = yes` package that is absent.
- `verify_runtime_env <release dir>` runs as the app user from the release directory with a minimal environment (`env -i HOME=... PATH=...`, no `R_ENVIRON_USER`, `R_PROFILE_USER` or `R_LIBS_USER` override) so that the release's own `.Renviron` and `.Rprofile` take effect exactly as under shiny-server. It asserts: the first two `.libPaths()` entries are the release library then the annotation library; the same two entries appear in a `future::multisession` worker (`future::value(future::future(.libPaths()))`); the `.Renviron` bytes equal the generator output; the test-only variables are absent; each pre-installed package loads from the annotation library, is built for R 4.6 and is not found in the release library; `buildAnnot(species, "SYMBOL", "GO")` meets the floors for the five species; Reactome and builtin KEGG meet theirs; `richStudio:::shiny_enrich` on the human fixture (below) returns the expected term.
- Order in the full deploy: build -> `ensure_annotation_library` -> existing `verify_release` -> finalize -> `verify_runtime_env` at the final path (before the swap) -> swap and restart -> `wait_for_app` -> `verify_runtime_env` against the live path and an HTTP check -> on any failure after the swap, the existing `restore_release` runs and the script exits non-zero. `--preflight` runs the same function against the build tree with a scratch annotation library and the generated `.Renviron` (REQ-014).
- Fixture `tests/fixtures/annotation/human-query-20.tsv`: the 20 human SYMBOLs TP53, BAX, BCL2, CASP3, CASP8, CASP9, APAF1, CYCS, BID, BAK1, FAS, FADD, TNFRSF10B, MDM2, CDKN1A, ATM, CHEK2, BBC3, PMAIP1, XIAP (a DNA-damage/apoptosis list, chosen so that apoptotic terms are enriched). Expected: at least 5 GO BP rows with the adjusted p-value column below 0.05, including `GO:0006915` (apoptotic process). The lead confirms this on the host before merge (recorded in the deploy record; a gap until then).

## Dependencies and ownership

- Logical prerequisites: SPEC-WS-013 merged to `main` (done: `141e095` plus PR #3 fix `fcf91c8`). No dependency on SPEC-WS-004/005/006 internals beyond reading the review snapshot and extending the background record (REQ-026).
- One disposable implementer owns this leaf in its own fresh worktree; each milestone is independently reviewed, merged and CI-verified before the next starts; M1 is deployed by the checklist below before M2 starts.
- Shared targets are exclusive locks, even for nonoverlapping line edits.
- No `DESCRIPTION`, `NAMESPACE` or `renv.lock` change: the installer uses base R and system tools the host already has (`bash`, `curl`, `flock`, GNU `timeout`, `setsid`, checked in AC-006). A new package dependency needs a registry revision.
- Upstream richR work is separately owned; no richR 0.2.0 adoption; richR is not edited.

### M1 file ownership (installer, deploy, verification)

Existing: `scripts/deploy-r46-release.sh`, `docs/DEPENDENCY_DEPLOYMENT.md`, `install_dependencies.R` (comment pointing to the annotation library; list unchanged), `scripts/test-deploy-recovery.py` (extended; no assertion weakened).

New: `inst/annotation/annotation-install.sh`, `inst/annotation/annotation-install.R`, `inst/extdata/annotation-allowlist.tsv`, `inst/extdata/annotation-verify-floors.tsv`, `tests/fixtures/annotation/human-query-20.tsv`, `scripts/test-annotation-library.py` (drives the installer with a fake downloader and local repository), `docs/quality/ws014-m1-deploy-record.md`.

### M2 file ownership (app integration)

Existing: `R/enrich_tab.R` (Run observer, dropdown choices from the allowlist, install row), `R/workspace_jobs.R` (install row kind and state label, structured failure into the Copy command panel, Stop/Retry for the install row), `R/enrichment_background.R` (additive `annotation$packages` field), `docs/PROJECT_FORMAT.md` (one paragraph on the additive field), `docs/DEPENDENCY_DEPLOYMENT.md`. Existing tests change only where a changed label or id requires it; an assertion that enumerates the exact keys of the background `annotation` object may gain the new key, recorded in the M2 record; no assertion is weakened.

New: `R/annotation_packages.R` (allowlist reader, resolver, status reader, detached launcher, structured failure), `tests/testthat/test-annotation-packages.R`, `tests/testthat/helper-annotation-repo.R`, `tests/e2e/annotation-app.R`, `tests/e2e/annotation-install.spec.ts`, `docs/quality/ws014-m2-record.md`.

## Milestones

| Milestone | Scope | Acceptance |
|---|---|---|
| M1 Installer, deploy-time library, real-environment verification | installer, allowlist and floors data files, pre-install of six packages, `.Renviron` generator, `verify_runtime_env`, post-swap smoke with restore, preflight on a scratch library, pin fix (R minor), measured sizes and cap, owner redeploy | AC-001 .. AC-017 |
| M2 App integration | resolver, detached launch, status polling, row and states, failure contract, duplicate/Stop/Retry, app-side validation, provenance, live runtime install | AC-018 .. AC-030 |

## GEARS requirements

### M1

- **REQ-001** The deploy shall create the annotation library outside every release directory, owned by the app user with mode 0755, writable by the shiny-server process, per R minor and Bioconductor version, and shall leave it in place on release switch and rollback.
- **REQ-002** The release `.Renviron` shall be produced by one generator function, shall list the release library before the annotation library in `R_LIBS_USER`, and shall set `RICHSTUDIO_ANNOTATION_LIB`.
- **REQ-003** The deploy shall pre-install `org.Hs.eg.db`, `org.Mm.eg.db`, `org.Rn.eg.db`, `org.Dr.eg.db`, `org.Ce.eg.db` and `reactome.db` through the installer.
- **REQ-004** The installer shall install through a private staging directory and an atomic rename, shall validate each package in staging before the rename, shall never replace or delete an existing library entry, and shall leave no staging directory after success, failure, timeout or stop; after a SIGKILL of the supervisor the library shall be unchanged and the next lock holder shall remove any leftover staging before it installs.
- **REQ-005** The installer shall serialize installs per library with a kernel advisory lock (`flock`) on a fixed lock file, held by the supervisor for its lifetime and inherited by its children, so that a second installer gets `busy` immediately, a SIGKILLed holder frees the lock at once (an orphaned worker holds it until the worker ends), and no stale detection, takeover or owner matching exists; owner and status data shall be informational only.
- **REQ-006** The installer shall run as a bash supervisor that runs each worker phase as a child under `timeout`, knows each child's pid and exit status, enforces 1200 s per download, 1200 s per install and a 2400 s overall deadline, traps TERM, INT and HUP to kill the child's process group and clean up, maps exit codes to the fixed reason codes, and writes a heartbeat and the status file atomically.
- **REQ-007** The installer shall download only over https from the pinned Bioconductor repository, shall reject a redirect whose final URL is not on that host over https, and shall fail when the repository index has no MD5 for the package or the tarball does not match it.
- **REQ-008** The installer shall refuse to start a download when free space is below 2 GiB or when the library plus the package estimate exceeds the cap of `max(5 GiB, 2 x sum of measured installed sizes of the available allowlist)`, and the measured installed sizes shall be present in the allowlist before merge.
- **REQ-009** The installer shall record every installed package in `INSTALLED.tsv` (package, version, sha256, md5, source URL, time) by temporary file and rename, while holding the lock, whether it runs from the deploy or from the app.
- **REQ-010** The test-only repository, downloader, allowlist, shortened-limit clock and free-space seams shall take effect only when both test environment variables are set; otherwise the installer shall use the production constants, and the release `.Renviron` and the live app process environment shall contain neither variable.
- **REQ-011** Before the symlink swap, the deploy shall run a verification as the app user from the release directory in the release's real environment, with no environment overrides, and shall fail unless the library search order, the worker search order, the `.Renviron` bytes and the annotation packages are exactly as specified.
- **REQ-012** The verification shall build a real GO annotation for human, mouse, rat, zebrafish and celegans, a Reactome annotation for the same five, a builtin KEGG annotation for human, each meeting the floors in the tracked data file, and shall run one real enrichment on the fixed human fixture that returns the expected term.
- **REQ-013** After the symlink swap and restart, the deploy shall run the same real-environment verification against the live path and an HTTP check, and if either fails shall restore the previous release and exit non-zero.
- **REQ-014** The `--preflight` mode shall run the same verification against a scratch annotation library under its own work root, with the generated `.Renviron` exempt from the script's clean-tree check, and shall not modify the live annotation library, the live symlink, or the server configuration.
- **REQ-015** The deploy shall fail before the swap when an annotation package exists in the sealed release library, when an annotation package is not built for R 4.6, or when the annotation library or its parent is not owned by the app user or is group- or world-writable.
- **REQ-016** The deploy shall pin the R minor version (4.6.x) and the Bioconductor version, shall accept any 4.6 patch level, shall reject any other minor or Bioconductor version naming the measured and pinned values, and shall print the measured values.
- **REQ-017** The live release shall run a human GO enrichment of the verification fixture to completion after the M1 deploy.

### M2

- **REQ-018** The resolver shall map `(species, anntype, keytype)` to needed packages by exact match against the allowlist only, shall accept no package name, path, URL or argument derived from user input, and shall start no process for a name that fails the match.
- **REQ-019** When a species is unavailable or has no allowlist row, or the annotation type is not supported for it, the app shall refuse the run before any job or install starts with a plain reason, and the species dropdown shall offer only available species.
- **REQ-020** While an annotation install is running, the app shall run it in a detached supervisor process outside the future worker pool, shall not occupy a worker for it or for any waiting session, and shall let other sessions' jobs start and finish normally.
- **REQ-021** While an annotation install is queued, waiting for another installation, running or verifying, the workspace shall show an "installing annotation" row naming the package and species through the job tray and the single live region, and shall not present it as a failure.
- **REQ-022** If an install fails, the app shall show one of the fixed reason messages and, where applicable, the manual install command in the Copy command panel from a structured failure, shall keep previous results unchanged, and shall not start the enrichment.
- **REQ-023** While an install is running, a second Run for the same package shall not start a second install; a Run for another package shall wait for the running install and then launch its own; Stop on the install row owned by this session shall SIGTERM the verified supervisor so that it removes staging and writes the `stopped` status; Retry on a failed install row shall launch a new supervisor and continue the retained run request; Dismiss shall discard the retained request.
- **REQ-024** If the user's browser session ends during an install, the installer shall continue to completion, and the next session that needs the package shall find it installed and shall not download it again; a service restart that kills the supervisor shall leave the library unchanged and be reported as `interrupted`.
- **REQ-025** If the annotation library fails the deploy ownership, mode or path checks, the app shall show a warning and shall refuse to install into it with the manual command, and shall not change `.libPaths()`.
- **REQ-026** The enrichment result's existing background record shall carry the name and installed version of every annotation package the run needs (for Reactome with a non-ENTREZID keytype, both `reactome.db` and the organism package) under `annotation$packages`, shall round-trip through project save and load without a change to the manifest's top-level keys, shall be omitted when no annotation package is needed, and shall be absent, without error, in projects saved before this change.
- **REQ-027** The installer and the app shall not change the sealed release library, the release `.Renviron`, `.libPaths()` ordering, enrichment cutoffs, background semantics or any statistical result.
- **REQ-028** When a species whose package is not pre-installed is run on the live host, the app shall install it as the shiny-server process user, shall show the installing state, shall continue to the result, and shall add its row to `INSTALLED.tsv`.
- **REQ-029** When a run starts after an install in a process that was already running, the future worker shall load the newly installed package without a restart.
- **REQ-030** While a session needs a package that is missing, the app shall read the status file every 2 s without blocking, shall act on it as the state table in Runtime flow specifies for each state, and shall treat a `running` status whose pid is dead or is not the supervisor as `interrupted`.

## Binary acceptance scenarios

"CI" means no internet: the fake downloader and local repository of the test transport. "Host" means the lead runs it on hurlab as juhur.

### M1

**AC-001** (REQ-001) Given a deploy, when it finishes, then `stat -c '%U:%G %a' /home/juhur/.local/share/richStudio/annotation/r4.6-bioc3.23` prints `juhur:juhur 755`; the path is not under `/opt/richStudio`; `runuser -u juhur -- bash -c 'f=$(mktemp -p /home/juhur/.local/share/richStudio/annotation/r4.6-bioc3.23) && rm "$f"'` exits 0; after `scripts/rollback.sh` to the previous release the directory and `INSTALLED.tsv` are unchanged; and the deploy record contains the output of `systemctl show shiny-server -p User -p ProtectHome -p ReadWritePaths -p ReadOnlyPaths -p KillMode` (B7 gap).

**AC-002** (REQ-002) Given the finalized release, when `cmp <release>/.Renviron <generator output for that release>` runs, then it exits 0; the file has exactly the three variables `RENV_CONFIG_AUTOLOADER_ENABLED`, `R_LIBS_USER=<release>/renv/library/release-r46:/home/juhur/.local/share/richStudio/annotation/r4.6-bioc3.23` and `RICHSTUDIO_ANNOTATION_LIB=<same annotation path>`; a unit test with a deliberately mistyped path shows `cmp` exits non-zero.

**AC-003** (REQ-003) Given the deploy, when it finishes, then `INSTALLED.tsv` has one row each for the six pre-install packages with the version found in the index at install time, `tools::md5sum` of each tarball equals the index `MD5sum`, and `packageDescription(<pkg>)$Built` starts with `R 4.6` for each.

**AC-004** (REQ-004) Given a local repository and the fake downloader (CI), when the supervisor runs, then: success leaves no `.staging-*` directory; a tarball with changed bytes ends with `checksum_mismatch` and a byte-identical library; SIGTERM to the supervisor mid-install leaves no staging and a `stopped` status; SIGKILL to the supervisor and its process group mid-install leaves the library unchanged and the staging present, and the next supervisor run removes it before installing; a valid existing entry makes the run a no-op success; an invalid existing entry (wrong version) fails with `entry_invalid` and the entry is untouched; a package whose validation probe fails stays in staging and is never renamed into the library.

**AC-005** (REQ-005) Given the lock (CI), when supervisors run, then: the lock is a regular file at `<annotation parent>/r4.6-bioc3.23.lock` and no lock directory, owner file or tombstone is ever created (`find` shows none); a second supervisor started while the first runs exits 75 within 2 s and leaves the status file and staging untouched; after SIGKILL of the supervisor and its process group, `flock -n <lock> true` succeeds immediately; after SIGKILL of the supervisor alone while the fake worker still runs, `flock -n` fails until the worker exits and then succeeds; three supervisors started together give exit codes 0, 75, 75 and the fake downloader call log shows one download.

**AC-006** (REQ-006) Given the supervisor and a fake downloader that sleeps or fails (CI), when it runs, then: the `heartbeat` field advances at least every 15 s; a hanging download and a hanging `R CMD INSTALL` end at their limits (shortened through the clock seam; `--print-plan` shows 1200, 1200 and 2400 in production) with status `failed`, reason `timed_out`, `pgrep -f <staging path>` empty, staging removed and the lock free; SIGTERM does the same with state `stopped` and exit 130; a worker exiting with each of the exit codes 10-16 maps to its reason code, exit 20 skips to the next package, an unknown exit code maps to `internal_error`, and a worker killed by `timeout` maps to `timed_out` (one case each); the status file validates against the schema (all fields, enums, terminal states) and a reader polling 1000 times during a run never reads a partial file. On the host `command -v setsid flock timeout curl` succeeds.

**AC-007** (REQ-007) Given repository and redirect inputs (CI), when the installer validates them, then `http://`, `ftp://`, a non-Bioconductor host and a redirect whose final URL is on another host or `http` are each rejected with a named reason; an index entry without `MD5sum` fails with `index_no_md5`; the production repository constant equals `https://bioconductor.org/packages/3.23/data/annotation`.

**AC-008** (REQ-008) Given the allowlist, when the unit test computes the cap, then it equals `max(5 GiB, 2 x sum(inst_mb))` over the available rows and no `inst_mb` is empty; a free-space seam of 2 GiB minus 1 byte, and a library size plus estimate above the cap, each stop the installer before any download with `not_enough_disk`. The deploy record lists `du -sk` of each of the 19 available packages after a scratch install on the host (additive, nothing live touched), download seconds, and `df -k` of the annotation filesystem.

**AC-009** (REQ-009) Given an install, when it ends, then `INSTALLED.tsv` has a header with the six columns and one row per package; SIGKILL of the supervisor and its process group between writing the temporary file and the rename leaves the previous `INSTALLED.tsv` byte-identical; an app-started and a deploy-started install both write the same format.

**AC-010** (REQ-010) Given the installer, when `--print-plan` runs with `RICHSTUDIO_ANNOTATION_TEST_CONFIG` set but `RICHSTUDIO_ANNOTATION_TEST_MODE` unset, then it prints the production repository, the production allowlist path and `curl`; with both set it prints the test values; and `grep -c RICHSTUDIO_ANNOTATION_TEST <release>/.Renviron` prints 0 and the same pattern is absent from `/proc/<live app R pid>/environ` (host).

**AC-011** (REQ-011) Given a release directory, when `verify_runtime_env` runs as juhur with `env -i`, then it prints the first two `.libPaths()` entries (release library, annotation library) and the identical two entries from a `future::multisession` worker, and exits 0; a CI harness with a staged `.Renviron` whose annotation path is mistyped, or whose order is reversed, exits non-zero before the swap.

**AC-012** (REQ-012) Given the pre-installed library, when the verification runs, then each of the five species meets the GO floors, Reactome floors and human KEGG floor of `annotation-verify-floors.tsv`, and `richStudio:::shiny_enrich` on the human fixture returns at least 5 rows with adjusted p below 0.05 including `GO:0006915`; with the annotation library emptied the same check exits non-zero. Before merge the lead's host measurement shows every floor is at most 50% of the measured count and the deploy record lists the measured counts and the fixture result.

**AC-013** (REQ-013) Given the deploy harness (as in `scripts/test-deploy-recovery.py`), when the post-swap verification is made to fail, then `restore_release` runs, the app symlink points to the previous target and the script exits non-zero; when the app answers HTTP 200 but `verify_runtime_env` fails, the outcome is the same (a 200 alone never passes).

**AC-014** (REQ-014) Given `--preflight` run as juhur without sudo, when it ends, then the live `INSTALLED.tsv` sha256, the app symlink target and the checksums of `/etc/shiny-server/shiny-server.conf` are unchanged, the generated `.Renviron` does not trip the clean-tree check, the scratch annotation library holds the six packages, and the log shows the same check names as the full deploy.

**AC-015** (REQ-015) Given three planted faults (CI harness), when the deploy verification runs, then each exits non-zero before the swap with a message naming it: a copy of `org.Hs.eg.db` in the release library; a package whose `Built` is `R 4.5.x`; an annotation directory owned by root, or with mode 0777.

**AC-016** (REQ-016) Given a PATH shim printing `R version 4.6.2`, `4.7.0` and `4.5.9` (and Bioconductor `3.23` and `3.24`), when the version check runs, then 4.6.2 with 3.23 is accepted and the measured version is printed, and each of the others is rejected with a message naming both the measured and the pinned value.

**AC-017** (REQ-017) Given the M1 deploy, when the lead runs the fixture (20 human SYMBOLs, GO BP) through the live browser, then the Results page shows at least 5 rows with adjusted p below 0.05 including `GO:0006915`; the lead records the row count and closes the browser tabs before stopping the SSH tunnel.

### M2

**AC-018** (REQ-018) Given the resolver (CI), when it is called with each allowlisted `(species, anntype, keytype)`, then the needed packages equal the table in "Allowlist, resolver" (Reactome with SYMBOL: `reactome.db` plus the organism package; with ENTREZID: `reactome.db` only); given `../x`, `org.Hs.eg.db; rm -rf /`, `org.Xx.eg.db`, a URL and an empty string, then it returns a refusal and a spy on the process seam records no process start and nothing is written below the library.

**AC-019** (REQ-019) Given the dropdown, when it is built, then it offers no value whose allowlist `status` is `unavailable` (`sco`, `toxoplasma` are absent); given a session or project that restores `sco`, or Reactome for `anopheles` or `ecoli`, when Run is pressed, then the run is refused before any job with the stated reason and the job registry is unchanged; a unit test asserts the allowlist rows against the pinned richR 0.1.6 species table and the dropdown values.

**AC-020** (REQ-020) Given `plan(multisession, workers = 2)` and an install in flight (fake downloader sleeping), when another session starts an ordinary enrichment, then that job starts and completes while the install is still running; `future::nbrOfFreeWorkers()` is the same before and during the install; a third session needing the same package shows "waiting for another installation" and the count of its futures is unchanged; the supervisor is not a child of a future worker (its process group leader is its own pid), and the status file shows `running` throughout.

**AC-021** (REQ-021) Given an install, when it runs, then e2e asserts the tray row text names the package and species, the state text changes queued/downloading/installing/verifying/done, exactly one polite live region announces each change, and no failure notification and no error colour class appears.

**AC-022** (REQ-022) Given each failure reason code produced by the fake downloader or seams (`no_network`, `timed_out`, `checksum_mismatch`, `not_enough_disk`, `dependency_missing`, `entry_invalid`, `index_no_md5`, `internal_error`, `interrupted`), when the install fails, then the notification shows the fixed message for that code, the Copy command panel shows `BiocManager::install("<pkg>")` where the table says a command applies, previous results are unchanged, no enrichment job exists in the registry, and the structured failure is used (a test passes a message that the text classifier would miss).

**AC-023** (REQ-023) Given an install in flight, when the same session presses Run twice for the same package, then the process spy shows one supervisor (a second launch, if any, exits 75); when another session presses Run for a different package, then it shows "waiting for another installation" and launches its own supervisor after the status turns terminal; when Stop is pressed on the install row, then the app sent SIGTERM only to a pid whose `/proc/<pid>/cmdline` contains `annotation-install.sh` (a test with a status file naming an unrelated pid sends no signal), the supervisor's process group is gone, staging is removed, the status is `stopped`, the lock is free and the retained request is kept with a Retry action; when Retry is pressed a new supervisor runs and, on success, the retained request runs once; when Dismiss is pressed the request is discarded.

**AC-024** (REQ-024) Given an install in flight, when the browser tab is closed, then the supervisor finishes, the package and its `INSTALLED.tsv` row exist and the lock is free; a new session running the same species then starts its enrichment directly and the fake downloader call log shows no second download; when instead the supervisor is SIGKILLed (the service-restart case), the library is unchanged, the next session reports `interrupted` with the manual command, and its next run removes the staging and installs.

**AC-025** (REQ-025) Given a library that is owned by another user or has mode 0777, or a `RICHSTUDIO_ANNOTATION_LIB` that is relative, contains `..`, is a symlink, or whose last component does not equal the running `r<minor>-bioc<version>`, when a run needs a missing package, then the app shows the warning and the manual command, starts no installer, and `.libPaths()` is identical before and after.

**AC-026** (REQ-026) Given an enrichment run with installed packages (CI), when the project is saved and reloaded through the existing project export and import functions, then `background$annotation$packages` equals the named list of `packageVersion()` values (human GO: `org.Hs.eg.db`; human Reactome with SYMBOL: `reactome.db` and `org.Hs.eg.db`), the top-level manifest keys equal those of a project saved before this change, a project saved before this change reloads without error and without the field, and the existing `test-project-manifest.R` and `test-project-import.R` pass unchanged except for a recorded new-key assertion.

**AC-027** (REQ-027) Given an install and a following enrichment, when compared with before, then the release library directory listing and checksum of the `.Renviron` are unchanged, `.libPaths()` order is unchanged, the existing `test-baseline-result-figures.R` and `test-enrichment-background.R` pass unchanged, and no annotation package is present in the release library.

**AC-028** (REQ-028) Given the M2 deploy on the host, when the lead runs yeast (SYMBOL, GO, `org.Sc.sgd.db`, about 15 MB, not pre-installed) through the live browser, then the row shows installing and then done, the enrichment completes with result rows, `INSTALLED.tsv` on the host has an `org.Sc.sgd.db` row with version and sha256, and `stat -c '%U' <lib>/org.Sc.sgd.db` prints `juhur`; the lead records the commands and outputs in `docs/quality/ws014-m2-record.md`.

**AC-029** (REQ-029) Given a running app whose worker already ran an enrichment, when a package is installed and a new enrichment for it starts, then it succeeds without restarting the app or recreating the future plan, and `future::value(future::future(find.package("<pkg>")))` returns a path under the annotation library.

**AC-030** (REQ-030) Given status files for every row of the state table (unit test with a fixed clock and a pid seam), when the session logic evaluates them, then each row yields exactly the stated action (launch, installing, waiting, continue, show failure, `internal_error`); `running` with a dead pid and `running` with a live pid whose cmdline is not the supervisor both yield `interrupted`; the observer uses `invalidateLater(2000)` and creates no future and no sleep (asserted by a spy on the future seam and on `Sys.sleep`).

## Test plan

- **Unit and integration (CI, no internet):** `tests/testthat/test-annotation-packages.R` with `helper-annotation-repo.R` (local repository of tiny source packages named from the alternate allowlist, `PACKAGES` with `MD5sum`) and the fake downloader; process, shortened-limit clock and free-space seams are the test-transport seams above, never reachable from production code paths (AC-010).
- **Installer and deploy (CI):** `scripts/test-annotation-library.py` drives `annotation-install.R` as real child processes for AC-004 .. AC-009 and AC-015; `scripts/test-deploy-recovery.py` extended for AC-011, AC-013, AC-016.
- **E2E (Playwright):** `tests/e2e/annotation-install.spec.ts` against `tests/e2e/annotation-app.R` (stubbed runner and builder, fake downloader) for the M2 UI scenarios (AC-020 .. AC-024, AC-030); follows the local browser gate recorded in the project notes.
- **Host (lead):** AC-001, 003, 008 (measure), 012 (floors), 014, 017 for M1; AC-028 for M2. Verbatim commands and outputs go into the two record files.
- Full-suite gates run in clean CI; local checks are scoped to affected behaviour.

## Requirement-to-acceptance traceability

Primary scenario is the one with the REQ's own number; secondary scenarios add coverage.

| Requirement | Primary | Secondary |
|---|---|---|
| REQ-001 | AC-001 | AC-015 |
| REQ-002 | AC-002 | AC-011 |
| REQ-003 | AC-003 | AC-014 |
| REQ-004 | AC-004 | AC-006 |
| REQ-005 | AC-005 | AC-006 |
| REQ-006 | AC-006 | AC-004 |
| REQ-007 | AC-007 | AC-004 |
| REQ-008 | AC-008 | AC-004 |
| REQ-009 | AC-009 | AC-003 |
| REQ-010 | AC-010 | AC-011 |
| REQ-011 | AC-011 | AC-002 |
| REQ-012 | AC-012 | AC-017 |
| REQ-013 | AC-013 | AC-011 |
| REQ-014 | AC-014 | AC-012 |
| REQ-015 | AC-015 | AC-001 |
| REQ-016 | AC-016 | none |
| REQ-017 | AC-017 | AC-012 |
| REQ-018 | AC-018 | AC-004 |
| REQ-019 | AC-019 | AC-018 |
| REQ-020 | AC-020 | AC-023 |
| REQ-021 | AC-021 | AC-020 |
| REQ-022 | AC-022 | AC-007 |
| REQ-023 | AC-023 | AC-006 |
| REQ-024 | AC-024 | AC-005 |
| REQ-025 | AC-025 | AC-015 |
| REQ-026 | AC-026 | none |
| REQ-027 | AC-027 | AC-029 |
| REQ-028 | AC-028 | AC-001 |
| REQ-029 | AC-029 | AC-020 |
| REQ-030 | AC-030 | AC-020, AC-023 |

Counts: M1 has 17 requirements and 17 scenarios (REQ-001..017 and AC-001..017); M2 has 13 requirements and 13 scenarios (018..030).

## Security and trust boundary

| Threat | Control |
|---|---|
| Path injection (library or staging path from input) | Library path comes only from the root-written `.Renviron`, validated by the deploy (REQ-015) and re-validated by the app (REQ-025); staging names are `.staging-<allowlisted package>-<token>` created with `dir.create` under the library; no user text enters a path (AC-018, AC-025). |
| Package-name, URL or argument injection | Exact allowlist match plus name regex; the installer is invoked with a vector of arguments (no shell string), takes package names only, and builds URLs itself from the pinned repository constant (AC-018). |
| Concurrent install corruption | Kernel `flock` on a fixed lock file held by the supervisor and inherited by its children; private staging and atomic rename; no entry is ever replaced (AC-004, AC-005). |
| Dead or stuck owner, pid reuse | None needed: the kernel releases the lock when the last holder exits; pid and start-time matching does not exist; the status file's pid is informational and a signal is sent only to a pid verified by `/proc/<pid>/cmdline` (AC-005, AC-023). |
| Partial install, crash, kill | Library holds only validated, renamed packages; leftover staging is removed by the next lock holder; `timeout` signals the whole phase group, the supervisor's trap cleans up on TERM, and an orphan after SIGKILL keeps the lock until it ends (AC-004, AC-005, AC-006). |
| Disk fill | Free-space floor and size cap checked before download (AC-008). |
| Network failure, slow network, redirect abuse | Per-download, per-install and overall limits; `--proto-redir =https`, `--max-redirs 3`, final-URL host check (AC-006, AC-007). |
| Supply chain | Pinned Bioconductor version in the URL; https only; host check; tarball MD5 from the index required; SHA-256 recorded in `INSTALLED.tsv`. Honest limit: index and tarball share an origin, so this detects corruption and substitution of the tarball, not a compromised repository; per-package pinned hashes are not part of this leaf (OD-9). |
| Privilege | Runs as juhur into a juhur-owned directory; nothing needs root at runtime; the sealed release library is never written; the deploy never gives the directory to root (AC-001, AC-015). |
| Resource abuse through the UI | Only available species resolve; one installer at a time per library; waiting sessions poll a status file and hold no worker (AC-020). |
| Test-only escape hatches | Seams need two environment variables the UI cannot set; absent from the release `.Renviron` and the live process environment; inert without the mode flag (AC-010). |
| Sandbox surprises | The service sandbox is measured (AC-001) and proven by the live install (AC-028). |

The remediation command is displayed and copied as text and never executed by the app (unchanged from SPEC-WS-013). Gene lists never appear in installer logs or status files.

## Rollout and rollback

- **M1:** the owner runs the sudo command (checklist below). Rollback is the previous release symlink (`scripts/rollback.sh`); the annotation library is additive and unused by an older release. Rolling back to the pre-M1 release `141e095` **restores the "package not installed" failure** (it has no annotation library in its `.Renviron`); a rollback is a safety exit, not a fix, and the record says so (D20). Removing the library is optional and manual, after the old release is retired.
- **M2:** a normal release deploy; the app finds the library through the `.Renviron` M1 wrote. Rolling back to an M1 release disables runtime install and leaves installed packages usable.
- **Project format:** frozen. M2 adds one optional nested value inside the already-persisted background record (`annotation$packages`); no manifest top-level key, route or stored-data change; projects saved before and after open in every state (AC-026). `docs/PROJECT_FORMAT.md` gets one paragraph.

## Owner-run deployment checklists

The owner runs only the sudo command; the lead stages scripts and verifies on the host (scp, `sha256sum` on both ends, `bash -n`; each non-sudo line rehearsed on the host first; the record notes which lines were rehearsed and which are exercisable only under sudo).

### M1

1. (lead, before merge, host, juhur) Measurements: install the full allowlist into a scratch library under a temp directory; record installed sizes, download times, `command -v setsid flock timeout curl`, `systemctl show shiny-server -p User -p ProtectHome -p ReadWritePaths -p ReadOnlyPaths`; run `buildAnnot` counts for the five species and confirm each floor is at most 50% of the measured count; run the fixture and record the rows (AC-001, 008, 012). Commit the measured `inst_mb` values and floors.
2. (lead) Merge M1 to `main`; record the 40-character release SHA.
3. (lead, host, juhur) Stage `scripts/deploy-r46-release.sh`; print `R --version` (expect 4.6.x) and the Bioconductor version (expect 3.23); `bash -n`.
4. (lead, host, juhur) Rehearse `bash scripts/deploy-r46-release.sh --preflight --release-sha <sha>`; expect `PREFLIGHT PASS`, the per-species counts and the fixture rows (AC-012, AC-014).
5. (owner, plain WSL terminal on the host or over SSH to Tailscale 100.94.67.89, any directory) `sudo bash scripts/deploy-r46-release.sh --run-id <token> --release-sha <sha>`. Reason: builds the release, installs the annotation packages, runs the real-environment verification, swaps the symlink, restarts shiny-server and re-verifies against the live path. Warning: without `sudo` it aborts with `run the deploy with sudo`; it refuses to run with the preflight flag under sudo.
6. (lead, live browser) Run the fixture (AC-017); close tabs before stopping the SSH tunnel.
7. (lead) Note in the record that rolling back to `141e095` restores the failure (D20).

### M2

1. (lead) Merge M2; stage and run the preflight as for M1. Before the owner deploy confirm no install is in flight (`state` in `<annotation parent>/r4.6-bioc3.23.status` is not `running`): a service restart kills a running supervisor, which is then reported as `interrupted`.
2. (owner) The same sudo deploy command for the M2 release SHA.
3. (lead, live browser) AC-028: run yeast; record the commands, outputs and the `INSTALLED.tsv` row.

## Open decisions

| ID | Question | Status |
|---|---|---|
| OD-1 | Library path | Accepted: `/home/juhur/.local/share/richStudio/annotation/r4.6-bioc3.23` |
| OD-2 | `reactome.db` runtime-installable | Accepted: yes, `kind=reactome` |
| OD-3 | Time limits | Owner changed: 1200 s per download, 1200 s per install, 2400 s overall. The 120 s stale-owner grace of v0.2.0 is removed with the lock redesign (the kernel lock needs no liveness rule); a 30 s TERM-to-KILL grace remains. |
| OD-4 | No `MD5sum` in the index | Accepted: fail closed |
| OD-5 | Disk cap and floor | Accepted, formula fixed: floor 2 GiB free; cap = `max(5 GiB, 2 x sum(inst_mb of available rows))` |
| OD-6 | Dropdown for uninstalled species | Accepted: all available species selectable with an "installs on first use (about N MB)" hint from `est_mb`; unavailable species are not offered |
| OD-7 | One implementation or two | Accepted as written, settled by OD-11 |
| OD-8 | `sco` | Accepted: unavailable; mapping it is a separate fix (richR has no `sco` key; `org.Sco.eg.db` is not in the 3.23 index anyway) |
| OD-9 | Pinned hashes per package | Accepted: not in this leaf |
| OD-10 | Pre-install set | Owner changed: human, mouse, rat, zebrafish, celegans and `reactome.db` (651 MB compressed); verification builds GO for the five species plus Reactome for the five |
| OD-11 | Detached installer: one shared implementation | Accepted by the lead. Implemented as a bash supervisor plus a base-R worker in `inst/annotation/`, used by deploy and app; no R rewrite. |
| OD-12 | Verification cost | Open, low risk: Reactome for five species plus GO for five species loads `reactome.db` (319 MB compressed) repeatedly; load time is unmeasured and M1 step 1 measures it. Recommended: keep all five, relax only if the measured preflight time is unacceptable. |

## Exclusions

### Out of Scope — Product scope

- Adopting richR 0.2.0, editing richR, changing the richR species table or dropdown values beyond offering only available species.
- Any change to analysis cutoffs, background or universe semantics, statistical methods, or result tables.
- Installing arbitrary packages, user-supplied packages, CRAN or GitHub packages, or any package not in the allowlist; installing at app start-up or from any request other than Run; installing packages for `toxoplasma`, `sco`, `streptomyces` or `ecsakai`.
- Live KEGG access (`KEGGREST` network calls) and offline KEGG databases.

### Out of Scope — Technology and format

- New package dependencies (`filelock`, `processx`, `BiocManager` at runtime), an in-app package manager UI, a system-wide shared annotation cache, or root-owned runtime installs.
- Any change to the project file format beyond the optional `annotation$packages` value; changing route identifiers or job lifecycle rules beyond the install row.
- Migrating R or Bioconductor versions; those start a new annotation library by design.

## HISTORY

- 2026-11-06 (v0.3.0): Revision after plan-audit iteration 2 (FAIL 0.83, D21-D34). Kernel `flock` lock replaces the mkdir/tombstone lock; a bash supervisor owns signals, pids, exit codes, heartbeat and status; the base-R worker keeps the package logic; status-file contract and session state table added (REQ-030, AC-030); reason codes `internal_error` and `interrupted` added; sweep rule simplified (leftover staging removed by the next lock holder); id convention stated; OD-11 accepted. 30 requirements and 30 scenarios (M1 001-017, M2 018-030).
- 2026-11-06 (v0.2.0): Revision after plan-audit iteration 1 (FAIL, D1-D20) and owner decisions of 2026-11-06 (OD-3 limits doubled; OD-10 pre-install set extended). Added lead-measured Bioconductor index sizes and the host R 4.6.2 fact; detached installer and rename-takeover lock; real-environment verification and post-swap smoke; test transport and gated seams; additive provenance field; live acceptances AC-017 and AC-028; per-REQ primary scenarios; floors and cap fixed by data files; allowlist `status`, `est_mb` and `reactome_supported` columns. 29 requirements and 29 scenarios (M1 001-017, M2 018-029).
- 2026-11-06 (v0.1.0): Planning-only draft authored after the lead's live measurements of 2026-11-06 and source reading of the deploy script, richR 0.1.6 and the job code.
