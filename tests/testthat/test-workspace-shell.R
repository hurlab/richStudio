# SPEC-WS-013 M5: the job badge says in words what is running, the job tray is a
# closed slide-over until the user opens it, and the context bar replaces the
# active-workspace card.

ws5_record <- function(state, id = "0123456789ab") list(run_id = id, state = state)

test_that("AC-014 AC-015 the job counts separate running, queued and finished jobs", {
  counts <- richStudio:::workspace_job_counts
  expect_identical(counts(list())$total, 0L)
  c1 <- counts(list(ws5_record("running"), ws5_record("succeeded"), ws5_record("failed"), ws5_record("queued")))
  expect_identical(c(c1$total, c1$running, c1$queued, c1$finished), c(4L, 1L, 1L, 2L))
  # a stop request that is not yet acknowledged still counts as running work
  expect_identical(counts(list(ws5_record("cancel_requested")))$running, 1L)
})

test_that("AC-015 the badge states running work first, in words, and counts finished jobs otherwise", {
  text <- function(...) richStudio:::workspace_job_badge_text(richStudio:::workspace_job_counts(list(...)))
  expect_identical(text(ws5_record("running")), "1 job running")
  expect_identical(text(ws5_record("running"), ws5_record("running", "b")), "2 jobs running")
  expect_identical(text(ws5_record("running"), ws5_record("queued", "b")), "1 job running, 1 queued")
  expect_identical(text(ws5_record("running"), ws5_record("running", "c"), ws5_record("queued", "b")), "2 jobs running, 1 queued")
  expect_identical(text(ws5_record("queued")), "1 job queued")
  expect_identical(text(ws5_record("succeeded"), ws5_record("failed", "b")), "2 jobs finished")
  expect_identical(text(ws5_record("succeeded")), "1 job finished")
})

test_that("AC-015 the badge shows compact words for running plus queued jobs and names them as jobs", {
  html <- as.character(richStudio:::workspace_job_badge(list(ws5_record("running"), ws5_record("running", "c"), ws5_record("queued", "b"))))
  expect_match(html, ">2 running, 1 queued</button>", fixed = TRUE)
  expect_match(html, 'aria-label="2 running, 1 queued jobs"', fixed = TRUE)
  expect_false(grepl("aria-label", as.character(richStudio:::workspace_job_badge(list(ws5_record("running")))), fixed = TRUE))
})

test_that("AC-015 the badge is a button for the tray, absent without jobs, and not a live region", {
  badge <- richStudio:::workspace_job_badge
  expect_null(badge(list()))
  html <- as.character(badge(list(ws5_record("running"))))
  expect_match(html, "<button", fixed = TRUE)
  expect_match(html, 'id="jobs-job_badge"', fixed = TRUE)
  expect_match(html, 'aria-controls="jobs-tray"', fixed = TRUE)
  expect_match(html, 'aria-expanded="false"', fixed = TRUE)
  expect_match(html, "1 job running", fixed = TRUE)
  expect_false(grepl("aria-live", html, fixed = TRUE))
  slot <- as.character(richStudio:::workspace_jobs_badge_ui("jobs"))
  expect_match(slot, 'id="jobs-badge"', fixed = TRUE)
  expect_match(slot, 'aria-live="off"', fixed = TRUE)
})

test_that("AC-015 the job tray is a slide-over region with a Close button and the unchanged job outputs", {
  ui <- as.character(richStudio:::workspace_jobs_ui("jobs"))
  expect_match(ui, 'id="jobs-tray"', fixed = TRUE)
  expect_match(ui, "rs-job-tray", fixed = TRUE)
  expect_match(ui, 'tabindex="-1"', fixed = TRUE)
  expect_match(ui, "rs-job-tray-close", fixed = TRUE)
  expect_match(ui, 'aria-label="Analysis jobs"', fixed = TRUE)
  for (id in c("jobs-jobs_list", "jobs-jobs_status", "jobs-jobs_time", "jobs-jobs_announce")) {
    expect_match(ui, paste0('id="', id, '"'), fixed = TRUE)
  }
  # one polite region (the announcement output) and nothing in the tray opens it by itself
  expect_identical(lengths(regmatches(ui, gregexpr('aria-live="polite"', ui, fixed = TRUE))), 1L)
  expect_false(grepl("rs-job-tray-open", ui, fixed = TRUE))
})

