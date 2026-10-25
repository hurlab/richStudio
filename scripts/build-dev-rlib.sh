#!/usr/bin/env bash
# Build the local CI-matching R library used by scripts/dev-r.sh.
# Mirrors .github/workflows/workspace-quality.yml: Posit PPM noble binaries plus
# Bioconductor 3.23, and the exact scientific archives (sha256-verified, abort on mismatch).
# The library lives outside git and outside ~/R; re-running only fills what is missing.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="${RICHSTUDIO_DEV_RLIB:-$HOME/.local/share/richStudio/rlib-r46-ci}"
CRAN_REPO="https://packagemanager.posit.co/cran/__linux__/noble/latest"
BIOC_VERSION="3.23"

RICHR_URL="https://github.com/hurlab/richR/releases/download/v0.1.5/richR_0.1.5.tar.gz"
RICHR_SHA256="0fdca054567c3e6c0ef51512a11ba755ea3694126aa42cbbb051fed3f1b69abf"
RICHCLUSTER_URL="https://api.github.com/repos/hurlab/richCluster/tarball/a0d1f630fbe64089ab38516116b78962672e6349"
RICHCLUSTER_SHA256="6abe64c1c156368afcd9fbec942fadf80848ba64c00dadeac6b2faff27b73c00"
BIOANNO_URL="https://api.github.com/repos/guokai8/bioAnno/tarball/3c8936033b806b9f40c7028faa80e4971f6d0859"
BIOANNO_SHA256="ddab5c458aee07253aedf26d137caeeb6e548538c1ef14f1d0cb27d4d1dc9da9"

mkdir -p "$LIB"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export R_LIBS_USER="" R_LIBS="$LIB" RENV_CONFIG_AUTOLOADER_ENABLED=FALSE

fetch_verified() { # name url sha256
  curl -fsSL -A richStudio-dev-rlib -o "$TMP/$1.tar.gz" "$2"
  local actual
  actual="$(sha256sum "$TMP/$1.tar.gz" | cut -d' ' -f1)"
  [ "$actual" = "$3" ] || { echo "$1: archive digest mismatch $actual" >&2; exit 1; }
}

fetch_verified richR "$RICHR_URL" "$RICHR_SHA256"
fetch_verified richCluster "$RICHCLUSTER_URL" "$RICHCLUSTER_SHA256"
fetch_verified bioAnno "$BIOANNO_URL" "$BIOANNO_SHA256"

for name in richR richCluster bioAnno; do
  mkdir "$TMP/$name"
  tar -xzf "$TMP/$name.tar.gz" -C "$TMP/$name"
done

# CRAN/Bioconductor dependencies: richStudio Depends/Imports/Suggests, the hard dependencies of
# the pinned archives, and the tools the CI workflow installs.
Rscript --vanilla - "$ROOT/DESCRIPTION" "$LIB" "$CRAN_REPO" "$BIOC_VERSION" \
  "$(ls "$TMP"/richR/*/DESCRIPTION "$TMP"/richCluster/*/DESCRIPTION "$TMP"/bioAnno/*/DESCRIPTION)" <<'R'
args <- commandArgs(TRUE)
desc <- read.dcf(args[[1]]); lib <- args[[2]]
# The user agent makes Posit PPM serve noble binaries instead of source packages.
options(repos = c(CRAN = args[[3]]), Ncpus = max(1L, parallel::detectCores() - 2L),
        HTTPUserAgent = sprintf("R/%s R (%s)", getRversion(),
          paste(getRversion(), R.version["platform"], R.version["arch"], R.version["os"])))
fields <- intersect(c("Depends", "Imports", "Suggests"), colnames(desc))
deps <- tools:::.extract_dependency_package_names(paste(desc[, fields], collapse = ","))
hard <- unlist(lapply(strsplit(args[[5]], "\n")[[1]], function(f) {
  d <- read.dcf(f)
  tools:::.extract_dependency_package_names(paste(d[, intersect(c("Depends", "Imports", "LinkingTo"), colnames(d))], collapse = ","))
}))
deps <- c(deps, hard)
base <- rownames(installed.packages(priority = "base"))
want <- setdiff(unique(c(deps, "remotes", "tidyverse", "pkgload", "later", "testthat", "covr",
                         "lintr", "rcmdcheck", "languageserver", "jsonlite")),
                c(base, "R", "richR", "richCluster", "bioAnno"))
# Install the full dependency closure into LIB itself. BiocManager::install() would skip
# packages that merely exist in a system/user library, which is what this library avoids.
repos <- BiocManager::repositories(version = args[[4]])
repos[["CRAN"]] <- args[[3]]
db <- available.packages(repos = repos)
closure <- unique(c(want, unlist(tools::package_dependencies(want, db = db, recursive = TRUE))))
closure <- setdiff(closure, base)
missing <- setdiff(closure, rownames(installed.packages(lib.loc = lib)))
if (length(missing)) install.packages(missing, lib = lib, repos = repos, dependencies = FALSE)
still <- setdiff(missing, rownames(installed.packages(lib.loc = lib)))
if (length(still)) stop("failed to install: ", paste(still, collapse = ", "))
R

R CMD INSTALL --library="$LIB" "$TMP/richR.tar.gz"
R CMD INSTALL --library="$LIB" "$(dirname "$(ls "$TMP"/bioAnno/*/DESCRIPTION)")"
R CMD INSTALL --library="$LIB" "$(dirname "$(ls "$TMP"/richCluster/*/DESCRIPTION)")"

"$ROOT/scripts/dev-r.sh" true
