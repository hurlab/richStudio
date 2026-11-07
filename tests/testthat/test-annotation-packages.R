# SPEC-WS-014 M2: resolver, install gate, polling rules, Stop/Retry/Dismiss, provenance.
# Pure rules run with a fixed clock and seams; the supervisor and the future worker are exercised for real in
# the integration test at the end (NOT_CRAN).

fake_jobs <- function() {
  jobs <- new.env(parent = emptyenv())
  jobs$installs <- shiny::reactiveVal(list())
  jobs$announce <- shiny::reactiveVal("")
  jobs$install_observer <- TRUE
  jobs$session <- NULL
  jobs
}
recs <- function(jobs) shiny::isolate(jobs$installs())
announced <- function(jobs) shiny::isolate(jobs$announce())

collect_notifications <- function(env = parent.frame()) {
  box <- new.env()
  box$notes <- list()
  testthat::local_mocked_bindings(
    showNotification = function(ui, ..., type = "default") { box$notes[[length(box$notes) + 1L]] <- list(text = as.character(ui), type = type); invisible(NULL) },
    .package = "shiny", .env = env)
  box
}

# Seams with a mutable clock and spies.
fake_deps <- function(box = new.env(), states = list(), status = NULL, pid_live = function(pid) FALSE, lock_free = TRUE) {
  box$now <- as.POSIXct("2026-11-06 12:00:00", tz = "UTC")
  box$launches <- list()
  box$signals <- list()
  box$sessions_killed <- c()
  box$status <- status
  box$states <- states
  list(
    now = function() box$now,
    status = function(lib) box$status,
    pid_live = pid_live,
    lock_free = function(lib) lock_free,
    launch = function(lib, packages, token) { box$launches[[length(box$launches) + 1L]] <- list(packages = packages, token = token); TRUE },
    state = function(lib, pkg) if (!is.null(box$states[[pkg]])) box$states[[pkg]] else "missing",
    start_epoch = function(pid) as.numeric(box$now) - 100,
    session_of = function(pid) 4242L,
    signal = function(pid, signal) { box$signals[[length(box$signals) + 1L]] <- list(pid = pid, signal = signal); invisible(NULL) },
    kill_session = function(sid) box$sessions_killed <- c(box$sessions_killed, sid))
}

status_for <- function(token, state = "running", pid = "4242", phase = "downloading", reason = "", started = NULL) {
  list(schema = "1", pid = pid, request = token, packages = "org.Hs.eg.db", current = "org.Hs.eg.db", phase = phase,
       state = state, reason = reason, started = as.character(started %||% as.numeric(Sys.time()) - 10),
       deadline = "0", heartbeat = "0", updated = "0")
}

# ---- AC-018 resolver -----------------------------------------------------------------------------------

test_that("AC-018 the resolver maps each allowlisted request to the packages the design table names", {
  al <- annotation_allowlist()
  org <- al[al$kind == "organism" & al$status == "available", ]
  for (i in seq_len(nrow(org))) {
    sp <- org$species[[i]]
    expect_identical(annotation_resolve(sp, "GO", "SYMBOL")$packages, org$package[[i]])
    expect_identical(annotation_resolve(sp, "KEGG", "SYMBOL")$packages, org$package[[i]])
    if (identical(org$reactome_supported[[i]], "yes")) {
      expect_identical(annotation_resolve(sp, "Reactome", "SYMBOL")$packages, c("reactome.db", org$package[[i]]))
      expect_identical(annotation_resolve(sp, "Reactome", "ENTREZID")$packages, "reactome.db")
    } else {
      expect_false(annotation_resolve(sp, "Reactome", "SYMBOL")$ok)
    }
  }
})

