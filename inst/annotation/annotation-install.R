# SPEC-WS-014 annotation installer: base-R worker.
#
# One phase per process, driven by annotation-install.sh (the bash supervisor):
#   Rscript annotation-install.R <phase> <package> <staging dir>
#   phases: prepare | download | install | validate | finalize
# Utility commands (no supervisor, no lock):
#   print-plan | check-url <url> | cap | check-lib <dir> | verify-env <release dir> <annotation lib>
#
# Base R only (utils, tools). curl and R CMD INSTALL are system tools. The package
# name arrives from the supervisor and is re-validated against the allowlist here;
# no URL or path ever comes from the caller (REQ-007, REQ-018).
#
# Exit codes (mapped to reason codes by the supervisor):
#   0 ok  10 no_network  11 checksum_mismatch  12 not_enough_disk
#   13 dependency_missing  14 entry_invalid  15 index_no_md5  16 unavailable
#   17 timed_out  20 package already present and valid  1 internal_error

BIOC_VERSION <- "3.23"
PROD_REPO <- "https://bioconductor.org/packages/3.23/data/annotation"
PROD_HOST <- "bioconductor.org"
FREE_SPACE_FLOOR <- 2 * 1024^3
CAP_FLOOR <- 5 * 1024^3
NAME_RE <- "^[A-Za-z][A-Za-z0-9.]*$"
# Lead-measured on hurlab (human fixture, richGO defaults): 298 rows with Padj < 0.05; the floor is
# 50% of that (149). GO:0006915 can never be reported (1766 annotated BP genes > maxGSSize 500),
# so the expected term, among the five best by Padj, is the intrinsic apoptotic signaling pathway.
FIXTURE_MIN_ROWS <- 149L
INSTALLED_COLS <- c("package", "version", "sha256", "md5", "source_url", "installed_at")

# ---- plumbing -------------------------------------------------------------

script_dir <- function() {
  if (exists(".annotation_script_dir", envir = globalenv(), inherits = FALSE)) {
    return(get(".annotation_script_dir", envir = globalenv()))
  }
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  if (length(f)) dirname(normalizePath(f[[1L]])) else getwd()
}

# Stop with a specific worker exit code.
bail <- function(code, msg) {
  stop(structure(class = c("annotation_exit", "error", "condition"),
                 list(message = msg, call = NULL, code = code)))
}

lib_name_expected <- function() {
  paste0("r", R.version$major, ".", strsplit(R.version$minor, ".", fixed = TRUE)[[1L]][[1L]],
         "-bioc", BIOC_VERSION)
}

# The test-only configuration is honoured only when BOTH variables are set (REQ-010).
test_mode_active <- function() {
  identical(Sys.getenv("RICHSTUDIO_ANNOTATION_TEST_MODE"), "1") &&
    nzchar(Sys.getenv("RICHSTUDIO_ANNOTATION_TEST_CONFIG"))
}

load_config <- function() {
  cfg <- list(repo = PROD_REPO,
              allowlist = normalizePath(file.path(script_dir(), "..", "extdata", "annotation-allowlist.tsv"),
                                        mustWork = FALSE),
              downloader = "curl", probe = "real", free_space_bytes = NA_real_,
              finalize_pause = 0, test_mode = FALSE)
  if (!test_mode_active()) return(cfg)
  path <- Sys.getenv("RICHSTUDIO_ANNOTATION_TEST_CONFIG")
  if (!file.exists(path)) bail(1L, paste("test config not readable:", path))
  d <- read.dcf(path)
  get <- function(k) if (k %in% colnames(d) && !is.na(d[1L, k])) unname(d[1L, k]) else NULL
  if (!is.null(v <- get("repo"))) cfg$repo <- v
  if (!is.null(v <- get("allowlist"))) cfg$allowlist <- v
  if (!is.null(v <- get("downloader"))) cfg$downloader <- v
  if (!is.null(v <- get("probe"))) cfg$probe <- v
  if (!is.null(v <- get("free_space_bytes"))) cfg$free_space_bytes <- as.numeric(v)
  if (!is.null(v <- get("finalize_pause"))) cfg$finalize_pause <- as.numeric(v)
  cfg$test_mode <- TRUE
  cfg
}

sh <- function(x) shQuote(x)

is_link <- function(p) { r <- Sys.readlink(p); !is.na(r) && nzchar(r) }
exists_or_link <- function(p) file.exists(p) || is_link(p)

# ---- allowlist and resolver data ---------------------------------------------

