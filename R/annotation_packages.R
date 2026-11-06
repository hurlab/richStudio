# Runtime install of species annotation packages (SPEC-WS-014 M2).
#
# The app never installs in-process and never in the future pool. A Run that needs an allowlisted,
# not-yet-installed package launches the shipped supervisor (inst/annotation/annotation-install.sh)
# detached, and each session watches the supervisor's status file every 2 s. Everything that touches
# the world goes through a small seam (annotation_now, annotation_launch, ...), so the decision rules
# are pure and testable with a fixed clock.

ANNOTATION_NAME_RE <- "^[A-Za-z][A-Za-z0-9.]*$"
ANNOTATION_STALL_SECONDS <- 15
ANNOTATION_KILL_AFTER_SECONDS <- 45
ANNOTATION_SESSION_KILL_AFTER_SECONDS <- 5
ANNOTATION_BIOC_VERSION <- "3.23"

# ---- allowlist and resolver (REQ-018, REQ-019) ---------------------------------------------

annotation_allowlist_path <- function() {
  system.file("extdata", "annotation-allowlist.tsv", package = "richStudio")
}

annotation_allowlist <- function(path = annotation_allowlist_path()) {
  if (!nzchar(path) || !file.exists(path)) return(NULL)
  utils::read.delim(path, sep = "\t", quote = "", comment.char = "", colClasses = "character",
                    na.strings = character(), check.names = FALSE)
}

# (species, anntype, keytype) -> the packages it needs, or a refusal with a plain reason. Matching is
# exact against the allowlist; no value derived from user input ever becomes a package name, path, URL
# or process argument.
annotation_resolve <- function(species, anntype, keytype, allowlist = annotation_allowlist()) {
  refuse <- function(reason) list(ok = FALSE, packages = character(), reason = reason)
  one <- function(x) is.character(x) && length(x) == 1L && !is.na(x) && nzchar(x)
  if (is.null(allowlist)) return(refuse("The annotation allowlist is not available."))
  if (!one(species) || !grepl(ANNOTATION_NAME_RE, species)) return(refuse("The species is not a supported value."))
  if (!one(anntype) || !anntype %in% c("GO", "KEGG", "Reactome")) {
    return(refuse("This annotation source is not supported."))
  }
  if (!one(keytype)) keytype <- ""
  row <- allowlist[allowlist$species == species & allowlist$kind == "organism", , drop = FALSE]
  if (!nrow(row)) return(refuse(sprintf("There is no annotation package for the species '%s'.", species)))
  row <- row[1L, , drop = FALSE]
  if (!identical(row$status, "available")) {
    return(refuse(sprintf("Species '%s' cannot be analysed here: %s.", species, row$reason)))
  }
  if (identical(anntype, "Reactome") && !identical(row$reactome_supported, "yes")) {
    return(refuse(sprintf("Reactome is not available for the species '%s'.", species)))
  }
  org <- row$package
  if (!grepl(ANNOTATION_NAME_RE, org)) return(refuse("The species annotation package name is invalid."))
  pkgs <- if (identical(anntype, "Reactome")) {
    react <- allowlist$package[allowlist$kind == "reactome" & allowlist$status == "available"]
    if (!length(react) || !grepl(ANNOTATION_NAME_RE, react[[1L]])) return(refuse("Reactome data is not available."))
    c(react[[1L]], if (!identical(keytype, "ENTREZID")) org)
  } else {
    org
  }
  list(ok = TRUE, packages = pkgs, reason = "", species = species, est_mb = annotation_est_mb(allowlist, pkgs))
}

annotation_est_mb <- function(allowlist, pkgs) {
  mb <- suppressWarnings(as.numeric(allowlist$est_mb[match(pkgs, allowlist$package)]))
  sum(mb, na.rm = TRUE)
}

# ---- the library, presence and provenance ----------------------------------------------------

annotation_lib_dir <- function() sub("/+$", "", Sys.getenv("RICHSTUDIO_ANNOTATION_LIB"))

annotation_lib_leaf <- function() {
  paste0("r", R.version$major, ".", strsplit(R.version$minor, ".", fixed = TRUE)[[1L]][[1L]],
         "-bioc", ANNOTATION_BIOC_VERSION)
}

