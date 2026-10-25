# Session-owned analysis jobs (SPEC-WS-006): the per-session registry, the bounded
# in-process admission queue, dispatch, capability, Stop/Detach/Retry, the
# authorization that keeps stale callbacks inert, and the job panel. Everything here
# is internal. Records are data only; futures, PIDs and closures live in `handles`.

# ---- seams (replaced in tests with testthat::local_mocked_bindings) ------------------

workspace_jobs_now <- function() Sys.time()
workspace_jobs_free_workers <- function() future::nbrOfFreeWorkers()
# The factory seam: the caller's expression is captured unevaluated, as future() does.
workspace_jobs_future <- function(expr, ..., envir = parent.frame()) {
  future::future(substitute(expr), ..., substitute = FALSE, envir = envir)
}
workspace_jobs_cancel <- function(f) future::cancel(f)
workspace_jobs_resolved <- function(f) future::resolved(f)

# Queue bounds are read from the installed 001 resource policy (single source).
workspace_job_queue_limit <- function() {
  as.integer(workspace_resource_policy()$limits$job_queue_process)
}
workspace_job_session_queue_limit <- function() {
  as.integer(workspace_resource_policy()$limits$job_queue_session)
}

# ---- process-level admission queue (in-process, in-memory, bounded) -----------------

.workspace_job_queue <- new.env(parent = emptyenv())
.workspace_job_queue$entries <- list()
.workspace_job_queue$seq <- 0L

# Tests only: a fresh queue and a fresh version counter for every test.
workspace_job_queue_reset <- function() {
  .workspace_job_queue$entries <- list()
  .workspace_job_queue$seq <- 0L
  .workspace_job_queue$version <- NULL
  invisible(NULL)
}

# One process-level counter, created lazily at runtime, read only by sessions that
# hold a queued record, so their queue position refreshes when others mutate the queue.
# Created outside any session's domain: it outlives the session that first touches it,
# and shiny >= 1.14 destroys a session's reactives when that session closes.
workspace_job_queue_version <- function() {
  if (is.null(.workspace_job_queue$version)) {
    .workspace_job_queue$version <- shiny::withReactiveDomain(NULL, shiny::reactiveVal(0L))
  }
  .workspace_job_queue$version
}

workspace_job_queue_bump <- function() {
  v <- workspace_job_queue_version()
  v(shiny::isolate(v()) + 1L)
  invisible(NULL)
}

workspace_job_queue_remove <- function(run_ids) {
  entries <- .workspace_job_queue$entries
  keep <- !vapply(entries, function(e) e$run_id %in% run_ids, logical(1))
  if (!all(keep)) {
    .workspace_job_queue$entries <- entries[keep]
    workspace_job_queue_bump()
  }
  invisible(!all(keep))
}

# The set of queued records equals the set of queue entries, with no duplicates.
# The queue holds the only references to other sessions' registries, so the check
# covers the registries reachable from the queue plus any registries supplied.
workspace_job_queue_consistent <- function(registries = list()) {
  entries <- .workspace_job_queue$entries
  ids <- vapply(entries, function(e) e$run_id, character(1))
  if (anyDuplicated(ids)) return(FALSE)
  regs <- c(lapply(entries, function(e) e$registry), registries)
  seen <- list()
  for (reg in regs) {
    if (any(vapply(seen, identical, logical(1), reg))) next
    seen[[length(seen) + 1L]] <- reg
    if (isTRUE(reg$closed)) next
    queued <- vapply(Filter(function(r) identical(r$state, "queued"), reg$records),
                     function(r) r$run_id, character(1))
    mine <- ids[vapply(entries, function(e) identical(e$registry, reg), logical(1))]
    if (!setequal(queued, mine)) return(FALSE)
  }
  for (e in entries) {
    rec <- workspace_jobs_record(e$registry, e$run_id)
    if (is.null(rec) || !identical(rec$state, "queued")) return(FALSE)
  }
  TRUE
}

# ---- containment ----------------------------------------------------------------

# An unexpected error never propagates into the observer or callback that happened
# to trigger the work, which may belong to another session.
workspace_jobs_contain <- function(expr, where) {
  tryCatch(expr, error = function(e) {
    message("[richStudio] job dispatch error (", where, "): ", workspace_jobs_error_summary(e))
    NULL
  })
}

workspace_jobs_error_summary <- function(cond) {
  msg <- tryCatch(paste(conditionMessage(cond), collapse = "\n"), error = function(e) "Unknown error")
  msg <- strsplit(msg, "\n", fixed = TRUE)[[1]]
  msg <- if (length(msg)) msg[[1]] else ""
  msg <- iconv(enc2utf8(msg), "UTF-8", "UTF-8", sub = "?")
  if (is.na(msg)) msg <- ""
  msg <- gsub("[[:cntrl:]]", "", msg, perl = TRUE)
  msg <- gsub("[A-Za-z]:\\\\[^\\s'\"]+", "<path>", msg, perl = TRUE, useBytes = TRUE)
  msg <- gsub("(?:/[^/\\s'\"]+){2,}", "<path>", msg, perl = TRUE, useBytes = TRUE)
  msg <- gsub("(token|password|secret|key)\\s*[=:]\\s*\\S+", "\\1=<redacted>", msg, ignore.case = TRUE, perl = TRUE)
  msg <- gsub("(Bearer)\\s+\\S+", "\\1 <redacted>", msg, ignore.case = TRUE, perl = TRUE)
  substr(msg, 1L, 300L)
}

# ---- registry ----------------------------------------------------------------------

workspace_jobs_root <- function(session) {
  root <- tryCatch(session$rootScope(), error = function(e) NULL)
  if (is.null(root)) session else root
}

workspace_jobs_session_closed <- function(session) {
  isTRUE(tryCatch(session$isClosed(), error = function(e) FALSE))
}

