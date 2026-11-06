# SPEC-WS-014 M1 deploy record

Species annotation packages: installer, deploy-time annotation library, real-environment verification.

**How this file works.** Every placeholder cell is a host measurement or a host result that only the lead can produce (juhur on hurlab); the placeholder is the upper-case token `PENDING` followed by `-LEAD`. `scripts/test-annotation-library.py` (class `MergeGatePlaceholders`) fails while that token appears anywhere in this file, or in the allowlist `inst_mb` column, so M1 cannot merge unmeasured. Replace each placeholder with the verbatim command output or the measured number. This paragraph deliberately never spells the token as one string.

Developer-side evidence (run locally, no host access) is recorded in the M1 completion report, not here.

## 1. Pre-merge measurements (checklist step 1; lead, host, juhur)

### 1.1 Host tools and service sandbox (AC-001 gap B7, AC-006)

| Item | Command | Result |
|---|---|---|
| Tools present | `command -v setsid flock timeout curl` | PENDING-LEAD |
| bash version (>= 5.1) | `bash --version \| head -1` | PENDING-LEAD |
| GNU timeout version | `timeout --version \| head -1` | PENDING-LEAD |
| shiny-server sandbox | `systemctl show shiny-server -p User -p ProtectHome -p ReadWritePaths -p ReadOnlyPaths -p KillMode` | PENDING-LEAD |
| App user can write the annotation parent | `runuser -u juhur -- bash -c 'f=$(mktemp -p /home/juhur/.local/share/richStudio/annotation/r4.6-bioc3.23) && rm "$f"'; echo $?` (after the deploy, AC-001) | PENDING-LEAD |

### 1.2 Installed sizes, download times, disk (AC-008)

Scratch install of the full allowlist into a temporary library on the host (additive; nothing live is touched). `inst_mb` is `du -sk <lib>/<pkg>` divided by 1024, rounded up, and is what goes into `inst/extdata/annotation-allowlist.tsv`.

| Package | est_mb (index) | du -sk installed (lead-measured 2026-11-06) | inst_mb (committed, as measured) | Seconds (lead-measured install; download time not measured) |
|---|---|---|---|---|
| org.Hs.eg.db | 99 | 398.5 MB | 398.5 | 29.7 (install) |
| org.Mm.eg.db | 89 | 380.7 MB | 380.7 | 27.5 (install) |
| org.Rn.eg.db | 61 | 273.9 MB | 273.9 | 24.0 (install) |
| org.Dr.eg.db | 36 | 140.8 MB | 140.8 | 17.9 (install) |
| org.Ce.eg.db | 20 | 71.5 MB | 71.5 | 15.5 (install) |
| reactome.db | 319 | 1365.4 MB | 1365.4 | 70.1 (install) |
| org.Dm.eg.db | 30 | 109.8 MB | 109.8 | 16.0 (install) |
| org.Sc.sgd.db | 15 | 64.8 MB | 64.8 | 15.0 (install) |
| org.Gg.eg.db | 19 | 68.4 MB | 68.4 | 15.3 (install) |
| org.Bt.eg.db | 22 | 77.9 MB | 77.9 | 15.3 (install) |
| org.Ss.eg.db | 21 | 80.5 MB | 80.5 | 16.1 (install) |
| org.Cf.eg.db | 31 | 123.4 MB | 123.4 | 17.6 (install) |
| org.Xl.eg.db | 26 | 107.0 MB | 107.0 | 16.5 (install) |
| org.Mmu.eg.db | 26 | 100.6 MB | 100.6 | 16.0 (install) |
| org.At.tair.db | 39 | 217.0 MB | 217.0 | 19.9 (install) |
| org.Ag.eg.db | 5 | 12.7 MB | 12.7 | 13.3 (install) |
| org.EcK12.eg.db | 6 | 24.5 MB | 24.5 | 12.7 (install) |
| org.Pf.plasmo.db | 3 | 11.8 MB | 11.8 | 12.4 (install) |
| org.Pt.eg.db | 27 | 105.1 MB | 105.1 | 16.6 (install) |

