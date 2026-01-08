#
# richStudio - Shiny web application for integrative enrichment analysis and visualization
#
# This is the main entry point for the richStudio application.
# It can be run directly or via richStudio::launch_richStudio()
#

# Ensure package code is available when running outside an installed package.
pkg_root <- tryCatch(
  normalizePath(file.path(getwd(), "..", ".."), mustWork = TRUE),
  error = function(e) NULL
)

if (!is.null(pkg_root) && file.exists(file.path(pkg_root, "DESCRIPTION"))) {
  options(richStudio.appdir = pkg_root)
  if (requireNamespace("richStudio", quietly = TRUE)) {
    library(richStudio)
  } else {
    r_dir <- file.path(pkg_root, "R")
    r_files <- list.files(r_dir, pattern = "\\.R$", full.names = TRUE)
    invisible(lapply(r_files, source, chdir = TRUE))
  }
}

library(shiny)
library(shinydashboard)
library(shinyjs)

library(Rcpp)

library(config)
library(tidyverse)
library(tidyr)
library(readxl)
library(data.table)
library(ggplot2)
library(dplyr)
library(plotly)
library(heatmaply)
library(reshape2)
library(DT)
library(stringdist)
library(shinyWidgets)
library(shinyjqui)
library(jsonlite)
library(writexl)
library(zip)

# richR and bioAnno are suggested packages - check availability
richR_available <- FALSE
bioAnno_available <- FALSE

if (requireNamespace("richR", quietly = TRUE)) {
  library(richR)
  richR_available <- TRUE
} else {
  message("Note: richR package not installed. Enrichment analysis features will be limited.")
  message("Install with: remotes::install_github('guokai8/richR')")
}

if (requireNamespace("bioAnno", quietly = TRUE)) {
  library(bioAnno)
  bioAnno_available <- TRUE
} else {
  message("Note: bioAnno package not installed. Annotation features will be limited.")
  message("Install with: remotes::install_github('guokai8/bioAnno')")
}

# richCluster is optional - load if available (now on CRAN)
if (requireNamespace("richCluster", quietly = TRUE)) {
  library(richCluster)
} else {
  message("Note: richCluster package not installed. Hierarchical and DAVID clustering methods will not be available.")
  message("Install from CRAN with: install.packages('richCluster')")
}

app_version <- "0.1.5"

