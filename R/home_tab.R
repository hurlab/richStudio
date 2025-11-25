
homeTabUI <- function(id, tabName) {
  ns <- NS(id)
  tabItem(tabName = tabName,
    h1("Welcome to RichStudio v0.1.5!"),
    p("Upload from differential expression geneset (DEG) or enrichment result. Supports kappa clustering and multiple visualizations.")
  )
}


homeTabServer <- function(id) {

  moduleServer(id, function(input, output, session) {


  })

}
