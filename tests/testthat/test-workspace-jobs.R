# SPEC-WS-006 owned jobs, queue, cancellation and stale-result guards.
#
# Cases R1-R30 follow the accepted dispatch plan (r6, step 4); R31-R33 reproduce code
# review r1 findings F1-F3, R34-R36 review r2 findings F13, F11, F12, and R37 owner
# decision D14 (shiny >= 1.14 session teardown). Internals are reached through richStudio:::; only these
# seams are replaced, with
# testthat::local_mocked_bindings(.package = "richStudio"):
#   workspace_jobs_now, workspace_jobs_free_workers, workspace_jobs_future,
#   workspace_jobs_cancel, workspace_jobs_pid_alive, workspace_cluster_compute,
#   workspace_jobs_resolved, workspace_jobs_capability, workspace_jobs_authorized,
#   workspace_job_queue_limit, workspace_job_session_queue_limit.
# future::resolved itself is never mocked (promises polls it).
#
# Sessions are shiny::MockShinySession objects in one process; modules are mounted
# with shiny::withReactiveDomain(), as app.R mounts them. Worker tests own their
# multisession workers: cleanup is registered before plan(), switches to sequential,
# then SIGKILLs only recorded PIDs whose /proc start time still matches, and asserts
# that none remains. Delayed workers wait on a latch file for at most 30 s.
#
# Names the plan leaves open and these tests fix: the run-id generator
# workspace_jobs_new_run_id(jobs) (R1); the handle fields handles[[id]]$pid;
# workspace_cluster_compute(genesets, method, params, cluster_name) (the mock reads
# its arguments by name, falling back to position).

# ---- messages and labels (plan items 2, 3, 5, 8, 9, 10) ------------------------

ws6_msg <- list(
  policy = "Job checks unavailable: resource policy missing or invalid",
  policy_wait = "Job checks unavailable: resource policy missing or invalid; your queued job waits",
  identical = "An identical job is already queued or running",
  session_queue = "This session already has a queued job; wait for it to start or stop it",
  cluster_name = "A cluster result named %s already exists; choose another name",
  queue_full = "The server job queue is full (%d waiting); try again later",
  unknown = "Unknown or unavailable job action",
  retry_changed = "Inputs changed since this run; start a new run",
  removed = "Removed from the queue before it started",
  late = "Finished before Stop; result not applied",
  unconfirmed = "Stop not confirmed within",
  confirmed_late = "Stop confirmed after the timeout",
  could_not_start = "Could not start",
  interrupted = "Session was saved while this run was queued or active; it was not resumed or re-queued",
  waiting = "Queued: waiting for this session's active job",
  ahead = "Queued: %d job(s) ahead in this server's queue",
  progress = "Progress: not reported by this engine",
  detach = "Detach (keeps running)",
  enrich_ok = "DEG set(s) enriched successfully!",
  cluster_ok = "Clustering complete!"
)

# ---- process identity and owned workers ---------------------------------------

ws6_proc <- function(pid) {
  path <- sprintf("/proc/%d/stat", as.integer(pid))
  raw <- tryCatch(readLines(path, warn = FALSE)[1], error = function(e) NA_character_,
                  warning = function(w) NA_character_)
  if (length(raw) != 1L || is.na(raw)) return(NULL)
  fields <- strsplit(sub(".*\\) ", "", raw), " ", fixed = TRUE)[[1]]
  list(state = fields[1], start = fields[20])
}

# Alive and still the same process (start time unchanged; zombies count as gone).
ws6_same <- function(rec) {
  now <- ws6_proc(rec$pid)
  !is.null(now) && !identical(now$state, "Z") && identical(now$start, rec$start)
}

ws6_alive <- function(pid) {
  now <- ws6_proc(pid)
  !is.null(now) && !identical(now$state, "Z")
}

ws6_own_pid <- function(own, pid) {
  pid <- suppressWarnings(as.integer(pid))
  if (length(pid) != 1L || is.na(pid) || pid == Sys.getpid()) return(invisible(own))
  info <- ws6_proc(pid)
  key <- as.character(pid)
  if (!is.null(info) && is.null(own$pids[[key]])) own$pids[[key]] <- list(pid = pid, start = info$start)
  invisible(own)
}

# Record the backend's worker PIDs; called after every launch and every cancel.
ws6_own <- function(own) {
  workers <- tryCatch(future::plan("backend")[["workers"]], error = function(e) NULL)
  for (i in seq_along(workers)) {
    pid <- tryCatch(workers[[i]]$session_info$process$pid, error = function(e) NA_integer_)
    if (length(pid) == 1L) ws6_own_pid(own, pid)
  }
  invisible(own)
}

ws6_workers <- function(n, interrupts = TRUE, dir = NULL, env = parent.frame()) {
  own <- new.env(parent = emptyenv())
  own$pids <- list()
  withr::defer({
    if (!is.null(dir) && dir.exists(dir)) file.create(file.path(dir, "release.all"))
    future::plan(future::sequential)
    for (rec in own$pids) if (ws6_same(rec)) tools::pskill(rec$pid, tools::SIGKILL)
    deadline <- Sys.time() + 5
    while (any(vapply(own$pids, ws6_same, logical(1))) && Sys.time() < deadline) Sys.sleep(0.05)
    remaining <- Filter(ws6_same, own$pids)
    testthat::expect_identical(names(remaining), character(), label = "owned workers left after cleanup")
  }, envir = env)
  if (interrupts) {
    future::plan(future::multisession, workers = I(n))
  } else {
    future::plan(future::multisession, workers = I(n), interrupts = FALSE)
  }
  ws6_own(own)
}

ws6_sequential <- function(env = parent.frame()) {
  previous <- future::plan()
  withr::defer(future::plan(previous), envir = env)
  future::plan(future::sequential)
}

# ---- latch runners (cleanup-guaranteed: every wait is bounded by 30 s) -----------

ws6_key <- function(label, k = 1L) sprintf("%s.%d", gsub("[^A-Za-z0-9_]", "_", label), as.integer(k))

# One runner kit per latch directory. Each call claims `<label>.<k>` atomically,
# writes `<key>.pid`, records its arguments in `<key>.call.rds`, waits for
# `<key>.release` (or `release.all`) for at most 30 s, then returns a fixed valid
# result. `fail.txt` makes every call fail with its first line; `fail_on.txt`
# names an input label that fails after earlier inputs were computed.
ws6_latch_runner <- function(dir) {
  dir <- normalizePath(dir, mustWork = TRUE)
  claim <- function(label) {
    k <- 1L
    while (!dir.create(file.path(dir, paste0(ws6_key(label, k), ".claim")), showWarnings = FALSE)) k <- k + 1L
    ws6_key(label, k)
  }
  latch <- function(key, call) {
    tmp <- file.path(dir, paste0(key, ".tmp"))
    saveRDS(call, tmp)
    file.rename(tmp, file.path(dir, paste0(key, ".call.rds")))
    writeLines(as.character(Sys.getpid()), tmp)
    file.rename(tmp, file.path(dir, paste0(key, ".pid")))
    deadline <- Sys.time() + 30
    while (!file.exists(file.path(dir, paste0(key, ".release"))) &&
           !file.exists(file.path(dir, "release.all")) && Sys.time() < deadline) Sys.sleep(0.02)
    fail <- file.path(dir, "fail.txt")
    if (file.exists(fail)) {
      file.create(file.path(dir, paste0(key, ".done")))
      stop(readLines(fail, warn = FALSE)[1], call. = FALSE)
    }
  }
  enrichment <- function(deg_inputs, cutoff, species, anntype, keytype, ontology) {
    labels <- vapply(deg_inputs, function(x) x$name, character(1))
    key <- claim(labels[[1]])
    latch(key, list(labels = labels, species = species, anntype = anntype, keytype = keytype,
                    ontology = ontology, cutoff = cutoff, pid = Sys.getpid()))
    fail_on <- file.path(dir, "fail_on.txt")
    results <- list()
    for (inp in deg_inputs) {
      if (file.exists(fail_on) && identical(inp$name, readLines(fail_on, warn = FALSE)[1])) {
        file.create(file.path(dir, paste0(key, ".done")))
        stop(paste(inp$name, "failed in the batch"), call. = FALSE)
      }
      results[[length(results) + 1L]] <- list(
        name = inp$name,
        result = data.frame(Annot = "Term one", Term = "T1", Pvalue = 0.01, Padj = 0.02,
                            GeneID = "g1,g2", stringsAsFactors = FALSE),
        anntype = if (is.null(anntype)) "Reactome" else anntype,
        keytype = if (is.null(keytype)) "SYMBOL" else keytype,
        ontology = if (is.null(ontology)) "" else ontology,
        species = if (is.null(species)) "custom" else species)
    }
    file.create(file.path(dir, paste0(key, ".done")))
    results
  }
  cluster <- function(...) {
    args <- list(...)
    pick <- function(name, pos) if (!is.null(args[[name]])) args[[name]] else if (length(args) >= pos) args[[pos]] else NULL
    genesets <- pick("genesets", 1L)
    method <- pick("method", 2L)
    params <- pick("params", 3L)
    cluster_name <- pick("cluster_name", 4L)
    key <- claim(cluster_name)
    latch(key, list(labels = names(genesets), cluster_name = cluster_name, method = method,
                    params = params, pid = Sys.getpid()))
    cluster_df <- data.frame(Term = c("T1", "T2"), Cluster = c(1L, 1L), Representative_Term = "T1",
                             stringsAsFactors = FALSE)
    file.create(file.path(dir, paste0(key, ".done")))
    list(success = TRUE, cluster_name = cluster_name,
         summary_df = data.frame(Cluster = 1L, Representative_Term = "T1"),
         cluster_df = cluster_df,
         cluster_result = list(distance_matrix = matrix(1, 1, 1), cluster_summary = data.frame(Cluster = 1L)),
         method = method, params = params,
         new_row = data.frame(name = cluster_name, method = if (is.null(method)) "?" else method,
                              n_clusters = 1L, n_terms = 2L, stringsAsFactors = FALSE),
         gs_names = names(genesets))
  }
  list(dir = dir, enrichment = enrichment, cluster = cluster)
}

ws6_release <- function(dir, key) file.create(file.path(dir, paste0(key, ".release")))
ws6_release_all <- function(dir) file.create(file.path(dir, "release.all"))
ws6_started <- function(dir, key) file.exists(file.path(dir, paste0(key, ".pid")))
ws6_done <- function(dir, key) file.exists(file.path(dir, paste0(key, ".done")))
ws6_claims <- function(dir, label) {
  length(list.files(dir, pattern = paste0("^", gsub("[^A-Za-z0-9_]", "_", label), "\\.[0-9]+\\.claim$")))
}
ws6_call <- function(dir, key) readRDS(file.path(dir, paste0(key, ".call.rds")))

ws6_pid <- function(dir, key, sessions = list(), timeout = 20, own = NULL) {
  ok <- ws6_until(function() ws6_started(dir, key), sessions, timeout = timeout)
  if (!ok) return(NA_integer_)
  pid <- as.integer(readLines(file.path(dir, paste0(key, ".pid")), warn = FALSE)[1])
  if (!is.null(own)) {
    ws6_own_pid(own, pid)
    ws6_own(own)
  }
  pid
}

# ---- sessions, stores and modules ----------------------------------------------

ws6_state <- function() {
  list(u_degnames = shiny::reactiveValues(labels = NULL), u_degdfs = shiny::reactiveValues(),
       u_big_degdf = shiny::reactiveValues(),
       u_rrnames = shiny::reactiveValues(labels = NULL), u_rrdfs = shiny::reactiveValues(),
       u_big_rrdf = shiny::reactiveValues(),
       u_clusnames = shiny::reactiveValues(labels = NULL), u_clusdfs = shiny::reactiveValues(),
       u_big_clusdf = shiny::reactiveValues(), u_cluslists = shiny::reactiveValues(),
       clus_intermed = shiny::reactiveValues())
}

ws6_deg_df <- function(n = 4L) data.frame(gene = paste0("g", seq_len(n)), Padj = rep(0.01, n))

ws6_add_deg <- function(state, labels, df = ws6_deg_df()) {
  shiny::isolate({
    for (label in labels) {
      state$u_degdfs[[label]] <- df
      state$u_big_degdf$df <- richStudio::add_file_degdf(state$u_big_degdf$df, label, df)
    }
    state$u_degnames$labels <- c(state$u_degnames$labels, labels)
  })
  invisible(state)
}

ws6_cluster_rr <- function() {
  g <- function(i) paste0("g", i, collapse = ",")
  data.frame(Term = paste0("T", 1:6), Annot = paste("term", 1:6),
             GeneID = c(g(1:8), g(c(1:7, 9)), g(c(1:6, 9:10)), g(11:18), g(c(11:17, 19)), g(c(11:16, 19:20))),
             Pvalue = c(1e-6, 2e-6, 3e-6, 1e-5, 2e-5, 3e-5), Padj = c(1e-5, 2e-5, 3e-5, 1e-4, 2e-4, 3e-4),
             stringsAsFactors = FALSE)
}

ws6_add_rr <- function(state, labels, df = ws6_cluster_rr()) {
  shiny::isolate({
    for (label in labels) {
      state$u_rrdfs[[label]] <- df
      state$u_big_rrdf$df <- richStudio::add_file_rrdf(state$u_big_rrdf$df, name = label, file = TRUE)
    }
    state$u_rrnames$labels <- c(state$u_rrnames$labels, labels)
  })
  invisible(state)
}

ws6_snapshot <- function(state) {
  shiny::isolate(list(
    degnames = state$u_degnames$labels, degdfs = shiny::reactiveValuesToList(state$u_degdfs),
    rrnames = state$u_rrnames$labels, rrdfs = shiny::reactiveValuesToList(state$u_rrdfs),
    big_rr = state$u_big_rrdf$df, clusnames = state$u_clusnames$labels,
    clusdfs = shiny::reactiveValuesToList(state$u_clusdfs),
    cluslists = shiny::reactiveValuesToList(state$u_cluslists), big_clus = state$u_big_clusdf$df,
    intermed = shiny::reactiveValuesToList(state$clus_intermed)))
}

# A MockShinySession whose notifications, custom messages, input messages and
# output renders are captured. `probe`, when set, is evaluated at every custom
# message so its result shows what the stores held when the message was sent.
ws6_session <- function(tag, probe = NULL, env = parent.frame()) {
  s <- shiny::MockShinySession$new()
  log <- new.env(parent = emptyenv())
  log$notes <- list()
  log$custom <- list()
  log$inputs <- list()
  log$renders <- list()
  log$probe <- probe
  log$nonce <- 0L
  log$enrich_n <- 0L
  log$cluster_n <- 0L
  s$sendNotification <- function(type, message) {
    log$notes[[length(log$notes) + 1L]] <- list(type = type, message = message)
  }
  s$sendCustomMessage <- function(type, message) {
    seen <- if (is.function(log$probe)) shiny::isolate(log$probe()) else NULL
    log$custom[[length(log$custom) + 1L]] <- list(type = type, message = message, probe = seen)
  }
  original_input <- s$sendInputMessage
  s$sendInputMessage <- function(inputId, message) {
    log$inputs[[length(log$inputs) + 1L]] <- list(id = inputId, message = message)
    original_input(inputId, message)
  }
  # A wrapped output: every render of every output is counted per output name.
  # defineOutput is an R6 method, so its binding is locked; unlock it to wrap it.
  original_define <- s$defineOutput
  unlockBinding("defineOutput", s)
  s$defineOutput <- function(name, func, label) {
    force(name)
    force(func)
    counted <- if (is.function(func)) function(...) {
      log$renders[[name]] <- (if (is.null(log$renders[[name]])) 0L else log$renders[[name]]) + 1L
      value <- func(...)
      log$values[[name]] <- value
      value
    } else func
    original_define(name, counted, label)
  }
  lockBinding("defineOutput", s)
  sess <- list(s = s, log = log, tag = tag)
  withr::defer(if (!s$isClosed()) s$close(), envir = env)
  sess
}

ws6_renders <- function(sess, output) {
  n <- sess$log$renders[[output]]
  if (is.null(n)) 0L else n
}

ws6_show_html <- function(note) {
  m <- note$message
  if (is.list(m) && !is.null(m$html)) paste(as.character(m$html), collapse = "") else ""
}

ws6_shown <- function(sess, pattern, from = 0L) {
  notes <- sess$log$notes
  keep <- seq_along(notes) > from
  sum(vapply(notes[keep], function(n) identical(n$type, "show") && grepl(pattern, ws6_show_html(n), fixed = TRUE),
             logical(1)))
}

ws6_note_ids <- function(sess, type) {
  out <- character()
  for (n in sess$log$notes) {
    if (!identical(n$type, type)) next
    id <- if (is.list(n$message)) n$message$id else n$message
    if (length(id) == 1L && !is.null(id)) out <- c(out, as.character(id))
  }
  out
}

ws6_enables <- function(sess, id) {
  sum(vapply(sess$log$custom, function(m) identical(m$type, "shinyjs-enable") && identical(m$message$id, id),
             logical(1)))
}

# getOutput() drains the whole later loop (shiny:::wait_for_it), which never empties
# while a future is unresolved; read the value the wrapped output last rendered.
ws6_html <- function(sess, output) {
  sess$s$flushReact()
  value <- sess$log$values[[output]]
  if (is.list(value) && !is.null(value$html)) paste(as.character(value$html), collapse = "") else
    paste(as.character(value), collapse = "")
}

ws6_buttons <- function(html) regmatches(html, gregexpr("<button[^>]*>.*?</button>", html, perl = TRUE))[[1]]

ws6_has_button <- function(html, run_id, label) {
  any(vapply(ws6_buttons(html), function(b) grepl(run_id, b, fixed = TRUE) && grepl(label, b, fixed = TRUE),
             logical(1)))
}

ws6_buttons_for <- function(html, run_id) sum(vapply(ws6_buttons(html), grepl, logical(1), pattern = run_id, fixed = TRUE))

ws6_download <- function(sess) {
  function(filename, content, ...) {
    sess$log$download <- content
    shiny::downloadHandler(filename, content, ...)
  }
}