# The deploy's ownership, mode and path checks, re-run by the app (REQ-025).
annotation_lib_problems <- function(lib) {
  p <- character()
  if (!is.character(lib) || length(lib) != 1L || is.na(lib) || !nzchar(lib)) return("the annotation library path is empty")
  if (!startsWith(lib, "/")) p <- c(p, "the annotation library path is not absolute")
  if (any(strsplit(lib, "/", fixed = TRUE)[[1L]] == "..")) p <- c(p, "the annotation library path contains '..'")
  if (!identical(basename(lib), annotation_lib_leaf())) {
    p <- c(p, sprintf("the library is '%s' but this R needs '%s'", basename(lib), annotation_lib_leaf()))
  }
  if (length(p)) return(p)
  me <- Sys.info()[["effective_user"]]
  for (d in c(lib, dirname(lib))) {
    info <- file.info(d)
    if (is.na(info$isdir) || !info$isdir) return(c(p, paste("not a directory:", d)))
    link <- Sys.readlink(d)
    if (!is.na(link) && nzchar(link)) p <- c(p, paste("is a symbolic link:", d))
    if (!identical(unname(info$uname), unname(me))) p <- c(p, sprintf("%s is owned by %s, not by %s", d, info$uname, me))
    if (bitwAnd(as.integer(info$mode), 18L) != 0L) p <- c(p, paste("is group- or world-writable:", d))
  }
  p
}

# "present" only for a readable DESCRIPTION naming the package; a directory that fails that is "invalid".
annotation_package_state <- function(lib, pkg) {
  dir <- file.path(lib, pkg)
  if (!file.exists(dir)) return("missing")
  d <- tryCatch(read.dcf(file.path(dir, "DESCRIPTION"), fields = "Package"), error = function(e) NULL, warning = function(w) NULL)
  if (!is.null(d) && identical(unname(d[1L, 1L]), pkg)) "present" else "invalid"
}

annotation_status_path <- function(lib) paste0(lib, ".status")
annotation_lock_path <- function(lib) paste0(lib, ".lock")
annotation_log_path <- function(lib) paste0(lib, ".log")

ANNOTATION_STATUS_KEYS <- c("schema", "pid", "request", "packages", "current", "phase", "state", "reason",
                 "started", "deadline", "heartbeat", "updated")

# NULL for a missing or malformed status file; the supervisor writes it atomically.
annotation_read_status <- function(lib) {
  f <- annotation_status_path(lib)
  if (!file.exists(f)) return(NULL)
  lines <- tryCatch(readLines(f, warn = FALSE), error = function(e) character())
  kv <- strsplit(lines, "=", fixed = TRUE)
  if (!length(kv) || !all(vapply(kv, length, 1L) >= 1L)) return(NULL)
  st <- stats::setNames(lapply(kv, function(x) paste(x[-1L], collapse = "=")), vapply(kv, `[[`, "", 1L))
  if (!all(ANNOTATION_STATUS_KEYS %in% names(st)) || !identical(st$schema, "1")) return(NULL)
  if (!st$state %in% c("running", "completed", "failed", "stopped")) return(NULL)
  st
}

# Name and installed version of every annotation package a run needs, under annotation$packages
# (REQ-026). Empty when none is needed or none is installed.
annotation_provenance_packages <- function(species, anntype, keytype) {
  res <- annotation_resolve(species, anntype, keytype)
  if (!isTRUE(res$ok)) return(list())
  out <- list()
  for (p in res$packages) {
    v <- tryCatch(as.character(utils::packageVersion(p)), error = function(e) NA_character_)
    if (!is.na(v)) out[[p]] <- v
  }
  out
}

# ---- failure vocabulary (REQ-022) -----------------------------------------------------------

