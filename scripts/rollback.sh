#!/usr/bin/env bash
# rollback.sh — instant rollback to the most recent PREV snapshot on the server
#
# Usage:
#   scripts/rollback.sh                                # rollback to most recent PREV
#   scripts/rollback.sh --snapshot=/srv/...PREV.XXX    # rollback to specific snapshot
#   scripts/rollback.sh --list                         # show available snapshots
#   scripts/rollback.sh --dry-run                      # show what would happen
#
# Env overrides:
#   RICHSTUDIO_HOST       — SSH target                  (default: hurlab.med.und.edu)
#   RICHSTUDIO_SSH_USER   — SSH login user              (default: $USER)
#   RICHSTUDIO_PATH       — Server install path         (default: /srv/shiny-server/richStudio)
#   RICHSTUDIO_URL        — Public URL for smoke test   (default: https://hurlab.med.und.edu/richStudio/)
#
# Exit codes:
#   0 — rollback succeeded
#   1 — arg/env error
#   2 — SSH/network failure
#   3 — rollback step failed
#   4 — smoke test failed after rollback (server in unknown state — manual intervention)

set -euo pipefail

RICHSTUDIO_HOST="${RICHSTUDIO_HOST:-hurlab.med.und.edu}"
RICHSTUDIO_SSH_USER="${RICHSTUDIO_SSH_USER:-$USER}"
RICHSTUDIO_PATH="${RICHSTUDIO_PATH:-/srv/shiny-server/richStudio}"
RICHSTUDIO_URL="${RICHSTUDIO_URL:-https://hurlab.med.und.edu/richStudio/}"
SNAPSHOT=""
LIST_ONLY=0
DRY_RUN=0

for arg in "$@"; do
    case "$arg" in
        --snapshot=*) SNAPSHOT="${arg#*=}" ;;
        --list)       LIST_ONLY=1 ;;
        --dry-run)    DRY_RUN=1 ;;
        -h|--help)
            sed -n '2,18p' "$0"
            exit 0
            ;;
        *)
            echo "ERROR: unknown argument: $arg" >&2; exit 1 ;;
    esac
done

SSH_TARGET="${RICHSTUDIO_SSH_USER}@${RICHSTUDIO_HOST}"
log()  { printf '[rollback] %s\n' "$*"; }
fail() { printf '[rollback] ERROR: %s\n' "$*" >&2; exit "${2:-1}"; }

ssh_run() { ssh -o BatchMode=yes -o ConnectTimeout=10 "$SSH_TARGET" "$@"; }

log "Target: $SSH_TARGET:$RICHSTUDIO_PATH"
ssh_run "echo connected" >/dev/null 2>&1 || fail "cannot ssh to $SSH_TARGET" 2

# ---------- list snapshots ----------
SNAPSHOTS=$(ssh_run "ls -1dt ${RICHSTUDIO_PATH}.PREV.* 2>/dev/null || true")
if [ -z "$SNAPSHOTS" ]; then
    fail "no snapshots found matching ${RICHSTUDIO_PATH}.PREV.*. Nothing to roll back to." 1
fi

if [ "$LIST_ONLY" -eq 1 ]; then
    log "Available snapshots (newest first):"
    echo "$SNAPSHOTS"
    log ""
    log "Current server HEAD:"
    ssh_run "cd $RICHSTUDIO_PATH && git log -1 --format='  %h %s (%ar)' 2>/dev/null || echo '  (not a git checkout)'"
    exit 0
fi

# ---------- pick snapshot ----------
if [ -z "$SNAPSHOT" ]; then
    SNAPSHOT=$(echo "$SNAPSHOTS" | head -1)
    log "Selected most recent: $SNAPSHOT"
else
    ssh_run "test -d $SNAPSHOT" || fail "snapshot $SNAPSHOT does not exist on server" 1
fi

log "Rolling back FROM:"
ssh_run "cd $RICHSTUDIO_PATH && git log -1 --format='  %h %s (%ar)' 2>/dev/null || echo '  (current state)'"
log "Rolling back TO:"
ssh_run "cd $SNAPSHOT && git log -1 --format='  %h %s (%ar)' 2>/dev/null || echo '  $SNAPSHOT (no git info)'"

if [ "$DRY_RUN" -eq 1 ]; then
    log "Dry-run complete. No changes made."
    exit 0
fi

# ---------- perform rollback ----------
BAD_SAVE="${RICHSTUDIO_PATH}.BAD.$(date +%Y%m%d-%H%M%S)"
log "Stopping shiny-server..."
ssh_run "sudo systemctl stop shiny-server" || fail "stop failed" 3

log "Saving current (broken) state as $BAD_SAVE..."
ssh_run "sudo mv $RICHSTUDIO_PATH $BAD_SAVE" || fail "could not save current state" 3

log "Promoting snapshot to live..."
ssh_run "sudo mv $SNAPSHOT $RICHSTUDIO_PATH" || {
    log "promote failed; restoring BAD as live..."
    ssh_run "sudo mv $BAD_SAVE $RICHSTUDIO_PATH"
    ssh_run "sudo systemctl start shiny-server"
    fail "rollback failed; original state restored" 3
}

log "Starting shiny-server..."
ssh_run "sudo systemctl start shiny-server" || fail "start failed" 3
sleep 2

# ---------- smoke test ----------
log "Smoke test: curl $RICHSTUDIO_URL ..."
HTTP_CODE=$(curl -sk -o /dev/null -w '%{http_code}' --max-time 20 "$RICHSTUDIO_URL" || echo "000")
if [ "$HTTP_CODE" != "200" ] && [ "$HTTP_CODE" != "302" ]; then
    log "WARNING: smoke test returned HTTP $HTTP_CODE after rollback. App may need manual intervention."
    log "Recent log:"
    ssh_run "sudo tail -30 /var/log/shiny-server/richStudio-*.log 2>/dev/null | tail -20" || true
    exit 4
fi
log "Smoke test passed (HTTP $HTTP_CODE)"

log ""
log "ROLLBACK COMPLETE"
log "  Live now at: $RICHSTUDIO_PATH"
log "  Bad state preserved at: $BAD_SAVE  (inspect, then sudo rm -rf when satisfied)"
log "  Public:      $RICHSTUDIO_URL"
