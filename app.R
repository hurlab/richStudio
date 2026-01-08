# Thin wrapper so Shiny Server can serve the app from the repo root (e.g., /richStudio_3)
if (file.exists("renv/activate.R")) {
  source("renv/activate.R")
}

# Make module functions (homeTabUI, etc.) available whether or not the package is installed.
if (requireNamespace("richStudio", quietly = TRUE)) {
  library(richStudio)
} else if (requireNamespace("devtools", quietly = TRUE)) {
  devtools::load_all(".", export_all = FALSE)
}

library(shiny)

app_dir <- file.path("inst", "application")
if (!dir.exists(app_dir)) {
  stop("richStudio application directory not found at inst/application", call. = FALSE)
}

# Return the packaged app; Shiny Server picks up the shiny.appobj produced here.
shiny::shinyAppDir(app_dir)
