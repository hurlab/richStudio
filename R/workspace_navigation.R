# Workspace navigation adapters (SPEC-WS-003). Navigation selects an existing
# route or result; it never runs enrichment or clustering. All selection state
# is created per session by workspace_navigation_server(); nothing here is global.

workspace_tabs <- c("home_tab", "enrich_tab", "rr_visualize_tab", "cluster_upload_tab",
                    "cluster_tab", "clus_visualize_tab", "update_tab", "save_tab")
workspace_sidebar_id <- "workspace_sidebar"
workspace_demo_labels <- c("go1", "go2", "kegg1")

# Version comes from the package metadata; deployed builds use their stamped
# release commit, while a source checkout may use git as a development fallback.
workspace_package_root <- function(root = NULL, candidates = NULL) {
  if (is.null(candidates)) {
    wd <- normalizePath(getwd(), mustWork = FALSE)
    candidates <- c(getOption("richStudio.appdir"), wd, dirname(wd),
                    dirname(dirname(wd)), system.file(package = "richStudio"))
  }
  candidates <- unique(as.character(c(root, candidates)))
  candidates <- candidates[!is.na(candidates) & nzchar(candidates)]
  candidates <- vapply(candidates, normalizePath, character(1), mustWork = FALSE)
  candidates <- unique(candidates)
  for (candidate in candidates) {
    description <- file.path(candidate, "DESCRIPTION")
    if (!file.exists(description)) next
    fields <- tryCatch(read.dcf(description, fields = "Package"), error = function(e) NULL)
    if (!is.null(fields) && identical(unname(fields[[1L]]), "richStudio")) return(candidate)
  }
  NULL
}

workspace_release_metadata <- function(root = NULL) {
  root <- workspace_package_root(root)
  description <- if (!is.null(root)) file.path(root, "DESCRIPTION") else NULL
  version <- if (!is.null(description) && file.exists(description)) {
    as.character(read.dcf(description, fields = "Version")[[1L]])
  } else if (requireNamespace("richStudio", quietly = TRUE)) {
    as.character(utils::packageVersion("richStudio"))
  } else {
    NA_character_
  }

  valid_build <- function(value) length(value) == 1L && !is.na(value) &&
    grepl("^[[:xdigit:]]{7,40}$", value)
  release_file <- if (!is.null(root)) file.path(root, ".release-commit") else NULL
  build <- if (!is.null(release_file) && file.exists(release_file)) {
    trimws(readLines(release_file, n = 1L, warn = FALSE))
  } else {
    NA_character_
  }
  if (valid_build(build)) build <- substr(build, 1L, 7L)
  if (!valid_build(build) && !is.null(root) &&
      file.exists(file.path(root, ".git"))) {
    candidate <- tryCatch(system2("git", c("-C", shQuote(root), "rev-parse", "--short", "HEAD"),
                                  stdout = TRUE, stderr = FALSE), error = function(e) character())
    if (length(candidate) == 1L && valid_build(candidate)) build <- substr(candidate, 1L, 7L)
  }
  if (!valid_build(build)) build <- NULL
  if (length(version) != 1L || is.na(version) || !nzchar(version)) version <- NULL
  list(version = version, build = build)
}

# Sidebar menu. Route strings are unchanged in both release-switch states; only
# the two figure captions differ.
workspace_sidebar_menu <- function(enabled = TRUE) {
  figures <- if (isTRUE(enabled)) c("Enrichment figures", "Cluster figures") else c("Visualize", "Visualize")
  shinydashboard::sidebarMenu(id = if (isTRUE(enabled)) workspace_sidebar_id,
    shinydashboard::menuItem("Home", icon = shiny::icon("house"), tabName = "home_tab", selected = TRUE),
    shiny::tags$li(class = "header", "ANALYSIS"),
    shinydashboard::menuItem("Enrichment", icon = shiny::icon("flask"), tabName = "enrich_tab_group",
      startExpanded = TRUE,
      shinydashboard::menuSubItem("Enrich", icon = shiny::icon("play-circle"), tabName = "enrich_tab"),
      shinydashboard::menuSubItem(figures[1], icon = shiny::icon("chart-bar"), tabName = "rr_visualize_tab")
    ),
    shinydashboard::menuItem("Clustering", icon = shiny::icon("layer-group"), tabName = "cluster_tab_group",
      startExpanded = TRUE,
      shinydashboard::menuSubItem("Upload files", icon = shiny::icon("file-arrow-up"), tabName = "cluster_upload_tab"),
      shinydashboard::menuSubItem("Cluster", icon = shiny::icon("vials"), tabName = "cluster_tab"),
      shinydashboard::menuSubItem(figures[2], icon = shiny::icon("chart-line"), tabName = "clus_visualize_tab")
    ),
    shiny::tags$li(class = "header", "TOOLS"),
    shinydashboard::menuItem("Manage Files", icon = shiny::icon("folder-open"), tabName = "update_tab"),
    shinydashboard::menuItem("Save/Load", icon = shiny::icon("floppy-disk"), tabName = "save_tab"),
    shiny::hr(),
    shiny::bookmarkButton()
  )
}