annotation_reason_message <- function(reason) {
  switch(
    reason,
    no_network = "The annotation download could not reach the Bioconductor server.",
    timed_out = "The annotation installation took too long and was stopped.",
    checksum_mismatch = "The downloaded annotation package did not match its published checksum.",
    not_enough_disk = "There is not enough free disk space to install the annotation package.",
    dependency_missing = "A package the annotation package depends on is missing.",
    entry_invalid = "An annotation package folder exists but is not valid.",
    index_no_md5 = "The Bioconductor index lists no checksum for the annotation package.",
    unavailable = "This annotation package is not available from Bioconductor.",
    interrupted = "The annotation installation was interrupted (the service may have restarted).",
    stopped = "The annotation installation was stopped.",
    unsafe_library = "The annotation library failed its safety checks, so nothing was installed.",
    "The annotation installation failed for an unexpected reason."
  )
}

# Reasons for which the manual BiocManager command helps.
annotation_reason_has_command <- function(reason) {
  !reason %in% c("entry_invalid", "unavailable", "stopped")
}

# A structured failure: the reason code and message plus the manual command, never parsed from text.
annotation_failure <- function(reason, packages, detail = NULL) {
  cmd <- if (annotation_reason_has_command(reason) && length(packages)) {
    if (length(packages) == 1L) sprintf("BiocManager::install(\"%s\")", packages)
    else sprintf("BiocManager::install(c(%s))", paste0("\"", packages, "\"", collapse = ", "))
  }
  list(reason = reason, message = paste0(annotation_reason_message(reason), if (!is.null(detail)) paste0(" ", detail)),
       command = cmd)
}

# ---- seams: everything that touches the process table or the clock ----------------------------

annotation_now <- function() Sys.time()

annotation_proc_file <- function(pid, name) file.path("/proc", as.character(pid), name)

annotation_pid_is_installer <- function(pid) {
  pid <- suppressWarnings(as.integer(pid))
  if (is.na(pid) || pid <= 1L) return(FALSE)
  f <- annotation_proc_file(pid, "cmdline")
  raw <- tryCatch(readBin(f, "raw", 65536L), error = function(e) raw())
  length(raw) > 0L && grepl("annotation-install.sh", rawToChar(raw[raw != as.raw(0)]), fixed = TRUE)
}

annotation_proc_stat <- function(pid) {
  s <- tryCatch(readLines(annotation_proc_file(pid, "stat"), warn = FALSE), error = function(e) character())
  if (!length(s)) return(NULL)
  strsplit(sub("^.*\\) ", "", s[[1L]]), " ", fixed = TRUE)[[1L]]
}

# Epoch seconds at which the process started; NA when unreadable.
annotation_proc_start_epoch <- function(pid) {
  f <- annotation_proc_stat(pid)
  if (is.null(f) || length(f) < 20L) return(NA_real_)
  btime <- tryCatch(as.numeric(sub("^btime ", "", grep("^btime ", readLines("/proc/stat", warn = FALSE), value = TRUE))), error = function(e) NA_real_)
  as.numeric(f[[20L]]) / 100 + btime
}

annotation_proc_session <- function(pid) {
  f <- annotation_proc_stat(pid)
  if (is.null(f) || length(f) < 4L) NA_integer_ else suppressWarnings(as.integer(f[[4L]]))
}

annotation_signal <- function(pid, signal) tools::pskill(pid, signal)

annotation_kill_session <- function(sid) {
  if (!is.na(sid) && sid > 1L) system2("pkill", c("-KILL", "-s", as.character(sid)), stdout = FALSE, stderr = FALSE)
  invisible(NULL)
}

annotation_lock_free <- function(lib) {
  lock <- annotation_lock_path(lib)
  if (!file.exists(lock)) return(TRUE)
  flock <- Sys.which("flock")
  if (!nzchar(flock)) return(FALSE)
  identical(suppressWarnings(system2(flock, c("-n", shQuote(lock), "true"), stdout = FALSE, stderr = FALSE)), 0L)
}

annotation_supervisor_path <- function() {
  system.file("annotation", "annotation-install.sh", package = "richStudio")
}

