---
id: "SPEC-WS-014"
title: "Species annotation packages: deploy-time library and guarded runtime install"
version: "0.1.0"
status: draft
created: "2026-11-06"
updated: "2026-11-06"
author: "workspace planning team"
priority: P0
phase: "v0.1.7 target"
module: "R/, scripts/"
lifecycle: spec-anchored
tier: L
tags: "deployment, annotation, enrichment, reproducibility, security"
---

# SPEC-WS-014 — Species annotation packages: deploy-time library and guarded runtime install

Planning-only draft (Tier L; this single leaf document carries the design, research and implementation contract, so no separate design.md or research.md exists). No implementation or test completion is claimed. Companion umbrella: [SPEC-WORKSPACE-001](SPEC-WORKSPACE-001/plan.md). Related: [SPEC-WS-013](SPEC-WS-013.md) (the "Copy command" panel and environment-failure classification this leaf builds on, M2 / AC-010), [SPEC-WS-005](SPEC-WS-005.md) (annotation provenance and the universe definition).

## Problem and observable outcome

Live richStudio (release `141e095`, host hurlab) cannot run a new human GO enrichment: the run fails with "Package 'org.Hs.eg.db' is not installed". The sealed, root-owned release library does not contain the organism annotation packages, because the deploy script installs only what the DESCRIPTION files declare and no DESCRIPTION declares them. The deploy preflight never builds a real annotation, so it passed while analysis was broken.

After this leaf:

- **M1 (restore analysis, then redeploy):** a persistent annotation library, separate from the sealed release library, exists on the host with human, mouse, rat and Reactome annotation pre-installed; every release finds it through its `.Renviron`; the preflight builds a real annotation for each pre-installed species and runs one tiny real enrichment, and fails closed when any of that fails.
- **M2 (no more manual installs):** when a user runs an enrichment for an allowlisted species whose package is not yet installed, the app installs it in the background from the pinned Bioconductor release, shows an "installing annotation" state, continues the analysis automatically on success, and on failure shows the reason and the manual command. The installed package name and version are recorded in the result provenance.

## Measured baseline

All items below were measured by the lead on 2026-11-06 unless marked otherwise. Items marked **(source read)** were read from source by the SPEC author on 2026-11-06 and not executed; they are hypotheses until a milestone check runs them.

| # | Fact | Source |
|---|---|---|
| B1 | Release `141e095` runs on host hurlab with R 4.6.2 and Bioconductor 3.23. | lead, host |
| B2 | A live browser run of 20 human SYMBOLs failed with: "Package 'org.Hs.eg.db' is not installed. Install it in R with: BiocManager::install('org.Hs.eg.db')". | lead, live browser |
| B3 | The release library `/opt/richStudio/releases/<release>/renv/library/release-r46` (root-owned, sealed; set by the release `.Renviron` `R_LIBS_USER`; `.Rprofile` sources `renv/activate.R`) lacks `org.Hs.eg.db`, `org.Mm.eg.db`, `org.Rn.eg.db` and `reactome.db`; `GO.db` and `KEGGREST` are present. | lead, host |
| B4 | `richR::buildAnnot(species = "human", keytype = "SYMBOL", anntype = "GO")` fails in that library. | lead, host |
| B5 | `scripts/deploy-r46-release.sh` (about lines 140-175) installs only Depends/Imports/LinkingTo of the richR, bioAnno, richCluster and richStudio DESCRIPTIONs. No DESCRIPTION declares an organism package; only the manual helper `install_dependencies.R` (lines 79-87) lists `org.Hs.eg.db` and `org.Mm.eg.db`. | lead; re-read by author |
| B6 | `--preflight` (runs as juhur, changes nothing live) never builds a real annotation, so it PASSed while analysis was broken. The old R 4.3 library `/home/shiny/R/x86_64-pc-linux-gnu-library/4.3` had `org.Hs.eg.db`; it was lost in the R 4.6 move. | lead |
| B7 | Shiny Server: `location /richStudio` has `app_dir /home/juhur/shinyapps/richStudio` (symlink to the release) and `run_as juhur`. The app process runs as juhur; the full deploy runs under sudo (root). The Bioconductor 3.23 annotation repository is reachable from the host (HTTP 200). | lead, host |
| B8 | The Enrich species dropdown (`R/enrich_tab.R`, about lines 185-222) offers 20 species: human, mouse, rat, zebrafish, fly, celegans, yeast, chicken, bovine, pig, canine, xenopus, rhesus, arabidopsis, anopheles, ecoli, malaria, chipm, toxoplasma, sco. | lead; re-read by author |
| B9 | **(source read)** richR 0.1.6 maps species to an organism package in `.species_table()` (`R/species.R`): anopheles `org.Ag.eg.db`, arabidopsis `org.At.tair.db`, bovine `org.Bt.eg.db`, celegans `org.Ce.eg.db`, canine `org.Cf.eg.db`, chicken `org.Gg.eg.db`, chipm `org.Pt.eg.db`, ecoli `org.EcK12.eg.db`, ecsakai `org.EcSakai.eg.db`, fly `org.Dm.eg.db`, human `org.Hs.eg.db`, malaria `org.Pf.plasmo.db`, mouse `org.Mm.eg.db`, pig `org.Ss.eg.db`, rat `org.Rn.eg.db`, rhesus `org.Mmu.eg.db`, streptomyces `org.Sco.eg.db`, toxoplasma `org.Tgondii.eg.db`, xenopus `org.Xl.eg.db`, yeast `org.Sc.sgd.db`, zebrafish `org.Dr.eg.db`. | richR v0.1.6 sources |
| B10 | **(source read)** The dropdown value `sco` is not a key of that table (the key is `streptomyces`), so `.getdbname("sco")` stops with "database error!" regardless of installed packages. `ecsakai` is in the table but not in the dropdown. | richR `R/species.R`, `R/enrich_tab.R` |
| B11 | **(source read)** `buildAnnot` needs: GO and KEGG (builtin) -> the organism package, loaded with `requireNamespace(dbname)` at call time in the worker; KEGG live / KEGGM -> `KEGGREST` (network); Reactome -> `reactome.db` and, when the keytype is not ENTREZID, `idconvert()` (organism package) as well. The missing-package message is `Package '<pkg>' is required. Install it with: BiocManager::install('<pkg>')` (GO/KEGG) or `... Install it with:\n  BiocManager::install('reactome.db')`. | richR `R/makeAnnot.R` |
| B12 | **(source read)** `scripts/deploy-r46-release.sh` pins `EXPECTED_R="4.6.1"` (line 25) and fails with "server R is not 4.6.1" when `R --version` differs (line 106), while B1 measured R 4.6.2. If both hold the committed script refuses to run on the host; M1 resolves this first (AC-WS-014-009). | script lines 25, 106 |
| B13 | The app already classifies a missing-package failure and shows the install command in a "Copy command" panel (`R/workspace_jobs.R`: `workspace_jobs_is_missing_package`, `workspace_jobs_environment_failure`; test `tests/testthat/test-workspace-jobs.R`, AC-010 block, about lines 2800-2815). Analysis runs as background futures (`workspace_jobs_future`, `R/workspace_jobs.R` line 16; call sites `R/enrich_tab.R` lines ~1281, ~1468, `R/cluster_tab.R` line ~546; worker `run_enrichment_jobs`, `R/deg_enrich.R` line 71). | author, source |