ws6_mount <- function(sess, state, modules = "enrich", runner = NULL, jobs = NULL) {
  s <- sess$s
  shiny::withReactiveDomain(s, {
    if ("enrich" %in% modules) {
      args <- list("enrich", u_degnames = state$u_degnames, u_degdfs = state$u_degdfs,
                   u_big_degdf = state$u_big_degdf, u_rrnames = state$u_rrnames,
                   u_rrdfs = state$u_rrdfs, u_big_rrdf = state$u_big_rrdf)
      if (!is.null(runner)) args$enrichment_runner <- runner
      do.call(richStudio:::enrichTabServer, args)
    }
    if ("cluster" %in% modules) {
      richStudio::clusterTabServer("cluster", u_degnames = state$u_degnames, u_degdfs = state$u_degdfs,
        u_rrnames = state$u_rrnames, u_rrdfs = state$u_rrdfs, u_big_rrdf = state$u_big_rrdf,
        u_clusnames = state$u_clusnames, u_clusdfs = state$u_clusdfs, u_big_clusdf = state$u_big_clusdf,
        u_cluslists = state$u_cluslists, clus_intermed = state$clus_intermed)
    }
    if ("upload" %in% modules) {
      richStudio:::clusterUploadTabServer("cluster_upload", u_degnames = state$u_degnames,
        u_degdfs = state$u_degdfs, u_rrnames = state$u_rrnames, u_rrdfs = state$u_rrdfs,
        u_big_rrdf = state$u_big_rrdf, u_clusnames = state$u_clusnames, u_clusdfs = state$u_clusdfs,
        u_big_clusdf = state$u_big_clusdf, u_cluslists = state$u_cluslists)
    }
    if ("update" %in% modules) {
      richStudio::updateTabServer("update", u_degnames = state$u_degnames, u_degdfs = state$u_degdfs,
        u_rrnames = state$u_rrnames, u_rrdfs = state$u_rrdfs, u_clusnames = state$u_clusnames,
        u_clusdfs = state$u_clusdfs, u_cluslists = state$u_cluslists)
    }
    if ("save" %in% modules) {
      richStudio::saveTabServer("save", u_degnames = state$u_degnames, u_degdfs = state$u_degdfs,
        u_rrnames = state$u_rrnames, u_rrdfs = state$u_rrdfs, u_clusnames = state$u_clusnames,
        u_clusdfs = state$u_clusdfs, u_cluslists = state$u_cluslists, download_handler = ws6_download(sess))
    }
    if ("panel" %in% modules) richStudio:::workspace_jobs_server("jobs", jobs)
  })
  s$flushReact()
  invisible(sess)
}

# The registry as app.R installs it: created in the session, stored in userData
# before the module servers start, closed first in onSessionEnded.
ws6_install <- function(sess, ...) {
  jobs <- shiny::withReactiveDomain(sess$s, richStudio:::workspace_jobs_registry(sess$s, ...))
  sess$s$userData$workspace_jobs <- jobs
  sess$s$onSessionEnded(function() richStudio:::workspace_jobs_close(jobs))
  jobs
}

# app.R's close wiring for a registry a module created lazily; inert while none exists.
ws6_close_wiring <- function(sess) {
  sess$s$onSessionEnded(function() {
    jobs <- sess$s$userData$workspace_jobs
    if (!is.null(jobs)) richStudio:::workspace_jobs_close(jobs)
  })
}

ws6_run <- function(sess, labels, species = "human", cutoff = 0.05, anntype = "Reactome") {
  do.call(sess$s$setInputs, list("enrich-species_select" = species, "enrich-anntype_select" = anntype,
    "enrich-keytype_select" = "SYMBOL", "enrich-ont_select" = "BP", "enrich-deg_filter_cutoff" = cutoff,
    "enrich-degs_to_enrich" = labels))
  sess$log$enrich_n <- sess$log$enrich_n + 1L
  do.call(sess$s$setInputs, list("enrich-enrich_deg" = sess$log$enrich_n))
}

ws6_cluster <- function(sess, selected, name, method = "hierarchical", extra = list()) {
  do.call(sess$s$setInputs, c(list("cluster-selected_rrs" = selected, "cluster-cluster_name" = name,
                                   "cluster-clustering_method" = method), extra))
  sess$log$cluster_n <- sess$log$cluster_n + 1L
  do.call(sess$s$setInputs, list("cluster-cluster" = sess$log$cluster_n))
}

ws6_action <- function(sess, action, run, value = NULL) {
  sess$log$nonce <- sess$log$nonce + 1L
  if (is.null(value)) value <- list(action = action, run = run, nonce = sess$log$nonce)
  sess$s$setInputs("jobs-job_action" = value)
}

ws6_until <- function(predicate, sessions = list(), timeout = 20, elapse = 0) {
  deadline <- Sys.time() + timeout
  repeat {
    if (isTRUE(predicate())) return(TRUE)
    if (Sys.time() > deadline) return(FALSE)
    later::run_now(timeoutSecs = 0.02)
    for (x in sessions) if (!x$s$isClosed()) {
      if (elapse > 0) x$s$elapse(elapse) else x$s$flushReact()
    }
  }
}

ws6_settle <- function(sessions = list(), secs = 0.3) {
  ws6_until(function() FALSE, sessions, timeout = secs)
  invisible(NULL)
}

# ---- registry inspection ----------------------------------------------------------

ws6_ids <- function(jobs) vapply(jobs$records, function(r) as.character(r$run_id), character(1))
ws6_rec <- function(jobs, id) {
  i <- match(id, ws6_ids(jobs))
  if (is.na(i)) NULL else jobs$records[[i]]
}
ws6_last <- function(jobs) jobs$records[[length(jobs$records)]]
ws6_state_of <- function(jobs, id) {
  r <- ws6_rec(jobs, id)
  if (is.null(r)) NA_character_ else as.character(r$state)
}
ws6_queue <- function() richStudio:::.workspace_job_queue
ws6_queue_ids <- function() vapply(ws6_queue()$entries, function(e) as.character(e$run_id), character(1))
ws6_id8 <- function(id) substr(id, 1L, 8L)

# Call-through spies on the factory and free-worker seams. Each factory call is
# tagged with the session whose module domain launched it.
ws6_spy <- function(sessions = list(), env = parent.frame()) {
  log <- new.env(parent = emptyenv())
  log$events <- character()
  log$factory <- character()
  log$free <- NULL
  log$fail <- NULL
  real_future <- richStudio:::workspace_jobs_future
  real_free <- richStudio:::workspace_jobs_free_workers
  who <- function() {
    domain <- shiny::getDefaultReactiveDomain()
    root <- if (is.null(domain)) NULL else tryCatch(domain$rootScope(), error = function(e) NULL)
    for (x in sessions) if (identical(root, x$s)) return(x$tag)
    "?"
  }
  testthat::local_mocked_bindings(
    workspace_jobs_free_workers = function(...) {
      n <- if (is.function(log$free)) log$free() else real_free(...)
      log$events <- c(log$events, paste0("free:", n))
      n
    },
    workspace_jobs_future = function(...) {
      tag <- who()
      log$events <- c(log$events, paste0("future:", tag))
      log$factory <- c(log$factory, tag)
      if (is.function(log$fail) && isTRUE(log$fail(tag))) stop("boom")
      # Call through with the caller's own argument expressions, so a seam that
      # captures its expression lazily (as future::future does) still sees it.
      call <- match.call()
      call[[1L]] <- real_future
      eval(call, parent.frame())
    },
    .package = "richStudio", .env = env)
  log
}

ws6_cancel_spy <- function(defer = FALSE, env = parent.frame()) {
  log <- new.env(parent = emptyenv())
  log$n <- 0L
  log$futures <- list()
  real <- richStudio:::workspace_jobs_cancel
  testthat::local_mocked_bindings(workspace_jobs_cancel = function(f, ...) {
    log$n <- log$n + 1L
    log$futures[[length(log$futures) + 1L]] <- f
    if (!defer) real(f, ...) else invisible(NULL)
  }, .package = "richStudio", .env = env)
  log
}

ws6_clock <- function(env = parent.frame()) {
  clock <- new.env(parent = emptyenv())
  clock$t <- as.POSIXct("2026-10-23 10:00:00", tz = "UTC")
  testthat::local_mocked_bindings(workspace_jobs_now = function() clock$t, .package = "richStudio", .env = env)
  clock
}

ws6_alive_switch <- function(value = TRUE, env = parent.frame()) {
  sw <- new.env(parent = emptyenv())
  sw$value <- value
  testthat::local_mocked_bindings(workspace_jobs_pid_alive = function(pid, start, ...) sw$value,
                                  .package = "richStudio", .env = env)
  sw
}

# Every element of an exported record is an atomic vector or a plain list.
ws6_data_only <- function(x) {
  if (is.list(x) && !is.data.frame(x) && is.null(attr(x, "class"))) return(all(vapply(x, ws6_data_only, logical(1))))
  is.null(x) || (is.atomic(x) && is.null(attr(x, "class")))
}

ws6_accepts <- function(x) tryCatch(!isFALSE(richStudio:::workspace_run_record_validate(x)), error = function(e) FALSE)

ws6_save <- function(sess, path, format) {
  sess$s$setInputs("save-session_name" = "ws6", "save-save_format" = format)
  shiny::isolate(shiny::withReactiveDomain(sess$s, sess$log$download(path)))
  withr::defer(unlink(paste0(path, ".lock")), envir = parent.frame())
  invisible(path)
}

ws6_load <- function(sess, path, name = basename(path)) {
  sess$log$load_n <- (if (is.null(sess$log$load_n)) 0L else sess$log$load_n) + 1L
  sess$s$setInputs("save-load_session_file" = list(name = name, datapath = path))
  sess$s$setInputs("save-load_session" = sess$log$load_n)
}

ws6_saved_records <- function(path, format) {
  value <- if (format == "rds") readRDS(path)$run_records_json else
    jsonlite::read_json(path, simplifyVector = TRUE)$run_records_json
  richStudio:::workspace_run_records_parse(value)
}

# ---- R1-R3: registry, admission, capability ----------------------------------------

test_that("R1 REQ-001 REQ-002 registry fields, run ids and data-only exported records", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  s1 <- ws6_session("S1")
  jobs <- ws6_install(s1)
  expect_true(is.environment(jobs))
  for (field in c("session", "owner", "generation", "closed", "revisions", "records", "in_flight",
                  "handles", "tick", "announce")) {
    expect_true(exists(field, envir = jobs, inherits = FALSE), info = field)
  }
  expect_identical(jobs$session, s1$s)
  expect_match(jobs$owner, "^[0-9a-f]{16}$")
  expect_identical(jobs$generation, 1L)
  expect_false(jobs$closed)
  expect_true(is.environment(jobs$revisions))
  expect_true(is.environment(jobs$handles))
  expect_identical(jobs$in_flight, character())
  expect_length(jobs$records, 0L)
  expect_true(inherits(jobs$tick, "reactiveVal"))
  expect_true(inherits(jobs$announce, "reactiveVal"))
  ids <- vapply(seq_len(1000L), function(i) richStudio:::workspace_jobs_new_run_id(jobs), character(1))
  expect_true(all(grepl("^[0-9a-f]{12}$", ids)))
  expect_false(anyDuplicated(ids) > 0L)

  # A queued record from a real Run (no worker is free, so none starts).
  spy <- ws6_spy(list(s1))
  spy$free <- function() 0L
  state <- ws6_add_deg(ws6_state(), "deg_a")
  ws6_mount(s1, state)
  ws6_run(s1, "deg_a")
  expect_length(jobs$records, 1L)
  expect_identical(ws6_last(jobs)$state, "queued")
  expect_length(spy$factory, 0L)
  exported <- richStudio:::workspace_run_record_export(ws6_last(jobs))
  expect_identical(exported$schema, "richstudio.run_record")
  expect_identical(exported$version, 1L)
  expect_true(ws6_data_only(exported))
  expect_false(any(c("pid", "handle", "future", "launch", "session") %in% names(exported)))
  expect_false(any(vapply(unlist(exported, recursive = TRUE, use.names = FALSE),
                          function(v) is.function(v) || is.environment(v), logical(1))))
  canonical <- richStudio:::workspace_run_records(jobs)[[1]]
  expect_true(ws6_accepts(canonical))
  for (bad in list(within(canonical, note <- function() 1), within(canonical, note <- new.env()),
                   within(canonical, version <- 2L))) {
    expect_false(ws6_accepts(bad))
  }
  copy <- richStudio:::workspace_run_records(jobs)
  copy[[1]]$state <- "succeeded"
  expect_identical(ws6_last(jobs)$state, "queued")
  expect_identical(richStudio:::workspace_run_records(jobs)[[1]]$state, "queued")
})

test_that("R2 REQ-001 REQ-002 duplicate clicks, policy refusal and reserved cluster names", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  dir <- withr::local_tempdir()
  kit <- ws6_latch_runner(dir)
  own <- ws6_workers(2L, dir = dir)
  s1 <- ws6_session("S1")
  ws6_close_wiring(s1)
  state <- ws6_add_deg(ws6_state(), "deg_a")
  ws6_mount(s1, state, runner = kit$enrichment)
  # Two identical Run events while the first job is latched.
  ws6_run(s1, "deg_a")
  ws6_pid(dir, ws6_key("deg_a"), list(s1), own = own)
  ws6_run(s1, "deg_a")
  ws6_until(function() ws6_claims(dir, "deg_a") >= 2L, list(s1), timeout = 3)
  ws6_own(own)
  expect_identical(ws6_claims(dir, "deg_a"), 1L)
  expect_identical(ws6_shown(s1, ws6_msg$identical), 1L)
  jobs1 <- s1$s$userData$workspace_jobs
  expect_length(jobs1$records, 1L)

  # Policy loader error: one message, zero factory calls, stores unchanged.
  s2 <- ws6_session("S2")
  jobs2 <- ws6_install(s2, policy_loader = function() stop("policy gone"))
  spy <- ws6_spy(list(s1, s2))
  state2 <- ws6_add_deg(ws6_state(), "deg_b")
  ws6_mount(s2, state2, runner = kit$enrichment)
  before <- ws6_snapshot(state2)
  ws6_run(s2, "deg_b")
  expect_identical(ws6_shown(s2, ws6_msg$policy), 1L)
  expect_length(spy$factory, 0L)
  expect_length(jobs2$records, 0L)
  expect_identical(ws6_snapshot(state2), before)

  # Duplicate cluster names: an existing result, then a queued run's reserved name.
  testthat::local_mocked_bindings(workspace_cluster_compute = kit$cluster, .package = "richStudio")
  s3 <- ws6_session("S3")
  jobs3 <- ws6_install(s3)
  spy3 <- ws6_spy(list(s3))
  state3 <- ws6_add_rr(ws6_add_deg(ws6_state(), "deg_c"), c("rr1", "rr2"))
  shiny::isolate(state3$u_clusnames$labels <- "taken")
  ws6_mount(s3, state3, modules = c("enrich", "cluster"), runner = kit$enrichment)
  ws6_cluster(s3, "rr1", "taken")
  expect_identical(ws6_shown(s3, sprintf(ws6_msg$cluster_name, "taken")), 1L)
  expect_length(spy3$factory, 0L)
  expect_identical(ws6_claims(dir, "taken"), 0L)
  ws6_run(s3, "deg_c")
  ws6_pid(dir, ws6_key("deg_c"), list(s3), own = own)
  # Check 3 (one queued job per session) runs before check 4; allow two queued
  # jobs so that the reserved name, not the queue bound, decides the refusal.
  testthat::local_mocked_bindings(workspace_job_session_queue_limit = function() 2L, .package = "richStudio")
  ws6_cluster(s3, "rr1", "reserved")
  expect_identical(ws6_last(jobs3)$state, "queued")
  ws6_cluster(s3, "rr2", "reserved")
  expect_identical(ws6_shown(s3, sprintf(ws6_msg$cluster_name, "reserved")), 1L)
  expect_identical(spy3$factory, "S3")
  expect_identical(ws6_claims(dir, "reserved"), 0L)
  expect_length(jobs3$records, 2L)
})

test_that("R3 REQ-003 REQ-004 capability follows the installed backend", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  dir <- withr::local_tempdir()
  kit <- ws6_latch_runner(dir)
  # sequential: no worker process, so Stop is unsupported.
  ws6_sequential()
  ws6_release_all(dir)
  s0 <- ws6_session("S0")
  jobs0 <- ws6_install(s0)
  state0 <- ws6_add_deg(ws6_state(), "deg_s")
  ws6_mount(s0, state0, runner = kit$enrichment)
  ws6_run(s0, "deg_s")
  ws6_until(function() identical(ws6_last(jobs0)$state, "succeeded"), list(s0), timeout = 10)
  expect_false(isTRUE(ws6_last(jobs0)$stop_supported))
  unlink(file.path(dir, "release.all"))

  for (variant in list(list(n = 1L, interrupts = TRUE, expected = TRUE),
                       list(n = 2L, interrupts = FALSE, expected = FALSE))) {
    local({
      unlink(file.path(dir, "release.all"))
      own <- ws6_workers(variant$n, interrupts = variant$interrupts, dir = dir)
      s1 <- ws6_session(paste0("S", variant$n))
      jobs <- ws6_install(s1)
      label <- paste0("deg_cap", variant$n)
      state <- ws6_add_deg(ws6_state(), label)
      ws6_mount(s1, state, runner = kit$enrichment)
      ws6_run(s1, label)
      ws6_pid(dir, ws6_key(label), list(s1), own = own)
      expect_identical(ws6_last(jobs)$state, "running")
      expect_identical(isTRUE(ws6_last(jobs)$stop_supported), variant$expected)
      ws6_release(dir, ws6_key(label))
      ws6_until(function() identical(ws6_last(jobs)$state, "succeeded"), list(s1))
    })
  }
})

