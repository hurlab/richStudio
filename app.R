#
# Shiny web application for integrative enrichment analysis and visualization
#

library(shiny)
library(shinydashboard)
library(shinyjs)
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

library(shinyWidgets) # Installed from GitHub

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
source("file_handling.R")
source('deg_enrich.R')
source('rr_column_handling.R')
source('round_table.R')
source('rr_bar.R')
source('rr_dot.R')
source('rr_network.R')
source('rr_cluster.R')
source('rr_hmap.R')
source('cluster_hmap.R')

source('home_tab.R')
source('upload_tab.R')
source('update_tab.R')
source('enrich_tab.R')
source('rr_visualize_tab.R')
source('cluster_tab.R')
source('clus_visualize_tab.R')


ui <- dashboardPage(
  dashboardHeader(title = "RichStudio v0.1.3"),
  dashboardSidebar(
    sidebarMenu(
      menuItem("Home", icon=icon("house"), tabName="home_tab"),
      menuItem("Enrichment", icon=icon("flask"), tabName = "enrich_tab_group",
        menuSubItem("Enrich", icon=icon("upload"), tabName="enrich_tab"),
        menuSubItem("Visualize", icon=icon("dna"), tabName="rr_visualize_tab")
        #menuSubItem("Export", icon=icon("file-export"), tabName="export_rr_tab")
      ),
      menuItem("Clustering", icon=icon("layer-group"), tabName="cluster_tab_group",
        menuSubItem("Cluster", icon=icon("upload"), tabName="cluster_tab"),
        menuSubItem("Visualize", icon=icon("layer-group"), tabName="clus_visualize_tab")
        #menuSubItem("Export", icon=icon("file-export"), tabName="export_cluster_tab")
      )
    )
  ),
  
  dashboardBody(
    tabItems(
      homeTabUI("home", tabName="home_tab"),
      enrichTabUI("enrich", tabName="enrich_tab"),
      rrVisTabUI("rr_visualize", tabName="rr_visualize_tab"),
      clusterTabUI("cluster", tabName="cluster_tab"),
      clusVisTabUI("clus_visualize", tabName="clus_visualize_tab")
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


server <- function(input, output) {
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
  
  # Server logic
  homeTabServer("home")
  uploadTabServer("upload", u_degnames=u_degnames, u_degdfs=u_degdfs, 
                  u_rrnames=u_rrnames, u_rrdfs=u_rrdfs, 
                  u_clusnames=u_clusnames, u_clusdfs=u_clusdfs, u_cluslists=u_cluslists)
  updateTabServer("update", u_degnames=u_degnames, u_degdfs=u_degdfs, 
                  u_rrnames=u_rrnames, u_rrdfs=u_rrdfs, 
                  u_clusnames=u_clusnames, u_clusdfs=u_clusdfs, u_cluslists=u_cluslists)
  enrichTabServer("enrich", u_degnames=u_degnames, u_degdfs=u_degdfs, u_big_degdf=u_big_degdf,
                     u_rrnames=u_rrnames, u_rrdfs=u_rrdfs, u_big_rrdf=u_big_rrdf)
  rrVisTabServer("rr_visualize", u_degnames=u_degnames, u_degdfs=u_degdfs, u_big_degdf=u_big_degdf, 
                  u_rrnames=u_rrnames, u_rrdfs=u_rrdfs, u_big_rrdf=u_big_rrdf,
                  u_clusnames=u_clusnames, u_clusdfs=u_clusdfs, u_cluslists=u_cluslists)
  #uploadRichTabServer()
  clusterTabServer("cluster", u_degnames=u_degnames, u_degdfs=u_degdfs, 
                   u_rrnames=u_rrnames, u_rrdfs=u_rrdfs, u_big_rrdf=u_big_rrdf,
                   u_clusnames=u_clusnames, u_clusdfs=u_clusdfs, u_big_clusdf=u_big_clusdf, u_cluslists=u_cluslists)
  clusVisTabServer("clus_visualize", u_degnames=u_degnames, u_degdfs=u_degdfs, 
                   u_rrnames=u_rrnames, u_rrdfs=u_rrdfs, u_big_rrdf=u_big_rrdf,
                   u_clusnames=u_clusnames, u_clusdfs=u_clusdfs, u_big_clusdf=u_big_clusdf, u_cluslists=u_cluslists)
}

# Run the application 
shinyApp(ui = ui, server = server)