# Detached launch: setsid bash annotation-install.sh <packages>, stdin from /dev/null, output appended to
# <parent>/<leaf>.log, with an explicit environment so a different PATH under shiny-server cannot matter.
# Returns TRUE when the process was started (not that it will succeed: the status file decides).
annotation_launch <- function(lib, packages, token) {
  sup <- annotation_supervisor_path()
  setsid <- Sys.which("setsid")
  if (!nzchar(setsid) || !nzchar(sup) || !all(grepl(ANNOTATION_NAME_RE, packages)) ||
      !grepl("^[A-Za-z0-9]{8,32}$", token)) {
    return(FALSE)
  }
  libs <- Sys.getenv("R_LIBS_USER")
  if (!nzchar(libs)) libs <- paste(.libPaths(), collapse = ":")
  env <- c(RICHSTUDIO_ANNOTATION_LIB = lib, R_LIBS_USER = libs,
           RICHSTUDIO_RSCRIPT = file.path(R.home("bin"), "Rscript"), RICHSTUDIO_ANNOTATION_REQUEST = token,
           PATH = "/usr/local/bin:/usr/bin:/bin")
  # The test-only variables are forwarded only when the app's own environment already has both; the
  # deploy verifies that they never do on the live host.
  for (v in c("RICHSTUDIO_ANNOTATION_TEST_MODE", "RICHSTUDIO_ANNOTATION_TEST_CONFIG")) {
    if (nzchar(Sys.getenv(v))) env[[v]] <- Sys.getenv(v)
  }
  cmd <- paste0(paste0("env ", paste0(names(env), "=", shQuote(env), collapse = " ")), " ",
                shQuote(setsid), " bash ", shQuote(sup), " ", paste(shQuote(packages), collapse = " "),
                " < /dev/null >> ", shQuote(annotation_log_path(lib)), " 2>&1")
  ok <- tryCatch({ system(cmd, wait = FALSE, ignore.stdout = FALSE, ignore.stderr = FALSE); TRUE }, error = function(e) FALSE)
  ok
}

annotation_deps <- function() {
  list(now = annotation_now, status = annotation_read_status, pid_live = annotation_pid_is_installer,
       lock_free = annotation_lock_free, launch = annotation_launch, state = annotation_package_state,
       start_epoch = annotation_proc_start_epoch, session_of = annotation_proc_session,
       signal = annotation_signal, kill_session = annotation_kill_session)
}

# ---- the decision rules (REQ-030): strict first match ----------------------------------------------

# req: list(token, launched_at, waited). Returns list(action, phase, reason). `present` is TRUE when the
# resolver finds every needed package; `status` is the parsed status file or NULL.
annotation_install_decide <- function(req, present, status, now, pid_live, lock_free) {
  if (isTRUE(present)) return(list(action = "continue"))                                       # 1
  own <- !is.null(status) && identical(status$request, req$token)
  if (own && identical(status$state, "running")) {
    if (isTRUE(pid_live(status$pid))) return(list(action = "installing", phase = status$phase))  # 2
    if (!isTRUE(lock_free())) return(list(action = "waiting_previous"))                            # 3
    return(list(action = "fail", reason = "interrupted"))
  }
  if (own && status$state %in% c("failed", "stopped")) {                                           # 4
    return(list(action = "fail", reason = if (identical(status$state, "stopped")) "stopped" else
      if (nzchar(status$reason)) status$reason else "internal_error"))
  }
  if (own && identical(status$state, "completed")) return(list(action = "fail", reason = "internal_error"))  # 5
  if (!is.null(status) && !own && identical(status$state, "running") && isTRUE(pid_live(status$pid))) {
    return(list(action = "waiting_other"))                                                       # 6
  }
  if (is.null(req$launched_at) || isTRUE(req$waited)) return(list(action = "launch"))              # 7
  if (as.numeric(difftime(now, req$launched_at, units = "secs")) < ANNOTATION_STALL_SECONDS) {
    return(list(action = "starting"))                                                              # 8
  }
  list(action = "fail", reason = "internal_error", detail = "The installer did not start.")        # 9
}

annotation_phase_text <- function(phase) {
  switch(phase, starting = , preparing = "Queued", downloading = "Downloading", installing = "Installing",
         validating = , finalizing = "Verifying", done = "Done", "Installing")
}

# ---- session request records ------------------------------------------------------------------------

annotation_new_token <- function() paste(sample(c(LETTERS, letters, 0:9), 16L, replace = TRUE), collapse = "")

