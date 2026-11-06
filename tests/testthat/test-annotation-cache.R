# SPEC-WS-014 M1: Reactome attach and the two-level annotation cache.

fake_annot <- function(n = 3L) {
  methods::new("Annot", species = "human", anntype = "GO", keytype = "SYMBOL",
               annot = data.frame(GeneID = paste0("g", seq_len(n)), GOALL = paste0("GO:", seq_len(n)),
                                  stringsAsFactors = FALSE))
}

# A temporary annotation world: <tmp>/annotation/r4.6-bioc3.23 plus the cache beside it.
cache_world <- function(env = parent.frame()) {
  root <- withr::local_tempdir(.local_envir = env)
  parent <- file.path(root, "annotation")
  dir.create(parent, mode = "0755")
  Sys.chmod(parent, "0755")
  lib <- file.path(parent, "r4.6-bioc3.23")
  dir.create(lib, mode = "0755")
  withr::local_envvar(RICHSTUDIO_ANNOTATION_LIB = lib, .local_envir = env)
  annotation_cache_reset()
  withr::defer(annotation_cache_reset(), envir = env)
  list(parent = parent, lib = lib, cache = file.path(parent, "cache", "r4.6-bioc3.23"))
}

# Mock the version lookup, the organism package and Reactome attach; count real builder calls.
mock_world <- function(env = parent.frame(), versions = list(), attach = NULL) {
  state <- new.env()
  state$builds <- 0L
  state$attached <- character()
  state$versions <- versions
  testthat::local_mocked_bindings(
    annotation_org_package = function(species) "org.Fake.eg.db",
    annotation_package_versions = function(pkgs) vapply(pkgs, function(p) {
      if (!is.null(state$versions[[p]])) state$versions[[p]] else "1.0"
    }, character(1)),
    annotation_remote_sha = function(pkg) "",
    annotation_attach_reactome = function(anntype) { state$attached <- c(state$attached, anntype); invisible(FALSE) },
    .env = env)
  testthat::local_mocked_bindings(
    buildAnnot = function(species, keytype, anntype, ...) { state$builds <- state$builds + 1L; fake_annot() },
    .package = "richR", .env = env)
  state
}

quiet <- function(expr) suppressMessages(expr)

test_that("a memory hit avoids the builder", {
  cache_world()
  st <- mock_world()
  a <- quiet(richstudio_build_annotation("human", "SYMBOL", "GO"))
  b <- quiet(richstudio_build_annotation("human", "SYMBOL", "GO"))
  expect_identical(st$builds, 1L)
  expect_identical(attr(a, "cache_source"), "built")
  expect_identical(attr(b, "cache_source"), "memory")
  expect_identical(a@annot, b@annot)
  s <- annotation_cache_stats()
  expect_equal(c(s$memory_hits, s$misses, s$writes), c(1L, 1L, 1L))
})

test_that("a disk hit after a memory reset (a fresh worker) avoids the builder", {
  w <- cache_world()
  st <- mock_world()
  a <- quiet(richstudio_build_annotation("human", "SYMBOL", "GO"))
  expect_length(list.files(w$cache, pattern = ANNOTATION_CACHE_FILE_RE), 1L)
  annotation_cache_reset()
  b <- quiet(richstudio_build_annotation("human", "SYMBOL", "GO"))
  expect_identical(st$builds, 1L)
  expect_identical(b@annot, a@annot)
  expect_identical(attr(b, "cache_source"), "disk")
  expect_equal(annotation_cache_stats()$disk_hits, 1L)
  expect_equal(bitwAnd(as.integer(file.info(w$cache)$mode), 63L), 0L)
})

