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
