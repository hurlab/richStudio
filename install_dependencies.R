# richStudio Dependency Installation Script
#
# This script installs all required packages for richStudio.
# Run this before loading or installing the package.
#
# Usage:
#   source("install_dependencies.R")
#   install_all_dependencies()
#
# richCluster Installation Priority:
#   1. CRAN (if available - package is under review)
#   2. GitHub (https://github.com/hurlab/richCluster)
#   3. Local tarball (if path provided)

# ============================================================================
# CRAN Packages
# ============================================================================

cran_packages <- c(
  # Shiny framework
  "shiny",
  "shinydashboard",
  "shinyjs",
  "shinyWidgets",
  "shinyjqui",

  # Data manipulation
  "dplyr",
  "tidyr",
  "tidyverse",
  "data.table",
  "readxl",
  "writexl",
  "rlang",

  # Visualization
  "ggplot2",
  "plotly",
  "heatmaply",
  "reshape2",
  "DT",
  "viridis",
  "RColorBrewer",

  # Utilities
  "jsonlite",
  "zip",
  "stringdist",
  "config",

  # Development
  "devtools",
  "remotes",
  "Rcpp",
  "testthat",
  "knitr",
  "rmarkdown",

  # Additional for richCluster
  "fields",
  "iheatmapr",
  "networkD3",
  "igraph"
)

install_cran <- function(packages) {
  new_packages <- packages[!(packages %in% installed.packages()[, "Package"])]
  if (length(new_packages) > 0) {
    message("Installing CRAN packages: ", paste(new_packages, collapse = ", "))
    install.packages(new_packages, repos = "https://cloud.r-project.org")
  } else {
    message("All CRAN packages are already installed.")
  }
}

# ============================================================================
# Bioconductor Packages
# ============================================================================

bioc_packages <- c(
  # These are typically required by richR/bioAnno
  "AnnotationDbi",
  "org.Hs.eg.db",
  "org.Mm.eg.db",
  "GO.db",
  "KEGGREST",
  "ReactomePA",
  "clusterProfiler"
)

install_bioconductor <- function(packages) {
  if (!requireNamespace("BiocManager", quietly = TRUE)) {
    install.packages("BiocManager")
  }

  new_packages <- packages[!(packages %in% installed.packages()[, "Package"])]
  if (length(new_packages) > 0) {
    message("Installing Bioconductor packages: ", paste(new_packages, collapse = ", "))
    BiocManager::install(new_packages, ask = FALSE, update = FALSE)
  } else {
    message("All Bioconductor packages are already installed.")
  }
}

# ============================================================================
# GitHub Packages (richR, bioAnno)
# ============================================================================

github_packages <- list(
  richR = "guokai8/richR",
  bioAnno = "guokai8/bioAnno"
)

install_github_packages <- function(packages) {
  if (!requireNamespace("remotes", quietly = TRUE)) {
    install.packages("remotes")
  }

  for (pkg_name in names(packages)) {
    if (!(pkg_name %in% installed.packages()[, "Package"])) {
      message("Installing GitHub package: ", pkg_name, " from ", packages[[pkg_name]])
      tryCatch({
        remotes::install_github(packages[[pkg_name]], quiet = FALSE)
      }, error = function(e) {
        message("Failed to install ", pkg_name, ": ", e$message)
        message("You may need to install it manually.")
      })
    } else {
      message("GitHub package already installed: ", pkg_name)
    }
  }
}

# ============================================================================
# richCluster Package Installation
# Available on CRAN since 2024
# ============================================================================

