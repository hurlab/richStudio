# Dependency migration deployment

This is a one-time, user-executed deployment procedure for the validated dependency migration. It is separate from migration acceptance: do not run it until the migration's required security, performance, compatibility, and test gates have passed and the exact release commit has been reviewed.

The script targets only the measured Hurlab Shiny app: `100.94.67.89` (`Hurlab.und.nodak.edu`), `/home/juhur/shinyapps/richStudio`, with Shiny `run_as juhur` and R 4.5.2. It refuses a different server, app HEAD, R version, app configuration, dirty tracked checkout, or unexpected untracked or ignored app content. It allows only the known `.playwright-mcp/`, renv library, app logs, `.Renviron`, and the app-local `restart.txt` marker. The existing `.playwright-mcp/` directory remains in the preserved prior app tree.

## What the script does

The script clones the current app checkout into a private build directory and fetches only the supplied full commit SHA. It downloads and SHA256-checks richR 0.1.5 from `hurlab/richR` commit `9be43abdae556d9f1df128149a70721f08ab7d25`, plus bioAnno 0.99.45 and richCluster 2.0.1 from their exact lockfile revisions, then compiles them plus richStudio with the server's R 4.5.2 as `juhur`. It does not run `renv::restore()`, modify the existing project library, or copy packages compiled under another R version. Other Imports resolve from the existing server project/system libraries, and the script logs their actual version and library paths. It does not claim to validate or restore the full lockfile closure; installation stops before the app-path swap if a required package is unavailable.

Before changing the configured app path, the script freezes the completed app-user build child inside a root-controlled temporary parent, then copies it into a root-owned release under `/opt/richStudio/releases`, excluding Git metadata. Pre-publication R checks suppress the staged `.Renviron` and use explicit staging library paths; after the app-path swap, a separate check reads the real release `.Renviron` and verifies its overlay and preserved-library paths. The script verifies copied package identities, resolved Imports, changed dependency tests, and app construction while release files are root-owned and not app-user-writable. Only the release's `logs/` directory is writable by `juhur`. The new app's root-owned `.Renviron` disables renv activation and prepends the private release library while retaining the prior project's library as a fallback lookup path; that fallback is not mutated or claimed to be read-only. The old app tree is renamed intact to `/home/juhur/shinyapps/richStudio.PREV.<UTC timestamp>`; that tree retains the previous checkout, renv library, logs, and `.playwright-mcp/` data for rollback. The configured app path becomes a symlink to the root-owned release.

The script touches and retains the root-owned app-local `restart.txt` marker, then requests the app route. Posit's Shiny Server guidance says this marker restarts that application when a new connection arrives; existing sessions can continue on their prior process. The script records an empty log-directory baseline before publication, then requires a successful route response and a candidate log in the release directory. Traffic that starts a worker after publication is valid and does not fail the deployment. This evidence does not establish that a worker completed startup or that existing sessions moved to the new process; the log and exit-status files must be inspected before claiming deployment. On rollback it restores the old tree and touches its marker so the next connection uses the previous app. It does not stop or restart the shared `shiny-server` service. See [Posit Shiny Server: restarting an application](https://docs.posit.co/shiny-server/#restarting-an-application).

If a step fails after the path swap, the script removes its release symlink and restores the complete previous app tree. It leaves the staged release and private result directory for inspection. On success, keep the `.PREV` tree until the deployed app has been reviewed; the script never prunes old trees.

## User execution

After the migration owner supplies the reviewed script SHA256 and exact release commit SHA, transfer the script to a user-owned path on Hurlab, then compare its digest with the handoff before installing it as root. For example, transfer the reviewed file to `/home/juhur/richStudio-deploy-dependency-update.sh`; do not upload directly to `/root`.

```bash
printf '%s  %s\n' '<reviewed-script-sha256>' /home/juhur/richStudio-deploy-dependency-update.sh \
  | sha256sum --check -
sudo install -o root -g root -m 0700 \
  /home/juhur/richStudio-deploy-dependency-update.sh \
  /root/richStudio-deploy-dependency-update.sh
sudo sha256sum /root/richStudio-deploy-dependency-update.sh
sudo bash /root/richStudio-deploy-dependency-update.sh \
  --run-id 20261020T220000Z \
  --baseline-sha fc124971b004fcbc24a212a40636d34cc57fd587 \
  --release-sha <reviewed-40-character-migration-commit-sha>
```