annotation_request_new <- function(species, anntype, keytype, packages, est_mb, start_job, token = annotation_new_token()) {
  list(id = token, token = token, species = species, anntype = anntype, keytype = keytype, packages = packages,
       est_mb = est_mb, start_job = start_job, state = "active", text = "Queued", failure = NULL,
       launched_at = NULL, waited = FALSE, stop_at = NULL, kill_at = NULL, stop_sid = NA_integer_)
}

annotation_install_records <- function(jobs) shiny::isolate(jobs$installs())

annotation_install_update <- function(jobs, id, values) {
  recs <- shiny::isolate(jobs$installs())
  for (i in seq_along(recs)) {
    if (identical(recs[[i]]$id, id)) {
      for (k in names(values)) recs[[i]][k] <- list(values[[k]])
      jobs$installs(recs)
      return(invisible(TRUE))
    }
  }
  invisible(FALSE)
}

annotation_install_label <- function(rec) {
  sprintf("%s (%s)", paste(rec$packages, collapse = ", "), rec$species)
}

annotation_install_announce <- function(jobs, rec, text) {
  jobs$announce(sprintf("Annotation install %s: %s", annotation_install_label(rec), text))
}

# Set the visible text only when it changes; one announcement per change.
annotation_install_set_text <- function(jobs, rec, text) {
  if (!identical(rec$text, text)) {
    annotation_install_update(jobs, rec$id, list(text = text))
    annotation_install_announce(jobs, rec, text)
  }
}

annotation_install_fail <- function(jobs, rec, reason, detail = NULL, notify = TRUE) {
  failure <- annotation_failure(reason, rec$packages, detail)
  annotation_install_update(jobs, rec$id, list(state = "failed", text = "Failed", failure = failure, stop_at = NULL))
  annotation_install_announce(jobs, rec, paste("Failed.", failure$message))
  if (notify) {
    shiny::showNotification(paste("Annotation install failed:", failure$message), type = "warning", duration = 10)
  }
  invisible(failure)
}

# ---- the Run gate (REQ-019, REQ-023, REQ-025) ------------------------------------------------------

# Called by the Run observer after review, with `start_job` the closure that admits the enrichment job.
# Nothing missing (or no annotation library configured): the run starts exactly as before. Refused: a plain
# reason, no job, no process. Missing and available: a retained request, an "installing" row, one launch.
annotation_install_gate <- function(jobs, session, species, anntype, keytype, start_job, deps = annotation_deps()) {
  lib <- annotation_lib_dir()
  if (!nzchar(lib)) {
    start_job()
    return(invisible("started"))
  }
  res <- annotation_resolve(species, anntype, keytype)
  if (!isTRUE(res$ok)) {
    shiny::showNotification(paste("Run not started.", res$reason), type = "warning", duration = 10)
    return(invisible("refused"))
  }
  states <- vapply(res$packages, function(p) deps$state(lib, p), character(1))
  if (all(states == "present")) {
    start_job()
    return(invisible("started"))
  }
  # Another request for the same packages: never a second install.
  open <- Filter(function(r) identical(r$packages, res$packages) && r$state %in% c("active", "stopping"),
                 annotation_install_records(jobs))
  if (length(open)) {
    shiny::showNotification("These annotation packages are already being installed.", type = "message")
    return(invisible("duplicate"))
  }
  rec <- annotation_request_new(species, anntype, keytype, res$packages, res$est_mb, start_job)
  jobs$installs(c(shiny::isolate(jobs$installs()), list(rec)))
  bad <- annotation_lib_problems(lib)
  if (any(states == "invalid")) {
    path <- file.path(lib, res$packages[which(states == "invalid")[[1L]]])
    annotation_install_fail(jobs, rec, "entry_invalid", sprintf("Ask the host owner to remove %s.", path))
  } else if (length(bad)) {
    annotation_install_fail(jobs, rec, "unsafe_library", paste0("(", paste(bad, collapse = "; "), ")"))
  } else {
    annotation_install_announce(jobs, rec, "Queued")
    shiny::showNotification(
      sprintf("Installing the %s annotation (about %s MB); the analysis starts when it is ready.", species, round(res$est_mb)),
      type = "message")
    annotation_install_observe(jobs, session, deps)
  }
  invisible("pending")
}

