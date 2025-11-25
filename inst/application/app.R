#
# Shiny web application for integrative enrichment analysis and visualization
#

library(shiny)
library(shinydashboard)
library(shinyjs)

library(Rcpp)
library(cpp11)

library(config)
library(tidyverse)
library(readxl)
library(data.table)
library(ggplot2)
library(dplyr)
library(plotly)
library(heatmaply)
library(DT)
library(stringdist)
library(shinyWidgets)
library(shinyjqui)

library(richR)
library(bioAnno)

# Set working directory with config.yml
# config_vars <- config::get("hurlab-server")
# setwd(config_vars$project_directory)
#
# options(shiny.error = browser)

ui <- function(request) {
  dashboardPage(
  dashboardHeader(title = "RichStudio v0.1.5"),
  dashboardSidebar(
    sidebarMenu(
      menuItem("Home", icon=icon("house"), tabName="home_tab"),
      menuItem("Enrichment", icon=icon("flask"), tabName = "enrich_tab_group",
        menuSubItem("Enrich", icon=icon("upload"), tabName="enrich_tab"),
        menuSubItem("Visualize", icon=icon("dna"), tabName="rr_visualize_tab")
      ),
      menuItem("Clustering", icon=icon("layer-group"), tabName="cluster_tab_group",
        menuSubItem("Upload files", icon=icon("upload"), tabName="cluster_upload_tab"),
        menuSubItem("Cluster", icon=icon("vials"), tabName="cluster_tab"),
        menuSubItem("Visualize", icon=icon("layer-group"), tabName="clus_visualize_tab")
      ),
      menuItem("Save", icon=icon("save"), tabName="save_tab"),
      bookmarkButton()
    )
  ),

  dashboardBody(
    tabItems(
      homeTabUI("home", tabName="home_tab"),
      enrichTabUI("enrich", tabName="enrich_tab"),
      rrVisTabUI("rr_visualize", tabName="rr_visualize_tab"),
      clusterUploadTabUI("cluster_upload", tabName="cluster_upload_tab"),
      clusterTabUI("cluster", tabName="cluster_tab"),
      clusVisTabUI("clus_visualize", tabName="clus_visualize_tab"),
      saveTabUI("save", tabName="save_tab")
    ),
    tags$head(
      tags$style(
        HTML('
             .content-wrapper { overflow: auto; }
             .dataTables_wrapper { overflow-x: scroll; }
            ')
      ),
      tags$link(
        rel = "stylesheet", type = "text/css", href = "custom.css"
      ),
      tags$script(HTML("shinyjs.init();"))
    )
  )
)
}


server <- function(input, output, session) {
  # Create reactive values for DEG sets, enrichment, and cluster results
  u_degnames <- reactiveValues(labels=NULL)  # uploaded deg names
  u_degdfs <- reactiveValues()  # uploaded deg dataframes
  u_big_degdf <- reactiveValues() # list of uploaded degs with info

  u_rrnames <- reactiveValues(labels=NULL)  # rich result names
  u_rrdfs <- reactiveValues()  # rich result dataframes
  u_big_rrdf <- reactiveValues() # list of uploaded degs with info

  u_clusnames <- reactiveValues(labels=NULL)  # cluster result names
  u_clusdfs <- reactiveValues()  # cluster result dataframes
  u_big_clusdf <- reactiveValues() # list of created cluster results with info
  u_cluslists <- reactiveValues()  # cluster info lists
  clus_intermed <- reactiveValues() # cluster intermediate results (kappa similarity matrix, etc.)

  # Server logic
  homeTabServer("home")
  enrichTabServer("enrich", u_degnames=u_degnames, u_degdfs=u_degdfs, u_big_degdf=u_big_degdf,
                     u_rrnames=u_rrnames, u_rrdfs=u_rrdfs, u_big_rrdf=u_big_rrdf)
  rrVisTabServer("rr_visualize", u_degnames=u_degnames, u_degdfs=u_degdfs, u_big_degdf=u_big_degdf,
                  u_rrnames=u_rrnames, u_rrdfs=u_rrdfs, u_big_rrdf=u_big_rrdf,
                  u_clusnames=u_clusnames, u_clusdfs=u_clusdfs, u_cluslists=u_cluslists)
  #uploadRichTabServer()
  clusterUploadTabServer("cluster_upload", u_degnames=u_degnames, u_degdfs=u_degdfs,
                   u_rrnames=u_rrnames, u_rrdfs=u_rrdfs, u_big_rrdf=u_big_rrdf,
                   u_clusnames=u_clusnames, u_clusdfs=u_clusdfs, u_big_clusdf=u_big_clusdf, u_cluslists=u_cluslists)
  clusterTabServer("cluster", u_degnames=u_degnames, u_degdfs=u_degdfs,
                   u_rrnames=u_rrnames, u_rrdfs=u_rrdfs, u_big_rrdf=u_big_rrdf,
                   u_clusnames=u_clusnames, u_clusdfs=u_clusdfs, u_big_clusdf=u_big_clusdf, u_cluslists=u_cluslists, clus_intermed=clus_intermed)
  clusVisTabServer("clus_visualize", u_degnames=u_degnames, u_degdfs=u_degdfs,
                   u_rrnames=u_rrnames, u_rrdfs=u_rrdfs, u_big_rrdf=u_big_rrdf,
                   u_clusnames=u_clusnames, u_clusdfs=u_clusdfs, u_big_clusdf=u_big_clusdf, u_cluslists=u_cluslists)
  saveTabServer("save")
}

# Run the application
shinyApp(ui = ui, server = server, enableBookmarking = "url")



