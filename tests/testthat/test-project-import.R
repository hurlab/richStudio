# SPEC-WS-007: validated import, transactional apply, legacy JSON adapter.
# REQ-002 (AC-002), REQ-003 (AC-003), REQ-004 (AC-004), REQ-005 (AC-003).
#
# Hostile archives are built byte by byte in temporary directories (a small stored-ZIP
# writer below) or with zip::zipr; nothing is ever extracted outside a private temp dir
# and no exploit is executed. Pending-worker tests own their multisession worker:
# cleanup releases the latch, switches to sequential and asserts the worker is gone.

pi_session <- function() {
  deg <- data.frame(gene = c("g1", "g2", "g3"), Padj = c(0.01, NA, 0.5), stringsAsFactors = FALSE)
  rr <- data.frame(Term = c("GO:1", "GO:2", "GO:3"), Annot = c("a", "b", "c"),
                   Pvalue = c(1e-8, 0.02, 0.3), Padj = c(1e-6, NA, 0.9), GeneID = c("g1", "g2", "g3"),
                   stringsAsFactors = FALSE)
  summary <- data.frame(Cluster = 1:2, Representative_Term = c("GO:1", "GO:3"), stringsAsFactors = FALSE)
  detail <- data.frame(Term = c("GO:1", "GO:2", "GO:3"), Cluster = c(1L, 1L, 2L),
                       Representative_Term = c("GO:1", "GO:1", "GO:3"), stringsAsFactors = FALSE)
  list(version = "1.0", degnames = "deg_a", degdfs = list(deg_a = deg),
       rrnames = "deg_a_enriched", rrdfs = list(deg_a_enriched = rr),
       clusnames = "clus1", clusdfs = list(clus1 = summary), cluslists = list(clus1 = detail))
}

pi_run_record <- function() {
  rec <- list(schema = "richstudio.run_record", version = 1L, run_id = "0123456789ab", kind = "enrichment",
              state = "succeeded", created = "2026-10-25T10:00:00Z", queued_at = "2026-10-25T10:00:00Z",
              started = "2026-10-25T10:00:01Z", ended = "2026-10-25T10:00:09Z",
              settings = list(species = "human", anntype = "GO"), inputs = list(list(store = "deg", label = "deg_a", revision = 0L)),
              outputs = "deg_a_enriched", retry_of = NA_character_, imported_from = NA_character_,
              note = NA_character_, error_summary = NA_character_)
  richStudio:::workspace_run_records_parse(richStudio:::workspace_run_records_json(list(rec)))
}

pi_valid <- function(session = pi_session(), env = parent.frame()) {
  path <- withr::local_tempfile(fileext = ".zip", .local_envir = env)
  richStudio:::project_write(session, pi_run_record(), path)
  path
}

pi_policy <- function(...) {
  policy <- richStudio:::workspace_resource_policy()
  changes <- list(...)
  for (key in names(changes)) policy$limits[[key]] <- changes[[key]]
  function() policy
}

pi_read <- function(path, policy_loader = richStudio:::workspace_resource_policy) {
  richStudio:::project_import_read(path, policy_loader = policy_loader)
}

expect_rejected <- function(path, pattern, policy_loader = richStudio:::workspace_resource_policy) {
  err <- tryCatch(pi_read(path, policy_loader), error = function(e) e)
  testthat::expect_s3_class(err, "richstudio_project_invalid")
  testthat::expect_match(conditionMessage(err), pattern, fixed = TRUE)
}

# ---- a stored-ZIP writer: exact names, duplicate names and link attributes -----------

pi_le <- function(x, n) as.raw((x %/% 256^(seq_len(n) - 1)) %% 256)