# One polling observer per session registry, every 2 s while any request is active.
annotation_install_observe <- function(jobs, session, deps = annotation_deps()) {
  if (isTRUE(jobs$install_observer)) return(invisible(NULL))
  jobs$install_observer <- TRUE
  shiny::withReactiveDomain(jobs$session, {
    shiny::observe({
      recs <- jobs$installs()
      if (!any(vapply(recs, function(r) r$state %in% c("active", "stopping"), logical(1)))) {
        return(invisible(NULL))
      }
      shiny::invalidateLater(2000)
      shiny::isolate(annotation_install_poll(jobs, deps))
    })
  })
  invisible(NULL)
}

# One evaluation of every active request (no sleep, no future).
annotation_install_poll <- function(jobs, deps = annotation_deps()) {
  lib <- annotation_lib_dir()
  now <- deps$now()
  status <- deps$status(lib)
  for (rec in annotation_install_records(jobs)) {
    if (!rec$state %in% c("active", "stopping")) next
    states <- vapply(rec$packages, function(p) deps$state(lib, p), character(1))
    if (any(states == "invalid")) {
      annotation_install_fail(jobs, rec, "entry_invalid",
                              sprintf("Ask the host owner to remove %s.", file.path(lib, rec$packages[which(states == "invalid")[[1L]]])))
      next
    }
    if (identical(rec$state, "stopping")) {
      annotation_install_escalate(jobs, rec, status, now, deps)
    }
    d <- annotation_install_decide(rec, all(states == "present"), status, now, deps$pid_live,
                                   function() deps$lock_free(lib))
    switch(
      d$action,
      continue = {
        annotation_install_update(jobs, rec$id, list(state = "done", text = "Done", stop_at = NULL))
        annotation_install_announce(jobs, rec, "Done")
        tryCatch(rec$start_job(), error = function(e) {
          shiny::showNotification(paste("The analysis could not start:", conditionMessage(e)), type = "warning")
        })
      },
      installing = annotation_install_set_text(jobs, rec, annotation_phase_text(d$phase)),
      waiting_previous = annotation_install_set_text(jobs, rec, "Waiting for a previous installer to finish"),
      waiting_other = {
        annotation_install_update(jobs, rec$id, list(waited = TRUE))
        annotation_install_set_text(jobs, rec, "Waiting for another installation")
      },
      launch = {
        bad <- annotation_lib_problems(lib)
        if (length(bad)) {
          annotation_install_fail(jobs, rec, "unsafe_library", paste0("(", paste(bad, collapse = "; "), ")"))
        } else {
          deps$launch(lib, rec$packages, rec$token)
          annotation_install_update(jobs, rec$id, list(launched_at = now, waited = FALSE))
          annotation_install_set_text(jobs, rec, "Starting")
        }
      },
      starting = annotation_install_set_text(jobs, rec, "Starting"),
      fail = annotation_install_fail(jobs, rec, d$reason, d$detail),
      NULL
    )
  }
  invisible(NULL)
}

# ---- Stop, Retry, Dismiss (REQ-023) ---------------------------------------------------------------------

# Stop is offered only to the session whose token equals the status token while the installer runs.
annotation_stop_offered <- function(rec, status) {
  !is.null(status) && rec$state %in% c("active", "stopping") && identical(status$request, rec$token) &&
    identical(status$state, "running")
}

# The pid must be an installer (its cmdline names annotation-install.sh) that started no later than the
# status says it did; otherwise nothing is signalled.
annotation_verify_installer <- function(status, deps = annotation_deps()) {
  pid <- suppressWarnings(as.integer(status$pid))
  if (is.na(pid) || !isTRUE(deps$pid_live(pid))) return(FALSE)
  start <- deps$start_epoch(pid)
  started <- suppressWarnings(as.numeric(status$started))
  !is.na(start) && !is.na(started) && start <= started + 1
}