# @MX:ANCHOR: [AUTO] The per-session job registry every job module, the panel and the save tab share.
# @MX:REASON: Owner/generation/revision authorization of every callback rests on this one environment.
workspace_jobs_registry <- function(session, policy_loader = workspace_resource_policy, ack_timeout = 5) {
  jobs <- new.env(parent = emptyenv())
  root <- workspace_jobs_root(session)
  jobs$session <- root
  jobs$owner <- substr(digest::digest(list(workspace_jobs_now(), stats::runif(1))), 1L, 16L)
  jobs$generation <- 1L
  # Known limitation: `closed` tracks only the root session, and everything here treats the
  # root as the unit of teardown. Shiny >= 1.14 can tear a module scope down on its own
  # (`session$destroy(id)`) while the root lives, and a module proxy then still reports
  # isClosed() == FALSE, so sources and publish callbacks captured from that module would be
  # read after destruction. Nothing in R/ calls `$destroy(` today (tests R46 fails if that
  # changes); a caller that starts doing so must first give the registry a per-module close.
  jobs$closed <- FALSE
  jobs$revisions <- new.env(parent = emptyenv())
  jobs$records <- list()
  jobs$in_flight <- character()
  jobs$handles <- new.env(parent = emptyenv())
  # Outside the session's domain: late callbacks reach these after the session closes,
  # and shiny >= 1.14 destroys a session's reactives on close. Observers below stay owned.
  jobs$tick <- shiny::withReactiveDomain(NULL, shiny::reactiveVal(0L))
  jobs$announce <- shiny::withReactiveDomain(NULL, shiny::reactiveVal(""))
  jobs$policy_loader <- policy_loader
  jobs$ack_timeout <- ack_timeout
  jobs$imported <- character()
  shiny::withReactiveDomain(root, {
    # Acknowledgement poller: a Stop is labelled cancelled only once the owned PID is gone.
    shiny::observe({
      jobs$tick()
      pending <- Filter(function(r) identical(r$state, "cancel_requested"), jobs$records)
      if (!length(pending)) return(invisible(NULL))
      shiny::invalidateLater(100)
      workspace_jobs_contain(workspace_jobs_poll_acks(jobs), "acknowledgement")
    })
    # Bounded re-check: a safety net for releases no callback observes.
    shiny::observe({
      jobs$tick()
      if (!any(vapply(jobs$records, function(r) identical(r$state, "queued"), logical(1)))) return(invisible(NULL))
      shiny::invalidateLater(500)
      workspace_jobs_contain(workspace_job_queue_dispatch(), "re-check")
    })
  })
  jobs
}

workspace_jobs_for <- function(session) {
  jobs <- session$userData$workspace_jobs
  if (is.null(jobs)) {
    jobs <- workspace_jobs_registry(workspace_jobs_root(session))
    session$userData$workspace_jobs <- jobs
  }
  jobs
}

workspace_jobs_peek <- function(session) session$userData$workspace_jobs

workspace_jobs_new_run_id <- function(jobs) {
  existing <- vapply(jobs$records, function(r) as.character(r$run_id), character(1))
  repeat {
    id <- substr(digest::digest(list(workspace_jobs_now(), stats::runif(1), jobs$owner)), 1L, 12L)
    if (!id %in% existing) return(id)
  }
}

workspace_jobs_index <- function(jobs, run_id) {
  ids <- vapply(jobs$records, function(r) as.character(r$run_id), character(1))
  match(run_id, ids)
}

workspace_jobs_record <- function(jobs, run_id) {
  i <- workspace_jobs_index(jobs, run_id)
  if (is.na(i)) NULL else jobs$records[[i]]
}

workspace_jobs_update <- function(jobs, run_id, values) {
  i <- workspace_jobs_index(jobs, run_id)
  if (is.na(i)) return(invisible(FALSE))
  rec <- jobs$records[[i]]
  rec[names(values)] <- values
  jobs$records[[i]] <- rec
  invisible(TRUE)
}

workspace_jobs_bump <- function(jobs) {
  jobs$tick(shiny::isolate(jobs$tick()) + 1L)
  invisible(NULL)
}

workspace_jobs_terminal <- c("succeeded", "failed", "cancelled", "detached", "superseded", "interrupted")

workspace_jobs_state_label <- function(state) {
  switch(state, queued = "Queued", running = "Running", succeeded = "Succeeded", failed = "Failed",
         cancel_requested = "Stop requested", cancelled = "Cancelled", detached = "Detached",
         superseded = "Superseded", interrupted = "Interrupted", state)
}

# One transition: state and note replaced (never appended), times stamped, the panel
# ticked, and one line announced for this record only.
workspace_jobs_transition <- function(jobs, run_id, state, note = NA_character_, extra = list()) {
  values <- c(list(state = state, note = note), extra)
  if (identical(state, "running")) values$started <- workspace_jobs_now()
  if (state %in% workspace_jobs_terminal) values$ended <- workspace_jobs_now()
  workspace_jobs_update(jobs, run_id, values)
  rec <- workspace_jobs_record(jobs, run_id)
  line <- sprintf("Run %s (%s): %s", substr(run_id, 1L, 8L), rec$kind, workspace_jobs_state_label(state))
  if (!is.na(note) && nzchar(note)) line <- paste(line, "\u2014", note)
  jobs$announce(line)
  if (state %in% c("succeeded", "superseded", "interrupted")) {
    handle <- jobs$handles[[run_id]]
    if (!is.null(handle)) {
      handle$sources <- NULL
      handle$launch <- NULL
      handle$publish <- NULL
    }
  }
  workspace_jobs_bump(jobs)
  if (state %in% workspace_jobs_terminal) workspace_jobs_bound(jobs)
  invisible(NULL)
}

workspace_jobs_enable <- function(handle) {
  if (is.null(handle) || is.null(handle$module_session)) return(invisible(NULL))
  if (workspace_jobs_session_closed(workspace_jobs_root(handle$module_session))) return(invisible(NULL))
  shiny::withReactiveDomain(handle$module_session, shinyjs::enable(handle$button_id))
  invisible(NULL)
}

workspace_jobs_notify <- function(handle, text, type = "message", ...) {
  if (is.null(handle) || is.null(handle$module_session)) return(invisible(NULL))
  if (workspace_jobs_session_closed(workspace_jobs_root(handle$module_session))) return(invisible(NULL))
  shiny::withReactiveDomain(handle$module_session, shiny::showNotification(text, type = type, ...))
  invisible(NULL)
}

# A record that was never launched ends: the queue entry goes and the button returns.
workspace_jobs_end_unlaunched <- function(jobs, run_id, state, note, extra = list()) {
  workspace_job_queue_remove(run_id)
  workspace_jobs_transition(jobs, run_id, state, note, extra)
  workspace_jobs_enable(jobs$handles[[run_id]])
  invisible(NULL)
}