test_that("AC-018 anything not on the allowlist is refused and starts no process", {
  # the launcher itself refuses a name or token that fails the pattern (before it is mocked below)
  injected <- paste0("org.Hs.eg.db; rm -rf", " /")
  expect_false(annotation_launch("/nonexistent/lib", injected, "abcdefgh12345678"))
  expect_false(annotation_launch("/nonexistent/lib", "org.Hs.eg.db", "bad token"))
  launches <- 0L
  testthat::local_mocked_bindings(annotation_launch = function(...) { launches <<- launches + 1L; TRUE })
  for (bad in c("../x", injected, "org.Xx.eg.db", "https://evil.example/x", "")) {
    r <- annotation_resolve(bad, "GO", "SYMBOL")
    expect_false(r$ok, info = bad)
    expect_length(r$packages, 0L)
  }
  expect_false(annotation_resolve("human", "KEGGM", "SYMBOL")$ok)
  expect_false(annotation_resolve("human", "GO; x", "SYMBOL")$ok)
  expect_identical(launches, 0L)
})

# ---- AC-019 allowlist against richR and the dropdown ---------------------------------------------------------

test_that("AC-019 the allowlist matches the pinned richR species table and the dropdown offers only available species", {
  skip_if_not_installed("richR")
  st <- richR:::.species_table()
  al <- annotation_allowlist()
  org <- al[al$kind == "organism", ]
  for (i in seq_len(nrow(org))) {
    sp <- org$species[[i]]
    if (!sp %in% st$species) {
      expect_identical(org$status[[i]], "unavailable", info = sp)
      next
    }
    row <- st[st$species == sp, ]
    if (identical(org$status[[i]], "available")) {
      expect_identical(org$package[[i]], row$dbname, info = sp)
      expect_identical(org$reactome_supported[[i]], if (is.na(row$reactome)) "no" else "yes", info = sp)
    }
  }
  choices <- annotation_species_choices(c("human", "mouse", "sco", "toxoplasma", "yeast"), al, lib = "")
  # the given order comes first; every other available species follows; unavailable ones never appear
  expect_identical(unname(choices)[1:3], c("human", "mouse", "yeast"))
  expect_setequal(unname(choices), al$species[al$kind == "organism" & al$status == "available"])
  expect_false(any(c("sco", "toxoplasma", "streptomyces", "ecsakai") %in% choices))
  hinted <- annotation_species_choices(c("human", "yeast"), al, lib = withr::local_tempdir())
  expect_identical(unname(hinted)[1:2], c("human", "yeast"))
  expect_match(names(hinted)[[2L]], "installs on first use, about 15 MB")
  expect_identical(names(hinted)[[1L]], "human")
})

test_that("AC-019 a restored unavailable species or an unsupported Reactome request is refused before any job", {
  lib <- withr::local_tempdir()
  withr::local_envvar(RICHSTUDIO_ANNOTATION_LIB = lib)
  box <- collect_notifications()
  jobs <- fake_jobs()
  started <- 0L
  for (args in list(c("sco", "GO"), c("anopheles", "Reactome"), c("ecoli", "Reactome"), c("toxoplasma", "KEGG"))) {
    res <- annotation_install_gate(jobs, NULL, args[[1L]], args[[2L]], "SYMBOL", function() started <<- started + 1L, fake_deps())
    expect_identical(res, "refused", info = paste(args, collapse = " "))
  }
  expect_identical(started, 0L)
  expect_length(recs(jobs), 0L)
  expect_length(box$notes, 4L)
})

# ---- the gate --------------------------------------------------------------------------------------------------

test_that("nothing missing, or no annotation library configured, starts the job exactly as before", {
  started <- 0L
  go <- function() started <<- started + 1L
  jobs <- fake_jobs()
  withr::local_envvar(RICHSTUDIO_ANNOTATION_LIB = "")
  expect_identical(annotation_install_gate(jobs, NULL, "yeast", "GO", "SYMBOL", go, fake_deps()), "started")
  lib <- withr::local_tempdir()
  withr::local_envvar(RICHSTUDIO_ANNOTATION_LIB = lib)
  deps <- fake_deps(states = list(org.Sc.sgd.db = "present"))
  expect_identical(annotation_install_gate(jobs, NULL, "yeast", "GO", "SYMBOL", go, deps), "started")
  expect_identical(started, 2L)
  expect_length(recs(jobs), 0L)
})