annotation_install_stop <- function(jobs, id, deps = annotation_deps()) {
  rec <- Filter(function(r) identical(r$id, id), annotation_install_records(jobs))
  if (!length(rec)) return(invisible(FALSE))
  rec <- rec[[1L]]
  status <- deps$status(annotation_lib_dir())
  if (!annotation_stop_offered(rec, status) || !annotation_verify_installer(status, deps)) return(invisible(FALSE))
  pid <- as.integer(status$pid)
  sid <- deps$session_of(pid)
  deps$signal(pid, tools::SIGTERM)
  annotation_install_update(jobs, id, list(state = "stopping", text = "Stopping", stop_at = deps$now(), stop_sid = sid))
  annotation_install_announce(jobs, rec, "Stopping")
  invisible(TRUE)
}

# 45 s after SIGTERM, if the status is still running: repeat the verification, then SIGKILL the supervisor;
# 5 s later kill the session read before the first signal.
annotation_install_escalate <- function(jobs, rec, status, now, deps) {
  if (is.null(status) || !identical(status$state, "running") || is.null(rec$stop_at)) return(invisible(FALSE))
  waited <- as.numeric(difftime(now, rec$stop_at, units = "secs"))
  if (is.null(rec$kill_at) && waited >= ANNOTATION_KILL_AFTER_SECONDS) {
    if (annotation_verify_installer(status, deps)) {
      deps$signal(as.integer(status$pid), tools::SIGKILL)
      annotation_install_update(jobs, rec$id, list(kill_at = now))
    }
  } else if (!is.null(rec$kill_at) &&
             as.numeric(difftime(now, rec$kill_at, units = "secs")) >= ANNOTATION_SESSION_KILL_AFTER_SECONDS) {
    deps$kill_session(rec$stop_sid)
    annotation_install_update(jobs, rec$id, list(kill_at = now + 1e9))
  }
  invisible(TRUE)
}

# Retry: a new token and one launch; the retained run request continues when the packages are present.
annotation_install_retry <- function(jobs, id) {
  rec <- Filter(function(r) identical(r$id, id), annotation_install_records(jobs))
  if (!length(rec) || !identical(rec[[1L]]$state, "failed")) return(invisible(FALSE))
  rec <- rec[[1L]]
  annotation_install_update(jobs, id, list(token = annotation_new_token(), state = "active", text = "Queued", failure = NULL,
                                           launched_at = NULL, waited = FALSE, stop_at = NULL, kill_at = NULL))
  annotation_install_announce(jobs, rec, "Queued")
  invisible(TRUE)
}

# Dismiss discards the retained request and clears the row.
annotation_install_dismiss <- function(jobs, id) {
  recs <- annotation_install_records(jobs)
  jobs$installs(Filter(function(r) !identical(r$id, id), recs))
  invisible(TRUE)
}

annotation_install_action <- function(jobs, value, deps = annotation_deps()) {
  id <- if (is.list(value) && is.character(value$run) && length(value$run) == 1L) value$run else return(invisible(FALSE))
  switch(sub("^install_", "", value$action),
         stop = annotation_install_stop(jobs, id, deps),
         retry = annotation_install_retry(jobs, id),
         dismiss = annotation_install_dismiss(jobs, id),
         invisible(FALSE))
}

# ---- species choices (REQ-019, OD-6) -----------------------------------------------------------------------

# The dropdown offers every available species; one that is not installed carries an "installs on first
# use" hint. Unavailable species are not offered. Values are the species keys.
annotation_species_choices <- function(order = NULL, allowlist = annotation_allowlist(), lib = annotation_lib_dir()) {
  if (is.null(allowlist)) return(order)
  org <- allowlist[allowlist$kind == "organism" & allowlist$status == "available", , drop = FALSE]
  # `order` fixes the familiar order; any other available allowlist species follows it.
  if (!is.null(order)) org <- org[order(match(org$species, order), na.last = TRUE), , drop = FALSE]
  labels <- vapply(seq_len(nrow(org)), function(i) {
    installed <- !nzchar(lib) || identical(org$preinstall[[i]], "yes") ||
      identical(annotation_package_state(lib, org$package[[i]]), "present")
    if (installed) org$species[[i]]
    else sprintf("%s (installs on first use, about %s MB)", org$species[[i]], org$est_mb[[i]])
  }, character(1))
  stats::setNames(org$species, labels)
}
