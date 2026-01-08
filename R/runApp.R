#' Launch richStudio Shiny Application
#'
#' Launches the interactive richStudio Shiny application for functional
#' enrichment analysis and visualization.
#'
#' @return This function does not return a value. It launches a Shiny
#'   application in the user's default web browser.
#'
#' @details
#' The richStudio application provides an interactive interface for:
#' \itemize{
#'   \item Uploading and managing DEG (differentially expressed gene) sets
#'   \item Performing functional enrichment analysis (GO, KEGG, Reactome)
#'   \item Clustering enrichment results using multiple algorithms
#'   \item Visualizing results with interactive plots
#'   \item Saving and loading analysis sessions
#' }
#'
#' @examples
#' if (interactive()) {
#'   launch_richStudio()
#' }
#'
#' @seealso
#' \code{\link{merge_genesets}}, \code{\link{perform_clustering}}
#'
#' @export
launch_richStudio <- function() {
  appDir <- system.file("application", package = "richStudio")
  if (appDir == "") {
    stop("Could not find application. Try re-installing `richStudio`.",
         call. = FALSE)
  }

  shiny::runApp(appDir, display.mode = "normal")
}
