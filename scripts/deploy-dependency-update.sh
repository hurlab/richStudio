#!/usr/bin/env bash
# Install the reviewed dependency migration as a private release beside the
# current Shiny app, then switch the app path. This script is user-executed.
set -Eeuo pipefail
umask 077

readonly APP_USER="juhur"
readonly APP_GROUP="juhur"
readonly APP_PATH="/home/juhur/shinyapps/richStudio"
readonly APP_PARENT="/home/juhur/shinyapps"
readonly RELEASE_ROOT="/opt/richStudio/releases"
readonly SHINY_CONFIG="/etc/shiny-server/shiny-server.conf"
readonly SHINY_URL="http://127.0.0.1:3838/richStudio/"
readonly EXPECTED_HOST="Hurlab.und.nodak.edu"
readonly EXPECTED_TAILSCALE_IP="100.94.67.89"
readonly EXPECTED_BASELINE="fc124971b004fcbc24a212a40636d34cc57fd587"
readonly RICHR_URL="https://github.com/hurlab/richR/releases/download/v0.1.5/richR_0.1.5.tar.gz"
readonly RICHR_SHA256="0fdca054567c3e6c0ef51512a11ba755ea3694126aa42cbbb051fed3f1b69abf"
readonly RICHCLUSTER_URL="https://api.github.com/repos/hurlab/richCluster/tarball/a0d1f630fbe64089ab38516116b78962672e6349"
readonly RICHCLUSTER_SHA256="6abe64c1c156368afcd9fbec942fadf80848ba64c00dadeac6b2faff27b73c00"
readonly BIOANNO_URL="https://api.github.com/repos/guokai8/bioAnno/tarball/3c8936033b806b9f40c7028faa80e4971f6d0859"
readonly BIOANNO_SHA256="ddab5c458aee07253aedf26d137caeeb6e548538c1ef14f1d0cb27d4d1dc9da9"

BASELINE_SHA=""
RELEASE_SHA=""
RUN_ID=""
RESULT_DIR=""
LOG_FILE=""
STATUS_FILE=""
BUILD_ROOT=""
BUILD_DIR=""
RELEASE_DIR=""
RELEASE_STAGE=""
BACKUP_PATH=""
OVERLAY_LIB=""
BASELINE_LIB=""
APP_MOVED=0
DEPLOY_SUCCEEDED=0

usage() {
    cat <<'EOF'
Usage:
  sudo bash scripts/deploy-dependency-update.sh \
    --run-id <unique-safe-token> \
    --baseline-sha fc124971b004fcbc24a212a40636d34cc57fd587 \
    --release-sha <reviewed-40-character-commit-sha>

The release SHA must identify the validated richStudio migration commit on
origin. This script only fetches that exact SHA; it never deploys a branch tip.
EOF
}