pi_raw_zip <- function(entries, path) {
  out <- raw()
  central <- raw()
  for (e in entries) {
    name <- charToRaw(e$name)
    data <- if (is.null(e$data)) charToRaw("{}") else e$data
    local <- c(pi_le(0x04034b50, 4), pi_le(20, 2), pi_le(0, 2), pi_le(0, 2), pi_le(0, 4), pi_le(0, 4),
               pi_le(length(data), 4), pi_le(length(data), 4), pi_le(length(name), 2), pi_le(0, 2), name, data)
    central <- c(central, pi_le(0x02014b50, 4), pi_le(768 + 20, 2), pi_le(20, 2), pi_le(0, 2), pi_le(0, 2),
                 pi_le(0, 4), pi_le(0, 4), pi_le(length(data), 4), pi_le(length(data), 4), pi_le(length(name), 2),
                 pi_le(0, 2), pi_le(0, 2), pi_le(0, 2), pi_le(0, 2),
                 pi_le(if (is.null(e$attr)) 0x81A40000 else e$attr, 4), pi_le(length(out), 4), name)
    out <- c(out, local)
  }
  n <- length(entries)
  eocd <- c(pi_le(0x06054b50, 4), pi_le(0, 2), pi_le(0, 2), pi_le(n, 2), pi_le(n, 2),
            pi_le(length(central), 4), pi_le(length(out), 4), pi_le(0, 2))
  writeBin(c(out, central, eocd), path)
  invisible(path)
}

pi_hostile <- function(entries, env = parent.frame()) {
  path <- withr::local_tempfile(fileext = ".zip", .local_envir = env)
  pi_raw_zip(entries, path)
  path
}

# Rewrite a valid project: edit the manifest/tables, optionally refreshing file digests.
pi_edit <- function(path, manifest = identity, tables_text = identity, fix_digests = TRUE, env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  zip::unzip(path, exdir = dir)
  m <- jsonlite::read_json(file.path(dir, "manifest.json"), simplifyVector = FALSE)
  t_text <- paste(readLines(file.path(dir, "tables.json"), warn = FALSE), collapse = "\n")
  writeLines(tables_text(t_text), file.path(dir, "tables.json"), useBytes = TRUE)
  m <- manifest(m)
  if (fix_digests) {
    for (i in seq_along(m$files)) {
      f <- file.path(dir, m$files[[i]]$name)
      m$files[[i]]$sha256 <- digest::digest(f, algo = "sha256", file = TRUE)
      m$files[[i]]$bytes <- file.size(f)
    }
  }
  jsonlite::write_json(m, file.path(dir, "manifest.json"), auto_unbox = TRUE, digits = I(17), null = "null", na = "null")
  out <- withr::local_tempfile(fileext = ".zip", .local_envir = env)
  zip::zipr(out, c("manifest.json", "tables.json", "methods.md"), root = dir)
  out
}

# ---- AC-003: invalid archives fail before any state is built ------------------------

test_that("AC-003 traversal, absolute, drive, backslash and directory names are rejected", {
  for (bad in c("../evil.json", "tables/../../evil.json", "/etc/cron.d/x", "C:/x.json", "a\\b.json", "./manifest.json")) {
    path <- pi_hostile(list(list(name = "manifest.json"), list(name = bad)))
    expect_rejected(path, "unsafe member path")
  }
})

test_that("AC-003 a directory member is rejected", {
  expect_rejected(pi_hostile(list(list(name = "manifest.json"), list(name = "tables/"))),
                  "link, directory or special member")
})

test_that("AC-003 duplicate and ambiguous member names are rejected", {
  expect_rejected(pi_hostile(list(list(name = "manifest.json"), list(name = "manifest.json"))),
                  "duplicate or ambiguous")
  expect_rejected(pi_hostile(list(list(name = "manifest.json"), list(name = "Manifest.JSON"))),
                  "duplicate or ambiguous")
})

test_that("AC-003 link members and unexpected (code) members are rejected", {
  link <- pi_hostile(list(list(name = "manifest.json"), list(name = "tables.json", attr = 0xA1FF0000)))
  expect_rejected(link, "link, directory or special member")
  expect_rejected(pi_hostile(list(list(name = "manifest.json"), list(name = "tables.json"), list(name = "run.R"))),
                  "unexpected member")
  expect_rejected(pi_hostile(list(list(name = "manifest.json"))), "lacks manifest.json or tables.json")
  junk <- withr::local_tempfile(fileext = ".zip")
  writeLines("not a zip", junk)
  expect_rejected(junk, "not a readable ZIP")
  expect_rejected(withr::local_tempfile(fileext = ".zip"), "could not be read")
})

