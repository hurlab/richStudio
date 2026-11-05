# Workspace shell pieces shared by the context bar and the job tray (SPEC-WS-013
# M5): the job counts and the badge that states them in words. Display only; the
# job registry itself is unchanged.

# Counts of the jobs by what the badge says: running (including a requested stop
# that is not yet acknowledged), queued and finished.
workspace_job_counts <- function(records) {
  states <- vapply(
    records,
    function(r) as.character(r$state)[[1L]],
    character(1)
  )
  running <- sum(states %in% c("running", "cancel_requested"))
  queued <- sum(states == "queued")
  list(
    total = length(states),
    running = as.integer(running),
    queued = as.integer(queued),
    finished = as.integer(length(states) - running - queued)
  )
}

workspace_job_plural <- function(n, noun = "job") {
  paste0(n, " ", noun, if (n == 1L) "" else "s")
}

# The badge text states the live work first: "1 job running", "2 jobs running, 1
# queued", "1 job queued"; with no live work it counts the finished jobs.
workspace_job_badge_text <- function(counts, full = TRUE) {
  if (counts$running > 0L) {
    if (counts$queued > 0L) {
      # Compact when both are shown, so the narrow context bar keeps one row.
      return(paste0(
        if (full) workspace_job_plural(counts$running) else counts$running,
        " running, ",
        counts$queued,
        " queued"
      ))
    }
    return(paste(workspace_job_plural(counts$running), "running"))
  }
  if (counts$queued > 0L) {
    return(paste(workspace_job_plural(counts$queued), "queued"))
  }
  paste(workspace_job_plural(counts$total), "finished")
}

# NULL while the session has no job; otherwise the button that opens the tray.
workspace_job_badge <- function(records, tray_id = "jobs-tray", id = "jobs-job_badge") {
  counts <- workspace_job_counts(records)
  if (counts$total == 0L) {
    return(NULL)
  }
  shiny::tags$button(
    id = id,
    type = "button",
    class = "rs-job-badge",
    # The accessible name starts with the visible words and adds the noun the
    # compact wording leaves out.
    `aria-label` = if (counts$running > 0L && counts$queued > 0L) {
      paste(workspace_job_badge_text(counts, full = FALSE), "jobs")
    },
    `aria-controls` = tray_id,
    `aria-expanded` = "false",
    `data-running` = counts$running + counts$queued,
    workspace_job_badge_text(counts, full = FALSE)
  )
}

# Output slot of the badge. Shiny marks every bound output aria-live="polite"
# unless the attribute is set; the one polite job-status region is the tray's
# announcement output, so the badge is quiet.
workspace_jobs_badge_ui <- function(id = "jobs") {
  shiny::uiOutput(shiny::NS(id, "badge"), `aria-live` = "off", inline = TRUE)
}

# ---- Task stepper (SPEC-WS-013 M6) ---------------------------------------------------------------
# Five ordered steps with a textual status and a next action, derived from what the workspace
# holds. The stepper never gates: every step opens whatever the status says.

workspace_step_routes <- c(
  data = "update_tab",
  enrich = "enrich_tab",
  results = "rr_visualize_tab",
  cluster = "cluster_tab",
  save = "save_tab"
)
workspace_step_labels <- c(
  data = "Data",
  enrich = "Enrich",
  results = "Results",
  cluster = "Cluster",
  save = "Save"
)

# The step a route belongs to; the importer sub-route belongs to Data, Cluster figures to Cluster.
workspace_step_of_route <- function(route) {
  if (!is.character(route) || length(route) != 1L || is.na(route)) {
    return(NA_character_)
  }
  switch(
    route,
    update_tab = ,
    cluster_upload_tab = "data",
    enrich_tab = "enrich",
    rr_visualize_tab = "results",
    cluster_tab = ,
    clus_visualize_tab = "cluster",
    save_tab = "save",
    NA_character_
  )
}

# Status and next action per step from four counts: gene lists, imported results, results made
# by enrichment, and cluster results.
workspace_step_status <- function(
  n_deg = 0L,
  n_imported = 0L,
  n_enriched = 0L,
  n_clus = 0L
) {
  n_results <- n_imported + n_enriched
  count <- function(n, noun, plural = paste0(noun, "s")) {
    paste(n, if (n == 1L) noun else plural)
  }
  data_status <- if (n_deg + n_results == 0L) {
    "No data yet"
  } else {
    parts <- c(
      if (n_deg > 0L) paste(count(n_deg, "gene list"), "loaded"),
      if (n_imported > 0L) paste(count(n_imported, "result"), "imported")
    )
    if (!length(parts)) parts <- "Data loaded"
    paste(parts, collapse = ", ")
  }
  data_next <- if (n_deg + n_results == 0L) {
    "Upload gene lists or import results"
  } else if (n_results > 0L) {
    "Continue to Results"
  } else {
    "Continue to Enrich"
  }
  enrich_status <- if (n_enriched > 0L) {
    paste(count(n_enriched, "result"), "from enrichment")
  } else if (n_deg > 0L) {
    "Ready to run"
  } else {
    "Needs gene lists"
  }
  enrich_next <- if (n_enriched > 0L) {
    "Open the results"
  } else if (n_deg > 0L) {
    "Run enrichment"
  } else {
    "Upload gene lists first"
  }
  results_status <- if (n_results > 0L) count(n_results, "result") else "No results"
  results_next <- if (n_results > 0L) "Open Enrichment figures" else "Run Enrich or import results"
  cluster_status <- if (n_clus > 0L) {
    count(n_clus, "cluster result")
  } else if (n_results > 0L) {
    "Ready to cluster"
  } else {
    "No results to cluster"
  }
  cluster_next <- if (n_clus > 0L) {
    "View cluster figures"
  } else if (n_results > 0L) {
    "Cluster results"
  } else {
    "Get results first"
  }
  has_work <- n_deg + n_results + n_clus > 0L
  data.frame(
    step = names(workspace_step_routes),
    label = unname(workspace_step_labels),
    route = unname(workspace_step_routes),
    status = c(data_status, enrich_status, results_status, cluster_status, if (has_work) "Ready to save" else "Nothing to save"),
    next_action = c(data_next, enrich_next, results_next, cluster_next, if (has_work) "Save project" else "Load data first"),
    stringsAsFactors = FALSE
  )
}

