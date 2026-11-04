#!/usr/bin/env bash
# Rebuild a richStudio release against the server's R 4.6 runtime with a fresh,
# release-private library (no R 4.5 fallback), switch the app symlink, and
# restart shiny-server so the old R 4.5 process is replaced.
#
#   bash scripts/deploy-r46-release.sh --preflight --release-sha <sha>
#       As juhur, no sudo: build + verify in ~/richStudio-r46-preflight.<stamp>.
#       Touches nothing live.
#   sudo bash scripts/deploy-r46-release.sh --run-id <token> --release-sha <sha>
#       Full deploy. Previous release and richStudio.PREV.* are left untouched.
set -Eeuo pipefail
umask 022

readonly APP_USER="juhur"
readonly APP_GROUP="juhur"
readonly APP_HOME="/home/juhur"
readonly APP_PATH="/home/juhur/shinyapps/richStudio"
readonly APP_PARENT="/home/juhur/shinyapps"
readonly RELEASE_ROOT="/opt/richStudio/releases"
readonly SHINY_CONFIG="/etc/shiny-server/shiny-server.conf"
readonly SHINY_URL="http://127.0.0.1:3838/richStudio/"
readonly REPO_URL="https://github.com/hurlab/richStudio.git"
readonly EXPECTED_HOST="Hurlab.und.nodak.edu"
readonly EXPECTED_TAILSCALE_IP="100.94.67.89"
readonly EXPECTED_R="4.6.1"
readonly BIOC_VERSION="3.23"
readonly CRAN_BINARY_REPO="https://packagemanager.posit.co/cran/__linux__/noble/latest"
readonly RICHR_URL="https://github.com/hurlab/richR/releases/download/v0.1.5/richR_0.1.5.tar.gz"
readonly RICHR_SHA256="0fdca054567c3e6c0ef51512a11ba755ea3694126aa42cbbb051fed3f1b69abf"
readonly RICHCLUSTER_URL="https://api.github.com/repos/hurlab/richCluster/tarball/a0d1f630fbe64089ab38516116b78962672e6349"
readonly RICHCLUSTER_SHA256="6abe64c1c156368afcd9fbec942fadf80848ba64c00dadeac6b2faff27b73c00"
readonly BIOANNO_URL="https://api.github.com/repos/guokai8/bioAnno/tarball/3c8936033b806b9f40c7028faa80e4971f6d0859"
readonly BIOANNO_SHA256="ddab5c458aee07253aedf26d137caeeb6e548538c1ef14f1d0cb27d4d1dc9da9"
readonly LIB_RELATIVE="renv/library/release-r46"

PREFLIGHT=0
RUN_ID=""
RELEASE_SHA=""

usage() {
    cat <<'EOF'
Usage:
  bash scripts/deploy-r46-release.sh --preflight --release-sha <40-char sha>
  sudo bash scripts/deploy-r46-release.sh --run-id <safe-token> --release-sha <40-char sha>
EOF
}