test_that("a second Run for the same packages does not start a second install", {
  w <- apk_world()
  withr::local_envvar(RICHSTUDIO_ANNOTATION_LIB = w$lib)
  box <- collect_notifications()
  jobs <- fake_jobs()
  box <- new.env()
  deps <- fake_deps(box)
  expect_identical(annotation_install_gate(jobs, NULL, "yeast", "GO", "SYMBOL", function() NULL, deps), "pending")
  expect_identical(annotation_install_gate(jobs, NULL, "yeast", "GO", "SYMBOL", function() NULL, deps), "duplicate")
  expect_length(recs(jobs), 1L)
  annotation_install_poll(jobs, deps)
  annotation_install_poll(jobs, deps)
  expect_length(box$launches, 1L)
})

test_that("an invalid entry is reported with its path and never deleted", {
  w <- apk_world()
  withr::local_envvar(RICHSTUDIO_ANNOTATION_LIB = w$lib)
  collect_notifications()
  dir.create(file.path(w$lib, "org.Sc.sgd.db"))
  jobs <- fake_jobs()
  box <- new.env()
  deps <- fake_deps(box, states = list(org.Sc.sgd.db = "invalid"))
  annotation_install_gate(jobs, NULL, "yeast", "GO", "SYMBOL", function() NULL, deps)
  rec <- recs(jobs)[[1L]]
  expect_identical(rec$failure$reason, "entry_invalid")
  expect_match(rec$failure$message, file.path(w$lib, "org.Sc.sgd.db"), fixed = TRUE)
  expect_true(dir.exists(file.path(w$lib, "org.Sc.sgd.db")))
  expect_length(box$launches, 0L)
})

# ---- AC-025 library safety ------------------------------------------------------------------------------------------

test_that("AC-025 an unsafe annotation library shows the warning and the manual command and starts no installer", {
  base_dir <- withr::local_tempdir()
  parent <- file.path(base_dir, "annotation")
  dir.create(parent, mode = "0755"); Sys.chmod(parent, "0755")
  leaf <- annotation_lib_leaf()
  good <- file.path(parent, leaf)
  dir.create(good, mode = "0755"); Sys.chmod(good, "0755")
  expect_identical(annotation_lib_problems(good), character())
  wrong <- file.path(parent, "r3.9-bioc3.1"); dir.create(wrong)
  link <- file.path(parent, "link"); file.symlink(good, link)
  world <- file.path(parent, paste0("x", leaf)); dir.create(world); Sys.chmod(world, "0777", use_umask = FALSE)
  cases <- c("relative/path", paste0(good, "/../", leaf), wrong, world, link)
  for (lib in cases) expect_gt(length(annotation_lib_problems(lib)), 0L, label = lib)
  mode777 <- file.path(parent, "m"); dir.create(mode777); Sys.chmod(mode777, "0777", use_umask = FALSE)
  expect_match(paste(annotation_lib_problems(file.path(mode777, leaf)), collapse = " "), "not a directory|writable|r\\d")
  # the gate: a 0777 library
  bad_parent <- file.path(base_dir, "annotation2"); dir.create(bad_parent); Sys.chmod(bad_parent, "0755")
  bad_lib <- file.path(bad_parent, leaf); dir.create(bad_lib); Sys.chmod(bad_lib, "0777", use_umask = FALSE)
  withr::local_envvar(RICHSTUDIO_ANNOTATION_LIB = bad_lib)
  collect_notifications()
  jobs <- fake_jobs()
  box <- new.env()
  deps <- fake_deps(box)
  before <- .libPaths()
  annotation_install_gate(jobs, NULL, "yeast", "GO", "SYMBOL", function() NULL, deps)
  annotation_install_poll(jobs, deps)
  rec <- recs(jobs)[[1L]]
  expect_identical(rec$failure$reason, "unsafe_library")
  expect_identical(rec$failure$command, "BiocManager::install(\"org.Sc.sgd.db\")")
  expect_length(box$launches, 0L)
  expect_identical(.libPaths(), before)
})