test_that("AC-014 the context bar is one bar with the switcher, the metadata, the job badge slot and a narrow toggle", {
  html <- as.character(richStudio:::workspace_header_content_ui("workspace"))
  expect_identical(lengths(regmatches(html, gregexpr('class="rs-workspace rs-context-bar"', html, fixed = TRUE))), 1L)
  expect_false(grepl("rs-workspace-card", html, fixed = TRUE))
  for (piece in c('id="workspace-header"', 'id="workspace-active_result"', 'id="workspace-summary"',
                  'id="workspace-actions"', 'id="jobs-badge"', "rs-context-toggle", 'id="workspace-context-more"')) {
    expect_match(html, piece, fixed = TRUE)
  }
})

test_that("AC-014 the job tray and the context bar are the only places that carry job state in the page", {
  jobs <- as.character(richStudio:::workspace_jobs_ui("jobs"))
  expect_false(grepl("rs-context-bar", jobs, fixed = TRUE))
})

# ---- SPEC-WS-013 M5 follow-up: one visible status per job, Dismiss for finished rows ----

ws5_html <- function(value) paste(value$html, collapse = "")

ws5_job <- function(state, id = "0123456789ab", note = NULL, error = NULL) {
  list(run_id = id, state = state, kind = "enrichment", inputs = list(list(label = "deg_a")),
    settings = list(species = "human"), note = note, error_summary = error)
}

ws5_jobs_env <- function(records) {
  jobs <- new.env(parent = emptyenv())
  jobs$tick <- shiny::withReactiveDomain(NULL, shiny::reactiveVal(0L))
  jobs$records <- records
  jobs$handles <- list()
  jobs$imported <- character()
  jobs$in_flight <- character()
  jobs$announce <- function() ""
  jobs
}

test_that("AC-015 the announcement output is visually hidden but stays the one polite live region", {
  ui <- as.character(richStudio:::workspace_jobs_ui("jobs"))
  expect_match(ui, '<div class="rs-sr-only">\\s*<div id="jobs-jobs_announce"[^>]*aria-live="polite"', perl = TRUE)
  expect_match(ui, 'aria-live="polite"', fixed = TRUE)
  expect_identical(lengths(regmatches(ui, gregexpr('aria-live="polite"', ui, fixed = TRUE))), 1L)
})

test_that("AC-015 a status paragraph without a note or error is visually hidden, so the row names the status once", {
  jobs <- ws5_jobs_env(list(ws5_job("succeeded"), ws5_job("failed", "ba9876543210", error = "boom")))
  shiny::testServer(richStudio:::workspace_jobs_server, args = list(id = "jobs", jobs = jobs), {
    session$flushReact()
    status <- ws5_html(output$jobs_status)
    paragraphs <- regmatches(status, gregexpr("<p[^>]*>.*?</p>", status))[[1]]
    expect_length(paragraphs, 2L)
    expect_match(paragraphs[[1]], "rs-sr-only", fixed = TRUE)
    # the failure keeps its error text visible, with the repeated status word hidden
    expect_false(grepl('class="rs-job-status rs-sr-only"', paragraphs[[2]], fixed = TRUE))
    expect_match(paragraphs[[2]], "Error: boom", fixed = TRUE)
    expect_match(paragraphs[[2]], '<span class="rs-sr-only">Failed</span>', fixed = TRUE)
  })
})