# History bound: while the registry holds more than history_runs records, drop the
# oldest evictable one (terminal, not in flight, not queued). Active and unsettled
# records are never dropped, so the count may exceed the bound only by them.
# Stores are untouched.
workspace_jobs_bound <- function(jobs, imported_first = FALSE) {
  limit <- tryCatch(as.integer(jobs$policy_loader()$limits$history_runs), error = function(e) NA_integer_)
  if (length(limit) != 1L || is.na(limit)) return(invisible(NULL))
  queued_ids <- vapply(.workspace_job_queue$entries, function(e) e$run_id, character(1))
  evictable <- function() {
    vapply(jobs$records, function(r) r$state %in% workspace_jobs_terminal &&
             !(r$run_id %in% jobs$in_flight) && !(r$run_id %in% queued_ids), logical(1))
  }
  ev <- evictable()
  while (length(jobs$records) > limit && any(ev)) {
    candidates <- which(ev)
    if (imported_first) {
      imported <- candidates[vapply(jobs$records[candidates], function(r) r$run_id %in% jobs$imported, logical(1))]
      if (length(imported)) candidates <- imported
    }
    drop <- candidates[[1]]
    id <- jobs$records[[drop]]$run_id
    jobs$records <- jobs$records[-drop]
    if (exists(id, envir = jobs$handles, inherits = FALSE)) rm(list = id, envir = jobs$handles)
    jobs$imported <- setdiff(jobs$imported, id)
    ev <- evictable()
  }
  invisible(NULL)
}

# ---- revisions, authorization, supersede sweeps, close ------------------------------

workspace_jobs_revision <- function(jobs, store, label) {
  key <- paste0(store, ":", label)
  value <- jobs$revisions[[key]]
  if (is.null(value)) 0L else value
}

workspace_jobs_reason <- function(jobs, run_id) {
  if (isTRUE(jobs$closed)) return("session closed")
  rec <- workspace_jobs_record(jobs, run_id)
  if (is.null(rec)) return("record removed")
  if (!identical(rec$owner, jobs$owner) || !identical(rec$generation, jobs$generation)) return("workspace replaced")
  handle <- jobs$handles[[run_id]]
  for (src in handle$sources) {
    if (!identical(workspace_jobs_revision(jobs, src$store, src$label), src$revision) ||
        !identical(shiny::isolate(src$rv[[src$label]]), src$value)) {
      return(sprintf("input %s changed", src$label))
    }
  }
  "authorization lost"
}

# @MX:ANCHOR: [AUTO] The single authorization check for dispatch and every callback.
# @MX:REASON: Stale-result protection (REQ-002) holds only if every publication path passes here.
workspace_jobs_authorized <- function(jobs, run_id) {
  if (isTRUE(jobs$closed)) return(FALSE)
  rec <- workspace_jobs_record(jobs, run_id)
  if (is.null(rec)) return(FALSE)
  if (!identical(rec$owner, jobs$owner) || !identical(rec$generation, jobs$generation)) return(FALSE)
  if (!rec$state %in% c("queued", "running")) return(FALSE)
  handle <- jobs$handles[[run_id]]
  if (is.null(handle)) return(FALSE)
  for (src in handle$sources) {
    if (!identical(workspace_jobs_revision(jobs, src$store, src$label), src$revision)) return(FALSE)
    if (!identical(shiny::isolate(src$rv[[src$label]]), src$value)) return(FALSE)
  }
  TRUE
}

workspace_jobs_touch <- function(jobs, store, labels) {
  if (is.null(jobs) || !length(labels)) return(invisible(NULL))
  labels <- unique(as.character(labels))
  for (label in labels) {
    key <- paste0(store, ":", label)
    jobs$revisions[[key]] <- workspace_jobs_revision(jobs, store, label) + 1L
  }
  for (rec in jobs$records) {
    if (!identical(rec$state, "queued")) next
    hit <- Filter(function(inp) identical(inp$store, store) && inp$label %in% labels, rec$inputs)
    if (length(hit)) {
      workspace_jobs_end_unlaunched(jobs, rec$run_id, "superseded", sprintf("input %s changed", hit[[1]]$label))
    }
  }
  workspace_jobs_contain(workspace_job_queue_dispatch(), "touch")
  invisible(NULL)
}

workspace_jobs_commit_workspace_swap <- function(jobs) {
  if (is.null(jobs)) return(invisible(NULL))
  jobs$generation <- jobs$generation + 1L
  for (rec in jobs$records) {
    if (identical(rec$state, "queued")) workspace_jobs_end_unlaunched(jobs, rec$run_id, "superseded", "workspace replaced")
  }
  workspace_jobs_contain(workspace_job_queue_dispatch(), "workspace swap")
  invisible(NULL)
}

workspace_jobs_close <- function(jobs) {
  if (is.null(jobs)) return(invisible(NULL))
  workspace_jobs_contain({
    jobs$closed <- TRUE
    jobs$generation <- jobs$generation + 1L
    mine <- vapply(Filter(function(e) identical(e$registry, jobs), .workspace_job_queue$entries),
                   function(e) e$run_id, character(1))
    workspace_job_queue_remove(mine)
    for (id in jobs$in_flight) {
      rec <- workspace_jobs_record(jobs, id)
      handle <- jobs$handles[[id]]
      if (is.null(rec) || is.null(handle) || is.null(handle$future) || !isTRUE(rec$stop_supported)) next
      if (!isTRUE(workspace_jobs_resolved(handle$future))) workspace_jobs_cancel(handle$future)
    }
    workspace_job_queue_dispatch()
  }, "close")
  invisible(NULL)
}

# ---- admission ---------------------------------------------------------------------

workspace_jobs_digest <- function(kind, sources, settings) {
  digest::digest(list(kind, lapply(sources, function(s) list(s$store, s$label, s$revision)), settings))
}

