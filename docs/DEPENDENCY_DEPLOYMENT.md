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