test_that("AC-015 Dismiss is offered for finished rows only and hides the row and the badge count for the session", {
  jobs <- ws5_jobs_env(list(ws5_job("succeeded"), ws5_job("running", "ba9876543210")))
  shiny::testServer(richStudio:::workspace_jobs_server, args = list(id = "jobs", jobs = jobs), {
    session$flushReact()
    html <- ws5_html(output$jobs_list)
    expect_identical(lengths(regmatches(html, gregexpr("Dismiss", html, fixed = TRUE))), 1L)
    expect_match(ws5_html(output$badge), "1 job running", fixed = TRUE)
    # a running row cannot be dismissed
    session$setInputs(job_action = list(action = "dismiss", run = "ba9876543210", nonce = 1L))
    session$flushReact()
    expect_match(ws5_html(output$jobs_list), "ba987654", fixed = TRUE)
    session$setInputs(job_action = list(action = "dismiss", run = "0123456789ab", nonce = 2L))
    session$flushReact()
    html <- ws5_html(output$jobs_list)
    expect_false(grepl("01234567", html, fixed = TRUE))
    expect_match(html, "ba987654", fixed = TRUE)
    expect_false(grepl("01234567", ws5_html(output$jobs_status), fixed = TRUE))
    # the registry is untouched: Dismiss is a view setting
    expect_length(jobs$records, 2L)
  })
})

test_that("AC-015 dismissing the last finished row removes the badge", {
  jobs <- ws5_jobs_env(list(ws5_job("succeeded")))
  shiny::testServer(richStudio:::workspace_jobs_server, args = list(id = "jobs", jobs = jobs), {
    session$flushReact()
    expect_match(ws5_html(output$badge), "1 job finished", fixed = TRUE)
    session$setInputs(job_action = list(action = "dismiss", run = "0123456789ab", nonce = 1L))
    session$flushReact()
    expect_identical(ws5_html(output$badge), "")
  })
})

# ---- SPEC-WS-013 M6: stepper (AC-017), Data step and navigation (AC-019) ----

ws6s_html <- function(x) paste(as.character(x), collapse = "")
ws6s_text <- function(x) trimws(gsub("[[:space:]]+", " ", gsub("<[^>]+>", " ", ws6s_html(x))))
ws6s_ids <- function(x) regmatches(ws6s_html(x), gregexpr('id="[^"]+"', ws6s_html(x)))[[1]]

test_that("AC-017 the step status names the five steps in order for empty, gene-lists-only, imported-only, enriched and clustered states", {
  status <- richStudio:::workspace_step_status
  steps <- c("data", "enrich", "results", "cluster", "save")
  states <- list(
    empty = status(),
    genes = status(n_deg = 2L),
    imported = status(n_imported = 3L),
    enriched = status(n_deg = 2L, n_enriched = 2L),
    clustered = status(n_deg = 2L, n_enriched = 2L, n_clus = 1L)
  )
  for (name in names(states)) {
    st <- states[[name]]
    expect_identical(st$step, steps, info = name)
    expect_identical(st$route, c("update_tab", "enrich_tab", "rr_visualize_tab", "cluster_tab", "save_tab"), info = name)
    expect_true(all(nzchar(st$status)) && all(nzchar(st$next_action)), info = name)
  }
  expect_match(states$empty$status[[1]], "No data", fixed = TRUE)
  expect_match(states$empty$status[[3]], "No results", fixed = TRUE)
  expect_match(states$genes$status[[1]], "2 gene lists", fixed = TRUE)
  expect_match(states$genes$status[[2]], "Ready", fixed = TRUE)
  expect_match(states$imported$status[[1]], "3 results imported", fixed = TRUE)
  expect_match(states$imported$status[[3]], "3 results", fixed = TRUE)
  expect_match(states$imported$status[[4]], "Ready", fixed = TRUE)
  expect_match(states$enriched$status[[2]], "2 results", fixed = TRUE)
  expect_match(states$clustered$status[[4]], "1 cluster result", fixed = TRUE)
  expect_match(states$clustered$next_action[[4]], "View cluster figures", fixed = TRUE)
  # imported results reach Results and Cluster without Enrich
  expect_false(identical(states$imported$status[[3]], states$empty$status[[3]]))
})