test_that("AC-003 an archive bomb is rejected by the compression-ratio and size limits", {
  dir <- withr::local_tempdir()
  writeBin(raw(6 * 1024 * 1024), file.path(dir, "tables.json"))
  writeLines("{}", file.path(dir, "manifest.json"))
  bomb <- withr::local_tempfile(fileext = ".zip")
  zip::zipr(bomb, c("manifest.json", "tables.json"), root = dir)
  expect_lt(file.size(bomb), 100000)
  expect_rejected(bomb, "compression ratio limit")
  expect_rejected(bomb, "archive_expanded_bytes", pi_policy(archive_expanded_bytes = 1048576))
})

test_that("AC-003 depth, member count, size and table-shape limits hold at and above the limit", {
  path <- pi_valid()
  listed <- zip::zip_list(path)
  expanded <- sum(listed$uncompressed_size)
  expect_silent(pi_read(path, pi_policy(archive_members = 3L, archive_expanded_bytes = expanded,
                                        archive_bytes = file.size(path), rows = 3L, columns = 5L,
                                        archive_depth = 1L, string_bytes = 14L)))
  expect_rejected(path, "archive_members", pi_policy(archive_members = 2L))
  expect_rejected(path, "archive_expanded_bytes", pi_policy(archive_expanded_bytes = expanded - 1))
  expect_rejected(path, "larger than the reviewed limit", pi_policy(archive_bytes = file.size(path) - 1))
  expect_rejected(path, "rows", pi_policy(rows = 2L))
  expect_rejected(path, "columns", pi_policy(columns = 4L))
  expect_rejected(path, "Invalid deg label", pi_policy(string_bytes = 4L))
  deep <- pi_hostile(list(list(name = "manifest.json"), list(name = "a/b.json")))
  expect_rejected(deep, "archive_depth", pi_policy(archive_depth = 1L))
})

test_that("AC-003 a missing or invalid resource policy blocks import", {
  path <- pi_valid()
  expect_rejected(path, "resource policy missing or invalid", function() stop("no policy"))
  expect_rejected(path, "resource policy missing or invalid", function() list(limits = list()))
  expect_rejected(path, "resource policy missing or invalid", function() NULL)
})

test_that("AC-003 an unsupported future major version, malformed JSON and broken references are rejected", {
  path <- pi_valid()
  expect_rejected(pi_edit(path, function(m) { m$format_version <- "2.0"; m }), "does not support")
  expect_rejected(pi_edit(path, function(m) { m$format_version <- "banana"; m }), "no valid format_version")
  expect_rejected(pi_edit(path, function(m) { m$schema <- "other"; m }), "not a richStudio project manifest")
  # A newer MINOR version of the same major is read.
  expect_silent(pi_read(pi_edit(path, function(m) { m$format_version <- "1.7"; m })))

  expect_rejected(pi_edit(path, function(m) { m$relationships[[1]]$from <- "ds-000000000000"; m }),
                  "broken relationship reference")
  expect_rejected(pi_edit(path, function(m) { m$results[[1]]$table <- "t0099"; m }), "missing table")
  expect_rejected(pi_edit(path, function(m) { m$results[[1]]$table <- m$datasets[[1]]$table; m }),
                  "more than once")
  expect_rejected(pi_edit(path, function(m) { m$results[[1]]$id <- m$datasets[[1]]$id; m }), "repeats an ID")
  expect_rejected(pi_edit(path, function(m) { m$results[[1]]$id <- "../x"; m }), "invalid ID")
  expect_rejected(pi_edit(path, function(m) { m$results[[1]]$label <- ""; m }), "Invalid enrichment label")
  expect_rejected(pi_edit(path, function(m) { m$datasets <- c(m$datasets, m$datasets[1]); m }), "repeats")
  expect_rejected(pi_edit(path, function(m) { m$runs[[1]]$state <- "exploding"; m }), "invalid run record")
  expect_rejected(pi_edit(path, function(m) { m$datasets <- list(); m }), "does not reference")
  expect_rejected(pi_edit(path, function(m) { m$results[[1]]$nrow <- 99L; m }), "manifest description")
})