# ---- AC-030 the decision rules ----------------------------------------------------------------------------------------

decide <- function(req = list(token = "TOKEN12345678AB", launched_at = NULL, waited = FALSE), present = FALSE, status = NULL,
                   pid_live = FALSE, lock_free = TRUE, now = as.POSIXct("2026-11-06 12:00:00", tz = "UTC")) {
  annotation_install_decide(req, present, status, now, function(pid) pid_live, function() lock_free)
}

test_that("AC-030 exactly the first matching rule applies", {
  tok <- "TOKEN12345678AB"
  own <- function(...) status_for(tok, ...)
  other <- function(...) status_for("OTHERTOKEN123456", ...)
  t0 <- as.POSIXct("2026-11-06 12:00:00", tz = "UTC")
  # 1: present beats every status, including another token's failure
  expect_identical(decide(present = TRUE, status = other(state = "failed"))$action, "continue")
  expect_identical(decide(present = TRUE, status = own(state = "running"), pid_live = TRUE)$action, "continue")
  # 2
  expect_identical(decide(status = own(phase = "installing"), pid_live = TRUE)$phase, "installing")
  expect_identical(decide(status = own(), pid_live = TRUE)$action, "installing")
  # 3
  expect_identical(decide(status = own(), pid_live = FALSE, lock_free = FALSE)$action, "waiting_previous")
  d <- decide(status = own(), pid_live = FALSE, lock_free = TRUE)
  expect_identical(c(d$action, d$reason), c("fail", "interrupted"))
  # 4
  d <- decide(status = own(state = "failed", reason = "no_network"))
  expect_identical(c(d$action, d$reason), c("fail", "no_network"))
  expect_identical(decide(status = own(state = "stopped"))$reason, "stopped")
  # 5
  expect_identical(decide(status = own(state = "completed"))$reason, "internal_error")
  # 6
  expect_identical(decide(status = other(), pid_live = TRUE)$action, "waiting_other")
  # 7: another token that is not live and not running -> launch (never launched)
  expect_identical(decide(status = other(state = "failed"))$action, "launch")
  expect_identical(decide(status = NULL)$action, "launch")
  expect_identical(decide(status = other(), pid_live = FALSE)$action, "launch")
  waited <- list(token = tok, launched_at = t0, waited = TRUE)
  expect_identical(decide(req = waited, status = other(state = "completed"))$action, "launch")
  # 8 and 9
  launched <- list(token = tok, launched_at = t0, waited = FALSE)
  expect_identical(decide(req = launched, now = t0 + 14)$action, "starting")
  d <- decide(req = launched, now = t0 + 15)
  expect_identical(c(d$action, d$reason), c("fail", "internal_error"))
})

test_that("AC-030 over 100 polls with a launcher that writes no status there is exactly one launch and a failure at 15 s", {
  w <- apk_world()
  withr::local_envvar(RICHSTUDIO_ANNOTATION_LIB = w$lib)
  collect_notifications()
  jobs <- fake_jobs()
  box <- new.env()
  deps <- fake_deps(box)
  annotation_install_gate(jobs, NULL, "yeast", "GO", "SYMBOL", function() NULL, deps)
  t0 <- box$now
  failed_at <- NULL
  for (i in 0:99) {
    box$now <- t0 + 2 * i
    annotation_install_poll(jobs, deps)
    if (is.null(failed_at) && identical(recs(jobs)[[1L]]$state, "failed")) failed_at <- 2 * i
  }
  expect_length(box$launches, 1L)
  expect_identical(failed_at, 16)           # first poll at or after the 15 s mark (polls are 2 s apart)
  rec <- recs(jobs)[[1L]]
  expect_identical(rec$failure$reason, "internal_error")
  expect_match(rec$failure$message, "did not start")
})