test_that("each key component change is a miss; GO.db does not affect a KEGG key", {
  cache_world()
  st <- mock_world()
  sha <- list(richR = "", bioAnno = "")
  schema_now <- ANNOTATION_CACHE_SCHEMA
  r_minor <- "4.6"
  testthat::local_mocked_bindings(
    annotation_remote_sha = function(pkg) sha[[pkg]] %||% "",
    annotation_r_minor = function() r_minor)
  build <- function(anntype = "GO", sp = "human", kt = "SYMBOL") {
    annotation_cache_reset(memory_only = TRUE)
    before <- st$builds
    quiet(richstudio_build_annotation(sp, kt, anntype))
    st$builds - before
  }
  expect_identical(build(), 1L)
  expect_identical(build(), 0L)                       # unchanged key is a hit
  changes <- list(
    function() st$versions <- list(GO.db = "2.0"), function() st$versions <- list(AnnotationDbi = "9"),
    function() st$versions <- list(richR = "0.2.0"), function() st$versions <- list(bioAnno = "1.1"),
    function() st$versions <- list(org.Fake.eg.db = "7"),
    function() { st$versions <- list(); sha$richR <<- "abc" }, function() { sha$richR <<- ""; sha$bioAnno <<- "def" },
    function() { sha$bioAnno <<- ""; r_minor <<- "4.7" })
  for (i in seq_along(changes)) {
    changes[[i]]()
    expect_identical(build(), 1L, info = paste("change", i))
    st$versions <- list(); sha <- list(richR = "", bioAnno = ""); r_minor <- "4.6"
  }
  testthat::local_mocked_bindings(ANNOTATION_CACHE_SCHEMA = "2")
  expect_identical(build(), 1L)
  testthat::local_mocked_bindings(ANNOTATION_CACHE_SCHEMA = "1")
  expect_identical(build(), 0L)
  expect_identical(build(sp = "mouse"), 1L)
  expect_identical(build(kt = "ENTREZID"), 1L)
  expect_identical(build("KEGG"), 1L)
  st$versions <- list(GO.db = "3.0")
  expect_identical(build("KEGG"), 0L)                 # GO.db is not in a KEGG key
  expect_identical(build("GO"), 1L)
  st$versions <- list(reactome.db = "1.1")
  expect_identical(build("GO"), 0L)                   # reactome.db is not in a GO key
  expect_identical(build("Reactome"), 1L)
  st$versions <- list()
  expect_identical(build("Reactome"), 1L)             # reactome.db change is a miss for Reactome
})

test_that("planted bad files are each rejected, rebuilt and replaced by a valid file", {
  w <- cache_world()
  st <- mock_world()
  quiet(richstudio_build_annotation("human", "SYMBOL", "GO"))
  f <- list.files(w$cache, pattern = ANNOTATION_CACHE_FILE_RE, full.names = TRUE)
  expect_match(basename(f), "^[0-9a-f]{32}\\.rds$")
  key <- readRDS(f)$key
  plant <- list(
    truncated = function() writeBin(readBin(f, "raw", 20L), f),
    wrong_class = function() saveRDS(list(key = key, annot = "not an annot"), f),
    zero_rows = function() saveRDS(list(key = key, annot = methods::new("Annot", species = "h", anntype = "GO", keytype = "SYMBOL",
                                                                      annot = data.frame(GeneID = character(), GOALL = character()))), f),
    missing_columns = function() saveRDS(list(key = key, annot = methods::new("Annot", species = "h", anntype = "GO", keytype = "SYMBOL",
                                                                            annot = data.frame(GeneID = "a"))), f),
    wrong_key = function() saveRDS(list(key = "other", annot = fake_annot()), f))
  for (name in names(plant)) {
    plant[[name]]()
    annotation_cache_reset(memory_only = TRUE)
    before <- st$builds
    expect_no_error(quiet(richstudio_build_annotation("human", "SYMBOL", "GO")))
    expect_identical(st$builds, before + 1L, info = name)
    expect_true(annotation_cache_valid(readRDS(f), key), info = name)
  }
})

