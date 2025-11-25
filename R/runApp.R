#' Launch RichStudio shiny app
#'
#' @import Rcpp
#' @export
launch_RichStudio <- function() {
  appDir <- system.file("application", package = "RichStudio")
  if (appDir == "") {
    stop("Could not find application. Try re-installing `RichStudio`.", call. = FALSE)
  }
  shiny::runApp(appDir, display.mode = "normal")
}