test_that("AC-030 a foreign install that turns terminal with the package still missing allows exactly one more launch", {
  w <- apk_world()
  withr::local_envvar(RICHSTUDIO_ANNOTATION_LIB = w$lib)
  collect_notifications()
  jobs <- fake_jobs()
  box <- new.env()
  deps <- fake_deps(box, status = status_for("OTHERTOKEN123456"), pid_live = function(pid) TRUE)
  annotation_install_gate(jobs, NULL, "yeast", "GO", "SYMBOL", function() NULL, deps)
  for (i in 1:5) { box$now <- box$now + 2; annotation_install_poll(jobs, deps) }
  expect_length(box$launches, 0L)
  expect_identical(recs(jobs)[[1L]]$text, "Waiting for another installation")
  box$status <- status_for("OTHERTOKEN123456", state = "completed")
  for (i in 1:5) { box$now <- box$now + 2; annotation_install_poll(jobs, deps) }
  expect_length(box$launches, 1L)
})

test_that("AC-030 the polling observer creates no future and no sleep and uses invalidateLater(2000)", {
  for (f in list(annotation_install_poll, annotation_install_decide, annotation_install_gate)) {
    nm <- all.names(body(f))
    expect_false(any(c("Sys.sleep", "future", "workspace_jobs_future") %in% nm))
  }
  expect_match(paste(deparse(annotation_install_observe), collapse = " "), "invalidateLater(2000)", fixed = TRUE)
  fired <- 0L
  testthat::local_mocked_bindings(workspace_jobs_future = function(...) { fired <<- fired + 1L })
  w <- apk_world()
  withr::local_envvar(RICHSTUDIO_ANNOTATION_LIB = w$lib)
  collect_notifications()
  jobs <- fake_jobs()
  deps <- fake_deps()
  annotation_install_gate(jobs, NULL, "yeast", "GO", "SYMBOL", function() NULL, deps)
  annotation_install_poll(jobs, deps)
  expect_identical(fired, 0L)
})

test_that("the live row text follows the installer phases and each change is announced once", {
  w <- apk_world()
  withr::local_envvar(RICHSTUDIO_ANNOTATION_LIB = w$lib)
  collect_notifications()
  jobs <- fake_jobs()
  box <- new.env()
  deps <- fake_deps(box, pid_live = function(pid) TRUE)
  annotation_install_gate(jobs, NULL, "yeast", "GO", "SYMBOL", function() NULL, deps)
  annotation_install_poll(jobs, deps)
  token <- recs(jobs)[[1L]]$token
  seen <- character()
  for (ph in c("preparing", "downloading", "downloading", "installing", "validating", "finalizing")) {
    box$status <- status_for(token, phase = ph)
    annotation_install_poll(jobs, deps)
    seen <- c(seen, recs(jobs)[[1L]]$text)
  }
  expect_identical(unique(seen), c("Queued", "Downloading", "Installing", "Verifying"))
  expect_match(announced(jobs), "Verifying")
})

# ---- Stop / Retry / Dismiss (AC-023) -------------------------------------------------------------------------------------

stop_world <- function(env = parent.frame()) {
  w <- apk_world()
  withr::local_envvar(RICHSTUDIO_ANNOTATION_LIB = w$lib, .local_envir = env)
  collect_notifications(env)
  jobs <- fake_jobs()
  box <- new.env()
  live <- new.env(); live$ok <- TRUE
  deps <- fake_deps(box, pid_live = function(pid) live$ok)
  annotation_install_gate(jobs, NULL, "yeast", "GO", "SYMBOL", function() NULL, deps)
  annotation_install_poll(jobs, deps)
  list(jobs = jobs, box = box, live = live, deps = deps, rec = recs(jobs)[[1L]])
}

