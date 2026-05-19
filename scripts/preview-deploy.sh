#!/usr/bin/env bash
# preview-deploy.sh — show exactly what would be deployed without changing anything
#
# Usage:
#   scripts/preview-deploy.sh                  # preview main branch
#   scripts/preview-deploy.sh --branch=develop # preview a specific branch
#
# Env overrides: same as deploy.sh

set -euo pipefail

RICHSTUDIO_HOST="${RICHSTUDIO_HOST:-hurlab.med.und.edu}"
RICHSTUDIO_SSH_USER="${RICHSTUDIO_SSH_USER:-$USER}"
RICHSTUDIO_PATH="${RICHSTUDIO_PATH:-/srv/shiny-server/richStudio}"
RICHSTUDIO_RUNAS="${RICHSTUDIO_RUNAS:-shiny}"
BRANCH="main"

for arg in "$@"; do
    case "$arg" in
        --branch=*) BRANCH="${arg#*=}" ;;
        -h|--help)  sed -n '2,9p' "$0"; exit 0 ;;
        *) echo "unknown arg: $arg" >&2; exit 1 ;;
    esac
done

SSH_TARGET="${RICHSTUDIO_SSH_USER}@${RICHSTUDIO_HOST}"
log() { printf '[preview] %s\n' "$*"; }

ssh_run() { ssh -o BatchMode=yes -o ConnectTimeout=10 "$SSH_TARGET" "$@"; }

log "Server: $SSH_TARGET:$RICHSTUDIO_PATH (branch: $BRANCH)"
log ""

log "Current server HEAD:"
ssh_run "cd $RICHSTUDIO_PATH && git log -1 --format='  %h %s (%an, %ar)'"
log ""

log "Fetching origin/$BRANCH..."
ssh_run "cd $RICHSTUDIO_PATH && sudo -u $RICHSTUDIO_RUNAS git fetch origin $BRANCH" >/dev/null
log ""

log "Commits that would deploy (origin/$BRANCH ahead of server HEAD):"
N=$(ssh_run "cd $RICHSTUDIO_PATH && git rev-list --count HEAD..origin/$BRANCH")
if [ "$N" = "0" ]; then
    log "  (server is up to date)"
    exit 0
fi
ssh_run "cd $RICHSTUDIO_PATH && git log --oneline HEAD..origin/$BRANCH"
log ""

log "Files that would change:"
ssh_run "cd $RICHSTUDIO_PATH && git diff --stat HEAD..origin/$BRANCH"
log ""

log "DESCRIPTION / NAMESPACE diff (renv-relevant):"
ssh_run "cd $RICHSTUDIO_PATH && git diff HEAD..origin/$BRANCH -- DESCRIPTION NAMESPACE 2>/dev/null | head -80 || echo '  (no changes in DESCRIPTION or NAMESPACE)'"
log ""

log "C++ source diff (Rcpp-relevant):"
ssh_run "cd $RICHSTUDIO_PATH && git diff --stat HEAD..origin/$BRANCH -- 'src/*.cpp' 'src/*.h' 2>/dev/null || echo '  (no C++ changes)'"
log ""

log "Estimated post-deploy actions:"
DESC_CHANGED=$(ssh_run "cd $RICHSTUDIO_PATH && git diff --name-only HEAD..origin/$BRANCH | grep -E '^(DESCRIPTION|NAMESPACE|renv\\.lock)$' | wc -l")
CPP_CHANGED=$(ssh_run "cd $RICHSTUDIO_PATH && git diff --name-only HEAD..origin/$BRANCH | grep -E '^src/.*\\.(cpp|h)$' | wc -l")
[ "$DESC_CHANGED" -gt 0 ] && log "  - renv::restore() required (DESCRIPTION/NAMESPACE/renv.lock touched)" \
                          || log "  - renv::restore() optional (no dep changes)"
[ "$CPP_CHANGED" -gt 0 ] && log "  - Rcpp::compileAttributes() required ($CPP_CHANGED C++ files changed)" \
                         || log "  - Rcpp::compileAttributes() optional (no C++ changes)"
log "  - sudo systemctl restart shiny-server"
log ""

log "To deploy:  scripts/deploy.sh --branch=$BRANCH"
log "To dry-run: scripts/deploy.sh --branch=$BRANCH --dry-run"