# Run and Retry admission. Checks run in order before any enqueue; a refusal shows
# one notification and makes zero factory calls. Returns the run id or NULL.
# `sources` are list(store, label, rv, value); `taken` are existing cluster names, or a
# function returning them, read at each admission so that Retry checks current names.
workspace_jobs_submit <- function(jobs, kind, sources, settings, launch, publish, module_session, button_id,
                                  progress = "Analysis running in background...", taken = character(),
                                  retry_of = NA_character_) {
  refuse <- function(text) {
    shiny::withReactiveDomain(module_session, shiny::showNotification(text, type = "error"))
    NULL
  }
  policy <- tryCatch(jobs$policy_loader(), error = function(e) e)
  if (inherits(policy, "error") || is.null(policy)) return(refuse("Job checks unavailable: resource policy missing or invalid"))
  for (i in seq_along(sources)) {
    sources[[i]]$revision <- workspace_jobs_revision(jobs, sources[[i]]$store, sources[[i]]$label)
  }
  digest <- workspace_jobs_digest(kind, sources, settings)
  for (rec in jobs$records) {
    h <- jobs$handles[[rec$run_id]]
    if (rec$state %in% c("queued", "running") && !is.null(h) && identical(h$digest, digest)) {
      return(refuse(sprintf("An identical job is already queued or running (run %s)", substr(rec$run_id, 1L, 8L))))
    }
  }
  queued <- sum(vapply(jobs$records, function(r) identical(r$state, "queued"), logical(1)))
  if (queued >= workspace_job_session_queue_limit()) {
    return(refuse("This session already has a queued job; wait for it to start or stop it"))
  }
  if (identical(kind, "clustering")) {
    name <- settings$cluster_name
    reserved <- vapply(Filter(function(r) identical(r$kind, "clustering") && r$state %in% c("queued", "running"),
                              jobs$records), function(r) as.character(r$settings$cluster_name), character(1))
    if (name %in% c(if (is.function(taken)) taken() else taken, reserved)) {
      return(refuse(sprintf("A cluster result named %s already exists; choose another name", name)))
    }
  }
  workspace_job_queue_prune()
  waiting <- length(.workspace_job_queue$entries)
  if (waiting >= workspace_job_queue_limit()) {
    return(refuse(sprintf("The server job queue is full (%d waiting); try again later", waiting)))
  }

  run_id <- workspace_jobs_new_run_id(jobs)
  now <- workspace_jobs_now()
  record <- list(run_id = run_id, kind = kind, state = "queued", created = now, queued_at = now,
                 started = as.POSIXct(NA), ended = as.POSIXct(NA), owner = jobs$owner, generation = jobs$generation,
                 inputs = lapply(sources, function(s) list(store = s$store, label = s$label, revision = s$revision)),
                 settings = settings, retry_of = retry_of, imported_from = NA_character_, outputs = character(),
                 note = NA_character_, error_summary = NA_character_, stop_supported = FALSE)
  handle <- new.env(parent = emptyenv())
  handle$kind <- kind
  handle$sources <- sources
  handle$settings <- settings
  handle$launch <- launch
  handle$publish <- publish
  handle$module_session <- module_session
  handle$button_id <- button_id
  handle$progress <- progress
  handle$digest <- digest
  handle$taken <- taken
  assign(run_id, handle, envir = jobs$handles)
  jobs$records[[length(jobs$records) + 1L]] <- record
  .workspace_job_queue$seq <- .workspace_job_queue$seq + 1L
  .workspace_job_queue$entries[[length(.workspace_job_queue$entries) + 1L]] <-
    list(seq = .workspace_job_queue$seq, run_id = run_id, registry = jobs)
  workspace_job_queue_bump()
  jobs$announce(sprintf("Run %s (%s): Queued", substr(run_id, 1L, 8L), kind))
  workspace_jobs_bump(jobs)
  shiny::withReactiveDomain(module_session, shinyjs::disable(button_id))
  workspace_jobs_contain(workspace_job_queue_dispatch(), "enqueue")
  run_id
}

# ---- dispatch ----------------------------------------------------------------------

# Entries whose session has ended are dropped; their records stay with the session.
workspace_job_queue_prune <- function() {
  dead <- vapply(.workspace_job_queue$entries, function(e) isTRUE(e$registry$closed) ||
                   workspace_jobs_session_closed(e$registry$session), logical(1))
  if (any(dead)) {
    .workspace_job_queue$entries <- .workspace_job_queue$entries[!dead]
    workspace_job_queue_bump()
  }
  invisible(NULL)
}

# NULL: a policy load error (the entry waits, its session is told once); else a
# boolean from the 001 worker bound for this session (D2: one running job).
workspace_jobs_policy_admits <- function(registry) {
  policy <- tryCatch(registry$policy_loader(), error = function(e) NULL)
  if (is.null(policy)) return(NULL)
  isTRUE(tryCatch(workspace_check_resources(list(workers = length(registry$in_flight) + 1L), policy),
                  error = function(e) FALSE))
}

# @MX:WARN: [AUTO] Launches another session's job from whichever observer or callback calls it.
# @MX:REASON: Always call through workspace_jobs_contain; never call future() unless a worker is free.
workspace_job_queue_dispatch <- function() {
  workspace_job_queue_prune()
  repeat {
    free <- tryCatch(suppressWarnings(as.numeric(workspace_jobs_free_workers())), error = function(e) 0)
    if (length(free) != 1L || is.na(free) || free < 1) return(invisible(FALSE))
    entries <- .workspace_job_queue$entries
    if (!length(entries)) return(invisible(FALSE))
    entries <- entries[order(vapply(entries, function(e) e$seq, numeric(1)))]
    chosen <- NULL
    for (e in entries) {
      reg <- e$registry
      if (isTRUE(reg$closed)) next
      admits <- workspace_jobs_policy_admits(reg)
      if (is.null(admits)) {
        handle <- reg$handles[[e$run_id]]
        if (!is.null(handle) && !isTRUE(handle$policy_notified)) {
          handle$policy_notified <- TRUE
          workspace_jobs_notify(handle, "Job checks unavailable: resource policy missing or invalid; your queued job waits",
                                type = "warning")
        }
        next
      }
      if (isTRUE(admits)) {
        chosen <- e
        break
      }
    }
    if (is.null(chosen)) return(invisible(FALSE))
    jobs <- chosen$registry
    run_id <- chosen$run_id
    auth <- tryCatch(workspace_jobs_authorized(jobs, run_id), error = function(e) e)
    if (inherits(auth, "error")) {
      workspace_jobs_end_unlaunched(jobs, run_id, "failed", "Could not start",
                                    list(error_summary = workspace_jobs_error_summary(auth)))
      next
    }
    if (!isTRUE(auth)) {
      workspace_jobs_end_unlaunched(jobs, run_id, "superseded", workspace_jobs_reason(jobs, run_id))
      next
    }
    # Take: the entry leaves the queue and the record is running, with nothing between.
    .workspace_job_queue$entries <- Filter(function(e) !identical(e$run_id, run_id), .workspace_job_queue$entries)
    workspace_jobs_update(jobs, run_id, list(state = "running", started = workspace_jobs_now()))
    workspace_job_queue_bump()
    workspace_jobs_launch(jobs, run_id)
  }
}