while (($#)); do
    case "$1" in
        --preflight) PREFLIGHT=1; shift ;;
        --run-id) (($# >= 2)) || { usage >&2; exit 1; }; RUN_ID=$2; shift 2 ;;
        --release-sha) (($# >= 2)) || { usage >&2; exit 1; }; RELEASE_SHA=$2; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; printf 'ERROR: unknown argument: %s\n' "$1" >&2; exit 1 ;;
    esac
done

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[[ "$RELEASE_SHA" =~ ^[0-9a-f]{40}$ ]] || fail 'release SHA must be a full lowercase 40-character commit SHA'
stamp="$(date -u +%Y%m%dT%H%M%SZ)"

if (( PREFLIGHT )); then
    [[ "$(id -un)" == "$APP_USER" ]] || fail "preflight runs as $APP_USER without sudo"
    WORK_ROOT="$APP_HOME/richStudio-r46-preflight.$stamp"
    mkdir -m 0700 -- "$WORK_ROOT"
    LOG_FILE="$WORK_ROOT/preflight.log"
else
    (( EUID == 0 )) || fail 'run the deploy with sudo (or pass --preflight as juhur)'
    [[ "$RUN_ID" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]] || fail '--run-id is required (safe 1-64 character token)'
    RESULT_DIR="/tmp/richstudio-deploy.$RUN_ID"
    mkdir -m 0750 -- "$RESULT_DIR" || fail "result directory already exists: $RESULT_DIR"
    chgrp "$APP_GROUP" "$RESULT_DIR"
    WORK_ROOT="$(mktemp -d /tmp/richstudio-build.XXXXXX)"
    chgrp "$APP_GROUP" "$WORK_ROOT"
    chmod 0770 "$WORK_ROOT"
    LOG_FILE="$RESULT_DIR/deployment.log"
fi
touch "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

as_app_user() {
    local working_directory=$1
    shift
    if (( PREFLIGHT )); then
        (cd "$working_directory" && env HOME="$APP_HOME" "$@")
    else
        runuser -u "$APP_USER" -- env HOME="$APP_HOME" bash -c 'cd "$1" || exit; shift; exec "$@"' _ "$working_directory" "$@"
    fi
}

BUILD_DIR="$WORK_ROOT/repo"
LIB="$BUILD_DIR/$LIB_RELATIVE"
r_build() {
    # Build-time R: release library first, then the R 4.6 site libraries only.
    as_app_user "$BUILD_DIR" env R_ENVIRON_USER=/dev/null R_PROFILE_USER=/dev/null \
        RENV_CONFIG_AUTOLOADER_ENABLED=FALSE R_LIBS_USER="$LIB" "$@"
}

printf 'Mode: %s\nRelease: %s\nWork root: %s\nLog: %s\n' \
    "$([[ $PREFLIGHT == 1 ]] && echo preflight || echo deploy)" "$RELEASE_SHA" "$WORK_ROOT" "$LOG_FILE"

# ---- environment checks -----------------------------------------------------
[[ "$(hostname -f)" == "$EXPECTED_HOST" ]] || fail 'hostname does not match the reviewed server'
[[ "$(tailscale ip -4 2>/dev/null | head -n 1)" == "$EXPECTED_TAILSCALE_IP" ]] || fail 'Tailscale address does not match'
[[ "$(R --version | sed -n '1s/.*version \([0-9.]*\).*/\1/p')" == "$EXPECTED_R" ]] || fail "server R is not $EXPECTED_R"
grep -Eq "^[[:space:]]*app_dir $APP_PATH;$" "$SHINY_CONFIG" || fail 'configured Shiny app directory changed'
grep -Eq '^[[:space:]]*run_as juhur;$' "$SHINY_CONFIG" || fail 'configured app run user changed'
grep -Eq "^[[:space:]]*log_dir $APP_PATH/logs;$" "$SHINY_CONFIG" || fail 'configured app log directory changed'
[[ -L "$APP_PATH" ]] || fail 'app path is not the expected release symlink'
PREVIOUS_TARGET="$(readlink -- "$APP_PATH")"
[[ "$PREVIOUS_TARGET" == "$RELEASE_ROOT"/richStudio-* && -d "$PREVIOUS_TARGET" ]] || fail "app symlink points outside the release root: $PREVIOUS_TARGET"
printf 'Current live target: %s\n' "$PREVIOUS_TARGET"

# ---- exact-commit checkout ---------------------------------------------------
as_app_user "$WORK_ROOT" git init --quiet "$BUILD_DIR"
as_app_user "$BUILD_DIR" git remote add origin "$REPO_URL"
as_app_user "$BUILD_DIR" git fetch --quiet --no-tags --depth 1 origin "$RELEASE_SHA"
as_app_user "$BUILD_DIR" git checkout --quiet --detach FETCH_HEAD
[[ "$(as_app_user "$BUILD_DIR" git rev-parse HEAD)" == "$RELEASE_SHA" ]] || fail 'checked-out commit does not match the release SHA'
[[ ! -e "$BUILD_DIR/.Renviron" ]] || fail 'release already contains a .Renviron'
as_app_user "$BUILD_DIR" mkdir -p "$LIB" logs

# ---- pinned source archives --------------------------------------------------
SRC="$WORK_ROOT/src"
as_app_user "$WORK_ROOT" mkdir "$SRC" "$SRC/richCluster" "$SRC/bioAnno"
fetch() { as_app_user "$WORK_ROOT" curl --fail --location --silent --show-error --proto '=https' --tlsv1.2 --max-time 180 "$1" --output "$2"; }
fetch "$RICHR_URL" "$SRC/richR_0.1.5.tar.gz"
fetch "$RICHCLUSTER_URL" "$SRC/richCluster.tar.gz"
fetch "$BIOANNO_URL" "$SRC/bioAnno.tar.gz"
printf '%s  %s\n' "$RICHR_SHA256" "$SRC/richR_0.1.5.tar.gz" | sha256sum --check --status || fail 'richR archive SHA256 mismatch'
printf '%s  %s\n' "$RICHCLUSTER_SHA256" "$SRC/richCluster.tar.gz" | sha256sum --check --status || fail 'richCluster archive SHA256 mismatch'
printf '%s  %s\n' "$BIOANNO_SHA256" "$SRC/bioAnno.tar.gz" | sha256sum --check --status || fail 'bioAnno archive SHA256 mismatch'
as_app_user "$WORK_ROOT" tar -xzf "$SRC/richCluster.tar.gz" --strip-components=1 -C "$SRC/richCluster"
as_app_user "$WORK_ROOT" tar -xzf "$SRC/bioAnno.tar.gz" --strip-components=1 -C "$SRC/bioAnno"
as_app_user "$WORK_ROOT" tar -xzf "$SRC/richR_0.1.5.tar.gz" -C "$SRC"
[[ -f "$SRC/richR/DESCRIPTION" ]] || fail 'richR archive did not unpack to richR/'

# ---- third-party dependencies (only what the R 4.6 libraries lack) ----------
printf 'Installing missing CRAN (Posit binaries) and Bioconductor %s dependencies into %s\n' "$BIOC_VERSION" "$LIB"
r_build Rscript -e '
  args <- commandArgs(TRUE); lib <- args[[1]]; cran <- args[[2]]; bioc <- args[[3]]; srcs <- args[-(1:3)]
  options(repos = c(CRAN = cran), Ncpus = max(1L, parallel::detectCores() - 2L),
          HTTPUserAgent = sprintf("R/%s R (%s)", getRversion(),
            paste(getRversion(), R.version["platform"], R.version["arch"], R.version["os"])))
  stopifnot(identical(normalizePath(.libPaths()[[1L]]), normalizePath(lib)))
  local_pkgs <- c("richR", "bioAnno", "richCluster", "richStudio")
  fields <- c("Depends", "Imports", "LinkingTo")
  deps <- unlist(lapply(srcs, function(d) {
    desc <- read.dcf(file.path(d, "DESCRIPTION"))
    tools:::.extract_dependency_package_names(paste(desc[, intersect(fields, colnames(desc))], collapse = ","))
  }))
  base <- rownames(installed.packages(priority = "base"))
  deps <- setdiff(unique(c(deps, "testthat")), c(base, "R", local_pkgs))
  missing <- setdiff(deps, rownames(installed.packages()))
  cat("Direct dependencies:", length(deps), " missing:", if (length(missing)) missing else "(none)", "\n")
  if (length(missing)) {
    BiocManager::install(missing, lib = lib, version = bioc, update = FALSE, ask = FALSE, force = FALSE)
    still <- setdiff(missing, rownames(installed.packages()))
    if (length(still)) stop("dependencies failed to install: ", paste(still, collapse = ", "))
  }
  # Shared site libraries still hold packages built under R < 4.6; shadow every
  # such package in the dependency closure with a fresh R 4.6 build in the release library.
  stale_closure <- function() {
    db <- installed.packages()
    closure <- intersect(unique(c(deps, unlist(tools::package_dependencies(deps, db = db, recursive = TRUE)))), rownames(db))
    built <- vapply(closure, function(p) sub("^R ([0-9.]+);.*", "\\1", packageDescription(p)$Built), "")
    names(built)[!startsWith(built, "4.6")]
  }
  stale <- stale_closure()
  cat("Closure packages built for R < 4.6:", if (length(stale)) stale else "(none)", "\n")
  if (length(stale)) {
    BiocManager::install(stale, lib = lib, version = bioc, update = FALSE, ask = FALSE, force = TRUE)
    left <- stale_closure()
    if (length(left)) stop("packages still not built for R 4.6: ", paste(left, collapse = ", "))
  }
' "$LIB" "$CRAN_BINARY_REPO" "$BIOC_VERSION" "$SRC/richR" "$SRC/bioAnno" "$SRC/richCluster" "$BUILD_DIR"

printf 'Building compiled hurlab packages and richStudio from source for R %s\n' "$EXPECTED_R"
for pkg_src in "$SRC/richR_0.1.5.tar.gz" "$SRC/bioAnno" "$SRC/richCluster" "$BUILD_DIR"; do
    r_build R CMD INSTALL --no-test-load --library="$LIB" "$pkg_src"
done

# ---- verification before anything live changes -----------------------------
verify_release() {
    local root=$1
    as_app_user "$root" env R_ENVIRON_USER=/dev/null R_PROFILE_USER=/dev/null RENV_CONFIG_AUTOLOADER_ENABLED=FALSE \
        R_LIBS_USER="$root/$LIB_RELATIVE" Rscript -e '
      lib <- normalizePath(commandArgs(TRUE)[[1L]], mustWork = TRUE)
      stopifnot(identical(normalizePath(.libPaths()[[1L]]), lib))
      if (any(grepl("R-4\\.5|PREV", .libPaths()))) stop("an R 4.5 library is on the search path")
      expected <- c(richR = "0.1.5", bioAnno = "0.99.45", richCluster = "2.0.1")
      for (p in c(names(expected), "richStudio")) {
        stopifnot(startsWith(normalizePath(find.package(p)), paste0(lib, .Platform$file.sep)))
        if (p %in% names(expected)) stopifnot(as.character(packageVersion(p)) == expected[[p]])
      }
      db <- installed.packages()
      closure <- unique(c("richStudio", "richCluster",
        unlist(tools::package_dependencies(c("richStudio", "richCluster"), db = db, recursive = TRUE))))
      closure <- intersect(closure, rownames(db))
      built <- vapply(closure, function(p) sub("^R ([0-9.]+);.*", "\\1", packageDescription(p)$Built), "")
      stale <- built[!startsWith(built, "4.6")]
      if (length(stale)) stop("packages not built for R 4.6: ", paste(names(stale), stale, collapse = ", "))
      invisible(lapply(closure, loadNamespace))
      cat("PASS:", length(closure), "packages in the dependency closure load and are built for R 4.6\n")
    ' "$root/$LIB_RELATIVE"
    as_app_user "$root" env R_ENVIRON_USER=/dev/null R_PROFILE_USER=/dev/null RENV_CONFIG_AUTOLOADER_ENABLED=FALSE \
        R_LIBS_USER="$root/$LIB_RELATIVE" Rscript -e '
      testthat::test_dir("tests/testthat", package = "richStudio", load_package = "installed",
                         filter = "dependency", stop_on_failure = TRUE, reporter = "summary")
      app <- source("app.R", local = new.env(parent = globalenv()))$value
      stopifnot(inherits(app, "shiny.appobj"))
      cat("PASS: dependency tests and Shiny app construction\n")
    '
}
verify_release "$BUILD_DIR"
[[ -z "$(as_app_user "$BUILD_DIR" git status --porcelain --untracked-files=normal | grep -v "^?? $LIB_RELATIVE\|^?? renv/\|^?? logs/" || true)" ]] || fail 'verification changed release files'

if (( PREFLIGHT )); then
    printf 'PREFLIGHT PASS\nNothing live was changed. Build left at %s (delete when done).\n' "$WORK_ROOT"
    exit 0
fi

# ---- finalize a root-owned, read-only release --------------------------------
RELEASE_STAGE="$RELEASE_ROOT/.richStudio-$RELEASE_SHA-$stamp.staging"
RELEASE_DIR="$RELEASE_ROOT/richStudio-$RELEASE_SHA-$stamp"
[[ ! -e "$RELEASE_STAGE" && ! -e "$RELEASE_DIR" ]] || fail 'release destination already exists'
chmod 0750 "$WORK_ROOT"
[[ -z "$(find "$BUILD_DIR" -type l -print -quit)" ]] || fail 'build contains a symbolic link'
mkdir -m 0700 "$RELEASE_STAGE"
cp -a --no-preserve=ownership,mode "$BUILD_DIR/." "$RELEASE_STAGE/"
rm -rf -- "$RELEASE_STAGE/.git"
printf 'RENV_CONFIG_AUTOLOADER_ENABLED=FALSE\nR_LIBS_USER=%s\n' "$RELEASE_DIR/$LIB_RELATIVE" > "$RELEASE_STAGE/.Renviron"
printf '%s\n' "$RELEASE_SHA" > "$RELEASE_STAGE/.release-commit"
printf 'richR %s\nbioAnno %s\nrichCluster %s\n' "$RICHR_SHA256" "$BIOANNO_SHA256" "$RICHCLUSTER_SHA256" \
    > "$RELEASE_STAGE/.dependency-archives.sha256"
chown -R root:root "$RELEASE_STAGE"
chmod -R a+rX,u+w,go-w "$RELEASE_STAGE"
chmod 0444 "$RELEASE_STAGE/.release-commit" "$RELEASE_STAGE/.dependency-archives.sha256"
rm -rf -- "$RELEASE_STAGE/logs"
mkdir -m 0755 "$RELEASE_STAGE/logs"
chown "$APP_USER:$APP_GROUP" "$RELEASE_STAGE/logs"
mv -- "$RELEASE_STAGE" "$RELEASE_DIR"
printf 'Verifying the finalized release at its final path.\n'
verify_release "$RELEASE_DIR"
as_app_user "$RELEASE_DIR" bash -c 'test ! -w "$1/app.R" && test -w "$1/logs"' _ "$RELEASE_DIR" || fail 'release permissions are wrong'

# ---- publish: atomic symlink swap, then full shiny-server restart -----------
[[ "$(readlink -- "$APP_PATH")" == "$PREVIOUS_TARGET" ]] || fail 'live symlink changed during the build'
SWAPPED=0
wait_for_app() {
    local attempt page http_code=000 errors=1
    for attempt in $(seq 1 20); do
        sleep 3
        timeout --kill-after=5s 5s systemctl is-active --quiet shiny-server || continue
        if ! page="$(curl --silent --max-time 30 --write-out '\n%{http_code}' "$SHINY_URL")"; then
            continue
        fi
        http_code="${page##*$'\n'}"
        errors="$(printf '%s' "$page" | grep -c 'An error has occurred' || true)"
        if [[ "$http_code" == 200 && "$errors" == 0 ]]; then
            printf 'HTTP %s, error-page matches %s\n' "$http_code" "$errors"
            return 0
        fi
    done
    printf 'HTTP %s, error-page matches %s\n' "$http_code" "$errors"
    return 1
}
restore_release() {
    local current
    if ! current="$(readlink -- "$APP_PATH")"; then
        printf 'ROLLBACK FAILED: ownership: cannot read live target.\n'
        return 1
    fi
    [[ "$current" != "$PREVIOUS_TARGET" || "$SWAPPED" == 1 ]] || return 0
    if [[ "$current" != "$RELEASE_DIR" && "$current" != "$PREVIOUS_TARGET" ]]; then
        printf 'ROLLBACK FAILED: ownership: unexpected live target %s; left untouched.\n' "$current"
        return 1
    fi
    if [[ "$current" == "$RELEASE_DIR" ]]; then
        printf 'Restoring app symlink to %s.\n' "$PREVIOUS_TARGET"
        if ! { as_app_user "$APP_PARENT" ln -sfn -- "$PREVIOUS_TARGET" "$APP_PATH.swap" &&
               [[ "$(readlink -- "$APP_PATH")" == "$RELEASE_DIR" ]] &&
               as_app_user "$APP_PARENT" mv -T -- "$APP_PATH.swap" "$APP_PATH"; }; then
            printf 'ROLLBACK FAILED: restore: could not restore the previous link.\n'
            return 1
        fi
    fi
    if [[ "$(readlink -- "$APP_PATH")" != "$PREVIOUS_TARGET" ]]; then
        printf 'ROLLBACK FAILED: ownership: previous target is not live; service left untouched.\n'
        return 1
    fi
    # The reviewed server permits 90s each for stop/start; bound the combined operation.
    if ! timeout --kill-after=5s 210s systemctl restart shiny-server; then
        printf 'ROLLBACK FAILED: restart: previous link restored but service restart failed.\n'
        return 1
    fi
    if ! wait_for_app; then
        printf 'ROLLBACK FAILED: health: previous service could not be verified.\n'
        return 1
    fi
    if [[ "$(readlink -- "$APP_PATH")" != "$PREVIOUS_TARGET" ]]; then
        printf 'ROLLBACK FAILED: ownership: live target changed during verification.\n'
        return 1
    fi
    printf 'ROLLBACK VERIFIED: %s; service active and HTTP healthy.\n' "$PREVIOUS_TARGET"
}
deployment_exit() {
    local status=$1
    trap - EXIT
    trap '' INT TERM
    if (( status )); then
        restore_release || true
    fi
    exit "$status"
}
trap 'deployment_exit $?' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
as_app_user "$APP_PARENT" ln -sfn -- "$RELEASE_DIR" "$APP_PATH.swap"
as_app_user "$APP_PARENT" mv -T -- "$APP_PATH.swap" "$APP_PATH"
SWAPPED=1
[[ "$(readlink -- "$APP_PATH")" == "$RELEASE_DIR" ]] || fail 'symlink swap did not land'

printf 'Restarting shiny-server for the new release.\n'
timeout --kill-after=5s 210s systemctl restart shiny-server
wait_for_app || fail 'app did not come up cleanly after restart'
if pgrep -u "$APP_USER" -f 'R-4\.5' >/dev/null; then
    fail 'an R process still references the R 4.5 library'
fi

trap - EXIT INT TERM
printf 'DEPLOY COMPLETE\nRelease: %s\nLive path: %s -> %s\nPrevious release kept: %s\nApp logs: %s/logs\n' \
    "$RELEASE_SHA" "$APP_PATH" "$RELEASE_DIR" "$PREVIOUS_TARGET" "$RELEASE_DIR"
rm -rf -- "$WORK_ROOT"
