# SPEC-WS-014 M1 deploy record

Species annotation packages: installer, deploy-time annotation library, real-environment verification.

**How this file works.** Every placeholder cell is a host measurement or a host result that only the lead can produce (juhur on hurlab); the placeholder is the upper-case token `PENDING` followed by `-LEAD`. `scripts/test-annotation-library.py` (class `MergeGatePlaceholders`) fails while that token appears anywhere in this file, or in the allowlist `inst_mb` column, so M1 cannot merge unmeasured. Replace each placeholder with the verbatim command output or the measured number. This paragraph deliberately never spells the token as one string.

Developer-side evidence (run locally, no host access) is recorded in the M1 completion report, not here.

## 1. Pre-merge measurements (checklist step 1; lead, host, juhur)

### 1.1 Host tools and service sandbox (AC-001 gap B7, AC-006)

| Item | Command | Result |
|---|---|---|
| Tools present | `command -v setsid flock timeout curl` | /usr/bin/setsid /usr/bin/flock /usr/bin/timeout /usr/bin/curl (/usr/bin/bash) (lead, 2026-11-06) |
| bash version (>= 5.1) | `bash --version \| head -1` | GNU bash, version 5.2.21(1)-release (x86_64-pc-linux-gnu); flock from util-linux 2.39.3; curl 8.5.0 (lead, 2026-11-06) |
| GNU timeout version | `timeout --version \| head -1` | timeout (GNU coreutils) 9.4 (lead, 2026-11-06) |
| shiny-server sandbox | `systemctl show shiny-server -p User -p ProtectHome -p ReadWritePaths -p ReadOnlyPaths -p KillMode` | User= (empty), ProtectHome=no, ReadWritePaths= (empty), ReadOnlyPaths= (empty), PrivateTmp=no, ProtectSystem=no, NoNewPrivileges=no, KillMode=control-group (lead, 2026-11-06) |
| App user can write the annotation parent | write probe (AC-001) | Annotation library is `drwxr-xr-x juhur juhur`; the six packages were installed into it by the deploy as juhur, and the cache directory beside it (0700, juhur) holds the 15 pre-warm entries (lead, 2026-11-06) |

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
- `df -k` of the annotation filesystem: `/dev/sdb1 1151643828 849865888 243251120 78% /` (lead, 2026-11-06)
- `INSTALLED.tsv` of the scratch library (19 packages): the scratch install is the lead's `measure.log` (all 19 `ok=TRUE`, install seconds and `inst_mb` above, total 3734.2 MB); the live library holds the six pre-install packages (section 4) (lead, 2026-11-06)

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
| mouse | KEGG (builtin) | 3302 | 6605 | 112 | 225 | yes (lead, 2026-11-06) | 1.1 |
| rat | KEGG (builtin) | 3195 | 6390 | 112 | 225 | yes (lead, 2026-11-06) | 0.5 |
| zebrafish | KEGG (builtin) | 2277 | 4554 | 77 | 155 | yes (lead, 2026-11-06) | 0.5 |
| celegans | KEGG (builtin) | 979 | 1959 | 62 | 125 | yes (lead, 2026-11-06) | 0.5 |

- OD-12 (verification cost): lead-measured Reactome builds 0.9-4.8 s each with `reactome.db` attached; human GO is about 85 s per build (existing behaviour), which is why verification builds each annotation once and a second pass must be served from the disk cache. Full `verify-env` pre-warm on the host (preflight 1af494e, lead, 2026-11-06): first pass 261.2 s, second pass 13.0 s (all 15 from the disk cache). Decision: keep all five.

### 1.4 Fixture (AC-012, AC-017 basis)

`richStudio:::shiny_enrich` on `tests/fixtures/annotation/human-query-20.tsv` (20 human SYMBOLs, GO BP):