workspace_step_open_js <- function(route) {
  paste0(
    "var l=document.querySelector('.sidebar-menu a[href=\"#shiny-tab-", route, "\"]');",
    "if(l)l.click();var d=this.closest('details');if(d)d.removeAttribute('open');"
  )
}

# The stepper markup: a numbered list on wide screens and one "Step N of 5" disclosure on narrow
# screens (custom.css shows one of the two). `route` is the page showing now.
workspace_stepper_content <- function(status, route = NULL) {
  current <- workspace_step_of_route(route)
  index <- match(current, status$step)
  shown <- if (is.na(index)) 1L else index
  item <- function(i) {
    is_current <- !is.na(index) && i == index
    shiny::tags$li(
      class = if (is_current) "rs-step rs-step-current" else "rs-step",
      `data-step` = status$step[[i]],
      `aria-current` = if (is_current) "step",
      shiny::tags$button(
        type = "button",
        class = "rs-step-button",
        title = status$next_action[[i]],
        onclick = workspace_step_open_js(status$route[[i]]),
        shiny::tags$span(class = "rs-step-number", i),
        shiny::tags$span(class = "rs-step-name", status$label[[i]]),
        shiny::tags$span(class = "rs-step-status", status$status[[i]]),
        shiny::tags$span(class = "rs-step-next", paste("Next:", status$next_action[[i]]))
      )
    )
  }
  shiny::tags$section(
    id = "workspace-stepper",
    class = "rs-stepper-bar",
    `aria-label` = "Workflow steps",
    shiny::tags$ol(class = "rs-stepper", lapply(seq_len(nrow(status)), item)),
    shiny::tags$details(
      class = "rs-stepper-compact",
      shiny::tags$summary(
        paste0("Step ", shown, " of ", nrow(status), ": ", status$label[[shown]])
      ),
      shiny::tags$div(
        class = "rs-stepper-menu",
        lapply(seq_len(nrow(status)), function(i) {
          shiny::tags$button(
            type = "button",
            class = "rs-step-link",
            onclick = workspace_step_open_js(status$route[[i]]),
            paste0(i, ". ", status$label[[i]], " - ", status$status[[i]])
          )
        })
      )
    )
  )
}

workspace_stepper_ui <- function(id = "stepper", enabled = TRUE) {
  if (!isTRUE(enabled)) {
    return(NULL)
  }
  shiny::uiOutput(shiny::NS(id, "bar"), `aria-live` = "off")
}

# Counts of what the stores hold; results made by enrichment carry the gene list they came from,
# imported ones carry "No" in from_deg.
workspace_step_counts <- function(u_degnames, u_rrnames, u_big_rrdf, u_clusnames = NULL) {
  labels <- as.character(u_rrnames$labels)
  big <- u_big_rrdf[["df"]]
  enriched <- 0L
  if (length(labels) && is.data.frame(big) && all(c("name", "from_deg") %in% names(big))) {
    rows <- big[big$name %in% labels, , drop = FALSE]
    enriched <- as.integer(sum(!rows$from_deg %in% "No"))
  }
  list(
    n_deg = length(u_degnames$labels),
    n_imported = length(labels) - enriched,
    n_enriched = enriched,
    n_clus = if (is.null(u_clusnames)) 0L else length(u_clusnames$labels)
  )
}

workspace_stepper_server <- function(id, u_degnames, u_rrnames, u_big_rrdf, u_clusnames = NULL) {
  shiny::moduleServer(id, function(input, output, session) {
    root <- session$rootScope()
    output$bar <- shiny::renderUI({
      counts <- workspace_step_counts(u_degnames, u_rrnames, u_big_rrdf, u_clusnames)
      route <- root$input[[workspace_sidebar_id]]
      workspace_stepper_content(do.call(workspace_step_status, counts), route)
    })
    shiny::outputOptions(output, "bar", suspendWhenHidden = FALSE)
  })
}