if (($# == 1)) && [[ "$1" == '-h' || "$1" == '--help' ]]; then
    usage
    exit 0
fi

if (( EUID != 0 )); then
    printf 'ERROR: run this script with sudo.\n' >&2
    exit 1
fi

arg_scan=("$@")
while ((${#arg_scan[@]})); do
    case "${arg_scan[0]}" in
        --run-id)
            ((${#arg_scan[@]} >= 2)) || { usage >&2; printf 'ERROR: missing value for --run-id\n' >&2; exit 1; }
            [[ -z "$RUN_ID" ]] || { usage >&2; printf 'ERROR: --run-id may be specified only once\n' >&2; exit 1; }
            RUN_ID=${arg_scan[1]}
            arg_scan=("${arg_scan[@]:2}")
            ;;
        --baseline-sha|--release-sha)
            ((${#arg_scan[@]} >= 2)) || { usage >&2; printf 'ERROR: missing value for %s\n' "${arg_scan[0]}" >&2; exit 1; }
            arg_scan=("${arg_scan[@]:2}")
            ;;
        *) arg_scan=("${arg_scan[@]:1}") ;;
    esac
done
[[ "$RUN_ID" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]] || { usage >&2; printf 'ERROR: --run-id is required and must be a safe 1-64 character token\n' >&2; exit 1; }
[[ -d /tmp && ! -L /tmp && "$(stat -c '%U:%G' /tmp)" == 'root:root' && "$(stat -c '%a' /tmp)" == 1777 ]] || { printf 'ERROR: /tmp is not the expected root-owned sticky directory\n' >&2; exit 1; }
RESULT_DIR="/tmp/richstudio-deploy.$RUN_ID"
mkdir -m 0750 -- "$RESULT_DIR" || { printf 'ERROR: result directory already exists or cannot be created: %s\n' "$RESULT_DIR" >&2; exit 1; }
chgrp "$APP_GROUP" "$RESULT_DIR"
chmod 0750 "$RESULT_DIR"
LOG_FILE="$RESULT_DIR/deployment.log"
STATUS_FILE="$RESULT_DIR/exit-status"
touch "$LOG_FILE"
chgrp "$APP_GROUP" "$LOG_FILE"
chmod 0640 "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1
exec 9>/run/lock/richStudio-dependency-update.lock

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

as_app_user() {
    local working_directory=$1
    shift
    runuser -u "$APP_USER" -- bash -c 'cd "$1" || exit; shift; exec "$@"' _ "$working_directory" "$@"
}

rollback_if_needed() {
    local rc=0
    if (( APP_MOVED )); then
        if [[ ! -e "$BACKUP_PATH" && ! -L "$BACKUP_PATH" && -d "$APP_PATH" && ! -L "$APP_PATH" ]]; then
            APP_MOVED=0
            return 0
        fi
        if [[ -L "$APP_PATH" && "$(readlink -- "$APP_PATH")" == "$RELEASE_DIR" ]]; then
            as_app_user "$APP_PARENT" rm -- "$APP_PATH" || rc=1
        elif [[ -e "$APP_PATH" || -L "$APP_PATH" ]]; then
            printf 'ERROR: live app path changed unexpectedly; leaving it untouched.\n' >&2
            rc=1
        fi
        if [[ -d "$BACKUP_PATH" && ! -e "$APP_PATH" && ! -L "$APP_PATH" ]]; then
            as_app_user "$APP_PARENT" mv -- "$BACKUP_PATH" "$APP_PATH" || rc=1
            if (( rc == 0 )); then
                APP_MOVED=0
                as_app_user "$APP_PATH" touch "$APP_PATH/restart.txt" || rc=1
            fi
        else
            printf 'ERROR: cannot safely restore prior app tree from %s.\n' "$BACKUP_PATH" >&2
            rc=1
        fi
    fi
    return "$rc"
}

finish() {
    local rc=$?
    local status_tmp="$RESULT_DIR/.exit-status.$$"
    trap - EXIT
    trap '' HUP INT TERM
    if (( rc != 0 && DEPLOY_SUCCEEDED == 0 )); then
        printf 'Deployment failed (exit %s); attempting app-path rollback.\n' "$rc"
        if ! rollback_if_needed; then
            printf 'ERROR: automatic rollback needs manual inspection.\n' >&2
            rc=1
        fi
    fi
    printf '%s\n' "$rc" > "$status_tmp" || rc=1
    chmod 0640 "$status_tmp" && chgrp "$APP_GROUP" "$status_tmp" && mv -- "$status_tmp" "$STATUS_FILE" || rc=1
    chmod 0640 "$LOG_FILE"
    printf 'Result log: %s\nExit status: %s\n' "$LOG_FILE" "$STATUS_FILE"
    exit "$rc"
}
trap finish EXIT
on_signal() {
    local signal=$1
    local exit_code=$2
    printf 'Interrupted by %s; finalizing with failure.\n' "$signal" >&2
    exit "$exit_code"
}
trap 'on_signal HUP 129' HUP
trap 'on_signal INT 130' INT
trap 'on_signal TERM 143' TERM
command -v flock >/dev/null || fail 'flock is required to prevent overlapping app updates'
flock -n 9 || fail 'another dependency update is already running'

while (($#)); do
    case "$1" in
        --run-id)
            shift 2
            ;;
        --baseline-sha)
            (($# >= 2)) || { usage >&2; fail 'missing value for --baseline-sha'; }
            BASELINE_SHA=$2
            shift 2
            ;;
        --release-sha)
            (($# >= 2)) || { usage >&2; fail 'missing value for --release-sha'; }
            RELEASE_SHA=$2
            shift 2
            ;;
        *)
            usage >&2
            fail "unknown argument: $1"
            ;;
    esac
done

[[ "$BASELINE_SHA" == "$EXPECTED_BASELINE" ]] || fail 'baseline SHA does not match the reviewed server baseline'
[[ "$RELEASE_SHA" =~ ^[0-9a-f]{40}$ ]] || fail 'release SHA must be a full lowercase 40-character commit SHA'

printf 'Target: %s (%s)\nApp: %s\nBaseline: %s\nRelease: %s\n' \
    "$EXPECTED_HOST" "$EXPECTED_TAILSCALE_IP" "$APP_PATH" "$BASELINE_SHA" "$RELEASE_SHA"
printf 'Private result directory: %s\n' "$RESULT_DIR"

[[ "$(hostname -f)" == "$EXPECTED_HOST" ]] || fail 'hostname does not match the reviewed server'
[[ "$(tailscale ip -4 2>/dev/null | head -n 1)" == "$EXPECTED_TAILSCALE_IP" ]] || fail 'Tailscale address does not match the reviewed server'
[[ -d "$APP_PATH" && ! -L "$APP_PATH" ]] || fail 'app path is not the expected physical checkout'
[[ "$(realpath -- "$APP_PATH")" == "$APP_PATH" ]] || fail 'app path does not resolve to the expected location'
[[ -d "$APP_PARENT" && ! -L "$APP_PARENT" && "$(stat -c '%U' "$APP_PARENT")" == "$APP_USER" ]] || fail 'app parent directory identity changed'
[[ "$(stat -c '%a' "$APP_PARENT")" =~ ^[0-7][0-5][0-5]$ ]] || fail 'app parent directory is group/other writable'
[[ -f "$SHINY_CONFIG" ]] || fail 'Shiny Server configuration is missing'
grep -Eq "^[[:space:]]*app_dir $APP_PATH;$" "$SHINY_CONFIG" || fail 'configured Shiny app directory changed'
grep -Eq '^[[:space:]]*run_as juhur;$' "$SHINY_CONFIG" || fail 'configured app run user changed'
grep -Eq "^[[:space:]]*log_dir $APP_PATH/logs;$" "$SHINY_CONFIG" || fail 'configured app log directory changed'
systemctl is-active --quiet shiny-server || fail 'shiny-server is not active'
[[ "$(R --version | sed -n '1s/.*version \([0-9.]*\).*/\1/p')" == '4.5.2' ]] || fail 'server R runtime is not the reviewed 4.5.2 runtime'

CURRENT_SHA="$(as_app_user "$APP_PATH" git -C "$APP_PATH" rev-parse HEAD)"
[[ "$CURRENT_SHA" == "$BASELINE_SHA" ]] || fail "app checkout moved: expected $BASELINE_SHA, found $CURRENT_SHA"
REMOTE_URL="$(as_app_user "$APP_PATH" git -C "$APP_PATH" remote get-url origin)"
[[ "$REMOTE_URL" == 'https://github.com/hurlab/richStudio.git' ]] || fail 'app origin is not the reviewed repository'
APP_STATUS="$(as_app_user "$APP_PATH" git -C "$APP_PATH" status --porcelain --ignored=traditional --untracked-files=normal)"
if [[ -n "$APP_STATUS" ]]; then
    while IFS= read -r status_line; do
        case "$status_line" in
            '?? .playwright-mcp/'|'!! .playwright-mcp/'|'!! renv/library/'|'!! logs/'|'!! .Renviron'|'?? restart.txt') ;;
            *) printf 'Unexpected app checkout state:\n%s\n' "$status_line" >&2; fail 'refusing to replace the app checkout with unexpected local or ignored content' ;;
        esac
    done <<< "$APP_STATUS"
fi
CONFIG_SHA="$(sha256sum "$SHINY_CONFIG" | awk '{print $1}')"
BASELINE_LIB_OUTPUT="$(as_app_user "$APP_PATH" Rscript -e 'cat("LIBRARY=", normalizePath(.libPaths()[1], mustWork = TRUE), "\n", sep = "")' 2>&1)" || fail 'could not inspect the current project library'
BASELINE_LIB_LINES="$(printf '%s\n' "$BASELINE_LIB_OUTPUT" | sed -n 's/^LIBRARY=//p')"
[[ -n "$BASELINE_LIB_LINES" && "$BASELINE_LIB_LINES" != *$'\n'* ]] || fail 'current project library inspection returned ambiguous output'
BASELINE_LIB="$BASELINE_LIB_LINES"
[[ "$BASELINE_LIB" == "$APP_PATH"/renv/library/* ]] || fail "project library path is outside the expected app renv library: $BASELINE_LIB"
[[ -d "$APP_PATH/logs" && -w "$APP_PATH/logs" ]] || fail 'configured app log directory is not writable'

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
[[ -d /opt && ! -L /opt && "$(stat -c '%U:%G' /opt)" == 'root:root' ]] || fail '/opt is not a physical root-owned directory'
[[ "$(stat -c '%a' /opt)" =~ ^[0-7][0-5][0-5]$ ]] || fail '/opt must not be group/other writable'
if [[ ! -e /opt/richStudio && ! -L /opt/richStudio ]]; then
    install -d -m 0755 -o root -g root /opt/richStudio
fi
[[ -d /opt/richStudio && ! -L /opt/richStudio ]] || fail '/opt/richStudio is not a physical directory'
[[ "$(stat -c '%U:%G' /opt/richStudio)" == 'root:root' ]] || fail '/opt/richStudio is not root-owned'
[[ "$(stat -c '%a' /opt/richStudio)" =~ ^[0-7][0-5][0-5]$ ]] || fail '/opt/richStudio must not be group/other writable'
if [[ ! -e "$RELEASE_ROOT" && ! -L "$RELEASE_ROOT" ]]; then
    install -d -m 0755 -o root -g root "$RELEASE_ROOT"
fi
[[ -d "$RELEASE_ROOT" && ! -L "$RELEASE_ROOT" ]] || fail 'release root is not a physical directory'
[[ "$(stat -c '%U:%G' "$RELEASE_ROOT")" == 'root:root' ]] || fail 'release root is not root-owned'
[[ "$(stat -c '%a' "$RELEASE_ROOT")" =~ ^7[0-5][0-5]$ ]] || fail 'release root must not be group/other writable'
BUILD_ROOT="$(mktemp -d /tmp/richstudio-build.XXXXXX)"
chgrp "$APP_GROUP" "$BUILD_ROOT"
chmod 0730 "$BUILD_ROOT"
BUILD_DIR="$BUILD_ROOT/repo"
as_app_user "$BUILD_ROOT" mkdir "$BUILD_DIR"
RELEASE_STAGE="$RELEASE_ROOT/.richStudio-$RELEASE_SHA-$stamp.staging"
RELEASE_DIR="$RELEASE_ROOT/richStudio-$RELEASE_SHA-$stamp"
[[ ! -e "$RELEASE_STAGE" && ! -L "$RELEASE_STAGE" && ! -e "$RELEASE_DIR" && ! -L "$RELEASE_DIR" ]] || fail 'release destination already exists'
BACKUP_PATH="${APP_PATH}.PREV.${stamp}"
[[ ! -e "$BACKUP_PATH" && ! -L "$BACKUP_PATH" ]] || fail 'backup path already exists'

printf 'Building exact release commit in private staging %s\n' "$BUILD_DIR"
as_app_user "$(dirname "$BUILD_DIR")" git clone --no-checkout --no-hardlinks "$APP_PATH" "$BUILD_DIR"
as_app_user "$BUILD_DIR" git remote set-url origin "$REMOTE_URL"
as_app_user "$BUILD_DIR" git fetch --no-tags origin "$RELEASE_SHA"
FETCHED_SHA="$(as_app_user "$BUILD_DIR" git -C "$BUILD_DIR" rev-parse FETCH_HEAD)"
[[ "$FETCHED_SHA" == "$RELEASE_SHA" ]] || fail 'fetched commit does not match the requested immutable release SHA'
as_app_user "$BUILD_DIR" git -C "$BUILD_DIR" merge-base --is-ancestor "$BASELINE_SHA" "$RELEASE_SHA" || fail 'release commit is not descended from the reviewed baseline'
as_app_user "$BUILD_DIR" git checkout --detach "$RELEASE_SHA"
[[ "$(as_app_user "$BUILD_DIR" git -C "$BUILD_DIR" rev-parse HEAD)" == "$RELEASE_SHA" ]] || fail 'staged checkout SHA mismatch'

OVERLAY_LIB="$BUILD_DIR/renv/library/dependency-overlay"
as_app_user "$BUILD_DIR" mkdir -p "$OVERLAY_LIB" "$BUILD_DIR/logs"
[[ ! -e "$BUILD_DIR/.Renviron" ]] || fail 'release already contains a .Renviron; refusing to overwrite it'
write_renviron() {
    local fallback_library=$1
    local overlay_library=${2:-$OVERLAY_LIB}
    local temporary="$BUILD_DIR/.Renviron.tmp"
    as_app_user "$BUILD_DIR" bash -c '
        printf "RENV_CONFIG_AUTOLOADER_ENABLED=FALSE\\nR_LIBS_USER=%s:%s\\n" "$1" "$2" > "$3"
        chmod 0600 "$3"
        mv -f -- "$3" "$4"
    ' _ "$overlay_library" "$fallback_library" "$temporary" "$BUILD_DIR/.Renviron"
}
write_renviron "$BASELINE_LIB"

RICHR_ARCHIVE="$RESULT_DIR/richR_0.1.5.tar.gz"
RICHCLUSTER_ARCHIVE="$RESULT_DIR/richCluster-a0d1f630.tar.gz"
RICHCLUSTER_SOURCE="$BUILD_ROOT/src-richCluster"
BIOANNO_ARCHIVE="$RESULT_DIR/bioAnno-3c893603.tar.gz"
BIOANNO_SOURCE="$BUILD_ROOT/src-bioAnno"
curl --fail --location --silent --show-error --proto '=https' --tlsv1.2 --max-time 180 \
    "$RICHR_URL" --output "$RICHR_ARCHIVE"
curl --fail --location --silent --show-error --proto '=https' --tlsv1.2 --max-time 180 \
    "$RICHCLUSTER_URL" --output "$RICHCLUSTER_ARCHIVE"
curl --fail --location --silent --show-error --proto '=https' --tlsv1.2 --max-time 180 \
    "$BIOANNO_URL" --output "$BIOANNO_ARCHIVE"
chgrp "$APP_GROUP" "$RICHR_ARCHIVE" "$RICHCLUSTER_ARCHIVE" "$BIOANNO_ARCHIVE"
chmod 0640 "$RICHR_ARCHIVE" "$RICHCLUSTER_ARCHIVE" "$BIOANNO_ARCHIVE"
printf '%s  %s\n' "$RICHR_SHA256" "$RICHR_ARCHIVE" | sha256sum --check --status || fail 'richR source archive SHA256 mismatch'
printf '%s  %s\n' "$RICHCLUSTER_SHA256" "$RICHCLUSTER_ARCHIVE" | sha256sum --check --status || fail 'richCluster source archive SHA256 mismatch'
printf '%s  %s\n' "$BIOANNO_SHA256" "$BIOANNO_ARCHIVE" | sha256sum --check --status || fail 'bioAnno source archive SHA256 mismatch'
as_app_user "$BUILD_ROOT" mkdir "$RICHCLUSTER_SOURCE" "$BIOANNO_SOURCE"
as_app_user "$BUILD_ROOT" tar -xzf "$RICHCLUSTER_ARCHIVE" --strip-components=1 -C "$RICHCLUSTER_SOURCE"
as_app_user "$BUILD_ROOT" tar -xzf "$BIOANNO_ARCHIVE" --strip-components=1 -C "$BIOANNO_SOURCE"

printf 'Installing only the pinned packages and app into the release-private library.\n'
as_app_user "$BUILD_DIR" env R_ENVIRON_USER=/dev/null RENV_CONFIG_AUTOLOADER_ENABLED=FALSE R_LIBS_USER="$OVERLAY_LIB:$BASELINE_LIB" R CMD INSTALL --library="$OVERLAY_LIB" "$RICHR_ARCHIVE"
as_app_user "$BUILD_DIR" env R_ENVIRON_USER=/dev/null RENV_CONFIG_AUTOLOADER_ENABLED=FALSE R_LIBS_USER="$OVERLAY_LIB:$BASELINE_LIB" R CMD INSTALL --library="$OVERLAY_LIB" "$BIOANNO_SOURCE"
as_app_user "$BUILD_DIR" env R_ENVIRON_USER=/dev/null RENV_CONFIG_AUTOLOADER_ENABLED=FALSE R_LIBS_USER="$OVERLAY_LIB:$BASELINE_LIB" R CMD INSTALL --library="$OVERLAY_LIB" "$RICHCLUSTER_SOURCE"
as_app_user "$BUILD_DIR" env R_ENVIRON_USER=/dev/null RENV_CONFIG_AUTOLOADER_ENABLED=FALSE R_LIBS_USER="$OVERLAY_LIB:$BASELINE_LIB" R CMD INSTALL --library="$OVERLAY_LIB" "$BUILD_DIR"

as_app_user "$BUILD_DIR" env R_ENVIRON_USER=/dev/null RENV_CONFIG_AUTOLOADER_ENABLED=FALSE R_LIBS_USER="$OVERLAY_LIB:$BASELINE_LIB" Rscript -e '
  expected <- c(richR = "0.1.5", bioAnno = "0.99.45", richCluster = "2.0.1")
  overlay <- normalizePath(file.path(getwd(), "renv", "library", "dependency-overlay"), mustWork = TRUE)
  libs <- normalizePath(.libPaths(), mustWork = TRUE)
  stopifnot(identical(libs[[1L]], overlay))
  for (p in names(expected)) {
    stopifnot(as.character(utils::packageVersion(p)) == expected[[p]])
    path <- normalizePath(find.package(p), mustWork = TRUE)
    stopifnot(startsWith(path, paste0(overlay, .Platform$file.sep)))
  }
  stopifnot(startsWith(normalizePath(find.package("richStudio"), mustWork = TRUE), paste0(overlay, .Platform$file.sep)))
  invisible(lapply(c(names(expected), "richStudio"), loadNamespace))
  imports <- tools::package_dependencies("richStudio", db = utils::installed.packages(), which = "Imports")[["richStudio"]]
  for (p in c("richStudio", imports)) {
    cat("RESOLVED_PACKAGE ", p, "=", as.character(utils::packageVersion(p)), " path=", normalizePath(find.package(p), mustWork = TRUE), "\n", sep = "")
  }
  cat("PASS: pinned packages and richStudio resolve from the release overlay; R", as.character(getRversion()), "\n")
'

CHANGED_TESTS_OUTPUT="$(as_app_user "$BUILD_DIR" git -C "$BUILD_DIR" diff --name-only --diff-filter=ACMR "$BASELINE_SHA" "$RELEASE_SHA" -- tests/testthat)"
[[ -n "$CHANGED_TESTS_OUTPUT" ]] || fail 'release does not change any scoped dependency tests'
mapfile -t CHANGED_TESTS <<< "$CHANGED_TESTS_OUTPUT"
(( ${#CHANGED_TESTS[@]} > 0 )) || fail 'release does not change any scoped dependency tests'
for test_path in "${CHANGED_TESTS[@]}"; do
    [[ "$test_path" =~ ^tests/testthat/test-dependency[^/]*\.R$ ]] || fail "changed test is outside the reviewed dependency test scope: $test_path"
done
printf 'Running the scoped dependency tests against the installed package before the app path changes.\n'
as_app_user "$BUILD_DIR" env R_ENVIRON_USER=/dev/null RENV_CONFIG_AUTOLOADER_ENABLED=FALSE R_LIBS_USER="$OVERLAY_LIB:$BASELINE_LIB" Rscript -e 'testthat::test_dir("tests/testthat", package = "richStudio", load_package = "installed", filter = "dependency", stop_on_failure = TRUE, reporter = "summary")'
as_app_user "$BUILD_DIR" env R_ENVIRON_USER=/dev/null RENV_CONFIG_AUTOLOADER_ENABLED=FALSE R_LIBS_USER="$OVERLAY_LIB:$BASELINE_LIB" Rscript -e '
  app <- source("app.R", local = new.env(parent = globalenv()))$value
  stopifnot(inherits(app, "shiny.appobj"))
  cat("PASS: staged Shiny app constructs with the release library; R", as.character(getRversion()), "\n")
'
[[ -z "$(as_app_user "$BUILD_DIR" git -C "$BUILD_DIR" status --porcelain --untracked-files=normal)" ]] || fail 'staged tests changed release files'

FALLBACK_RELATIVE="${BASELINE_LIB#"$APP_PATH"/}"
[[ "$FALLBACK_RELATIVE" != "$BASELINE_LIB" ]] || fail 'could not derive the preserved baseline library location'
FALLBACK_LIB="$BACKUP_PATH/$FALLBACK_RELATIVE"
write_renviron "$FALLBACK_LIB" "$RELEASE_DIR/renv/library/dependency-overlay"

# Freeze the app-owned build child through its root-owned parent. Removing the
# parent's app-group write bit makes the child pathname stable before root
# changes its ownership or permissions; the no-dereference chown cannot follow
# a substituted symlink.
chmod 0710 "$BUILD_ROOT"
[[ -d "$BUILD_ROOT" && ! -L "$BUILD_ROOT" && "$(stat -c '%U:%G %a' "$BUILD_ROOT")" == "root:$APP_GROUP 710" ]] || fail 'build parent could not be safely frozen'
[[ -d "$BUILD_DIR" && ! -L "$BUILD_DIR" && "$(stat -c '%U' "$BUILD_DIR")" == "$APP_USER" ]] || fail 'app build child changed ownership or type before finalization'
chown --no-dereference root:root "$BUILD_DIR"
[[ -d "$BUILD_DIR" && ! -L "$BUILD_DIR" && "$(stat -c '%U:%G' "$BUILD_DIR")" == 'root:root' ]] || fail 'app build child could not be safely frozen'
chmod 0700 "$BUILD_DIR"
[[ "$(stat -c '%a' "$BUILD_DIR")" == 700 ]] || fail 'app build child is not private after freezing'
[[ -z "$(find "$BUILD_DIR" -type l -print -quit)" ]] || fail 'staged release contains a symbolic link and cannot be safely finalized'
[[ -z "$(find "$BUILD_DIR" ! -type f ! -type d -print -quit)" ]] || fail 'staged release contains a special file and cannot be safely finalized'

mkdir -m 0700 "$RELEASE_STAGE"
cp -a --no-preserve=ownership,mode "$BUILD_DIR/." "$RELEASE_STAGE/"
[[ -z "$(find "$RELEASE_STAGE" -type l -print -quit)" ]] || fail 'finalization produced a symbolic link'
[[ -z "$(find "$RELEASE_STAGE" ! -type f ! -type d -print -quit)" ]] || fail 'finalization produced a special file'
[[ -d "$RELEASE_STAGE/.git" && ! -L "$RELEASE_STAGE/.git" ]] || fail 'copied Git metadata is not a physical directory'
rm -rf -- "$RELEASE_STAGE/.git"
[[ ! -e "$RELEASE_STAGE/.git" && ! -L "$RELEASE_STAGE/.git" ]] || fail 'could not remove copied Git metadata from the release'
chmod -R a+rX,u+w,go-w "$RELEASE_STAGE"
mkdir -p "$RELEASE_STAGE/logs"
chown "$APP_USER:$APP_GROUP" "$RELEASE_STAGE/logs"
chmod 0755 "$RELEASE_STAGE/logs"
printf '%s\n' "$RELEASE_SHA" > "$RELEASE_STAGE/.release-commit"
chmod 0444 "$RELEASE_STAGE/.release-commit"
printf 'richR %s\nbioAnno %s\nrichCluster %s\n' \
    "$RICHR_SHA256" "$BIOANNO_SHA256" "$RICHCLUSTER_SHA256" > "$RELEASE_STAGE/.dependency-archives.sha256"
chmod 0444 "$RELEASE_STAGE/.dependency-archives.sha256"
[[ "$(stat -c '%U:%G' "$RELEASE_STAGE")" == 'root:root' ]] || fail 'final release stage is not root-owned'
[[ -z "$(find "$RELEASE_STAGE" -path "$RELEASE_STAGE/logs" -prune -o ! -user root -print -quit)" ]] || fail 'release content is not root-owned'
[[ -z "$(find "$RELEASE_STAGE" -path "$RELEASE_STAGE/logs" -prune -o -perm /022 -print -quit)" ]] || fail 'release content is writable by the app user'
as_app_user "$RELEASE_STAGE" bash -c 'test -x "$1" && test -r "$1/app.R" && test -r "$1/.Renviron" && test ! -w "$1" && test ! -w "$1/app.R" && test ! -w "$1/renv/library/dependency-overlay" && test -w "$1/logs"' _ "$RELEASE_STAGE" || fail 'app-user read/write permissions do not match the release policy'
if as_app_user "$RELEASE_STAGE" touch "$RELEASE_STAGE/.permission-probe" 2>/dev/null; then
    fail 'app user unexpectedly wrote into the finalized release root'
fi
[[ ! -e "$RELEASE_STAGE/.permission-probe" ]] || fail 'permission probe left a release artifact'

FINAL_OVERLAY_LIB="$RELEASE_STAGE/renv/library/dependency-overlay"
printf 'Verifying the root-owned finalized release before app publication.\n'
as_app_user "$RELEASE_STAGE" env R_ENVIRON_USER=/dev/null RENV_CONFIG_AUTOLOADER_ENABLED=FALSE R_LIBS_USER="$FINAL_OVERLAY_LIB:$BASELINE_LIB" Rscript -e '
  expected <- c(richR = "0.1.5", bioAnno = "0.99.45", richCluster = "2.0.1")
  overlay <- normalizePath(file.path(getwd(), "renv", "library", "dependency-overlay"), mustWork = TRUE)
  libs <- normalizePath(.libPaths(), mustWork = TRUE)
  stopifnot(identical(libs[[1L]], overlay))
  for (p in names(expected)) {
    stopifnot(as.character(utils::packageVersion(p)) == expected[[p]])
    stopifnot(startsWith(normalizePath(find.package(p), mustWork = TRUE), paste0(overlay, .Platform$file.sep)))
  }
  stopifnot(startsWith(normalizePath(find.package("richStudio"), mustWork = TRUE), paste0(overlay, .Platform$file.sep)))
  invisible(lapply(c(names(expected), "richStudio"), loadNamespace))
  imports <- tools::package_dependencies("richStudio", db = utils::installed.packages(), which = "Imports")[["richStudio"]]
  for (p in c("richStudio", imports)) {
    cat("RESOLVED_PACKAGE ", p, "=", as.character(utils::packageVersion(p)), " path=", normalizePath(find.package(p), mustWork = TRUE), "\n", sep = "")
  }
  cat("PASS: finalized package identities and Imports resolve; R", as.character(getRversion()), "\n")
'
as_app_user "$RELEASE_STAGE" env R_ENVIRON_USER=/dev/null RENV_CONFIG_AUTOLOADER_ENABLED=FALSE R_LIBS_USER="$FINAL_OVERLAY_LIB:$BASELINE_LIB" Rscript -e 'testthat::test_dir("tests/testthat", package = "richStudio", load_package = "installed", filter = "dependency", stop_on_failure = TRUE, reporter = "summary")'
as_app_user "$RELEASE_STAGE" env R_ENVIRON_USER=/dev/null RENV_CONFIG_AUTOLOADER_ENABLED=FALSE R_LIBS_USER="$FINAL_OVERLAY_LIB:$BASELINE_LIB" Rscript -e '
  app <- source("app.R", local = new.env(parent = globalenv()))$value
  stopifnot(inherits(app, "shiny.appobj"))
  cat("PASS: finalized Shiny app constructs with the release library\n")
'
mv -- "$RELEASE_STAGE" "$RELEASE_DIR"
FINAL_OVERLAY_LIB="$RELEASE_DIR/renv/library/dependency-overlay"

[[ "$(hostname -f)" == "$EXPECTED_HOST" ]] || fail 'server hostname changed during staging'
[[ "$(tailscale ip -4 2>/dev/null | head -n 1)" == "$EXPECTED_TAILSCALE_IP" ]] || fail 'Tailscale address changed during staging'
[[ "$(as_app_user "$APP_PATH" git -C "$APP_PATH" rev-parse HEAD)" == "$BASELINE_SHA" ]] || fail 'live app checkout moved during staging'
[[ "$(as_app_user "$APP_PATH" git -C "$APP_PATH" status --porcelain --ignored=traditional --untracked-files=normal)" == "$APP_STATUS" ]] || fail 'live app checkout status changed during staging'
[[ "$(sha256sum "$SHINY_CONFIG" | awk '{print $1}')" == "$CONFIG_SHA" ]] || fail 'Shiny Server configuration changed during staging'
systemctl is-active --quiet shiny-server || fail 'shiny-server state changed during staging'

printf 'Preserving the complete old app tree at %s\n' "$BACKUP_PATH"
[[ -z "$(find "$RELEASE_DIR/logs" -type f -print -quit)" ]] || fail 'release log directory is not empty before publication'
APP_MOVED=1
as_app_user "$APP_PARENT" mv -- "$APP_PATH" "$BACKUP_PATH"
[[ -d "$FALLBACK_LIB" ]] || fail 'preserved baseline library is missing'
as_app_user "$APP_PARENT" ln -s -- "$RELEASE_DIR" "$APP_PATH"
[[ -L "$APP_PATH" && "$(readlink -- "$APP_PATH")" == "$RELEASE_DIR" ]] || fail 'published app path does not point to the reviewed release'

as_app_user "$APP_PATH" env RENV_CONFIG_AUTOLOADER_ENABLED=FALSE R_LIBS_USER="$FINAL_OVERLAY_LIB:$FALLBACK_LIB" Rscript -e '
  expected <- c(richR = "0.1.5", bioAnno = "0.99.45", richCluster = "2.0.1")
  overlay <- normalizePath(file.path(getwd(), "renv", "library", "dependency-overlay"), mustWork = TRUE)
  fallback <- normalizePath(strsplit(Sys.getenv("R_LIBS_USER"), ":", fixed = TRUE)[[1L]][[2L]], mustWork = TRUE)
  libs <- normalizePath(.libPaths(), mustWork = TRUE)
  stopifnot(identical(libs[[1L]], overlay), identical(libs[[2L]], fallback))
  for (p in names(expected)) {
    stopifnot(as.character(utils::packageVersion(p)) == expected[[p]])
    stopifnot(startsWith(normalizePath(find.package(p), mustWork = TRUE), paste0(overlay, .Platform$file.sep)))
  }
  stopifnot(startsWith(normalizePath(find.package("richStudio"), mustWork = TRUE), paste0(overlay, .Platform$file.sep)))
  imports <- tools::package_dependencies("richStudio", db = utils::installed.packages(), which = "Imports")[["richStudio"]]
  for (p in c("richStudio", imports)) {
    cat("RESOLVED_PACKAGE ", p, "=", as.character(utils::packageVersion(p)), " path=", normalizePath(find.package(p), mustWork = TRUE), "\n", sep = "")
  }
  cat("PASS: live app uses the release overlay and preserved baseline fallback\n")
'

RESTART_FILE="$RELEASE_DIR/restart.txt"
touch "$RESTART_FILE"
chmod 0644 "$RESTART_FILE"
printf 'Requesting the app-scoped restart through restart.txt (no shiny-server restart).\n'
http_code="000"
for attempt in 1 2 3 4 5; do
    http_code="$(curl --silent --show-error --output /dev/null --write-out '%{http_code}' --max-time 30 "$SHINY_URL" || true)"
    if [[ "$http_code" == '200' || "$http_code" == '302' ]] && find "$RELEASE_DIR/logs" -type f -print -quit | grep -q .; then
        break
    fi
    sleep 2
done
[[ "$http_code" == '200' || "$http_code" == '302' ]] || fail "app endpoint returned HTTP $http_code; prior app tree will be restored"
candidate_log="$(find "$RELEASE_DIR/logs" -type f -print -quit)"
[[ -n "$candidate_log" ]] || fail 'no candidate app log appeared after the restart request; prior app tree will be restored'
printf 'Candidate app log: %s\n' "$candidate_log"

DEPLOY_SUCCEEDED=1
printf 'SCRIPT CHECKS COMPLETE\nRelease commit: %s\nPrevious tree: %s\nHTTP: %s\nCandidate app log observed; inspect it before a deployed claim.\n' \
    "$RELEASE_SHA" "$BACKUP_PATH" "$http_code"