- Lead-measured 2026-11-06 with richGO defaults: 328 rows, 298 with Padj < 0.05. Top terms: GO:0097193 (intrinsic apoptotic signaling pathway, Annotated 294, Significant 16, Padj 2.55e-23), GO:0043065, GO:0070059, GO:0071214, GO:0104004. The SPEC's `GO:0006915` (apoptotic process) has 1766 annotated BP genes, above maxGSSize 500, so it can never be reported; the check expects `GO:0097193` and at least 149 rows (50% of 298) with it among the five best terms by Padj.
- Result of the deployed check on the host: `CHECK fixture_enrichment: PASS significant_rows=298 (floor 149) GO:0097193_in_top5=TRUE top5=GO:0097193,GO:0043065,GO:0070059,GO:0071214,GO:0104004` (preflight of 1af494e, lead, 2026-11-06)

## 2. Merge (checklist step 2)

- 40-character release SHA of the merged M1: `846f0b9d920015fdd025b04d6302e374117db821` (tree `1415549a...`, identical to the preflighted `1af494e`; main fast-forwarded; PR #4 merged; PR #3 had been merged earlier by the owner as `4ef3031`) (lead, 2026-11-06)

## 3. Staging and rehearsal (checklist steps 3 and 4; lead, host, juhur)

- Script staged as `~/deploy-r46-release-846f0b9.sh`, sha256 `877a345ce15c5e38134a9e826403913a0d51e2d6ddffcb5f0fa2bc776d4ea170` (lead, 2026-11-06)
- `bash -n` on the staged script: OK (lead, 2026-11-06)
- Runtime pin line printed by the preflight: `Measured R 4.6.2, Bioconductor 3.23 (pinned: R 4.6.x, Bioconductor 3.23)` (lead, 2026-11-06)
- `bash ~/deploy-r46-release-1af494e.sh --preflight --release-sha 1af494ed0fe155a568cc506319adaeaccc01f359` ended with `VERIFY PASS` and `PREFLIGHT PASS` (work root since deleted). Per-species counts equal the measured counts of section 1.3 (e.g. `floor_human_GO: genes=20826 terms=21344`, `floor_human_Reactome: genes=11287 terms=2811`); `CHECK cache_second_pass: PASS entries=15 hits=15 first_pass_seconds=261.2 second_pass_seconds=13.0 sources=15 disk`; `INFO cache_dir_du_kb: 48532 | main process VmRSS: 4518660 kB`; fixture rows in section 1.4 (log: lead's `preflight-1af494e.log`, lead, 2026-11-06)
- AC-014: the preflight ran as juhur without sudo against a scratch annotation library under its own work root; it never touched the live annotation library, the symlink or the server configuration (lead, 2026-11-06; the before/after checksums were not captured by the lead, so this rests on the scratch-library design)
- Rehearsed vs sudo-only (lead, 2026-11-06): the preflight exercised every non-sudo function (version pin, `ensure_annotation_library` as juhur, `verify_runtime_env`, the cache pre-warm). `ensure_annotation_library` ownership handling as root to juhur, the finalize/chown, the symlink swap, the restart and the post-swap verification ran only under the owner's sudo.

## 4. Owner deploy (checklist step 5)

Command the owner runs (plain WSL terminal on the host or over SSH to Tailscale 100.94.67.89, any directory; reason: builds the release, installs the annotation packages, runs the real-environment verification, swaps the symlink, restarts shiny-server and re-verifies against the live path; without `sudo` it aborts with `run the deploy with sudo`):

```bash
sudo bash scripts/deploy-r46-release.sh --run-id <token> --release-sha <sha>
```

- Run id `ws014-m1-846f0b9-20261106` (log `/tmp/richstudio-deploy.ws014-m1-846f0b9-20261106/deployment.log`); live release `/opt/richStudio/releases/richStudio-846f0b9d920015fdd025b04d6302e374117db821-20261106T165909Z`; previous release `141e095` kept (lead, 2026-11-06)
- The owner's terminal output (the `DEPLOY COMPLETE` block and the pre/post-swap `verify_runtime_env` output) was not captured by the lead; the post-deploy evidence below was collected by the lead instead.
- Live process environment (lead, 2026-11-06): `SockJSAdapter.R` R process 985259 and its two future workers (985596, 985597) are running; the workers' `.libPaths()` start with the release library then `/home/juhur/.local/share/richStudio/annotation/r4.6-bioc3.23`.
- AC-001/post-deploy facts (lead, 2026-11-06): live HTTP 200; the annotation library is juhur-owned (`drwxr-xr-x juhur juhur`) with `org.Ce/Dr/Hs/Mm/Rn.eg.db` and `reactome.db`; cache directory `drwx------ juhur juhur` with 15 entries, 48536 KB; library 2693900 KB; installer status file `state=completed` for the last package (reactome.db).
- AC-002/AC-010 (lead, 2026-11-06): the live `.Renviron` has `R_LIBS_USER` = release library : annotation library and `RICHSTUDIO_ANNOTATION_LIB` set; by design the deploy's pre- and post-swap `verify_runtime_env` compares the bytes to the generator and rejects any `RICHSTUDIO_ANNOTATION_TEST*` variable (the owner's output showing those checks was not captured).
- AC-003: `INSTALLED.tsv` (live) has one row per pre-install package: org.Hs.eg.db 3.23.1, org.Mm.eg.db 3.23.0, org.Rn.eg.db 3.23.0, org.Dr.eg.db 3.22.0, org.Ce.eg.db 3.22.0, reactome.db 1.96.0, each with sha256, md5 and an https://bioconductor.org source URL (lead, 2026-11-06). Built-for-R-4.6 is asserted by the deploy's `pkg_*` checks (`built_ok=TRUE` in the preflight log).
- AC-010: see the AC-002/AC-010 entry above; the process-environment scan result was not captured separately.
- AC-001 rollback check: not recorded by the lead (no rollback evidence supplied). The annotation library is additive and `scripts/rollback.sh` does not touch it (lead, 2026-11-06).

## 5. Live acceptance (checklist step 6, AC-017; lead, live browser)

- Live browser (headless, direct over Tailscale, no tunnel, browser closed by the script; lead, 2026-11-06): fixture GO run Succeeded in 7.2-10.0 s (measured 10.033 s); second GO 9.0 s (log `source=memory 0.00 s`); Reactome 3.0 s (`source=disk 0.11 s`); custom background check 1.0 s ("60 of 18842 annotated genes ... 20 tested") and the explicit-background GO run 8.1 s Succeeded. No page errors were recorded.
- Browser closed by the script; no SSH tunnel was used (lead, 2026-11-06).

## 6. Rollback caveat (checklist step 7, D20)

Rolling back to the pre-annotation release `141e095` restores the "Package 'org.Hs.eg.db' is not installed" failure: that release's `.Renviron` does not name the annotation library. A rollback to it is a safety exit, not a fix. The annotation library is additive and is left in place by `scripts/rollback.sh`.

## 7. Scope additions approved by the lead (2026-11-06)

- **Reactome attach (defect).** richR 0.1.6 `buildAnnot(anntype = "Reactome")` fails for every species with "object 'reactomePATHNAME2ID' not found" unless `reactome.db` is attached (richR 0.2.0 NEWS lines 139-141). Fix: `annotation_attach_reactome()` in `R/annotation_cache.R`, called on a cache miss inside the worker path, never at package load. Approved out-of-list file: `R/deg_enrich.R`.
- **Two-level annotation cache.** New `R/annotation_cache.R` and `tests/testthat/test-annotation-cache.R`; `richstudio_build_annotation` is the default builder in `R/deg_enrich.R` (`shiny_enrich`, `run_enrichment_jobs`) and `R/enrich_tab.R` (that default only). Cache directory `<annotation parent>/cache/<library name>/`, counted in the installer cap accounting. A cache hit does not need `reactome.db` attached; a miss attaches it.
- Fixture expectation changed from `GO:0006915` / 5 rows to `GO:0097193` among the top five / 149 rows (section 1.4).
- **Test exemption approved.** `tests/testthat/test-session-json.R` (no package function may deserialize R objects) now exempts exactly `annotation_disk_read`, the cache reader that reads only app-generated hashed-name files in a verified app-owned 0700 directory. Approved by the lead 2026-11-06 (commit d03b23f).
- **Cache file name hash.** The disk file name is the 32-hex md5 of the canonical key text, computed with `digest::digest(algo = "md5", serialize = FALSE)` (digest is already in Imports), not `tools::md5sum` of a temp file; the values are identical.