Use a unique safe run-id for each attempt; the example command writes exactly `/tmp/richstudio-deploy.20261020T220000Z/deployment.log` and `/tmp/richstudio-deploy.20261020T220000Z/exit-status`. The script refuses to reuse an existing result path. The directory is root-owned, group `juhur`, mode `0750`; log and status files are root-owned, group `juhur`, mode `0640`. `juhur` can read them but cannot replace the paths later written by root. Treat exit status `0` as script completion only; inspect the log and status file before recording a deployment result. The migration owner retrieves those exact files from the server and reviews them directly before making a deployment claim.

The script does not push or create the migration commit. The target commit must already exist in the configured origin and descend from the required baseline. It fetches that object by its exact SHA and does not deploy `main`, a branch tip, or `latest`.

## Rollback after a successful run

If later review finds a problem, as `juhur`, restore the exact prior tree named in the successful run's log. First verify that `/home/juhur/shinyapps/richStudio` is still a symlink to the release directory from that run, then run:

```bash
rm /home/juhur/shinyapps/richStudio
mv /home/juhur/shinyapps/richStudio.PREV.<UTC timestamp> \
  /home/juhur/shinyapps/richStudio
touch /home/juhur/shinyapps/richStudio/restart.txt
```

Do not substitute a different `.PREV` tree. The marker asks Shiny Server to start the restored app for the next connection; it does not restart the shared Shiny Server service.

## Evidence limits

The script checks the target server identity and current baseline at execution time. It verifies the configured app path points to the root-owned release at publication time; the symlink remains in a user-owned parent directory and is not claimed to be immutable against later host changes. The previously measured server identity and baseline are embedded as refusal guards, not treated as fresh evidence. The resulting server log and exit-status file are the evidence for a particular run. A successful HTTP response does not replace review of the staged test output or the independent migration gates.


## Species annotation library (SPEC-WS-014)

Organism annotation packages are not part of any release library. Live richStudio keeps them in one persistent, per R minor and Bioconductor version annotation library, outside every release directory:

```text
/home/juhur/.local/share/richStudio/annotation/r4.6-bioc3.23          the library (juhur:juhur, 0755)
/home/juhur/.local/share/richStudio/annotation/r4.6-bioc3.23.lock     kernel flock file (one installer at a time)
/home/juhur/.local/share/richStudio/annotation/r4.6-bioc3.23.status   installer status, key=value, written atomically
/home/juhur/.local/share/richStudio/annotation/r4.6-bioc3.23/INSTALLED.tsv   package, version, sha256, md5, source_url, installed_at
```

Every release `.Renviron` is produced by one function in `scripts/deploy-r46-release.sh` (`render_renviron`) and has exactly three variables: `RENV_CONFIG_AUTOLOADER_ENABLED=FALSE`, `R_LIBS_USER=<release library>:<annotation library>` (release library first) and `RICHSTUDIO_ANNOTATION_LIB=<annotation library>`. The annotation library is never written by a release and never rolled back with one. An R or Bioconductor upgrade starts an empty library by design.

### What the deploy does

