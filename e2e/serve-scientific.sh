#!/usr/bin/env bash
set -euo pipefail
root_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
: "${WORKSPACE_INSTALLED_LIBRARY:?Root must supply the frozen installed candidate library}"
export SCIENTIFIC_E2E_PORT=${SCIENTIFIC_E2E_PORT:-3887}
export SCIENTIFIC_E2E_ARTIFACTS=${SCIENTIFIC_E2E_ARTIFACTS:-"$root_dir/.moai/reports/scientific-heatmap-adoption/e2e"}
export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 RENV_CONFIG_AUTOLOADER_ENABLED=FALSE
mkdir -p "$SCIENTIFIC_E2E_ARTIFACTS"
cd "$root_dir"
Rscript --vanilla - <<'R'
expected <- normalizePath(file.path(Sys.getenv("WORKSPACE_INSTALLED_LIBRARY"), "richStudio"))
actual <- normalizePath(find.package("richStudio"))
stopifnot(identical(actual, expected))
jsonlite::write_json(list(
  candidate = actual, version = as.character(packageVersion("richStudio")),
  library_paths = .libPaths(), R = R.version.string,
  app_sha256 = digest::digest(file = system.file("application/app.R", package = "richStudio"), algo = "sha256"),
  package_rdb_sha256 = digest::digest(file = file.path(actual, "R/richStudio.rdb"), algo = "sha256")
), file.path(Sys.getenv("SCIENTIFIC_E2E_ARTIFACTS"), "candidate-runtime.json"), auto_unbox = TRUE, pretty = TRUE)
R
cleanup() {
  if [[ -n ${server_group_pid:-} ]]; then
    kill -TERM -- "-$server_group_pid" 2>/dev/null || true
    wait "$server_group_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT
trap 'exit 143' TERM INT
setsid timeout --kill-after=5s 900s Rscript --vanilla - <<'R' > "$SCIENTIFIC_E2E_ARTIFACTS/shiny.log" 2>&1 &
tryCatch(shiny::runApp(system.file("application", package = "richStudio"),
                       host = "127.0.0.1", port = as.integer(Sys.getenv("SCIENTIFIC_E2E_PORT")),
                       launch.browser = FALSE), finally = future::plan(future::sequential))
R
server_group_pid=$!
wait "$server_group_pid"