test_that("AC-023 Stop signals only a verified installer pid owned by this session", {
  x <- stop_world()
  # a status naming an unrelated pid: no signal
  x$live$ok <- FALSE
  x$box$status <- status_for(x$rec$token, pid = "1234")
  expect_false(annotation_install_stop(x$jobs, x$rec$id, x$deps))
  expect_length(x$box$signals, 0L)
  # another session's token: Stop is not offered and nothing is signalled
  x$live$ok <- TRUE
  x$box$status <- status_for("OTHERTOKEN123456")
  expect_false(annotation_stop_offered(x$rec, x$box$status))
  expect_false(annotation_install_stop(x$jobs, x$rec$id, x$deps))
  expect_length(x$box$signals, 0L)
  # the owning session: one SIGTERM
  x$box$status <- status_for(x$rec$token, started = as.numeric(x$box$now))
  expect_true(annotation_stop_offered(x$rec, x$box$status))
  expect_true(annotation_install_stop(x$jobs, x$rec$id, x$deps))
  expect_identical(x$box$signals[[1L]]$signal, tools::SIGTERM)
  expect_identical(recs(x$jobs)[[1L]]$state, "stopping")
})

test_that("AC-023 a pid swapped for an unrelated process before the 45 s escalation gets no SIGKILL", {
  x <- stop_world()
  x$box$status <- status_for(x$rec$token, started = as.numeric(x$box$now))
  expect_true(annotation_install_stop(x$jobs, x$rec$id, x$deps))
  x$live$ok <- FALSE
  x$box$now <- x$box$now + 46
  annotation_install_poll(x$jobs, x$deps)
  expect_length(x$box$signals, 1L)
})

test_that("AC-023 a verified pid still running 45 s after SIGTERM gets SIGKILL, and 5 s later its session", {
  x <- stop_world()
  x$box$status <- status_for(x$rec$token, started = as.numeric(x$box$now))
  annotation_install_stop(x$jobs, x$rec$id, x$deps)
  x$box$now <- x$box$now + 44
  annotation_install_poll(x$jobs, x$deps)
  expect_length(x$box$signals, 1L)
  x$box$now <- x$box$now + 2
  annotation_install_poll(x$jobs, x$deps)
  expect_identical(x$box$signals[[2L]]$signal, tools::SIGKILL)
  x$box$now <- x$box$now + 6
  annotation_install_poll(x$jobs, x$deps)
  expect_identical(x$box$sessions_killed, 4242L)
})

test_that("AC-023 a stopped install keeps its request with a Retry; Retry relaunches once with a new token; Dismiss discards", {
  w <- apk_world()
  withr::local_envvar(RICHSTUDIO_ANNOTATION_LIB = w$lib)
  collect_notifications()
  jobs <- fake_jobs()
  box <- new.env()
  started <- 0L
  deps <- fake_deps(box, pid_live = function(pid) TRUE)
  annotation_install_gate(jobs, NULL, "yeast", "GO", "SYMBOL", function() started <<- started + 1L, deps)
  annotation_install_poll(jobs, deps)
  old <- recs(jobs)[[1L]]$token
  box$status <- status_for(old, state = "stopped")
  annotation_install_poll(jobs, deps)
  rec <- recs(jobs)[[1L]]
  expect_identical(c(rec$state, rec$failure$reason), c("failed", "stopped"))
  expect_null(rec$failure$command)
  expect_true(annotation_install_retry(jobs, rec$id))
  new <- recs(jobs)[[1L]]$token
  expect_false(identical(new, old))
  annotation_install_poll(jobs, deps)
  annotation_install_poll(jobs, deps)
  expect_length(box$launches, 2L)
  expect_identical(box$launches[[2L]]$token, new)
  # success: the retained request runs once
  box$states <- list(org.Sc.sgd.db = "present")
  annotation_install_poll(jobs, deps)
  annotation_install_poll(jobs, deps)
  expect_identical(started, 1L)
  expect_identical(recs(jobs)[[1L]]$state, "done")
  annotation_install_dismiss(jobs, rec$id)
  expect_length(recs(jobs), 0L)
})

