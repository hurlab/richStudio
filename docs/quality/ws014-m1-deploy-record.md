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

| Package | est_mb (index) | du -sk installed | inst_mb (committed) | Download seconds |
|---|---|---|---|---|
| org.Hs.eg.db | 99 | PENDING-LEAD | PENDING-LEAD | PENDING-LEAD |
| org.Mm.eg.db | 89 | PENDING-LEAD | PENDING-LEAD | PENDING-LEAD |
| org.Rn.eg.db | 61 | PENDING-LEAD | PENDING-LEAD | PENDING-LEAD |
| org.Dr.eg.db | 36 | PENDING-LEAD | PENDING-LEAD | PENDING-LEAD |
| org.Ce.eg.db | 20 | PENDING-LEAD | PENDING-LEAD | PENDING-LEAD |
| reactome.db | 319 | PENDING-LEAD | PENDING-LEAD | PENDING-LEAD |
| org.Dm.eg.db | 30 | PENDING-LEAD | PENDING-LEAD | PENDING-LEAD |
| org.Sc.sgd.db | 15 | PENDING-LEAD | PENDING-LEAD | PENDING-LEAD |
| org.Gg.eg.db | 19 | PENDING-LEAD | PENDING-LEAD | PENDING-LEAD |
| org.Bt.eg.db | 22 | PENDING-LEAD | PENDING-LEAD | PENDING-LEAD |
| org.Ss.eg.db | 21 | PENDING-LEAD | PENDING-LEAD | PENDING-LEAD |
| org.Cf.eg.db | 31 | PENDING-LEAD | PENDING-LEAD | PENDING-LEAD |
| org.Xl.eg.db | 26 | PENDING-LEAD | PENDING-LEAD | PENDING-LEAD |
| org.Mmu.eg.db | 26 | PENDING-LEAD | PENDING-LEAD | PENDING-LEAD |
| org.At.tair.db | 39 | PENDING-LEAD | PENDING-LEAD | PENDING-LEAD |
| org.Ag.eg.db | 5 | PENDING-LEAD | PENDING-LEAD | PENDING-LEAD |
| org.EcK12.eg.db | 6 | PENDING-LEAD | PENDING-LEAD | PENDING-LEAD |
| org.Pf.plasmo.db | 3 | PENDING-LEAD | PENDING-LEAD | PENDING-LEAD |
| org.Pt.eg.db | 27 | PENDING-LEAD | PENDING-LEAD | PENDING-LEAD |

- Sum of `inst_mb` over the 19 available rows: PENDING-LEAD MiB; cap = `max(5 GiB, 2 x sum)` = PENDING-LEAD bytes (the gate test recomputes it with `Rscript inst/annotation/annotation-install.R cap`).
- `df -k` of the annotation filesystem: PENDING-LEAD
- `INSTALLED.tsv` of the scratch library lists all 19 packages: PENDING-LEAD

### 1.3 Floors against real counts (AC-012)

`buildAnnot(species, keytype = "SYMBOL", anntype)` with the pinned richR 0.1.6 in the release library. Each floor must be at most 50% of the measured count (the committed floors are in `inst/extdata/annotation-verify-floors.tsv`; adjust the data file, not the script, if one is wrong).

| species | anntype | floor genes | measured genes | floor terms | measured terms | floors <= 50% | build seconds |
|---|---|---|---|---|---|---|---|
| human | GO | 5000 | PENDING-LEAD | 1000 | PENDING-LEAD | PENDING-LEAD | PENDING-LEAD |
| mouse | GO | 5000 | PENDING-LEAD | 1000 | PENDING-LEAD | PENDING-LEAD | PENDING-LEAD |
| rat | GO | 5000 | PENDING-LEAD | 1000 | PENDING-LEAD | PENDING-LEAD | PENDING-LEAD |
| zebrafish | GO | 5000 | PENDING-LEAD | 1000 | PENDING-LEAD | PENDING-LEAD | PENDING-LEAD |
| celegans | GO | 5000 | PENDING-LEAD | 1000 | PENDING-LEAD | PENDING-LEAD | PENDING-LEAD |
| human | Reactome | 1000 | PENDING-LEAD | 100 | PENDING-LEAD | PENDING-LEAD | PENDING-LEAD |
| mouse | Reactome | 1000 | PENDING-LEAD | 100 | PENDING-LEAD | PENDING-LEAD | PENDING-LEAD |
| rat | Reactome | 1000 | PENDING-LEAD | 100 | PENDING-LEAD | PENDING-LEAD | PENDING-LEAD |
| zebrafish | Reactome | 1000 | PENDING-LEAD | 100 | PENDING-LEAD | PENDING-LEAD | PENDING-LEAD |
| celegans | Reactome | 1000 | PENDING-LEAD | 100 | PENDING-LEAD | PENDING-LEAD | PENDING-LEAD |
| human | KEGG (builtin) | 3000 | PENDING-LEAD | 100 | PENDING-LEAD | PENDING-LEAD | PENDING-LEAD |

- OD-12 (verification cost): wall time of the full `verify-env` run, dominated by loading `reactome.db` five times: PENDING-LEAD seconds. Decision (keep all five, or relax): PENDING-LEAD

### 1.4 Fixture (AC-012, AC-017 basis)

`richStudio:::shiny_enrich` on `tests/fixtures/annotation/human-query-20.tsv` (20 human SYMBOLs, GO BP):

- Rows with adjusted p < 0.05: PENDING-LEAD (need >= 5)
- `GO:0006915` among them: PENDING-LEAD

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
