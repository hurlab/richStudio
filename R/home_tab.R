
homeTabUI <- function(id, tabName, app_version = "0.1.5") {
  ns <- NS(id)
  tabItem(
    tabName = tabName,

    # --- Row 1: Hero Banner ---
    fluidRow(
      column(12,
        div(class = "home-hero",
          tags$img(src = "richstudio-logo.svg", alt = "richStudio logo", class = "home-logo"),
          div(
            h1(sprintf("Welcome to richStudio"), class = "home-title"),
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
                "Upload DEG lists, select species and annotation database, then run GO, KEGG, or Reactome enrichment."),
              span(class = "step-arrow", icon("arrow-right"))
            ),
            div(class = "step-card",
              span(class = "step-number", "2"),
              div(class = "step-title", "Cluster"),
              p(class = "step-desc",
                "Group enrichment results by functional similarity using richCluster, hierarchical, or DAVID-style clustering."),
              span(class = "step-arrow", icon("arrow-right"))
            ),
            div(class = "step-card",
              span(class = "step-number", "3"),
              div(class = "step-title", "Visualize & Export"),
              p(class = "step-desc",
                "Explore interactive bar, dot, heatmap, and network plots. Save sessions and export results.")
            )
          )
        )
      )
    ),

    # --- Row 3: Features + Links ---
    fluidRow(
      column(6, class = "home-section",
        box(title = "What you can do", width = 12, status = "primary", solidHeader = TRUE,
          tags$ul(class = "home-list",
            tags$li("Run GO, KEGG, and Reactome enrichment with richR and bioAnno."),
            tags$li("Cluster functionally related terms with three algorithm options."),
            tags$li("Explore bar, dot, heatmap, and network visualizations interactively."),
            tags$li("Upload DEGs or enrichment tables and compare multiple analyses."),
            tags$li("Save sessions, export results, and reload completed analyses.")
          )
        ),
        box(title = "Workflows", width = 12, status = "primary", solidHeader = TRUE,
          tags$ul(class = "home-list",
            tags$li(tags$strong("Enrichment:"),
              " Upload DEG lists, choose species and database, run richR/bioAnno, then visualize results."),
            tags$li(tags$strong("Clustering:"),
              " Select enrichment results, pick algorithm and parameters, review clusters and distance matrices."),
            tags$li(tags$strong("Sessions:"),
              " Bookmark the URL or save/load sessions to resume where you left off.")
          )
        )
      ),
      column(6, class = "home-section",
        box(title = "Helpful Links", width = 12, status = "info", solidHeader = TRUE,
          tags$ul(class = "link-list",
            tags$li(
              tags$a(href = "http://hurlab.med.und.edu/", target = "_blank",
                icon("globe", class = "link-icon"),
                div(
                  div(class = "link-text", "Hur Lab Homepage"),
                  div(class = "link-desc", "UND School of Medicine & Health Sciences")
                )
              )
            ),
            tags$li(
              tags$a(href = "https://github.com/hurlab/richStudio", target = "_blank",
                icon("github", class = "link-icon"),
                div(
                  div(class = "link-text", "richStudio on GitHub"),
                  div(class = "link-desc", "Source code, issues, and documentation")
                )
              )
            ),
            tags$li(
              tags$a(href = "https://github.com/hurlab/richCluster", target = "_blank",
                icon("github", class = "link-icon"),
                div(
                  div(class = "link-text", "richCluster"),
                  div(class = "link-desc", "Clustering algorithms for enrichment results")
                )
              )
            ),
            tags$li(
              tags$a(href = "https://github.com/guokai8/richR", target = "_blank",
                icon("github", class = "link-icon"),
                div(
                  div(class = "link-text", "richR"),
                  div(class = "link-desc", "Enrichment analysis engine")
                )
              )
            ),
            tags$li(
              tags$a(href = "https://github.com/guokai8/bioAnno", target = "_blank",
                icon("github", class = "link-icon"),
                div(
                  div(class = "link-text", "bioAnno"),
                  div(class = "link-desc", "Annotation package (install via remotes)")
                )
              )
            )
          )
        ),
        box(title = "About", width = 12, status = "info", solidHeader = TRUE,
          div(class = "about-section",
            p("richStudio is developed by the",
              tags$a(href = "http://hurlab.med.und.edu/", target = "_blank", "Hur Lab"),
              "at the University of North Dakota School of Medicine & Health Sciences."),
            div(class = "citation-block",
              tags$strong("Citation:"),
              br(),
              "If you use richStudio in your research, please cite the richStudio application note",
              " and the underlying packages (richR, richCluster, bioAnno)."
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