test_that("AC-003 a tampered table or file is caught by its digest", {
  path <- pi_valid()
  tampered <- pi_edit(path, tables_text = function(t) sub("0.02", "0.03", t, fixed = TRUE), fix_digests = FALSE)
  expect_rejected(tampered, "tables.json does not match the digest")
  # With the file digest repaired the per-table digest still catches the changed value.
  repaired <- pi_edit(path, tables_text = function(t) sub("0.02", "0.03", t, fixed = TRUE), fix_digests = TRUE)
  expect_rejected(repaired, "does not match its recorded digest")
  expect_rejected(pi_edit(path, tables_text = function(t) "{not json", fix_digests = TRUE), "not valid JSON")
})

test_that("AC-003 import never evaluates anything it reads", {
  sentinel <- file.path(tempdir(), "pi-sentinel-should-not-exist")
  unlink(sentinel)
  code <- sprintf("system(\"touch %s\")", sentinel)
  session <- pi_session()
  session$degnames <- code
  session$degdfs <- stats::setNames(list(data.frame(gene = c(code, "quote(stop(1))"), stringsAsFactors = FALSE)), code)
  path <- pi_valid(session)
  edited <- pi_edit(path, function(m) { m$extra_recipe <- list(run = code, source = "source('x.R')"); m })
  candidate <- pi_read(edited)
  expect_false(file.exists(sentinel))
  expect_identical(candidate$degnames, code)
  expect_identical(candidate$degdfs[[1]]$gene, c(code, "quote(stop(1))"))
  inert <- function(x) {
    if (is.list(x)) return(all(vapply(x, inert, logical(1))))
    !(is.function(x) || is.language(x) || is.environment(x) || is.symbol(x))
  }
  expect_true(inert(unclass(candidate)))
})

# ---- the candidate is complete and data only ----------------------------------------

test_that("a valid project becomes a complete data-only candidate", {
  candidate <- pi_read(pi_valid())
  expect_identical(candidate$source$kind, "project")
  expect_identical(candidate$degdfs, pi_session()$degdfs)
  expect_identical(candidate$rrdfs, pi_session()$rrdfs)
  expect_match(candidate$methods, "# Methods summary", fixed = TRUE)
  expect_length(richStudio:::workspace_run_records_parse(candidate$run_records_json), 1L)
})

# ---- AC-002 / REQ-002: legacy JSON 1.0 through the data-only adapter ------------------

test_that("AC-002 legacy JSON 1.0 keeps its data and every provenance field is not recorded", {
  fixture <- testthat::test_path("..", "fixtures", "workspace", "legacy-session-v1.json")
  legacy <- richStudio:::project_legacy_candidate(richStudio:::session_json_read(fixture))
  expect_identical(legacy$source$kind, "legacy_session_json")
  expect_identical(legacy$source$metadata, "not_recorded")
  expect_identical(legacy$rrnames, "imported")
  expect_identical(legacy$rrdfs$imported$ProviderExtra, "retained-a")
  expect_identical(legacy$rrdfs$imported$Padj, 0.9)
  built <- richStudio:::project_manifest_build(legacy, list())$manifest
  r <- built$results[[1]]
  for (field in c("run_id", "species", "keytype", "annotation_type", "ontology", "parameters", "background")) {
    expect_identical(r[[field]]$status, "not_recorded", info = field)
  }
  # Opening and re-saving as a project keeps the same numbers and invents no metadata.
  again <- pi_read({
    path <- withr::local_tempfile(fileext = ".zip")
    richStudio:::project_write(legacy, list(), path)
    path
  })
  expect_identical(again$rrdfs$imported, legacy$rrdfs$imported)
  expect_identical(again$manifest$results[[1]]$species$status, "not_recorded")
})