workspace_jobs_launch <- function(jobs, run_id) {
  handle <- jobs$handles[[run_id]]
  shiny::withReactiveDomain(handle$module_session, {
    f <- tryCatch(handle$launch(), error = function(e) e)
    if (inherits(f, "error")) {
      workspace_jobs_transition(jobs, run_id, "failed", "Could not start",
                                list(error_summary = workspace_jobs_error_summary(f)))
      workspace_jobs_enable(handle)
      workspace_jobs_notify(handle, sprintf("%s could not start (run %s): %s", workspace_jobs_kind_label(handle$kind),
                                            substr(run_id, 1L, 8L), workspace_jobs_error_summary(f)), type = "error")
      return(invisible(FALSE))
    }
    promises::catch(promises::finally(promises::then(f,
      onFulfilled = function(value) workspace_jobs_contain(workspace_jobs_on_fulfilled(jobs, run_id, value), "fulfilled"),
      onRejected = function(err) workspace_jobs_contain(workspace_jobs_on_rejected(jobs, run_id, err), "rejected")),
      function() workspace_jobs_contain(workspace_jobs_on_finally(jobs, run_id), "finally")), function(e) NULL)
    jobs$in_flight <- c(jobs$in_flight, run_id)
    handle$future <- f
    cap <- tryCatch(workspace_jobs_capability(f), error = function(e) list(stop_supported = FALSE))
    handle$pid <- cap$pid
    handle$start <- cap$start
    handle$node <- cap$node
    workspace_jobs_transition(jobs, run_id, "running", NA_character_,
                              list(stop_supported = isTRUE(cap$stop_supported), started = workspace_jobs_now()))
    workspace_jobs_contain(shiny::showNotification(handle$progress, id = paste0("job-", run_id),
                                                   duration = NULL, type = "message"), "progress notification")
  })
  invisible(TRUE)
}

workspace_jobs_kind_label <- function(kind) if (identical(kind, "clustering")) "Clustering" else "Enrichment"

# Labels handed out by workspace_jobs_free_label while a publication runs. Publication
# has no rollback, so if publish() raises these are the outputs it may have written.
.workspace_job_publication <- new.env(parent = emptyenv())

workspace_jobs_publish <- function(handle, value) {
  .workspace_job_publication$labels <- character()
  .workspace_job_publication$active <- TRUE
  on.exit(.workspace_job_publication$active <- FALSE, add = TRUE)
  tryCatch(handle$publish(value), error = function(e) e)
}

# A publish error fails the record like a rejection; the note names any output that
# was already written.
workspace_jobs_publish_failed <- function(jobs, run_id, handle, err) {
  summary <- workspace_jobs_error_summary(err)
  written <- unique(.workspace_job_publication$labels)
  note <- if (length(written)) sprintf("Publication stopped by an error; already written and kept: %s",
                                       paste(written, collapse = ", ")) else NA_character_
  workspace_jobs_transition(jobs, run_id, "failed", note, list(error_summary = summary))
  text <- sprintf("%s failed (run %s): %s. Previous results are unchanged; use Retry in the job panel.",
                  workspace_jobs_kind_label(handle$kind), substr(run_id, 1L, 8L), summary)
  if (!is.na(note)) text <- paste0(text, " ", note, ".")
  workspace_jobs_notify(handle, text, type = "error", duration = 10)
  invisible(NULL)
}

workspace_jobs_on_fulfilled <- function(jobs, run_id, value) {
  handle <- jobs$handles[[run_id]]
  if (workspace_jobs_authorized(jobs, run_id) && !is.null(handle$publish)) {
    outputs <- workspace_jobs_publish(handle, value)
    if (inherits(outputs, "error")) return(workspace_jobs_publish_failed(jobs, run_id, handle, outputs))
    note <- attr(outputs, "note")
    workspace_jobs_transition(jobs, run_id, "succeeded", if (is.null(note)) NA_character_ else note,
                              list(outputs = as.character(outputs)))
  } else {
    rec <- workspace_jobs_record(jobs, run_id)
    if (!is.null(rec) && identical(rec$state, "running")) {
      workspace_jobs_transition(jobs, run_id, "superseded", workspace_jobs_reason(jobs, run_id))
    }
  }
  invisible(NULL)
}

workspace_jobs_on_rejected <- function(jobs, run_id, err) {
  handle <- jobs$handles[[run_id]]
  if (!is.null(handle)) handle$rejection_class <- class(err)[1]
  if (workspace_jobs_authorized(jobs, run_id)) {
    summary <- workspace_jobs_error_summary(err)
    workspace_jobs_transition(jobs, run_id, "failed", NA_character_, list(error_summary = summary))
    workspace_jobs_notify(handle, sprintf("%s failed (run %s): %s. Previous results are unchanged; use Retry in the job panel.",
                                          workspace_jobs_kind_label(handle$kind), substr(run_id, 1L, 8L), summary),
                          type = "error", duration = 10)
  } else {
    rec <- workspace_jobs_record(jobs, run_id)
    if (!is.null(rec) && identical(rec$state, "running")) {
      workspace_jobs_transition(jobs, run_id, "superseded", workspace_jobs_reason(jobs, run_id))
    }
  }
  invisible(NULL)
}

