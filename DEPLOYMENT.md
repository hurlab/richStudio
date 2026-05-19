# richStudio Deployment Guide

This guide covers deploying richStudio on a remote server with Shiny Server.

## Deployment Model

richStudio uses a **git-based deployment** with **PREV-snapshot rollback**. The server holds a git clone of the repository; deploys are `git fetch + reset --hard` against a known SHA, preceded by a hardlinked snapshot of the previous state for instant rollback.

This replaces the older rsync-based workflow described in earlier revisions of this document. rsync still works for one-off transfers (untracked files, generated artifacts), but git pull is the canonical mechanism for shipping new releases.

## Prerequisites

- R (>= 4.0.0) installed on the server
- Shiny Server installed and running
- SSH access to the server with a key that allows passwordless login from your dev machine
- `sudo` available on the server for the `shiny` user operations
- `git` installed on the server
- `bash` available locally (the deploy scripts in `scripts/` are bash)

## Quick Deployment (Recommended) — Scripted

Three scripts under `scripts/` automate the workflow. Set environment variables once, then deploy with a single command:

```bash
# One-time: set in your shell rc, or pass per-invocation
export RICHSTUDIO_HOST=hurlab.med.und.edu
export RICHSTUDIO_SSH_USER=juhur
export RICHSTUDIO_PATH=/srv/shiny-server/richStudio
export RICHSTUDIO_RUNAS=shiny
export RICHSTUDIO_URL=https://hurlab.med.und.edu/richStudio/

# Preview what would deploy (no changes)
scripts/preview-deploy.sh

# Deploy
scripts/deploy.sh

# Or deploy a specific branch / tag
scripts/deploy.sh --branch=develop

# If anything goes wrong, instant rollback
scripts/rollback.sh
```

The deploy script:
1. SSH-checks connectivity
2. Verifies server is a git checkout and prints what would deploy (commits + diffstat)
3. Hardlinks current state to `<path>.PREV.<timestamp>` (near-instant; no extra disk)
4. Stops shiny-server
5. `git reset --hard origin/<branch>`
6. Runs `renv::restore()` + `Rcpp::compileAttributes()` as the shiny user
7. Restarts shiny-server
8. Curl-tests the public URL; if HTTP != 200/302, leaves the snapshot in place for one-step rollback
9. Prunes old PREV snapshots beyond `RICHSTUDIO_KEEP_PREV` (default 3)

The rollback script:
1. Lists or selects a PREV snapshot
2. Moves current state aside as `<path>.BAD.<timestamp>` (for forensics)
3. Promotes the snapshot to live
4. Restarts shiny-server and smoke-tests

## One-Time Setup — Migrating an Existing rsync Deployment to Git

If the server's `/srv/shiny-server/richStudio` is currently a plain copy (not a git checkout), run this once:

```bash
ssh user@server '
  sudo systemctl stop shiny-server &&
  sudo mv /srv/shiny-server/richStudio /srv/shiny-server/richStudio.OLD &&
  sudo git clone https://github.com/hurlab/richStudio.git /srv/shiny-server/richStudio &&
  sudo chown -R shiny:shiny /srv/shiny-server/richStudio &&
  cd /srv/shiny-server/richStudio &&
  sudo -u shiny git checkout main &&
  sudo -u shiny R --quiet -e "renv::restore()" &&
  sudo -u shiny R --quiet -e "Rcpp::compileAttributes()" &&
  sudo systemctl start shiny-server
'
```

After verification, delete `/srv/shiny-server/richStudio.OLD`.

If the server is behind a corporate proxy or cannot reach GitHub, push from your dev machine to a bare repo on the server instead:

```bash
ssh user@server 'sudo -u shiny git init --bare /srv/shiny-server/richStudio.git'
git remote add server user@server:/srv/shiny-server/richStudio.git
git push server main
# then on server: clone from the bare repo
```

## Manual Deployment (Without Scripts)

If you cannot run the scripts (e.g., from a CI runner without SSH agent), the equivalent SSH sequence is:

```bash
ssh user@server '
  cd /srv/shiny-server/richStudio &&
  sudo systemctl stop shiny-server &&
  sudo -u shiny git fetch origin &&
  sudo -u shiny git log --oneline HEAD..origin/main &&
  sudo cp -al /srv/shiny-server/richStudio /srv/shiny-server/richStudio.PREV.$(date +%Y%m%d-%H%M%S) &&
  sudo -u shiny git reset --hard origin/main &&
  sudo -u shiny R --quiet -e "renv::restore()" &&
  sudo -u shiny R --quiet -e "Rcpp::compileAttributes()" &&
  sudo systemctl start shiny-server
' && curl -sf https://hurlab.med.und.edu/richStudio/ -o /dev/null && echo "deploy OK"
```

## Legacy rsync Method (deprecated, still supported)

For one-off transfers where you need to push untracked or locally-generated files:

```bash
rsync -avz --progress \
  --exclude='.git/' --exclude='.renv/library/' --exclude='renv/library/' \
  --exclude='*.Rproj.user/' --exclude='.Rhistory' \
  richStudio/ user@server:/srv/shiny-server/richStudio/

# Then on the server:
ssh user@server "
  sudo chown -R shiny:shiny /srv/shiny-server/richStudio &&
  sudo -u shiny R --quiet -e 'renv::restore()' &&
  sudo -u shiny R --quiet -e 'Rcpp::compileAttributes()' &&
  sudo systemctl restart shiny-server
"
```

The `--exclude` flags are essential: without them, your local `renv/library/` (R-version-specific) will overwrite the server's, and the wrong R version may resolve.

---

## Alternative Methods

### Method A: Direct Install (Without renv)

If you prefer not to use renv:

```bash
cd /srv/shiny-server/richStudio

# Run the installation script as shiny user
sudo su - shiny -c "cd /srv/shiny-server/richStudio && Rscript install_dependencies.R"
```

This installs packages to `~/R/library` (user library).

### Method B: Manual Package Installation

```bash
# Install CRAN packages (including richCluster)
sudo su - shiny -c "R -e \"install.packages(c('shiny', 'shinydashboard', 'shinyjs', 'shinyWidgets', 'shinyjqui', 'dplyr', 'tidyverse', 'ggplot2', 'plotly', 'heatmaply', 'reshape2', 'rlang', 'DT', 'data.table', 'readxl', 'writexl', 'jsonlite', 'zip', 'stringdist', 'config', 'Rcpp', 'richCluster'), repos='https://cloud.r-project.org')\""

# Install GitHub packages
sudo su - shiny -c "R -e \"install.packages('remotes', repos='https://cloud.r-project.org')\""
sudo su - shiny -c "R -e \"remotes::install_github('guokai8/richR')\""
sudo su - shiny -c "R -e \"remotes::install_github('guokai8/bioAnno')\""

# Install Bioconductor packages
sudo su - shiny -c "R -e \"if (!requireNamespace('BiocManager', quietly = TRUE)) install.packages('BiocManager', repos='https://cloud.r-project.org')\""
sudo su - shiny -c "R -e \"BiocManager::install(c('AnnotationDbi', 'org.Hs.eg.db'), ask=FALSE)\""
```

---

## Testing Before Shiny Server

To test the app before deploying to Shiny Server:

```bash
cd /srv/shiny-server/richStudio/inst/application

# Run interactively (you'll need X11 forwarding or run with R --quiet)
R -e "shiny::runApp('.', port=3838)"
```

Press `Ctrl+C` to stop.

---

## Troubleshooting

### App Won't Load

Check Shiny Server logs:

```bash
# Main log
sudo tail -f /var/log/shiny-server.log

# App-specific log
sudo tail -f /var/log/shiny-server/richStudio-*.log
```

### Package Not Found Errors

1. Verify packages are installed where Shiny Server expects them:
```bash
sudo su - shiny -c "R -e '.libPaths()'"
```

2. If using renv, check the project library:
```bash
ls -la /srv/shiny-server/richStudio/.renv/library/
```

3. Reinstall dependencies:
```bash
cd /srv/shiny-server/richStudio
sudo su - shiny -c "R -e 'renv::restore()'"
```

### Permission Issues

```bash
# Fix ownership
sudo chown -R shiny:shiny /srv/shiny-server/richStudio

# Fix permissions
sudo chmod -R 755 /srv/shiny-server/richStudio
```

### C++ Compilation Errors