test_that("R3b REQ-003 REQ-004 a capability-read error gives Detach and the job still publishes", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  dir <- withr::local_tempdir()
  kit <- ws6_latch_runner(dir)
  testthat::local_mocked_bindings(workspace_jobs_capability = function(f, ...) stop("capability read failed"),
                                  .package = "richStudio")
  own <- ws6_workers(1L, dir = dir)
  s1 <- ws6_session("S1")
  jobs <- ws6_install(s1)
  state <- ws6_add_deg(ws6_state(), "deg_a")
  ws6_mount(s1, state, modules = c("enrich", "panel"), runner = kit$enrichment, jobs = jobs)
  ws6_run(s1, "deg_a")
  ws6_pid(dir, ws6_key("deg_a"), list(s1), own = own)
  id <- ws6_last(jobs)$run_id
  expect_identical(ws6_state_of(jobs, id), "running")
  expect_false(isTRUE(ws6_rec(jobs, id)$stop_supported))
  expect_false(s1$s$isClosed())
  expect_true(ws6_has_button(ws6_html(s1, "jobs-jobs_list"), id, ws6_msg$detach))
  ws6_release(dir, ws6_key("deg_a"))
  expect_true(ws6_until(function() identical(ws6_state_of(jobs, id), "succeeded"), list(s1)))
  expect_true("deg_a_enriched" %in% shiny::isolate(names(state$u_rrdfs)))
  expect_true(ws6_until(function() !length(jobs$in_flight), list(s1)))
})

# ---- R4-R7: Stop, late Stop, unconfirmed Stop, Detach -----------------------------

test_that("R4 AC-002 REQ-003 two sessions: Stop ends only the owned worker, acknowledged by PID", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  dir <- withr::local_tempdir()
  kit <- ws6_latch_runner(dir)
  s1 <- ws6_session("S1")
  jobs1 <- ws6_install(s1)
  s2 <- ws6_session("S2")
  jobs2 <- ws6_install(s2)
  own <- ws6_workers(2L, dir = dir)
  state1 <- ws6_add_deg(ws6_state(), "deg_a")
  state2 <- ws6_add_deg(ws6_state(), "deg_b")
  ws6_mount(s1, state1, modules = c("enrich", "panel"), runner = kit$enrichment, jobs = jobs1)
  ws6_mount(s2, state2, modules = c("enrich", "panel"), runner = kit$enrichment, jobs = jobs2)
  ws6_run(s1, "deg_a")
  ws6_run(s2, "deg_b")
  pid1 <- ws6_pid(dir, ws6_key("deg_a"), list(s1, s2), own = own)
  pid2 <- ws6_pid(dir, ws6_key("deg_b"), list(s1, s2), own = own)
  id1 <- ws6_last(jobs1)$run_id
  id2 <- ws6_last(jobs2)$run_id
  expect_identical(as.integer(jobs1$handles[[id1]]$pid), pid1)
  expect_identical(as.integer(jobs2$handles[[id2]]$pid), pid2)
  expect_false(identical(pid1, pid2))
  expect_true(isTRUE(ws6_rec(jobs1, id1)$stop_supported))
  stores1 <- ws6_snapshot(state1)

  ws6_action(s1, "stop", id1)
  ws6_own(own)
  expect_identical(ws6_state_of(jobs1, id1), "cancel_requested")
  premature <- FALSE
  acknowledged <- ws6_until(function() {
    st <- ws6_state_of(jobs1, id1)
    if (identical(st, "cancelled") && ws6_alive(pid1)) premature <<- TRUE
    identical(st, "cancelled")
  }, list(s1, s2), timeout = 10, elapse = 100)
  ws6_own(own)
  expect_true(acknowledged)
  expect_false(premature)
  expect_false(ws6_alive(pid1))
  expect_true(ws6_alive(pid2))
  expect_identical(ws6_state_of(jobs2, id2), "running")

  ws6_release(dir, ws6_key("deg_b"))
  expect_true(ws6_until(function() identical(ws6_state_of(jobs2, id2), "succeeded"), list(s1, s2)))
  expect_true("deg_b_enriched" %in% shiny::isolate(names(state2$u_rrdfs)))
  expect_identical(ws6_snapshot(state1), stores1)

  ws6_run(s1, "deg_a")
  pid3 <- ws6_pid(dir, ws6_key("deg_a", 2L), list(s1, s2), own = own)
  expect_false(is.na(pid3))
  expect_false(identical(pid3, pid1))
  ws6_release(dir, ws6_key("deg_a", 2L))
  expect_true(ws6_until(function() identical(ws6_last(jobs1)$state, "succeeded"), list(s1, s2)))
})

test_that("R5 REQ-003 Stop after the worker finished detaches without a kill", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  dir <- withr::local_tempdir()
  kit <- ws6_latch_runner(dir)
  s1 <- ws6_session("S1")
  jobs <- ws6_install(s1)
  calls <- new.env(parent = emptyenv())
  calls$resolved <- 0L
  real_resolved <- richStudio:::workspace_jobs_resolved
  testthat::local_mocked_bindings(workspace_jobs_resolved = function(f, ...) {
    calls$resolved <- calls$resolved + 1L
    real_resolved(f, ...)
  }, .package = "richStudio")
  cancels <- ws6_cancel_spy()
  own <- ws6_workers(1L, dir = dir)
  state <- ws6_add_deg(ws6_state(), "deg_a")
  ws6_mount(s1, state, modules = c("enrich", "panel"), runner = kit$enrichment, jobs = jobs)
  ws6_release_all(dir)
  ws6_run(s1, "deg_a")
  id <- ws6_last(jobs)$run_id
  # Non-sleeping bounded wait on the done file; later is not pumped.
  deadline <- Sys.time() + 20
  while (!ws6_done(dir, ws6_key("deg_a")) && Sys.time() < deadline) NULL
  settle <- Sys.time() + 0.5
  while (Sys.time() < settle) NULL
  ws6_own(own)
  pid <- as.integer(readLines(file.path(dir, paste0(ws6_key("deg_a"), ".pid")))[1])
  expect_identical(ws6_state_of(jobs, id), "running")
  stores <- ws6_snapshot(state)
  calls$resolved <- 0L
  ws6_action(s1, "stop", id)
  expect_identical(calls$resolved, 1L)
  expect_identical(cancels$n, 0L)
  expect_identical(ws6_state_of(jobs, id), "detached")
  expect_identical(ws6_rec(jobs, id)$note, ws6_msg$late)
  expect_true(ws6_alive(pid))
  ws6_until(function() !length(jobs$in_flight), list(s1))
  ws6_settle(list(s1))
  expect_identical(ws6_snapshot(state), stores)
  expect_identical(ws6_shown(s1, ws6_msg$enrich_ok), 0L)
})

test_that("R6 REQ-003 REQ-004 an unconfirmed Stop detaches, keeps the slot and relabels at finally", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  dir <- withr::local_tempdir()
  kit <- ws6_latch_runner(dir)
  clock <- ws6_clock()
  alive <- ws6_alive_switch(TRUE)
  cancels <- ws6_cancel_spy(defer = TRUE)
  s1 <- ws6_session("S1")
  jobs <- ws6_install(s1, ack_timeout = 0.3)
  state <- ws6_add_deg(ws6_state(), c("deg_a", "deg_b"))
  s1$log$probe <- function() "deg_b_enriched" %in% names(state$u_rrdfs)
  spy <- ws6_spy(list(s1))
  own <- ws6_workers(1L, dir = dir)
  ws6_mount(s1, state, modules = c("enrich", "panel"), runner = kit$enrichment, jobs = jobs)
  ws6_run(s1, "deg_a")
  pid <- ws6_pid(dir, ws6_key("deg_a"), list(s1), own = own)
  id_a <- ws6_last(jobs)$run_id
  ws6_run(s1, "deg_b")
  id_b <- ws6_last(jobs)$run_id
  expect_identical(ws6_state_of(jobs, id_b), "queued")

  ws6_action(s1, "stop", id_a)
  expect_identical(cancels$n, 1L)
  expect_identical(ws6_state_of(jobs, id_a), "cancel_requested")
  clock$t <- clock$t + 0.2
  s1$s$elapse(200)
  expect_identical(ws6_state_of(jobs, id_a), "cancel_requested")
  clock$t <- clock$t + 0.2
  s1$s$elapse(200)
  expect_identical(ws6_state_of(jobs, id_a), "detached")
  expect_match(ws6_rec(jobs, id_a)$note, ws6_msg$unconfirmed, fixed = TRUE)
  expect_match(ws6_rec(jobs, id_a)$note, "may still be running", fixed = TRUE)
  expect_true(id_a %in% jobs$in_flight)
  expect_identical(ws6_state_of(jobs, id_b), "queued")
  expect_identical(spy$factory, "S1")
  ws6_settle(list(s1))
  expect_identical(ws6_state_of(jobs, id_b), "queued")

  # The stop is now real: the worker ends, the mock reports it gone.
  alive$value <- FALSE
  future::cancel(cancels$futures[[1]])
  ws6_own(own)
  ws6_release(dir, ws6_key("deg_a"))
  expect_true(ws6_until(function() identical(ws6_state_of(jobs, id_a), "cancelled"), list(s1)))
  # The relabel reads the class onRejected stored, so onRejected ran before onFinally.
  expect_identical(jobs$handles[[id_a]]$rejection_class, "FutureCanceledError")
  expect_identical(ws6_rec(jobs, id_a)$note, ws6_msg$confirmed_late)
  expect_false(id_a %in% jobs$in_flight)
  expect_true(ws6_until(function() identical(ws6_state_of(jobs, id_b), "running"), list(s1)))
  expect_identical(spy$factory, c("S1", "S1"))
  expect_false(ws6_alive(pid))

  # A fulfilled run publishes before its button is re-enabled.
  ws6_pid(dir, ws6_key("deg_b"), list(s1), own = own)
  enables_before <- ws6_enables(s1, "enrich-enrich_deg")
  ws6_release(dir, ws6_key("deg_b"))
  expect_true(ws6_until(function() identical(ws6_state_of(jobs, id_b), "succeeded"), list(s1)))
  ws6_settle(list(s1))
  enables <- Filter(function(m) identical(m$type, "shinyjs-enable") && identical(m$message$id, "enrich-enrich_deg"),
                    s1$log$custom)
  expect_gt(length(enables), enables_before)
  expect_true(isTRUE(enables[[length(enables)]]$probe))
})

test_that("R7 REQ-004 AC-002 Detach is explicit where Stop is unsupported", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  dir <- withr::local_tempdir()
  kit <- ws6_latch_runner(dir)
  s1 <- ws6_session("S1")
  jobs <- ws6_install(s1)
  spy <- ws6_spy(list(s1))
  own <- ws6_workers(2L, interrupts = FALSE, dir = dir)
  state <- ws6_add_deg(ws6_state(), c("deg_a", "deg_b"))
  ws6_mount(s1, state, modules = c("enrich", "panel"), runner = kit$enrichment, jobs = jobs)
  ws6_run(s1, "deg_a")
  pid <- ws6_pid(dir, ws6_key("deg_a"), list(s1), own = own)
  id_a <- ws6_last(jobs)$run_id
  html <- ws6_html(s1, "jobs-jobs_list")
  expect_true(ws6_has_button(html, id_a, ws6_msg$detach))
  expect_false(ws6_has_button(html, id_a, ">Stop<"))
  ws6_run(s1, "deg_b")
  id_b <- ws6_last(jobs)$run_id
  expect_identical(ws6_state_of(jobs, id_b), "queued")
  stores <- ws6_snapshot(state)
  notes <- length(s1$log$notes)

  ws6_action(s1, "detach", id_a)
  expect_identical(ws6_state_of(jobs, id_a), "detached")
  expect_true(ws6_alive(pid))
  expect_true(id_a %in% jobs$in_flight)
  ws6_settle(list(s1))
  expect_identical(ws6_state_of(jobs, id_b), "queued")
  expect_identical(spy$factory, "S1")

  ws6_release(dir, ws6_key("deg_a"))
  expect_true(ws6_until(function() !(id_a %in% jobs$in_flight), list(s1)))
  expect_true(ws6_until(function() identical(ws6_state_of(jobs, id_b), "running"), list(s1)))
  expect_identical(spy$factory, c("S1", "S1"))
  expect_identical(ws6_state_of(jobs, id_a), "detached")
  after <- ws6_snapshot(state)
  expect_identical(after$rrdfs, stores$rrdfs)
  expect_identical(after$rrnames, stores$rrnames)
  expect_identical(ws6_shown(s1, ws6_msg$enrich_ok, from = notes), 0L)
  ws6_release(dir, ws6_key("deg_b"))
  expect_true(ws6_until(function() identical(ws6_state_of(jobs, id_b), "succeeded"), list(s1)))
})

# ---- R8-R11: stale results after delete, rename, replace, load and close ----------

# R8: the job starts on a module mounted without a registry (app.R wiring absent),
# its input is mutated, the latch is released, and nothing may be published.
ws6_r8_case <- function(label, mutate, modules, reason, env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  kit <- ws6_latch_runner(dir)
  own <- ws6_workers(1L, dir = dir, env = env)
  s1 <- ws6_session("S1", env = env)
  ws6_close_wiring(s1)
  state <- ws6_add_deg(ws6_state(), c(label, "deg_other"))
  ws6_mount(s1, state, modules = modules, runner = kit$enrichment)
  ws6_run(s1, label)
  ws6_pid(dir, ws6_key(label), list(s1), own = own)
  enables <- ws6_enables(s1, "enrich-enrich_deg")
  mutate(s1, state)
  stores <- ws6_snapshot(state)
  notes <- length(s1$log$notes)
  inputs <- length(s1$log$inputs)
  ws6_release(dir, ws6_key(label))
  ws6_until(function() ws6_enables(s1, "enrich-enrich_deg") > enables, list(s1))
  ws6_settle(list(s1))
  list(s1 = s1, state = state, stores = stores, notes = notes, inputs = inputs, label = label, reason = reason)
}

ws6_r8_expect_inert <- function(case) {
  after <- ws6_snapshot(case$state)
  expect_identical(after$rrdfs, case$stores$rrdfs)
  expect_identical(after$rrnames, case$stores$rrnames)
  expect_identical(after$big_rr, case$stores$big_rr)
  expect_identical(ws6_shown(case$s1, ws6_msg$enrich_ok, from = case$notes), 0L)
  new_inputs <- case$s1$log$inputs[seq_along(case$s1$log$inputs) > case$inputs]
  expect_false(any(vapply(new_inputs, function(m) identical(m$id, "enrich-rr_table_select") &&
                            any(grepl(paste0(case$label, "_enriched"), unlist(m$message), fixed = TRUE)), logical(1))))
  jobs <- case$s1$s$userData$workspace_jobs
  expect_false(is.null(jobs))
  expect_identical(ws6_last(jobs)$state, "superseded")
  expect_match(ws6_last(jobs)$note, case$reason, fixed = TRUE)
}

test_that("R8a AC-001 REQ-002 Manage Files confirm_remove_deg while running publishes nothing", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  case <- ws6_r8_case("deg_a", function(s1, state) {
    s1$s$setInputs("update-remove_deg_select" = "deg_a")
    s1$s$setInputs("update-confirm_remove_deg" = 1L)
  }, c("enrich", "update"), "input deg_a changed")
  ws6_r8_expect_inert(case)
})

test_that("R8b AC-001 REQ-002 enrichment remove_deg while running publishes nothing", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  case <- ws6_r8_case("deg_a", function(s1, state) {
    s1$s$setInputs("enrich-deg_list_table_rows_selected" = 1L)
    s1$s$setInputs("enrich-remove_deg" = 1L)
  }, "enrich", "input deg_a changed")
  ws6_r8_expect_inert(case)
})

test_that("R8c AC-001 REQ-002 Manage Files rename while running publishes nothing", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  case <- ws6_r8_case("deg_a", function(s1, state) {
    s1$s$setInputs("update-rename_deg_select" = "deg_a", "update-new_deg_name" = "deg_renamed")
    s1$s$setInputs("update-rename_deg_btn" = 1L)
  }, c("enrich", "update"), "input deg_a changed")
  ws6_r8_expect_inert(case)
})

test_that("R8d AC-001 REQ-002 deg_load replacing a running input publishes nothing", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  case <- ws6_r8_case("deg_mouse1", function(s1, state) {
    s1$s$setInputs("enrich-deg_load" = 1L)
  }, "enrich", "input deg_mouse1 changed")
  ws6_r8_expect_inert(case)
})

test_that("R8e AC-001 REQ-002 a clustering input removed outside the lock publishes no cluster", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  # The real clustering computation runs; its callback can only run when the test
  # pumps later, which happens after the removal.
  own <- ws6_workers(1L)
  s1 <- ws6_session("S1")
  ws6_close_wiring(s1)
  state <- ws6_add_rr(ws6_state(), "fx_rr")
  prior <- list(DistanceMatrix = matrix(2), cluster_df = data.frame(Term = "prior"),
                cluster_summary = data.frame(Term = "prior"), method = "richR", params = list(cutoff = 0.5))
  shiny::isolate(for (key in names(prior)) state$clus_intermed[[key]] <- prior[[key]])
  ws6_mount(s1, state, modules = c("cluster", "upload"))
  enables <- ws6_enables(s1, "cluster-cluster")
  ws6_cluster(s1, "fx_rr", "k_fx")
  ws6_own(own)
  s1$s$setInputs("cluster_upload-rr_list_table_rows_selected" = 1L)
  s1$s$setInputs("cluster_upload-remove_rr" = 1L)
  expect_false("fx_rr" %in% shiny::isolate(state$u_rrnames$labels))
  notes <- length(s1$log$notes)
  ws6_until(function() ws6_enables(s1, "cluster-cluster") > enables, list(s1), timeout = 60)
  ws6_settle(list(s1))
  after <- ws6_snapshot(state)
  expect_null(after$clusnames)
  expect_length(after$clusdfs, 0L)
  expect_length(after$cluslists, 0L)
  expect_null(after$big_clus)
  expect_identical(ws6_shown(s1, ws6_msg$cluster_ok, from = notes), 0L)
  expect_identical(after$intermed[names(prior)], prior)
  jobs <- s1$s$userData$workspace_jobs
  expect_false(is.null(jobs))
  expect_identical(ws6_last(jobs)$state, "superseded")
  expect_match(ws6_last(jobs)$note, "input fx_rr changed", fixed = TRUE)
})

test_that("R8f AC-001 positive control: removing an unrelated label leaves the job published", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  case <- ws6_r8_case("deg_a", function(s1, state) {
    s1$s$setInputs("update-remove_deg_select" = "deg_other")
    s1$s$setInputs("update-confirm_remove_deg" = 1L)
  }, c("enrich", "update"), "")
  after <- ws6_snapshot(case$state)
  expect_true("deg_a_enriched" %in% names(after$rrdfs))
  expect_true("deg_a_enriched" %in% after$rrnames)
  expect_identical(ws6_shown(case$s1, ws6_msg$enrich_ok, from = case$notes), 1L)
  jobs <- case$s1$s$userData$workspace_jobs
  expect_false(is.null(jobs))
  expect_identical(ws6_last(jobs)$state, "succeeded")
})