read_allowlist <- function(path) {
  if (!file.exists(path)) bail(1L, paste("allowlist not found:", path))
  al <- utils::read.delim(path, sep = "\t", quote = "", comment.char = "", colClasses = "character",
                          na.strings = character(), check.names = FALSE)
  need <- c("species", "package", "kind", "status", "preinstall", "est_mb", "inst_mb",
            "reactome_supported", "reason")
  if (!all(need %in% names(al))) bail(1L, "allowlist is missing required columns")
  al
}

allow_entry <- function(al, pkg) {
  if (!is.character(pkg) || length(pkg) != 1L || !grepl(NAME_RE, pkg)) return(NULL)
  hit <- al[al$package == pkg & al$status == "available", , drop = FALSE]
  if (!nrow(hit)) NULL else hit[1L, , drop = FALSE]
}

# Library size cap = max(5 GiB, 2 x sum(inst_mb of available rows)), MiB units (OD-5, REQ-008).
allow_cap_bytes <- function(al) {
  avail <- al[al$status == "available", , drop = FALSE]
  mb <- suppressWarnings(as.numeric(avail$inst_mb))
  if (!nrow(avail) || anyNA(mb)) {
    bail(1L, paste0("inst_mb is not measured for: ",
                    paste(avail$package[is.na(mb)], collapse = ", "),
                    " (REQ-008: measured installed sizes are required)"))
  }
  max(CAP_FLOOR, 2 * sum(mb) * 1024^2)
}

# ---- URL policy (REQ-007) ----------------------------------------------------

# Returns "" when acceptable, otherwise a named reason.
url_problem <- function(url, allow_file = FALSE) {
  if (!is.character(url) || length(url) != 1L || is.na(url) || !nzchar(url)) return("empty_url")
  m <- regmatches(url, regexec("^([A-Za-z][A-Za-z0-9+.-]*)://([^/?#:@]*)(:[0-9]+)?([/?#].*)?$", url))[[1L]]
  if (!length(m)) return("malformed_url")
  scheme <- tolower(m[[2L]])
  host <- tolower(m[[3L]])
  if (scheme == "file" && allow_file) return("")
  if (scheme != "https") return(paste0("scheme_not_https:", scheme))
  if (!identical(host, PROD_HOST)) return(paste0("host_not_", PROD_HOST, ":", host))
  ""
}

# ---- downloader --------------------------------------------------------------

# Returns list(status, final_url). The argument vector is the production curl policy; a test
# downloader receives the same vector.
fetch_url <- function(cfg, url, dest, max_time, errfile) {
  bad <- url_problem(url, allow_file = cfg$test_mode)
  if (nzchar(bad)) bail(1L, paste("refused URL:", bad))
  args <- c("--fail", "--silent", "--show-error", "--proto", "=https", "--proto-redir", "=https",
            "--max-redirs", "3", "--max-time", as.character(max_time),
            "--write-out", "%{url_effective}", "--output", dest, url)
  out <- suppressWarnings(system2(cfg$downloader, sh(args), stdout = TRUE, stderr = errfile))
  status <- attr(out, "status")
  status <- if (is.null(status)) 0L else as.integer(status)
  list(status = status, final_url = paste(out, collapse = ""))
}

phase_max_time <- function() {
  lim <- suppressWarnings(as.numeric(Sys.getenv("RICHSTUDIO_PHASE_LIMIT", "1200")))
  if (is.na(lim)) lim <- 1200
  if (lim >= 60) lim - 30 else max(1, lim - 1)
}

download_checked <- function(cfg, url, dest, errfile) {
  res <- fetch_url(cfg, url, dest, phase_max_time(), errfile)
  if (res$status != 0L) {
    msg <- if (file.exists(errfile)) paste(utils::tail(readLines(errfile, warn = FALSE), 3L), collapse = " ") else ""
    bail(if (res$status == 28L) 17L else 10L, paste0("download failed (curl exit ", res$status, "): ", msg))
  }
  bad <- url_problem(res$final_url, allow_file = cfg$test_mode)
  if (nzchar(bad)) {
    unlink(dest)
    bail(1L, paste0("rejected redirect target (", bad, "): ", res$final_url))
  }
  res$final_url
}

# ---- library and staging checks ---------------------------------------------

