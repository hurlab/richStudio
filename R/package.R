#' @title richStudio: Interactive Visualization and Clustering of Functional
#'   Enrichment Results
#'
#' @description A Shiny application for integrative enrichment analysis and
#'   visualization of multiple gene datasets. richStudio enables users to
#'   perform functional enrichment analysis (GO, KEGG, Reactome), cluster
#'   functionally related terms using multiple algorithms, and visualize
#'   results through interactive plots.
#'
#' @details
#' richStudio provides a complete workflow for functional enrichment analysis:
#'
#' \strong{Enrichment Analysis:}
#' Perform Gene Ontology (GO), KEGG pathway, and Reactome pathway enrichment
#' analysis on one or more gene sets using the richR engine.
#'
#' \strong{Clustering:}
#' Cluster functionally related enrichment terms using multiple algorithms
#' including richR built-in clustering, hierarchical clustering, and DAVID-style
#' grouping.
#'
#' \strong{Visualization:}
#' Generate interactive plots including bar plots, dot plots, integrative
#' heatmaps, and gene-concept network graphs. All plots are powered by plotly
#' for interactivity.
#'
#' \strong{Session Save/Load:}
#' Save and restore complete analysis sessions (DEG sets, enrichment results,
#' clustering results) in RDS or JSON format for reproducibility.
#'
#' @section Dependencies:
#' Key packages required by richStudio:
#' \itemize{
#'   \item \pkg{shiny}, \pkg{shinydashboard} -- Web application framework
#'   \item \pkg{richR}, \pkg{bioAnno} -- Enrichment analysis engine
#'   \item \pkg{plotly}, \pkg{ggplot2}, \pkg{heatmaply} -- Interactive
#'     visualization
#'   \item \pkg{dplyr}, \pkg{tidyr}, \pkg{reshape2} -- Data manipulation
#'   \item \pkg{DT}, \pkg{data.table} -- Data table display
#'   \item \pkg{jsonlite}, \pkg{readxl}, \pkg{writexl} -- File I/O
#' }
#'
#' @keywords internal
#' @useDynLib richStudio
#' @import shiny
#' @import shinydashboard
#' @importFrom dplyr filter arrange rename any_of
#' @importFrom plotly plot_ly layout
#' @importFrom reshape2 melt
#' @importFrom jsonlite read_json write_json
#' @importFrom rlang .data
#' @importFrom utils head
"_PACKAGE"
