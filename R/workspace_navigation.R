# Workspace navigation adapters (SPEC-WS-003). Navigation selects an existing
# route or result; it never runs enrichment or clustering. All selection state
# is created per session by workspace_navigation_server(); nothing here is
# global.

workspace_tabs <- c(
  "home_tab",
  "enrich_tab",
  "rr_visualize_tab",
  "cluster_upload_tab",
  "cluster_tab",
  "clus_visualize_tab",
  "update_tab",
  "save_tab"
)
workspace_sidebar_id <- "workspace_sidebar"
workspace_demo_labels <- c("go1", "go2", "kegg1")

# Version comes from the package metadata; deployed builds use their stamped
# release commit, while a source checkout may use git as a development fallback.
workspace_package_root <- function(root = NULL, candidates = NULL) {
  if (is.null(candidates)) {
    wd <- normalizePath(getwd(), mustWork = FALSE)
    candidates <- c(
      getOption("richStudio.appdir"),
      wd,
      dirname(wd),
      dirname(dirname(wd)),
      system.file(package = "richStudio")
    )
  }
  candidates <- unique(as.character(c(root, candidates)))
  candidates <- candidates[!is.na(candidates) & nzchar(candidates)]
  candidates <- vapply(
    candidates,
    normalizePath,
    character(1),
    mustWork = FALSE
  )
  candidates <- unique(candidates)
  for (candidate in candidates) {
    description <- file.path(candidate, "DESCRIPTION")
    if (!file.exists(description)) {
      next
    }
    fields <- tryCatch(
      read.dcf(description, fields = "Package"),
      error = function(e) NULL
    )
    if (!is.null(fields) && identical(unname(fields[[1L]]), "richStudio")) {
      return(candidate)
    }
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

  valid_build <- function(value) {
    length(value) == 1L && !is.na(value) && grepl("^[[:xdigit:]]{7,40}$", value)
  }
  release_file <- if (!is.null(root)) {
    file.path(root, ".release-commit")
  } else {
    NULL
  }
  build <- if (!is.null(release_file) && file.exists(release_file)) {
    trimws(readLines(release_file, n = 1L, warn = FALSE))
  } else {
    NA_character_
  }
  if (valid_build(build)) {
    build <- substr(build, 1L, 7L)
  }
  if (
    !valid_build(build) &&
      !is.null(root) &&
      file.exists(file.path(root, ".git"))
  ) {
    candidate <- tryCatch(
      system2(
        "git",
        c("-C", shQuote(root), "rev-parse", "--short", "HEAD"),
        stdout = TRUE,
        stderr = FALSE
      ),
      error = function(e) character()
    )
    if (length(candidate) == 1L && valid_build(candidate)) {
      build <- substr(candidate, 1L, 7L)
    }
  }
  if (!valid_build(build)) {
    build <- NULL
  }
  if (length(version) != 1L || is.na(version) || !nzchar(version)) {
    version <- NULL
  }
  list(version = version, build = build)
}

# Sidebar menu. Route strings are unchanged in both release-switch states; only
# the two figure captions differ.
workspace_sidebar_menu <- function(enabled = TRUE) {
  figures <- if (isTRUE(enabled)) {
    c("Enrichment figures", "Cluster figures")
  } else {
    c("Visualize", "Visualize")
  }
  # One flat list in task order (SPEC-WS-013 F14): no collapsible groups. The importer
  # route stays reachable as "Upload files", the sub-route of Data.
  shinydashboard::sidebarMenu(
    id = if (isTRUE(enabled)) workspace_sidebar_id,
    shinydashboard::menuItem(
      "Home",
      icon = shiny::icon("house"),
      tabName = "home_tab",
      selected = TRUE
    ),
    shinydashboard::menuItem(
      "Data",
      icon = shiny::icon("folder-open"),
      tabName = "update_tab"
    ),
    shinydashboard::menuItem(
      "Upload files",
      icon = shiny::icon("file-arrow-up"),
      tabName = "cluster_upload_tab"
    ),
    shinydashboard::menuItem(
      "Enrich",
      icon = shiny::icon("play-circle"),
      tabName = "enrich_tab"
    ),
    shinydashboard::menuItem(
      figures[1],
      icon = shiny::icon("chart-bar"),
      tabName = "rr_visualize_tab"
    ),
    shinydashboard::menuItem(
      "Cluster",
      icon = shiny::icon("vials"),
      tabName = "cluster_tab"
    ),
    shinydashboard::menuItem(
      figures[2],
      icon = shiny::icon("chart-line"),
      tabName = "clus_visualize_tab"
    ),
    shinydashboard::menuItem(
      "Save",
      icon = shiny::icon("floppy-disk"),
      tabName = "save_tab"
    )
  )
}

# Validated route change on the top-level sidebar. Unknown names are rejected.
workspace_navigate <- function(session, tab) {
  if (
    !is.character(tab) ||
      length(tab) != 1L ||
      is.na(tab) ||
      !tab %in% workspace_tabs
  ) {
    return(invisible(FALSE))
  }
  shinydashboard::updateTabItems(session$rootScope(), workspace_sidebar_id, tab)
  invisible(TRUE)
}

# Adds the bundled demo enrichment results exactly as the Enrichment figures
# "Load data" action does, skipping labels already present. Returns added
# labels.
workspace_load_demo_results <- function(u_rrnames, u_rrdfs, u_big_rrdf) {
  added <- character()
  for (lab in workspace_demo_labels) {
    if (lab %in% u_rrnames$labels) {
      next
    }
    df <- utils::read.delim(sample_rr_path(paste0(lab, ".txt")))
    u_rrdfs[[lab]] <- df
    u_rrnames$labels <- c(u_rrnames$labels, lab)
    u_big_rrdf[["df"]] <- add_file_rrdf(
      df = u_big_rrdf[["df"]],
      name = lab,
      file = TRUE
    )
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
    return(paste0(
      "Added bundled demo results: ",
      paste(added, collapse = ", "),
      "."
    ))
  }
  reason <- paste0(
    "Not added because a result with that name already exists: ",
    paste(skipped, collapse = ", "),
    "."
  )
  if (!length(added)) {
    return(paste("No bundled demo results added.", reason))
  }
  paste0(
    "Added bundled demo results: ",
    paste(added, collapse = ", "),
    ". ",
    reason
  )
}

# Unknown recorded values ("?", "NULL", "NA", "", missing) become one NA.
workspace_recorded_value <- function(value) {
  value <- as.character(value)
  if (
    length(value) != 1L || is.na(value) || value %in% c("?", "NULL", "NA", "")
  ) {
    return(NA_character_)
  }
  value
}

# Recorded facts for a result name. Only an unambiguous single row is used;
# nothing is inferred from file names, setup selectors or result contents.
workspace_recorded_facts <- function(metadata, name) {
  rows <- integer()
  if (
    is.data.frame(metadata) &&
      all(c("name", "species", "keytype") %in% names(metadata))
  ) {
    rows <- which(metadata$name %in% name)
  }
  if (length(rows) != 1L) {
    return(list(
      organism = NA_character_,
      keytype = NA_character_,
      unique = FALSE
    ))
  }
  list(
    organism = workspace_recorded_value(metadata$species[rows]),
    keytype = workspace_recorded_value(metadata$keytype[rows]),
    unique = TRUE
  )
}

workspace_header_ui <- function(id = "workspace", enabled = TRUE) {
  if (!isTRUE(enabled)) {
    return(NULL)
  }
  ns <- shiny::NS(id)
  shiny::uiOutput(ns("container"))
}

# The context bar (SPEC-WS-013 M5): one compact bar naming the active dataset with
# its switcher, the recorded metadata as chips, one "not recorded" disclosure, the
# Create figure / Cluster actions and the job badge that opens the job tray. It
# replaces the former active-workspace card. custom.css shows it on the Enrich,
# Results and Cluster pages only; on a narrow screen everything but the switcher
# and the badge sits behind a toggle.
workspace_header_content_ui <- function(id = "workspace") {
  ns <- shiny::NS(id)
  shiny::tags$section(
    id = ns("header"),
    class = "rs-workspace rs-context-bar",
    `aria-label` = "Dataset and jobs",
    shiny::selectInput(
      ns("active_result"),
      "Change dataset",
      choices = c("Choose a result" = ""),
      selectize = FALSE
    ),
    shiny::tags$div(
      id = ns("context-more"),
      class = "rs-context-more",
      shiny::uiOutput(ns("summary")),
      shiny::uiOutput(ns("actions"))
    ),
    workspace_jobs_badge_ui("jobs"),
    shiny::tags$button(
      type = "button",
      class = "rs-context-toggle",
      `aria-expanded` = "false",
      `aria-controls` = ns("context-more"),
      "Details"
    )
  )
}

# @MX:NOTE: [AUTO] active_result changes only by the demo action, an explicit
# Change dataset choice, or removal of the active label; labels never
# auto-select.
workspace_header_server <- function(
  id,
  active_result,
  u_rrnames,
  u_big_rrdf,
  navigate,
  jobs = NULL
) {
  shiny::moduleServer(id, function(input, output, session) {
    labels <- shiny::reactive(as.character(u_rrnames$labels))

    # The bar exists once there is something to name or to follow: a result, or a
    # job (a failed run can precede any result).
    # A reactiveVal: the bar is only rebuilt when this flips, not on every job
    # tick, so the switcher keeps its selection while jobs change state.
    has_jobs <- shiny::reactiveVal(FALSE)
    if (!is.null(jobs)) {
      shiny::observe({
        jobs$tick()
        present <- length(jobs$records) > 0L
        if (!identical(shiny::isolate(has_jobs()), present)) has_jobs(present)
      })
    }

    # A rebuilt bar echoes its initial (empty) choice back as an input event; that
    # echo must not clear the active result.
    bar_state <- new.env(parent = emptyenv())
    bar_state$fresh <- FALSE

    output$container <- shiny::renderUI({
      if (!length(labels()) && !has_jobs()) {
        return(NULL)
      }
      bar_state$fresh <- TRUE
      workspace_header_content_ui(session$ns(NULL))
    })

    # Keep the chooser in step with the stores; a removed active label is
    # cleared.
    shiny::observe({
      choices <- labels()
      current <- active_result()
      has_jobs() # the bar is rebuilt when the first job appears: re-send the selection
      if (!is.null(current) && !current %in% choices) {
        active_result(NULL)
        return()
      }
      shiny::updateSelectInput(
        session,
        "active_result",
        choices = c("Choose a result" = "", choices),
        selected = if (is.null(current)) "" else current
      )
    })

    shiny::observeEvent(
      input$active_result,
      {
        value <- input$active_result
        fresh <- isTRUE(bar_state$fresh)
        bar_state$fresh <- FALSE
        if (identical(value, "")) {
          if (!is.null(active_result())) {
            if (fresh) {
              # re-send the selection to the rebuilt bar instead of clearing it
              shiny::updateSelectInput(
                session,
                "active_result",
                choices = c("Choose a result" = "", labels()),
                selected = active_result()
              )
            } else {
              active_result(NULL)
            }
          }
          return()
        }
        if (
          !is.character(value) || length(value) != 1L || !value %in% labels()
        ) {
          return()
        }
        if (!identical(value, active_result())) {
          active_result(value)
          # Switching the dataset sets the default selection on Cluster and Results.
          root <- session$rootScope()
          shiny::updateSelectizeInput(
            root,
            "cluster-selected_rrs",
            selected = value
          )
          for (select in c("select_table", "select_bar", "select_dot", "select_net")) {
            shiny::updateSelectInput(
              root,
              paste0("rr_visualize-", select),
              selected = value
            )
          }
        }
      },
      ignoreInit = TRUE
    )

    output$summary <- shiny::renderUI({
      current <- active_result()
      if (is.null(current)) {
        return(shiny::tags$p(shiny::tags$strong("No dataset selected")))
      }
      facts <- workspace_recorded_facts(u_big_rrdf[["df"]], current)
      # Recorded facts are shown as rows; every unrecorded field sits in one
      # closed disclosure whose trigger counts them ("Not recorded" stays the
      # text of each field inside it).
      fields <- list(
        list(label = "Run", value = NA_character_),
        list(label = "Recorded organism", value = facts$organism),
        list(label = "Recorded identifier type", value = facts$keytype)
      )
      row <- function(field) {
        list(
          shiny::tags$dt(field$label),
          shiny::tags$dd(workspace_text(field$value, missing = TRUE))
        )
      }
      unrecorded <- Filter(function(f) is.na(f$value), fields)
      recorded <- Filter(function(f) !is.na(f$value), fields)
      shiny::tagList(
        shiny::tags$p(
          class = "rs-context-name",
          "Active result: ",
          shiny::tags$strong(workspace_text(current, "result"))
        ),
        if (length(recorded)) {
          shiny::tags$dl(unlist(lapply(recorded, row), recursive = FALSE))
        },
        if (length(unrecorded)) {
          shiny::tags$details(
            class = "rs-workspace-unrecorded",
            shiny::tags$summary(paste(length(unrecorded), "not recorded")),
            shiny::tags$dl(unlist(lapply(unrecorded, row), recursive = FALSE))
          )
        },
        if (facts$unique) {
          shiny::tags$p(class = "rs-context-note", "From the recorded result details")
        } else {
          shiny::tags$p(
            class = "rs-context-note",
            "Recorded details unavailable for this result name"
          )
        }
      )
    })

    output$actions <- shiny::renderUI({
      available <- !is.null(active_result())
      reason <- if (length(labels())) {
        "Choose a result first"
      } else {
        "Import or load enrichment results first"
      }
      ns_id <- session$ns(NULL)
      hint_id <- paste0(ns_id, "-actions-reason")
      shiny::tags$div(
        class = "rs-workspace rs-workspace-actions",
        workspace_action(
          ns_id,
          "create_figure",
          "Create figure",
          available,
          reason,
          show_reason = FALSE,
          reason_id = hint_id
        ),
        workspace_action(
          ns_id,
          "cluster_results",
          "Cluster results",
          available,
          reason,
          show_reason = FALSE,
          reason_id = hint_id
        ),
        if (!available) shiny::tags$span(id = hint_id, reason)
      )
    })
    # The narrow bar collapses these outputs with display: contents, which Shiny reads as hidden.
    shiny::outputOptions(output, "summary", suspendWhenHidden = FALSE)
    shiny::outputOptions(output, "actions", suspendWhenHidden = FALSE)

    # Selects the active result in the Enrichment figures selectors only.
    shiny::observeEvent(input$create_figure, {
      current <- active_result()
      if (is.null(current) || !current %in% labels()) {
        return()
      }
      root <- session$rootScope()
      shiny::updateSelectInput(
        root,
        "rr_visualize-select_bar",
        selected = current
      )
      shiny::updateSelectInput(
        root,
        "rr_visualize-select_dot",
        selected = current
      )
      navigate("rr_visualize_tab")
    })

    # The Cluster step opens with the active result selected (SPEC-WS-013 F3).
    shiny::observeEvent(input$cluster_results, {
      current <- active_result()
      if (is.null(current) || !current %in% labels()) {
        return()
      }
      shiny::updateSelectizeInput(
        session$rootScope(),
        "cluster-selected_rrs",
        selected = current
      )
      navigate("cluster_tab")
    })
  })
}

# @MX:ANCHOR: [AUTO] Session wiring for Home entry actions and the header.
# @MX:REASON: app.R server, the release switch and the navigation tests depend
# on
# its arguments and on the returned active_result/navigate/load_demo handles.
workspace_navigation_server <- function(
  session,
  u_degnames,
  u_rrnames,
  u_rrdfs,
  u_big_rrdf,
  u_clusnames = NULL
) {
  active_result <- shiny::reactiveVal(NULL)
  navigate <- function(tab) workspace_navigate(session, tab)
  load_demo <- function() {
    added <- workspace_load_demo_results(u_rrnames, u_rrdfs, u_big_rrdf)
    # Only a go1 added by this action becomes active, and only if none is
    # active.
    if ("go1" %in% added && is.null(shiny::isolate(active_result()))) {
      active_result("go1")
    }
    invisible(added)
  }
  home_tab_server(
    "home",
    navigate = navigate,
    load_demo = load_demo,
    has_results = shiny::reactive(length(u_rrnames$labels) > 0L),
    has_gene_lists = shiny::reactive(length(u_degnames$labels) > 0L)
  )
  workspace_header_server(
    "workspace",
    active_result = active_result,
    u_rrnames = u_rrnames,
    u_big_rrdf = u_big_rrdf,
    navigate = navigate,
    jobs = workspace_jobs_peek(session)
  )
  workspace_stepper_server(
    "stepper",
    u_degnames = u_degnames,
    u_rrnames = u_rrnames,
    u_big_rrdf = u_big_rrdf,
    u_clusnames = u_clusnames
  )
  workspace_handoffs(
    session,
    active_result = active_result,
    navigate = navigate,
    u_degnames = u_degnames,
    u_rrnames = u_rrnames,
    u_big_rrdf = u_big_rrdf,
    jobs = workspace_jobs_peek(session)
  )
  list(
    active_result = active_result,
    navigate = navigate,
    load_demo = load_demo
  )
}

# Cross-step handoffs (SPEC-WS-013 REQ-009): a success notice with a next action when data are
# loaded, the active dataset's source as the default gene-list selection when Enrich opens, and a
# "View cluster figures" action when a clustering job succeeds. All display state; no analysis runs.
workspace_handoffs <- function(
  session,
  active_result,
  navigate,
  u_degnames,
  u_rrnames,
  u_big_rrdf,
  jobs = NULL
) {
  input <- session$input
  root <- session
  seen <- new.env(parent = emptyenv())
  seen$started <- FALSE
  seen$rr <- character()
  seen$deg <- character()
  seen$jobs <- character()
  seen$figures <- NULL

  notice <- function(text, action_id, action_label, id) {
    shiny::showNotification(
      shiny::tagList(
        shiny::tags$span(text),
        shiny::tags$br(),
        shiny::actionLink(action_id, action_label)
      ),
      duration = 12,
      type = "message",
      id = id
    )
  }

  shiny::observe({
    rr <- as.character(u_rrnames$labels)
    deg <- as.character(u_degnames$labels)
    shiny::isolate({
      new_rr <- setdiff(rr, seen$rr)
      new_deg <- setdiff(deg, seen$deg)
      first <- !seen$started
      seen$started <- TRUE
      seen$rr <- rr
      seen$deg <- deg
      if (first) {
        return()
      }
      if (length(new_rr)) {
        notice(
          paste0(
            "Loaded ",
            length(new_rr),
            if (length(new_rr) == 1L) " result: " else " results: ",
            paste(utils::head(new_rr, 3L), collapse = ", "),
            if (length(new_rr) > 3L) ", ..." else "",
            "."
          ),
          "workspace_next_cluster",
          "Cluster these results",
          "workspace-loaded"
        )
      } else if (length(new_deg)) {
        notice(
          paste0(
            "Loaded ",
            length(new_deg),
            if (length(new_deg) == 1L) " gene list." else " gene lists."
          ),
          "workspace_next_enrich",
          "Go to Enrich",
          "workspace-loaded"
        )
      }
    })
  })

  shiny::observeEvent(input$workspace_next_cluster, {
    current <- active_result()
    labels <- as.character(u_rrnames$labels)
    shiny::updateSelectizeInput(
      root,
      "cluster-selected_rrs",
      selected = if (!is.null(current) && current %in% labels) current else utils::head(labels, 1L)
    )
    navigate("cluster_tab")
  })
  shiny::observeEvent(input$workspace_next_enrich, navigate("enrich_tab"))

  # Opening Enrich with an empty gene-list selection selects the gene list the active result came from.
  shiny::observeEvent(input[[workspace_sidebar_id]], {
    if (!identical(input[[workspace_sidebar_id]], "enrich_tab")) {
      return()
    }
    current <- active_result()
    big <- u_big_rrdf[["df"]]
    if (
      is.null(current) ||
        length(input[["enrich-degs_to_enrich"]]) ||
        !is.data.frame(big) ||
        !all(c("name", "from_deg") %in% names(big))
    ) {
      return()
    }
    source <- as.character(big$from_deg[big$name %in% current])
    source <- source[source %in% as.character(u_degnames$labels)]
    if (length(source) == 1L) {
      shiny::updateSelectizeInput(root, "enrich-degs_to_enrich", selected = source)
    }
  }, ignoreInit = TRUE)

  if (!is.null(jobs)) {
    shiny::observe({
      jobs$tick()
      shiny::isolate({
        for (rec in jobs$records) {
          id <- as.character(rec$run_id)
          if (
            id %in% seen$jobs ||
              !identical(rec$state, "succeeded") ||
              id %in% jobs$imported
          ) {
            next
          }
          seen$jobs <- c(seen$jobs, id)
          if (!identical(rec$kind, "clustering")) {
            next
          }
          outputs <- as.character(unlist(rec$outputs))
          if (!length(outputs)) {
            next
          }
          # The finished-clustering notice itself (counts, name, "View cluster figures")
          # is raised once, by the cluster step; this only remembers which result to open.
          seen$figures <- outputs[[1L]]
        }
      })
    })
    shiny::observeEvent(input$workspace_view_cluster_figures, {
      name <- seen$figures
      if (!is.null(name)) {
        for (select in c("clus_visualize-clusdf_select", "clus_visualize-cluslist_select")) {
          shiny::updateSelectInput(root, select, selected = name)
        }
      }
      navigate("clus_visualize_tab")
    })
  }
  invisible(NULL)
}