path_problems <- function(dir, label) {
  p <- character()
  info <- file.info(dir)
  if (is.na(info$isdir) || !info$isdir) return(paste0(label, " is not a directory: ", dir))
  if (is_link(dir)) p <- c(p, paste0(label, " is a symlink: ", dir))
  me <- Sys.info()[["effective_user"]]
  if (!identical(unname(info$uname), unname(me))) {
    p <- c(p, paste0(label, " is owned by ", info$uname, ", not by ", me, ": ", dir))
  }
  if (bitwAnd(as.integer(info$mode), 18L) != 0L) {
    p <- c(p, paste0(label, " is group- or world-writable (mode ", format(info$mode), "): ", dir))
  }
  p
}

lib_problems <- function(lib) {
  p <- character()
  if (!is.character(lib) || length(lib) != 1L || is.na(lib) || !nzchar(lib)) return("library path is empty")
  if (!startsWith(lib, "/")) p <- c(p, "library path is not absolute")
  if (any(strsplit(lib, "/", fixed = TRUE)[[1L]] == "..")) p <- c(p, "library path contains '..'")
  if (startsWith(lib, "/opt/richStudio/")) p <- c(p, "library path is inside the sealed release tree")
  name <- basename(lib)
  if (!grepl("^r[0-9]+\\.[0-9]+-bioc[0-9]+\\.[0-9]+$", name)) {
    p <- c(p, "last path component is not r<R minor>-bioc<Bioc version>")
  } else if (!identical(name, lib_name_expected())) {
    p <- c(p, paste0("library is ", name, " but the running R/Bioconductor needs ", lib_name_expected()))
  }
  if (length(p)) return(p)
  c(path_problems(lib, "annotation library"), path_problems(dirname(lib), "annotation parent"))
}

staging_problems <- function(staging, lib, pkg) {
  if (!identical(dirname(staging), lib)) return("staging is not directly inside the library")
  if (!grepl(paste0("^\\.staging-", gsub(".", "\\.", pkg, fixed = TRUE), "-[A-Za-z0-9._]+$"), basename(staging))) {
    return("staging name is not .staging-<package>-<token>")
  }
  info <- file.info(staging)
  if (is.na(info$isdir) || !info$isdir || is_link(staging)) return("staging is not a real directory")
  ""
}

free_bytes <- function(cfg, lib) {
  if (!is.na(cfg$free_space_bytes)) return(cfg$free_space_bytes)
  out <- suppressWarnings(system2("df", c("-Pk", sh(lib)), stdout = TRUE, stderr = FALSE))
  f <- strsplit(trimws(out[[length(out)]]), "[[:space:]]+")[[1L]]
  as.numeric(f[[4L]]) * 1024
}

lib_bytes <- function(lib) {
  entries <- list.files(lib, all.files = TRUE, no.. = TRUE)
  entries <- entries[!startsWith(entries, ".staging-")]
  paths <- file.path(lib, entries)
  # The annotation cache (<parent>/cache/<library name>) counts against the same cap.
  cache <- file.path(dirname(lib), "cache", basename(lib))
  if (dir.exists(cache)) paths <- c(paths, cache)
  if (!length(paths)) return(0)
  out <- suppressWarnings(system2("du", c("-sk", sh(paths)), stdout = TRUE, stderr = FALSE))
  sum(as.numeric(sub("\\s.*$", "", out)), na.rm = TRUE) * 1024
}

# Existing entry: valid DESCRIPTION, built for this R, consistent with INSTALLED.tsv, loadable.
entry_state <- function(lib, pkg) {
  dir <- file.path(lib, pkg)
  desc_file <- file.path(dir, "DESCRIPTION")
  if (!file.exists(desc_file)) return(list(ok = FALSE, code = 14L, msg = paste("entry has no DESCRIPTION:", dir)))
  d <- tryCatch(read.dcf(desc_file), error = function(e) NULL)
  if (is.null(d) || !all(c("Package", "Version") %in% colnames(d))) {
    return(list(ok = FALSE, code = 14L, msg = paste("unreadable DESCRIPTION:", desc_file)))
  }
  if (!identical(unname(d[1L, "Package"]), pkg)) {
    return(list(ok = FALSE, code = 14L, msg = paste0("DESCRIPTION Package is ", d[1L, "Package"], ", expected ", pkg)))
  }
  built <- if ("Built" %in% colnames(d)) d[1L, "Built"] else ""
  want <- paste0("R ", R.version$major, ".", strsplit(R.version$minor, ".", fixed = TRUE)[[1L]][[1L]])
  if (is.na(built) || !startsWith(built, want)) {
    return(list(ok = FALSE, code = 14L, msg = paste0("entry is built for '", built, "', not ", want)))
  }
  tsv <- file.path(lib, "INSTALLED.tsv")
  if (file.exists(tsv)) {
    rows <- utils::read.delim(tsv, sep = "\t", quote = "", colClasses = "character", na.strings = character())
    hit <- rows[rows$package == pkg, , drop = FALSE]
    if (nrow(hit) && !identical(hit$version[[nrow(hit)]], unname(d[1L, "Version"]))) {
      return(list(ok = FALSE, code = 14L,
                  msg = paste0("DESCRIPTION version ", d[1L, "Version"], " differs from INSTALLED.tsv ", hit$version[[nrow(hit)]])))
    }
  }
  ok <- tryCatch({ loadNamespace(pkg, lib.loc = c(lib, .libPaths())); TRUE }, error = function(e) conditionMessage(e))
  if (!isTRUE(ok)) {
    code <- if (grepl("there is no package called|not available", ok)) 13L else 14L
    return(list(ok = FALSE, code = code, msg = paste("entry does not load:", ok)))
  }
  list(ok = TRUE, code = 0L, msg = "")
}