workspace_jobs_on_finally <- function(jobs, run_id) {
  jobs$in_flight <- setdiff(jobs$in_flight, run_id)
  handle <- jobs$handles[[run_id]]
  rec <- workspace_jobs_record(jobs, run_id)
  if (!is.null(rec) && !is.null(handle) && identical(rec$state, "detached") && isTRUE(handle$timeout_detached) &&
      identical(handle$rejection_class, "FutureCanceledError") &&
      !isTRUE(tryCatch(workspace_jobs_pid_alive(handle$pid, handle$start), error = function(e) TRUE))) {
    workspace_jobs_transition(jobs, run_id, "cancelled", "Stop confirmed after the timeout")
  }
  if (!isTRUE(jobs$closed) && !is.null(handle)) {
    if (!workspace_jobs_session_closed(workspace_jobs_root(handle$module_session))) {
      workspace_jobs_contain(
        shiny::withReactiveDomain(handle$module_session, shiny::removeNotification(paste0("job-", run_id))),
        "progress removal")
    }
    workspace_jobs_enable(handle)
  }
  if (!is.null(handle)) handle$future <- NULL
  workspace_jobs_bump(jobs)
  workspace_jobs_bound(jobs)
  workspace_jobs_contain(workspace_job_queue_dispatch(), "finally")
  invisible(NULL)
}

# ---- capability, acknowledgement ----------------------------------------------------

workspace_jobs_proc <- function(pid) {
  raw <- tryCatch(readLines(sprintf("/proc/%d/stat", as.integer(pid)), warn = FALSE)[1],
                  error = function(e) NA_character_, warning = function(w) NA_character_)
  if (length(raw) != 1L || is.na(raw)) return(NULL)
  fields <- strsplit(sub(".*\\) ", "", raw), " ", fixed = TRUE)[[1]]
  list(state = fields[1], start = fields[20])
}

# Alive, not a zombie, and still the process whose start time was recorded at launch.
workspace_jobs_pid_alive <- function(pid, start) {
  if (length(pid) != 1L || is.na(pid)) return(FALSE)
  if (!isTRUE(tools::pskill(as.integer(pid), 0L))) return(FALSE)
  info <- workspace_jobs_proc(pid)
  !is.null(info) && !identical(info$state, "Z") && identical(info$start, start)
}

# Stop is supported only for an owned, interruptible cluster worker whose PID and
# start time can be read now; otherwise running jobs offer Detach.
workspace_jobs_capability <- function(f) {
  out <- list(stop_supported = FALSE, pid = NA_integer_, start = NA_character_, node = NA_integer_)
  backend <- future::plan("backend")
  if (!inherits(backend, "ClusterFutureBackend") || !isTRUE(backend[["interrupts"]])) return(out)
  node <- backend[["workers"]][[f$node]]
  if (!inherits(node, "RichSOCKnode")) return(out)
  pid <- node$session_info$process$pid
  if (length(pid) != 1L || is.na(pid) || !is.numeric(pid) || as.integer(pid) == Sys.getpid()) return(out)
  info <- workspace_jobs_proc(pid)
  if (is.null(info)) return(out)
  list(stop_supported = TRUE, pid = as.integer(pid), start = info$start, node = f$node)
}

workspace_jobs_poll_acks <- function(jobs) {
  for (rec in jobs$records) {
    if (!identical(rec$state, "cancel_requested")) next
    handle <- jobs$handles[[rec$run_id]]
    if (is.null(handle)) next
    # The first look happens on a poll tick, never in the flush that requested Stop.
    if (!isTRUE(handle$ack_armed)) {
      handle$ack_armed <- TRUE
      next
    }
    if (!isTRUE(workspace_jobs_pid_alive(handle$pid, handle$start))) {
      workspace_jobs_transition(jobs, rec$run_id, "cancelled", "Stopped; the worker process ended")
    } else if (as.numeric(difftime(workspace_jobs_now(), handle$cancel_at, units = "secs")) > jobs$ack_timeout) {
      handle$timeout_detached <- TRUE
      workspace_jobs_transition(jobs, rec$run_id, "detached", sprintf(paste0(
        "Stop not confirmed within %s s; the computation may still be running and keeps this ",
        "session's worker slot until it ends"), format(jobs$ack_timeout)))
    }
  }
  invisible(NULL)
}

# ---- Stop, Detach, Retry ----------------------------------------------------------

workspace_jobs_action_valid <- function(jobs, value) {
  if (!is.list(value)) return(NULL)
  action <- value$action
  run <- value$run
  if (!is.character(action) || length(action) != 1L || is.na(action)) return(NULL)
  if (!is.character(run) || length(run) != 1L || is.na(run)) return(NULL)
  if (!action %in% c("stop", "detach", "retry")) return(NULL)
  rec <- workspace_jobs_record(jobs, run)
  if (is.null(rec)) return(NULL)
  if (!workspace_jobs_action_offered(jobs, rec, action)) return(NULL)
  list(action = action, run = run, record = rec)
}

workspace_jobs_retry_offered <- function(jobs, rec) {
  handle <- jobs$handles[[rec$run_id]]
  rec$state %in% c("failed", "cancelled") && !(rec$run_id %in% jobs$imported) && !is.null(handle) &&
    !is.null(handle$sources) && !is.null(handle$launch) && !isTRUE(handle$retry_dropped)
}

workspace_jobs_action_offered <- function(jobs, rec, action) {
  switch(action,
    stop = identical(rec$state, "queued") || (identical(rec$state, "running") && isTRUE(rec$stop_supported)),
    detach = identical(rec$state, "running") && !isTRUE(rec$stop_supported),
    retry = workspace_jobs_retry_offered(jobs, rec),
    FALSE)
}

workspace_jobs_stop <- function(jobs, run_id) {
  rec <- workspace_jobs_record(jobs, run_id)
  handle <- jobs$handles[[run_id]]
  if (identical(rec$state, "queued")) {
    # No future exists for a queued run: removal is synchronous and final.
    workspace_jobs_end_unlaunched(jobs, run_id, "cancelled", "Removed from the queue before it started")
    workspace_jobs_contain(workspace_job_queue_dispatch(), "stop")
    return(invisible(NULL))
  }
  if (isTRUE(workspace_jobs_resolved(handle$future))) {
    workspace_jobs_transition(jobs, run_id, "detached", "Finished before Stop; result not applied")
    return(invisible(NULL))
  }
  handle$cancel_at <- workspace_jobs_now()
  workspace_jobs_transition(jobs, run_id, "cancel_requested")
  workspace_jobs_cancel(handle$future)
  invisible(NULL)
}

workspace_jobs_detach <- function(jobs, run_id) {
  workspace_jobs_transition(jobs, run_id, "detached",
    "Result will be ignored; the computation keeps running and holds a worker until it finishes")
}

