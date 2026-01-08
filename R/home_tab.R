
homeTabUI <- function(id, tabName, app_version = "0.1.5") {
  ns <- NS(id)
  tabItem(
    tabName = tabName,
    fluidRow(
      column(12,
        div(class = "home-hero",
          tags$img(src = "richstudio-logo.svg", alt = "richStudio logo", class = "home-logo"),
          div(
            h1(sprintf("Welcome to richStudio v%s", app_version), class = "home-title"),
            p("Integrative enrichment analysis, clustering, and visualization for multi-gene studies.", class = "home-subtitle"),
            span(class = "version-pill", paste0("Version ", app_version))
          )
        )
      )
    ),
    fluidRow(
      column(6, class = "home-section",
        box(title = "What you can do", width = 12, status = "primary", solidHeader = TRUE,
          tags$ul(class = "home-list",
            tags$li("Run GO, KEGG, and Reactome enrichment with richR and bioAnno."),
            tags$li("Cluster functionally related terms with richCluster, hierarchical, or DAVID-style options."),
            tags$li("Explore bar, dot, heatmap, and network visualizations interactively."),
            tags$li("Upload DEGs or enrichment tables and compare multiple analyses side by side."),
            tags$li("Save sessions, export results, and reload completed analyses.")
          )
        ),
        box(title = "Workflows", width = 12, status = "primary", solidHeader = TRUE,
          tags$ul(class = "home-list",
            tags$li("Enrichment: upload DEG lists → choose species and database → run richR/bioAnno → visualize results."),
            tags$li("Clustering: select enrichment results → pick algorithm (richCluster, hierarchical, DAVID) → review seeds and distance matrices → export clusters."),
            tags$li("Sessions: bookmark the URL or save/load sessions to resume where you left off.")
          )
        )
      ),
      column(6, class = "home-section",
        box(title = "Helpful links", width = 12, status = "info", solidHeader = TRUE,
          tags$ul(class = "home-list",
            tags$li(tags$a(href = "https://github.com/hurlab/richStudio", target = "_blank", "Project page")),
            tags$li(tags$a(href = "https://github.com/hurlab/richCluster", target = "_blank", "richCluster algorithms")),
            tags$li(tags$a(href = "https://github.com/guokai8/richR", target = "_blank", "richR enrichment engine")),
            tags$li("bioAnno: install via remotes::install_github(\"guokai8/bioAnno\")")
          )
        )
      )
    )
  )
}


homeTabServer <- function(id) {

  moduleServer(id, function(input, output, session) {
  })

}