# ---- phases ------------------------------------------------------------------

phase_context <- function(pkg, staging) {
  cfg <- load_config()
  lib <- Sys.getenv("RICHSTUDIO_ANNOTATION_LIB")
  lib <- sub("/+$", "", lib)
  probs <- lib_problems(lib)
  if (length(probs)) bail(1L, paste("annotation library rejected:", paste(probs, collapse = "; ")))
  al <- read_allowlist(cfg$allowlist)
  entry <- allow_entry(al, pkg)
  if (is.null(entry)) bail(16L, paste0("package is not an available allowlist entry: ", pkg))
  bad <- staging_problems(staging, lib, pkg)
  if (nzchar(bad)) bail(1L, bad)
  list(cfg = cfg, lib = lib, al = al, entry = entry, pkg = pkg, staging = staging,
       plan = file.path(staging, "plan"), tar_info = file.path(staging, "download.info"))
}

read_kv <- function(path) {
  x <- readLines(path, warn = FALSE)
  k <- sub("=.*$", "", x)
  v <- sub("^[^=]*=", "", x)
  stats::setNames(as.list(v), k)
}

phase_prepare <- function(ctx) {
  st <- entry_dir_state(ctx)
  if (!is.null(st)) return(st)
  free <- free_bytes(ctx$cfg, ctx$lib)
  if (free < FREE_SPACE_FLOOR) bail(12L, sprintf("free space %.0f bytes is below the 2 GiB floor", free))
  cap <- allow_cap_bytes(ctx$al)
  est <- suppressWarnings(as.numeric(ctx$entry$est_mb)) * 1024^2
  if (is.na(est)) bail(1L, paste("est_mb is not numeric for", ctx$pkg))
  used <- lib_bytes(ctx$lib)
  if (used + est > cap) bail(12L, sprintf("library %.0f + estimate %.0f bytes exceeds the %.0f byte cap", used, est, cap))
  index_url <- paste0(ctx$cfg$repo, "/src/contrib/PACKAGES")
  index <- file.path(ctx$staging, "PACKAGES")
  download_checked(ctx$cfg, index_url, index, file.path(ctx$staging, "index.err"))
  d <- tryCatch(read.dcf(index, fields = c("Package", "Version", "MD5sum")), error = function(e) NULL)
  if (is.null(d)) bail(1L, "repository index could not be parsed")
  row <- which(d[, "Package"] == ctx$pkg)
  if (!length(row)) bail(16L, paste0(ctx$pkg, " is not in the repository index"))
  row <- row[[1L]]
  ver <- d[row, "Version"]
  md5 <- d[row, "MD5sum"]
  if (is.na(md5) || !nzchar(md5)) bail(15L, paste0("index entry for ", ctx$pkg, " has no MD5sum"))
  if (is.na(ver) || !grepl("^[0-9][0-9A-Za-z.-]*$", ver)) bail(1L, "index version has an unexpected shape")
  if (!grepl("^[0-9a-f]{32}$", md5)) bail(1L, "index MD5sum has an unexpected shape")
  file <- paste0(ctx$pkg, "_", ver, ".tar.gz")
  writeLines(c(paste0("version=", ver), paste0("md5=", md5), paste0("file=", file),
               paste0("url=", ctx$cfg$repo, "/src/contrib/", file)), ctx$plan)
  invisible(0L)
}

# Returns NULL when the package must be installed, otherwise the exit code to use.
entry_dir_state <- function(ctx) {
  if (!exists_or_link(file.path(ctx$lib, ctx$pkg))) return(NULL)
  st <- entry_state(ctx$lib, ctx$pkg)
  if (isTRUE(st$ok)) {
    message("annotation-install: ", ctx$pkg, " is already installed and valid")
    return(20L)
  }
  bail(st$code, st$msg)
}

