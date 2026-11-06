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
  expect_identical(a, b)
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
  expect_equal(annotation_cache_stats()$disk_hits, 1L)
  expect_equal(bitwAnd(as.integer(file.info(w$cache)$mode), 63L), 0L)
})

test_that("any key component change is a miss, including GO.db and richR versions", {
  cache_world()
  st <- mock_world()
  quiet(richstudio_build_annotation("human", "SYMBOL", "GO"))
  quiet(richstudio_build_annotation("human", "SYMBOL", "GO"))
  expect_identical(st$builds, 1L)
  for (change in list(list(GO.db = "2.0"), list(AnnotationDbi = "9"), list(richR = "0.2.0"), list(org.Fake.eg.db = "7"))) {
    st$versions <- change
    annotation_cache_reset(memory_only = TRUE)
    before <- st$builds
    quiet(richstudio_build_annotation("human", "SYMBOL", "GO"))
    expect_identical(st$builds, before + 1L, info = names(change))
  }
  st$versions <- list()
  annotation_cache_reset(memory_only = TRUE)
  before <- st$builds
  quiet(richstudio_build_annotation("mouse", "SYMBOL", "GO"))
  quiet(richstudio_build_annotation("human", "ENTREZID", "GO"))
  quiet(richstudio_build_annotation("human", "SYMBOL", "KEGG"))
  expect_identical(st$builds, before + 3L)
})

test_that("reactome.db is part of the Reactome key only", {
  cache_world()
  st <- mock_world()
  quiet(richstudio_build_annotation("human", "SYMBOL", "Reactome"))
  st$versions <- list(reactome.db = "9.9")
  annotation_cache_reset(memory_only = TRUE)
  quiet(richstudio_build_annotation("human", "SYMBOL", "Reactome"))
  expect_identical(st$builds, 2L)
  quiet(richstudio_build_annotation("human", "SYMBOL", "GO"))
  annotation_cache_reset(memory_only = TRUE)
  st$versions <- list(reactome.db = "1.1")
  quiet(richstudio_build_annotation("human", "SYMBOL", "GO"))
  expect_identical(st$builds, 3L)
})

test_that("a corrupt or truncated file is rebuilt and overwritten without an error", {
  w <- cache_world()
  st <- mock_world()
  quiet(richstudio_build_annotation("human", "SYMBOL", "GO"))
  f <- list.files(w$cache, pattern = ANNOTATION_CACHE_FILE_RE, full.names = TRUE)
  writeBin(readBin(f, "raw", 20L), f)
  annotation_cache_reset(memory_only = TRUE)
  expect_no_error(quiet(richstudio_build_annotation("human", "SYMBOL", "GO")))
  expect_identical(st$builds, 2L)
  expect_gt(file.size(f), 100)
  saveRDS(list(key = "other", annot = fake_annot()), f)
  annotation_cache_reset(memory_only = TRUE)
  quiet(richstudio_build_annotation("human", "SYMBOL", "GO"))
  expect_identical(st$builds, 3L)
  saveRDS(list(key = "x", annot = "not an annot"), f)
  annotation_cache_reset(memory_only = TRUE)
  quiet(richstudio_build_annotation("human", "SYMBOL", "GO"))
  expect_identical(st$builds, 4L)
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

test_that("the disk cache is bounded by entry count and bytes, oldest first", {
  w <- cache_world()
  st <- mock_world()
  withr::local_options(richstudio.annotation_cache_max_entries = 2L)
  for (sp in c("human", "mouse", "rat")) {
    quiet(richstudio_build_annotation(sp, "SYMBOL", "GO"))
    Sys.sleep(1.1)
  }
  files <- list.files(w$cache, pattern = ANNOTATION_CACHE_FILE_RE, full.names = TRUE)
  expect_length(files, 2L)
  expect_equal(annotation_cache_stats()$evictions, 1L)
  withr::local_options(richstudio.annotation_cache_max_entries = 200L, richstudio.annotation_cache_max_bytes = 10)
  quiet(richstudio_build_annotation("pig", "SYMBOL", "GO"))
  expect_length(list.files(w$cache, pattern = ANNOTATION_CACHE_FILE_RE), 0L)
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
