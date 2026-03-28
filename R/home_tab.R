
homeTabUI <- function(id, tabName, app_version = "0.1.6") {
  ns <- NS(id)
  tabItem(
    tabName = tabName,

    # --- Row 1: Compact Hero Banner ---
    fluidRow(
      column(12,
        div(class = "home-hero-compact",
          tags$img(src = "richstudio-logo.svg", alt = "richStudio logo", class = "home-logo"),
          div(
            h1("Welcome to richStudio", class = "home-title"),
            p("Integrative enrichment analysis, clustering, and visualization for functional genomics.",
              class = "home-subtitle"),
            span(class = "version-pill", paste0("v", app_version))
          )
        )
      )
    ),

    # --- Row 2: Quick Start Workflow Stepper ---
    fluidRow(
      column(12,
        div(class = "workflow-stepper",
          h3("Quick Start"),
          div(class = "stepper-container",
            div(class = "step-card",
              span(class = "step-number", "1"),
              div(class = "step-title", "Upload & Enrich"),
              p(class = "step-desc",
                "Upload DEG lists and run GO, KEGG, or Reactome enrichment."),
              span(class = "step-arrow", icon("arrow-right"))
            ),
            div(class = "step-card",
              span(class = "step-number", "2"),
              div(class = "step-title", "Cluster"),
              p(class = "step-desc",
                "Import enrichment results from any tool (clusterProfiler, DAVID, etc.) or enrich here first at Step 1."),
              span(class = "step-arrow", icon("arrow-right"))
            ),
            div(class = "step-card",
              span(class = "step-number", "3"),
              div(class = "step-title", "Visualize & Export"),
              p(class = "step-desc",
                "Explore interactive plots, save sessions, and export results.")
            )
          )
        )
      )
    ),

    # --- Row 3: Features + Links + About (3 equal columns) ---
    fluidRow(
      column(4, class = "home-section",
        box(title = "Key Features", width = 12, status = "primary", solidHeader = TRUE,
          tags$ul(class = "home-list",
            tags$li("GO, KEGG, and Reactome enrichment via richR and bioAnno"),
            tags$li("Import enrichment results from any tool, or enrich here"),
            tags$li("Three clustering algorithms (Hierarchical, DAVID, richR Kappa)"),
            tags$li("Interactive bar, dot, heatmap, and network visualizations")
          )
        )
      ),
      column(4, class = "home-section",
        box(title = "Quick Links", width = 12, status = "info", solidHeader = TRUE,
          tags$ul(class = "link-list-compact",
            tags$li(tags$a(href = "http://hurlab.med.und.edu/", target = "_blank",
              icon("globe"), "Hur Lab Homepage")),
            tags$li(tags$a(href = "https://github.com/hurlab/richStudio", target = "_blank",
              icon("github"), "richStudio on GitHub")),
            tags$li(tags$a(href = "https://github.com/hurlab/richCluster", target = "_blank",
              icon("github"), "richCluster")),
            tags$li(tags$a(href = "https://github.com/guokai8/richR", target = "_blank",
              icon("github"), "richR")),
            tags$li(tags$a(href = "https://github.com/guokai8/bioAnno", target = "_blank",
              icon("github"), "bioAnno"))
          )
        )
      ),
      column(4, class = "home-section",
        box(title = "About", width = 12, status = "info", solidHeader = TRUE,
          div(class = "about-section",
            p("Developed by the",
              tags$a(href = "http://hurlab.med.und.edu/", target = "_blank", "Hur Lab"),
              "at UND School of Medicine & Health Sciences."),
            div(class = "citation-block",
              tags$strong("Citation:"),
              br(),
              "Please cite the richStudio application note and underlying packages",
              " (richR, richCluster, bioAnno)."
            ),
            p(tags$small(
              style = "color: var(--rs-text-muted);",
              paste0("richStudio v", app_version, " | R Shiny | GPL-3 License")
            ))
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