test_that("R9 AC-001 REQ-002 rejected requests leave the running job valid", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  dir <- withr::local_tempdir()
  kit <- ws6_latch_runner(dir)
  own <- ws6_workers(1L, dir = dir)
  s1 <- ws6_session("S1")
  ws6_close_wiring(s1)
  state <- ws6_add_deg(ws6_state(), c("deg_a", "deg_other"))
  ws6_mount(s1, state, modules = c("enrich", "update"), runner = kit$enrichment)
  ws6_run(s1, "deg_a")
  ws6_pid(dir, ws6_key("deg_a"), list(s1), own = own)
  # A rename onto an existing name, a remove without confirmation, a duplicate upload.
  s1$s$setInputs("update-rename_deg_select" = "deg_a", "update-new_deg_name" = "deg_other")
  s1$s$setInputs("update-rename_deg_btn" = 1L)
  s1$s$setInputs("update-remove_deg_select" = "deg_a")
  s1$s$setInputs("update-remove_deg_btn" = 1L)
  upload <- withr::local_tempfile(fileext = ".csv")
  utils::write.csv(ws6_deg_df(), upload, row.names = FALSE)
  s1$s$setInputs("enrich-deg_files" = data.frame(name = "deg_a", datapath = upload))
  expect_identical(ws6_shown(s1, "A gene list named deg_a already exists"), 1L)
  ws6_release(dir, ws6_key("deg_a"))
  expect_true(ws6_until(function() "deg_a_enriched" %in% shiny::isolate(names(state$u_rrdfs)), list(s1)))
  expect_true("deg_a_enriched" %in% shiny::isolate(state$u_rrnames$labels))
  jobs <- s1$s$userData$workspace_jobs
  expect_false(is.null(jobs))
  expect_identical(jobs$generation, 1L)
  revisions <- unlist(mget(ls(jobs$revisions, all.names = TRUE), envir = jobs$revisions))
  expect_true(all(revisions == 0))
  expect_identical(ws6_last(jobs)$state, "succeeded")
})

test_that("R10 AC-001 REQ-002 a session load during a run publishes nothing into the loaded workspace", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  dir <- withr::local_tempdir()
  kit <- ws6_latch_runner(dir)
  own <- ws6_workers(1L, dir = dir)
  payload <- ws_baseline_session()
  valid <- withr::local_tempfile(fileext = ".rds")
  saveRDS(payload, valid)
  s1 <- ws6_session("S1")
  ws6_close_wiring(s1)
  state <- ws6_add_deg(ws6_state(), "deg_a")
  ws6_mount(s1, state, modules = c("enrich", "save"), runner = kit$enrichment)
  ws6_run(s1, "deg_a")
  ws6_pid(dir, ws6_key("deg_a"), list(s1), own = own)
  enables <- ws6_enables(s1, "enrich-enrich_deg")
  ws6_load(s1, valid, "valid.rds")
  expect_identical(shiny::isolate(state$u_rrnames$labels), payload$rrnames)
  notes <- length(s1$log$notes)
  ws6_release(dir, ws6_key("deg_a"))
  ws6_until(function() ws6_enables(s1, "enrich-enrich_deg") > enables, list(s1))
  ws6_settle(list(s1))
  expect_identical(shiny::isolate(state$u_rrnames$labels), payload$rrnames)
  expect_false("deg_a_enriched" %in% shiny::isolate(names(state$u_rrdfs)))
  expect_identical(ws6_shown(s1, ws6_msg$enrich_ok, from = notes), 0L)
  jobs <- s1$s$userData$workspace_jobs
  expect_false(is.null(jobs))
  expect_identical(ws6_last(jobs)$state, "superseded")
  expect_match(ws6_last(jobs)$note, "workspace replaced", fixed = TRUE)
  expect_identical(jobs$generation, 2L)

  # A file rejected at save_tab.R:274-277 (no version) leaves the job valid.
  invalid <- withr::local_tempfile(fileext = ".rds")
  saveRDS(list(degnames = "x"), invalid)
  s2 <- ws6_session("S2")
  ws6_close_wiring(s2)
  state2 <- ws6_add_deg(ws6_state(), "deg_b")
  ws6_mount(s2, state2, modules = c("enrich", "save"), runner = kit$enrichment)
  ws6_run(s2, "deg_b")
  ws6_pid(dir, ws6_key("deg_b"), list(s2), own = own)
  ws6_load(s2, invalid, "invalid.rds")
  expect_identical(ws6_shown(s2, "Invalid session file format"), 1L)
  ws6_release(dir, ws6_key("deg_b"))
  expect_true(ws6_until(function() "deg_b_enriched" %in% shiny::isolate(names(state2$u_rrdfs)), list(s2)))
  jobs2 <- s2$s$userData$workspace_jobs
  expect_identical(jobs2$generation, 1L)
  expect_identical(ws6_last(jobs2)$state, "succeeded")

  # A save without an installed registry writes exactly today's fields.
  s3 <- ws6_session("S3")
  state3 <- ws6_add_deg(ws6_state(), "deg_c")
  ws6_mount(s3, state3, modules = "save")
  for (format in c("rds", "json")) {
    saved <- withr::local_tempfile(fileext = paste0(".", format))
    ws6_save(s3, saved, format)
    fields <- if (format == "rds") names(readRDS(saved)) else names(jsonlite::read_json(saved))
    expect_identical(fields, c("version", "created", "degnames", "degdfs", "rrnames", "rrdfs",
                               "clusnames", "clusdfs", "cluslists"))
  }
  expect_null(s3$s$userData$workspace_jobs)
})

test_that("R11 REQ-002 AC-001 AC-002 closing a session leaves its callback inert and the sibling running", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  dir <- withr::local_tempdir()
  kit <- ws6_latch_runner(dir)
  own <- ws6_workers(2L, dir = dir)
  s1 <- ws6_session("S1")
  ws6_close_wiring(s1)
  s2 <- ws6_session("S2")
  ws6_close_wiring(s2)
  state1 <- ws6_add_deg(ws6_state(), "deg_a")
  state2 <- ws6_add_deg(ws6_state(), "deg_b")
  ws6_mount(s1, state1, runner = kit$enrichment)
  ws6_mount(s2, state2, runner = kit$enrichment)
  ws6_run(s1, "deg_a")
  ws6_run(s2, "deg_b")
  pid1 <- ws6_pid(dir, ws6_key("deg_a"), list(s1, s2), own = own)
  pid2 <- ws6_pid(dir, ws6_key("deg_b"), list(s1, s2), own = own)
  stores1 <- ws6_snapshot(state1)
  notes1 <- length(s1$log$notes)
  s1$s$close()
  ws6_own(own)
  ws6_settle(list(s2), secs = 1)
  ws6_release(dir, ws6_key("deg_a"))
  ws6_until(function() ws6_done(dir, ws6_key("deg_a")) || !ws6_alive(pid1), list(s2), timeout = 10)
  ws6_settle(list(s2), secs = 1)
  expect_identical(ws6_snapshot(state1), stores1)
  expect_identical(ws6_shown(s1, ws6_msg$enrich_ok, from = notes1), 0L)
  expect_false(ws6_alive(pid1))
  expect_false(ws6_done(dir, ws6_key("deg_a")))
  jobs1 <- s1$s$userData$workspace_jobs
  expect_false(is.null(jobs1))
  expect_true(jobs1$closed)
  expect_identical(jobs1$in_flight, character())
  expect_true(ws6_alive(pid2))
  ws6_release(dir, ws6_key("deg_b"))
  expect_true(ws6_until(function() "deg_b_enriched" %in% shiny::isolate(names(state2$u_rrdfs)), list(s2)))
  expect_identical(ws6_shown(s2, ws6_msg$enrich_ok), 1L)
})

# ---- R12-R14: out-of-order completion, failure, Retry, clustering -----------------

test_that("R12 REQ-002 a stopped run's late callbacks leave its Retry running and publishing", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  dir <- withr::local_tempdir()
  kit <- ws6_latch_runner(dir)
  alive <- ws6_alive_switch(FALSE)
  cancels <- ws6_cancel_spy(defer = TRUE)
  s1 <- ws6_session("S1")
  jobs <- ws6_install(s1)
  spy <- ws6_spy(list(s1))
  own <- ws6_workers(1L, dir = dir)
  state <- ws6_add_deg(ws6_state(), "deg_a")
  ws6_mount(s1, state, modules = c("enrich", "panel"), runner = kit$enrichment, jobs = jobs)
  ws6_run(s1, "deg_a")
  ws6_pid(dir, ws6_key("deg_a"), list(s1), own = own)
  id_a <- ws6_last(jobs)$run_id
  ws6_action(s1, "stop", id_a)
  expect_true(ws6_until(function() identical(ws6_state_of(jobs, id_a), "cancelled"), list(s1),
                        timeout = 5, elapse = 100))
  expect_true(id_a %in% jobs$in_flight)
  ws6_action(s1, "retry", id_a)
  id_b <- ws6_last(jobs)$run_id
  expect_false(identical(id_b, id_a))
  expect_identical(ws6_rec(jobs, id_b)$retry_of, id_a)
  expect_identical(ws6_state_of(jobs, id_b), "queued")
  # A's worker now really ends; its rejection and finally dispatch B.
  future::cancel(cancels$futures[[1]])
  ws6_own(own)
  expect_true(ws6_until(function() identical(ws6_state_of(jobs, id_b), "running"), list(s1)))
  expect_identical(spy$factory, c("S1", "S1"))
  expect_identical(ws6_state_of(jobs, id_a), "cancelled")
  expect_true(paste0("job-", id_b) %in% ws6_note_ids(s1, "show"))
  expect_false(paste0("job-", id_b) %in% ws6_note_ids(s1, "remove"))
  ws6_pid(dir, ws6_key("deg_a", 2L), list(s1), own = own)
  ws6_release(dir, ws6_key("deg_a", 2L))
  expect_true(ws6_until(function() identical(ws6_state_of(jobs, id_b), "succeeded"), list(s1)))
  expect_true("deg_a_enriched" %in% shiny::isolate(names(state$u_rrdfs)))
  expect_identical(ws6_state_of(jobs, id_a), "cancelled")
})

test_that("R13a AC-004 REQ-005 a failure keeps the predecessor and a rerun never overwrites it", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  dir <- withr::local_tempdir()
  kit <- ws6_latch_runner(dir)
  ws6_release_all(dir)
  own <- ws6_workers(1L, dir = dir)
  s1 <- ws6_session("S1")
  ws6_close_wiring(s1)
  state <- ws6_add_deg(ws6_state(), "x")
  predecessor <- data.frame(Term = "predecessor", GeneID = "p1,p2")
  shiny::isolate({
    state$u_rrdfs$x_enriched <- predecessor
    state$u_rrnames$labels <- "x_enriched"
    state$u_big_rrdf$df <- richStudio::add_file_rrdf(NULL, "x", file = FALSE)
  })
  ws6_mount(s1, state, runner = kit$enrichment)
  writeLines("engine failed", file.path(dir, "fail.txt"))
  enables <- ws6_enables(s1, "enrich-enrich_deg")
  ws6_run(s1, "x")
  ws6_until(function() ws6_enables(s1, "enrich-enrich_deg") > enables, list(s1))
  ws6_own(own)
  expect_identical(shiny::isolate(state$u_rrdfs$x_enriched), predecessor)
  unlink(file.path(dir, "fail.txt"))
  enables <- ws6_enables(s1, "enrich-enrich_deg")
  ws6_run(s1, "x")
  ws6_until(function() ws6_enables(s1, "enrich-enrich_deg") > enables, list(s1))
  ws6_settle(list(s1))
  expect_identical(shiny::isolate(state$u_rrdfs$x_enriched), predecessor)
  expect_true("x_enriched_2" %in% shiny::isolate(names(state$u_rrdfs)))
  expect_identical(shiny::isolate(state$u_rrnames$labels), c("x_enriched", "x_enriched_2"))
})

test_that("R13b AC-004 REQ-005 escaped error summary, then Retry with the captured settings", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  dir <- withr::local_tempdir()
  kit <- ws6_latch_runner(dir)
  s1 <- ws6_session("S1")
  jobs <- ws6_install(s1)
  ws6_release_all(dir)
  own <- ws6_workers(1L, dir = dir)
  state <- ws6_add_deg(ws6_state(), "x")
  predecessor <- data.frame(Term = "predecessor", GeneID = "p1,p2")
  shiny::isolate({
    state$u_rrdfs$x_enriched <- predecessor
    state$u_rrnames$labels <- "x_enriched"
    state$u_big_rrdf$df <- richStudio::add_file_rrdf(NULL, "x", file = FALSE)
  })
  ws6_mount(s1, state, modules = c("enrich", "panel"), runner = kit$enrichment, jobs = jobs)
  writeLines("<script>x</script> at /home/u/secret/file.R token=abc123", file.path(dir, "fail.txt"))
  ws6_run(s1, "x", species = "human")
  id <- ws6_last(jobs)$run_id
  expect_true(ws6_until(function() identical(ws6_state_of(jobs, id), "failed"), list(s1)))
  ws6_own(own)
  expect_identical(shiny::isolate(state$u_rrdfs$x_enriched), predecessor)
  summary <- ws6_rec(jobs, id)$error_summary
  expect_match(summary, "<path>", fixed = TRUE)
  expect_match(summary, "token=<redacted>", fixed = TRUE)
  expect_false(grepl("/home/u", summary, fixed = TRUE))
  expect_false(grepl("abc123", summary, fixed = TRUE))
  expect_identical(ws6_shown(s1, sprintf("Enrichment failed (run %s)", ws6_id8(id))), 1L)
  expect_identical(ws6_shown(s1, "Previous results are unchanged; use Retry in the job panel."), 1L)
  panel <- paste(ws6_html(s1, "jobs-jobs_list"), ws6_html(s1, "jobs-jobs_status"))
  for (token in c("&lt;script&gt;", "&lt;path&gt;", "token=&lt;redacted&gt;")) expect_match(panel, token, fixed = TRUE)
  expect_false(grepl("<script>", panel, fixed = TRUE))
  expect_true(ws6_has_button(ws6_html(s1, "jobs-jobs_list"), id, "Retry"))

  unlink(file.path(dir, "fail.txt"))
  s1$s$setInputs("enrich-species_select" = "mouse")
  ws6_action(s1, "retry", id)
  retry <- ws6_last(jobs)
  expect_false(identical(retry$run_id, id))
  expect_identical(retry$retry_of, id)
  expect_true(ws6_until(function() identical(ws6_state_of(jobs, retry$run_id), "succeeded"), list(s1)))
  expect_identical(ws6_call(dir, ws6_key("x", 2L))$species, "human")
  expect_identical(shiny::isolate(state$u_rrdfs$x_enriched), predecessor)
  expect_true("x_enriched_2" %in% shiny::isolate(names(state$u_rrdfs)))
  expect_identical(ws6_rec(jobs, retry$run_id)$outputs, "x_enriched_2")
  expect_identical(ws6_state_of(jobs, id), "failed")
})

test_that("R13c AC-004 REQ-005 a partial batch publishes nothing and fails the record", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  dir <- withr::local_tempdir()
  kit <- ws6_latch_runner(dir)
  s1 <- ws6_session("S1")
  jobs <- ws6_install(s1)
  ws6_release_all(dir)
  own <- ws6_workers(1L, dir = dir)
  state <- ws6_add_deg(ws6_state(), c("first", "second"))
  ws6_mount(s1, state, runner = kit$enrichment)
  writeLines("second", file.path(dir, "fail_on.txt"))
  before <- ws6_snapshot(state)
  ws6_run(s1, c("first", "second"))
  id <- ws6_last(jobs)$run_id
  expect_true(ws6_until(function() identical(ws6_state_of(jobs, id), "failed"), list(s1)))
  ws6_own(own)
  ws6_settle(list(s1))
  expect_identical(ws6_snapshot(state), before)
})

test_that("R13d AC-004 REQ-005 Retry after an input was removed is refused and hidden", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  dir <- withr::local_tempdir()
  kit <- ws6_latch_runner(dir)
  s1 <- ws6_session("S1")
  jobs <- ws6_install(s1)
  spy <- ws6_spy(list(s1))
  ws6_release_all(dir)
  own <- ws6_workers(1L, dir = dir)
  state <- ws6_add_deg(ws6_state(), "z")
  ws6_mount(s1, state, modules = c("enrich", "panel"), runner = kit$enrichment, jobs = jobs)
  writeLines("engine failed", file.path(dir, "fail.txt"))
  ws6_run(s1, "z")
  id <- ws6_last(jobs)$run_id
  expect_true(ws6_until(function() identical(ws6_state_of(jobs, id), "failed"), list(s1)))
  ws6_own(own)
  unlink(file.path(dir, "fail.txt"))
  s1$s$setInputs("enrich-deg_list_table_rows_selected" = 1L)
  s1$s$setInputs("enrich-remove_deg" = 1L)
  calls <- length(spy$factory)
  ws6_action(s1, "retry", id)
  expect_identical(ws6_shown(s1, ws6_msg$retry_changed), 1L)
  expect_identical(length(spy$factory), calls)
  expect_length(jobs$records, 1L)
  expect_false(ws6_has_button(ws6_html(s1, "jobs-jobs_list"), id, "Retry"))
})

test_that("R13e REQ-005 a superseded record offers no Retry", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  s1 <- ws6_session("S1")
  jobs <- ws6_install(s1)
  spy <- ws6_spy(list(s1))
  spy$free <- function() 0L
  state <- ws6_add_deg(ws6_state(), "z")
  ws6_mount(s1, state, modules = c("enrich", "update", "panel"), jobs = jobs)
  ws6_run(s1, "z")
  id <- ws6_last(jobs)$run_id
  expect_identical(ws6_state_of(jobs, id), "queued")
  s1$s$setInputs("update-remove_deg_select" = "z")
  s1$s$setInputs("update-confirm_remove_deg" = 1L)
  expect_identical(ws6_state_of(jobs, id), "superseded")
  html <- ws6_html(s1, "jobs-jobs_list")
  expect_false(ws6_has_button(html, id, "Retry"))
  expect_identical(ws6_buttons_for(html, id), 0L)
  expect_length(spy$factory, 0L)
})