test_that("writes use a temp name no reader accepts, leave no temp file, and a failed write keeps the old file", {
  w <- cache_world()
  mock_world()
  expect_false(grepl(ANNOTATION_CACHE_FILE_RE, ".tmp-123-abcdefgh"))
  quiet(richstudio_build_annotation("human", "SYMBOL", "GO"))
  expect_length(list.files(w$cache, all.files = TRUE, no.. = TRUE, pattern = "^\\.tmp-"), 0L)
  f <- list.files(w$cache, pattern = ANNOTATION_CACHE_FILE_RE, full.names = TRUE)
  before <- tools::md5sum(f)
  skip_if(Sys.info()[["user"]] == "root")
  Sys.chmod(w$cache, "0500")
  withr::defer(Sys.chmod(w$cache, "0700"))
  expect_false(suppressMessages(annotation_disk_write(w$cache, sub("^annot-(.*)\\.rds$", "\\1", basename(f)), "k", fake_annot())))
  expect_identical(unname(tools::md5sum(f)), unname(before))
})

test_that("the memory level is an LRU of three", {
  cache_world()
  st <- mock_world()
  for (sp in c("human", "mouse", "rat", "zebrafish")) quiet(richstudio_build_annotation(sp, "SYMBOL", "GO", .builder = function(...) fake_annot()))
  expect_length(.annotation_cache$order, 3L)
  # human was the least recently used and was evicted; mouse still hits
  n <- 0L
  counting <- function(...) { n <<- n + 1L; fake_annot() }
  quiet(richstudio_build_annotation("mouse", "SYMBOL", "GO", .builder = counting))
  expect_identical(n, 0L)
  quiet(richstudio_build_annotation("human", "SYMBOL", "GO", .builder = counting))
  expect_identical(n, 1L)
})

test_that("a stub builder never touches the disk cache", {
  w <- cache_world()
  mock_world()
  quiet(richstudio_build_annotation("human", "SYMBOL", "GO", .builder = function(...) fake_annot()))
  expect_false(dir.exists(w$cache))
  expect_equal(annotation_cache_stats()$writes, 0L)
})

test_that("an unset library or unwritable cache builds every time and writes nowhere else", {
  root <- withr::local_tempdir()
  withr::local_envvar(RICHSTUDIO_ANNOTATION_LIB = "")
  annotation_cache_reset()
  st <- mock_world()
  quiet(richstudio_build_annotation("human", "SYMBOL", "GO"))
  quiet(richstudio_build_annotation("human", "SYMBOL", "GO"))
  expect_identical(st$builds, 2L)
  expect_equal(annotation_cache_stats()$disabled, 2L)
  expect_length(list.files(root, all.files = TRUE, no.. = TRUE), 0L)
  annotation_cache_reset()
})

test_that("a symlinked cache directory, a symlinked file and a foreign-named file are never read", {
  w <- cache_world()
  st <- mock_world()
  quiet(richstudio_build_annotation("human", "SYMBOL", "GO"))
  f <- list.files(w$cache, pattern = ANNOTATION_CACHE_FILE_RE, full.names = TRUE)
  # symlinked file
  real <- file.path(w$parent, "elsewhere.rds")
  file.rename(f, real)
  file.symlink(real, f)
  annotation_cache_reset(memory_only = TRUE)
  quiet(richstudio_build_annotation("human", "SYMBOL", "GO"))
  expect_identical(st$builds, 2L)
  expect_equal(annotation_cache_stats()$disk_hits, 0L)
  # foreign-named file: right content, wrong name
  unlink(f)
  file.copy(real, file.path(w$cache, "evil.rds"))
  file.copy(real, file.path(w$parent, paste0(strrep("a", 32), ".rds")))
  annotation_cache_reset(memory_only = TRUE)
  quiet(richstudio_build_annotation("human", "SYMBOL", "GO"))
  expect_equal(annotation_cache_stats()$disk_hits, 0L)
  expect_identical(st$builds, 3L)
  # symlinked cache directory: no disk read or write for that call, analysis still works
  moved <- file.path(w$parent, "cache-real")
  file.rename(file.path(w$parent, "cache"), moved)
  file.symlink(moved, file.path(w$parent, "cache"))
  before_files <- list.files(moved, recursive = TRUE)
  annotation_cache_reset(memory_only = TRUE)
  quiet(richstudio_build_annotation("human", "SYMBOL", "GO"))
  expect_equal(annotation_cache_stats()$disk_hits, 0L)
  expect_gte(annotation_cache_stats()$disabled, 1L)
  expect_identical(list.files(moved, recursive = TRUE), before_files)
})

