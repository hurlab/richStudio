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

# Enable async processing for long-running operations
future::plan(future::multisession, workers = 2)

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

app_version <- "0.1.6"

# UI Definition
ui <- function(request) {
  dashboardPage(
    dashboardHeader(title = "richStudio"),
    dashboardSidebar(
      sidebarMenu(
        menuItem("Home", icon = icon("house"), tabName = "home_tab"),
        tags$li(class = "header", "ANALYSIS"),
        menuItem("Enrichment", icon = icon("flask"), tabName = "enrich_tab_group",
          menuSubItem("Enrich", icon = icon("play-circle"), tabName = "enrich_tab"),
          menuSubItem("Visualize", icon = icon("chart-bar"), tabName = "rr_visualize_tab")
        ),
        menuItem("Clustering", icon = icon("layer-group"), tabName = "cluster_tab_group",
          menuSubItem("Upload files", icon = icon("file-arrow-up"), tabName = "cluster_upload_tab"),
          menuSubItem("Cluster", icon = icon("vials"), tabName = "cluster_tab"),
          menuSubItem("Visualize", icon = icon("chart-line"), tabName = "clus_visualize_tab")
        ),
        tags$li(class = "header", "TOOLS"),
        menuItem("Manage Files", icon = icon("folder-open"), tabName = "update_tab"),
        menuItem("Save/Load", icon = icon("floppy-disk"), tabName = "save_tab"),
        hr(),
        bookmarkButton()
      ),
      # Sidebar footer with lab homepage link
      div(class = "sidebar-footer",
        tags$a(href = "http://hurlab.med.und.edu/", target = "_blank",
          icon("flask-vial", class = "lab-icon"),
          div(
            span("Hur Lab", class = "lab-name"),
            br(),
            span("UND School of Medicine", class = "lab-dept")
          )
        )
      )
    ),

    dashboardBody(
      # Loading overlay — shows immediately, hides when Shiny connects
      div(id = "loading-overlay",
        div(class = "loading-content",
          tags$img(src = "favicon.svg", height = "48", width = "48", class = "loading-logo"),
          h3("richStudio", class = "loading-title"),
          div(class = "loading-spinner"),
          p("Loading application...", class = "loading-text")
        )
      ),

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
        tags$link(rel = "icon", type = "image/svg+xml", href = "favicon.svg"),
        tags$link(rel = "stylesheet", type = "text/css", href = "custom.css"),
        tags$script(HTML("
          $(document).on('shiny:connected', function() {
            // Hide loading overlay with fade
            var $overlay = $('#loading-overlay');
            if ($overlay.length) {
              $overlay.addClass('loaded');
              setTimeout(function() { $overlay.remove(); }, 600);
            }
            // Breadcrumb mapping
            var breadcrumbs = {
              'home_tab': 'Home',
              'enrich_tab': 'Enrichment / Enrich',
              'rr_visualize_tab': 'Enrichment / Visualize',
              'cluster_upload_tab': 'Clustering / Upload Files',
              'cluster_tab': 'Clustering / Cluster',
              'clus_visualize_tab': 'Clustering / Visualize',
              'update_tab': 'Manage Files',
              'save_tab': 'Save / Load'
            };
            // Create breadcrumb element in navbar
            var $bc = $('<div class=\"navbar-breadcrumb\"><span class=\"bc-icon\"></span><span class=\"bc-text\">Home</span></div>');
            $('.navbar-custom-menu').before($bc);
            // Update on tab change
            $(document).on('shown.bs.tab', 'a[data-toggle=\"tab\"]', function() {
              var href = $(this).attr('href') || '';
              var tab = href.replace('#shiny-tab-', '');
              if (breadcrumbs[tab]) {
                $bc.find('.bc-text').text(breadcrumbs[tab]);
              }
            });
            // Also listen for sidebar menu clicks
            $(document).on('click', '.sidebar-menu a[data-toggle=\"tab\"]', function() {
              var href = $(this).attr('href') || '';
              var tab = href.replace('#shiny-tab-', '');
              if (breadcrumbs[tab]) {
                $bc.find('.bc-text').text(breadcrumbs[tab]);
              }
            });
          });
        "))
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

  # Generate unique session ID for debugging concurrent issues
  session_id <- paste0("rs_", format(Sys.time(), "%Y%m%d_%H%M%S"), "_",
                       substr(digest::digest(runif(1)), 1, 8))
  message("[richStudio] Session started: ", session_id)

  # Clean up large reactive values when session ends to free memory
  session$onSessionEnded(function() {
    message("[richStudio] Session ended: ", session_id)
    # Clear contents of each reactiveValues store
    for (nm in names(u_degdfs))   u_degdfs[[nm]]   <- NULL
    for (nm in names(u_rrdfs))    u_rrdfs[[nm]]     <- NULL
    for (nm in names(u_clusdfs))  u_clusdfs[[nm]]   <- NULL
    for (nm in names(u_cluslists)) u_cluslists[[nm]] <- NULL
    for (nm in names(clus_intermed)) clus_intermed[[nm]] <- NULL
    for (nm in names(u_degnames)) u_degnames[[nm]]  <- NULL
    for (nm in names(u_rrnames))  u_rrnames[[nm]]   <- NULL
    for (nm in names(u_clusnames)) u_clusnames[[nm]] <- NULL
    for (nm in names(u_big_degdf)) u_big_degdf[[nm]] <- NULL
    for (nm in names(u_big_rrdf))  u_big_rrdf[[nm]]  <- NULL
    for (nm in names(u_big_clusdf)) u_big_clusdf[[nm]] <- NULL
    gc()
  })

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
