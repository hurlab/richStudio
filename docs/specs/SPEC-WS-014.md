---
id: "SPEC-WS-014"
title: "Species annotation packages: deploy-time library and guarded runtime install"
version: "0.3.3"
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

**Revision note (v0.3.3, 2026-11-06).** Patch for plan-audit iteration 4 (D49-D58): one richStudio annotation builder in `R/annotation_cache.R` (Reactome attach plus the two-level cache) is the default builder on every path that builds an annotation, including the custom-background check (REQ-037); the cache key covers every package whose data shapes the annotation (D50); the deserialization controls are made consistent and testable, with a stub-builder bypass (D52); the disk cache is bounded with oldest-first eviction (REQ-038); hits and misses are observable through a returned source attribute, counters and a log line (D53). Requirement and scenario ids 037 and 038 are added to the M1 addendum.

**Revision note (v0.3.2, 2026-11-06).** Adds lead measurements from hurlab (installed sizes and install times, `buildAnnot` counts for the five pre-installed species, the cache timings) and resolves OD-12. Three changes follow from them: (1) richR 0.1.6 cannot build a Reactome annotation unless `reactome.db` is attached, so richStudio attaches it before a Reactome build (REQ-031); (2) the verification fixture's expected term changes from `GO:0006915` (1766 BP genes, above `maxGSSize` 500, so never reportable) to `GO:0097193`; (3) by owner decision a two-level annotation cache (memory LRU plus disk) is part of M1 (REQ-032..036), turning a ~91 s first-step annotation build into ~6-9 s. The new M1 requirements and scenarios are numbered 031-036 after M2 so that existing ids stay stable.

**Revision note (v0.3.1, 2026-11-06).** Patch for plan-audit iteration 3 (PASS-WITH-DEBT 0.89, D35-D43): kill targets are stated precisely (a whole-session kill for tests; the supervisor's own TERM path signals the `timeout` child's process group); the session state table is a strict first-match order with the package-present check first, token-owned status and a bounded launch; the heartbeat uses `wait -n -p`; Stop is offered only to the session that owns the status token and re-verifies the pid before every signal; the 2400 s deadline is per package and the deploy bound is stated separately. The supervisor signal and flock pattern was **not rehearsed** before this SPEC was written (see the known gap in the baseline).

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
| B13 | Bioconductor 3.23 annotation index (`https://bioconductor.org/packages/3.23/data/annotation/src/contrib/PACKAGES`) and HTTP HEAD `Content-Length`, measured 2026-11-06: every package listed in the allowlist below has an `MD5sum` field; `org.Tgondii.eg.db` and `org.Sco.eg.db` are **not in the index**. Pre-install set is 650,940,605 bytes (about 651 MB) compressed; the whole available allowlist is 924,799,222 bytes (about 882 MB). Installed sizes: see B14. | lead, host |
| B14 | Installed sizes and install times (lead, hurlab, 2026-11-06, source install into a scratch library): `org.Hs.eg.db` 398.5 MB in 29.7 s (3.23.1); `org.Mm.eg.db` 380.7 MB / 27.5 s; `org.Rn.eg.db` 273.9 MB / 24.0 s; `org.Dr.eg.db` 140.8 MB / 17.9 s; `org.Ce.eg.db` 71.5 MB / 15.5 s; `reactome.db` 1365.4 MB / 70.1 s (1.96.0); the other allowlisted organism packages 11.8-217.0 MB and 12-20 s each. Whole available allowlist 3734.2 MB; the six pre-installed packages 2630.8 MB. | lead, host |
| B15 | `richR::buildAnnot(..., keytype = "SYMBOL")` counts on hurlab (lead, 2026-11-06), as rows / genes / terms / seconds. GO: human 1794913 / 20826 / 21344 / 85.5; mouse 2101010 / 26322 / 22180 / 61.6; rat 2058200 / 23756 / 22067 / 38.6; zebrafish 1057140 / 21813 / 14273 / 20.7; celegans 521875 / 14135 / 9580 / 15.8. KEGG (genes / terms): human 5868 / 229 (16312 rows); mouse 6605 / 225 (17003); rat 6390 / 225 (16497); zebrafish 4554 / 155 (9725); celegans 1959 / 125 (4010). Reactome with `reactome.db` attached, rows / genes / terms: human 137039 / 11287 / 2811 (4.8 s); mouse 87743 / 8851 / 1835; rat 68706 / 6909 / 1813; zebrafish 59126 / 5975 / 1683; celegans 41841 / 4289 / 1401 (each 1-5 s). | lead, host |
| B16 | **Defect in richR 0.1.6:** `buildAnnot(anntype = "Reactome")` fails for every species even with `reactome.db` installed ("object 'reactomePATHNAME2ID' not found") unless `reactome.db` is attached; the richR 0.2.0 NEWS (lines 139-141) documents this 0.1.x bug. richR is not changed by this leaf (no 0.2.0 adoption), so richStudio attaches the package itself (REQ-031). | lead, host |
| B17 | Fixture measurement (lead, hurlab): for the 20-gene human fixture `GO:0006915` has 1766 BP genes, above `maxGSSize` 500, so richGO can never report it. Measured result: 328 rows, 298 with Padj < 0.05, top term `GO:0097193` (Annotated 294, Significant 16, Padj 2.55e-23), then `GO:0043065`, `GO:0070059`, `GO:0071214`, `GO:0104004`. | lead, host |
| B18 | Annotation cache timings (lead, hurlab, human GO SYMBOL): build 84.8 s; the `Annot` object is 73 MB in memory; `saveRDS` compressed 4.0 s / 11 MB, `readRDS` 2.5 s; uncompressed 1.2 s / 153 MB, read 1.8 s; the read object is identical to the built one (`identical()` TRUE); `richGO` on a cached annotation 6.3 s; in a persistent multisession worker the first analysis takes 1.8 s and the second 0.0 s of annotation work. Whole analysis about 91 s without cache, about 6-9 s with it. | lead, host |

Not measured, therefore not assumed: download time of the tarballs (install times are in B14); whether `setsid`, `flock` (lead-measured present: `/usr/bin/flock`, util-linux 2.39.3), GNU `timeout` (9.4) and `curl` exist on the host (AC-006 runs `command -v setsid flock timeout curl`); the shiny-server `KillMode` (whether a service restart kills a detached installer; `systemctl show shiny-server -p KillMode` is recorded in AC-001).

**Known gap (not rehearsed).** The supervisor's signal, `flock` and process-group pattern (fd 9 inherited by children, `trap` firing during `wait -n`, `timeout` creating its own process group, session-wide kill) was not executed before this SPEC was written: the lead's local rehearsal was refused by the local permission policy and the auditor's sandbox refused it too. Every statement about that pattern is therefore a design claim from the `timeout`, bash and `flock` documentation. AC-004, AC-005 and AC-006 are the first measurement; the developer runs them and the lead re-runs them independently before M1 is accepted.

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

One tracked file `inst/extdata/annotation-allowlist.tsv` is the single source for the deploy and the app. Columns: `species`, `package`, `kind` (`organism` or `reactome`), `status` (`available` or `unavailable`), `preinstall` (`yes`/`no`), `est_mb` (compressed tarball, rounded up), `inst_mb` (installed size in MB, from the measurement of B14 and committed before merge), `reactome_supported` (`yes`/`no`, from the pinned richR table), `reason` (non-empty for `unavailable`). The single `reactome` row has `species = *`. Initial contents (versions and sizes measured by the lead on 2026-11-06, B13; the index may move, so the installer reads the version from the index at install time):

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

Measured installed sizes (B14) for the six pre-installed packages, to be committed as `inst_mb` (rounded up): `org.Hs.eg.db` 399, `org.Mm.eg.db` 381, `org.Rn.eg.db` 274, `org.Dr.eg.db` 141, `org.Ce.eg.db` 72, `reactome.db` 1366; the thirteen other available packages carry their own measured value in the 12-217 range. The sum over the available rows is 3734.2 MB, so the cap of OD-5 is `max(5 GiB, 2 x 3734.2 MB)` = 7468.4 MB (about 7.3 GiB); the unit test computes it from the committed column.

The **resolver** is `(species, anntype, keytype) -> needed packages or a refusal`: GO and KEGG need the organism package; Reactome needs `reactome.db` and, when the keytype is not ENTREZID, the organism package; an `unavailable` species, a species without a row, or Reactome for a `reactome_supported = no` species is refused with a named reason. Names are accepted only by exact match against the file and must also match `^[A-Za-z][A-Za-z0-9.]*$`. A unit test asserts the file against the pinned richR table and the dropdown values.

`inst/extdata/annotation-verify-floors.tsv` holds the verification **floors** (`species`, `anntype`, `min_genes`, `min_terms`), each at most 50% of the count the lead measured on hurlab (B15), so they catch an empty or broken annotation and are **not expected values**:

| species | GO genes / terms | KEGG genes / terms | Reactome genes / terms |
|---|---|---|---|
| human | 10000 / 10000 | 2900 / 110 | 5600 / 1400 |
| mouse | 13000 / 11000 | 3300 / 110 | 4400 / 900 |
| rat | 11000 / 11000 | 3100 / 110 | 3400 / 900 |
| zebrafish | 10000 / 7000 | 2200 / 75 | 2900 / 840 |
| celegans | 7000 / 4700 | 950 / 60 | 2100 / 700 |

Measured counts are in the deploy record for later tightening. Because the floors are a data file, a wrong floor is corrected without touching the script, and the numbers exist before the merge they gate (D9).

### Installer: bash supervisor plus base-R worker