test_that("R14a REQ-005 a failed clustering run keeps the predecessor's intermediate results", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  ws6_sequential()
  s1 <- ws6_session("S1")
  ws6_close_wiring(s1)
  state <- ws6_add_rr(ws6_state(), "bad_rr", data.frame(Name = "not a result"))
  prior <- list(DistanceMatrix = matrix(2), cluster_df = data.frame(Term = "prior"),
                cluster_summary = data.frame(Term = "prior"), method = "richR", params = list(cutoff = 0.5))
  shiny::isolate({
    for (key in names(prior)) state$clus_intermed[[key]] <- prior[[key]]
    state$u_clusdfs$prior <- data.frame(Cluster = 1L, Representative_Term = "prior")
    state$u_clusnames$labels <- "prior"
  })
  ws6_mount(s1, state, modules = "cluster")
  enables <- ws6_enables(s1, "cluster-cluster")
  ws6_cluster(s1, "bad_rr", "k_bad")
  expect_identical(shiny::isolate(shiny::reactiveValuesToList(state$clus_intermed))[names(prior)], prior)
  ws6_until(function() ws6_enables(s1, "cluster-cluster") > enables, list(s1))
  ws6_settle(list(s1))
  after <- ws6_snapshot(state)
  expect_identical(after$intermed[names(prior)], prior)
  expect_identical(after$clusdfs, list(prior = data.frame(Cluster = 1L, Representative_Term = "prior")))
  expect_identical(after$clusnames, "prior")
  jobs <- s1$s$userData$workspace_jobs
  expect_false(is.null(jobs))
  expect_identical(ws6_last(jobs)$state, "failed")
})

test_that("R14b REQ-005 characterization: a valid-empty clustering run clears stale intermediates", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  ws6_sequential()
  withr::local_seed(42)
  s1 <- ws6_session("S1")
  ws6_close_wiring(s1)
  state <- ws6_add_rr(ws6_state(), "fixture", ws_baseline_inputs()$imported)
  shiny::isolate({
    state$clus_intermed$DistanceMatrix <- matrix(1)
    state$clus_intermed$cluster_df <- data.frame(Term = "stale")
    state$clus_intermed$cluster_summary <- data.frame(Term = "stale")
    state$clus_intermed$method <- "hierarchical"
    state$clus_intermed$params <- list(min_value = 1)
  })
  ws6_mount(s1, state, modules = "cluster")
  enables <- ws6_enables(s1, "cluster-cluster")
  ws6_cluster(s1, "fixture", "empty", extra = list("cluster-hier_min_value" = 1e-8))
  ws6_until(function() ws6_enables(s1, "cluster-cluster") > enables, list(s1))
  ws6_settle(list(s1))
  after <- ws6_snapshot(state)
  expect_null(after$clusnames)
  expect_length(after$clusdfs, 0L)
  expect_null(after$big_clus)
  for (key in c("DistanceMatrix", "cluster_summary", "cluster_df", "method", "params")) {
    expect_null(after$intermed[[key]])
  }
})

# ---- R15-R18: history, panel, job_action, app wiring --------------------------------

test_that("R15 REQ-001 the history bound drops only evictable terminal records", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  dir <- withr::local_tempdir()
  kit <- ws6_latch_runner(dir)
  limit <- richStudio:::workspace_resource_policy()$limits$history_runs
  s1 <- ws6_session("S1")
  jobs <- ws6_install(s1)
  ws6_release_all(dir)
  own <- ws6_workers(1L, interrupts = FALSE, dir = dir)
  state <- ws6_add_deg(ws6_state(), c("x", "held", "next"))
  ws6_mount(s1, state, modules = c("enrich", "panel"), runner = kit$enrichment, jobs = jobs)
  first <- NULL
  for (i in seq_len(limit + 1L)) {
    ws6_run(s1, "x")
    id <- ws6_last(jobs)$run_id
    if (i == 1L) first <- id
    if (i == 2L) second <- id
    expect_true(ws6_until(function() identical(ws6_state_of(jobs, id), "succeeded"), list(s1)), info = i)
  }
  ws6_own(own)
  expect_length(jobs$records, limit)
  expect_false(first %in% ws6_ids(jobs))
  expect_true(second %in% ws6_ids(jobs))
  published <- c("x_enriched", paste0("x_enriched_", 2:(limit + 1L)))
  expect_true(all(published %in% shiny::isolate(names(state$u_rrdfs))))

  # A detached run whose future is unsettled, and a queued record, are kept.
  unlink(file.path(dir, "release.all"))
  ws6_run(s1, "held")
  ws6_pid(dir, ws6_key("held"), list(s1), own = own)
  held <- ws6_last(jobs)$run_id
  ws6_action(s1, "detach", held)
  expect_identical(ws6_state_of(jobs, held), "detached")
  ws6_run(s1, "next")
  queued <- ws6_last(jobs)$run_id
  expect_identical(ws6_state_of(jobs, queued), "queued")
  ws6_settle(list(s1))
  expect_true(held %in% ws6_ids(jobs))
  expect_true(queued %in% ws6_ids(jobs))
  evictable <- vapply(jobs$records, function(r) {
    r$state %in% c("succeeded", "failed", "cancelled", "detached", "superseded", "interrupted") &&
      !(r$run_id %in% jobs$in_flight) && !(r$run_id %in% ws6_queue_ids())
  }, logical(1))
  expect_lte(sum(evictable), limit)
  expect_true(all(published %in% shiny::isolate(names(state$u_rrdfs))))
  ws6_release_all(dir)
  ws6_until(function() !length(jobs$in_flight) && identical(ws6_state_of(jobs, queued), "succeeded"), list(s1))
})

test_that("R16 AC-003 REQ-001 the panel shows identity, settings, elapsed time and no invented progress", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  dir <- withr::local_tempdir()
  kit <- ws6_latch_runner(dir)
  clock <- ws6_clock()
  alive <- ws6_alive_switch(TRUE)
  cancels <- ws6_cancel_spy(defer = TRUE)
  hostile <- "<img src=x onerror=alert(1)>"
  s1 <- ws6_session("S1")
  jobs <- ws6_install(s1, ack_timeout = 0.3)
  own <- ws6_workers(1L, dir = dir)
  state <- ws6_add_deg(ws6_state(), c("deg_a", hostile))
  ws6_mount(s1, state, runner = kit$enrichment)
  shiny::testServer(richStudio:::workspace_jobs_server, args = list(id = "jobs", jobs = jobs), session = s1$s, {
    ws6_run(s1, "deg_a", species = "human")
    ws6_pid(dir, ws6_key("deg_a"), list(s1), own = own)
    id_a <- ws6_last(jobs)$run_id
    session$flushReact()
    list_html <- ws6_html(s1, "jobs-jobs_list")
    text <- paste(list_html, ws6_html(s1, "jobs-jobs_status"))
    for (needle in c(ws6_id8(id_a), "deg_a", "species: human", ws6_msg$progress)) expect_match(text, needle, fixed = TRUE)
    expect_false(grepl("%", text, fixed = TRUE))
    expect_false(grepl("stage", text, ignore.case = TRUE))
    announce <- ws6_html(s1, "jobs-jobs_announce")
    expect_identical(lengths(regmatches(announce, gregexpr("<p[ >]", announce))), 1L)
    expect_match(announce, ws6_id8(id_a), fixed = TRUE)

    ws6_run(s1, hostile)
    id_b <- ws6_last(jobs)$run_id
    session$flushReact()
    announce <- ws6_html(s1, "jobs-jobs_announce")
    expect_identical(lengths(regmatches(announce, gregexpr("<p[ >]", announce))), 1L)
    expect_match(announce, ws6_id8(id_b), fixed = TRUE)
    expect_false(grepl(ws6_id8(id_a), announce, fixed = TRUE))
    status <- ws6_html(s1, "jobs-jobs_status")
    expect_match(status, ws6_msg$waiting, fixed = TRUE)
    for (word in c("ETA", "remaining", "%")) expect_false(grepl(word, status, fixed = TRUE))
    list_html <- ws6_html(s1, "jobs-jobs_list")
    expect_match(list_html, "&lt;img", fixed = TRUE)
    expect_false(grepl("<img", list_html, fixed = TRUE))

    time_before <- ws6_html(s1, "jobs-jobs_time")
    clock$t <- clock$t + 2
    s1$s$elapse(2000)
    expect_false(identical(ws6_html(s1, "jobs-jobs_time"), time_before))
    expect_identical(ws6_html(s1, "jobs-jobs_list"), list_html)

    # Remove the queued run, then let A's Stop time out: the timer still runs.
    ws6_action(s1, "stop", id_b)
    expect_identical(ws6_state_of(jobs, id_b), "cancelled")
    ws6_action(s1, "stop", id_a)
    clock$t <- clock$t + 0.4
    s1$s$elapse(200)
    expect_identical(ws6_state_of(jobs, id_a), "detached")
    expect_true(id_a %in% jobs$in_flight)
    time_before <- ws6_html(s1, "jobs-jobs_time")
    clock$t <- clock$t + 2
    s1$s$elapse(2000)
    expect_false(identical(ws6_html(s1, "jobs-jobs_time"), time_before))
    alive$value <- FALSE
    future::cancel(cancels$futures[[1]])
    ws6_own(own)
    ws6_release(dir, ws6_key("deg_a"))
    ws6_until(function() !length(jobs$in_flight), list(s1))
  })
})

test_that("R17 REQ-003 job_action accepts only this session's valid run ids and actions", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  dir <- withr::local_tempdir()
  kit <- ws6_latch_runner(dir)
  s1 <- ws6_session("S1")
  jobs1 <- ws6_install(s1)
  s2 <- ws6_session("S2")
  jobs2 <- ws6_install(s2)
  cancels <- ws6_cancel_spy()
  own <- ws6_workers(2L, dir = dir)
  state1 <- ws6_add_deg(ws6_state(), "deg_a")
  state2 <- ws6_add_deg(ws6_state(), "deg_b")
  ws6_mount(s1, state1, modules = c("enrich", "panel"), runner = kit$enrichment, jobs = jobs1)
  ws6_mount(s2, state2, modules = c("enrich", "panel"), runner = kit$enrichment, jobs = jobs2)
  ws6_run(s1, "deg_a")
  ws6_run(s2, "deg_b")
  ws6_pid(dir, ws6_key("deg_a"), list(s1, s2), own = own)
  ws6_pid(dir, ws6_key("deg_b"), list(s1, s2), own = own)
  id1 <- ws6_last(jobs1)$run_id
  id2 <- ws6_last(jobs2)$run_id
  bad <- list(
    list(action = "stop", run = "0123456789ab", nonce = 1L),
    list(action = "stop", run = id2, nonce = 2L),
    list(action = "stop", run = 1L, nonce = 3L),
    list(run = id1, nonce = 4L),
    list(action = "kill", run = id1, nonce = 5L))
  for (value in bad) ws6_action(s1, NULL, NULL, value = value)
  expect_identical(ws6_shown(s1, ws6_msg$unknown), length(bad))
  expect_identical(cancels$n, 0L)
  expect_identical(ws6_state_of(jobs1, id1), "running")
  expect_identical(ws6_state_of(jobs2, id2), "running")
  expect_identical(ws6_shown(s2, ws6_msg$unknown), 0L)
  ws6_release_all(dir)
  ws6_until(function() !length(jobs1$in_flight) && !length(jobs2$in_flight), list(s1, s2))
})

test_that("R18 REQ-001 D2 the installed app installs the registry, panel and close hook", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  path <- system.file("application", "app.R", package = "richStudio")
  expect_true(nzchar(path))
  text <- paste(readLines(path, warn = FALSE), collapse = "\n")
  at <- function(pattern, fixed = TRUE) as.integer(regexpr(pattern, text, fixed = fixed))
  module_calls <- c("workspace_navigation_server(", "enrichTabServer(", "rrVisTabServer(",
                    "clusterUploadTabServer(", "clusterTabServer(", "clusVisTabServer(",
                    "updateTabServer(", "saveTabServer(")
  first_module <- min(vapply(module_calls, function(p) { i <- at(p); if (i < 0L) .Machine$integer.max else i }, 1L))
  registry <- at("workspace_jobs_registry(")
  userdata <- at("session$userData$workspace_jobs")
  expect_gt(registry, 0L)
  expect_gt(userdata, 0L)
  expect_lt(registry, first_module)
  expect_lt(userdata, first_module)
  panel <- at("workspace_jobs_ui(")
  expect_gt(panel, 0L)
  expect_lt(panel, at("tabItems("))
  ended <- at("onSessionEnded(")
  close <- at("workspace_jobs_close(")
  expect_gt(close, ended)
  expect_lt(close, at("for (nm in shiny::isolate(names(u_degdfs)))"))
  expect_match(text, "future::plan(future::multisession, workers = 2)", fixed = TRUE)
})

# ---- R19-R27: the queue -----------------------------------------------------------

# Three sessions, each with the app's registry, the enrichment module and the panel.
ws6_three <- function(dir, kit, labels = c("deg_a", "deg_b", "deg_c"), env = parent.frame(), ...) {
  out <- list()
  for (i in seq_along(labels)) {
    sess <- ws6_session(paste0("S", i), env = env)
    jobs <- ws6_install(sess, ...)
    state <- ws6_add_deg(ws6_state(), c(labels[[i]], paste0(labels[[i]], "_2")))
    ws6_mount(sess, state, modules = c("enrich", "panel"), runner = kit$enrichment, jobs = jobs)
    out[[i]] <- list(sess = sess, jobs = jobs, state = state, label = labels[[i]])
  }
  out
}
ws6_sessions <- function(x) lapply(x, `[[`, "sess")

test_that("R19 REQ-001 D3 FIFO across sessions with a live queue position", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  dir <- withr::local_tempdir()
  kit <- ws6_latch_runner(dir)
  x <- ws6_three(dir, kit)
  spy <- ws6_spy(ws6_sessions(x))
  own <- ws6_workers(1L, dir = dir)
  ws6_run(x[[1]]$sess, "deg_a")
  ws6_pid(dir, ws6_key("deg_a"), ws6_sessions(x), own = own)
  ws6_run(x[[2]]$sess, "deg_b")
  ws6_run(x[[3]]$sess, "deg_c")
  id2 <- ws6_last(x[[2]]$jobs)$run_id
  id3 <- ws6_last(x[[3]]$jobs)$run_id
  expect_identical(ws6_state_of(x[[2]]$jobs, id2), "queued")
  expect_identical(ws6_state_of(x[[3]]$jobs, id3), "queued")
  expect_match(ws6_html(x[[2]]$sess, "jobs-jobs_status"), sprintf(ws6_msg$ahead, 0L), fixed = TRUE)
  expect_match(ws6_html(x[[3]]$sess, "jobs-jobs_status"), sprintf(ws6_msg$ahead, 1L), fixed = TRUE)
  renders3 <- ws6_renders(x[[3]]$sess, "jobs-jobs_status")

  ws6_release(dir, ws6_key("deg_a"))
  expect_true(ws6_until(function() identical(ws6_state_of(x[[2]]$jobs, id2), "running"), ws6_sessions(x)[1:2]))
  ws6_own(own)
  expect_identical(spy$factory, c("S1", "S2"))
  x[[1]]$sess$s$flushReact()
  expect_gt(ws6_renders(x[[3]]$sess, "jobs-jobs_status"), renders3)
  expect_match(ws6_html(x[[3]]$sess, "jobs-jobs_status"), sprintf(ws6_msg$ahead, 0L), fixed = TRUE)

  ws6_pid(dir, ws6_key("deg_b"), ws6_sessions(x), own = own)
  ws6_release(dir, ws6_key("deg_b"))
  expect_true(ws6_until(function() identical(ws6_state_of(x[[3]]$jobs, id3), "running"), ws6_sessions(x)))
  expect_identical(spy$factory, c("S1", "S2", "S3"))
  ws6_pid(dir, ws6_key("deg_c"), ws6_sessions(x), own = own)
  ws6_release(dir, ws6_key("deg_c"))
  expect_true(ws6_until(function() identical(ws6_state_of(x[[3]]$jobs, id3), "succeeded"), ws6_sessions(x)))
})

test_that("R20 REQ-001 a session with a running job holds at most one queued job", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  dir <- withr::local_tempdir()
  kit <- ws6_latch_runner(dir)
  s1 <- ws6_session("S1")
  jobs <- ws6_install(s1)
  spy <- ws6_spy(list(s1))
  own <- ws6_workers(1L, dir = dir)
  state <- ws6_add_deg(ws6_state(), c("deg_a", "deg_b", "deg_c"))
  ws6_mount(s1, state, modules = c("enrich", "panel"), runner = kit$enrichment, jobs = jobs)
  ws6_run(s1, "deg_a")
  ws6_pid(dir, ws6_key("deg_a"), list(s1), own = own)
  ws6_run(s1, "deg_b")
  expect_identical(ws6_last(jobs)$state, "queued")
  queue <- length(ws6_queue()$entries)
  ws6_run(s1, "deg_c")
  expect_identical(ws6_shown(s1, ws6_msg$session_queue), 1L)
  expect_identical(length(ws6_queue()$entries), queue)
  expect_length(jobs$records, 2L)
  expect_identical(spy$factory, "S1")
})

test_that("R21 REQ-001 a session without a running job still holds at most one queued job", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  dir <- withr::local_tempdir()
  kit <- ws6_latch_runner(dir)
  x <- ws6_three(dir, kit, labels = c("deg_a", "deg_b"))
  spy <- ws6_spy(ws6_sessions(x))
  own <- ws6_workers(1L, dir = dir)
  ws6_run(x[[2]]$sess, "deg_b")
  ws6_pid(dir, ws6_key("deg_b"), ws6_sessions(x), own = own)
  expect_identical(x[[1]]$jobs$in_flight, character())
  ws6_run(x[[1]]$sess, "deg_a")
  expect_identical(ws6_last(x[[1]]$jobs)$state, "queued")
  queue <- length(ws6_queue()$entries)
  ws6_run(x[[1]]$sess, "deg_a_2")
  expect_identical(ws6_shown(x[[1]]$sess, ws6_msg$session_queue), 1L)
  expect_identical(length(ws6_queue()$entries), queue)
  expect_identical(spy$factory, "S2")
})

