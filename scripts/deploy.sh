#!/usr/bin/env bash
# deploy.sh — git-based deployment for richStudio Shiny app
#
# Usage:
#   scripts/deploy.sh                    # deploys main to default host
#   scripts/deploy.sh --branch=develop   # deploys a specific branch
#   scripts/deploy.sh --dry-run          # prints what would deploy, no changes
#   scripts/deploy.sh --no-restart       # pull + reconcile but don't restart shiny-server
#
# Env overrides (or edit defaults below):
#   RICHSTUDIO_HOST       — SSH target host                 (default: hurlab.med.und.edu)
#   RICHSTUDIO_SSH_USER   — SSH login user                  (default: $USER)
#   RICHSTUDIO_PATH       — Server install path             (default: /srv/shiny-server/richStudio)
#   RICHSTUDIO_RUNAS      — Server R/Shiny owner            (default: shiny)
#   RICHSTUDIO_URL        — Public URL for smoke test       (default: https://hurlab.med.und.edu/richStudio/)
#   RICHSTUDIO_KEEP_PREV  — Number of PREV snapshots to keep (default: 3)
#
# Exit codes:
#   0 — success, deployed and smoke-tested OK
#   1 — argument or env error
#   2 — SSH/network failure
#   3 — server-side deploy step failed
#   4 — smoke test failed (deploy completed but app not responding)

set -euo pipefail

# ---------- defaults ----------
RICHSTUDIO_HOST="${RICHSTUDIO_HOST:-hurlab.med.und.edu}"
RICHSTUDIO_SSH_USER="${RICHSTUDIO_SSH_USER:-$USER}"
RICHSTUDIO_PATH="${RICHSTUDIO_PATH:-/srv/shiny-server/richStudio}"
RICHSTUDIO_RUNAS="${RICHSTUDIO_RUNAS:-shiny}"
RICHSTUDIO_URL="${RICHSTUDIO_URL:-https://hurlab.med.und.edu/richStudio/}"
RICHSTUDIO_KEEP_PREV="${RICHSTUDIO_KEEP_PREV:-3}"
BRANCH="main"
DRY_RUN=0
NO_RESTART=0

# ---------- arg parsing ----------
for arg in "$@"; do
    case "$arg" in
        --branch=*)   BRANCH="${arg#*=}" ;;
        --dry-run)    DRY_RUN=1 ;;
        --no-restart) NO_RESTART=1 ;;
        -h|--help)
            sed -n '2,25p' "$0"
            exit 0
            ;;
        *)
            echo "ERROR: unknown argument: $arg" >&2
            exit 1
            ;;
    esac
done

SSH_TARGET="${RICHSTUDIO_SSH_USER}@${RICHSTUDIO_HOST}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
SNAPSHOT_PATH="${RICHSTUDIO_PATH}.PREV.${TIMESTAMP}"

# ---------- helpers ----------
log()  { printf '[deploy] %s\n' "$*"; }
fail() { printf '[deploy] ERROR: %s\n' "$*" >&2; exit "${2:-1}"; }

ssh_run() {
    # Run a command on the server via SSH. Each call is a fresh shell.
    ssh -o BatchMode=yes -o ConnectTimeout=10 "$SSH_TARGET" "$@"
}

restore_from_snapshot() {
    log "Restoring from snapshot $SNAPSHOT_PATH..."
    ssh_run "sudo systemctl stop shiny-server || true"
    ssh_run "sudo rm -rf $RICHSTUDIO_PATH && sudo mv $SNAPSHOT_PATH $RICHSTUDIO_PATH"
    ssh_run "sudo systemctl start shiny-server"
    log "Rollback complete."
}

# ---------- pre-flight ----------
log "Target:   $SSH_TARGET:$RICHSTUDIO_PATH"
log "Branch:   $BRANCH"
log "Snapshot: ${RICHSTUDIO_PATH}.PREV.${TIMESTAMP}"
log "Public:   $RICHSTUDIO_URL"
[ "$DRY_RUN" -eq 1 ] && log "MODE:     DRY-RUN (no changes will be made)"
log ""

log "Checking SSH connectivity..."
ssh_run "echo connected" >/dev/null 2>&1 || fail "cannot ssh to $SSH_TARGET" 2

log "Checking server-side repo state..."
SERVER_STATE=$(ssh_run "cd $RICHSTUDIO_PATH && git status --porcelain 2>&1 | head -5; echo ---; git log -1 --format='%h %s' 2>&1") \
    || fail "$RICHSTUDIO_PATH is not a git checkout on the server. Run one-time setup first (see DEPLOYMENT.md)." 3

CURRENT_SHA=$(ssh_run "cd $RICHSTUDIO_PATH && git rev-parse HEAD")
log "Server currently at: $(echo "$SERVER_STATE" | tail -1)"