test_that("AC-002 the legacy adapter rejects malformed candidates before anything is applied", {
  good <- richStudio:::session_json_read(testthat::test_path("..", "fixtures", "workspace", "legacy-session-v1.json"))
  bad <- function(change) {
    s <- good
    change(s)
  }
  expect_error(richStudio:::project_legacy_candidate(bad(function(s) { s$degnames <- 5; s })), "Invalid session file format")
  expect_error(richStudio:::project_legacy_candidate(bad(function(s) { s$rrdfs <- list(1, 2); s })), "Invalid session file format")
  expect_error(richStudio:::project_legacy_candidate(bad(function(s) { s$rrdfs <- list(a = "x"); s })), "Invalid session file format")
  expect_error(richStudio:::project_legacy_candidate(bad(function(s) { s$run_records_json <- list(1); s })), "Invalid session file format")
  expect_error(richStudio:::project_legacy_candidate("nope"), "Invalid session file format")
})

# ---- the Save tab: one atomic commit for projects and legacy JSON ----------------------

pi_app <- function(state, modules = "save", runner = NULL, env = parent.frame()) {
  s <- shiny::MockShinySession$new()
  log <- new.env(parent = emptyenv())
  log$notes <- list()
  log$n <- 0L
  s$sendNotification <- function(type, message) log$notes[[length(log$notes) + 1L]] <- list(type = type, message = message)
  jobs <- shiny::withReactiveDomain(s, richStudio:::workspace_jobs_registry(s))
  s$userData$workspace_jobs <- jobs
  s$onSessionEnded(function() richStudio:::workspace_jobs_close(jobs))
  withr::defer(if (!s$isClosed()) s$close(), envir = env)
  shiny::withReactiveDomain(s, {
    if ("enrich" %in% modules) {
      args <- list("enrich", u_degnames = state$u_degnames, u_degdfs = state$u_degdfs,
                   u_big_degdf = state$u_big_degdf, u_rrnames = state$u_rrnames,
                   u_rrdfs = state$u_rrdfs, u_big_rrdf = state$u_big_rrdf)
      if (!is.null(runner)) args$enrichment_runner <- runner
      do.call(richStudio:::enrichTabServer, args)
    }
    richStudio::saveTabServer("save", u_degnames = state$u_degnames, u_degdfs = state$u_degdfs,
      u_rrnames = state$u_rrnames, u_rrdfs = state$u_rrdfs, u_clusnames = state$u_clusnames,
      u_clusdfs = state$u_clusdfs, u_cluslists = state$u_cluslists)
  })
  s$flushReact()
  list(s = s, log = log, jobs = jobs, state = state)
}

pi_state <- function() {
  list(u_degnames = shiny::reactiveValues(labels = NULL), u_degdfs = shiny::reactiveValues(),
       u_big_degdf = shiny::reactiveValues(),
       u_rrnames = shiny::reactiveValues(labels = NULL), u_rrdfs = shiny::reactiveValues(),
       u_big_rrdf = shiny::reactiveValues(),
       u_clusnames = shiny::reactiveValues(labels = NULL), u_clusdfs = shiny::reactiveValues(),
       u_cluslists = shiny::reactiveValues())
}

# Cleared entries stay as NULL-valued keys (the app's own reset does the same), so only
# live values count as "present".
pi_snapshot <- function(state) {
  live <- function(rv) Filter(Negate(is.null), shiny::reactiveValuesToList(rv))
  shiny::isolate(list(
    degnames = state$u_degnames$labels, degdfs = live(state$u_degdfs),
    rrnames = state$u_rrnames$labels, rrdfs = live(state$u_rrdfs),
    clusnames = state$u_clusnames$labels, clusdfs = live(state$u_clusdfs),
    cluslists = live(state$u_cluslists)))
}

