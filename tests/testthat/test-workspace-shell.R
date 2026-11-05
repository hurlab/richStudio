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
