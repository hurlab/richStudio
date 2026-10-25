# Session files are JSON only: lossless round trip, no RDS deserialization on upload,
# and a local converter for trusted legacy .rds files.

sj_fixture <- function() {
  main <- data.frame(
    gene = c("g1", "caf\u00e9 \u03b1", NA, ""),
    `p-value` = c(1.234567890123e-10, 0.1 + 0.2, 1 / 3, NA),
    n = c(1L, NA, 3L, 4L),
    flag = c(TRUE, NA, FALSE, TRUE),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  special <- data.frame(
    stat = c(Inf, -Inf, NaN, 2.5, NA),
    group = factor(c("b", "a", "b", NA, "a"), levels = c("b", "a", "unused")),
    stringsAsFactors = FALSE
  )
  one_row <- data.frame(term = "only", Padj = 5e-324, k = 7L)
  list(
    version = "1.0", created = "2026-10-25T00:00:00Z",
    degnames = "d\u00e9g1", degdfs = stats::setNames(list(main), "d\u00e9g1"),
    rrnames = c("r1", "empty", "special", "one"),
    rrdfs = list(r1 = main, empty = main[FALSE, , drop = FALSE],
                 special = special, one = one_row),
    clusnames = "c1", clusdfs = list(c1 = one_row), cluslists = list(c1 = main)
  )
}

sj_state <- function(session = NULL) {
  state <- list(
    u_degnames = shiny::reactiveValues(labels = character()),
    u_degdfs = shiny::reactiveValues(),
    u_rrnames = shiny::reactiveValues(labels = character()),
    u_rrdfs = shiny::reactiveValues(),
    u_clusnames = shiny::reactiveValues(labels = character()),
    u_clusdfs = shiny::reactiveValues(),
    u_cluslists = shiny::reactiveValues()
  )
  if (!is.null(session)) {
    state$u_degnames$labels <- session$degnames
    state$u_rrnames$labels <- session$rrnames
    state$u_clusnames$labels <- session$clusnames
    for (n in names(session$degdfs)) state$u_degdfs[[n]] <- session$degdfs[[n]]
    for (n in names(session$rrdfs)) state$u_rrdfs[[n]] <- session$rrdfs[[n]]
    for (n in names(session$clusdfs)) state$u_clusdfs[[n]] <- session$clusdfs[[n]]
    for (n in names(session$cluslists)) state$u_cluslists[[n]] <- session$cluslists[[n]]
  }
  state
}

sj_save <- function(session, path) {
  captured <- new.env(parent = emptyenv())
  args <- sj_state(session)
  args$download_handler <- function(filename, content, ...) {
    captured$content <- content
    shiny::downloadHandler(filename, content, ...)
  }
  shiny::testServer(richStudio::saveTabServer, args = args, {
    session$setInputs(session_name = "roundtrip")
    captured$content(path)
  })
  invisible(path)
}

sj_load <- function(path, name = basename(path)) {
  state <- sj_state()
  args <- state
  shiny::testServer(richStudio::saveTabServer, args = args, {
    session$setInputs(load_session_file = list(name = name, datapath = path))
    session$setInputs(load_session = 1L)
  })
  state
}

sj_read_dfs <- function(state) {
  list(
    deg = shiny::isolate(shiny::reactiveValuesToList(state$u_degdfs)),
    rr = shiny::isolate(shiny::reactiveValuesToList(state$u_rrdfs)),
    clus = shiny::isolate(shiny::reactiveValuesToList(state$u_clusdfs)),
    cluslist = shiny::isolate(shiny::reactiveValuesToList(state$u_cluslists))
  )
}

test_that("JSON session round trip is lossless for every data frame", {
  session <- sj_fixture()
  saved <- withr::local_tempfile(fileext = ".json")
  sj_save(session, saved)
  state <- sj_load(saved)
  restored <- sj_read_dfs(state)

  expect_identical(shiny::isolate(state$u_degnames$labels), session$degnames)
  expect_identical(shiny::isolate(state$u_rrnames$labels), session$rrnames)
  expect_identical(shiny::isolate(state$u_clusnames$labels), session$clusnames)
  for (n in names(session$degdfs)) expect_identical(restored$deg[[n]], session$degdfs[[n]])
  for (n in names(session$rrdfs)) expect_identical(restored$rr[[n]], session$rrdfs[[n]])
  for (n in names(session$clusdfs)) expect_identical(restored$clus[[n]], session$clusdfs[[n]])
  for (n in names(session$cluslists)) expect_identical(restored$cluslist[[n]], session$cluslists[[n]])
  expect_identical(restored$rr$r1[["p-value"]][1:3], c(1.234567890123e-10, 0.1 + 0.2, 1 / 3))
  expect_identical(restored$rr$empty$n, integer())
  expect_identical(restored$rr$r1$gene[3:4], c(NA_character_, ""))
})

test_that("saved JSON keeps the version 1.0 layout and column-list tables", {
  saved <- withr::local_tempfile(fileext = ".json")
  sj_save(sj_fixture(), saved)
  raw <- jsonlite::read_json(saved, simplifyVector = TRUE)
  expect_identical(raw$version, "1.0")
  expect_identical(raw$rrnames, c("r1", "empty", "special", "one"))
  expect_identical(raw$rrdfs$r1$n, c(1L, NA, 3L, 4L))
})

test_that("legacy JSON sessions without a schema still load through the old path", {
  legacy <- withr::local_tempfile(fileext = ".json")
  jsonlite::write_json(list(
    version = "1.0", created = "2026-10-20T00:00:00Z",
    degnames = "q", degdfs = list(q = list(gene = c("a", "b"), score = c(1.5, 2))),
    rrnames = character(), rrdfs = list(), clusnames = character(),
    clusdfs = list(), cluslists = list()
  ), legacy, auto_unbox = TRUE)
  state <- sj_load(legacy)
  expect_identical(shiny::isolate(state$u_degdfs$q),
                   data.frame(gene = c("a", "b"), score = c(1.5, 2)))
  expect_identical(shiny::isolate(state$u_degnames$labels), "q")
})

test_that("uploaded RDS files are refused before deserialization and change nothing", {
  session <- sj_fixture()
  rds <- withr::local_tempfile(fileext = ".rds")
  saveRDS(session, rds)
  disguised <- withr::local_tempfile(fileext = ".json")
  file.copy(rds, disguised, overwrite = TRUE)

  messages <- character()
  testthat::local_mocked_bindings(
    showNotification = function(ui, ...) messages <<- c(messages, as.character(ui)),
    .package = "richStudio"
  )
  existing <- data.frame(keep = 1:2)
  state <- sj_state()
  state$u_rrnames$labels <- "keep"
  state$u_rrdfs$keep <- existing
  shiny::testServer(richStudio::saveTabServer, args = state, {
    session$setInputs(load_session_file = list(name = "old.rds", datapath = rds))
    session$setInputs(load_session = 1L)
    session$setInputs(load_session_file = list(name = "old.RDS", datapath = rds))
    session$setInputs(load_session = 2L)
    session$setInputs(load_session_file = list(name = "renamed.json", datapath = disguised))
    session$setInputs(load_session = 3L)
  })
  expect_length(messages, 3L)
  expect_true(all(grepl("convert-trusted-session.R", messages, fixed = TRUE)))
  expect_identical(shiny::isolate(state$u_rrnames$labels), "keep")
  expect_identical(shiny::isolate(state$u_rrdfs$keep), existing)
  expect_identical(shiny::isolate(state$u_degnames$labels), character())
  expect_null(shiny::isolate(state$u_degdfs[["d\u00e9g1"]]))
})

test_that("no package function can deserialize R objects", {
  ns <- asNamespace("richStudio")
  banned <- c("readRDS", "unserialize", "load", "attach", "readRDX")
  offenders <- Filter(function(name) {
    f <- get(name, envir = ns)
    is.function(f) && any(banned %in% all.names(body(f)))
  }, ls(ns, all.names = TRUE))
  expect_identical(offenders, character())
})

test_that("save UI offers JSON only and the load input accepts only JSON", {
  html <- as.character(richStudio::saveTabUI("persist", "saved-analysis"))
  expect_false(grepl("save_format", html, fixed = TRUE))
  expect_false(grepl("RDS (Recommended)", html, fixed = TRUE))
  expect_match(html, 'accept=".json,.JSON"', fixed = TRUE)
})

test_that("converter turns a trusted RDS into JSON the app loads identically", {
  script <- testthat::test_path("..", "..", "scripts", "convert-trusted-session.R")
  testthat::skip_if_not(file.exists(script), "converter script is not part of the installed package")
  script <- normalizePath(script)
  session <- sj_fixture()
  rds <- withr::local_tempfile(fileext = ".rds")
  out <- withr::local_tempfile(fileext = ".json")
  saveRDS(session, rds)
  run <- function(...) suppressWarnings(system2(
    file.path(R.home("bin"), "Rscript"), c("--vanilla", shQuote(script), ...),
    stdout = TRUE, stderr = TRUE
  ))

  result <- run(shQuote(rds), shQuote(out))
  expect_null(attr(result, "status"))
  restored <- sj_read_dfs(sj_load(out))
  for (n in names(session$rrdfs)) expect_identical(restored$rr[[n]], session$rrdfs[[n]])
  for (n in names(session$degdfs)) expect_identical(restored$deg[[n]], session$degdfs[[n]])

  before <- unname(tools::md5sum(out))
  refused <- run(shQuote(rds), shQuote(out))
  expect_gt(attr(refused, "status"), 0L)
  expect_match(paste(refused, collapse = "\n"), "Refusing to overwrite", fixed = TRUE)
  expect_identical(unname(tools::md5sum(out)), before)

  bogus <- withr::local_tempfile(fileext = ".rds")
  bogus_out <- withr::local_tempfile(fileext = ".json")
  saveRDS(list(not = "a session"), bogus)
  rejected <- run(shQuote(bogus), shQuote(bogus_out))
  expect_gt(attr(rejected, "status"), 0L)
  expect_false(file.exists(bogus_out))
})