# Validated route change on the top-level sidebar. Unknown names are rejected.
workspace_navigate <- function(session, tab) {
  if (!is.character(tab) || length(tab) != 1L || is.na(tab) || !tab %in% workspace_tabs) {
    return(invisible(FALSE))
  }
  shinydashboard::updateTabItems(session$rootScope(), workspace_sidebar_id, tab)
  invisible(TRUE)
}

# Adds the bundled demo enrichment results exactly as the Enrichment figures
# "Load data" action does, skipping labels already present. Returns added labels.
workspace_load_demo_results <- function(u_rrnames, u_rrdfs, u_big_rrdf) {
  added <- character()
  for (lab in workspace_demo_labels) {
    if (lab %in% u_rrnames$labels) next
    df <- utils::read.delim(sample_rr_path(paste0(lab, ".txt")))
    u_rrdfs[[lab]] <- df
    u_rrnames$labels <- c(u_rrnames$labels, lab)
    u_big_rrdf[["df"]] <- add_file_rrdf(df = u_big_rrdf[["df"]], name = lab, file = TRUE)
    added <- c(added, lab)
  }
  added
}

# Status text naming exactly which bundled names were added and which were not
# added because a result with that name already exists (never replaced).
workspace_demo_status <- function(added) {
  added <- intersect(workspace_demo_labels, added)
  skipped <- setdiff(workspace_demo_labels, added)
  if (!length(skipped)) {
    return(paste0("Added bundled demo results: ", paste(added, collapse = ", "), "."))
  }
  reason <- paste0("Not added because a result with that name already exists: ",
                   paste(skipped, collapse = ", "), ".")
  if (!length(added)) return(paste("No bundled demo results added.", reason))
  paste0("Added bundled demo results: ", paste(added, collapse = ", "), ". ", reason)
}

# Unknown recorded values ("?", "NULL", "NA", "", missing) become one NA.
workspace_recorded_value <- function(value) {
  value <- as.character(value)
  if (length(value) != 1L || is.na(value) || value %in% c("?", "NULL", "NA", "")) {
    return(NA_character_)
  }
  value
}

# Recorded facts for a result name. Only an unambiguous single row is used;
# nothing is inferred from file names, setup selectors or result contents.
workspace_recorded_facts <- function(metadata, name) {
  rows <- integer()
  if (is.data.frame(metadata) && all(c("name", "species", "keytype") %in% names(metadata))) {
    rows <- which(metadata$name %in% name)
  }
  if (length(rows) != 1L) {
    return(list(organism = NA_character_, keytype = NA_character_, unique = FALSE))
  }
  list(organism = workspace_recorded_value(metadata$species[rows]),
       keytype = workspace_recorded_value(metadata$keytype[rows]), unique = TRUE)
}

workspace_header_ui <- function(id = "workspace", enabled = TRUE) {
  if (!isTRUE(enabled)) return(NULL)
  ns <- shiny::NS(id)
  shiny::uiOutput(ns("container"))
}

workspace_header_content_ui <- function(id = "workspace") {
  ns <- shiny::NS(id)
  shiny::tags$section(id = ns("header"), class = "rs-workspace rs-workspace-card",
    `aria-label` = "Active workspace",
    shiny::uiOutput(ns("summary")),
    shiny::selectInput(ns("active_result"), "Change dataset",
                       choices = c("Choose a result" = ""), selectize = FALSE),
    shiny::uiOutput(ns("actions")))
}