test_that("AC-017 the stepper lists the steps as buttons that open any step, marks the current one and has a compact narrow control", {
  st <- richStudio:::workspace_step_status(n_imported = 3L)
  html <- ws6s_html(richStudio:::workspace_stepper_content(st, "cluster_upload_tab"))
  list_html <- regmatches(html, regexpr("(?s)<ol.*?</ol>", html, perl = TRUE))
  expect_identical(lengths(regmatches(list_html, gregexpr("<li ", list_html, fixed = TRUE)))[[1]], 5L)
  names_in_order <- regmatches(list_html, gregexpr('class="rs-step-name">[^<]+', list_html))[[1]]
  expect_identical(sub('.*>', "", names_in_order), c("Data", "Enrich", "Results", "Cluster", "Save"))
  expect_identical(lengths(regmatches(list_html, gregexpr("<button", list_html, fixed = TRUE)))[[1]], 5L)
  expect_match(html, 'aria-current="step"', fixed = TRUE)
  # Data is the current step on the importer sub-route
  expect_match(html, '<li class="rs-step rs-step-current" data-step="data"', fixed = TRUE)
  for (route in st$route) expect_match(html, paste0("#shiny-tab-", route), fixed = TRUE)
  expect_match(html, "Step 1 of 5", fixed = TRUE)
  expect_match(html, "rs-stepper-compact", fixed = TRUE)
  # no step is disabled: opening is never gated
  expect_false(grepl("disabled", html, fixed = TRUE))
})

test_that("AC-019 the sidebar is one flat list in task order with no groups and no Bookmark button", {
  html <- ws6s_html(richStudio:::workspace_sidebar_menu(enabled = TRUE))
  expect_false(grepl("treeview", html, fixed = TRUE))
  expect_false(grepl("_group", html, fixed = TRUE))
  expect_false(grepl("bookmark", html, ignore.case = TRUE))
  hrefs <- sub('.*#shiny-tab-', "", regmatches(html, gregexpr('href="#shiny-tab-[A-Za-z_]+"', html))[[1]])
  hrefs <- sub('"$', "", hrefs)
  expect_identical(hrefs, c("home_tab", "update_tab", "cluster_upload_tab", "enrich_tab", "rr_visualize_tab",
                            "cluster_tab", "clus_visualize_tab", "save_tab"))
  text <- ws6s_text(html)
  for (caption in c("Home", "Data", "Upload files", "Enrich", "Enrichment figures", "Cluster", "Cluster figures", "Save")) {
    expect_match(text, caption, fixed = TRUE)
  }
  expect_false(grepl("Manage Files|Save/Load", text))
})

test_that("AC-019 the Data step hosts the DEG upload, the enrichment-results loader and project open under their own namespaces", {
  ui <- richStudio:::updateTabUI("update", "update_tab", data_step = TRUE)
  ids <- ws6s_ids(ui)
  for (id in c("enrich-deg_files", "enrich-deg_load", "enrich-deg_text", "rr_visualize-rr_files", "rr_visualize-rr_load",
               "save-load_project_file", "save-load_project", "update-rename_deg_select")) {
    expect_true(paste0('id="', id, '"') %in% ids, info = id)
  }
  expect_match(ws6s_text(ui), "Data", fixed = TRUE)
  # tabBox containers carry random numeric ids that are not controls
  expect_false(anyDuplicated(ids[!grepl('^id="[0-9]+"$', ids)]) > 0)
  # the other pages no longer carry them when the app composes the Data step
  expect_false('id="app-deg_files"' %in% ws6s_ids(richStudio:::enrich_tab_ui("app", "enrich_tab", upload = FALSE)))
  expect_false('id="app-load_project"' %in% ws6s_ids(richStudio:::saveTabUI("app", "save_tab", open_project = FALSE)))
  expect_false('id="app-rr_files"' %in% ws6s_ids(richStudio:::rr_vis_tab_ui("app", "rr_visualize_tab")))
  expect_true('id="app-rr_files"' %in% ws6s_ids(richStudio:::cluster_upload_tab_ui("app", "cluster_upload_tab")))
})