pi_notes <- function(app) {
  vapply(app$log$notes, function(n) paste(as.character(n$message$html), collapse = ""), character(1))
}

pi_open_project <- function(app, path) {
  app$log$n <- app$log$n + 1L
  app$s$setInputs("save-load_project_file" = list(name = basename(path), datapath = path))
  app$s$setInputs("save-load_project" = app$log$n)
}

pi_open_json <- function(app, path) {
  app$log$n <- app$log$n + 1L
  app$s$setInputs("save-load_session_file" = list(name = "legacy.json", datapath = path))
  app$s$setInputs("save-load_session" = app$log$n)
}

pi_populate <- function(state) {
  shiny::isolate({
    state$u_degnames$labels <- c("old_deg", "old_deg2")
    state$u_degdfs$old_deg <- data.frame(keep = 1:2)
    state$u_degdfs$old_deg2 <- data.frame(keep = 3:4)
    state$u_rrnames$labels <- "old_rr"
    state$u_rrdfs$old_rr <- data.frame(Term = "old")
    state$u_clusnames$labels <- "old_clus"
    state$u_clusdfs$old_clus <- data.frame(Cluster = 1L)
    state$u_cluslists$old_clus <- data.frame(Term = "old", Cluster = 1L)
  })
  state
}

test_that("REQ-003 REQ-004 a rejected project changes nothing; a valid one replaces the workspace atomically", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  state <- pi_populate(pi_state())
  app <- pi_app(state)
  before <- pi_snapshot(state)
  expect_identical(app$jobs$generation, 1L)

  bad <- pi_edit(pi_valid(), function(m) { m$format_version <- "2.0"; m })
  pi_open_project(app, bad)
  expect_identical(pi_snapshot(state), before)
  expect_identical(app$jobs$generation, 1L)
  expect_true(any(grepl("Project could not be opened", pi_notes(app), fixed = TRUE)))

  traversal <- pi_hostile(list(list(name = "../x"), list(name = "manifest.json")))
  pi_open_project(app, traversal)
  expect_identical(pi_snapshot(state), before)
  expect_identical(app$jobs$generation, 1L)

  good <- pi_valid()
  pi_open_project(app, good)
  after <- pi_snapshot(state)
  expect_identical(app$jobs$generation, 2L)
  expect_identical(after$degnames, "deg_a")
  expect_identical(names(after$degdfs), "deg_a")
  expect_identical(after$degdfs$deg_a, pi_session()$degdfs$deg_a)
  expect_identical(after$rrnames, "deg_a_enriched")
  expect_identical(names(after$rrdfs), "deg_a_enriched")
  expect_identical(names(after$clusdfs), "clus1")
  expect_identical(names(after$cluslists), "clus1")
  expect_true(any(grepl("Project opened successfully", pi_notes(app), fixed = TRUE)))
  # The saved run history joins the new workspace as history.
  expect_identical(vapply(app$jobs$records, function(r) as.character(r$run_id), ""), "0123456789ab")
})

test_that("REQ-002 REQ-005 legacy JSON takes the same commit; a malformed file is refused before the swap", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  state <- pi_populate(pi_state())
  app <- pi_app(state)
  before <- pi_snapshot(state)

  malformed <- withr::local_tempfile(fileext = ".json")
  jsonlite::write_json(list(version = "1.0", degnames = 5, degdfs = list(), rrnames = character(),
                            rrdfs = list(), clusnames = character(), clusdfs = list(), cluslists = list()),
                       malformed, auto_unbox = TRUE)
  pi_open_json(app, malformed)
  expect_identical(pi_snapshot(state), before)
  expect_identical(app$jobs$generation, 1L)
  expect_true(any(grepl("Invalid session file format", pi_notes(app), fixed = TRUE)))

  broken_schema <- withr::local_tempfile(fileext = ".json")
  writeLines('{"version":"1.0","rrnames":["x"],"rrdfs":{"x":{"a":[1,2]}},"df_schema":{"rrdfs":{"x":{"nrow":5,"names":["a"],"classes":["double"],"levels":{}}}}}',
             broken_schema)
  pi_open_json(app, broken_schema)
  expect_identical(pi_snapshot(state), before)
  expect_identical(app$jobs$generation, 1L)

  fixture <- testthat::test_path("..", "fixtures", "workspace", "legacy-session-v1.json")
  pi_open_json(app, fixture)
  after <- pi_snapshot(state)
  expect_identical(app$jobs$generation, 2L)
  expect_identical(after$rrnames, "imported")
  expect_identical(names(after$rrdfs), "imported")
  expect_identical(names(after$degdfs), "query")
})