test_that("R21b REQ-001 the per-session bound reads workspace_job_session_queue_limit()", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  testthat::local_mocked_bindings(workspace_job_session_queue_limit = function() 2L, .package = "richStudio")
  dir <- withr::local_tempdir()
  kit <- ws6_latch_runner(dir)
  x <- ws6_three(dir, kit, labels = c("deg_a", "deg_b"))
  shiny::isolate(ws6_add_deg(x[[1]]$state, "deg_a_3"))
  spy <- ws6_spy(ws6_sessions(x))
  own <- ws6_workers(1L, dir = dir)
  ws6_run(x[[2]]$sess, "deg_b")
  ws6_pid(dir, ws6_key("deg_b"), ws6_sessions(x), own = own)
  ws6_run(x[[1]]$sess, "deg_a")
  ws6_run(x[[1]]$sess, "deg_a_2")
  expect_identical(vapply(x[[1]]$jobs$records, `[[`, character(1), "state"), c("queued", "queued"))
  ws6_run(x[[1]]$sess, "deg_a_3")
  expect_identical(ws6_shown(x[[1]]$sess, ws6_msg$session_queue), 1L)
  expect_length(x[[1]]$jobs$records, 2L)
  expect_identical(spy$factory, "S2")
})

test_that("R22 REQ-001 the process queue bound refuses with the queue length only", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  testthat::local_mocked_bindings(workspace_job_queue_limit = function() 2L, .package = "richStudio")
  dir <- withr::local_tempdir()
  kit <- ws6_latch_runner(dir)
  x <- ws6_three(dir, kit, labels = c("deg_a", "deg_b", "deg_c", "deg_d"))
  spy <- ws6_spy(ws6_sessions(x))
  own <- ws6_workers(1L, dir = dir)
  ws6_run(x[[1]]$sess, "deg_a")
  ws6_pid(dir, ws6_key("deg_a"), ws6_sessions(x), own = own)
  ws6_run(x[[2]]$sess, "deg_b")
  ws6_run(x[[3]]$sess, "deg_c")
  expect_length(ws6_queue()$entries, 2L)
  ws6_run(x[[4]]$sess, "deg_d")
  expect_identical(ws6_shown(x[[4]]$sess, sprintf(ws6_msg$queue_full, 2L)), 1L)
  expect_length(x[[4]]$jobs$records, 0L)
  expect_length(ws6_queue()$entries, 2L)
  expect_identical(spy$factory, "S1")
  html <- paste(vapply(x[[4]]$sess$log$notes, ws6_show_html, character(1)), collapse = " ")
  for (other in c("deg_b", "deg_c", x[[2]]$jobs$owner, x[[3]]$jobs$owner)) expect_false(grepl(other, html, fixed = TRUE))
})

test_that("R23 REQ-001 future() is never called while no worker is free", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  dir <- withr::local_tempdir()
  kit <- ws6_latch_runner(dir)
  s1 <- ws6_session("S1")
  jobs <- ws6_install(s1)
  spy <- ws6_spy(list(s1))
  spy$free <- function() 0L
  own <- ws6_workers(1L, dir = dir)
  state <- ws6_add_deg(ws6_state(), "deg_a")
  ws6_mount(s1, state, modules = c("enrich", "panel"), runner = kit$enrichment, jobs = jobs)
  ws6_run(s1, "deg_a")
  id <- ws6_last(jobs)$run_id
  expect_identical(ws6_state_of(jobs, id), "queued")
  s1$s$elapse(600)
  s1$s$elapse(600)
  expect_identical(ws6_state_of(jobs, id), "queued")
  expect_length(spy$factory, 0L)
  expect_true(any(spy$events == "free:0"))
  spy$free <- function() 1L
  s1$s$elapse(600)
  expect_identical(spy$factory, "S1")
  expect_identical(ws6_state_of(jobs, id), "running")
  calls <- which(startsWith(spy$events, "future:"))
  expect_length(calls, 1L)
  for (i in calls) {
    expect_gt(i, 1L)
    expect_match(spy$events[[i - 1L]], "^free:[1-9]")
  }
  ws6_pid(dir, ws6_key("deg_a"), list(s1), own = own)
  ws6_release(dir, ws6_key("deg_a"))
  expect_true(ws6_until(function() identical(ws6_state_of(jobs, id), "succeeded"), list(s1)))
})

# R24: S1 holds the only worker; S2's queued job loses its input; S3 waits behind it.
ws6_r24 <- function(env = parent.frame(), s2_modules = c("enrich", "panel")) {
  dir <- withr::local_tempdir(.local_envir = env)
  kit <- ws6_latch_runner(dir)
  testthat::local_mocked_bindings(workspace_cluster_compute = kit$cluster, .package = "richStudio", .env = env)
  x <- list()
  for (i in 1:3) {
    sess <- ws6_session(paste0("S", i), env = env)
    jobs <- ws6_install(sess)
    state <- ws6_add_rr(ws6_add_deg(ws6_state(), paste0("deg_", i)), paste0("rr_", i))
    x[[i]] <- list(sess = sess, jobs = jobs, state = state)
  }
  spy <- ws6_spy(ws6_sessions(x), env = env)
  own <- ws6_workers(1L, dir = dir, env = env)
  ws6_mount(x[[1]]$sess, x[[1]]$state, modules = c("enrich", "panel"), runner = kit$enrichment, jobs = x[[1]]$jobs)
  ws6_mount(x[[2]]$sess, x[[2]]$state, modules = s2_modules, runner = kit$enrichment, jobs = x[[2]]$jobs)
  ws6_mount(x[[3]]$sess, x[[3]]$state, modules = c("enrich", "panel"), runner = kit$enrichment, jobs = x[[3]]$jobs)
  ws6_run(x[[1]]$sess, "deg_1")
  ws6_pid(dir, ws6_key("deg_1"), ws6_sessions(x), own = own)
  list(x = x, spy = spy, own = own, dir = dir, kit = kit)
}

ws6_r24_expect <- function(r, id2, button, stores2, s1_enables = 0L) {
  x <- r$x
  expect_identical(ws6_state_of(x[[2]]$jobs, id2), "superseded")
  expect_false(id2 %in% ws6_queue_ids())
  expect_false("S2" %in% r$spy$factory)
  expect_identical(ws6_snapshot(x[[2]]$state)$rrdfs, stores2$rrdfs)
  expect_identical(ws6_snapshot(x[[2]]$state)$clusdfs, stores2$clusdfs)
  expect_gte(ws6_enables(x[[2]]$sess, button), 1L)
  expect_identical(ws6_enables(x[[1]]$sess, button), s1_enables)
  expect_identical(ws6_enables(x[[3]]$sess, button), 0L)
  expect_true(richStudio:::workspace_job_queue_consistent())
}

# After the immediate sweep, S1's worker is released: S3 gets it, S2 never runs.
ws6_r24_release <- function(r, id3) {
  x <- r$x
  ws6_release(r$dir, ws6_key("deg_1"))
  expect_true(ws6_until(function() identical(ws6_state_of(x[[3]]$jobs, id3), "running"), ws6_sessions(x)))
  ws6_own(r$own)
  expect_identical(r$spy$factory, c("S1", "S3"))
}

test_that("R24a REQ-002 AC-001 a queued job whose input is confirm-removed is superseded at once", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  r <- ws6_r24(s2_modules = c("enrich", "update", "panel"))
  x <- r$x
  ws6_run(x[[2]]$sess, "deg_2")
  id2 <- ws6_last(x[[2]]$jobs)$run_id
  ws6_run(x[[3]]$sess, "deg_3")
  id3 <- ws6_last(x[[3]]$jobs)$run_id
  expect_identical(ws6_state_of(x[[2]]$jobs, id2), "queued")
  x[[2]]$sess$s$setInputs("update-remove_deg_select" = "deg_2")
  x[[2]]$sess$s$setInputs("update-confirm_remove_deg" = 1L)
  expect_identical(ws6_state_of(x[[2]]$jobs, id2), "superseded")
  stores2 <- ws6_snapshot(x[[2]]$state)
  ws6_r24_expect(r, id2, "enrich-enrich_deg", stores2)
  ws6_r24_release(r, id3)
  ws6_settle(ws6_sessions(x))
  ws6_r24_expect(r, id2, "enrich-enrich_deg", stores2, s1_enables = 1L)
  ws6_release_all(r$dir)
})

test_that("R24b REQ-002 AC-001 a queued job is superseded by a session load in its session", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  r <- ws6_r24(s2_modules = c("enrich", "save", "panel"))
  x <- r$x
  valid <- withr::local_tempfile(fileext = ".rds")
  saveRDS(ws_baseline_session(), valid)
  ws6_run(x[[2]]$sess, "deg_2")
  id2 <- ws6_last(x[[2]]$jobs)$run_id
  ws6_run(x[[3]]$sess, "deg_3")
  id3 <- ws6_last(x[[3]]$jobs)$run_id
  expect_identical(ws6_state_of(x[[2]]$jobs, id2), "queued")
  ws6_load(x[[2]]$sess, valid, "valid.rds")
  expect_identical(ws6_state_of(x[[2]]$jobs, id2), "superseded")
  expect_match(ws6_rec(x[[2]]$jobs, id2)$note, "workspace replaced", fixed = TRUE)
  stores2 <- ws6_snapshot(x[[2]]$state)
  ws6_r24_expect(r, id2, "enrich-enrich_deg", stores2)
  ws6_r24_release(r, id3)
  ws6_settle(ws6_sessions(x))
  ws6_r24_expect(r, id2, "enrich-enrich_deg", stores2, s1_enables = 1L)
  ws6_release_all(r$dir)
})

test_that("R24c REQ-002 AC-001 an input removed outside the lock supersedes the queued job at dispatch", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  r <- ws6_r24(s2_modules = c("cluster", "upload", "panel"))
  x <- r$x
  ws6_cluster(x[[2]]$sess, "rr_2", "k_2")
  id2 <- ws6_last(x[[2]]$jobs)$run_id
  ws6_run(x[[3]]$sess, "deg_3")
  id3 <- ws6_last(x[[3]]$jobs)$run_id
  x[[2]]$sess$s$setInputs("cluster_upload-rr_list_table_rows_selected" = 1L)
  x[[2]]$sess$s$setInputs("cluster_upload-remove_rr" = 1L)
  expect_identical(ws6_state_of(x[[2]]$jobs, id2), "queued")
  stores2 <- ws6_snapshot(x[[2]]$state)
  ws6_release(r$dir, ws6_key("deg_1"))
  expect_true(ws6_until(function() identical(ws6_state_of(x[[3]]$jobs, id3), "running"), ws6_sessions(x)))
  ws6_own(r$own)
  ws6_r24_expect(r, id2, "cluster-cluster", stores2)
  expect_identical(r$spy$factory, c("S1", "S3"))
  expect_identical(ws6_claims(r$dir, "k_2"), 0L)
  ws6_release_all(r$dir)
})

ws6_r25 <- function(interrupts, env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  kit <- ws6_latch_runner(dir)
  x <- ws6_three(dir, kit, env = env)
  spy <- ws6_spy(ws6_sessions(x), env = env)
  cancels <- ws6_cancel_spy(env = env)
  own <- ws6_workers(1L, interrupts = interrupts, dir = dir, env = env)
  ws6_run(x[[1]]$sess, "deg_a")
  ws6_pid(dir, ws6_key("deg_a"), ws6_sessions(x), own = own)
  ws6_run(x[[2]]$sess, "deg_b")
  ws6_run(x[[3]]$sess, "deg_c")
  id2 <- ws6_last(x[[2]]$jobs)$run_id
  expect_match(ws6_html(x[[3]]$sess, "jobs-jobs_status"), sprintf(ws6_msg$ahead, 1L), fixed = TRUE)
  ws6_action(x[[2]]$sess, "stop", id2)
  expect_identical(ws6_state_of(x[[2]]$jobs, id2), "cancelled")
  expect_identical(ws6_rec(x[[2]]$jobs, id2)$note, ws6_msg$removed)
  expect_false(id2 %in% ws6_queue_ids())
  expect_identical(cancels$n, 0L)
  expect_false("S2" %in% spy$factory)
  x[[2]]$sess$s$flushReact()
  expect_match(ws6_html(x[[3]]$sess, "jobs-jobs_status"), sprintf(ws6_msg$ahead, 0L), fixed = TRUE)
  expect_gte(ws6_enables(x[[2]]$sess, "enrich-enrich_deg"), 1L)
  expect_true(richStudio:::workspace_job_queue_consistent())
  ws6_release_all(dir)
}

test_that("R25 REQ-003 AC-002 Stop on a queued job removes it without a worker", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  ws6_r25(interrupts = TRUE)
})

test_that("R25b REQ-003 AC-002 Stop on a queued job works where workers cannot be stopped", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  ws6_r25(interrupts = FALSE)
})

test_that("R26 REQ-002 closing a session drops its queued job", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  dir <- withr::local_tempdir()
  kit <- ws6_latch_runner(dir)
  x <- ws6_three(dir, kit)
  spy <- ws6_spy(ws6_sessions(x))
  own <- ws6_workers(1L, dir = dir)
  ws6_run(x[[1]]$sess, "deg_a")
  ws6_pid(dir, ws6_key("deg_a"), ws6_sessions(x), own = own)
  ws6_run(x[[2]]$sess, "deg_b")
  ws6_run(x[[3]]$sess, "deg_c")
  id2 <- ws6_last(x[[2]]$jobs)$run_id
  id3 <- ws6_last(x[[3]]$jobs)$run_id
  x[[2]]$sess$s$close()
  expect_false(id2 %in% ws6_queue_ids())
  expect_true(richStudio:::workspace_job_queue_consistent())
  ws6_release(dir, ws6_key("deg_a"))
  open <- ws6_sessions(x)[c(1, 3)]
  expect_true(ws6_until(function() identical(ws6_state_of(x[[3]]$jobs, id3), "running"), open))
  ws6_own(own)
  expect_identical(spy$factory, c("S1", "S3"))
  expect_identical(ws6_claims(dir, "deg_b"), 0L)
  ws6_release_all(dir)
})

test_that("R27 AC-002 sibling isolation under queueing: counts only, own outputs only", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  dir <- withr::local_tempdir()
  kit <- ws6_latch_runner(dir)
  x <- ws6_three(dir, kit)
  spy <- ws6_spy(ws6_sessions(x))
  own <- ws6_workers(1L, dir = dir)
  ws6_run(x[[1]]$sess, "deg_a")
  pid1 <- ws6_pid(dir, ws6_key("deg_a"), ws6_sessions(x), own = own)
  id1 <- ws6_last(x[[1]]$jobs)$run_id
  ws6_run(x[[2]]$sess, "deg_b")
  ws6_run(x[[3]]$sess, "deg_c")
  id2 <- ws6_last(x[[2]]$jobs)$run_id
  id3 <- ws6_last(x[[3]]$jobs)$run_id
  ws6_settle(ws6_sessions(x))
  stores1 <- ws6_snapshot(x[[1]]$state)
  stores2 <- ws6_snapshot(x[[2]]$state)
  counts <- c(s1_status = ws6_renders(x[[1]]$sess, "jobs-jobs_status"),
              s1_list = ws6_renders(x[[1]]$sess, "jobs-jobs_list"),
              s2_list = ws6_renders(x[[2]]$sess, "jobs-jobs_list"),
              s3_status = ws6_renders(x[[3]]$sess, "jobs-jobs_status"),
              s3_list = ws6_renders(x[[3]]$sess, "jobs-jobs_list"))

  ws6_action(x[[2]]$sess, "stop", id2)
  ws6_settle(ws6_sessions(x))
  expect_true(ws6_alive(pid1))
  expect_identical(ws6_state_of(x[[1]]$jobs, id1), "running")
  expect_match(ws6_html(x[[3]]$sess, "jobs-jobs_status"), sprintf(ws6_msg$ahead, 0L), fixed = TRUE)
  expect_gt(ws6_renders(x[[3]]$sess, "jobs-jobs_status"), counts[["s3_status"]])
  expect_identical(ws6_renders(x[[3]]$sess, "jobs-jobs_list"), counts[["s3_list"]])
  expect_identical(ws6_renders(x[[1]]$sess, "jobs-jobs_status"), counts[["s1_status"]])
  expect_identical(ws6_renders(x[[1]]$sess, "jobs-jobs_list"), counts[["s1_list"]])
  expect_identical(ws6_renders(x[[2]]$sess, "jobs-jobs_list"), counts[["s2_list"]] + 1L)

  ws6_action(x[[1]]$sess, "stop", id1)
  ws6_own(own)
  expect_true(ws6_until(function() identical(ws6_state_of(x[[1]]$jobs, id1), "cancelled"), ws6_sessions(x),
                        timeout = 10, elapse = 100))
  expect_false(ws6_alive(pid1))
  expect_true(ws6_until(function() identical(ws6_state_of(x[[3]]$jobs, id3), "running"), ws6_sessions(x)))
  expect_identical(spy$factory, c("S1", "S3"))
  ws6_pid(dir, ws6_key("deg_c"), ws6_sessions(x), own = own)
  ws6_release(dir, ws6_key("deg_c"))
  expect_true(ws6_until(function() identical(ws6_state_of(x[[3]]$jobs, id3), "succeeded"), ws6_sessions(x)))
  expect_identical(ws6_shown(x[[3]]$sess, ws6_msg$enrich_ok), 1L)
  expect_identical(ws6_shown(x[[1]]$sess, ws6_msg$enrich_ok), 0L)
  expect_identical(ws6_shown(x[[2]]$sess, ws6_msg$enrich_ok), 0L)
  expect_true("deg_c_enriched" %in% shiny::isolate(names(x[[3]]$state$u_rrdfs)))
  expect_identical(ws6_snapshot(x[[1]]$state), stores1)
  expect_identical(ws6_snapshot(x[[2]]$state), stores2)
})

# ---- R28-R30: saved records, lossless round trip, containment ----------------------