```bash
# Ensure R development tools are installed
sudo apt-get install r-base-dev

# Recompile C++ attributes
cd /srv/shiny-server/richStudio
sudo su - shiny -c "R -e 'Rcpp::compileAttributes()'"
```

---

## Package Locations Reference

| Method | Location | Notes |
|--------|----------|-------|
| **renv::restore()** | `.renv/library/` | Project-local, isolated |
| install_dependencies.R | `~/R/library` | User library, shared |
| System install | `/usr/lib/R/library` | System-wide, not recommended |

---

## Updating the App

See "Quick Deployment (Recommended) — Scripted" above. The TL;DR is:

```bash
scripts/preview-deploy.sh    # show what would deploy
scripts/deploy.sh            # do it
scripts/rollback.sh          # undo it
```

## Pre-deployment Safety Checklist

Before running `scripts/deploy.sh`, especially for the first time after substantial changes:

1. **Parse-check locally**: `Rscript -e 'for(f in list.files("R","\\.R$",full.names=TRUE)) parse(f)'` — must show all OK.
2. **Run tests locally**: `Rscript -e 'testthat::test_dir("tests/testthat")'` — requires renv restored against current R version on this machine.
3. **Try `R CMD check --as-cran`** — surfaces NAMESPACE drift, undeclared imports, broken examples. ~5-10 min.
4. **Preview the deploy**: `scripts/preview-deploy.sh` — shows commits, file diff, whether renv reconcile is needed.
5. **Optional: staging slot** — for high-risk bundles, deploy to a parallel path (`/srv/shiny-server/richStudio_staging/`) configured in `shiny-server.conf` as a separate `location` block. Smoke-test, then swap with `mv`.

After `scripts/deploy.sh` completes, the smoke test runs automatically. If it fails, the script preserves the snapshot and tells you the rollback command.

## Risk-by-change-type Reference

| Change type | renv reconcile needed? | Rcpp recompile needed? | Recommended safety tier |
|---|---|---|---|
| Comment-only / docs | No | No | Tier 3 (atomic swap) suffices |
| R logic in `R/*.R` | No | No | Tier 3 + smoke test |
| New `@importFrom` or DESCRIPTION change | Yes | No | Tier 3 + log tail post-deploy |
| `src/*.cpp` or `src/*.h` change | No | Yes | Tier 2 (staging slot) recommended |
| `renv.lock` update | Yes (significant) | Maybe | Tier 2 (staging slot) required |
| `inst/application/app.R` UI change | No | No | Tier 3 + manual click-through |

---

## Server Configuration (Optional)

For custom Shiny Server configuration, edit:

```bash
sudo nano /etc/shiny-server/shiny-server.conf
```

Example site configuration:

```r
# /etc/shiny-server/shiny-server.conf
server {
  listen 3838;

  location /richStudio {
    app_dir /srv/shiny-server/richStudio/inst/application;
    log_dir /var/log/shiny-server;

    # Run as shiny user
    run_as shiny;

    # Optional: Disable bookmarking for security
    disable_bookmarking TRUE;
  }
}
```

After configuration changes:

```bash
sudo systemctl restart shiny-server
```

---

## Security Considerations

1. **File Permissions**: Ensure sensitive data files are not accessible
2. **Network Access**: Consider firewall rules for port 3838
3. **HTTPS**: Use reverse proxy (nginx/Apache) for SSL/TLS
4. **Authentication**: Add authentication if needed (see Shiny Server docs)

---

## Maintenance

### Regular Updates

```bash
# Update R packages
cd /srv/shiny-server/richStudio
sudo su - shiny -c "R -e 'renv::update()'"
```

### Backup

```bash
# Backup the entire app directory
tar -czf richstudio-backup-$(date +%Y%m%d).tar.gz /srv/shiny-server/richStudio
```

---

## Useful Commands

```bash
# Check Shiny Server status
sudo systemctl status shiny-server

# Restart Shiny Server
sudo systemctl restart shiny-server

# View real-time logs
sudo journalctl -u shiny-server -f

# Check R version
R --version

# List installed packages
sudo su - shiny -c "R -e 'installed.packages()[,c(\"Package\", \"Version\")]'"
```

---

## Support

For issues or questions:
- GitHub Issues: https://github.com/hurlab/richStudio/issues
- richCluster Package: https://github.com/hurlab/richCluster (now on CRAN)