log "Fetching origin/$BRANCH on server..."
ssh_run "cd $RICHSTUDIO_PATH && sudo -u $RICHSTUDIO_RUNAS git fetch origin $BRANCH" || fail "git fetch failed" 3

TARGET_SHA=$(ssh_run "cd $RICHSTUDIO_PATH && git rev-parse origin/$BRANCH")
log "origin/$BRANCH resolves to: $TARGET_SHA"

if [ "$CURRENT_SHA" = "$TARGET_SHA" ]; then
    log "Server is already up to date. Nothing to deploy."
    exit 0
fi

log ""
log "Commits about to deploy:"
ssh_run "cd $RICHSTUDIO_PATH && git log --oneline ${CURRENT_SHA}..${TARGET_SHA}"
log ""
log "Files changed:"
ssh_run "cd $RICHSTUDIO_PATH && git diff --stat ${CURRENT_SHA} ${TARGET_SHA}"
log ""

if [ "$DRY_RUN" -eq 1 ]; then
    log "Dry-run complete. No changes made."
    exit 0
fi

# ---------- snapshot ----------
log "Creating PREV snapshot (hardlinked, near-instant)..."
ssh_run "sudo cp -al $RICHSTUDIO_PATH $SNAPSHOT_PATH && sudo chown -R $RICHSTUDIO_RUNAS:$RICHSTUDIO_RUNAS $SNAPSHOT_PATH" \
    || fail "snapshot creation failed" 3
log "Snapshot:  $SNAPSHOT_PATH"

# ---------- pull ----------
log "Stopping shiny-server..."
ssh_run "sudo systemctl stop shiny-server" || fail "could not stop shiny-server" 3

log "Resetting working tree to origin/$BRANCH..."
ssh_run "cd $RICHSTUDIO_PATH && sudo -u $RICHSTUDIO_RUNAS git reset --hard origin/$BRANCH" \
    || { log "git reset failed; restoring from snapshot..."; restore_from_snapshot; fail "git reset failed" 3; }

# ---------- reconcile R deps ----------
log "Running renv::restore() (this may take several minutes)..."
ssh_run "cd $RICHSTUDIO_PATH && sudo -u $RICHSTUDIO_RUNAS R --quiet -e 'options(renv.config.auto.snapshot = FALSE); renv::restore(prompt = FALSE)'" \
    || { log "renv::restore failed; restoring from snapshot..."; restore_from_snapshot; fail "renv::restore failed" 3; }

log "Compiling Rcpp attributes..."
ssh_run "cd $RICHSTUDIO_PATH && sudo -u $RICHSTUDIO_RUNAS R --quiet -e 'Rcpp::compileAttributes()'" \
    || { log "Rcpp::compileAttributes failed; restoring from snapshot..."; restore_from_snapshot; fail "Rcpp compile failed" 3; }

# ---------- restart ----------
if [ "$NO_RESTART" -eq 1 ]; then
    log "--no-restart set; skipping shiny-server start. App will not be live until you run: sudo systemctl start shiny-server"
else
    log "Starting shiny-server..."
    ssh_run "sudo systemctl start shiny-server" || fail "could not start shiny-server" 3
    sleep 2
fi

# ---------- smoke test ----------
log "Smoke test: curl $RICHSTUDIO_URL ..."
HTTP_CODE=$(curl -sk -o /dev/null -w '%{http_code}' --max-time 20 "$RICHSTUDIO_URL" || echo "000")
if [ "$HTTP_CODE" != "200" ] && [ "$HTTP_CODE" != "302" ]; then
    log "ERROR: smoke test returned HTTP $HTTP_CODE"
    log "Recent shiny-server log on server:"
    ssh_run "sudo tail -50 /var/log/shiny-server/richStudio-*.log 2>/dev/null | tail -30" || true
    log ""
    log "Deploy completed but app is not responding. Snapshot preserved at: $SNAPSHOT_PATH"
    log "To roll back:  scripts/rollback.sh --snapshot=$SNAPSHOT_PATH"
    exit 4
fi
log "Smoke test passed (HTTP $HTTP_CODE)"

# ---------- prune old PREV snapshots ----------
log "Pruning PREV snapshots beyond ${RICHSTUDIO_KEEP_PREV}..."
ssh_run "ls -1dt ${RICHSTUDIO_PATH}.PREV.* 2>/dev/null | tail -n +$((RICHSTUDIO_KEEP_PREV + 1)) | xargs -r sudo rm -rf" || true

log ""
log "DEPLOY COMPLETE"
log "  Server:   $SSH_TARGET:$RICHSTUDIO_PATH"
log "  Now at:   $TARGET_SHA"
log "  Was at:   $CURRENT_SHA  (preserved at $SNAPSHOT_PATH)"
log "  Live:     $RICHSTUDIO_URL"
log ""
log "If anything misbehaves, roll back with:"
log "  scripts/rollback.sh"