test_that("R28 REQ-001 REQ-002 saved queued and running records reopen as interrupted history", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  dir <- withr::local_tempdir()
  kit <- ws6_latch_runner(dir)
  src <- ws6_session("SRC")
  jobs_src <- ws6_install(src)
  dst <- ws6_session("DST")
  jobs_dst <- ws6_install(dst)
  spy <- ws6_spy(list(src, dst))
  own <- ws6_workers(2L, dir = dir)
  state_src <- ws6_add_deg(ws6_state(), c("x1", "x2", "x3"))
  ws6_mount(src, state_src, modules = c("enrich", "save", "panel"), runner = kit$enrichment, jobs = jobs_src)
  ws6_run(src, "x1")
  ws6_pid(dir, ws6_key("x1"), list(src), own = own)
  ws6_release(dir, ws6_key("x1"))
  expect_true(ws6_until(function() identical(ws6_last(jobs_src)$state, "succeeded"), list(src)))
  ws6_run(src, "x2")
  ws6_pid(dir, ws6_key("x2"), list(src), own = own)
  ws6_run(src, "x3")
  states <- vapply(jobs_src$records, `[[`, character(1), "state")
  expect_identical(states, c("succeeded", "running", "queued"))
  saved <- withr::local_tempfile(fileext = ".rds")
  ws6_save(src, saved, "rds")

  state_dst <- ws6_add_deg(ws6_state(), "live")
  ws6_mount(dst, state_dst, modules = c("enrich", "save", "panel"), runner = kit$enrichment, jobs = jobs_dst)
  ws6_run(dst, "live")
  ws6_pid(dir, ws6_key("live"), list(dst), own = own)
  live <- ws6_last(jobs_dst)
  # The saved running record takes the live record's run id, forcing a collision.
  payload <- readRDS(saved)
  records <- richStudio:::workspace_run_records_parse(payload$run_records_json)
  records[[2]]$run_id <- live$run_id
  payload$run_records_json <- richStudio:::workspace_run_records_json(records)
  saveRDS(payload, saved)
  queue <- length(ws6_queue()$entries)
  factory <- length(spy$factory)
  ws6_load(dst, saved, "saved.rds")

  expect_identical(ws6_rec(jobs_dst, live$run_id)$state, "running")
  expect_identical(ws6_rec(jobs_dst, live$run_id)$inputs, live$inputs)
  imported <- Filter(function(r) !identical(r$run_id, live$run_id), jobs_dst$records)
  expect_length(imported, 3L)
  by_source <- function(id) Filter(function(r) identical(r$run_id, id) || identical(r$imported_from, id), imported)[[1]]
  rekeyed <- by_source(live$run_id)
  expect_false(identical(rekeyed$run_id, live$run_id))
  expect_identical(rekeyed$imported_from, live$run_id)
  expect_identical(rekeyed$state, "interrupted")
  expect_identical(rekeyed$note, ws6_msg$interrupted)
  expect_length(rekeyed$note, 1L)
  expect_identical(by_source(records[[3]]$run_id)$state, "interrupted")
  expect_identical(by_source(records[[1]]$run_id)$state, "succeeded")
  expect_identical(length(ws6_queue()$entries), queue)
  expect_identical(length(spy$factory), factory)
  list_html <- ws6_html(dst, "jobs-jobs_list")
  for (r in imported) expect_identical(ws6_buttons_for(list_html, r$run_id), 0L)

  # An invalid record is dropped and counted.
  extra <- ws6_session("EXTRA")
  jobs_extra <- ws6_install(extra)
  bad <- records
  bad[[1]]$version <- 2L
  shiny::withReactiveDomain(extra$s, richStudio:::workspace_run_records_reopen(
    richStudio:::workspace_run_records_json(bad), jobs_extra))
  expect_length(jobs_extra$records, 2L)
  reported <- vapply(extra$log$notes, ws6_show_html, character(1))
  expect_true(any(grepl("\\b1\\b", reported) & grepl("record", reported, ignore.case = TRUE)))

  # The history bound applies right after import, oldest imported terminal first.
  small <- ws6_session("SMALL")
  jobs_small <- ws6_install(small, policy_loader = function() {
    policy <- richStudio:::workspace_resource_policy()
    policy$limits$history_runs <- 2L
    policy
  })
  shiny::withReactiveDomain(small$s, richStudio:::workspace_run_records_reopen(
    richStudio:::workspace_run_records_json(records), jobs_small))
  expect_length(jobs_small$records, 2L)
  kept <- c(ws6_ids(jobs_small), vapply(jobs_small$records, function(r) {
    if (is.null(r$imported_from) || is.na(r$imported_from)) NA_character_ else as.character(r$imported_from)
  }, character(1)))
  expect_false(records[[1]]$run_id %in% kept)
  ws6_release_all(dir)
})

# Records in the registry's internal form (plan item 1), appended to the registry.
ws6_internal_record <- function(jobs, run_id, kind, state, settings, inputs, outputs = character(),
                                retry_of = NA_character_, note = NA_character_) {
  at <- as.POSIXct("2026-10-23 10:00:00", tz = "UTC")
  list(run_id = run_id, kind = kind, state = state, created = at, queued_at = at,
       started = if (state == "queued") as.POSIXct(NA) else at + 1,
       ended = if (state %in% c("queued", "running")) as.POSIXct(NA) else at + 60,
       owner = jobs$owner, generation = jobs$generation, inputs = inputs, settings = settings,
       retry_of = retry_of, imported_from = NA_character_, outputs = outputs, note = note,
       error_summary = NA_character_, stop_supported = FALSE)
}

test_that("R29 REQ-001 run records survive RDS and JSON saves losslessly", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  latin1 <- "\xe9t\xe9"
  Encoding(latin1) <- "latin1"
  invalid <- rawToChar(as.raw(c(0x61, 0xff, 0x62)))
  input <- function(store, label, revision = 0L) list(store = store, label = label, revision = revision)
  build <- function(jobs) list(
    ws6_internal_record(jobs, "aaaaaaaaaaaa", "enrichment", "succeeded",
      list(species = "mouse", anntype = "GO", keytype = "SYMBOL", ontology = NULL, cutoff = 1e-5,
           query = list(list(name = "a", query_rule = list(gene_col = "gene", column = "padj", role = "adjusted",
                                                           cutoff = 0.0123456789),
                             n_submitted = 12L, revision_digest = "deadbeef"))),
      list(input("deg", "a")), "a_enriched"),
    ws6_internal_record(jobs, "bbbbbbbbbbbb", "clustering", "failed",
      list(method = "richR", params = list(cutoff = 0.123456, overlap = 0.5, minSize = 2, linkage = 0.1 + 0.2),
           cluster_name = "k1", selected = c("r1", "r2")),
      list(input("rr", "r1"), input("rr", "r2", 3L)), character(), note = ws6_msg$could_not_start),
    ws6_internal_record(jobs, "cccccccccccc", "clustering", "queued",
      list(method = "hierarchical", params = list(distance_metric = "kappa", min_terms = 2L, min_value = 1e-8),
           cluster_name = "été 漢字", selected = "r1"),
      list(input("rr", "r1"))),
    ws6_internal_record(jobs, "eeeeeeeeeeee", "enrichment", "succeeded", list(species = "mouse", cutoff = 1e-5),
      list(input("deg", latin1)), paste0(latin1, "_enriched")),
    ws6_internal_record(jobs, "ffffffffffff", "enrichment", "succeeded", list(species = "human", cutoff = 0.05),
      list(input("deg", invalid)), character()),
    ws6_internal_record(jobs, "dddddddddddd", "enrichment", "running",
      list(species = "human", anntype = "KEGG", keytype = "ENTREZID", ontology = "", cutoff = 0.05, query = list()),
      list(input("deg", "b", 2L), input("deg", "c")), retry_of = "aaaaaaaaaaaa"))

  for (format in c("rds", "json")) for (pick in list(1:6, 2L, integer())) {
    src <- ws6_session("SRC")
    jobs <- ws6_install(src)
    jobs$records <- build(jobs)[pick]
    state <- ws6_add_deg(ws6_state(), "a")
    ws6_mount(src, state, modules = "save")
    at_save <- richStudio:::workspace_run_records(jobs)
    if (length(pick) == 6L) {
      labels <- vapply(at_save, function(r) r$inputs[[1]]$label, character(1))
      expect_identical(labels[[4]], "été")
      expect_identical(labels[[5]], "a?b")
      expect_identical(at_save[[2]]$settings$params$cutoff, 0.123456)
      expect_identical(names(at_save[[1]]$settings), c("species", "anntype", "keytype", "ontology", "cutoff", "query"))
    }
    saved <- withr::local_tempfile(fileext = paste0(".", format))
    ws6_save(src, saved, format)
    loaded <- ws6_saved_records(saved, format)
    expect_length(loaded, length(pick))
    for (i in seq_along(pick)) expect_true(identical(loaded[[i]], at_save[[i]]), info = paste(format, i))

    dst <- ws6_session("DST")
    jobs_dst <- ws6_install(dst)
    ws6_mount(dst, ws6_add_deg(ws6_state(), "other"), modules = "save")
    ws6_load(dst, saved)
    reopened <- richStudio:::workspace_run_records(jobs_dst)
    expect_length(reopened, length(pick))
    for (i in seq_along(pick)) {
      expected <- at_save[[i]]
      if (expected$state %in% c("queued", "running")) {
        expect_identical(reopened[[i]]$state, "interrupted", info = paste(format, i))
        expect_identical(reopened[[i]]$note, ws6_msg$interrupted)
        expect_null(reopened[[i]]$ended)
        # `[<-` with a list keeps a NULL element in place; `$<-` would drop it.
        expected[c("state", "note", "ended")] <- reopened[[i]][c("state", "note", "ended")]
      }
      expect_true(identical(reopened[[i]], expected), info = paste(format, "reopened", i))
    }
    src$s$close()
    dst$s$close()
  }
})

test_that("R30 REQ-002 AC-002 dispatch errors are contained to the entry that raised them", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  dir <- withr::local_tempdir()
  kit <- ws6_latch_runner(dir)
  x <- ws6_three(dir, kit)
  spy <- ws6_spy(ws6_sessions(x))
  spy$fail <- function(tag) identical(tag, "S2")
  own <- ws6_workers(1L, dir = dir)
  ws6_run(x[[1]]$sess, "deg_a")
  ws6_pid(dir, ws6_key("deg_a"), ws6_sessions(x), own = own)
  ws6_run(x[[2]]$sess, "deg_b")
  ws6_run(x[[3]]$sess, "deg_c")
  id2 <- ws6_last(x[[2]]$jobs)$run_id
  id3 <- ws6_last(x[[3]]$jobs)$run_id
  enables1 <- ws6_enables(x[[1]]$sess, "enrich-enrich_deg")
  ws6_release(dir, ws6_key("deg_a"))
  expect_true(ws6_until(function() identical(ws6_state_of(x[[3]]$jobs, id3), "running"), ws6_sessions(x)))
  ws6_own(own)
  expect_false(x[[1]]$sess$s$isClosed())
  expect_identical(ws6_state_of(x[[2]]$jobs, id2), "failed")
  expect_identical(ws6_rec(x[[2]]$jobs, id2)$note, ws6_msg$could_not_start)
  expect_true(richStudio:::workspace_job_queue_consistent())
  expect_gte(ws6_enables(x[[2]]$sess, "enrich-enrich_deg"), 1L)
  # S1 gets only its own finally's re-enable; S3, still running, gets none.
  expect_identical(ws6_enables(x[[1]]$sess, "enrich-enrich_deg"), enables1 + 1L)
  expect_identical(ws6_enables(x[[3]]$sess, "enrich-enrich_deg"), 0L)
  spy$fail <- NULL
  ws6_run(x[[2]]$sess, "deg_b")
  expect_identical(ws6_last(x[[2]]$jobs)$state, "queued")
  expect_false(identical(ws6_last(x[[2]]$jobs)$run_id, id2))
  ws6_release_all(dir)
  ws6_until(function() !length(x[[3]]$jobs$in_flight) && !length(x[[2]]$jobs$in_flight), ws6_sessions(x))
})

test_that("R30b REQ-002 AC-002 authorization, free-worker and policy errors at dispatch are contained", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  dir <- withr::local_tempdir()
  kit <- ws6_latch_runner(dir)
  flag <- new.env(parent = emptyenv())
  flag$policy <- FALSE
  loader <- function() if (isTRUE(flag$policy)) stop("policy gone") else richStudio:::workspace_resource_policy()
  x <- ws6_three(dir, kit, policy_loader = loader)
  spy <- ws6_spy(ws6_sessions(x))
  real_authorized <- richStudio:::workspace_jobs_authorized
  testthat::local_mocked_bindings(workspace_jobs_authorized = function(jobs, run_id, ...) {
    if (identical(jobs, x[[2]]$jobs) && isTRUE(flag$auth)) stop("authorization failed")
    real_authorized(jobs, run_id, ...)
  }, .package = "richStudio")
  own <- ws6_workers(1L, dir = dir)
  ws6_run(x[[1]]$sess, "deg_a")
  ws6_pid(dir, ws6_key("deg_a"), ws6_sessions(x), own = own)

  # Free-worker read raises: read as 0, nothing starts, nothing closes.
  spy$free <- function() stop("free workers unknown")
  ws6_run(x[[2]]$sess, "deg_b")
  id2 <- ws6_last(x[[2]]$jobs)$run_id
  x[[2]]$sess$s$elapse(600)
  expect_identical(ws6_state_of(x[[2]]$jobs, id2), "queued")
  expect_false(x[[2]]$sess$s$isClosed())
  expect_true(richStudio:::workspace_job_queue_consistent())
  spy$free <- NULL

  # Policy load error at dispatch: the entry stays queued; its session is told once.
  flag$policy <- TRUE
  ws6_release(dir, ws6_key("deg_a"))
  ws6_until(function() !length(x[[1]]$jobs$in_flight), ws6_sessions(x))
  x[[2]]$sess$s$elapse(600)
  x[[2]]$sess$s$elapse(600)
  expect_identical(ws6_state_of(x[[2]]$jobs, id2), "queued")
  expect_identical(ws6_shown(x[[2]]$sess, ws6_msg$policy_wait), 1L)
  expect_true(richStudio:::workspace_job_queue_consistent())
  expect_false(x[[1]]$sess$s$isClosed())

  # Authorization raises: the entry fails as Could not start; the next entry runs.
  flag$policy <- FALSE
  flag$auth <- TRUE
  ws6_run(x[[3]]$sess, "deg_c")
  id3 <- ws6_last(x[[3]]$jobs)$run_id
  expect_true(ws6_until(function() identical(ws6_state_of(x[[3]]$jobs, id3), "running"), ws6_sessions(x)))
  ws6_own(own)
  expect_identical(ws6_state_of(x[[2]]$jobs, id2), "failed")
  expect_identical(ws6_rec(x[[2]]$jobs, id2)$note, ws6_msg$could_not_start)
  expect_true(richStudio:::workspace_job_queue_consistent())
  expect_false(any(vapply(ws6_sessions(x), function(s) s$s$isClosed(), logical(1))))
  ws6_release_all(dir)
  ws6_until(function() !length(x[[3]]$jobs$in_flight), ws6_sessions(x))
})

# ---- R31-R33: code review r1 findings F1-F3 -------------------------------------------

ws6_publish_result <- function(name) {
  list(name = name, result = data.frame(Annot = "Term one", Term = "T1", Pvalue = 0.01, Padj = 0.02,
                                        GeneID = "g1,g2", stringsAsFactors = FALSE),
       anntype = "Reactome", keytype = "SYMBOL", ontology = "", species = "human")
}

test_that("R31 REQ-005 F1 a publish error fails the record, releases it and admits a resubmission", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  ws6_sequential()
  s1 <- ws6_session("S1")
  jobs <- ws6_install(s1)
  state <- ws6_add_deg(ws6_state(), "deg_a")
  bad_runner <- function(deg_inputs, cutoff, species, anntype, keytype, ontology) list("not a result list")
  ws6_mount(s1, state, modules = c("enrich", "panel"), runner = bad_runner, jobs = jobs)
  ws6_run(s1, "deg_a")
  id <- ws6_last(jobs)$run_id
  expect_true(ws6_until(function() identical(ws6_state_of(jobs, id), "failed"), list(s1), timeout = 10))
  ws6_settle(list(s1))
  expect_identical(ws6_rec(jobs, id)$error_summary, "$ operator is invalid for atomic vectors")
  expect_identical(jobs$in_flight, character())
  expect_null(jobs$handles[[id]]$future)
  expect_identical(ws6_shown(s1, sprintf("Enrichment failed (run %s)", ws6_id8(id))), 1L)
  expect_false(grepl("elapsed", ws6_html(s1, "jobs-jobs_time"), fixed = TRUE))
  expect_true(ws6_has_button(ws6_html(s1, "jobs-jobs_list"), id, "Retry"))
  ws6_run(s1, "deg_a")
  expect_identical(ws6_shown(s1, ws6_msg$identical), 0L)
  expect_length(jobs$records, 2L)

  # A mid-loop error: the outputs written before it are named in the failure note.
  s2 <- ws6_session("S2")
  jobs2 <- ws6_install(s2)
  state2 <- ws6_add_deg(ws6_state(), c("first", "second"))
  partial_runner <- function(deg_inputs, cutoff, species, anntype, keytype, ontology) {
    list(ws6_publish_result(deg_inputs[[1]]$name), "not a result")
  }
  ws6_mount(s2, state2, modules = c("enrich", "panel"), runner = partial_runner, jobs = jobs2)
  ws6_run(s2, c("first", "second"))
  id2 <- ws6_last(jobs2)$run_id
  expect_true(ws6_until(function() identical(ws6_state_of(jobs2, id2), "failed"), list(s2), timeout = 10))
  expect_match(ws6_rec(jobs2, id2)$note, "first_enriched", fixed = TRUE)
  expect_true("first_enriched" %in% shiny::isolate(names(state2$u_rrdfs)))

  # Clustering: the failed run no longer reserves its name.
  testthat::local_mocked_bindings(workspace_cluster_compute = function(genesets, method, params, cluster_name) "not a result",
                                  .package = "richStudio")
  s3 <- ws6_session("S3")
  jobs3 <- ws6_install(s3)
  state3 <- ws6_add_rr(ws6_state(), "rr1")
  ws6_mount(s3, state3, modules = c("cluster", "panel"), jobs = jobs3)
  ws6_cluster(s3, "rr1", "k")
  id3 <- ws6_last(jobs3)$run_id
  expect_true(ws6_until(function() identical(ws6_state_of(jobs3, id3), "failed"), list(s3), timeout = 10))
  ws6_settle(list(s3))
  ws6_cluster(s3, "rr1", "k")
  expect_identical(ws6_shown(s3, sprintf(ws6_msg$cluster_name, "k")), 0L)
  expect_length(jobs3$records, 2L)
})

