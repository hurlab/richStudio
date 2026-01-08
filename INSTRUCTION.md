# exclude renv/library and staging directories

rsync -av --delete \
  --exclude 'renv/library' \
  --exclude 'renv/staging' \
  /path/to/project/  user@newserver:/path/to/project/




## Run this in your project root (where renv.lock lives)

# 0) Ensure renv is available at all (bootstrap)
if (!requireNamespace("renv", quietly = TRUE)) {
  install.packages("renv")
}

# 1) Load renv
library(renv)

# 2) Pin renv itself to the version you want for this project
renv::record("renv@1.1.5")
renv::restore(packages = "renv")

# 3) Pin digest to a buildable recent version (fixes your compile failure)
renv::record("digest@0.6.39")
renv::restore(packages = "digest")

# 4) Restore the full project library from the lockfile baseline
renv::restore()

# 5) Update all installed packages to the latest available versions
# (Bioconductor repo setup, safe even if you are CRAN-only)
if (requireNamespace("BiocManager", quietly = TRUE)) {
  options(repos = BiocManager::repositories())
}
renv::update()

# 6) Snapshot so renv.lock matches what is now installed
renv::snapshot(type = "all", prompt = FALSE)

# 7) Quick check
renv::status()