test_that("a project can be downloaded from the Save tab and opened again", {
  withr::defer(richStudio:::workspace_job_queue_reset())
  session <- pi_session()
  state <- pi_state()
  shiny::isolate({
    state$u_degnames$labels <- session$degnames
    state$u_degdfs$deg_a <- session$degdfs$deg_a
    state$u_rrnames$labels <- session$rrnames
    state$u_rrdfs$deg_a_enriched <- session$rrdfs$deg_a_enriched
    state$u_clusnames$labels <- session$clusnames
    state$u_clusdfs$clus1 <- session$clusdfs$clus1
    state$u_cluslists$clus1 <- session$cluslists$clus1
  })
  path <- withr::local_tempfile(fileext = ".zip")
  shiny::testServer(richStudio::saveTabServer,
    args = state[c("u_degnames", "u_degdfs", "u_rrnames", "u_rrdfs", "u_clusnames", "u_clusdfs", "u_cluslists")], {
      session$setInputs(session_name = "my/project")
      expect_match(basename(output$download_project), "^my_project\\.zip$")
      file.copy(output$download_project, path, overwrite = TRUE)
    })
  expect_true(file.exists(path))
  candidate <- pi_read(path)
  expect_identical(candidate$rrdfs, session$rrdfs)
  expect_identical(candidate$degnames, "deg_a")
})

# ---- AC-004: a pending worker from the old workspace never publishes -------------------

pi_latch_runner <- function(dir) {
  dir <- normalizePath(dir, mustWork = TRUE)
  function(deg_inputs, cutoff, species, anntype, keytype, ontology, background = NULL) {
    writeLines(as.character(Sys.getpid()), file.path(dir, "worker.pid.tmp"))
    file.rename(file.path(dir, "worker.pid.tmp"), file.path(dir, "worker.pid"))
    deadline <- Sys.time() + 30
    while (!file.exists(file.path(dir, "release")) && Sys.time() < deadline) Sys.sleep(0.02)
    lapply(deg_inputs, function(inp) {
      list(name = inp$name,
           result = data.frame(Annot = "Term one", Term = "T1", Pvalue = 0.01, Padj = 0.02, GeneID = "g1,g2",
                               stringsAsFactors = FALSE),
           anntype = anntype, keytype = keytype, ontology = ontology, species = species)
    })
  }
}

pi_worker <- function(dir, env = parent.frame()) {
  withr::defer({
    file.create(file.path(dir, "release"))
    pid <- if (file.exists(file.path(dir, "worker.pid"))) as.integer(readLines(file.path(dir, "worker.pid"))) else NA_integer_
    future::plan(future::sequential)
    if (!is.na(pid)) {
      deadline <- Sys.time() + 5
      while (dir.exists(file.path("/proc", pid)) && Sys.time() < deadline) Sys.sleep(0.05)
      if (dir.exists(file.path("/proc", pid))) tools::pskill(pid, tools::SIGKILL)
      testthat::expect_false(dir.exists(file.path("/proc", pid)) &&
                               !grepl("^Z", sub(".*\\) ", "", paste(readLines(file.path("/proc", pid, "stat")), collapse = ""))),
                             label = "worker left after cleanup")
    }
  }, envir = env)
  future::plan(future::multisession, workers = I(1L))
}