test_that("a group-writable cache directory disables the disk level for the call", {
  w <- cache_world()
  st <- mock_world()
  quiet(richstudio_build_annotation("human", "SYMBOL", "GO"))
  Sys.chmod(w$cache, "0770")
  annotation_cache_reset(memory_only = TRUE)
  quiet(richstudio_build_annotation("human", "SYMBOL", "GO"))
  expect_identical(st$builds, 2L)
  expect_equal(annotation_cache_stats()$disk_hits, 0L)
})

test_that("eviction keeps the bound, never the just-written entry, and sweeps stale temp files", {
  w <- cache_world()
  st <- mock_world()
  quiet(richstudio_build_annotation("human", "SYMBOL", "GO"))
  dir <- w$cache
  # 198 filler entries, oldest first
  for (i in seq_len(198L)) {
    f <- file.path(dir, sprintf("%032x.rds", i))
    saveRDS(list(key = "k", annot = fake_annot()), f)
    Sys.setFileTime(f, Sys.time() - 10000 + i)
  }
  expect_length(list.files(dir, pattern = ANNOTATION_CACHE_FILE_RE), 199L)
  old_tmp <- file.path(dir, ".tmp-1-old"); young_tmp <- file.path(dir, ".tmp-2-young")
  writeLines("x", old_tmp); writeLines("x", young_tmp)
  Sys.setFileTime(old_tmp, Sys.time() - 7200)
  quiet(richstudio_build_annotation("mouse", "SYMBOL", "GO"))
  expect_length(list.files(dir, pattern = ANNOTATION_CACHE_FILE_RE), 200L)
  expect_false(file.exists(old_tmp)); expect_true(file.exists(young_tmp))
  quiet(richstudio_build_annotation("rat", "SYMBOL", "GO"))
  files <- list.files(dir, pattern = ANNOTATION_CACHE_FILE_RE, full.names = TRUE)
  expect_length(files, 200L)
  expect_equal(annotation_cache_stats()$evictions, 1L)
  expect_false(file.exists(file.path(dir, sprintf("%032x.rds", 1L))))   # oldest went first
  # byte bound: just-written entry survives even when it alone exceeds the bound
  withr::local_options(richstudio.annotation_cache_max_bytes = 10)
  annotation_cache_reset(memory_only = TRUE)
  quiet(richstudio_build_annotation("pig", "SYMBOL", "GO"))
  left <- list.files(dir, pattern = ANNOTATION_CACHE_FILE_RE)
  expect_length(left, 1L)
  expect_true(grepl(ANNOTATION_CACHE_FILE_RE, left))
  annotation_cache_reset(memory_only = TRUE)
  before <- st$builds
  quiet(richstudio_build_annotation("pig", "SYMBOL", "GO"))
  expect_identical(st$builds, before)
})

test_that("Reactome attach happens on a miss and is not needed on a hit", {
  cache_world()
  st <- mock_world()
  quiet(richstudio_build_annotation("human", "SYMBOL", "Reactome"))
  expect_identical(st$attached, "Reactome")
  quiet(richstudio_build_annotation("human", "SYMBOL", "Reactome"))
  expect_identical(st$attached, "Reactome")
})