- Sum of `inst_mb` over the 19 available rows: 3734.2 (lead-measured 2026-11-06; pre-install six = 2630.8); cap = `max(5 GiB, 2 x 3734.2 MiB)` = 7831394714 bytes (the gate test recomputes it with `Rscript inst/annotation/annotation-install.R cap`).
- `df -k` of the annotation filesystem: PENDING-LEAD
- `INSTALLED.tsv` of the scratch library lists all 19 packages: PENDING-LEAD

### 1.3 Floors against real counts (AC-012)

`buildAnnot(species, keytype = "SYMBOL", anntype)` with the pinned richR 0.1.6 in the release library. Each floor must be at most 50% of the measured count (the committed floors are in `inst/extdata/annotation-verify-floors.tsv`; adjust the data file, not the script, if one is wrong).

| species | anntype | floor genes | measured genes | floor terms | measured terms | floors <= 50% | build seconds |
|---|---|---|---|---|---|---|---|
| human | GO | 10000 | 20826 | 10000 | 21344 | yes (lead-measured 2026-11-06) | 85.5 |
| mouse | GO | 13000 | 26322 | 11000 | 22180 | yes (lead-measured 2026-11-06) | 61.6 |
| rat | GO | 11000 | 23756 | 11000 | 22067 | yes (lead-measured 2026-11-06) | 38.6 |
| zebrafish | GO | 10000 | 21813 | 7000 | 14273 | yes (lead-measured 2026-11-06) | 20.7 |
| celegans | GO | 7000 | 14135 | 4700 | 9580 | yes (lead-measured 2026-11-06) | 15.8 |
| human | Reactome | 5600 | 11287 | 1400 | 2811 | yes (lead-measured 2026-11-06) | 4.8 |
| mouse | Reactome | 4400 | 8851 | 900 | 1835 | yes (lead-measured 2026-11-06) | 1.2 |
| rat | Reactome | 3400 | 6909 | 900 | 1813 | yes (lead-measured 2026-11-06) | 1.0 |
| zebrafish | Reactome | 2900 | 5975 | 800 | 1683 | yes (lead-measured 2026-11-06) | 1.0 |
| celegans | Reactome | 2100 | 4289 | 700 | 1401 | yes (lead-measured 2026-11-06) | 0.9 |
| human | KEGG (builtin) | 2900 | 5868 | 110 | 229 | yes (lead-measured 2026-11-06) | 2.0 |

- OD-12 (verification cost): lead-measured Reactome builds 0.9-4.8 s each with `reactome.db` attached; human GO is about 85 s per build (existing behaviour), which is why verification builds each annotation once and a second pass must be served from the disk cache. Full `verify-env` wall time on the host: PENDING-LEAD seconds. Decision (keep all five, or relax): PENDING-LEAD

### 1.4 Fixture (AC-012, AC-017 basis)

`richStudio:::shiny_enrich` on `tests/fixtures/annotation/human-query-20.tsv` (20 human SYMBOLs, GO BP):

- Lead-measured 2026-11-06 with richGO defaults: 328 rows, 298 with Padj < 0.05. Top terms: GO:0097193 (intrinsic apoptotic signaling pathway, Annotated 294, Significant 16, Padj 2.55e-23), GO:0043065, GO:0070059, GO:0071214, GO:0104004. The SPEC's `GO:0006915` (apoptotic process) has 1766 annotated BP genes, above maxGSSize 500, so it can never be reported; the check expects `GO:0097193` and at least 149 rows (50% of 298) with it among the five best terms by Padj.
- Result of the deployed check on the host (rows with Padj < 0.05, `GO:0097193` present): PENDING-LEAD

## 2. Merge (checklist step 2)

- 40-character release SHA of the merged M1: PENDING-LEAD

## 3. Staging and rehearsal (checklist steps 3 and 4; lead, host, juhur)

- Script sha256 on both ends (scp source and host copy): PENDING-LEAD
- `bash -n scripts/deploy-r46-release.sh`: PENDING-LEAD
- `R --version | head -1` (expect 4.6.x) and Bioconductor version (expect 3.23), as printed by the deploy line `Measured R ..., Bioconductor ...`: PENDING-LEAD
- `bash scripts/deploy-r46-release.sh --preflight --release-sha <sha>` ends with `PREFLIGHT PASS`; per-species counts and fixture rows from its `CHECK` lines: PENDING-LEAD
- AC-014 (preflight without sudo changes nothing live): live `INSTALLED.tsv` sha256 before and after, app symlink target before and after, `sha256sum /etc/shiny-server/shiny-server.conf` before and after: PENDING-LEAD
- Lines rehearsed on the host before the owner ran anything: PENDING-LEAD. Lines exercisable only under sudo (the `runuser`-wrapped steps, `systemctl restart`, the symlink swap, the root-owned finalize): PENDING-LEAD