pi_start_run <- function(app, dir) {
  s <- app$s
  do.call(s$setInputs, list("enrich-species_select" = "human", "enrich-anntype_select" = "Reactome",
    "enrich-keytype_select" = "SYMBOL", "enrich-ont_select" = "BP", "enrich-deg_filter_cutoff" = 0.05,
    "enrich-degs_to_enrich" = "deg_a"))
  s$setInputs("enrich-enrich_deg" = 1L)
  deadline <- Sys.time() + 20
  while (!file.exists(file.path(dir, "worker.pid")) && Sys.time() < deadline) {
    later::run_now(timeoutSecs = 0.02)
    s$flushReact()
  }
  expect_true(file.exists(file.path(dir, "worker.pid")))
}

pi_settle <- function(app, predicate, timeout = 20) {
  deadline <- Sys.time() + timeout
  repeat {
    if (isTRUE(predicate())) return(TRUE)
    if (Sys.time() > deadline) return(FALSE)
    later::run_now(timeoutSecs = 0.02)
    app$s$flushReact()
  }
}

pi_pending <- function(open, valid_path, bad_path) {
  withr::defer(richStudio:::workspace_job_queue_reset())
  dir <- withr::local_tempdir()
  pi_worker(dir)
  state <- pi_state()
  shiny::isolate({
    state$u_degdfs$deg_a <- data.frame(gene = paste0("g", 1:4), Padj = rep(0.01, 4))
    state$u_big_degdf$df <- richStudio::add_file_degdf(state$u_big_degdf$df, "deg_a", state$u_degdfs$deg_a)
    state$u_degnames$labels <- "deg_a"
  })
  app <- pi_app(state, modules = c("enrich", "save"), runner = pi_latch_runner(dir))

  # A malformed candidate: the pending job keeps its generation and still publishes.
  pi_start_run(app, dir)
  expect_identical(app$jobs$generation, 1L)
  open(app, bad_path)
  expect_identical(app$jobs$generation, 1L)
  file.create(file.path(dir, "release"))
  expect_true(pi_settle(app, function() "deg_a_enriched" %in% shiny::isolate(names(state$u_rrdfs))))
  expect_identical(app$jobs$records[[length(app$jobs$records)]]$state, "succeeded")
  unlink(file.path(dir, c("release", "worker.pid")))

  # A valid load while a second job is pending: loaded results only, old result rejected.
  shiny::isolate(state$u_degdfs$deg_a <- data.frame(gene = paste0("g", 1:4), Padj = rep(0.02, 4)))
  pi_start_run(app, dir)
  pending <- app$jobs$records[[length(app$jobs$records)]]
  expect_identical(pending$state, "running")
  open(app, valid_path)
  expect_identical(app$jobs$generation, 2L)
  loaded <- pi_snapshot(state)
  file.create(file.path(dir, "release"))
  expect_true(pi_settle(app, function() {
    rec <- Filter(function(r) identical(r$run_id, pending$run_id), app$jobs$records)
    length(rec) == 1L && identical(rec[[1]]$state, "superseded")
  }))
  rec <- Filter(function(r) identical(r$run_id, pending$run_id), app$jobs$records)[[1]]
  expect_match(rec$note, "workspace replaced", fixed = TRUE)
  expect_identical(pi_snapshot(state), loaded)
  expect_false("deg_a_enriched_1" %in% names(loaded$rrdfs))
  invisible(app)
}

test_that("AC-004 REQ-004 a pending worker's late result is rejected after a project load", {
  bad <- pi_edit(pi_valid(), function(m) { m$format_version <- "2.0"; m })
  pi_pending(pi_open_project, pi_valid(), bad)
})

test_that("AC-004 REQ-004 a pending worker's late result is rejected after a legacy JSON load", {
  fixture <- testthat::test_path("..", "fixtures", "workspace", "legacy-session-v1.json")
  malformed <- withr::local_tempfile(fileext = ".json")
  jsonlite::write_json(list(version = "1.0", degnames = 5), malformed, auto_unbox = TRUE)
  pi_pending(pi_open_json, fixture, malformed)
})