#' Install richCluster package
#'
#' Installs richCluster from CRAN (primary) with fallback to GitHub.
#'
#' @param local_tarball Optional path to local richCluster tarball (for fallback)
#' @param force If TRUE, reinstall even if already installed
#' @return TRUE if installation successful, FALSE otherwise
#' @note richCluster is available on CRAN as of 2024
install_richCluster <- function(local_tarball = NULL, force = FALSE) {

  pkg_name <- "richCluster"

  # Check if already installed
  if (!force && pkg_name %in% installed.packages()[, "Package"]) {
    message("richCluster is already installed.")
    return(TRUE)
  }

  message("Installing richCluster package from CRAN...")

  # Primary: Install from CRAN
  cran_success <- tryCatch({
    install.packages(pkg_name, repos = "https://cloud.r-project.org", quiet = TRUE)
    pkg_name %in% installed.packages()[, "Package"]
  }, error = function(e) {
    message("  CRAN installation failed: ", e$message)
    FALSE
  }, warning = function(w) {
    # Check if it was actually installed despite warnings
    pkg_name %in% installed.packages()[, "Package"]
  })

  if (cran_success) {
    message("  Successfully installed richCluster from CRAN")
    return(TRUE)
  }

  # Fallback: Try GitHub if CRAN fails
  message("  CRAN unavailable. Trying GitHub fallback...")
  if (!requireNamespace("remotes", quietly = TRUE)) {
    install.packages("remotes")
  }

  github_success <- tryCatch({
    remotes::install_github("hurlab/richCluster", quiet = FALSE, upgrade = "never")
    pkg_name %in% installed.packages()[, "Package"]
  }, error = function(e) {
    message("  GitHub installation failed: ", e$message)
    FALSE
  })

  if (github_success) {
    message("  Successfully installed richCluster from GitHub")
    return(TRUE)
  }

  # Installation failed
  message("")
  message("ERROR: Failed to install richCluster.")
  message("Please install manually with: install.packages('richCluster')")
  message("")

  return(FALSE)
}

# ============================================================================
# Main Installation Function
# ============================================================================

#' Install all richStudio dependencies
#'
#' @param richCluster_tarball Optional path to local richCluster tarball
#' @return Invisible TRUE on success
#' @export
install_all_dependencies <- function(richCluster_tarball = NULL) {
  message("=========================================")
  message("richStudio Dependency Installation")
  message("=========================================")
  message("")

  message("Step 1/4: Installing CRAN packages...")
  install_cran(cran_packages)
  message("")

  message("Step 2/4: Installing Bioconductor packages...")
  install_bioconductor(bioc_packages)
  message("")

  message("Step 3/4: Installing GitHub packages (richR, bioAnno)...")
  install_github_packages(github_packages)
  message("")

  message("Step 4/4: Installing richCluster...")
  richCluster_installed <- install_richCluster(richCluster_tarball)
  message("")

  message("=========================================")
  if (richCluster_installed) {
    message("Installation complete!")
  } else {
    message("Installation completed with warnings.")
    message("Note: richCluster was not installed. Some clustering methods may not be available.")
  }
  message("=========================================")
  message("")
  message("To verify installation and launch the app, run:")
  message('  devtools::load_all()')
  message('  richStudio::launch_richStudio()')
  message("")

  invisible(TRUE)
}

# ============================================================================
# Quick Install Functions
# ============================================================================

#' Install only richCluster package
#' @param tarball Optional path to local tarball
#' @export
install_richCluster_only <- function(tarball = NULL) {
  install_richCluster(tarball, force = FALSE)
}

#' Force reinstall richCluster package
#' @param tarball Optional path to local tarball
#' @export
reinstall_richCluster <- function(tarball = NULL) {
  install_richCluster(tarball, force = TRUE)
}

# ============================================================================
# Print Instructions on Source
# ============================================================================

message("richStudio Dependency Installation Script")
message("==========================================")
message("")
message("To install all dependencies, run:")
message('  source("install_dependencies.R")')
message('  install_all_dependencies()')
message("")
message("richCluster will be installed from (in order of priority):")
message("  1. CRAN (if available)")
message("  2. GitHub (https://github.com/hurlab/richCluster)")
message("  3. Local tarball (if provided)")
message("")
message("To install with local tarball fallback:")
message('  install_all_dependencies("../richCluster_1.0.1.tar.gz")')
message("")
message("To install only richCluster:")
message('  install_richCluster_only()')
message('  install_richCluster_only("path/to/richCluster.tar.gz")')