## 4. Owner deploy (checklist step 5)

Command the owner runs (plain WSL terminal on the host or over SSH to Tailscale 100.94.67.89, any directory; reason: builds the release, installs the annotation packages, runs the real-environment verification, swaps the symlink, restarts shiny-server and re-verifies against the live path; without `sudo` it aborts with `run the deploy with sudo`):

```bash
sudo bash scripts/deploy-r46-release.sh --run-id <token> --release-sha <sha>
```

- Run id and log path (`/tmp/richstudio-deploy.<token>/deployment.log`): PENDING-LEAD
- `DEPLOY COMPLETE` line and the `verify_runtime_env` output of the pre-swap and post-swap checks: PENDING-LEAD
- `Live process environment` line (scanned or NOT CHECKED): PENDING-LEAD
- AC-001: `stat -c '%U:%G %a' /home/juhur/.local/share/richStudio/annotation/r4.6-bioc3.23`: PENDING-LEAD
- AC-002: `cmp <release>/.Renviron <generator output for that release>` exits 0: PENDING-LEAD
- AC-003: `INSTALLED.tsv` rows for the six pre-install packages, `tools::md5sum` of each tarball equals the index `MD5sum`, `packageDescription(<pkg>)$Built` starts with `R 4.6`: PENDING-LEAD
- AC-010: `grep -c RICHSTUDIO_ANNOTATION_TEST <release>/.Renviron` prints 0 and the same pattern is absent from `/proc/<live app R pid>/environ`: PENDING-LEAD
- AC-001 rollback check: after `scripts/rollback.sh` to the previous release the annotation directory and `INSTALLED.tsv` are unchanged (sha256 before and after): PENDING-LEAD

## 5. Live acceptance (checklist step 6, AC-017; lead, live browser)

- Fixture run through the live browser, Results page rows with adjusted p < 0.05 and `GO:0006915` present: PENDING-LEAD
- Browser tabs closed before the SSH tunnel was stopped: PENDING-LEAD

## 6. Rollback caveat (checklist step 7, D20)

Rolling back to the pre-annotation release `141e095` restores the "Package 'org.Hs.eg.db' is not installed" failure: that release's `.Renviron` does not name the annotation library. A rollback to it is a safety exit, not a fix. The annotation library is additive and is left in place by `scripts/rollback.sh`.

## 7. Scope additions approved by the lead (2026-11-06)

- **Reactome attach (defect).** richR 0.1.6 `buildAnnot(anntype = "Reactome")` fails for every species with "object 'reactomePATHNAME2ID' not found" unless `reactome.db` is attached (richR 0.2.0 NEWS lines 139-141). Fix: `annotation_attach_reactome()` in `R/annotation_cache.R`, called on a cache miss inside the worker path, never at package load. Approved out-of-list file: `R/deg_enrich.R`.
- **Two-level annotation cache.** New `R/annotation_cache.R` and `tests/testthat/test-annotation-cache.R`; `richstudio_build_annotation` is the default builder in `R/deg_enrich.R` (`shiny_enrich`, `run_enrichment_jobs`) and `R/enrich_tab.R` (that default only). Cache directory `<annotation parent>/cache/<library name>/`, counted in the installer cap accounting. A cache hit does not need `reactome.db` attached; a miss attaches it.
- Fixture expectation changed from `GO:0006915` / 5 rows to `GO:0097193` among the top five / 149 rows (section 1.4).
- **Test exemption approved.** `tests/testthat/test-session-json.R` (no package function may deserialize R objects) now exempts exactly `annotation_disk_read`, the cache reader that reads only app-generated hashed-name files in a verified app-owned 0700 directory. Approved by the lead 2026-11-06 (commit d03b23f).
- **Cache file name hash.** The disk file name is the 32-hex md5 of the canonical key text, computed with `digest::digest(algo = "md5", serialize = FALSE)` (digest is already in Imports), not `tools::md5sum` of a temp file; the values are identical.