1. Checks the runtime pin: any R 4.6.x and Bioconductor 3.23 are accepted, any other minor or Bioconductor version is rejected naming the measured and the pinned value; the measured values are printed.
2. Creates the annotation library as `juhur` and runs the installer once per pre-install package (`org.Hs.eg.db`, `org.Mm.eg.db`, `org.Rn.eg.db`, `org.Dr.eg.db`, `org.Ce.eg.db`, `reactome.db`), each with its own 2400 s deadline. A busy library (installer exit 75) is retried every 10 s for up to 2400 s; a missing tool (exit 127) fails at once.
3. Fails before the swap when an annotation package sits in the sealed release library, a package is not built for R 4.6, or the annotation library or its parent is not owned by `juhur` or is group- or world-writable.
4. Runs `verify_runtime_env` against the finalized release at its final path, as `juhur`, from the release directory, with a minimal environment (`env -i`) so the release's own `.Renviron` and `.Rprofile` take effect as under shiny-server: the `.Renviron` bytes equal the generator output, the first two `.libPaths()` entries (main process and a `future::multisession` worker) are the release library then the annotation library, each pre-installed package loads from the annotation library and is built for R 4.6, `buildAnnot` meets the floors in `inst/extdata/annotation-verify-floors.tsv` (GO and Reactome for five species, builtin KEGG for human), and a real human GO enrichment of `tests/fixtures/annotation/human-query-20.tsv` returns at least 149 adjusted-p < 0.05 rows with `GO:0097193` among the five best by Padj (intrinsic apoptotic signaling pathway; `GO:0006915` can never be reported because its 1766 annotated genes exceed maxGSSize 500). Annotations are built through the app's own cached builder (`richstudio_build_annotation`, which attaches `reactome.db` on a miss), and the 15-entry pre-warm (GO, KEGG and Reactome for the five species) must be followed by a second pass served entirely from the cache, and after the swap human GO must be a hit.
5. After the symlink swap and restart it runs the same verification against the live path in addition to the HTTP check (a 200 alone never passes). A failure restores the previous release and the script exits non-zero.
6. `--preflight` runs the same function against the build tree with a scratch annotation library under its own work root and the generated `.Renviron`; it never touches the live annotation library, the symlink or the server configuration.

### Installer

`inst/annotation/annotation-install.sh <package> [<package> ...]` is a small bash supervisor (needs bash >= 5.1, `flock`, GNU `timeout`, `curl`, `Rscript`); `inst/annotation/annotation-install.R` is the base-R worker. Package names only: the allowlist is `inst/extdata/annotation-allowlist.tsv`, the repository is `https://bioconductor.org/packages/3.23/data/annotation`, a redirect to another host or to `http` is rejected, and the tarball MD5 from the repository index is required. Limits: 1200 s per download, 1200 s per install, 2400 s per package, 30 s TERM-to-KILL grace; at least 2 GiB free and a library size cap of `max(5 GiB, 2 x sum(inst_mb))`. A package is installed into a private staging directory, validated there, and renamed into the library; an existing library entry is never replaced or deleted. Exit codes: 0 completed, 1 failed (the reason is in the status file), 75 busy, 127 a required tool is missing, 130 stopped.

Stopping an installer from a shell (the host owner; the app offers no administrative stop):

```bash
pkill -TERM -f annotation-install.sh
```

The supervisor removes its staging directory and writes `state=stopped`. After a `SIGKILL` the kernel releases the lock at once (an orphaned worker keeps it until that worker ends, at most about 20 minutes); the next installer removes the leftover staging directory before it installs.

### Rollback

The annotation library is additive: `scripts/rollback.sh` leaves it and `INSTALLED.tsv` untouched. Rolling back to the pre-annotation release `141e095` restores the "Package 'org.Hs.eg.db' is not installed" failure, because that release's `.Renviron` does not name the annotation library. A rollback to it is a safety exit, not a fix. Removing the annotation library is optional and manual, after the old release is retired.

### Annotation cache

`richstudio_build_annotation()` (R/annotation_cache.R) is the one annotation builder of the app. It keeps a memory level (3 entries, per worker process) and a disk level in `/home/juhur/.local/share/richStudio/annotation/cache/r4.6-bioc3.23/` (mode 0700, app user only; files `<md5 of the key text>.rds`, written through a temp file and an atomic rename). The key covers the cache schema, species, keytype, annotation type, R minor, richR and bioAnno versions (and RemoteSha when present) and the versions of AnnotationDbi, GO.db, the organism package and, for Reactome, `reactome.db`. Each lookup returns `attr(x, "cache_source")` (memory, disk or built). The disk level is bounded to 1 GiB and 200 files (oldest first, never the entry just written; stale `.tmp-*` files older than an hour are removed) and counts against the installer's library size cap. An unset `RICHSTUDIO_ANNOTATION_LIB`, or an unwritable cache directory, disables the cache and the app builds every time; an unsafe directory (symlink, wrong owner, wrong mode) disables only the disk level, with one log line. The cache can be removed at any time; it is rebuilt on demand.
