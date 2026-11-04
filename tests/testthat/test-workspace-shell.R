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
  expect_identical(text(ws5_record("queued")), "1 job queued")
  expect_identical(text(ws5_record("succeeded"), ws5_record("failed", "b")), "2 jobs finished")
  expect_identical(text(ws5_record("succeeded")), "1 job finished")
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