# UI Definition
ui <- function(request) {
  dashboardPage(
    dashboardHeader(title = paste0("richStudio v", app_version)),
    dashboardSidebar(
      sidebarMenu(
        menuItem("Home", icon = icon("house"), tabName = "home_tab"),
        menuItem("Enrichment", icon = icon("flask"), tabName = "enrich_tab_group",
          menuSubItem("Enrich", icon = icon("upload"), tabName = "enrich_tab"),
          menuSubItem("Visualize", icon = icon("chart-bar"), tabName = "rr_visualize_tab")
        ),
        menuItem("Clustering", icon = icon("layer-group"), tabName = "cluster_tab_group",
          menuSubItem("Upload files", icon = icon("upload"), tabName = "cluster_upload_tab"),
          menuSubItem("Cluster", icon = icon("vials"), tabName = "cluster_tab"),
          menuSubItem("Visualize", icon = icon("chart-line"), tabName = "clus_visualize_tab")
        ),
        menuItem("Manage Files", icon = icon("folder-open"), tabName = "update_tab"),
        menuItem("Save/Load", icon = icon("save"), tabName = "save_tab"),
        hr(),
        bookmarkButton()
      )
    ),

    dashboardBody(
      # Enable shinyjs
      shinyjs::useShinyjs(),

      tabItems(
        homeTabUI("home", tabName = "home_tab", app_version = app_version),
        enrichTabUI("enrich", tabName = "enrich_tab"),
        rrVisTabUI("rr_visualize", tabName = "rr_visualize_tab"),
        clusterUploadTabUI("cluster_upload", tabName = "cluster_upload_tab"),
        clusterTabUI("cluster", tabName = "cluster_tab"),
        clusVisTabUI("clus_visualize", tabName = "clus_visualize_tab"),
        updateTabUI("update", tabName = "update_tab"),
        saveTabUI("save", tabName = "save_tab")
      ),
      tags$head(
        tags$style(
          HTML('
            .content-wrapper { overflow: auto; }
            .dataTables_wrapper { overflow-x: scroll; }
            .box-title { font-size: 18px; }
            .btn-primary { margin-right: 10px; }
            .help-block { font-size: 12px; color: #777; }
          ')
        ),
        tags$link(
          rel = "stylesheet", type = "text/css", href = "custom.css"
        )
      )
    )
  )
}


server <- function(input, output, session) {
  # Create reactive values for DEG sets, enrichment, and cluster results
  u_degnames <- reactiveValues(labels = NULL)   # uploaded deg names
  u_degdfs <- reactiveValues()                  # uploaded deg dataframes
  u_big_degdf <- reactiveValues()               # list of uploaded degs with info

  u_rrnames <- reactiveValues(labels = NULL)    # rich result names
  u_rrdfs <- reactiveValues()                   # rich result dataframes
  u_big_rrdf <- reactiveValues()                # list of uploaded degs with info

  u_clusnames <- reactiveValues(labels = NULL)  # cluster result names
  u_clusdfs <- reactiveValues()                 # cluster result dataframes
  u_big_clusdf <- reactiveValues()              # list of created cluster results with info
  u_cluslists <- reactiveValues()               # cluster info lists
  clus_intermed <- reactiveValues()             # cluster intermediate results

  # Initialize module servers
  homeTabServer("home")

  enrichTabServer("enrich",
    u_degnames = u_degnames, u_degdfs = u_degdfs, u_big_degdf = u_big_degdf,
    u_rrnames = u_rrnames, u_rrdfs = u_rrdfs, u_big_rrdf = u_big_rrdf
  )

  rrVisTabServer("rr_visualize",
    u_degnames = u_degnames, u_degdfs = u_degdfs, u_big_degdf = u_big_degdf,
    u_rrnames = u_rrnames, u_rrdfs = u_rrdfs, u_big_rrdf = u_big_rrdf,
    u_clusnames = u_clusnames, u_clusdfs = u_clusdfs, u_cluslists = u_cluslists
  )

  clusterUploadTabServer("cluster_upload",
    u_degnames = u_degnames, u_degdfs = u_degdfs,
    u_rrnames = u_rrnames, u_rrdfs = u_rrdfs, u_big_rrdf = u_big_rrdf,
    u_clusnames = u_clusnames, u_clusdfs = u_clusdfs,
    u_big_clusdf = u_big_clusdf, u_cluslists = u_cluslists
  )

  clusterTabServer("cluster",
    u_degnames = u_degnames, u_degdfs = u_degdfs,
    u_rrnames = u_rrnames, u_rrdfs = u_rrdfs, u_big_rrdf = u_big_rrdf,
    u_clusnames = u_clusnames, u_clusdfs = u_clusdfs,
    u_big_clusdf = u_big_clusdf, u_cluslists = u_cluslists,
    clus_intermed = clus_intermed
  )

  clusVisTabServer("clus_visualize",
    u_degnames = u_degnames, u_degdfs = u_degdfs,
    u_rrnames = u_rrnames, u_rrdfs = u_rrdfs, u_big_rrdf = u_big_rrdf,
    u_clusnames = u_clusnames, u_clusdfs = u_clusdfs,
    u_big_clusdf = u_big_clusdf, u_cluslists = u_cluslists
  )

  updateTabServer("update",
    u_degnames = u_degnames, u_degdfs = u_degdfs,
    u_rrnames = u_rrnames, u_rrdfs = u_rrdfs,
    u_clusnames = u_clusnames, u_clusdfs = u_clusdfs, u_cluslists = u_cluslists
  )

  saveTabServer("save",
    u_degnames = u_degnames, u_degdfs = u_degdfs,
    u_rrnames = u_rrnames, u_rrdfs = u_rrdfs,
    u_clusnames = u_clusnames, u_clusdfs = u_clusdfs, u_cluslists = u_cluslists
  )
}

# Run the application
shinyApp(ui = ui, server = server, enableBookmarking = "url")
