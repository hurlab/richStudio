#
# Shiny web application for integrative enrichment analysis and visualization
#

library(shiny)
library(shinydashboard)
library(tidyverse)
library(tools)
library(readxl)
library(data.table)
library(ggplot2)
library(dplyr)
library(plotly)
library(heatmaply)
library(DT)
library(devtools)
library(config)

library(richR)
library(bioAnno)

#Set working directory
# getwd()
# library(rstudioapi)
# current_path <- getActiveDocumentContext()$path
# setwd(dirname(current_path))
# base_dir = dirname(current_path)
# output = "output/"

# Set working directory with config.yml (Fix later)
config_vars <- config::get("hurlab-server")
setwd(config_vars$project_directory)

options(shiny.error = browser)

# Source related scripts
source('deg_enrich.R')
source('rr_column_handling.R')
source('round_table.R')
source('rr_bar.R')
source('rr_dot.R')
source('rr_network.R')
source('rr_cluster.R')
source('rr_hmap.R')
source('cluster_hmap.R')

source('upload_tab.R')
source('update_tab.R')
source('enrich_tab.R')
source('cluster_tab.R')


ui <- dashboardPage(
  dashboardHeader(title = "RichStudio"),
  dashboardSidebar(
    sidebarMenu(
      menuItem("Upload", icon = icon("plus"), tabName = "upload_tab",
        menuSubItem("Upload files", icon=icon("upload"), tabName="upload_files"),
        menuSubItem("Rename/remove files", icon=icon("pencil"), tabName="update_files")
      ),
      menuItem("Enrichment", icon=icon("flask"), tabName = "enrich_tab"),
      menuItem("Clustering", icon=icon("layer-group"), tabName = "cluster_tab")
    )
  ),
  
  dashboardBody(
    tabItems(
      uploadTabUI("upload", tabName="upload_files"),
      updateTabUI("update", tabName="update_files"),
      enrichTabUI("enrich", tabName="enrich_tab"),
      clusterTabUI("cluster", tabName="cluster_tab")
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
      )
    )
  )
)


server <- function(input, output) {
  # Create reactive values for DEG sets, enrichment, and cluster results
  u_degnames <- reactiveValues(labels=NULL)  # uploaded deg names
  u_degdfs <- reactiveValues()  # uploaded deg dataframes
  u_rrnames <- reactiveValues(labels=NULL)  # rich result names
  u_rrdfs <- reactiveValues()  # rich result dataframes
  u_clusnames <- reactiveValues(labels=NULL)  # cluster result names
  u_clusdfs <- reactiveValues()  # cluster result dataframes
  u_cluslists <- reactiveValues()  # cluster info lists
  
  # Server logic
  uploadTabServer("upload", u_degnames=u_degnames, u_degdfs=u_degdfs, 
                  u_rrnames=u_rrnames, u_rrdfs=u_rrdfs, 
                  u_clusnames=u_clusnames, u_clusdfs=u_clusdfs, u_cluslists=u_cluslists)
  updateTabServer("update", u_degnames=u_degnames, u_degdfs=u_degdfs, 
                  u_rrnames=u_rrnames, u_rrdfs=u_rrdfs, 
                  u_clusnames=u_clusnames, u_clusdfs=u_clusdfs, u_cluslists=u_cluslists)
  enrichTabServer("enrich", u_degnames=u_degnames, u_degdfs=u_degdfs, 
                  u_rrnames=u_rrnames, u_rrdfs=u_rrdfs, 
                  u_clusnames=u_clusnames, u_clusdfs=u_clusdfs, u_cluslists=u_cluslists)
  clusterTabServer("cluster", u_degnames=u_degnames, u_degdfs=u_degdfs, 
                   u_rrnames=u_rrnames, u_rrdfs=u_rrdfs, 
                   u_clusnames=u_clusnames, u_clusdfs=u_clusdfs, u_cluslists=u_cluslists)
}

# Run the application 
shinyApp(ui = ui, server = server)