test_that("R32 REQ-005 D4 F2 Retry re-checks the cluster name against the current results", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  ws6_sequential()
  dir <- withr::local_tempdir()
  kit <- ws6_latch_runner(dir)
  ws6_release_all(dir)
  testthat::local_mocked_bindings(workspace_cluster_compute = kit$cluster, .package = "richStudio")
  s1 <- ws6_session("S1")
  jobs <- ws6_install(s1)
  spy <- ws6_spy(list(s1))
  state <- ws6_add_rr(ws6_state(), "rr1")
  ws6_mount(s1, state, modules = c("cluster", "panel"), jobs = jobs)
  writeLines("engine failed", file.path(dir, "fail.txt"))
  ws6_cluster(s1, "rr1", "k")
  id <- ws6_last(jobs)$run_id
  expect_true(ws6_until(function() identical(ws6_state_of(jobs, id), "failed"), list(s1), timeout = 10))
  unlink(file.path(dir, "fail.txt"))
  ws6_cluster(s1, "rr1", "k")
  second <- ws6_last(jobs)$run_id
  expect_true(ws6_until(function() identical(ws6_state_of(jobs, second), "succeeded"), list(s1), timeout = 10))
  ws6_settle(list(s1))
  expect_identical(shiny::isolate(state$u_clusnames$labels), "k")
  expect_true(ws6_has_button(ws6_html(s1, "jobs-jobs_list"), id, "Retry"))
  notes <- length(s1$log$notes)
  calls <- length(spy$factory)
  ws6_action(s1, "retry", id)
  ws6_settle(list(s1))
  expect_identical(ws6_shown(s1, sprintf(ws6_msg$cluster_name, "k"), from = notes), 1L)
  expect_length(jobs$records, 2L)
  expect_identical(length(spy$factory), calls)
  expect_identical(shiny::isolate(state$u_clusnames$labels), "k")
  expect_identical(shiny::isolate(names(state$u_clusdfs)), "k")
})

test_that("R33 REQ-001 F3 malformed saved records are dropped and the panel still renders", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  rec <- function(id, kind = "enrichment", state = "succeeded",
                  inputs = list(list(store = "deg", label = "a", revision = 0L))) {
    list(schema = "richstudio.run_record", version = 1L, run_id = id, kind = kind, state = state,
         created = NULL, queued_at = NULL, started = NULL, ended = NULL, settings = list(species = "human"),
         inputs = inputs, outputs = list(), retry_of = NULL, imported_from = NULL, note = NULL, error_summary = NULL)
  }
  read_back <- function(x) richStudio:::workspace_run_records_parse(richStudio:::workspace_run_records_json(list(x)))[[1]]
  good <- rec("aaaaaaaaaaaa")
  expect_true(ws6_accepts(read_back(good)))
  expect_true(ws6_accepts(read_back(rec("bbbbbbbbbbbb", kind = "clustering", state = "failed", inputs = list()))))
  bad <- list(
    null_label = rec("c00000000001", inputs = list(list(store = "deg", label = NULL, revision = 0L))),
    numeric_label = rec("c00000000002", inputs = list(list(store = "deg", label = 1L, revision = 0L))),
    no_store = rec("c00000000003", inputs = list(list(label = "a", revision = 0L))),
    no_revision = rec("c00000000004", inputs = list(list(store = "deg", label = "a"))),
    bare_entry = rec("c00000000005", inputs = list("deg")),
    scalar_inputs = rec("c00000000006", inputs = "deg"),
    unknown_state = rec("c00000000007", state = "bogus"),
    unknown_kind = rec("c00000000008", kind = "other"))
  for (name in names(bad)) expect_false(ws6_accepts(read_back(bad[[name]])), info = name)

  s1 <- ws6_session("S1")
  jobs <- ws6_install(s1)
  ws6_mount(s1, ws6_state(), modules = "panel", jobs = jobs)
  shiny::withReactiveDomain(s1$s, richStudio:::workspace_run_records_reopen(
    richStudio:::workspace_run_records_json(c(list(good), unname(bad))), jobs))
  s1$s$flushReact()
  expect_identical(ws6_ids(jobs), "aaaaaaaaaaaa")
  expect_identical(ws6_shown(s1, sprintf("%d saved run record(s) could not be read and were dropped", length(bad))), 1L)
  rendered <- function() tryCatch({
    s1$s$flushReact()
    paste(as.character(s1$s$getOutput("jobs-jobs_list")$html), collapse = "")
  }, error = function(e) paste("ERROR:", conditionMessage(e)))
  html <- rendered()
  expect_false(startsWith(html, "ERROR:"))
  expect_match(html, "aaaaaaaa", fixed = TRUE)

  # Defence in depth: a malformed record already in the registry does not take the list down.
  jobs$records[[length(jobs$records) + 1L]] <- ws6_internal_record(jobs, "dddddddddddd", "enrichment", "failed",
    list(species = "human"), list(list(store = "deg", label = NULL, revision = 0L)))
  richStudio:::workspace_jobs_bump(jobs)
  html <- rendered()
  expect_false(startsWith(html, "ERROR:"))
  expect_match(html, "aaaaaaaa", fixed = TRUE)
})

test_that("R34 D4 F13 a deleted cluster result no longer blocks its name for Run and Retry", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  ws6_sequential()
  dir <- withr::local_tempdir()
  kit <- ws6_latch_runner(dir)
  ws6_release_all(dir)
  testthat::local_mocked_bindings(workspace_cluster_compute = kit$cluster, .package = "richStudio")
  s1 <- ws6_session("S1")
  jobs <- ws6_install(s1)
  state <- ws6_add_rr(ws6_state(), "rr1")
  ws6_mount(s1, state, modules = c("cluster", "update", "panel"), jobs = jobs)
  delete_k <- function(n) {
    s1$s$setInputs("update-remove_clus_select" = "k")
    s1$s$setInputs("update-confirm_remove_clus" = n)
    ws6_settle(list(s1))
  }
  refused <- function(from) ws6_shown(s1, sprintf(ws6_msg$cluster_name, "k"), from = from)

  writeLines("engine failed", file.path(dir, "fail.txt"))
  ws6_cluster(s1, "rr1", "k")
  failed <- ws6_last(jobs)$run_id
  expect_true(ws6_until(function() identical(ws6_state_of(jobs, failed), "failed"), list(s1), timeout = 10))
  unlink(file.path(dir, "fail.txt"))
  ws6_cluster(s1, "rr1", "k")
  first <- ws6_last(jobs)$run_id
  expect_true(ws6_until(function() identical(ws6_state_of(jobs, first), "succeeded"), list(s1), timeout = 10))
  ws6_settle(list(s1))

  # A live result named k is still refused by Run and by Retry.
  notes <- length(s1$log$notes)
  ws6_cluster(s1, "rr1", "k")
  ws6_settle(list(s1))
  ws6_action(s1, "retry", failed)
  ws6_settle(list(s1))
  expect_identical(refused(notes), 2L)
  expect_length(jobs$records, 2L)

  # Deleted through the update tab: the key stays in names() with a NULL value.
  delete_k(1L)
  expect_true("k" %in% shiny::isolate(names(state$u_clusdfs)))
  expect_null(shiny::isolate(state$u_clusdfs[["k"]]))
  expect_false("k" %in% shiny::isolate(state$u_clusnames$labels))

  # Run k after the deletion is admitted and publishes under k, not k_2.
  notes <- length(s1$log$notes)
  ws6_cluster(s1, "rr1", "k")
  rerun <- ws6_last(jobs)$run_id
  expect_length(jobs$records, 3L)
  expect_true(ws6_until(function() identical(ws6_state_of(jobs, rerun), "succeeded"), list(s1), timeout = 10))
  ws6_settle(list(s1))
  expect_identical(refused(notes), 0L)
  expect_identical(ws6_rec(jobs, rerun)$outputs, "k")
  expect_identical(shiny::isolate(state$u_clusnames$labels), "k")

  # Retry of the failed k after another deletion is admitted too.
  delete_k(2L)
  notes <- length(s1$log$notes)
  ws6_action(s1, "retry", failed)
  retried <- ws6_last(jobs)$run_id
  expect_length(jobs$records, 4L)
  expect_identical(ws6_rec(jobs, retried)$retry_of, failed)
  expect_true(ws6_until(function() identical(ws6_state_of(jobs, retried), "succeeded"), list(s1), timeout = 10))
  ws6_settle(list(s1))
  expect_identical(refused(notes), 0L)
  expect_identical(ws6_rec(jobs, retried)$outputs, "k")
})

test_that("R35 REQ-005 F11 a clustering publish error keeps the predecessor's intermediate results", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  ws6_sequential()
  dir <- withr::local_tempdir()
  kit <- ws6_latch_runner(dir)
  ws6_release_all(dir)
  mode <- new.env(parent = emptyenv())
  mode$v <- "ok"
  testthat::local_mocked_bindings(workspace_cluster_compute = function(genesets, method, params, cluster_name) {
    if (identical(mode$v, "atomic")) return("not a result")
    kit$cluster(genesets = genesets, method = method, params = params, cluster_name = cluster_name)
  }, .package = "richStudio")
  s1 <- ws6_session("S1")
  jobs <- ws6_install(s1)
  state <- ws6_add_rr(ws6_state(), "rr1")
  ws6_mount(s1, state, modules = c("cluster", "panel"), jobs = jobs)
  keys <- c("DistanceMatrix", "cluster_summary", "cluster_df", "method", "params")
  intermed <- function() shiny::isolate(lapply(stats::setNames(keys, keys), function(k) state$clus_intermed[[k]]))
  unchanged <- "Previous results are unchanged"

  ws6_cluster(s1, "rr1", "k1")
  id1 <- ws6_last(jobs)$run_id
  expect_true(ws6_until(function() identical(ws6_state_of(jobs, id1), "succeeded"), list(s1), timeout = 10))
  ws6_settle(list(s1))
  before <- intermed()
  expect_false(any(vapply(before, is.null, logical(1))))

  # The result shape cannot be read: nothing is cleared.
  mode$v <- "atomic"
  notes <- length(s1$log$notes)
  ws6_cluster(s1, "rr1", "k2")
  id2 <- ws6_last(jobs)$run_id
  expect_true(ws6_until(function() identical(ws6_state_of(jobs, id2), "failed"), list(s1), timeout = 10))
  ws6_settle(list(s1))
  expect_identical(ws6_shown(s1, sprintf("Clustering failed (run %s)", ws6_id8(id2)), from = notes), 1L)
  expect_identical(ws6_shown(s1, unchanged, from = notes), 1L)
  expect_identical(intermed(), before)

  # An error after the result was read but before its intermediates were stored.
  mode$v <- "ok"
  shiny::isolate(state$u_big_clusdf[["df"]] <- data.frame(other = 1L))
  notes <- length(s1$log$notes)
  ws6_cluster(s1, "rr1", "k3")
  id3 <- ws6_last(jobs)$run_id
  expect_true(ws6_until(function() identical(ws6_state_of(jobs, id3), "failed"), list(s1), timeout = 10))
  ws6_settle(list(s1))
  expect_identical(ws6_shown(s1, unchanged, from = notes), 1L)
  expect_identical(intermed(), before)
})

test_that("R36 REQ-001 F12 a non-string note or error summary is dropped and the status still renders", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  rec <- function(id, note = NULL, err = NULL) {
    list(schema = "richstudio.run_record", version = 1L, run_id = id, kind = "enrichment", state = "failed",
         created = NULL, queued_at = NULL, started = NULL, ended = NULL, settings = list(species = "human"),
         inputs = list(list(store = "deg", label = "a", revision = 0L)), outputs = list(), retry_of = NULL,
         imported_from = NULL, note = note, error_summary = err)
  }
  read_back <- function(x) richStudio:::workspace_run_records_parse(richStudio:::workspace_run_records_json(list(x)))[[1]]
  good <- rec("aaaaaaaaaaaa", note = "kept note", err = "kept error")
  expect_true(ws6_accepts(read_back(good)))
  expect_true(ws6_accepts(read_back(rec("bbbbbbbbbbbb"))))
  expect_true(ws6_accepts(rec("cccccccccccc", note = NA_character_, err = NA_character_)))
  bad <- list(
    note_array = rec("d00000000001", note = list("a", "b")),
    note_empty = rec("d00000000002", note = list()),
    note_number = rec("d00000000003", note = 5L),
    err_object = rec("d00000000004", err = list(x = "y", z = "w")),
    err_array = rec("d00000000005", err = list("a", "b")))
  for (name in names(bad)) expect_false(ws6_accepts(read_back(bad[[name]])), info = name)

  s1 <- ws6_session("S1")
  jobs <- ws6_install(s1)
  ws6_mount(s1, ws6_state(), modules = "panel", jobs = jobs)
  shiny::withReactiveDomain(s1$s, richStudio:::workspace_run_records_reopen(
    richStudio:::workspace_run_records_json(c(list(good), unname(bad))), jobs))
  s1$s$flushReact()
  expect_identical(ws6_ids(jobs), "aaaaaaaaaaaa")
  expect_identical(ws6_shown(s1, sprintf("%d saved run record(s) could not be read and were dropped", length(bad))), 1L)
  # A fresh render each time: getOutput() raises when the render errors.
  rendered <- function() tryCatch({
    s1$s$flushReact()
    paste(as.character(s1$s$getOutput("jobs-jobs_status")$html), collapse = "")
  }, error = function(e) paste("ERROR:", conditionMessage(e)))
  html <- rendered()
  expect_false(startsWith(html, "ERROR:"))
  expect_match(html, "kept note", fixed = TRUE)

  # Defence in depth: a malformed record already in the registry does not take the status down.
  jobs$records[[length(jobs$records) + 1L]] <- ws6_internal_record(jobs, "eeeeeeeeeeee", "enrichment", "failed",
    list(species = "human"), list(list(store = "deg", label = "a", revision = 0L)), note = list("a", "b"))
  richStudio:::workspace_jobs_bump(jobs)
  html <- rendered()
  expect_false(startsWith(html, "ERROR:"))
  expect_match(html, "aaaaaaaa", fixed = TRUE)
  expect_match(html, "eeeeeeee", fixed = TRUE)
})

# ---- R37: state that outlives the session that created it (D14) --------------------

test_that("R37 D14 the queue counter and a closed session's registry survive that session's close", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  # Start without a counter so S1 creates it, as the first user of a live process does;
  # no reset follows before S2, so S2 meets the counter S1 created.
  richStudio:::workspace_job_queue_reset()
  dispatch_errors <- character()
  withCallingHandlers({
    dir <- withr::local_tempdir()
    kit <- ws6_latch_runner(dir)
    s1 <- ws6_session("S1")
    s2 <- ws6_session("S2")
    spy <- ws6_spy(list(s1, s2))
    own <- ws6_workers(1L, dir = dir)
    jobs1 <- ws6_install(s1)
    jobs2 <- ws6_install(s2)
    state1 <- ws6_add_deg(ws6_state(), "deg_a")
    state2 <- ws6_add_deg(ws6_state(), "deg_b")
    ws6_mount(s1, state1, modules = c("enrich", "panel"), runner = kit$enrichment, jobs = jobs1)
    ws6_run(s1, "deg_a")
    expect_false(is.null(ws6_queue()$version))
    id1 <- ws6_last(jobs1)$run_id
    ws6_pid(dir, ws6_key("deg_a"), list(s1), own = own)

    # The worker finishes, but no callback runs before S1 closes: they all arrive after.
    ws6_release(dir, ws6_key("deg_a"))
    f1 <- jobs1$handles[[id1]]$future
    deadline <- Sys.time() + 20
    while (!isTRUE(future::resolved(f1)) && Sys.time() < deadline) Sys.sleep(0.05)
    expect_true(future::resolved(f1))
    s1$s$close()
    expect_true(jobs1$closed)
    expect_true(ws6_until(function() identical(jobs1$in_flight, character()), list(s2)))
    ws6_settle(list(s2))
    expect_identical(ws6_state_of(jobs1, id1), "superseded")
    expect_false("deg_a_enriched" %in% shiny::isolate(names(state1$u_rrdfs)))
    # A late callback's tick, announcement and queue bump stay inert after the close.
    expect_no_error(richStudio:::workspace_jobs_bump(jobs1))
    expect_no_error(jobs1$announce("late callback"))
    expect_no_error(richStudio:::workspace_job_queue_bump())

    # S2 submits against the counter S1 created; held queued, then dispatched.
    spy$free <- function() 0
    ws6_mount(s2, state2, modules = c("enrich", "panel"), runner = kit$enrichment, jobs = jobs2)
    ws6_run(s2, "deg_b")
    expect_length(jobs2$records, 1L)
    id2 <- ws6_last(jobs2)$run_id
    expect_identical(ws6_state_of(jobs2, id2), "queued")
    expect_identical(ws6_queue_ids(), id2)
    expect_true(richStudio:::workspace_job_queue_consistent(list(jobs1, jobs2)))
    expect_match(ws6_html(s2, "jobs-jobs_status"), sprintf(ws6_msg$ahead, 0L), fixed = TRUE)
    spy$free <- NULL
    expect_true(ws6_until(function() identical(ws6_state_of(jobs2, id2), "running"), list(s2), elapse = 500))
    expect_identical(spy$factory, c("S1", "S2"))
    ws6_pid(dir, ws6_key("deg_b"), list(s2), own = own)
    ws6_release(dir, ws6_key("deg_b"))
    expect_true(ws6_until(function() identical(ws6_state_of(jobs2, id2), "succeeded"), list(s2)))
    expect_identical(ws6_shown(s2, ws6_msg$enrich_ok), 1L)
    expect_identical(ws6_queue_ids(), character())
    expect_true(richStudio:::workspace_job_queue_consistent(list(jobs1, jobs2)))
  }, message = function(m) {
    if (grepl("job dispatch error", conditionMessage(m), fixed = TRUE)) {
      dispatch_errors <<- c(dispatch_errors, conditionMessage(m))
    }
  })
  expect_identical(dispatch_errors, character())
})