# ---- AC-022 structured failure -------------------------------------------------------------------------------------------------

test_that("AC-022 every reason code shows its fixed message and the manual command from the structured failure", {
  for (reason in c("no_network", "timed_out", "checksum_mismatch", "not_enough_disk", "dependency_missing", "entry_invalid",
                   "index_no_md5", "internal_error", "interrupted", "unavailable", "stopped")) {
    f <- annotation_failure(reason, "org.Sc.sgd.db")
    expect_identical(f$message, annotation_reason_message(reason))
    expect_identical(is.null(f$command), reason %in% c("entry_invalid", "unavailable", "stopped"), info = reason)
    rec <- list(id = "abcdef1234567890", state = "failed", text = "Failed", packages = "org.Sc.sgd.db", species = "yeast", failure = f)
    html <- as.character(workspace_install_row(function(x) x, rec))
    if (!is.null(f$command)) {
      expect_match(html, "Copy command", fixed = TRUE)
      expect_match(html, "BiocManager::install(&quot;org.Sc.sgd.db&quot;)", fixed = TRUE)
    }
    expect_match(html, "Package: org.Sc.sgd.db; species: yeast", fixed = TRUE)
  }
  # a message the text classifier would miss still yields the panel (it does not parse text)
  expect_null(workspace_jobs_environment_failure(annotation_reason_message("no_network")))
  multi <- annotation_failure("no_network", c("reactome.db", "org.Hs.eg.db"))
  expect_identical(multi$command, "BiocManager::install(c(\"reactome.db\", \"org.Hs.eg.db\"))")
})

# ---- AC-026 provenance ---------------------------------------------------------------------------------------------------------------

test_that("AC-026 annotation packages are recorded with their installed versions and round-trip through a project", {
  testthat::local_mocked_bindings(annotation_resolve = function(...) list(ok = TRUE, packages = c("stats", "utils")))
  pk <- annotation_provenance_packages("human", "Reactome", "SYMBOL")
  expect_identical(pk, list(stats = as.character(packageVersion("stats")), utils = as.character(packageVersion("utils"))))
  testthat::local_mocked_bindings(annotation_resolve = function(...) list(ok = FALSE, packages = character()))
  expect_identical(annotation_provenance_packages("sco", "GO", "SYMBOL"), list())
  bg <- list(mode = "annotation", source = "Annotation universe", background_digest = NA_character_, submitted_count = NA_integer_,
             mapped_size = NA_integer_, unique_count = 30L, duplicate_count = 0L, invalid_count = 0L, unmapped_count = 10L,
             query_effective = 5L, query_unmapped_count = 1L, query_excluded_count = 0L, query_rule = "r",
             annotation = list(species = "human", anntype = "GO", keytype = "SYMBOL", ontology = "BP", annotation_genes = 100L,
                               richR = "0.1.6", packages = pk),
             unavailable = "mapped_size")
  enc <- richStudio:::project_background_encode(bg)
  decoded <- richStudio:::project_background_decode(jsonlite::fromJSON(jsonlite::toJSON(enc, auto_unbox = TRUE, na = "null"), simplifyVector = FALSE))
  expect_identical(decoded$annotation$packages, pk)
  expect_identical(names(decoded), names(bg))
  # a record saved before this change has no packages key and decodes without error
  old <- bg; old$annotation$packages <- NULL
  expect_no_error(richStudio:::project_background_decode(jsonlite::fromJSON(jsonlite::toJSON(richStudio:::project_background_encode(old), auto_unbox = TRUE, na = "null"), simplifyVector = FALSE)))
})

# ---- integration: the real supervisor, a detached launch and the future worker -----------------------------------------------------

