
# Quick Start entry actions (SPEC-WS-003). Native buttons only; the demo action
# is the only one that loads data, and nothing here runs an analysis.
homeQuickStartUI <- function(id) {
  ns <- NS(id)
  # h2 keeps the outline valid under the h1; inline values mirror .workflow-stepper h3.
  tags$section(class = "workflow-stepper", `aria-labelledby` = ns("quick_start_heading"),
    h2(id = ns("quick_start_heading"), "Quick Start",
      style = "font-size: 18px; font-weight: 700; color: var(--rs-text); margin: 0 0 10px;"),
    # #475569 on the page background #f1f5f9 is 6.92:1 (the class colour gives 4.34:1).
    p(class = "step-desc", style = "color: #475569;",
      "Start from any of these. Nothing runs until you choose an action."),
    div(class = "rs-workspace rs-workspace-actions",
      workspace_action(id, "upload_gene_lists", "Upload gene lists"),
      workspace_action(id, "import_results", "Import enrichment results"),
      workspace_action(id, "open_saved", "Open saved analysis"),
      workspace_action(id, "load_demo", "Load demo results")
    ),
    p(class = "step-desc", style = "color: #475569;",
      "Load demo results adds the bundled demo results go1, go2 and kegg1 (example data, not your analysis)."),
    div(role = "status", textOutput(ns("demo_status"))),
    uiOutput(ns("context_actions"))
  )
}

homeTabUI <- function(id, tabName, app_version = NULL, enabled = TRUE, app_build = NULL) {
  ns <- NS(id)
  enabled <- isTRUE(enabled)
  # Enabled-Home accessibility adjustments; with the switch off every helper returns
  # the original markup unchanged.
  link_icon <- function(name) {
    tag <- icon(name)
    if (!enabled) return(tag)
    # Decorative: hidden from assistive technology; the link text names the link.
    tag$attribs$role <- NULL
    tag$attribs[["aria-label"]] <- NULL
    tag$attribs[["aria-hidden"]] <- "true"
    tag
  }
  # .box-title colour is #fff !important on the info header, so the readable colour
  # sits on a child span: #1e293b on #17a2b8 is 4.80:1 (white gives 3.04:1).
  info_title <- function(text) if (enabled) span(style = "color: #1e293b;", text) else text
  quick_start <- if (isTRUE(enabled)) homeQuickStartUI(id) else div(class = "workflow-stepper",
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
  rows <- list(

    # --- Row 1: Compact Hero Banner ---
    fluidRow(
      column(12,
        div(class = "home-hero-compact",
          tags$img(src = "richstudio-logo.svg", alt = "richStudio logo", class = "home-logo"),
          div(
            h1(id = if (isTRUE(enabled)) ns("title"), "Welcome to richStudio", class = "home-title"),
            p("An interactive platform for functional enrichment analysis, gene set clustering, and visualization.",
              class = "home-subtitle"),
            p("Run GO, KEGG, or Reactome enrichment directly, or import results from tools like clusterProfiler or DAVID. Cluster functionally related terms using multiple algorithms and explore results through interactive plots.",
              class = "home-subtitle"),
            span(class = "version-pill", if (is.null(app_version)) "richStudio" else paste0("v", app_version),
              if (!is.null(app_build)) span(class = "build-id", paste0(" | Build ", app_build)))
          )
        )
      )
    ),

    # --- Row 2: Quick Start (entry actions, or the previous stepper when disabled) ---
    fluidRow(
      column(12, quick_start)
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
        box(title = info_title("Quick Links"), width = 12, status = "info", solidHeader = TRUE,
          tags$ul(class = "link-list-compact",
            tags$li(tags$a(href = "http://hurlab.med.und.edu/", target = "_blank",
              link_icon("globe"), "Hur Lab Homepage")),
            tags$li(tags$a(href = "https://github.com/hurlab/richStudio", target = "_blank",
              link_icon("github"), "richStudio on GitHub")),
            tags$li(tags$a(href = "https://github.com/hurlab/richCluster", target = "_blank",
              link_icon("github"), "richCluster")),
            tags$li(tags$a(href = "https://github.com/hurlab/richR", target = "_blank",
              link_icon("github"), "richR (0.1.5+)")),
            tags$li(tags$a(href = "https://github.com/guokai8/bioAnno", target = "_blank",
              link_icon("github"), "bioAnno"))
          )
        )
      ),
      column(4, class = "home-section",
        box(title = info_title("About"), width = 12, status = "info", solidHeader = TRUE,
          div(class = "about-section",
            # Inline link: underlined so it is distinguishable without colour
            # (#0f6fc5 on the white card is 5.12:1 and stays unchanged).
            p("Developed by the",
              tags$a(href = "http://hurlab.med.und.edu/", target = "_blank",
                style = if (enabled) "text-decoration: underline;", "Hur Lab"),
              "at UND School of Medicine & Health Sciences."),
            p(tags$strong("Team:"), "Junguk Hur, Sarah Hong, Jane Kim, Kai Guo"),
            # #475569 is 6.92:1 on the citation background #f1f5f9 (was 4.34:1).
            div(class = "citation-block", style = if (enabled) "color: #475569;",
              tags$strong("Citation:"),
              br(),
              "Hur J, Hong S, Kim J, Guo K. richStudio: an interactive platform for functional enrichment clustering and visualization. Manuscript in preparation."
            ),
            # #475569 is 7.58:1 on the white card (the muted colour gives 2.56:1).
            p(tags$small(
              style = if (enabled) "color: #475569;" else "color: var(--rs-text-muted);",
              paste0("richStudio", if (!is.null(app_version)) paste0(" v", app_version),
                " | R Shiny | GPL-3 License")
            ))
          )
        )
      )
    )
  )
  # Enabled Home sits in one named landmark; the disabled Home renders as before.
  if (isTRUE(enabled)) {
    return(tabItem(tabName = tabName, tags$section(`aria-labelledby` = ns("title"), rows)))
  }
  do.call(tabItem, c(list(tabName = tabName), rows))
}


# Calls only the supplied callbacks; navigation and demo loading are owned by
# workspace_navigation_server(). has_results/has_gene_lists are reactives.
homeTabServer <- function(id, navigate, load_demo, has_results, has_gene_lists) {

  moduleServer(id, function(input, output, session) {
    demo_status <- reactiveVal("")
    output$demo_status <- renderText(demo_status())

    observeEvent(input$upload_gene_lists, navigate("enrich_tab"))
    observeEvent(input$import_results, navigate("cluster_upload_tab"))
    observeEvent(input$open_saved, navigate("save_tab"))
    observeEvent(input$load_demo, {
      added <- load_demo()
      demo_status(workspace_demo_status(added))
      navigate("rr_visualize_tab")
    })

    # Context actions appear only once the session holds data.
    output$context_actions <- renderUI({
      results <- isTRUE(has_results())
      gene_lists <- isTRUE(has_gene_lists())
      if (!results && !gene_lists) return(NULL)
      div(class = "rs-workspace rs-workspace-actions",
        workspace_action(session$ns(NULL), "view_results", "View results", results,
          "Import or load enrichment results first"),
        workspace_action(session$ns(NULL), "continue_setup", "Continue setup", gene_lists,
          "Upload gene lists first"))
    })
    observeEvent(input$view_results, {
      if (isTRUE(has_results())) navigate("rr_visualize_tab")
    })
    observeEvent(input$continue_setup, {
      if (isTRUE(has_gene_lists())) navigate("enrich_tab")
    })
  })

}