test_that("annotation_attach_reactome attaches an installed reactome.db and ignores other types", {
  expect_false(annotation_attach_reactome("GO"))
  attached <- 0L
  testthat::local_mocked_bindings(annotation_reactome_installed = function() TRUE,
                                  annotation_attach_ns = function(pkg) { attached <<- attached + 1L; invisible(NULL) })
  expect_true(annotation_attach_reactome("Reactome"))
  expect_identical(attached, 1L)
  testthat::local_mocked_bindings(annotation_reactome_installed = function() FALSE)
  expect_false(annotation_attach_reactome("Reactome"))
})

test_that("the background check and the analysis path share one builder and one cache", {
  expect_identical(formals(shiny_enrich)$annotation_builder, quote(richstudio_build_annotation))
  expect_identical(formals(run_enrichment_jobs)$annotation_builder, quote(richstudio_build_annotation))
  expect_identical(formals(enrich_tab_server)$annotation_builder, quote(richstudio_build_annotation))
  cache_world()
  st <- mock_world()
  settings <- list(species = "human", keytype = "SYMBOL", anntype = "GO", ontology = "BP")
  quiet(enrichment_background_check_job(richstudio_build_annotation, settings, c("g1", "g2"), list(c("g1"))))
  quiet(richstudio_build_annotation(species = "human", keytype = "SYMBOL", anntype = "GO"))
  expect_identical(st$builds, 1L)
})

test_that("disabled-cache behaviour equals a plain buildAnnot call", {
  withr::local_envvar(RICHSTUDIO_ANNOTATION_LIB = "")
  annotation_cache_reset()
  mock_world()
  direct <- richR::buildAnnot(species = "human", keytype = "SYMBOL", anntype = "GO")
  via <- quiet(richstudio_build_annotation("human", "SYMBOL", "GO"))
  expect_identical(via@annot, direct@annot)
  annotation_cache_reset()
})

test_that("a persistent single multisession worker reuses the memory level across futures", {
  skip_on_cran()
  skip_if_not_installed("pkgload")
  skip_if_not_installed("future")
  root <- normalizePath(testthat::test_path("..", ".."))
  skip_if_not(file.exists(file.path(root, "DESCRIPTION")))
  old <- future::plan(future::multisession, workers = 1L)
  withr::defer(future::plan(old))
  stub_run <- function(root) {
    if (!exists(".ws014_builds", envir = globalenv())) {
      suppressMessages(pkgload::load_all(root, quiet = TRUE, export_all = TRUE))
      assign(".ws014_builds", 0L, envir = globalenv())
    }
    mk <- function(species, keytype, anntype) {
      assign(".ws014_builds", get(".ws014_builds", envir = globalenv()) + 1L, envir = globalenv())
      methods::new("Annot", species = species, anntype = anntype, keytype = keytype,
                   annot = data.frame(GeneID = "a", GOALL = "b"))
    }
    ns <- asNamespace("richStudio")
    suppressMessages(ns$richstudio_build_annotation("human", "SYMBOL", "GO", .builder = mk))
    get(".ws014_builds", envir = globalenv())
  }
  first <- future::value(future::future(stub_run(root), globals = list(stub_run = stub_run, root = root)))
  second <- future::value(future::future(stub_run(root), globals = list(stub_run = stub_run, root = root)))
  expect_identical(first, 1L)
  expect_identical(second, 1L)
})

test_that("no app source other than annotation_cache.R defaults to a direct richR::buildAnnot", {
  root <- normalizePath(testthat::test_path("..", ".."))
  skip_if_not(dir.exists(file.path(root, "R")))
  files <- list.files(file.path(root, "R"), pattern = "\\.R$", full.names = TRUE)
  files <- files[basename(files) != "annotation_cache.R"]
  hits <- Filter(function(f) any(grepl("annotation_builder\\s*=\\s*richR::buildAnnot", readLines(f, warn = FALSE))), files)
  expect_identical(hits, character())
})