test_that("AC-020/024/029 a detached install runs outside the future pool, finishes after the session, and a worker sees the package", {
  skip_on_cran()
  skip_if_not(nzchar(Sys.which("setsid")) && nzchar(Sys.which("flock")))
  skip_if_not_installed("future")
  w <- apk_world("org.Fake1.eg.db")
  apk_use_world(w)
  collect_notifications()
  # a persistent worker that already ran something (AC-029)
  # a worker starts with the parent's .libPaths(); the app's parent has the annotation library there
  # through the release .Renviron
  old_paths <- .libPaths()
  .libPaths(c(w$lib, old_paths))
  withr::defer(.libPaths(old_paths))
  old_plan <- future::plan(future::multisession, workers = 1L)
  withr::defer(future::plan(old_plan))
  worker_pid_before <- future::value(future::future(Sys.getpid()))
  free_before <- future::nbrOfFreeWorkers()
  jobs <- fake_jobs()
  started <- 0L
  deps <- annotation_deps()
  expect_identical(annotation_install_gate(jobs, NULL, "sp1", "GO", "SYMBOL", function() started <<- started + 1L, deps), "pending")
  annotation_install_poll(jobs, deps)          # rule 7: one detached launch
  status <- NULL
  for (i in 1:600) {
    status <- w$status()
    if (!is.null(status) && identical(status$request, recs(jobs)[[1L]]$token)) break
    Sys.sleep(0.1)
  }
  expect_false(is.null(status), "the supervisor never wrote a status for this request")
  expect_identical(future::nbrOfFreeWorkers(), free_before)     # nothing occupied a future worker
  # the supervisor leads its own session, outside every worker
  sid <- as.integer(system2("ps", c("-o", "sid=", "-p", status$pid), stdout = TRUE))
  expect_identical(sid, as.integer(status$pid))
  for (i in 1:300) {
    annotation_install_poll(jobs, deps)
    if (started > 0L) break
    Sys.sleep(0.2)
  }
  expect_identical(started, 1L)
  expect_true(file.exists(file.path(w$lib, "org.Fake1.eg.db", "DESCRIPTION")))
  tsv <- utils::read.delim(file.path(w$lib, "INSTALLED.tsv"), colClasses = "character")
  expect_identical(tsv$package, "org.Fake1.eg.db")
  # a later Run finds it installed and downloads nothing more
  n_dl <- length(w$downloads())
  expect_identical(annotation_install_gate(fake_jobs(), NULL, "sp1", "GO", "SYMBOL", function() NULL, deps), "started")
  expect_identical(length(w$downloads()), n_dl)
  # the long-lived worker loads the new package without a restart (AC-029)
  found <- future::value(future::future(list(pid = Sys.getpid(), path = find.package("org.Fake1.eg.db"))))
  expect_identical(found$pid, worker_pid_before)
  expect_identical(dirname(normalizePath(found$path)), normalizePath(w$lib))
})

test_that("after an install finishes, a gene ID type the new package lacks stops the run with a plain reason", {
  w <- apk_world()
  withr::local_envvar(RICHSTUDIO_ANNOTATION_LIB = w$lib)
  notes <- collect_notifications()
  for (case in list(list(keytype = "SYMBOL", runs = 0L), list(keytype = "GENENAME", runs = 1L))) {
    jobs <- fake_jobs()
    box <- new.env()
    deps <- fake_deps(box)
    deps$keytypes <- function(lib, pkg) c("ENTREZID", "GENENAME", "ORF")
    started <- 0L
    expect_identical(annotation_install_gate(jobs, NULL, "yeast", "GO", case$keytype,
                                             function() started <<- started + 1L, deps), "pending")
    box$states <- list(org.Sc.sgd.db = "present")
    box$status <- status_for(recs(jobs)[[1L]]$token, state = "completed")
    box$now <- box$now + 2
    annotation_install_poll(jobs, deps)
    expect_identical(recs(jobs)[[1L]]$state, "done")
    expect_identical(started, case$runs)
  }
  texts <- vapply(notes$notes, function(n) n$text, "")
  expect_length(grep("Run not started. The yeast annotation has no 'SYMBOL'", texts, fixed = TRUE), 1L)
})
