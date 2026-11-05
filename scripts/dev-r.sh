#!/usr/bin/env bash
# Run a command against the local CI-matching R library (see scripts/build-dev-rlib.sh).
# Usage: scripts/dev-r.sh Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-x.R")'
set -euo pipefail

LIB="${RICHSTUDIO_DEV_RLIB:-$HOME/.local/share/richStudio/rlib-r46-ci}"
[ -d "$LIB" ] || { echo "dev-r.sh: $LIB missing; run scripts/build-dev-rlib.sh" >&2; exit 1; }

export R_LIBS_USER="$LIB" R_LIBS="$LIB" RENV_CONFIG_AUTOLOADER_ENABLED=FALSE
Rscript --vanilla -e 'v <- function(p) as.character(packageVersion(p))
  cat(sprintf("dev-r: %s | shiny %s | later %s | richR %s | lib %s\n", R.version.string,
      v("shiny"), v("later"), v("richR"), .libPaths()[[1L]]), file = stderr())'
exec "$@"