workspace_jobs_retry <- function(jobs, run_id) {
  rec <- workspace_jobs_record(jobs, run_id)
  handle <- jobs$handles[[run_id]]
  changed <- FALSE
  for (src in handle$sources) {
    if (!identical(workspace_jobs_revision(jobs, src$store, src$label), src$revision) ||
        !identical(shiny::isolate(src$rv[[src$label]]), src$value)) changed <- TRUE
  }
  if (changed) {
    handle$sources <- NULL
    handle$launch <- NULL
    handle$retry_dropped <- TRUE
    workspace_jobs_bump(jobs)
    workspace_jobs_notify(handle, "Inputs changed since this run; start a new run", type = "warning")
    return(invisible(NULL))
  }
  sources <- lapply(handle$sources, function(s) s[c("store", "label", "rv", "value")])
  workspace_jobs_submit(jobs, handle$kind, sources, handle$settings, handle$launch, handle$publish,
                        handle$module_session, handle$button_id, progress = handle$progress,
                        taken = handle$taken, retry_of = run_id)
  invisible(NULL)
}

# ---- panel ---------------------------------------------------------------------------

workspace_jobs_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tags$section(role = "region", `aria-label` = "Analysis jobs", class = "rs-workspace-jobs",
    shiny::uiOutput(ns("jobs_list")),
    shiny::uiOutput(ns("jobs_status")),
    shiny::tags$div(`aria-live` = "polite", shiny::uiOutput(ns("jobs_announce"))),
    shiny::uiOutput(ns("jobs_time")))
}

workspace_jobs_settings_text <- function(settings) {
  out <- character()
  for (key in names(settings)) {
    value <- settings[[key]]
    if (is.atomic(value) && length(value) && !is.null(value)) {
      out <- c(out, paste0(key, ": ", paste(as.character(value), collapse = ", ")))
    } else if (is.list(value) && length(value) && all(vapply(value, function(v) is.atomic(v) && length(v) == 1L, logical(1)))) {
      # Imported (canonical-form) vectors are unnamed lists: show the values alone.
      labels <- names(value)
      prefix <- if (is.null(labels)) rep("", length(value)) else ifelse(nzchar(labels), paste0(labels, "="), "")
      out <- c(out, paste0(key, ": ", paste0(prefix, unlist(value), collapse = ", ")))
    }
  }
  out
}

workspace_jobs_button <- function(ns, action, run_id, label) {
  shiny::tags$button(type = "button", class = "btn btn-default btn-sm",
    onclick = sprintf("Shiny.setInputValue('%s', {action: '%s', run: '%s', nonce: Date.now()}, {priority: 'event'})",
                      ns("job_action"), action, run_id),
    label)
}

workspace_jobs_status_line <- function(jobs, rec) {
  if (identical(rec$state, "queued")) {
    if (length(jobs$in_flight) >= 1L) return("Queued: waiting for this session's active job")
    entries <- .workspace_job_queue$entries
    mine <- Filter(function(e) identical(e$run_id, rec$run_id), entries)
    ahead <- if (length(mine)) sum(vapply(entries, function(e) e$seq < mine[[1]]$seq, logical(1))) else 0L
    return(sprintf("Queued: %d job(s) ahead in this server's queue", ahead))
  }
  if (identical(rec$state, "running")) return(paste("Running.", "Progress: not reported by this engine"))
  workspace_jobs_state_label(rec$state)
}

workspace_jobs_time_value <- function(x) {
  if (is.null(x) || length(x) != 1L || is.na(x)) return(NULL)
  if (is.character(x)) x <- as.POSIXct(x, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  x
}

workspace_jobs_server <- function(id, jobs) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns
    output$jobs_list <- shiny::renderUI({
      jobs$tick()
      records <- jobs$records
      if (!length(records)) return(NULL)
      # One malformed record shows a placeholder instead of erroring the whole list.
      shiny::tags$ul(class = "rs-job-list", lapply(records, function(rec) tryCatch({
        buttons <- list()
        if (workspace_jobs_action_offered(jobs, rec, "stop")) buttons <- c(buttons, list(workspace_jobs_button(ns, "stop", rec$run_id, "Stop")))
        if (workspace_jobs_action_offered(jobs, rec, "detach")) buttons <- c(buttons, list(workspace_jobs_button(ns, "detach", rec$run_id, "Detach (keeps running)")))
        if (workspace_jobs_action_offered(jobs, rec, "retry")) buttons <- c(buttons, list(workspace_jobs_button(ns, "retry", rec$run_id, "Retry")))
        labels <- vapply(rec$inputs, function(inp) as.character(inp$label), character(1))
        shiny::tags$li(class = "rs-job",
          shiny::tags$span(class = "rs-job-kind", workspace_jobs_kind_label(rec$kind)), " ",
          shiny::tags$code(class = "rs-job-id", substr(rec$run_id, 1L, 8L)), " ",
          shiny::tags$span(class = "rs-job-inputs", paste("Inputs:", paste(labels, collapse = ", "))),
          shiny::tags$ul(class = "rs-job-settings", lapply(workspace_jobs_settings_text(rec$settings), shiny::tags$li)),
          buttons)
      }, error = function(e) shiny::tags$li(class = "rs-job", "This run record could not be displayed"))))
    })
    output$jobs_status <- shiny::renderUI({
      jobs$tick()
      records <- jobs$records
      if (any(vapply(records, function(r) identical(r$state, "queued"), logical(1)))) workspace_job_queue_version()()
      if (!length(records)) return(NULL)
      # One malformed record shows a placeholder instead of erroring the whole status.
      shiny::tagList(lapply(records, function(rec) tryCatch({
        note <- rec$note
        summary <- rec$error_summary
        shiny::tags$p(class = "rs-job-status",
          shiny::tags$code(substr(rec$run_id, 1L, 8L)), " ", workspace_jobs_status_line(jobs, rec),
          if (!is.null(note) && !is.na(note) && nzchar(note)) paste0(" \u2014 ", note),
          if (!is.null(summary) && !is.na(summary) && nzchar(summary)) paste0(" Error: ", summary))
      }, error = function(e) shiny::tags$p(class = "rs-job-status",
        shiny::tags$code(tryCatch(substr(as.character(rec$run_id), 1L, 8L), error = function(e) "?")),
        " This run record could not be displayed"))))
    })
    output$jobs_announce <- shiny::renderUI({
      line <- jobs$announce()
      if (nzchar(line)) shiny::tags$p(line)
    })
    output$jobs_time <- shiny::renderUI({
      jobs$tick()
      active <- Filter(function(r) r$state %in% c("queued", "running", "cancel_requested") ||
                         r$run_id %in% jobs$in_flight, jobs$records)
      if (!length(active)) return(NULL)
      shiny::invalidateLater(1000)
      now <- workspace_jobs_now()
      shiny::tagList(lapply(active, function(rec) {
        from <- if (identical(rec$state, "queued")) workspace_jobs_time_value(rec$queued_at) else
          workspace_jobs_time_value(rec$started)
        if (is.null(from)) from <- workspace_jobs_time_value(rec$queued_at)
        elapsed <- if (is.null(from)) 0L else as.integer(round(as.numeric(difftime(now, from, units = "secs"))))
        shiny::tags$p(class = "rs-job-time", sprintf("Run %s %s %s; elapsed %d s", substr(rec$run_id, 1L, 8L),
          if (identical(rec$state, "queued")) "queued at" else "started at",
          if (is.null(from)) "?" else format(from, "%H:%M:%S", tz = "UTC"), elapsed))
      }))
    })
    shiny::observeEvent(input$job_action, {
      workspace_jobs_contain({
        valid <- workspace_jobs_action_valid(jobs, input$job_action)
        if (is.null(valid)) {
          shiny::showNotification("Unknown or unavailable job action", type = "warning")
        } else {
          switch(valid$action,
            stop = workspace_jobs_stop(jobs, valid$run),
            detach = workspace_jobs_detach(jobs, valid$run),
            retry = workspace_jobs_retry(jobs, valid$run))
        }
      }, "job action")
    })
  })
}