Not measured, therefore not assumed: on-disk size of `reactome.db` and of each organism package; download time from the host; whether Bioconductor `PACKAGES` serves an `MD5sum` field for every allowlisted package. M1 measures all three before the disk cap (OD-5) is fixed (AC-WS-014-008).

## Recorded owner decisions (binding)

| ID | Decision |
|---|---|
| D1 | Missing species annotation is installed automatically at runtime, with the safeguards below (owner's explicit choice over deploy-only). |
| D2 | Two milestones: M1 restores live analysis and is redeployed first; M2 follows. |
| D3 | A persistent annotation library, separate from the sealed release library, per R minor and Bioconductor version; appended after the release library so release packages always win; allowlist only (fixed species -> package table, no user-controlled package names); installs only from the pinned Bioconductor version's official repositories over https. |
| D4 | Runtime install runs in the background on the existing job/future infrastructure, single-flight across R processes through a lock file, with a timeout; the UI shows an "installing annotation" state; on success the analysis continues automatically; on failure the reason and the manual command are shown; installed package name and version are recorded in result provenance. |
| D5 | M1 deploy creates and validates the annotation library and pre-installs `org.Hs.eg.db`, `org.Mm.eg.db`, `org.Rn.eg.db` and `reactome.db`. |
| D6 | The preflight builds a real annotation for each pre-installed species (and Reactome) and runs one tiny real enrichment, failing closed. |

## Design

### Annotation library location and search order

- Path (OD-1): `/home/juhur/.local/share/richStudio/annotation/r<R minor>-bioc<Bioc version>` (today `r4.6-bioc3.23`). Reason: the app runs as juhur (B7), so the path is writable without privilege; it lives outside every release directory, so release switches and rollbacks never touch it; the R-minor and Bioconductor-version segments mean a later R or Bioconductor upgrade starts an empty, ABI-consistent library instead of mixing builds. The deploy creates it as juhur, mode 0755, never under `/opt/richStudio/releases`.
- The path is never derived from request, upload, URL or session input. The deploy writes it once as `RICHSTUDIO_ANNOTATION_LIB` in the release `.Renviron`, and the app accepts it only if it is absolute, has no `..`, is not a symlink, is owned by the running user, is not group/world-writable, and its final two path segments match the running R minor and the pinned Bioconductor version.
- Search order: the release `.Renviron` sets `R_LIBS_USER=<release lib>:<annotation lib>`, so release packages always win and future workers (which inherit the environment) see the same order. The app additionally verifies at startup that the release lib precedes the annotation lib in `.libPaths()` and never prepends the annotation lib.

### Allowlist

One tracked file, `inst/extdata/annotation-allowlist.tsv`, is the single source for the deploy and the app. Columns: `species`, `package`, `kind` (`organism` or `reactome`), `preinstall` (`yes` for human, mouse, rat and `reactome.db`), `bioc_repo` (`data/annotation`). It is derived from the richR 0.1.6 species table (B9) and restricted to species the dropdown can actually select (B10). A unit test asserts every dropdown value either maps to an allowlisted package or is explicitly marked unavailable, and that the file matches the pinned richR table. A package name is accepted only by exact match against this table; no name from any user-controlled value is passed to an installer, a shell or a URL.

### Runtime install (M2)

1. When Run is pressed, the observer asks a pure function which packages the run needs (organism package for GO/KEGG-builtin; `reactome.db` plus the organism package for Reactome with a non-ENTREZID keytype; `KEGGREST` is never installed at runtime, it is a release dependency) and which are missing (checked against `.libPaths()`, no package loading).
2. If none is missing, the run starts exactly as today.
3. If a needed package is not allowlisted, the run is refused up front with the existing "Copy command" panel and an "unsupported species" message; nothing is installed.
4. If an allowlisted package is missing, the app enqueues an **annotation-install job** through `workspace_jobs_future` (job kind label "Install annotation"), stores the already-reviewed run request (the SPEC-WS-004 review snapshot taken at Run), and shows the "installing annotation" state. On job success the stored request starts automatically as the normal enrichment job; inputs are not re-read, so nothing drifts. On failure the stored request is discarded, previous results stay unchanged, and the failure notification names the reason and the manual `BiocManager::install(...)` command.
5. The install job: acquires the single-flight lock; re-checks whether the package appeared meanwhile (another session installed it) and finishes successfully if so; checks free space and the library size cap; resolves the package and version from the pinned `https://bioconductor.org/packages/<Bioc version>/data/annotation` repository index; downloads the source tarball over https to a private temporary directory; compares the MD5 against the `MD5sum` field of the index when present (otherwise fails closed unless OD-4 says otherwise); installs with `R CMD INSTALL --library=<private staging dir>` in a child process with a timeout; verifies the installed `DESCRIPTION` (`Package`, `Version`, `Built` R minor) and loads the namespace in a child process; then moves the finished package directory into the annotation library with an atomic same-filesystem rename; releases the lock; removes the staging directory on every path.
6. Dependencies of the allowlisted packages must already be present (`AnnotationDbi` etc. are release dependencies). A missing dependency fails closed with the manual command; the installer never installs a package that is not in the allowlist.
7. Single-flight: the lock is a directory created with an atomic `dir.create` (no new package dependency) holding `owner` (pid, host, start time) and a heartbeat file touched while the install runs. A waiter polls until the lock is released or its own wait timeout ends; it takes over only when the holder's heartbeat is older than the stale limit and the holder pid is not alive. Two sessions requesting the same package produce one download.
8. Timeouts (OD-3): per-download and per-install limits, and one overall limit for the job; on expiry the child process is killed, the staging directory is removed, the lock is released, and the failure message says "timed out" with the manual command.
9. Provenance: the result records `annotation_packages` as name, version and `Built` R minor of every annotation package the run used (read from the loaded `Annot` metadata the richR 0.1.6 `buildAnnot` already attaches: `provider_package`, `provider_version`), and the install job record keeps the downloaded tarball SHA-256 and the index MD5 it matched.

### Deploy and preflight (M1)

- `scripts/deploy-r46-release.sh` gains an idempotent `ensure_annotation_library` step: create the directory as `$APP_USER` (0755, not root-owned), take the same lock the app uses, install any allowlisted `preinstall=yes` package that is absent using the same verified-download procedure as runtime install (MD5 check, private staging, atomic rename), record `INSTALLED.tsv` (package, version, sha256, time) in the library, and verify.
- The release `.Renviron` becomes `R_LIBS_USER=<release lib>:<annotation lib>` plus `RICHSTUDIO_ANNOTATION_LIB=<annotation lib>`; the staged `.Renviron` is still written by the existing finalize step and the "release already contains a .Renviron" guard is kept.
- `verify_release` is extended (it already runs on the build dir and again on the finalized release at its final path, before the symlink swap), so a release that cannot analyze never gets live:
  1. every `preinstall` package loads from the annotation library and is built for R 4.6 and not from any path outside the two libraries;
  2. `richR::buildAnnot(species, "SYMBOL", "GO")` and `"KEGG"` (builtin, no network) succeed for human, mouse and rat with at least the minimum numbers of genes and terms fixed in AC-WS-014-003; `buildAnnot(..., "Reactome")` likewise;
  3. one tiny real enrichment: `richGO` on a fixed list of 20 human SYMBOLs shipped as a fixture returns at least one term at the documented cutoff;
  4. the release lib precedes the annotation lib in `.libPaths()`; no annotation package is found in the release lib;
  5. the staged `.Renviron` contains the two variables and does not contain `RICHSTUDIO_ANNOTATION_ALLOW_FILE_REPO`.
- `--preflight` (juhur, no sudo, touches nothing live) runs the same checks against a scratch annotation library under its own work root, so it proves the whole path without mutating the live library. The full deploy runs them against the live library. Any failure prints the failed check and exits non-zero (`fail`), before the symlink swap.

## Dependencies and ownership

- Logical prerequisites: SPEC-WS-013 merged to `main` (done, `141e095` plus PR #3 fix `fcf91c8`). No dependency on SPEC-WS-004/005/006 internals beyond reading the review snapshot and result provenance fields.
- One disposable implementer owns this entire leaf in its own fresh worktree; each milestone is independently reviewed, merged and CI-verified before the next milestone starts. M1 is deployed by the owner-run checklist below before M2 starts.
- Shared targets are exclusive locks, even for nonoverlapping line edits.
- No `DESCRIPTION`, `NAMESPACE` or `renv.lock` change is planned: the installer uses base R (`utils`, `tools`, `system2(timeout=)`). A new package dependency is a dependency decision requiring a registry revision, not an implementer choice.
- Upstream richR work is separately owned; this leaf does not adopt richR 0.2.0 and does not edit richR.

### M1 file ownership (deploy and preflight)

Existing: `scripts/deploy-r46-release.sh`, `docs/DEPENDENCY_DEPLOYMENT.md`, `install_dependencies.R` (organism packages comment/list only), `scripts/test-deploy-recovery.py` (extend for the new steps; no assertion weakened).

New: `inst/extdata/annotation-allowlist.tsv`, `scripts/annotation-library.R` (base-R install, verify and lock routines shared by deploy steps and, in M2, wrapped by the package), `tests/fixtures/annotation/human-query-20.tsv`, `scripts/test-annotation-library.py` (shell-level tests with a fake local repository), `docs/quality/ws014-m1-deploy-record.md`.

### M2 file ownership (runtime install)

Existing: `R/enrich_tab.R` (Run observer, species dropdown availability), `R/workspace_jobs.R` (job kind, state label, failure text, continuation hook), `R/deg_enrich.R` (provenance of annotation packages only; no change to cutoffs or statistics), `scripts/annotation-library.R` (reduced to a thin wrapper over the package function, OD-7), `scripts/deploy-r46-release.sh` (call the package function), `docs/DEPENDENCY_DEPLOYMENT.md`, `docs/PROJECT_FORMAT.md` (only if a provenance field is added to the saved project; otherwise untouched).

New: `R/annotation_packages.R` (allowlist reader, need/missing resolver, lock, verified install, provenance), `tests/testthat/test-annotation-packages.R`, `tests/testthat/helper-annotation-repo.R` (builds a tiny local source repository with `PACKAGES` and `MD5sum`), `tests/e2e/annotation-install.spec.ts`, `docs/quality/ws014-m2-record.md`.

Existing test files change only where a changed label or id requires it; no assertion is weakened.

## Milestones

| Milestone | Scope | Target files | Acceptance |
|---|---|---|---|
| M1 Deploy-time annotation library and real preflight | R version constant reconciled (B12); annotation library created and validated; four packages pre-installed; `.Renviron` extended; `verify_release` and `--preflight` build real annotations and run one tiny enrichment; owner redeploys | M1 files above | AC-WS-014-001 .. 009 |
| M2 Guarded runtime install | allowlist reader, need resolver, single-flight verified background install, "installing annotation" state, auto-continue, failure panel, provenance | M2 files above | AC-WS-014-010 .. 024 |

## GEARS requirements

### M1

- **REQ-WS-014-001** The deploy shall create and validate a persistent annotation library outside every release directory, owned by the app user, per R minor and Bioconductor version, and shall never place it where a release switch or rollback removes it.
- **REQ-WS-014-002** The release `.Renviron` shall list the release library before the annotation library in `R_LIBS_USER`, and shall set `RICHSTUDIO_ANNOTATION_LIB` to the annotation library path.
- **REQ-WS-014-003** The deploy shall pre-install `org.Hs.eg.db`, `org.Mm.eg.db`, `org.Rn.eg.db` and `reactome.db` into the annotation library from the pinned Bioconductor version's official repository over https, verifying each tarball against the repository-published MD5 before installing.
- **REQ-WS-014-004** The deploy installation procedure shall use a private staging directory and an atomic rename into the library, shall take the single-flight lock, and shall leave no partial package or staging directory behind after success or failure.
- **REQ-WS-014-005** When the release is verified (build directory, preflight and the finalized release at its final path), the verification shall build a real GO and builtin KEGG annotation for human, mouse and rat, a Reactome annotation for the same species, and shall run one real enrichment on a fixed human SYMBOL fixture; any failure shall stop the deploy before the symlink swap.
- **REQ-WS-014-006** The `--preflight` mode shall run the same checks against a scratch annotation library under its own work root and shall not modify the live annotation library, the live symlink, or the server configuration.
- **REQ-WS-014-007** While the deploy runs, an annotation package found in the sealed release library, a package not built for R 4.6, or an annotation library whose ownership or mode differs from the validated one shall fail the deploy.
- **REQ-WS-014-008** The deploy shall read the pinned R version and Bioconductor version from one place and shall reject a host whose measured R minor or Bioconductor version differs from the pin, naming both values.
- **REQ-WS-014-009** The deploy shall record, for each annotation package, its name, version, tarball SHA-256, repository MD5 and install time in `INSTALLED.tsv` inside the annotation library.

### M2

- **REQ-WS-014-010** When the Run button is pressed for a species whose needed annotation package is missing and allowlisted, the app shall install it in the background and shall start the already-reviewed enrichment automatically when the install succeeds.
- **REQ-WS-014-011** The set of installable packages shall be exactly the rows of the tracked allowlist; the app shall pass no value derived from user input (file contents, names, query, URL, session) as a package name, path, URL or command-line argument to any installer.
- **REQ-WS-014-012** The app shall download only over https from the official Bioconductor repository of the pinned version, shall refuse any other scheme or host, and shall verify the tarball against the repository-published MD5 before installing; a missing or mismatching MD5 shall fail the install.
- **REQ-WS-014-013** The app shall install into a private staging directory and move the finished package into the annotation library by atomic rename only after the installed `DESCRIPTION` and a namespace load in a child process succeed; a failure or timeout shall leave the annotation library unchanged.
- **REQ-WS-014-014** While one R process installs a package, another process or session requesting the same package shall wait on the lock, shall not download it again, and shall continue when the package is present; a lock whose holder is dead and whose heartbeat is stale shall be taken over.
- **REQ-WS-014-015** The install shall be bounded by a per-download, a per-install and an overall timeout, and by a free-space check and a library-size cap checked before the download; exceeding any bound shall stop the install, kill the child process, remove staging and release the lock.
- **REQ-WS-014-016** While an annotation install is running or queued the workspace shall show an "installing annotation" state naming the package and the species, through the existing job tray and live region, and shall not show it as an analysis failure.
- **REQ-WS-014-017** When an install fails, the app shall show the plain reason (no network, timed out, checksum mismatch, not enough disk space, dependency missing, not allowlisted) and the manual install command in the existing "Copy command" panel, shall keep previous results unchanged, and shall not start the enrichment.
- **REQ-WS-014-018** When a species is not allowlisted or has no organism package (including the dropdown value `sco`, B10), the app shall refuse the run before any job starts with an "unsupported species" message and shall not attempt an install.
- **REQ-WS-014-019** The enrichment result provenance shall record the name, version and built-R minor of each annotation package used.
- **REQ-WS-014-020** The app shall search the annotation library after the release library and shall refuse to use the annotation library when the release library does not precede it or the validated ownership and mode checks fail; it shall never prepend it.
- **REQ-WS-014-021** The installer shall not change the sealed release library, the release `.Renviron`, `.libPaths()` ordering, enrichment cutoffs, background semantics or any statistical result.
- **REQ-WS-014-022** The installer shall never install a package outside the allowlist, including dependencies; a missing dependency shall fail closed with the manual command.
- **REQ-WS-014-023** Where `RICHSTUDIO_ANNOTATION_ALLOW_FILE_REPO=1` is set, the installer shall accept a local `file://` repository for tests; the deploy shall never set it and the preflight shall fail when it is present in the release `.Renviron`.
- **REQ-WS-014-024** A user whose browser session ends during an install shall not interrupt it, and the next session shall find the package installed or the lock released.

## Binary acceptance scenarios

Run on the host or in CI as stated. "CI" scenarios use a local fake Bioconductor-style repository (built by the helper, containing tiny source packages, a `PACKAGES` index and `MD5sum`) so CI needs no internet.

### M1

**AC-WS-014-001** Given a clean host state, when `sudo bash scripts/deploy-r46-release.sh --run-id <token> --release-sha <sha>` completes, then `stat -c '%U %a' /home/juhur/.local/share/richStudio/annotation/r4.6-bioc3.23` prints `juhur 755`, the path is not below `/opt/richStudio`, and `readlink` of the app symlink still points to the new release while the directory persists after `ls` of the previous release and after the symlink is switched back with `scripts/rollback.sh`.

**AC-WS-014-002** Given the finalized release, when `cat <release>/.Renviron` is read, then it contains exactly `R_LIBS_USER=<release>/renv/library/release-r46:/home/juhur/.local/share/richStudio/annotation/r4.6-bioc3.23` and `RICHSTUDIO_ANNOTATION_LIB=<same annotation path>` and, as juhur, `Rscript -e 'print(.libPaths()[1:2])'` run with that `.Renviron` prints the release lib first and the annotation lib second.

**AC-WS-014-003** Given the pre-installed annotation library, when as juhur with the release `.Renviron` `Rscript` runs `buildAnnot(species, "SYMBOL", anntype)` for species human, mouse, rat and anntype GO, KEGG and Reactome, then each call returns without error with at least 10000 distinct genes and 1000 distinct terms for GO, at least 5000 genes and 200 terms for KEGG, and at least 5000 genes and 1000 terms for Reactome (thresholds are fixed at the M1 measurement and recorded in the deploy record), and the `Annot` metadata `provider_package` is the allowlisted package. Evidence: the printed counts per species and anntype.

**AC-WS-014-004** Given the fixture `tests/fixtures/annotation/human-query-20.tsv`, when the verification runs `richR::richGO` through `richStudio:::shiny_enrich` for species human, SYMBOL, GO, ontology BP, then the result has at least one row at adjusted p below 0.05; the same call fails (non-zero exit) when the annotation library is empty, proving the check fails closed.

**AC-WS-014-005** Given a deploy whose annotation library lacks `org.Mm.eg.db`, when `verify_release` runs, then the script prints `ERROR:` naming the species and package and exits non-zero before the symlink swap (`readlink` of the app symlink is unchanged). Evidence: `scripts/test-annotation-library.py` with a fake repository.

**AC-WS-014-006** Given `--preflight` run as juhur without sudo, when it finishes, then the live annotation library's `INSTALLED.tsv` has an unchanged SHA-256, the app symlink target and `/etc/shiny-server/shiny-server.conf` checksums are unchanged, and the scratch annotation library under the preflight work root contains the four pre-install packages.

**AC-WS-014-007** Given a tampered tarball in the fake repository (valid name, changed bytes), when the install step runs, then it exits non-zero with a checksum message, the annotation library has no new directory, and no `.staging-*` directory remains.

**AC-WS-014-008** Given the host, when the M1 measurements run, then the deploy record lists, for each of the four packages, installed size (`du -sk`), tarball size, download seconds and `MD5sum` field presence in the Bioconductor `PACKAGES` index, plus `df -k` free space of the annotation filesystem, and the disk cap in OD-5 is confirmed or revised against those numbers.

**AC-WS-014-009** Given the host R version, when the deploy script starts, then `R --version` and the pinned version are both printed and the script proceeds only when the minor matches; with R 4.6.2 on the host and the pin updated to the measured value in the same commit, `bash scripts/deploy-r46-release.sh --preflight --release-sha <sha>` reaches the verification step (B12).

### M2

**AC-WS-014-010** Given an empty annotation library and an allowlisted species, when Run is pressed in the browser, then the workspace shows an "installing annotation" job row naming the package, and when the install ends the enrichment job starts without another click and the Results page shows rows; e2e asserts the row text before and the result table after.

**AC-WS-014-011** Given an unrelated request, when a test passes the strings `../x`, `org.Hs.eg.db; rm -rf /`, `org.Xx.eg.db`, a URL and an empty string as the species or package, then the resolver returns "unsupported", no child process starts (asserted with a spy on the process seam) and nothing is written below the annotation library.

**AC-WS-014-012** Given repository URLs `http://...`, `ftp://...`, `https://evil.example/...` and `file:///...` without `RICHSTUDIO_ANNOTATION_ALLOW_FILE_REPO`, when the installer validates the repository, then each is rejected with a named reason; `https://bioconductor.org/packages/3.23/data/annotation` is accepted; with the env variable set only `file://` is additionally accepted.

**AC-WS-014-013** Given a fake repository whose `MD5sum` does not match the tarball, or whose `PACKAGES` lacks the field, when the install runs, then it fails with a checksum message and the library is byte-identical before and after (directory listing and `INSTALLED.tsv` hash).

**AC-WS-014-014** Given an install that is killed in the middle (timeout seam forced to 1 second against a slow fake download), when it ends, then the library is unchanged, no `.staging-*` and no lock directory remain, and a following install of the same package succeeds.

**AC-WS-014-015** Given two R processes started together requesting the same missing package, when both finish, then the fake repository's request log shows one tarball download, both processes report the package present, and `INSTALLED.tsv` has one row for it.

**AC-WS-014-016** Given a lock whose owner pid is dead and whose heartbeat is older than the stale limit, when an install starts, then it takes over the lock and installs; given a live owner with a fresh heartbeat, then the waiter does not take over and ends with a timeout message after its wait limit.

**AC-WS-014-017** Given the fake repository set to refuse connections, when the install runs through the app, then the failure notification contains the reason "could not reach the Bioconductor repository" and the exact `BiocManager::install("<pkg>")` command in the Copy command panel, previous results are unchanged, and no enrichment job was started.

**AC-WS-014-018** Given a filesystem with less free space than the configured floor (space check seam returns the floor minus one), or a library whose total size plus the package estimate exceeds the cap, when the install starts, then it stops before any download with a "not enough disk space" reason.

**AC-WS-014-019** Given the dropdown value `sco` and any dropdown value with no allowlist row, when Run is pressed, then the run is refused before any job starts with an "unsupported species" message and the job registry is unchanged.

**AC-WS-014-020** Given an enrichment that used the installed packages, when the result is saved and reloaded, then the provenance lists each annotation package with name, version and built-R minor equal to `packageVersion()` and `packageDescription()$Built` of the loaded packages.

**AC-WS-014-021** Given an annotation library owned by another user or with mode 0777, or a `RICHSTUDIO_ANNOTATION_LIB` that is relative, contains `..`, is a symlink, or has final segments that do not match the running R minor and Bioconductor version, when the app starts, then it does not add the library to the search and the missing-package panel shows the manual command.

**AC-WS-014-022** Given the search order of REQ-WS-014-020, when a package is present in both libraries with different versions, then `find.package` and `packageVersion` resolve to the release library copy.

**AC-WS-014-023** Given an allowlisted package whose dependency is absent in the fake repository, when the install runs, then it fails with "dependency missing" and installs nothing, including the dependency.

**AC-WS-014-024** Given the browser tab is closed during an install, when a second session requests the same package after it ends, then the package is present, the lock directory is absent and no second download is recorded.

## Test plan

- **Unit (CI, no internet):** `tests/testthat/test-annotation-packages.R` with `helper-annotation-repo.R`, which builds a local repository of tiny source packages (valid DESCRIPTION, no compiled code) named by a fixture allowlist, with `PACKAGES` and `MD5sum`. Seams: process runner, clock, free-space function and repository fetcher are injectable (the repo already uses injectable builders: `annotation_builder`, `enrichment_runner`, `workspace_jobs_future`). Cover AC-WS-014-011 .. 016, 018, 019, 021 .. 023.
- **Shell/deploy (CI):** `scripts/test-annotation-library.py` runs the shell-level steps against the fake repository in a temp dir (staging, atomic rename, checksum, lock, no partial state); `bash -n` and a rehearsal of every non-sudo line of the deploy script on the host in M1 (AC-WS-014-005 .. 007).
- **E2E (Playwright):** `tests/e2e/annotation-install.spec.ts` launches the app with the fake repository, an empty temp annotation library and `RICHSTUDIO_ANNOTATION_ALLOW_FILE_REPO=1`; asserts the "installing annotation" row, auto-continue, and the failure panel (AC-WS-014-010, 017, 024). Follows the local browser gate recorded in the project notes (CI-equivalent environment).
- **Server preflight (M1, host):** `--preflight` run as juhur; AC-WS-014-003, 004, 006, 008, 009 evidence pasted into `docs/quality/ws014-m1-deploy-record.md` with the verbatim commands and outputs.
- Full-suite phase gates run in clean CI; local checks are scoped to affected behavior. Verification receipts name the REQ/AC ids and the baseline measured in that run.

## Requirement-to-acceptance traceability

| Requirement | Required scenarios |
|---|---|
| REQ-WS-014-001 | AC-001 |
| REQ-WS-014-002 | AC-002 |
| REQ-WS-014-003 | AC-003, AC-007, AC-008 |
| REQ-WS-014-004 | AC-005, AC-007 |
| REQ-WS-014-005 | AC-003, AC-004, AC-005 |
| REQ-WS-014-006 | AC-006 |
| REQ-WS-014-007 | AC-005, AC-021 |
| REQ-WS-014-008 | AC-009 |
| REQ-WS-014-009 | AC-001, AC-008 |
| REQ-WS-014-010 | AC-010, AC-024 |
| REQ-WS-014-011 | AC-011, AC-019 |
| REQ-WS-014-012 | AC-012, AC-013 |
| REQ-WS-014-013 | AC-013, AC-014 |
| REQ-WS-014-014 | AC-015, AC-016 |
| REQ-WS-014-015 | AC-014, AC-018 |
| REQ-WS-014-016 | AC-010 |
| REQ-WS-014-017 | AC-017 |
| REQ-WS-014-018 | AC-019 |
| REQ-WS-014-019 | AC-020 |
| REQ-WS-014-020 | AC-021, AC-022 |
| REQ-WS-014-021 | AC-022; existing `test-baseline-result-figures.R` and `test-enrichment-background.R` unchanged and passing |
| REQ-WS-014-022 | AC-011, AC-023 |
| REQ-WS-014-023 | AC-012; preflight check of the release `.Renviron` |
| REQ-WS-014-024 | AC-024 |

Counts: M1 has 9 requirements and 9 scenarios; M2 has 15 requirements and 15 scenarios.

## Security and trust boundary

| Threat | Control |
|---|---|
| Path injection (annotation library or staging path built from input) | The path comes only from the root-written `.Renviron`; absolute, no `..`, not a symlink, owned by the app user, mode not group/world-writable, trailing segments match R minor and Bioconductor version (REQ-020, AC-021). Staging names are `.staging-<allowlisted package>-<pid>-<random>` created with `dir.create` under the library; no user text is used in any path. |
| Package-name injection (shell, URL, R code) | Exact-match lookup in the tracked allowlist; installers get arguments as a vector (`system2(args=)`, no shell string); the package name is also matched against `^[A-Za-z][A-Za-z0-9.]*$` before use (AC-011). |
| Concurrent install corruption (two sessions, two processes) | Atomic directory lock with heartbeat, re-check after acquiring, install into private staging and atomic rename; readers never see a half-installed package (AC-014, 015, 016). |
| Partial install (kill, crash, power loss) | Staging is outside the library's package namespace; a crash leaves only a staging directory that the next run removes if stale; the library holds only complete packages (AC-014). |
| Disk fill | Free-space floor and library-size cap checked before download; size recorded per package (AC-018, AC-008). |
| Network failure and slow network | Per-download, per-install and overall timeouts; killed child process; plain failure message plus manual command (AC-014, 017). |
| Supply chain | Pinned Bioconductor version in the repository URL; https only; host and scheme allowlist; tarball MD5 verified against the repository index and SHA-256 recorded locally; missing MD5 fails closed (OD-4). Honest limit: the index and the tarball come from the same origin, so the check detects corruption and tarball substitution but not a compromised repository; the recorded SHA-256 allows later comparison. A signed or pinned hash per package is recorded as OD-9 and is not required by this leaf. |
| Privilege | The app installs as juhur into a juhur-owned directory; nothing needs root at runtime; the sealed release library is never written. The deploy never gives the annotation directory to root. |
| Resource abuse through the UI | Only allowlisted packages for selectable species; one install per package at a time; the job registry's existing per-session concurrency policy applies; no unauthenticated endpoint is added. |
| File repository escape hatch | `RICHSTUDIO_ANNOTATION_ALLOW_FILE_REPO` is test-only, never set by the deploy, and the preflight fails when the release `.Renviron` contains it (REQ-023). |

The remediation command is displayed and copied as text and never executed by the app (unchanged from SPEC-WS-013 AC-010). Sensitive gene lists never appear in installer logs or diagnostics.

## Rollout and rollback

- **M1 deploy:** the owner runs the sudo command; the lead stages the scripts (below). Rollback is the previous release symlink (`scripts/rollback.sh`); the annotation library is additive and is simply unused by an older release. Removing it is optional and manual (`rm -rf` of the version directory, by the owner, after the old release is also retired).
- **M2 deploy:** a normal release deploy; the app finds the library through the `.Renviron` M1 already wrote. Rollback to an M1 release disables runtime install and leaves installed packages in place and usable.
- No project-format, route or stored-data change; projects saved before and after open in every state.

## M1 owner-run deployment checklist

The owner runs only the sudo command; the lead stages scripts and verifies on the host (project rule: stage server scripts with scp and verify on host; owner runs only the sudo step). Each non-sudo line is rehearsed on the host first and the record notes which lines were rehearsed versus only exercisable under sudo.

1. (lead) Merge M1 to `main`; record the 40-character release SHA.
2. (lead, host, juhur) Stage the script: `scp scripts/deploy-r46-release.sh scripts/annotation-library.R` (the allowlist is read from the release checkout at the release SHA); `sha256sum` printed on both ends; `bash -n` passes on the host.
3. (lead, host, juhur) `R --version` and `Rscript -e 'BiocManager::version()'` recorded; confirm they equal the pins (AC-WS-014-009).
4. (lead, host, juhur) Rehearse: `bash scripts/deploy-r46-release.sh --preflight --release-sha <sha>`. Expected: `PREFLIGHT PASS`, the per-species annotation counts of AC-WS-014-003, the enrichment row count of AC-WS-014-004. Paste the output into the deploy record.
5. (lead) Record the M1 measurements (AC-WS-014-008) and confirm the disk cap (OD-5).
6. (owner, plain WSL terminal on the host or via SSH, Tailscale 100.94.67.89, any directory) `sudo bash scripts/deploy-r46-release.sh --run-id <token> --release-sha <sha>`. Reason: creates the release, runs verification against the live annotation library, swaps the symlink and restarts shiny-server. Warning: running it from a laptop shell or without `sudo` aborts with `run the deploy with sudo`; running the preflight flag under sudo is refused.
7. (lead, live browser) Run a human GO enrichment of 20 SYMBOLs (the AC-WS-014-004 fixture) on `/richStudio`; record the result row count and close the browser tabs before stopping the SSH tunnel.
8. (lead) Rollback drill note: `scripts/rollback.sh` target recorded; confirm the annotation directory persists.

## Open decisions (recommended defaults)

| ID | Question | Recommended default | Reason |
|---|---|---|---|
| OD-1 | Exact annotation library path | `/home/juhur/.local/share/richStudio/annotation/r4.6-bioc3.23` | Writable by the app user without privilege; outside releases; versioned by R minor and Bioconductor. Alternative `/var/lib/richStudio/annotation` needs root-created, juhur-owned directory and a separate backup story. |
| OD-2 | Are `reactome.db` and other non-organism packages runtime-installable? | Yes, allowlisted (`kind=reactome`), because a human Reactome run fails the same way | One mechanism; excluded: `KEGGREST` and any package that is a release dependency. |
| OD-3 | Timeouts | Per-download 600 s, per-install 600 s, overall job 1200 s, lock wait 1500 s, stale-lock heartbeat 120 s | Annotation tarballs are data-only; sizes unmeasured, so M1 measures download time and the numbers are revised in the deploy record. |
| OD-4 | When `PACKAGES` has no `MD5sum` for a package | Fail closed | Integrity check is the minimum supply-chain control; relax only by an explicit owner decision. |
| OD-5 | Disk cap and floor | Annotation library at most 5 GiB total and at least 2 GiB free before any install | `reactome.db` and organism sizes are unmeasured (baseline gap); M1 AC-008 fixes the numbers. |
| OD-6 | What the dropdown shows for species not yet installed | Keep all allowlisted species selectable, with a small "will be installed on first use (about N MB)" hint; hide or disable species without an allowlist row (`sco`) with an "unavailable" note | Matches owner decision D1; avoids a hidden failure mode (B10). |
| OD-7 | One implementation or two for the install routine | M1 ships `scripts/annotation-library.R` (base R); M2 moves the logic into `R/annotation_packages.R` and makes the script a thin wrapper, with a test that both read the same allowlist file | M1 must not depend on M2; the end state has one implementation. |
| OD-8 | What to do with dropdown `sco` | Mark unavailable now; mapping `sco` -> `streptomyces`/`org.Sco.eg.db` is a separate small fix | Changing richR's species keys or app values is outside this leaf. |
| OD-9 | Per-package pinned hashes in the allowlist | Not in this leaf | Would freeze versions against Bioconductor patch releases; the recorded SHA-256 in `INSTALLED.tsv` gives later auditability. |
| OD-10 | Pre-install more species (zebrafish, fly, yeast) in M1 | No (owner listed human, mouse, rat, `reactome.db`) | Others install on first use in M2; revisit after install-time measurements. |

## Exclusions

### Out of Scope — Product scope

- Adopting richR 0.2.0, editing richR, changing the species table or the dropdown values beyond marking unavailable ones.
- Any change to analysis cutoffs, background or universe semantics, statistical methods, or result tables.
- Installing arbitrary packages, user-supplied packages, CRAN packages, GitHub packages, or any package not in the allowlist; installing at app start-up or from any request other than Run.
- Live KEGG access (`KEGGREST` network calls) and offline KEGG databases.

### Out of Scope — Technology and format

- New package dependencies (`filelock`, `processx`, `BiocManager` at runtime), an in-app package manager UI, a system-wide shared annotation cache, or root-owned runtime installs.
- Changing the project file format, route identifiers or the job lifecycle rules beyond a new job kind and its state label.
- Migrating R or Bioconductor versions; those start a new annotation library by design.

## HISTORY

- 2026-11-06 (v0.1.0): Planning-only draft authored after the lead's live measurements of 2026-11-06 (human GO enrichment fails, `org.*.eg.db` and `reactome.db` absent from the sealed release library) and source reading of `deploy-r46-release.sh`, richR 0.1.6 `makeAnnot.R`/`species.R` and the job code. Owner decisions D1-D6 recorded; M1 (deploy) and M2 (runtime install) defined.
