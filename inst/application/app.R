#
# richStudio - Shiny web application for integrative enrichment analysis and visualization
#
# This is the main entry point for the richStudio application.
# It can be run directly or via richStudio::launch_richStudio()
#

# Ensure package code is available when running outside an installed package.
app_root_candidates <- function() {
  wd <- normalizePath(getwd(), mustWork = FALSE)
  candidates <- c(getOption("richStudio.appdir"), wd, dirname(wd),
                  dirname(dirname(wd)), system.file(package = "richStudio"))
  candidates <- unique(as.character(candidates))
  candidates <- candidates[!is.na(candidates) & nzchar(candidates)]
  vapply(candidates, normalizePath, character(1), mustWork = FALSE)
}
app_package_root <- function() {
  for (candidate in app_root_candidates()) {
    description <- file.path(candidate, "DESCRIPTION")
    if (!file.exists(description)) next
    fields <- tryCatch(read.dcf(description, fields = "Package"), error = function(e) NULL)
    if (!is.null(fields) && identical(unname(fields[[1L]]), "richStudio")) return(candidate)
  }
  NULL
}
pkg_root <- app_package_root()
richStudio_namespace <- NULL

if (!is.null(pkg_root) && file.exists(file.path(pkg_root, "DESCRIPTION"))) {
  options(richStudio.appdir = pkg_root)
  if (requireNamespace("richStudio", quietly = TRUE)) {
    library(richStudio)
    richStudio_namespace <- asNamespace("richStudio")
  } else {
    r_dir <- file.path(pkg_root, "R")
    r_files <- list.files(r_dir, pattern = "\\.R$", full.names = TRUE)
    invisible(lapply(r_files, source, chdir = TRUE))
  }
} else if (requireNamespace("richStudio", quietly = TRUE)) {
  library(richStudio)
  richStudio_namespace <- asNamespace("richStudio")
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

# richR and bioAnno are checked at startup so source-run apps can report missing dependencies.
richR_available <- FALSE
bioAnno_available <- FALSE

richR_installed <- requireNamespace("richR", quietly = TRUE)
richR_supported <- richR_installed && utils::packageVersion("richR") >= "0.1.5"
if (richR_supported) {
  library(richR)
  richR_available <- TRUE
} else if (richR_installed) {
  message("Note: richR 0.1.5 or newer is required for enrichment analysis.")
  message("Update with: remotes::install_github('hurlab/richR@9be43abdae556d9f1df128149a70721f08ab7d25')")
} else {
  message("Note: richR package not installed. Enrichment analysis features will be limited.")
  message("Install with: remotes::install_github('hurlab/richR@9be43abdae556d9f1df128149a70721f08ab7d25')")
}

if (requireNamespace("bioAnno", quietly = TRUE)) {
  library(bioAnno)
  bioAnno_available <- TRUE
} else {
  message("Note: bioAnno package not installed. Annotation features will be limited.")
  message("Install with: remotes::install_github('guokai8/bioAnno')")
}

# richCluster is optional - load the supported public API version if available
richCluster_available <- requireNamespace("richCluster", quietly = TRUE) &&
  utils::packageVersion("richCluster") >= "2.0.1"
if (richCluster_available) {
  library(richCluster)
} else if (requireNamespace("richCluster", quietly = TRUE)) {
  message("Note: richCluster 2.0.1 or newer is required for hierarchical and DAVID clustering.")
  message("Update with: install.packages('richCluster')")
} else {
  message("Note: richCluster package not installed. Hierarchical and DAVID clustering methods will not be available.")
  message("Install from CRAN with: install.packages('richCluster')")
}

app_release <- if (!is.null(richStudio_namespace)) {
  base::get("workspace_release_metadata", envir = richStudio_namespace)(pkg_root)
} else {
  workspace_release_metadata(pkg_root)
}
app_version <- app_release$version
app_build <- app_release$build

# UI Definition
ui <- function(request) {
  # Release switch for the workspace navigation (SPEC-WS-003); FALSE keeps the
  # previous Home, menu captions and no header. Stores and results are unaffected.
  workspace_navigation <- isTRUE(getOption("richStudio.workspace_navigation", TRUE))
  figure_breadcrumbs <- if (workspace_navigation) {
    "'rr_visualize_tab': 'Enrichment / Enrichment figures',
              'clus_visualize_tab': 'Clustering / Cluster figures',"
  } else {
    "'rr_visualize_tab': 'Enrichment / Visualize',
              'clus_visualize_tab': 'Clustering / Visualize',"
  }
  dashboardPage(
    dashboardHeader(title = "richStudio"),
    dashboardSidebar(
      workspace_sidebar_menu(enabled = workspace_navigation),
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

      workspace_header_ui("workspace", enabled = workspace_navigation),

      # Analysis job panel (SPEC-WS-006), shown above every tab.
      workspace_jobs_ui("jobs"),

      tabItems(
        homeTabUI("home", tabName = "home_tab", app_version = app_version,
                  app_build = app_build, enabled = workspace_navigation),
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
        if (workspace_navigation) tags$script(HTML("
          document.addEventListener('click', function(event) {
            var link = event.target.closest('.sidebar-menu > li.treeview > a');
            if (!link) return;
            var menu = link.nextElementSibling;
            if (!menu || !menu.classList.contains('treeview-menu')) return;
            event.preventDefault();
            event.stopImmediatePropagation();
            var open = menu.style.display !== 'none';
            menu.style.display = open ? 'none' : 'block';
            menu.classList.toggle('menu-open', !open);
          }, true);
        ")),
        tags$script(HTML(paste0("
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
              ", figure_breadcrumbs, "
              'cluster_upload_tab': 'Clustering / Upload Files',
              'cluster_tab': 'Clustering / Cluster',
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
        ")))
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

  # Session job registry (SPEC-WS-006): owned jobs, admission queue, stale-result
  # guards. Module servers find it in session$userData.
  jobs <- workspace_jobs_registry(session)
  session$userData$workspace_jobs <- jobs
  workspace_jobs_server("jobs", jobs)

  # Generate unique session ID for debugging concurrent issues
  session_id <- paste0("rs_", format(Sys.time(), "%Y%m%d_%H%M%S"), "_",
                       substr(digest::digest(runif(1)), 1, 8))
  message("[richStudio] Session started: ", session_id)

  # Clean up large reactive values when session ends to free memory
  session$onSessionEnded(function() {
    workspace_jobs_close(jobs)
    message("[richStudio] Session ended: ", session_id)
    # Clear contents of each reactiveValues store
    for (nm in shiny::isolate(names(u_degdfs)))   u_degdfs[[nm]]   <- NULL
    for (nm in shiny::isolate(names(u_rrdfs)))    u_rrdfs[[nm]]     <- NULL
    for (nm in shiny::isolate(names(u_clusdfs)))  u_clusdfs[[nm]]   <- NULL
    for (nm in shiny::isolate(names(u_cluslists))) u_cluslists[[nm]] <- NULL
    for (nm in shiny::isolate(names(clus_intermed))) clus_intermed[[nm]] <- NULL
    for (nm in shiny::isolate(names(u_degnames))) u_degnames[[nm]]  <- NULL
    for (nm in shiny::isolate(names(u_rrnames)))  u_rrnames[[nm]]   <- NULL
    for (nm in shiny::isolate(names(u_clusnames))) u_clusnames[[nm]] <- NULL
    for (nm in shiny::isolate(names(u_big_degdf))) u_big_degdf[[nm]] <- NULL
    for (nm in shiny::isolate(names(u_big_rrdf)))  u_big_rrdf[[nm]]  <- NULL
    for (nm in shiny::isolate(names(u_big_clusdf))) u_big_clusdf[[nm]] <- NULL
    gc()
  })

  # Initialize module servers. Home entry actions and the active-workspace header
  # exist only behind the release switch; their state is created per session.
  if (isTRUE(getOption("richStudio.workspace_navigation", TRUE))) {
    workspace_navigation_server(session,
      u_degnames = u_degnames, u_rrnames = u_rrnames,
      u_rrdfs = u_rrdfs, u_big_rrdf = u_big_rrdf
    )
  }

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
    u_clusnames = u_clusnames, u_clusdfs = u_clusdfs, u_cluslists = u_cluslists,
    u_big_rrdf = u_big_rrdf, u_big_clusdf = u_big_clusdf
  )
}

# Installed package applications run outside the package namespace by default.
# Keep app-server lookups within richStudio so its private module servers remain
# available without exporting those implementation functions.
if (!is.null(richStudio_namespace)) {
  ui_environment <- list2env(
    list(app_version = app_version, app_build = app_build),
    parent = richStudio_namespace
  )
  environment(ui) <- ui_environment
  environment(server) <- richStudio_namespace
}

# Run the application
shinyApp(ui = ui, server = server, enableBookmarking = "url")