fresh_body <- function(root, lib, builds_file) {
  suppressMessages(pkgload::load_all(root, quiet = TRUE))
  Sys.setenv(RICHSTUDIO_ANNOTATION_LIB = lib)
  fake <- methods::new("Annot", species = "human", anntype = "GO", keytype = "SYMBOL",
                       annot = data.frame(GeneID = c("a", "b"), GOALL = c("x", "y")))
  testthat::with_mocked_bindings(
    testthat::with_mocked_bindings(
      {
        x <- suppressMessages(richstudio_build_annotation("human", "SYMBOL", "GO"))
        list(source = attr(x, "cache_source"), builds = length(readLines(builds_file, warn = FALSE)),
             stats = annotation_cache_stats(), pid = Sys.getpid())
      },
      buildAnnot = function(...) { write("b", builds_file, append = TRUE); Sys.sleep(0.5); fake }, .package = "richR"),
    annotation_org_package = function(species) "org.Fake.eg.db",
    annotation_package_versions = function(pkgs) stats::setNames(rep("1.0", length(pkgs)), pkgs),
    annotation_remote_sha = function(pkg) "", annotation_attach_reactome = function(anntype) invisible(FALSE),
    .package = "richStudio")
}

fresh_process <- function(root, lib, builds_file) {
  callr::r(fresh_body, args = list(root, lib, builds_file))
}

test_that("a genuinely new multisession worker process is served from disk without a build", {
  skip_on_cran()
  skip_if_not_installed("pkgload")
  skip_if_not_installed("future")
  root <- normalizePath(testthat::test_path("..", ".."))
  skip_if_not(file.exists(file.path(root, "DESCRIPTION")))
  w <- cache_world()
  builds <- withr::local_tempfile()
  writeLines(character(), builds)
  old <- future::plan()
  withr::defer(future::plan(old))
  run <- function() future::value(future::future(fresh_body(root, lib, builds),
                                                 globals = list(fresh_body = fresh_body, root = root, lib = w$lib, builds = builds),
                                                 seed = TRUE))
  future::plan(future::multisession, workers = 1L)
  first <- run()
  future::plan(future::sequential)
  future::plan(future::multisession, workers = 2L)   # a different spec: a brand-new cluster of fresh processes
  second <- run()
  expect_false(identical(first$pid, second$pid))
  expect_identical(first$source, "built")
  expect_identical(second$source, "disk")
  expect_identical(second$builds, 1L)
})

test_that("a fresh process is served from disk, and two racing processes both succeed", {
  skip_on_cran()
  skip_if_not_installed("callr")
  skip_if_not_installed("pkgload")
  root <- normalizePath(testthat::test_path("..", ".."))
  skip_if_not(file.exists(file.path(root, "DESCRIPTION")))
  w <- cache_world()
  builds <- withr::local_tempfile()
  writeLines(character(), builds)
  first <- fresh_process(root, w$lib, builds)
  expect_identical(first$source, "built")
  second <- fresh_process(root, w$lib, builds)
  expect_identical(second$source, "disk")
  expect_identical(second$builds, 1L)                       # no second build
  expect_equal(second$stats$disk_hits, 1L)
  # race: remove the entry, run two processes at once
  unlink(list.files(w$cache, full.names = TRUE))
  p1 <- callr::r_bg(function(f, ...) f(...), args = list(fresh_process, root, w$lib, builds), package = FALSE)
  p2 <- callr::r_bg(function(f, ...) f(...), args = list(fresh_process, root, w$lib, builds), package = FALSE)
  p1$wait(); p2$wait()
  expect_length(list.files(w$cache, pattern = ANNOTATION_CACHE_FILE_RE), 1L)
  expect_length(list.files(w$cache, all.files = TRUE, pattern = "^\\.tmp-"), 0L)
  expect_true(annotation_cache_valid(readRDS(list.files(w$cache, full.names = TRUE, pattern = ANNOTATION_CACHE_FILE_RE)),
                                     readRDS(list.files(w$cache, full.names = TRUE, pattern = ANNOTATION_CACHE_FILE_RE))$key))
})