test_that("AC-019 REQ-015 no page carries a Text input tab, a Load cluster result panel or text about unsupported features", {
  pages <- list(
    home = richStudio:::home_tab_ui("home", tabName = "home_tab", app_version = "1", app_build = NULL, enabled = TRUE),
    data = richStudio:::updateTabUI("update", "update_tab", data_step = TRUE),
    enrich = richStudio:::enrich_tab_ui("enrich", "enrich_tab", upload = FALSE),
    results = richStudio:::rr_vis_tab_ui("rr_visualize", "rr_visualize_tab"),
    importer = richStudio:::cluster_upload_tab_ui("cluster_upload", "cluster_upload_tab"),
    cluster = richStudio:::clusterTabUI("cluster", "cluster_tab"),
    figures = richStudio:::clus_vis_tab_ui("clus_visualize", "clus_visualize_tab"),
    save = richStudio:::saveTabUI("save", "save_tab", open_project = FALSE)
  )
  for (name in names(pages)) {
    text <- ws6s_text(pages[[name]])
    expect_false(grepl("not yet supported|currently not available|will be supported", text), info = name)
    expect_false(grepl("docs/|\\.md\\b", text), info = name)
  }
  for (name in c("results", "importer", "figures")) {
    ids <- ws6s_ids(pages[[name]])
    expect_false(any(grepl("rr_text|rrtext_name|upload_rrtext|clus_files|clustext_name|upload_clustext", ids)), info = name)
    expect_false(grepl("Text input", ws6s_text(pages[[name]]), fixed = TRUE), info = name)
  }
  expect_false(grepl("Load cluster result", ws6s_text(pages$figures), fixed = TRUE))
})

test_that("AC-019 the Save step has one primary Save project action and keeps the JSON session inside Advanced", {
  html <- ws6s_html(richStudio:::saveTabUI("save", "save_tab", open_project = FALSE))
  save_tag <- regmatches(html, regexpr('<a[^>]*id="save-download_project"[^>]*>', html))
  expect_length(save_tag, 1L)
  expect_match(save_tag, "btn-primary", fixed = TRUE)
  expect_match(ws6s_text(html), "Save project", fixed = TRUE)
  advanced <- regmatches(html, regexpr("(?s)<details[^>]*>.*?</details>", html, perl = TRUE))
  expect_length(advanced, 1L)
  expect_match(advanced, "Advanced", fixed = TRUE)
  for (id in c("save-download_session", "save-load_session", "save-load_session_file")) {
    expect_match(advanced, paste0('id="', id, '"'), fixed = TRUE)
  }
  expect_false(grepl('id="save-download_session"', sub("(?s)<details[^>]*>.*?</details>", "", html, perl = TRUE)))
  expect_match(html, "richstudio_project_", fixed = TRUE)
})

test_that("AC-019 each moved control appears exactly once in the composed app UI under its unchanged id, and the removed ones nowhere", {
  app <- list(
    richStudio:::home_tab_ui("home", tabName = "home_tab", app_version = "1", app_build = NULL, enabled = TRUE),
    richStudio:::enrich_tab_ui("enrich", tabName = "enrich_tab", upload = FALSE),
    richStudio:::rr_vis_tab_ui("rr_visualize", tabName = "rr_visualize_tab"),
    richStudio:::cluster_upload_tab_ui("cluster_upload", tabName = "cluster_upload_tab"),
    richStudio:::clusterTabUI("cluster", tabName = "cluster_tab"),
    richStudio:::clus_vis_tab_ui("clus_visualize", tabName = "clus_visualize_tab"),
    richStudio:::updateTabUI("update", tabName = "update_tab", data_step = TRUE),
    richStudio:::saveTabUI("save", tabName = "save_tab", open_project = FALSE)
  )
  ids <- ws6s_ids(htmltools::tagList(app))
  moved <- c("enrich-deg_files", "enrich-deg_load", "enrich-deg_text", "enrich-degtext_name", "enrich-upload_degtext",
             "enrich-degtext_load", "enrich-deg_upload_status", "rr_visualize-rr_files", "rr_visualize-rr_load",
             "save-load_project_file", "save-load_project", "cluster_upload-rr_files", "cluster_upload-rr_load")
  for (id in moved) expect_identical(sum(ids == paste0('id="', id, '"')), 1L, info = id)
  removed <- c("rr_visualize-rr_text", "rr_visualize-rrtext_name", "rr_visualize-upload_rrtext",
               "cluster_upload-rr_text", "cluster_upload-rrtext_name", "cluster_upload-upload_rrtext",
               "clus_visualize-clus_files", "clus_visualize-rr_text", "clus_visualize-clustext_name",
               "clus_visualize-upload_clustext")
  for (id in removed) expect_identical(sum(ids == paste0('id="', id, '"')), 0L, info = id)
})