Two files in `inst/annotation/` are the only installer, shared by the deploy (M1) and the app (M2): `annotation-install.sh` (a small bash supervisor) and `annotation-install.R` (the base-R worker; no new package dependency). The supervisor is invoked as `annotation-install.sh <package> [<package> ...]` with names only (never a URL or path from the caller); the library path comes from `RICHSTUDIO_ANNOTATION_LIB`. The deploy runs it in the foreground and reads its exit code; the app launches it detached (`setsid bash annotation-install.sh ...`, `system2(wait = FALSE)`; see Runtime flow).

**Supervisor (bash)**

1. Checks the tools it needs (`command -v flock timeout curl Rscript`, bash >= 5.1 for `wait -n -p`) and exits **127** naming the missing tool; this is distinct from `busy`.
2. Installs the `trap` on TERM, INT and HUP before it touches the lock, the status file or staging (see step 8 for what the handler does).
3. Takes the lock: `exec 9>"$LOCK"; flock -n 9 || exit 75`. Exit 75 means `busy`: another installer holds the library; the loser writes nothing (it never touches the status file or staging).
4. Removes every `<lib>/.staging-*` directory. This is safe without an age rule because the lock is held, so no other writer exists (D14). Then, for each package in turn: creates `<lib>/.staging-<pkg>-<token>`, writes the status file (below) with its own pid `$$`, `state=running`, the `request` token, the current package and the **2400 s deadline for this package**.
5. Runs the worker phases `prepare`, `download`, `install`, `validate`, `finalize`, each as `timeout --signal=TERM --kill-after=30 <limit> Rscript annotation-install.R <phase> <package> <staging path> &`, passing the staging path to every phase. The limit for `download`, `install` and `validate` is `min(1200, remaining)`, for `prepare` and `finalize` `min(120, remaining)`, where `remaining` is the package's deadline minus now; a spent deadline ends the package with `timed_out`. `timeout` runs the worker in its own process group (its pgid is the `timeout` pid, `$!`) and signals that group, so `curl` and `R CMD INSTALL` die with the phase; the worker's `curl --max-time` is 1170 s, below the phase limit.
6. Waits without blocking the heartbeat: it loops `sleep 10 & tick=$!; wait -n -p done "$phase_pid" "$tick"`; when `done` is the tick it refreshes the `heartbeat` field and loops; when `done` is the phase it takes the exit status from that same `wait -n` return value. The supervisor is the only writer of the status file and of the heartbeat; the tick is a plain `sleep`, not a writer, and it is killed when the phase ends. The trap fires during `wait -n`.
7. Maps worker exit codes to reason codes: 0 ok; 10 `no_network`; 11 `checksum_mismatch`; 12 `not_enough_disk`; 13 `dependency_missing`; 14 `entry_invalid`; 15 `index_no_md5`; 16 `unavailable`; 17 `timed_out` (the worker's own curl exit 28); 20 package already present and valid (next package); 124 `timed_out`; 137 `timed_out` when the phase's elapsed time reached its limit and `internal_error` otherwise (137 is also what an out-of-memory kill returns); any other code `internal_error`.
8. The trap handler first ignores further signals (`trap '' TERM INT HUP`, so a second TERM or HUP during the grace wait changes nothing), then signals the running phase: `kill -TERM -- -$phase_pid` (the `timeout` process group); if that fails because `timeout` has not yet called `setpgid`, it falls back to `kill -TERM $phase_pid` (`timeout` forwards TERM to its child). It waits up to the 30 s grace, escalates with `kill -KILL -- -$phase_pid`, removes the staging directory, writes the terminal status `stopped`, and exits 130.
9. On every other end it removes its staging directory, writes the terminal status (`completed` or `failed` with the reason code) and exits 0 (completed) or 1 (failed). The lock is released when the process exits.

**Kill targets (D35).** Two different things are killed and the SPEC never calls them by one name. (a) *Supervisor-driven stop* (Stop, timeouts): the supervisor signals the `timeout` child's process group (`-$phase_pid`) as in step 8; this never signals the supervisor's own group. (b) *Test and crash simulation*: a **whole-session kill** `pkill -KILL -s <sid>` where `<sid>` is the `setsid` session id read from `ps -o sid= -p <supervisor pid>`; every descendant stays in that session even after `timeout` calls `setpgid`, so this kills supervisor, `timeout`, worker and `curl` together and the lock is free at once. Killing only the supervisor (`kill -KILL <pid>`) leaves `timeout`, the worker and `curl` alive in the session and holding fd 9, so the lock stays held until they end.


**Lock.** One fixed file, `<annotation parent>/r<R minor>-bioc<Bioc version>.lock` (a regular file next to the library, inside `/home/juhur/.local/share/richStudio/annotation/`), one lock per library so only one install runs at a time; the deploy and the app use the same file. The lock is the kernel `flock(2)` on descriptor 9, held for the supervisor's whole life. The kernel releases it on any exit, including SIGKILL, so there is **no stale detection, no pid or start-time matching, no takeover, no tombstone and no lock directory**. Children inherit descriptor 9 on purpose: if the supervisor is SIGKILLed while a worker is still running, the orphaned worker keeps the lock until it ends (at most the phase limit plus the 30 s grace), so an orphan can never write into staging while another installer runs; when nothing holds the descriptor the lock is free at once. The status file's pid, package and deadline are informational only and are never used for mutual exclusion.

**Worker (base R).** `prepare`: validate the package name against the allowlist and the library path against the deploy checks; if the entry already exists, verify `DESCRIPTION`/version/load and exit 20 for a valid entry or 14 for an invalid one (it is never replaced or deleted, D14); check the free-space floor and the size cap; fetch and parse the pinned index; require an `MD5sum` (15 otherwise); write the plan (version, md5, url) into `<lib>/.staging-<pkg>-<token>/plan`. `download`: `curl --fail --proto '=https' --proto-redir '=https' --max-redirs 3 --max-time 1200 --write-out '%{url_effective}'`; the final-URL host must be `bioconductor.org` (D19); the MD5 is compared to the index and the SHA-256 recorded. `install`: `R CMD INSTALL --library=<staging>/lib <tarball>`. `validate`, in a fresh process still in staging: `DESCRIPTION` `Package` and `Version` as expected, `requireNamespace()` with `lib.loc = <staging>/lib`, and a real probe (an organism package: `AnnotationDbi::keys(<pkg>, keytype = "ENTREZID")` is non-empty; `reactome.db`: `reactomePATHID2EXTID` is non-empty). `finalize`: atomic same-filesystem rename of the package directory into the library (never onto an existing entry), then write `INSTALLED.tsv` (package, version, sha256, md5, source_url, installed_at) by temporary file and rename (REQ-009).

Limits (owner decision OD-3): 1200 s per download, 1200 s per install, 2400 s deadline per package (a run of N packages is bounded by N x 2400 s), 30 s TERM-to-KILL grace. Free-space floor 2 GiB; library size cap = `max(5 GiB, 2 x sum(inst_mb of every available allowlist row))` computed from the data file (OD-5), so the number is derived from the M1 measurement yet checkable before merge (AC-008).

### Status file (D24)

- Path: `<annotation parent>/r<R minor>-bioc<Bioc version>.status`, one per library, overwritten when a new supervisor starts (the previous run's final state is kept until then). Writer: the supervisor only, by writing `<status>.tmp.<pid>` in the same directory and `mv -f` onto the status path, so a reader never sees a partial file. Format: `key=value` lines, UTF-8, values with no newline.
- Fields: `schema` (`1`); `pid` (supervisor pid, integer); `request` (opaque token `[A-Za-z0-9]{8,32}` passed by the launcher through `RICHSTUDIO_ANNOTATION_REQUEST`; **the app uses it to recognise its own run**, never for mutual exclusion); `packages` (comma list); `current` (package being processed or empty); `phase` (enum `starting | preparing | downloading | installing | validating | finalizing | done`); `state` (enum `running | completed | failed | stopped`); `reason` (empty unless `failed`, else a reason code); `started` (run start), `deadline` (of the current package), `heartbeat`, `updated` (epoch seconds).
- Terminal states are `completed`, `failed` and `stopped`; `running` is the only non-terminal state. Reason codes: `no_network`, `timed_out`, `checksum_mismatch`, `not_enough_disk`, `dependency_missing`, `entry_invalid`, `index_no_md5`, `unavailable`, `internal_error`, and `interrupted` (derived by the reader, never written: see below).
- Readers are the app's session observers (Runtime flow). A reader treats a status as live only when `state=running` and `/proc/<pid>/cmdline` of that pid contains `annotation-install.sh`; `state=running` with a dead or different pid means the supervisor was killed (SIGKILL, service restart): if `flock -n <lock> true` still fails the orphaned worker is finishing, the reader reports "waiting for a previous installer to finish" (at most about 20 minutes: the phase limit plus the 30 s grace), otherwise it reports `failed` with reason `interrupted`; the next supervisor sweeps the leftover staging when it takes the lock.
- The heartbeat is informational ("last activity N s ago"); a stalled heartbeat releases nothing, because the lock follows the process.


### Runtime flow (M2)

1. When Run is pressed, the observer calls the resolver and checks the needed packages against the library directory: an entry counts as present only if `<lib>/<pkg>/DESCRIPTION` is readable with the expected `Package` field; a directory that exists but fails that check is reported as `entry_invalid` with a message naming the path for the owner to remove (the app never deletes it) (D25). No package is loaded and `.libPaths()` is not changed.
2. Nothing missing: the run starts exactly as today. Refused (unavailable species or annotation type): refused before any job starts. Missing and available: the observer stores the already-reviewed run request (the SPEC-WS-004 review snapshot taken at Run) in the session, shows the "installing annotation" row and launches `setsid bash annotation-install.sh <packages>` with `system2(wait = FALSE)` using absolute paths, every argument `shQuote`d, stdin from `/dev/null`, output to `<annotation parent>/r4.6-bioc3.23.log`, (`Sys.which("setsid")`, the supervisor from `system.file("annotation", package = "richStudio")`) and an explicit environment (`RICHSTUDIO_ANNOTATION_LIB`, `R_LIBS_USER`, `RICHSTUDIO_RSCRIPT=file.path(R.home("bin"), "Rscript")`, `RICHSTUDIO_ANNOTATION_REQUEST`), so a different `PATH` under shiny-server cannot matter (D27). **The install never runs in the future pool**, and no waiting session holds a worker (D7). If another supervisor already holds the lock, the launched one exits 75 and the session watches the status file (rule 6); `flock -n` decides, not the app.
3. Every 2 s (`invalidateLater(2000)`, no waiting future, no sleep) each session reads the status file once and evaluates **these rules in strict first-match order** for its own run request (the Run click has a `request` token; one session may hold several):

| # | Condition (first that is true applies) | Session action |
|---|---|---|
| 1 | the resolver finds every needed package present | continue: start the stored enrichment job (a status of any kind is ignored) |
| 2 | the status carries this request's token and `state=running` with a live supervisor | show "installing" with the phase text |
| 3 | the status carries this request's token and `state=running` with a dead or foreign pid | if `flock -n <lock> true` fails show "waiting for a previous installer to finish", else failure `interrupted` |
| 4 | the status carries this request's token and `state` is `failed` or `stopped` | show the failure (reason message, manual command), keep the request on the row for Retry |
| 5 | the status carries this request's token, `state=completed` but a needed package is still missing | failure `internal_error` |
| 6 | the status carries another token and `state=running` with a live supervisor | show "waiting for another installation"; remember that a wait was observed |
| 7 | none of the above, and this request has not launched since its last observed wait (or ever) | launch one supervisor and record the launch time |
| 8 | none of the above, a launch was made, and fewer than 15 s have passed | show "starting" |
| 9 | none of the above, a launch was made, and 15 s have passed without a status carrying this token or a live other token | failure `internal_error` ("the installer did not start"); no further automatic launch |

Launch is bounded: there is at most **one automatic launch per Run click**, plus one more each time the request has observed another live token (rule 6) turn terminal; each such extra launch needs a distinct other supervisor to have run, so the count cannot loop. A launch that fails before writing any status (unwritable parent, `exec` failure, missing tool, exit 127) therefore ends at rule 9 after 15 s with a failure and a Retry; the app never relaunches every 2 s. **Retry** (a new Run click for the same retained request) creates a new token and launches once.

4. Stop is offered only on the install row of the session whose request token equals the status token (D38); every other session's row offers Dismiss only. Stop reads `pid` from the status file, verifies that `/proc/<pid>/cmdline` contains `annotation-install.sh` and that the process start time is not later than the status `started`, and only then sends SIGTERM to that pid. If the status is still `running` after 45 s it **repeats the same verification** and then sends SIGKILL to that pid and, after a further 5 s, `pkill -KILL -s <sid>` for the session it read from `/proc/<pid>/stat` before the first signal; if the verification now fails (the pid was recycled), nothing is signalled. In the TERM case the supervisor's trap cleans up (staging removed, terminal status `stopped`); after a kill the lock follows the processes and the next installer sweeps staging. The owner of the host stops an install from a shell with `pkill -TERM -f annotation-install.sh` (documented in `docs/DEPENDENCY_DEPLOYMENT.md`); an in-app administrative Stop is out of scope (OD-13).
5. Dismiss discards the retained request and clears the row.

6. The job-tray row for the install is a registry record driven by the status file; it is not a future. The SPEC fixes the observable row, not the mechanism.

Failure reason messages (REQ-022): fixed plain text for `no_network`, `timed_out`, `checksum_mismatch`, `not_enough_disk`, `dependency_missing`, `entry_invalid`, `index_no_md5`, `unavailable`, `internal_error` and `interrupted`; where useful the manual `BiocManager::install("<pkg>")` command is shown in the "Copy command" panel. The panel is fed from a structured failure (reason code plus command), not from the text classifier (D15); the text classifier remains for failures raised by richR.


### One annotation builder: Reactome attach and cache (REQ-031, REQ-037)

richR 0.1.6 builds a Reactome annotation by reading `reactomePATHNAME2ID` and related objects as if `reactome.db` were attached, which fails for every species unless it is (B16). richStudio therefore has **one** builder, `richstudio_build_annotation(species, keytype, anntype)` in `R/annotation_cache.R`, that (1) for Reactome attaches `reactome.db` when it is installed and not yet attached (`requireNamespace("reactome.db")` then `if (!"package:reactome.db" %in% search()) attachNamespace("reactome.db")`), (2) consults the cache below and (3) calls `richR::buildAnnot` only on a miss. It is the **default `annotation_builder`** on every path in the app that builds an annotation: the defaults of `shiny_enrich` and `run_enrichment_jobs` in `R/deg_enrich.R`, and the builder that `R/enrich_tab.R` (about line 416) passes to `enrichment_background_check_job`; the background-check path therefore gets the same attach and the same cache as the analysis path. No installer code attaches anything, and no other richR behaviour changes. If `reactome.db` is not installed the existing missing-package behaviour applies (in M2 the resolver has already arranged the install).

### Annotation cache (M1, REQ-032..038)

A built annotation costs about 85 s for human GO (B15) and the analysis is otherwise a few seconds, so by owner decision a two-level cache is part of M1 (B18).

- **Level 1, memory:** an LRU of 3 entries inside the persistent future worker process (module-level environment). A repeated analysis in the same worker costs 0.0 s of annotation work. The bound is by count; a human GO entry is 73 MB (B18) and mouse and rat GO have more rows (B15), so the ceiling per worker is an estimate, not a measurement; the deploy record lists the resident set size of the worker processes after the pre-warm (`ps -o rss`) so the real figure is known.
- **Level 2, disk:** `<annotation library parent>/cache/<library name>/` (today `/home/juhur/.local/share/richStudio/annotation/cache/r4.6-bioc3.23/`), created by the app user with mode 0700. Each entry is a compressed `saveRDS` written to a temporary name in the same directory and renamed into place under the name `<digest>.rds`, where `<digest>` is the 32-hex `tools::md5sum` of a temporary file holding the canonical key text (base R only, no new dependency); the name pattern is `^[0-9a-f]{32}\.rds$`.
- **Key (D50):** schema version, R minor, species, keytype, anntype, the versions of `richR`, `bioAnno` and `AnnotationDbi`, the organism package, `GO.db` for GO builds and `reactome.db` for Reactome builds, plus `RemoteSha` or `GithubSHA1` from the installed `DESCRIPTION` of richR and bioAnno when present (they are installed from pinned commits, so the version string alone does not identify the code). The key text is also stored inside the file and re-checked on read, so a renamed file or a hash collision cannot return a wrong annotation. A change in any component is a miss.
- **Lookup and source:** memory, then disk, then build; a disk hit also fills memory; a build writes disk and memory. The returned object carries `attr(x, "cache_source")` equal to `memory`, `disk` or `built` (never saved to disk); a **hit** means `memory` or `disk`. Every lookup logs one line (`annotation_cache: source=<...> species=<...> anntype=<...> secs=<...>`, no gene lists), and the internal `annotation_cache_stats()` returns the counters memory hits, disk hits, misses, writes, evictions and disabled calls. Anything that fails (unreadable file, wrong class, missing columns, zero rows, key mismatch, write error) falls back to a rebuild, **never fails the analysis**, and a bad file is replaced by the rebuilt one. Validation on read: the object inherits from the richR `Annot` class, has the expected columns, `nrow > 0` and its stored key equals the requested key.
- **Safety (D52):** the cache is **disabled for the call** (the annotation is built, nothing is read or written on disk) unless all of these hold: `RICHSTUDIO_ANNOTATION_LIB` is set; the cache directory is a real directory (`Sys.readlink(path) == ""`, not a symlink), owned by the app user (`file.info()$uid`), with mode 0700; every parent up to the annotation parent is a real directory owned by the app user and not group- or world-writable; the file being read has a name matching the pattern, is a regular file that is not a symlink (`Sys.readlink(file) == ""`) and is owned by the app user. `readRDS` is applied to nothing else, and no path comes from the user. A file outside the cache directory, with a name outside the pattern, or a symlink inside it is never read. A matching file with a wrong key or a damaged content is read, rejected and replaced. **A stubbed builder never touches the disk cache**: the internal test argument that injects a stub switches the cache to memory-only with a `stub` marker in the key, so a stub's output can never be served as a real annotation. Concurrent writers are harmless: they write the same content to distinct temporary names and rename atomically.
- **Bound (D51):** on each write the cache evicts the oldest-mtime entries (never the one just written) until the directory holds at most 200 entries and at most 1 GiB; stale `.tmp-*` files older than one hour are removed at the same time. A human GO entry is 11 MB (B18) and the 15 pre-warm entries stay far below the bound. The cache directory is counted in the library size cap of REQ-008.
- **Pre-warm:** the deploy verification (REQ-036) builds GO, KEGG and Reactome for SYMBOL for the five pre-installed species through the one builder (15 entries) and asserts that a second pass is all hits (memory or disk), so the first users do not pay the build.


### Test transport and seams (D1, D2)

Production constants: repository `https://bioconductor.org/packages/3.23/data/annotation`, allowlist `inst/extdata/annotation-allowlist.tsv`, downloader `curl` (used inside the worker; the supervisor, `flock` and `timeout` are never replaced). A single test-only configuration is honoured only when **both** environment variables are set: `RICHSTUDIO_ANNOTATION_TEST_MODE=1` and `RICHSTUDIO_ANNOTATION_TEST_CONFIG=<path to a dcf file>`. The file may name: a local `file://` repository, an alternate allowlist file, a **fake downloader** executable (invoked instead of `curl`; it can sleep, fail, refuse, log every call to a shared file, report a final URL, and serve a pre-built tarball), shortened phase limits and deadline (the clock seam) and a free-space override. Neither variable can be set from the UI, a request, an upload or the project file; the deploy never sets them; verification and the post-swap smoke fail when either appears in the release `.Renviron` or in the live app process environment (`/proc/<pid>/environ`); with `TEST_CONFIG` set but `TEST_MODE` unset the installer prints the production plan (`--print-plan`) and ignores the file (AC-010). CI needs no internet: slow, refused and failing downloads, request counting and MD5 mismatches are all produced by the fake downloader, and the local repository holds tiny source packages named from the alternate allowlist. The e2e app launcher `tests/e2e/annotation-app.R` (test-only, not shipped) wires the existing `enrichment_runner` and `annotation_builder` parameters to stubs, so a tiny fake `org.*` package never has to support a real `buildAnnot`.

### Deploy, verification and smoke (M1)

- A single function writes the release `.Renviron` (`RENV_CONFIG_AUTOLOADER_ENABLED=FALSE`, `R_LIBS_USER=<release lib>:<annotation lib>`, `RICHSTUDIO_ANNOTATION_LIB=<annotation lib>`); the finalize step, the preflight and the tests all use it, so the bytes can be compared exactly (D5).
- `ensure_annotation_library` (idempotent, as juhur): create the library (0755) and run the supervisor once **per** `preinstall = yes` package that is absent, so each package has its own 2400 s deadline; the deploy-level bound is the sum of those deadlines (at most 6 x 2400 s today), a deploy-time step outside the web request path. On exit 75 (`busy`) the deploy retries every 10 s for up to 2400 s and then fails with a message naming the holder pid from the status file; on exit 127 it fails at once naming the missing tool.
- `verify_runtime_env <release dir>` runs as the app user from the release directory with a minimal environment (`env -i HOME=... PATH=...`, no `R_ENVIRON_USER`, `R_PROFILE_USER` or `R_LIBS_USER` override) so that the release's own `.Renviron` and `.Rprofile` take effect exactly as under shiny-server. It asserts: the first two `.libPaths()` entries are the release library then the annotation library; the same two entries appear in a `future::multisession` worker (`future::value(future::future(.libPaths()))`); the `.Renviron` bytes equal the generator output; the test-only variables are absent; each pre-installed package loads from the annotation library, is built for R 4.6 and is not found in the release library; GO, builtin KEGG and Reactome annotations for the five species, built through the richStudio path (which attaches `reactome.db`, REQ-031), meet the floors of the table above, and a second pass hits the annotation cache (REQ-036); `richStudio:::shiny_enrich` on the human fixture (below) returns the expected term.
- Order in the full deploy: build -> `ensure_annotation_library` -> existing `verify_release` -> finalize -> `verify_runtime_env` at the final path (before the swap) -> swap and restart -> `wait_for_app` -> `verify_runtime_env` against the live path and an HTTP check -> on any failure after the swap, the existing `restore_release` runs and the script exits non-zero. `--preflight` runs the same function against the build tree with a scratch annotation library and the generated `.Renviron` (REQ-014).
- Fixture `tests/fixtures/annotation/human-query-20.tsv`: the 20 human SYMBOLs TP53, BAX, BCL2, CASP3, CASP8, CASP9, APAF1, CYCS, BID, BAK1, FAS, FADD, TNFRSF10B, MDM2, CDKN1A, ATM, CHEK2, BBC3, PMAIP1, XIAP. Measured by the lead on hurlab (B17): 328 rows, 298 with Padj < 0.05, top term `GO:0097193` (Annotated 294, Significant 16, Padj 2.55e-23). Expected by the verification: at least 149 rows (50% of 298) with Padj below 0.05, with `GO:0097193` among the five best terms by Padj (the exact order can move with a Bioconductor patch release; the row bound is the robust check). (`GO:0006915` is not used: it has 1766 BP genes, above `maxGSSize` 500, so it can never be reported.)

## Dependencies and ownership

- Logical prerequisites: SPEC-WS-013 merged to `main` (done: `141e095` plus PR #3 fix `fcf91c8`). No dependency on SPEC-WS-004/005/006 internals beyond reading the review snapshot and extending the background record (REQ-026).
- One disposable implementer owns this leaf in its own fresh worktree; each milestone is independently reviewed, merged and CI-verified before the next starts; M1 is deployed by the checklist below before M2 starts.
- Shared targets are exclusive locks, even for nonoverlapping line edits.
- No `DESCRIPTION`, `NAMESPACE` or `renv.lock` change: the installer uses base R and system tools the host already has (`bash`, `curl`, `flock`, GNU `timeout`, `setsid`, checked in AC-006). A new package dependency needs a registry revision.
- Upstream richR work is separately owned; no richR 0.2.0 adoption; richR is not edited.

### M1 file ownership (installer, deploy, verification)

Existing: `R/deg_enrich.R` (default builder of `shiny_enrich` and `run_enrichment_jobs`; lead-approved out-of-list, M2 later adds provenance only), `R/enrich_tab.R` (only the default builder passed to `enrichment_background_check_job`, about line 416; lead-approved out-of-list, M2 later changes the Run observer), and `R/enrichment_background.R` only if it calls a builder directly, `scripts/deploy-r46-release.sh`, `docs/DEPENDENCY_DEPLOYMENT.md`, `install_dependencies.R`

New: `inst/annotation/annotation-install.sh`, `inst/annotation/annotation-install.R`, `inst/extdata/annotation-allowlist.tsv`, `inst/extdata/annotation-verify-floors.tsv`, `tests/fixtures/annotation/human-query-20.tsv`, `scripts/test-annotation-library.py` (drives the installer with a fake downloader and local repository), `docs/quality/ws014-m1-deploy-record.md`, `R/annotation_cache.R`, `tests/testthat/test-annotation-cache.R`.

### M2 file ownership (app integration)

Existing: `R/enrich_tab.R` (Run observer, dropdown choices from the allowlist, install row), `R/workspace_jobs.R` (install row kind and state label, structured failure into the Copy command panel, Stop/Retry for the install row), `R/enrichment_background.R` (additive `annotation$packages` field), `docs/PROJECT_FORMAT.md` (one paragraph on the additive field), `docs/DEPENDENCY_DEPLOYMENT.md`. Existing tests change only where a changed label or id requires it; an assertion that enumerates the exact keys of the background `annotation` object may gain the new key, recorded in the M2 record; no assertion is weakened.

New: `R/annotation_packages.R` (allowlist reader, resolver, status reader, detached launcher, structured failure), `tests/testthat/test-annotation-packages.R`, `tests/testthat/helper-annotation-repo.R`, `tests/e2e/annotation-app.R`, `tests/e2e/annotation-install.spec.ts`, `docs/quality/ws014-m2-record.md`.

## Milestones

| Milestone | Scope | Acceptance |
|---|---|---|
| M1 Installer, deploy-time library, real-environment verification | installer, allowlist and floors data files, pre-install of six packages, `.Renviron` generator, `verify_runtime_env`, post-swap smoke with restore, preflight on a scratch library, pin fix (R minor), measured sizes and cap, Reactome attach, two-level annotation cache with deploy pre-warm, owner redeploy | AC-001 .. AC-017 and AC-031 .. AC-038 |
| M2 App integration | resolver, detached launch, status polling, row and states, failure contract, duplicate/Stop/Retry, app-side validation, provenance, live runtime install | AC-018 .. AC-030 |

## GEARS requirements

### M1

- **REQ-001** The deploy shall create the annotation library outside every release directory, owned by the app user with mode 0755, writable by the shiny-server process, per R minor and Bioconductor version, and shall leave it in place on release switch and rollback.
- **REQ-002** The release `.Renviron` shall be produced by one generator function, shall list the release library before the annotation library in `R_LIBS_USER`, and shall set `RICHSTUDIO_ANNOTATION_LIB`.
- **REQ-003** The deploy shall pre-install `org.Hs.eg.db`, `org.Mm.eg.db`, `org.Rn.eg.db`, `org.Dr.eg.db`, `org.Ce.eg.db` and `reactome.db` through the installer.
- **REQ-004** The installer shall install through a private staging directory and an atomic rename, shall validate each package in staging before the rename, shall never replace or delete an existing library entry, and shall leave no staging directory after success, failure, timeout or stop; after a SIGKILL of the supervisor the library shall be unchanged and the next lock holder shall remove any leftover staging before it installs.
- **REQ-005** The installer shall serialize installs per library with a kernel advisory lock (`flock`) on a fixed lock file, held by the supervisor for its lifetime and inherited by its children, so that a second installer gets `busy` immediately, a SIGKILLed holder frees the lock at once (an orphaned worker holds it until the worker ends), and no stale detection, takeover or owner matching exists; owner and status data shall be informational only.
- **REQ-006** The installer shall run as a bash supervisor that runs each worker phase as a child under `timeout`, knows each child's pid and exit status, enforces 1200 s per download, 1200 s per install and a 2400 s deadline per package, ticks a heartbeat with `wait -n -p` without a second writer, traps TERM, INT and HUP (installed before any other action, re-entry ignored) to signal the child's process group and clean up, exits 127 for a missing tool and 75 for a busy lock, maps exit codes to the fixed reason codes, and writes the status file atomically.
- **REQ-007** The installer shall download only over https from the pinned Bioconductor repository, shall reject a redirect whose final URL is not on that host over https, and shall fail when the repository index has no MD5 for the package or the tarball does not match it.
- **REQ-008** The installer shall refuse to start a download when free space is below 2 GiB or when the library plus its annotation cache plus the package estimate exceeds the cap of `max(5 GiB, 2 x sum of measured installed sizes of the available allowlist, computed from the committed values)`, and the measured installed sizes shall be present in the allowlist before merge.
- **REQ-009** The installer shall record every installed package in `INSTALLED.tsv` (package, version, sha256, md5, source URL, time) by temporary file and rename, while holding the lock, whether it runs from the deploy or from the app.
- **REQ-010** The test-only repository, downloader, allowlist, shortened-limit clock and free-space seams shall take effect only when both test environment variables are set; otherwise the installer shall use the production constants, and the release `.Renviron` and the live app process environment shall contain neither variable.
- **REQ-011** Before the symlink swap, the deploy shall run a verification as the app user from the release directory in the release's real environment, with no environment overrides, and shall fail unless the library search order, the worker search order, the `.Renviron` bytes and the annotation packages are exactly as specified.
- **REQ-012** The verification shall build a real GO, builtin KEGG and Reactome annotation for human, mouse, rat, zebrafish and celegans through the richStudio builder, each meeting the floors in the tracked data file, and shall run one real enrichment on the fixed human fixture that returns at least 149 rows below Padj 0.05 with `GO:0097193` among the five best terms by Padj.
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
- **REQ-023** While an install is running, a second Run for the same package shall not start a second install; a Run for another package shall wait for the running install and then launch its own; Stop shall be offered only to the session whose request token equals the status token, shall verify the supervisor pid before every signal and shall SIGTERM it so that it removes staging and writes the `stopped` status; Retry on a failed install row shall launch a new supervisor and continue the retained run request; Dismiss shall discard the retained request.
- **REQ-024** If the user's browser session ends during an install, the installer shall continue to completion, and the next session that needs the package shall find it installed and shall not download it again; a service restart that kills the supervisor shall leave the library unchanged and be reported as `interrupted`, or as waiting for a previous installer while an orphaned worker still holds the lock.
- **REQ-025** If the annotation library fails the deploy ownership, mode or path checks, the app shall show a warning and shall refuse to install into it with the manual command, and shall not change `.libPaths()`.
- **REQ-026** The enrichment result's existing background record shall carry the name and installed version of every annotation package the run needs (for Reactome with a non-ENTREZID keytype, both `reactome.db` and the organism package) under `annotation$packages`, shall round-trip through project save and load without a change to the manifest's top-level keys, shall be omitted when no annotation package is needed, and shall be absent, without error, in projects saved before this change.
- **REQ-027** The installer and the app shall not change the sealed release library, the release `.Renviron`, `.libPaths()` ordering, enrichment cutoffs, background semantics or any statistical result.
- **REQ-028** When a species whose package is not pre-installed is run on the live host, the app shall install it as the shiny-server process user, shall show the installing state, shall continue to the result, and shall add its row to `INSTALLED.tsv`.
- **REQ-029** When a run starts after an install in a process that was already running, the future worker shall load the newly installed package without a restart.
- **REQ-030** While a session needs a package that is missing, the app shall read the status file every 2 s without blocking, shall evaluate the strict first-match rules of the Runtime flow with the package-present check first and the request token deciding ownership, shall make at most one automatic launch per Run click (plus one per observed foreign install that ends), and shall fail the request with `internal_error` when no status for it appears within 15 s of a launch.

### M1 (added in v0.3.2; numbered after M2 so that existing ids stay stable)

- **REQ-031** Before building a Reactome annotation, richStudio shall attach `reactome.db` when it is installed and not yet attached, so that a Reactome annotation builds for every species with richR 0.1.6.
- **REQ-032** The app shall obtain an annotation from a two-level cache, a memory LRU of 3 entries per worker process and then a disk cache, shall build it only when both miss, and shall make every lookup observable (a returned `cache_source` of `memory`, `disk` or `built`, one log line per lookup, and counters in `annotation_cache_stats()`).
- **REQ-033** The disk cache shall write each entry as a compressed `saveRDS` file by temporary name and atomic rename under a hashed file name, shall validate every entry on read (class, columns, rows, stored key), and shall on any failure rebuild the annotation without failing the analysis.
- **REQ-034** The disk cache shall be disabled for a call, leaving behaviour as before, unless `RICHSTUDIO_ANNOTATION_LIB` is set and the cache directory and its parents are real directories (no symlinks) owned by the app user with the stated modes; shall read only regular, non-symlink, app-owned files whose name matches the hashed-key pattern; and shall bypass the disk entirely for a stubbed builder, which is accepted only through an internal test argument.
- **REQ-035** The cache key shall consist of the schema version, R minor, species, keytype, anntype, the versions of richR, bioAnno and AnnotationDbi, the organism package, GO.db for GO and reactome.db for Reactome, and the `RemoteSha` or `GithubSHA1` of richR and bioAnno when present, so that a change in any component is a miss.
- **REQ-036** The deploy verification shall pre-warm GO, builtin KEGG and Reactome annotations for SYMBOL for the five pre-installed species through the richStudio builder, shall fail unless a second pass is all hits (`memory` or `disk`, no `built`), and the post-swap smoke shall assert a hit; the cache size shall count in the disk cap.
- **REQ-037** Every path in the app that builds an annotation, including the custom-background check and the enrichment run, shall use the one richStudio builder as its default `annotation_builder`, so that each attaches `reactome.db` for Reactome and shares the same cache.
- **REQ-038** The disk cache shall evict oldest-mtime entries on each write until it holds at most 200 entries and at most 1 GiB, shall never evict the entry just written, and shall remove stale temporary files older than one hour.

## Binary acceptance scenarios

"CI" means no internet: the fake downloader and local repository of the test transport. "Host" means the lead runs it on hurlab as juhur.

### M1

**AC-001** (REQ-001) Given a deploy, when it finishes, then `stat -c '%U:%G %a' /home/juhur/.local/share/richStudio/annotation/r4.6-bioc3.23` prints `juhur:juhur 755`; the path is not under `/opt/richStudio`; `runuser -u juhur -- bash -c 'f=$(mktemp -p /home/juhur/.local/share/richStudio/annotation/r4.6-bioc3.23) && rm "$f"'` exits 0; after `scripts/rollback.sh` to the previous release the directory and `INSTALLED.tsv` are unchanged; and the deploy record contains the output of `systemctl show shiny-server -p User -p ProtectHome -p ReadWritePaths -p ReadOnlyPaths -p KillMode` (B7 gap).

**AC-002** (REQ-002) Given the finalized release, when `cmp <release>/.Renviron <generator output for that release>` runs, then it exits 0; the file has exactly the three variables `RENV_CONFIG_AUTOLOADER_ENABLED`, `R_LIBS_USER=<release>/renv/library/release-r46:/home/juhur/.local/share/richStudio/annotation/r4.6-bioc3.23` and `RICHSTUDIO_ANNOTATION_LIB=<same annotation path>`; a unit test with a deliberately mistyped path shows `cmp` exits non-zero.

**AC-003** (REQ-003) Given the deploy, when it finishes, then `INSTALLED.tsv` has one row each for the six pre-install packages with the version found in the index at install time, `tools::md5sum` of each tarball equals the index `MD5sum`, and `packageDescription(<pkg>)$Built` starts with `R 4.6` for each.

**AC-004** (REQ-004) Given a local repository and the fake downloader (CI), when the supervisor runs, then: success leaves no `.staging-*` directory; a tarball with changed bytes ends with `checksum_mismatch` and a byte-identical library; SIGTERM to the supervisor mid-install leaves no staging and a `stopped` status; a whole-session kill (`pkill -KILL -s <sid>`) mid-install leaves the library unchanged and the staging present, `flock -n <lock> true` then succeeds, and the next supervisor run removes the staging before installing; a valid existing entry makes the run a no-op success; an invalid existing entry (wrong version) fails with `entry_invalid` and the entry is untouched; a package whose validation probe fails stays in staging and is never renamed into the library.

**AC-005** (REQ-005) Given the lock (CI) and a fake downloader that holds for at least 5 s, when supervisors run, then: the lock is a regular file at `<annotation parent>/r4.6-bioc3.23.lock` and no lock directory, owner file or tombstone is ever created (`find` shows none); a second supervisor started while the first runs exits 75 within 2 s and leaves the status file and staging untouched; three supervisors started within 1 s give exit codes 0, 75, 75 and the downloader call log shows one download; after a whole-session kill (`pkill -KILL -s <sid>`, `<sid>` from `ps -o sid= -p <supervisor pid>`) `pgrep -s <sid>` is empty and `flock -n <lock> true` succeeds within 1 s; after `kill -KILL <supervisor pid>` alone, `pgrep -s <sid>` still lists the worker and `flock -n` fails until the worker exits (hold shortened for the test) and then succeeds; with `flock` absent from `PATH` the supervisor exits 127 naming it, not 75.

**AC-006** (REQ-006) Given the supervisor and a fake downloader that sleeps or fails (CI), when it runs, then: the test first observes a worker (`pgrep -s <sid> -f annotation-install.R` is non-empty; the worker's argv always contains that name) so no check can pass vacuously; the `heartbeat` field then advances at least every 15 s while the download hangs; a hanging download and a hanging `R CMD INSTALL` end at their limits (shortened through the clock seam; `--print-plan` shows 1200, 1200 and 2400 in production) with status `failed`, reason `timed_out`, `pgrep -s <sid>` empty afterwards, staging removed and the lock free; SIGTERM does the same with state `stopped` and exit 130, and a second TERM during the grace wait changes nothing; a worker exiting with each of 10-17 maps to its reason code, 20 skips to the next package, an unknown code maps to `internal_error`, a `timeout`-killed worker maps to `timed_out`, and exit 137 without the limit reached maps to `internal_error` (one case each); the status file validates against the schema and a reader polling 1000 times during a run never reads a partial file. On the host `command -v setsid flock timeout curl` succeeds and `bash --version` (>= 5.1) is recorded. This AC is the first measurement of the supervisor pattern (known gap): the developer runs it and the lead re-runs it.

**AC-007** (REQ-007) Given repository and redirect inputs (CI), when the installer validates them, then `http://`, `ftp://`, a non-Bioconductor host and a redirect whose final URL is on another host or `http` are each rejected with a named reason; an index entry without `MD5sum` fails with `index_no_md5`; the production repository constant equals `https://bioconductor.org/packages/3.23/data/annotation`.

**AC-008** (REQ-008) Given the allowlist, when the unit test computes the cap, then it equals `max(5 GiB, 2 x sum(inst_mb))` over the available rows and no `inst_mb` is empty; a free-space seam of 2 GiB minus 1 byte, and a library size plus estimate above the cap, each stop the installer before any download with `not_enough_disk`. The measured installed sizes of B14 are committed as `inst_mb` (sum 3734.2 MB, cap 7468.4 MB) and the unit test recomputes the cap from the file; the deploy record lists `du -sk` of each of the 19 available packages, download seconds, and `df -k` of the annotation filesystem.

**AC-009** (REQ-009) Given an install, when it ends, then `INSTALLED.tsv` has a header with the six columns and one row per package; a whole-session kill (`pkill -KILL -s <sid>`) between writing the temporary file and the rename leaves the previous `INSTALLED.tsv` byte-identical; an app-started and a deploy-started install both write the same format.

**AC-010** (REQ-010) Given the installer, when `--print-plan` runs with `RICHSTUDIO_ANNOTATION_TEST_CONFIG` set but `RICHSTUDIO_ANNOTATION_TEST_MODE` unset, then it prints the production repository, the production allowlist path and `curl`; with both set it prints the test values; and `grep -c RICHSTUDIO_ANNOTATION_TEST <release>/.Renviron` prints 0 and the same pattern is absent from `/proc/<live app R pid>/environ` (host).

**AC-011** (REQ-011) Given a release directory, when `verify_runtime_env` runs as juhur with `env -i`, then it prints the first two `.libPaths()` entries (release library, annotation library) and the identical two entries from a `future::multisession` worker, and exits 0; a CI harness with a staged `.Renviron` whose annotation path is mistyped, or whose order is reversed, exits non-zero before the swap.

**AC-012** (REQ-012) Given the pre-installed library, when the verification runs, then each of the five species meets the GO, KEGG and Reactome floors of `annotation-verify-floors.tsv` (table in the design), and `richStudio:::shiny_enrich` on the human fixture returns at least 149 rows with Padj below 0.05 with `GO:0097193` among the five best terms by Padj; with the annotation library emptied the same check exits non-zero. The floors were set at or below 50% of the lead's host measurement (B15, B17); the deploy record lists the measured counts and the fixture result.

**AC-013** (REQ-013) Given the deploy harness (as in `scripts/test-deploy-recovery.py`), when the post-swap verification is made to fail, then `restore_release` runs, the app symlink points to the previous target and the script exits non-zero; when the app answers HTTP 200 but `verify_runtime_env` fails, the outcome is the same (a 200 alone never passes).

**AC-014** (REQ-014) Given `--preflight` run as juhur without sudo, when it ends, then the live `INSTALLED.tsv` sha256, the app symlink target and the checksums of `/etc/shiny-server/shiny-server.conf` are unchanged, the generated `.Renviron` does not trip the clean-tree check, the scratch annotation library holds the six packages, and the log shows the same check names as the full deploy.

**AC-015** (REQ-015) Given three planted faults (CI harness), when the deploy verification runs, then each exits non-zero before the swap with a message naming it: a copy of `org.Hs.eg.db` in the release library; a package whose `Built` is `R 4.5.x`; an annotation directory owned by root, or with mode 0777.

**AC-016** (REQ-016) Given a PATH shim printing `R version 4.6.2`, `4.7.0` and `4.5.9` (and Bioconductor `3.23` and `3.24`), when the version check runs, then 4.6.2 with 3.23 is accepted and the measured version is printed, and each of the others is rejected with a message naming both the measured and the pinned value.

**AC-017** (REQ-017) Given the M1 deploy, when the lead runs the fixture (20 human SYMBOLs, GO BP) through the live browser, then the Results page shows at least 149 rows with Padj below 0.05 with `GO:0097193` among the five best terms by Padj; the lead records the row count and closes the browser tabs before stopping the SSH tunnel.

### M2

**AC-018** (REQ-018) Given the resolver (CI), when it is called with each allowlisted `(species, anntype, keytype)`, then the needed packages equal the table in "Allowlist, resolver" (Reactome with SYMBOL: `reactome.db` plus the organism package; with ENTREZID: `reactome.db` only); given `../x`, `org.Hs.eg.db; rm -rf /`, `org.Xx.eg.db`, a URL and an empty string, then it returns a refusal and a spy on the process seam records no process start and nothing is written below the library.

**AC-019** (REQ-019) Given the dropdown, when it is built, then it offers no value whose allowlist `status` is `unavailable` (`sco`, `toxoplasma` are absent); given a session or project that restores `sco`, or Reactome for `anopheles` or `ecoli`, when Run is pressed, then the run is refused before any job with the stated reason and the job registry is unchanged; a unit test asserts the allowlist rows against the pinned richR 0.1.6 species table and the dropdown values.

**AC-020** (REQ-020) Given `plan(multisession, workers = 2)` and an install in flight (fake downloader sleeping), when another session starts an ordinary enrichment, then that job starts and completes while the install is still running; `future::nbrOfFreeWorkers()` is the same before and during the install; a third session needing the same package shows "waiting for another installation" and the count of its futures is unchanged; the supervisor is not a child of a future worker (its process group leader is its own pid), and the status file shows `running` throughout.

**AC-021** (REQ-021) Given an install, when it runs, then e2e asserts the tray row text names the package and species, the state text changes queued/downloading/installing/verifying/done, exactly one polite live region announces each change, and no failure notification and no error colour class appears.

**AC-022** (REQ-022) Given each failure reason code produced by the fake downloader or seams (`no_network`, `timed_out`, `checksum_mismatch`, `not_enough_disk`, `dependency_missing`, `entry_invalid`, `index_no_md5`, `internal_error`, `interrupted`), when the install fails, then the notification shows the fixed message for that code, the Copy command panel shows `BiocManager::install("<pkg>")` where the table says a command applies, previous results are unchanged, no enrichment job exists in the registry, and the structured failure is used (a test passes a message that the text classifier would miss).

**AC-023** (REQ-023) Given an install in flight, when the same session presses Run twice for the same package, then the process spy shows one supervisor (a second launch, if any, exits 75); when another session presses Run for a different package, then it shows "waiting for another installation" and launches its own supervisor after the status turns terminal; the starting session's row offers Stop and a watching session's row offers only Dismiss; when Stop is pressed, then SIGTERM goes only to a pid whose `/proc/<pid>/cmdline` contains `annotation-install.sh` (a test with a status file naming an unrelated pid sends no signal, and a test that swaps the pid for an unrelated process before the 45 s escalation sends no SIGKILL), the supervisor's session is gone, staging is removed, the status is `stopped`, the lock is free and the retained request is kept with a Retry action; when Retry is pressed a new supervisor runs and, on success, the retained request runs once; when Dismiss is pressed the request is discarded.

**AC-024** (REQ-024) Given an install in flight, when the browser tab is closed, then the supervisor finishes, the package and its `INSTALLED.tsv` row exist and the lock is free; a new session running the same species then starts its enrichment directly and the fake downloader call log shows no second download; when instead the supervisor is SIGKILLed (the service-restart case), the library is unchanged, the next session reports `interrupted` with the manual command (or "waiting for a previous installer to finish" while an orphaned worker still holds the lock), and its next run removes the staging and installs.

**AC-025** (REQ-025) Given a library that is owned by another user or has mode 0777, or a `RICHSTUDIO_ANNOTATION_LIB` that is relative, contains `..`, is a symlink, or whose last component does not equal the running `r<minor>-bioc<version>`, when a run needs a missing package, then the app shows the warning and the manual command, starts no installer, and `.libPaths()` is identical before and after.

**AC-026** (REQ-026) Given an enrichment run with installed packages (CI), when the project is saved and reloaded through the existing project export and import functions, then `background$annotation$packages` equals the named list of `packageVersion()` values (human GO: `org.Hs.eg.db`; human Reactome with SYMBOL: `reactome.db` and `org.Hs.eg.db`), the top-level manifest keys equal those of a project saved before this change, a project saved before this change reloads without error and without the field, and the existing `test-project-manifest.R` and `test-project-import.R` pass unchanged except for a recorded new-key assertion.

**AC-027** (REQ-027) Given an install and a following enrichment, when compared with before, then the release library directory listing and checksum of the `.Renviron` are unchanged, `.libPaths()` order is unchanged, the existing `test-baseline-result-figures.R` and `test-enrichment-background.R` pass unchanged, and no annotation package is present in the release library.

**AC-028** (REQ-028) Given the M2 deploy on the host, when the lead runs yeast (SYMBOL, GO, `org.Sc.sgd.db`, about 15 MB, not pre-installed) through the live browser, then the row shows installing and then done, the enrichment completes with result rows, `INSTALLED.tsv` on the host has an `org.Sc.sgd.db` row with version and sha256, and `stat -c '%U' <lib>/org.Sc.sgd.db` prints `juhur`; the lead records the commands and outputs in `docs/quality/ws014-m2-record.md`.

**AC-029** (REQ-029) Given a running app whose worker already ran an enrichment, when a package is installed and a new enrichment for it starts, then it succeeds without restarting the app or recreating the future plan, and `future::value(future::future(find.package("<pkg>")))` returns a path under the annotation library.

**AC-030** (REQ-030) Given status files and resolver results for every rule of the Runtime flow table (unit test with a fixed clock and a pid seam), when the session logic evaluates them, then exactly the first matching rule applies and its action results: a package present beats any status (including a status of another token that is `failed`); a status carrying another token and `running` gives "waiting" and, once it turns terminal with the package still missing, exactly one further launch; a dead pid with the lock held gives "waiting for a previous installer" and with the lock free gives `interrupted`; over 100 polls (200 s of fixed clock) with a launcher spy whose launch writes no status the spy records exactly one launch and rule 9 fails the request at 15 s; two sessions racing on the same package end with one installed package and no failure shown to the loser; the observer uses `invalidateLater(2000)` and creates no future and no sleep (spy on the future seam and `Sys.sleep`).

### M1 (added in v0.3.2)

**AC-031** (REQ-031) Given `reactome.db` installed and not attached (CI with a spy builder, host with the real package), when richStudio builds a Reactome annotation, then the spy sees `"package:reactome.db" %in% search()` at call time and the host build succeeds for each of human, mouse, rat, zebrafish and celegans with counts at or above the Reactome floors; a regression guard shows the raw `richR::buildAnnot(anntype = "Reactome")` without the attach fails with "object 'reactomePATHNAME2ID' not found" on the host; run inside a `future::multisession` worker as well as the main process; with `reactome.db` not installed the existing missing-package message is raised and nothing is attached.

**AC-032** (REQ-032) Given the one builder (CI with a spy for `richR::buildAnnot` and `readRDS`), when the same annotation is requested repeatedly, then the first request returns `cache_source = built` and writes the disk entry; the second request in the same process returns `memory` with no build and no read; a fresh worker process returns `disk` with one read and no build; with 4 distinct keys the first is evicted from memory (LRU of 3) yet returns `disk`; `annotation_cache_stats()` counters and the one log line per lookup agree with these sources. On the host: the timed interval is the existing job record's start to finished timestamps of the **second** human GO analysis run in the same persistent worker (the first run was served from the disk cache or a build, whichever the state was, and is recorded), and that interval is at most 20 s (baseline about 91 s, B18); the deploy record lists both intervals and the stats.

**AC-033** (REQ-033) Given planted cache files (CI), when each is requested, then a truncated file, a file of the wrong class, a file with zero rows, a file with missing columns and a file whose stored key differs from its name are each read, rejected, rebuilt and replaced by a valid file with the analysis succeeding; a process killed during a write leaves no partially readable entry (only an ignored `.tmp-*` file); two processes building the same key at once both succeed and leave one valid file.

**AC-034** (REQ-034) Given the cache (CI), when `RICHSTUDIO_ANNOTATION_LIB` is unset, then no cache directory is created and the builder runs on each request; when the cache directory is unwritable, no error occurs and the builder runs; when the cache directory or any parent up to the annotation parent is a symlink, is owned by another user, or the cache directory is not mode 0700 or a parent is group- or world-writable, then the call builds, reads and writes nothing on disk and `annotation_cache_stats()` counts it as disabled; a file outside the cache directory, a file inside it whose name is outside the hashed pattern, and a symlink inside it named like a valid entry are never read (a read spy and a canary target prove it); a matching file with a wrong key is read, rejected and replaced (AC-033); setting an environment variable or option cannot inject a builder; a stubbed builder (internal argument) neither reads nor writes any file under the cache directory (directory listing and mtimes unchanged) and its result is never returned for a real request.

**AC-035** (REQ-035) Given a cached annotation (CI with version and `RemoteSha` seams), when each component of the key changes in turn (schema version, R minor, species, keytype, anntype, the richR version, the richR `RemoteSha`, the bioAnno version, the bioAnno `RemoteSha`, the AnnotationDbi version, the organism package version, the GO.db version for GO, and the `reactome.db` version for Reactome), then each change is a miss and a rebuild, a GO.db change does not affect a KEGG key, and an unchanged key is a hit.

**AC-036** (REQ-036) Given the deploy verification on the host, when it pre-warms the 15 entries (GO, KEGG, Reactome for five species) through the one builder, then a second pass returns `memory` or `disk` for all 15 with the `built` count unchanged in `annotation_cache_stats()`, and the run exits non-zero if any second-pass entry is `built`; after the swap the smoke asserts a hit for human GO; a unit test shows that library plus cache size above the cap stops an install with `not_enough_disk`; the deploy record lists the cache directory size (`du -sk`), the build and hit times, and the resident set size of the worker processes after the pre-warm.

**AC-037** (REQ-037) Given the app (CI with spies for `richR::buildAnnot` and `attachNamespace`), when the custom-background check job (`enrichment_background_check_job` with the builder from `R/enrich_tab.R`) and the enrichment run (`shiny_enrich`, `run_enrichment_jobs`) each need the same annotation, then both call the one richStudio builder, both attach `reactome.db` before a Reactome build, the first returns `built` and the second `memory` or `disk` with `richR::buildAnnot` called once in total; grepping the app sources for a direct `richR::buildAnnot` default shows none outside `R/annotation_cache.R`.

**AC-038** (REQ-038) Given a cache directory (CI) with 199 entries and then written to repeatedly, when a write brings it above 200 entries or above 1 GiB (sizes shortened through a seam), then the oldest-mtime entries are removed until both bounds hold, the entry just written survives, `annotation_cache_stats()` counts the evictions, and `.tmp-*` files older than one hour are removed while a younger one is kept.

## Test plan

- **Unit and integration (CI, no internet):** `tests/testthat/test-annotation-packages.R`, `tests/testthat/test-annotation-cache.R` (AC-031 .. AC-038 with spy builders and version seams) with `helper-annotation-repo.R` (local repository of tiny source packages named from the alternate allowlist, `PACKAGES` with `MD5sum`) and the fake downloader; process, shortened-limit clock and free-space seams are the test-transport seams above, never reachable from production code paths (AC-010).
- **Installer and deploy (CI):** `scripts/test-annotation-library.py` drives `annotation-install.R` as real child processes for AC-004 .. AC-009 and AC-015; `scripts/test-deploy-recovery.py` extended for AC-011, AC-013, AC-016.
- **E2E (Playwright):** `tests/e2e/annotation-install.spec.ts` against `tests/e2e/annotation-app.R` (stubbed runner and builder, fake downloader) for the M2 UI scenarios (AC-020 .. AC-024, AC-030); follows the local browser gate recorded in the project notes.
- **Host (lead):** AC-001, 003, 008 (committed measurements), 012, 014, 017, 031 (real Reactome), 032 (timing), 036 for M1; AC-028 for M2. Verbatim commands and outputs go into the two record files.
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
| REQ-031 | AC-031 | AC-012 |
| REQ-032 | AC-032 | AC-036, AC-037 |
| REQ-033 | AC-033 | AC-032 |
| REQ-034 | AC-034 | AC-033 |
| REQ-035 | AC-035 | AC-032 |
| REQ-036 | AC-036 | AC-008, AC-012 |
| REQ-037 | AC-037 | AC-031, AC-032 |
| REQ-038 | AC-038 | AC-036 |

Counts: M1 has 25 requirements and 25 scenarios (001..017 and 031..038); M2 has 13 requirements and 13 scenarios (018..030); 38 and 38 in all. The M1 addendum ids 031..038 follow M2 in the document to keep the existing ids stable.

## Security and trust boundary

| Threat | Control |
|---|---|
| Path injection (library or staging path from input) | Library path comes only from the root-written `.Renviron`, validated by the deploy (REQ-015) and re-validated by the app (REQ-025); staging names are `.staging-<allowlisted package>-<token>` created with `dir.create` under the library; no user text enters a path (AC-018, AC-025). |
| Package-name, URL or argument injection | Exact allowlist match plus name regex; the launcher passes validated names only, every argument `shQuote`d, stdin from `/dev/null`; the installer takes package names only and builds URLs itself from the pinned repository constant (AC-018). |
| Concurrent install corruption | Kernel `flock` on a fixed lock file held by the supervisor and inherited by its children; private staging and atomic rename; no entry is ever replaced (AC-004, AC-005). |
| Dead or stuck owner, pid reuse | None needed: the kernel releases the lock when the last holder exits; pid and start-time matching does not exist; the status file's pid is informational and a signal is sent only to a pid verified by `/proc/<pid>/cmdline` (AC-005, AC-023). |
| Partial install, crash, kill | Library holds only validated, renamed packages; leftover staging is removed by the next lock holder; `timeout` signals the whole phase group, the supervisor's trap cleans up on TERM, and an orphan after SIGKILL keeps the lock until it ends (AC-004, AC-005, AC-006). |
| Disk fill | Free-space floor and size cap checked before download (AC-008); the annotation cache is itself bounded to 200 entries and 1 GiB (AC-038). |
| Network failure, slow network, redirect abuse | Per-download, per-install and overall limits; `--proto-redir =https`, `--max-redirs 3`, final-URL host check (AC-006, AC-007). |
| Supply chain | Pinned Bioconductor version in the URL; https only; host check; tarball MD5 from the index required; SHA-256 recorded in `INSTALLED.tsv`. Honest limit: index and tarball share an origin, so this detects corruption and substitution of the tarball, not a compromised repository; per-package pinned hashes are not part of this leaf (OD-9). |
| Privilege | Runs as juhur into a juhur-owned directory; nothing needs root at runtime; the sealed release library is never written; the deploy never gives the directory to root (AC-001, AC-015). |
| Resource abuse through the UI | Only available species resolve; one installer at a time per library; waiting sessions poll a status file and hold no worker (AC-020). |
| Test-only escape hatches | Seams need two environment variables the UI cannot set; absent from the release `.Renviron` and the live process environment; inert without the mode flag (AC-010). |
| Deserialization of cache files | `readRDS` runs only on regular, non-symlink, app-owned files with the hashed-key name pattern inside a real, app-owned, mode-0700 cache directory whose parents are real, app-owned and not group- or world-writable (all checked at run time with `Sys.readlink` and `file.info`); no path comes from a user, a request or a project file; class, columns, rows and stored key are validated after reading and any failure rebuilds; a stubbed builder never touches the disk (AC-034). |
| Cache poisoning or staleness | The key contains every version, and the pinned-commit identity, that shapes the annotation and is re-checked inside the file; a change in any component is a miss; superseded entries age out by the oldest-first bound (AC-035, AC-038). |
| Memory and disk use by the cache | At most 3 entries per worker process in memory (worker RSS recorded after the pre-warm, AC-036); disk at most 200 entries and 1 GiB with oldest-first eviction, counted in the library cap (AC-038). |
| Sandbox surprises | The service sandbox is measured (AC-001) and proven by the live install (AC-028). |

The remediation command is displayed and copied as text and never executed by the app (unchanged from SPEC-WS-013). Gene lists never appear in installer logs or status files.

## Rollout and rollback

- **M1:** the owner runs the sudo command (checklist below). Rollback is the previous release symlink (`scripts/rollback.sh`); the annotation library is additive and unused by an older release. Rolling back to the pre-M1 release `141e095` **restores the "package not installed" failure** (it has no annotation library in its `.Renviron`); a rollback is a safety exit, not a fix, and the record says so (D20). Removing the library is optional and manual, after the old release is retired.
- **M2:** a normal release deploy; the app finds the library through the `.Renviron` M1 wrote. Rolling back to an M1 release disables runtime install and leaves installed packages usable.
- **Project format:** frozen. M2 adds one optional nested value inside the already-persisted background record (`annotation$packages`); no manifest top-level key, route or stored-data change; projects saved before and after open in every state (AC-026). `docs/PROJECT_FORMAT.md` gets one paragraph.

## Owner-run deployment checklists

The owner runs only the sudo command; the lead stages scripts and verifies on the host (scp, `sha256sum` on both ends, `bash -n`; each non-sudo line rehearsed on the host first; the record notes which lines were rehearsed and which are exercisable only under sudo).

### M1

1. (lead, before merge, host, juhur) The measurements of B14-B18 are done (installed sizes, `buildAnnot` counts, fixture, cache timings); remaining before merge: record `command -v setsid flock timeout curl`, `bash --version` (>= 5.1) and `systemctl show shiny-server -p User -p ProtectHome -p ReadWritePaths -p ReadOnlyPaths -p KillMode`, confirm the committed `inst_mb` values, floors and the fixture expectation (`GO:0097193`, at least 149 rows) against the tree to be merged (AC-001, 008, 012). The developer commits `inst_mb` and the floors from B14 and B15.
2. (lead) Merge M1 to `main`; record the 40-character release SHA.
3. (lead, host, juhur) Stage `scripts/deploy-r46-release.sh`; print `R --version` (expect 4.6.x) and the Bioconductor version (expect 3.23); `bash -n`.
4. (lead, host, juhur) Rehearse `bash scripts/deploy-r46-release.sh --preflight --release-sha <sha>`; expect `PREFLIGHT PASS`, the per-species counts, the fixture rows and the 15-entry cache pre-warm with its second-pass hits (AC-012, AC-014, AC-036).
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
| OD-3 | Time limits | Owner changed: 1200 s per download, 1200 s per install, 2400 s per package (deploy-level bound N x 2400 s, outside the web path). The 120 s stale-owner grace of v0.2.0 is removed with the lock redesign (the kernel lock needs no liveness rule); a 30 s TERM-to-KILL grace remains. |
| OD-4 | No `MD5sum` in the index | Accepted: fail closed |
| OD-5 | Disk cap and floor | Accepted, formula fixed: floor 2 GiB free; cap = `max(5 GiB, 2 x sum(inst_mb of available rows))` = 7468.4 MB from the measured 3734.2 MB; the annotation cache counts toward it |
| OD-6 | Dropdown for uninstalled species | Accepted: all available species selectable with an "installs on first use (about N MB)" hint from `est_mb`; unavailable species are not offered |
| OD-7 | One implementation or two | Accepted as written, settled by OD-11 |
| OD-8 | `sco` | Accepted: unavailable; mapping it is a separate fix (richR has no `sco` key; `org.Sco.eg.db` is not in the 3.23 index anyway) |
| OD-9 | Pinned hashes per package | Accepted: not in this leaf |
| OD-10 | Pre-install set | Owner changed: human, mouse, rat, zebrafish, celegans and `reactome.db` (651 MB compressed); verification builds GO for the five species plus Reactome for the five |
| OD-11 | Detached installer: one shared implementation | Accepted by the lead. Implemented as a bash supervisor plus a base-R worker in `inst/annotation/`, used by deploy and app; no R rewrite. |
| OD-12 | Verification cost | Resolved by measurement (B15): Reactome builds take 1-5 s; GO builds take 15.8-85.5 s, which the cache pre-warm (REQ-036) pays once at deploy time instead of at the first user's analysis. |
| OD-13 | Administrative Stop of an install owned by another session | Open, recommended default: out of scope for the app; the host owner stops it with `pkill -TERM -f annotation-install.sh` (documented in `docs/DEPENDENCY_DEPLOYMENT.md`); only the owning session gets Stop in the UI. |

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

- 2026-11-06 (v0.3.3): Patch for plan-audit iteration 4 (D49-D58): one builder `richstudio_build_annotation` as the default on every annotation path incl. the background check (REQ-037/AC-037, `R/enrich_tab.R` default and `R/deg_enrich.R` defaults in M1 ownership); full key (GO.db, AnnotationDbi, RemoteSha, R minor); consistent deserialization controls with symlink, parent-chain and stub-bypass rules; disk cache bound with eviction (REQ-038/AC-038); observable `cache_source`, stats and log line; measured-interval definition for AC-032; hash named (`tools::md5sum`); `GO:0097193` among the top five; RSS recorded; the 7468.4 MB literal removed from REQ-008. 38 requirements and 38 scenarios.
- 2026-11-06 (v0.3.2): Added lead host measurements (B14-B18), concrete floors, fixture expectation `GO:0097193`, OD-12 resolved; Reactome attach requirement (REQ-031, richR 0.1.6 defect B16); owner-decided two-level annotation cache in M1 (REQ-032..036, AC-031..036) with files `R/annotation_cache.R`, `tests/testthat/test-annotation-cache.R` and `R/deg_enrich.R` added to M1 ownership. 36 requirements and 36 scenarios.
- 2026-11-06 (v0.3.1): Patch for plan-audit iteration 3 (PASS-WITH-DEBT 0.89, D35-D43): whole-session kill versus supervisor-driven process-group signal stated; vacuous `pgrep` fixed; strict first-match session table with token ownership and bounded launch; `wait -n -p` heartbeat; token-owned Stop with pid re-verification before every signal; per-package deadline and deploy bound; supervisor ordering (trap first, 127 for a missing tool), exit-code edge cases, `shQuote` launch; known gap recorded (pattern not rehearsed before this SPEC). Counts unchanged: 30 requirements, 30 scenarios.
- 2026-11-06 (v0.3.0): Revision after plan-audit iteration 2 (FAIL 0.83, D21-D34). Kernel `flock` lock replaces the mkdir/tombstone lock; a bash supervisor owns signals, pids, exit codes, heartbeat and status; the base-R worker keeps the package logic; status-file contract and session state table added (REQ-030, AC-030); reason codes `internal_error` and `interrupted` added; sweep rule simplified (leftover staging removed by the next lock holder); id convention stated; OD-11 accepted. 30 requirements and 30 scenarios (M1 001-017, M2 018-030).
- 2026-11-06 (v0.2.0): Revision after plan-audit iteration 1 (FAIL, D1-D20) and owner decisions of 2026-11-06 (OD-3 limits doubled; OD-10 pre-install set extended). Added lead-measured Bioconductor index sizes and the host R 4.6.2 fact; detached installer and rename-takeover lock; real-environment verification and post-swap smoke; test transport and gated seams; additive provenance field; live acceptances AC-017 and AC-028; per-REQ primary scenarios; floors and cap fixed by data files; allowlist `status`, `est_mb` and `reactome_supported` columns. 29 requirements and 29 scenarios (M1 001-017, M2 018-029).
- 2026-11-06 (v0.1.0): Planning-only draft authored after the lead's live measurements of 2026-11-06 and source reading of the deploy script, richR 0.1.6 and the job code.