# @MX:NOTE: [AUTO] active_result changes only by the demo action, an explicit
# Change dataset choice, or removal of the active label; labels never auto-select.
workspaceHeaderServer <- function(id, active_result, u_rrnames, u_big_rrdf, navigate) {
  shiny::moduleServer(id, function(input, output, session) {
    labels <- shiny::reactive(as.character(u_rrnames$labels))

    output$container <- shiny::renderUI({
      if (!length(labels())) return(NULL)
      workspace_header_content_ui(session$ns(NULL))
    })

    # Keep the chooser in step with the stores; a removed active label is cleared.
    shiny::observe({
      choices <- labels()
      current <- active_result()
      if (!is.null(current) && !current %in% choices) {
        active_result(NULL)
        return()
      }
      shiny::updateSelectInput(session, "active_result",
        choices = c("Choose a result" = "", choices),
        selected = if (is.null(current)) "" else current)
    })

    shiny::observeEvent(input$active_result, {
      value <- input$active_result
      if (identical(value, "")) {
        if (!is.null(active_result())) active_result(NULL)
        return()
      }
      if (!is.character(value) || length(value) != 1L || !value %in% labels()) return()
      if (!identical(value, active_result())) active_result(value)
    }, ignoreInit = TRUE)

    output$summary <- shiny::renderUI({
      current <- active_result()
      if (is.null(current)) {
        return(shiny::tags$p(shiny::tags$strong("No dataset selected")))
      }
      facts <- workspace_recorded_facts(u_big_rrdf[["df"]], current)
      shiny::tagList(
        shiny::tags$p("Active result: ", shiny::tags$strong(workspace_text(current, "result"))),
        shiny::tags$dl(
          shiny::tags$dt("Run"),
          shiny::tags$dd(workspace_text(NA_character_, missing = TRUE)),
          shiny::tags$dt("Recorded organism"),
          shiny::tags$dd(workspace_text(facts$organism, missing = TRUE)),
          shiny::tags$dt("Recorded identifier type"),
          shiny::tags$dd(workspace_text(facts$keytype, missing = TRUE))),
        if (facts$unique) {
          shiny::tags$p("From the recorded result details")
        } else {
          shiny::tags$p("Recorded details unavailable for this result name")
        })
    })

    output$actions <- shiny::renderUI({
      available <- !is.null(active_result())
      reason <- if (length(labels())) "Choose a result first" else "Import or load enrichment results first"
      shiny::tags$div(class = "rs-workspace rs-workspace-actions",
        workspace_action(session$ns(NULL), "create_figure", "Create figure", available, reason),
        workspace_action(session$ns(NULL), "cluster_results", "Cluster results", available, reason))
    })

    # Selects the active result in the Enrichment figures selectors only.
    shiny::observeEvent(input$create_figure, {
      current <- active_result()
      if (is.null(current) || !current %in% labels()) return()
      root <- session$rootScope()
      shiny::updateSelectInput(root, "rr_visualize-select_bar", selected = current)
      shiny::updateSelectInput(root, "rr_visualize-select_dot", selected = current)
      navigate("rr_visualize_tab")
    })

    shiny::observeEvent(input$cluster_results, {
      if (is.null(active_result())) return()
      navigate("cluster_tab")
    })
  })
}

# @MX:ANCHOR: [AUTO] Session wiring for Home entry actions and the header.
# @MX:REASON: app.R server, the release switch and the navigation tests depend on
# its arguments and on the returned active_result/navigate/load_demo handles.
workspace_navigation_server <- function(session, u_degnames, u_rrnames, u_rrdfs, u_big_rrdf) {
  active_result <- shiny::reactiveVal(NULL)
  navigate <- function(tab) workspace_navigate(session, tab)
  load_demo <- function() {
    added <- workspace_load_demo_results(u_rrnames, u_rrdfs, u_big_rrdf)
    # Only a go1 added by this action becomes active, and only if none is active.
    if ("go1" %in% added && is.null(shiny::isolate(active_result()))) {
      active_result("go1")
    }
    invisible(added)
  }
  homeTabServer("home", navigate = navigate, load_demo = load_demo,
    has_results = shiny::reactive(length(u_rrnames$labels) > 0L),
    has_gene_lists = shiny::reactive(length(u_degnames$labels) > 0L))
  workspaceHeaderServer("workspace", active_result = active_result, u_rrnames = u_rrnames,
    u_big_rrdf = u_big_rrdf, navigate = navigate)
  list(active_result = active_result, navigate = navigate, load_demo = load_demo)
}