# ---- clustering runner seam: the future body of the Run observer ---------------------

workspace_cluster_compute <- function(genesets, method, params, cluster_name) {
  gs_names <- names(genesets)

  # Merge genesets
  merged_gs <- if (length(genesets) == 1) {
    normalize_geneset(genesets[[1]])
  } else {
    merge_genesets(genesets)
  }

  # Run clustering
  cluster_result <- perform_clustering(merged_gs, method = method,
                                       params = params, gs_names = gs_names,
                                       raw_genesets = genesets)

  # Process results (all pure data manipulation, no reactive access)
  cluster_df <- cluster_result$cluster_df

  if (!is.null(cluster_df) && nrow(cluster_df) > 0) {
    # Add Representative_Term for visualization compatibility
    if ("Padj" %in% colnames(cluster_df)) {
      cluster_df <- cluster_df %>%
        dplyr::group_by(Cluster) %>%
        dplyr::mutate(
          Representative_Term = {
            padj_vals <- Padj
            if (all(is.na(padj_vals))) {
              Term[1]
            } else {
              Term[which.min(padj_vals)]
            }
          }
        ) %>%
        dplyr::ungroup()
    } else if ("Pvalue" %in% colnames(cluster_df)) {
      cluster_df <- cluster_df %>%
        dplyr::group_by(Cluster) %>%
        dplyr::mutate(
          Representative_Term = {
            pval_vals <- Pvalue
            if (all(is.na(pval_vals))) {
              Term[1]
            } else {
              Term[which.min(pval_vals)]
            }
          }
        ) %>%
        dplyr::ungroup()
    } else {
      cluster_df <- cluster_df %>%
        dplyr::group_by(Cluster) %>%
        dplyr::mutate(Representative_Term = Term[1]) %>%
        dplyr::ungroup()
    }

    # Build summary data (one row per cluster) for visualization heatmap; the
    # row is the representative term's, so the values describe that term
    pval_padj_cols <- grep("^(Pvalue_|Padj_)", colnames(cluster_df), value = TRUE)
    summary_cols <- c("Cluster", "Representative_Term", pval_padj_cols)
    available_summary_cols <- intersect(summary_cols, colnames(cluster_df))

    if (length(available_summary_cols) >= 2) {
      summary_df <- cluster_df %>%
        dplyr::group_by(Cluster) %>%
        dplyr::slice(max(match(Representative_Term[1], Term), 1L, na.rm = TRUE)) %>%
        dplyr::ungroup()
      summary_df <- as.data.frame(summary_df[, available_summary_cols, drop = FALSE])
    } else {
      summary_df <- cluster_df %>%
        dplyr::group_by(Cluster) %>%
        dplyr::slice(max(match(Representative_Term[1], Term), 1L, na.rm = TRUE)) %>%
        dplyr::ungroup()
      summary_df <- as.data.frame(summary_df[, intersect(c("Cluster", "Representative_Term"), colnames(cluster_df)), drop = FALSE])
    }

    # Build tracking row
    new_row <- data.frame(
      name = cluster_name,
      method = method,
      n_clusters = length(unique(cluster_df$Cluster)),
      n_terms = nrow(cluster_df),
      stringsAsFactors = FALSE
    )

    list(
      success = TRUE,
      cluster_name = cluster_name,
      summary_df = summary_df,
      cluster_df = as.data.frame(cluster_df),
      cluster_result = cluster_result,
      method = method,
      params = params,
      new_row = new_row,
      gs_names = gs_names
    )
  } else {
    list(success = FALSE)
  }
}

# The six-column file-table row for a suffixed enrichment label (file_handling.R:120-150 shape).
workspace_jobs_rrdf_row <- function(df, label, deg, res) {
  value <- function(x) if (is.null(x) || !length(x)) "?" else as.character(x)[1]
  row <- c(name = label, from_deg = deg, annot = value(res$anntype), keytype = value(res$keytype),
           ontology = value(res$ontology), species = value(res$species))
  if (is.null(df)) {
    df <- as.data.frame(t(row))
  } else {
    df <- rbind(df, row)
    names(df) <- c("name", "from_deg", "annot", "keytype", "ontology", "species")
  }
  rownames(df) <- NULL
  df
}

# The smallest free label: `base`, else `base_<k>` with k >= 2.
workspace_jobs_free_label <- function(base, taken) {
  label <- base
  k <- 2L
  while (label %in% taken) {
    label <- paste0(base, "_", k)
    k <- k + 1L
  }
  if (isTRUE(.workspace_job_publication$active)) {
    .workspace_job_publication$labels <- c(.workspace_job_publication$labels, label)
  }
  label
}