phase_download <- function(ctx) {
  plan <- read_kv(ctx$plan)
  dest <- file.path(ctx$staging, plan$file)
  final <- download_checked(ctx$cfg, plan$url, dest, file.path(ctx$staging, "download.err"))
  got <- unname(tools::md5sum(dest))
  if (is.na(got) || !identical(got, plan$md5)) {
    unlink(dest)
    bail(11L, paste0("MD5 mismatch for ", plan$file, ": index ", plan$md5, ", got ", got))
  }
  sha <- file_sha256(dest)
  writeLines(c(paste0("sha256=", sha), paste0("final_url=", final)), ctx$tar_info)
  invisible(0L)
}

file_sha256 <- function(path) {
  if (exists("sha256sum", envir = asNamespace("tools"), inherits = FALSE)) {
    return(unname(get("sha256sum", envir = asNamespace("tools"))(path)))
  }
  out <- system2("sha256sum", sh(path), stdout = TRUE)
  sub("\\s.*$", "", out[[1L]])
}

phase_install <- function(ctx) {
  plan <- read_kv(ctx$plan)
  tarball <- file.path(ctx$staging, plan$file)
  if (!file.exists(tarball)) bail(1L, "downloaded tarball is missing from staging")
  stlib <- file.path(ctx$staging, "lib")
  tmp <- file.path(ctx$staging, "tmp")
  dir.create(stlib, showWarnings = FALSE)
  dir.create(tmp, showWarnings = FALSE)
  log <- file.path(ctx$staging, "install.log")
  status <- system2(file.path(R.home("bin"), "R"),
                    c("CMD", "INSTALL", "--no-test-load", paste0("--library=", sh(stlib)), sh(tarball)),
                    stdout = log, stderr = log, env = paste0("TMPDIR=", sh(tmp)))
  if (!identical(as.integer(status), 0L)) {
    out <- readLines(log, warn = FALSE)
    message(paste(utils::tail(out, 25L), collapse = "\n"))
    code <- if (any(grepl("there is no package called|dependency .* is not available", out))) 13L else 1L
    bail(code, paste0("R CMD INSTALL failed with status ", status))
  }
  invisible(0L)
}

# Test-only probe for packages that are not real annotation databases.
probe_ok <- function(cfg, pkg, kind, lib) {
  if (identical(cfg$probe, "stub") && cfg$test_mode) {
    f <- tryCatch(getExportedValue(pkg, "probe_ok"), error = function(e) NULL)
    return(is.function(f) && isTRUE(f()))
  }
  if (identical(kind, "reactome")) {
    obj <- getExportedValue(pkg, "reactomePATHID2EXTID")
    return(length(AnnotationDbi::keys(obj)) > 0L)
  }
  db <- getExportedValue(pkg, pkg)
  length(AnnotationDbi::keys(db, keytype = "ENTREZID")) > 0L
}

phase_validate <- function(ctx) {
  plan <- read_kv(ctx$plan)
  stlib <- file.path(ctx$staging, "lib")
  d <- tryCatch(read.dcf(file.path(stlib, ctx$pkg, "DESCRIPTION")), error = function(e) NULL)
  if (is.null(d)) bail(1L, "installed package has no readable DESCRIPTION in staging")
  if (!identical(unname(d[1L, "Package"]), ctx$pkg) || !identical(unname(d[1L, "Version"]), plan$version)) {
    bail(1L, paste0("staged DESCRIPTION says ", d[1L, "Package"], " ", d[1L, "Version"],
                    ", expected ", ctx$pkg, " ", plan$version))
  }
  res <- tryCatch({
    loadNamespace(ctx$pkg, lib.loc = c(stlib, .libPaths()))
    probe_ok(ctx$cfg, ctx$pkg, ctx$entry$kind, stlib)
  }, error = function(e) conditionMessage(e))
  if (!isTRUE(res)) bail(1L, paste0("validation failed for ", ctx$pkg, ": ", if (is.character(res)) res else "probe returned no data"))
  invisible(0L)
}

phase_finalize <- function(ctx) {
  plan <- read_kv(ctx$plan)
  info <- read_kv(ctx$tar_info)
  src <- file.path(ctx$staging, "lib", ctx$pkg)
  dst <- file.path(ctx$lib, ctx$pkg)
  if (exists_or_link(dst)) bail(14L, paste("refusing to replace existing entry", dst))
  if (!file.rename(src, dst)) bail(1L, "atomic rename into the library failed")
  tsv <- file.path(ctx$lib, "INSTALLED.tsv")
  rows <- if (file.exists(tsv)) readLines(tsv, warn = FALSE) else character()
  rows <- rows[-1L]
  rows <- rows[!startsWith(rows, paste0(ctx$pkg, "\t"))]
  row <- paste(c(ctx$pkg, plan$version, info$sha256, plan$md5, info$final_url,
                 format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")), collapse = "\t")
  tmp <- file.path(ctx$lib, paste0("INSTALLED.tsv.tmp.", Sys.getpid()))
  writeLines(c(paste(INSTALLED_COLS, collapse = "\t"), rows, row), tmp)
  if (ctx$cfg$test_mode && ctx$cfg$finalize_pause > 0) Sys.sleep(ctx$cfg$finalize_pause)
  if (!file.rename(tmp, tsv)) bail(1L, "INSTALLED.tsv rename failed")
  invisible(0L)
}

# ---- utility commands ---------------------------------------------------------

cmd_print_plan <- function() {
  cfg <- load_config()
  cat("repository=", cfg$repo, "\n", sep = "")
  cat("allowlist=", cfg$allowlist, "\n", sep = "")
  cat("downloader=", cfg$downloader, "\n", sep = "")
  cat("curl_policy=--fail --proto =https --proto-redir =https --max-redirs 3 --write-out %{url_effective}\n")
  cat("test_mode=", if (cfg$test_mode) 1 else 0, "\n", sep = "")
  invisible(0L)
}

cmd_cap <- function() {
  cfg <- load_config()
  cat("cap_bytes=", format(allow_cap_bytes(read_allowlist(cfg$allowlist)), scientific = FALSE), "\n", sep = "")
  invisible(0L)
}

# ---- real-environment verification (REQ-011, REQ-012, REQ-015) --------------------

check_line <- function(name, ok, detail = "") {
  cat(sprintf("CHECK %s: %s %s\n", name, if (isTRUE(ok)) "PASS" else "FAIL", detail))
  isTRUE(ok)
}

norm <- function(x) normalizePath(x, mustWork = FALSE)

# First two library entries must be the release library then the annotation library.
libpath_order_ok <- function(paths, release_lib, annot_lib) {
  length(paths) >= 2L && identical(norm(paths[[1L]]), norm(release_lib)) && identical(norm(paths[[2L]]), norm(annot_lib))
}

# Built field of an installed package must name this R minor; DESCRIPTION only, so a fault
# can be planted without a loadable package.
built_for_this_r <- function(lib, pkg) {
  d <- tryCatch(read.dcf(file.path(lib, pkg, "DESCRIPTION"), fields = "Built"), error = function(e) NULL)
  want <- paste0("R ", R.version$major, ".", strsplit(R.version$minor, ".", fixed = TRUE)[[1L]][[1L]])
  !is.null(d) && !is.na(d[1L, 1L]) && startsWith(d[1L, 1L], want)
}

annot_counts <- function(annot) {
  df <- if (inherits(annot, "Annot")) annot@annot else annot
  list(genes = length(unique(df[, 1L])), terms = length(unique(df[, 2L])))
}

default_worker_libpaths <- function() {
  old <- future::plan(future::multisession, workers = 1L)
  on.exit(future::plan(old), add = TRUE)
  future::value(future::future(.libPaths()))
}

# builder(species, keytype, anntype) -> Annot; enricher(df, header, species, anntype, keytype, ontology)
# -> data frame; worker_libpaths() -> character; cache_stats() / reset_memory() read and clear the
# annotation cache's memory level. The defaults are the real richStudio / future calls (annotations are
# built through richStudio's own cached builder, which attaches reactome.db on a miss); tests inject stubs.
verify_env <- function(release_dir, annot_lib, allowlist, floors, fixture,
                       builder = function(species, keytype, anntype) richStudio:::richstudio_build_annotation(species, keytype, anntype),
                       cache_stats = function() richStudio:::annotation_cache_stats(), expect_hit = FALSE,
                       reset_memory = function() richStudio:::annotation_cache_reset(memory_only = TRUE),
                       enricher = function(df, header, species, anntype, keytype, ontology) {
                         richStudio:::shiny_enrich(df, header, species, anntype, keytype, ontology)@result
                       },
                       worker_libpaths = default_worker_libpaths,
                       libpaths = .libPaths(), environ = Sys.getenv()) {
  release_lib <- file.path(release_dir, "renv", "library", "release-r46")
  ok <- TRUE
  step <- function(name, cond, detail = "") { r <- check_line(name, cond, detail); ok <<- ok && r; r }

  step("libpaths_order", libpath_order_ok(libpaths, release_lib, annot_lib),
       paste(utils::head(libpaths, 3L), collapse = " | "))
  wp <- tryCatch(worker_libpaths(), error = function(e) paste("ERROR", conditionMessage(e)))
  step("worker_libpaths_order", libpath_order_ok(wp, release_lib, annot_lib), paste(utils::head(wp, 3L), collapse = " | "))
  hit <- grep("^RICHSTUDIO_ANNOTATION_TEST", names(environ), value = TRUE)
  step("test_env_absent", !length(hit), paste(hit, collapse = ","))

  al <- read_allowlist(allowlist)
  pre <- al[al$preinstall == "yes" & al$status == "available", , drop = FALSE]
  for (pkg in pre$package) {
    inannot <- file.exists(file.path(annot_lib, pkg, "DESCRIPTION"))
    inrelease <- file.exists(file.path(release_lib, pkg))
    loc <- tryCatch(find.package(pkg), error = function(e) "")
    step(paste0("pkg_", pkg), inannot && !inrelease && identical(dirname(norm(loc)), norm(annot_lib)) &&
           built_for_this_r(annot_lib, pkg),
         sprintf("in_annotation_lib=%s in_release_lib=%s loaded_from=%s built_ok=%s", inannot, inrelease, loc,
                 built_for_this_r(annot_lib, pkg)))
  }

  fl <- utils::read.delim(floors, sep = "\t", colClasses = "character", na.strings = character())
  # Pre-warm: GO, builtin KEGG and Reactome for the five pre-installed species (15 entries) through the
  # one richStudio builder. Floors apply where the floors file has a row; every entry must be non-empty.
  five <- c("human", "mouse", "rat", "zebrafish", "celegans")
  combos <- expand.grid(anntype = c("GO", "KEGG", "Reactome"), species = five, stringsAsFactors = FALSE)
  src <- function(x) { s <- attr(x, "cache_source"); if (is.null(s)) "unknown" else s }
  t_first <- 0
  first_src <- character()
  for (i in seq_len(nrow(combos))) {
    sp <- combos$species[[i]]; at <- combos$anntype[[i]]
    t0 <- proc.time()[["elapsed"]]
    obj <- tryCatch(builder(sp, "SYMBOL", at), error = function(e) e)
    el <- proc.time()[["elapsed"]] - t0
    t_first <- t_first + el
    if (inherits(obj, "error")) {
      step(paste0("build_", sp, "_", at), FALSE, conditionMessage(obj))
      first_src[[paste(sp, at)]] <- "error"
      next
    }
    first_src[[paste(sp, at)]] <- src(obj)
    cnt <- annot_counts(obj)
    row <- which(fl$species == sp & fl$anntype == at)
    min_g <- if (length(row)) as.numeric(fl$min_genes[[row[[1L]]]]) else 1
    min_t <- if (length(row)) as.numeric(fl$min_terms[[row[[1L]]]]) else 1
    step(paste0("floor_", sp, "_", at), cnt$genes >= min_g && cnt$terms >= min_t,
         sprintf("genes=%s (floor %s) terms=%s (floor %s) seconds=%.1f source=%s", cnt$genes, min_g, cnt$terms, min_t, el, src(obj)))
  }
  if (expect_hit) {
    step("human_go_hit", first_src[["human GO"]] %in% c("memory", "disk"), paste("source =", first_src[["human GO"]]))
  }
  # Pass 2 in a cleared memory level: every entry must be a hit (memory or disk), none rebuilt.
  reset_memory()
  misses0 <- cache_stats()$misses
  t0 <- proc.time()[["elapsed"]]
  second <- vapply(seq_len(nrow(combos)), function(i) {
    x <- tryCatch(builder(combos$species[[i]], "SYMBOL", combos$anntype[[i]]), error = function(e) NULL)
    if (is.null(x)) "error" else src(x)
  }, character(1))
  t_second <- proc.time()[["elapsed"]] - t0
  step("cache_second_pass", all(second %in% c("memory", "disk")) && cache_stats()$misses == misses0,
       sprintf("entries=%d hits=%d first_pass_seconds=%.1f second_pass_seconds=%.1f sources=%s", nrow(combos),
               sum(second %in% c("memory", "disk")), t_first, t_second, paste(table(second), names(table(second)), collapse = ",")))
  rss <- tryCatch(grep("^VmRSS", readLines("/proc/self/status"), value = TRUE), error = function(e) "VmRSS: unavailable")
  cdir <- file.path(dirname(annot_lib), "cache", basename(annot_lib))
  du <- if (dir.exists(cdir)) suppressWarnings(system2("du", c("-sk", shQuote(cdir)), stdout = TRUE)) else "no cache dir"
  cat(sprintf("INFO cache_dir_du_kb: %s | main process %s\n", sub("\\s.*$", "", du[[1L]]), gsub("\\s+", " ", rss[[1L]])))

  fx <- utils::read.delim(fixture, sep = "\t", colClasses = "character", na.strings = character())
  res <- tryCatch(enricher(fx, "symbol", "human", "GO", "SYMBOL", "BP"), error = function(e) conditionMessage(e))
  if (is.data.frame(res)) {
    pc <- grep("^(padj|p\\.adjust|adj)", names(res), ignore.case = TRUE, value = TRUE)[1L]
    ac <- grep("^(annot|id|go)$", names(res), ignore.case = TRUE, value = TRUE)[1L]
    sig <- if (is.na(pc)) res[0, , drop = FALSE] else res[!is.na(res[[pc]]) & res[[pc]] < 0.05, , drop = FALSE]
    top5 <- if (is.na(pc) || is.na(ac)) character() else as.character(res[[ac]][order(res[[pc]])][seq_len(min(5L, nrow(res)))])
    has_term <- "GO:0097193" %in% top5
    step("fixture_enrichment", nrow(sig) >= FIXTURE_MIN_ROWS && has_term,
         sprintf("significant_rows=%d (floor %d) GO:0097193_in_top5=%s top5=%s", nrow(sig), FIXTURE_MIN_ROWS, has_term,
                 paste(top5, collapse = ",")))
  } else {
    step("fixture_enrichment", FALSE, paste("error:", res))
  }
  cat(if (ok) "VERIFY PASS\n" else "VERIFY FAIL\n")
  ok
}

# ---- entry point --------------------------------------------------------------

run_phase <- function(phase, pkg, staging) {
  ctx <- phase_context(pkg, staging)
  switch(phase,
         prepare = phase_prepare(ctx), download = phase_download(ctx), install = phase_install(ctx),
         validate = phase_validate(ctx), finalize = phase_finalize(ctx),
         bail(1L, paste("unknown phase:", phase)))
}

main <- function(args = commandArgs(trailingOnly = TRUE)) {
  code <- tryCatch({
    cmd <- if (length(args)) args[[1L]] else ""
    r <- switch(cmd,
      "print-plan" = cmd_print_plan(),
      "cap" = cmd_cap(),
      "check-url" = {
        p <- url_problem(if (length(args) >= 2L) args[[2L]] else "", allow_file = test_mode_active())
        cat(if (nzchar(p)) paste0("REJECT ", p) else "OK", "\n", sep = "")
        if (nzchar(p)) 1L else 0L
      },
      "check-lib" = {
        p <- lib_problems(sub("/+$", "", if (length(args) >= 2L) args[[2L]] else ""))
        if (length(p)) { cat(paste0("REJECT ", p, "\n"), sep = ""); 1L } else { cat("OK\n"); 0L }
      },
      "verify-env" = {
        if (length(args) < 3L) bail(1L, "usage: verify-env <release dir> <annotation lib>")
        rd <- sub("/+$", "", args[[2L]])
        if (verify_env(rd, sub("/+$", "", args[[3L]]), expect_hit = "expect-hit" %in% args[-(1:3)],
                       file.path(rd, "inst", "extdata", "annotation-allowlist.tsv"),
                       file.path(rd, "inst", "extdata", "annotation-verify-floors.tsv"),
                       file.path(rd, "tests", "fixtures", "annotation", "human-query-20.tsv"))) 0L else 1L
      },
      prepare = , download = , install = , validate = , finalize = {
        if (length(args) < 3L) bail(1L, "usage: <phase> <package> <staging dir>")
        run_phase(cmd, args[[2L]], sub("/+$", "", args[[3L]]))
      },
      bail(1L, paste("unknown command:", cmd)))
    if (is.null(r) || !is.numeric(r)) 0L else as.integer(r)
  }, annotation_exit = function(e) {
    message("annotation-install: ", conditionMessage(e))
    e$code
  }, error = function(e) {
    message("annotation-install: internal error: ", conditionMessage(e))
    1L
  })
  quit(save = "no", status = code)
}

if (!interactive() && sys.nframe() == 0L) main()
