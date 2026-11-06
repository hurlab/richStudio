# Annotation build: Reactome attach plus a two-level cache (SPEC-WS-014 M1).
#
# `richstudio_build_annotation()` is the ONE annotation builder of the app: the default
# `annotation_builder` of the analysis path (R/deg_enrich.R) and of the background check
# (R/enrich_tab.R). It runs inside the future worker, so the memory level lives in that
# persistent worker process and the disk level is shared by every worker.
#
#   level 1  memory: package-level environment, LRU bounded to 3 entries
#   level 2  disk:   <annotation library parent>/cache/<library name>/<md5 of the key text>.rds
#
# The cache never errors an analysis: any cache failure falls back to a normal build.
# Only app-generated files whose names match the hashed-key pattern are ever read.

ANNOTATION_CACHE_SCHEMA <- "1"
ANNOTATION_CACHE_MEMORY_MAX <- 3L
ANNOTATION_CACHE_FILE_RE <- "^[0-9a-f]{32}\\.rds$"

.annotation_cache <- new.env(parent = emptyenv())

annotation_cache_reset <- function(memory_only = FALSE) {
  .annotation_cache$store <- new.env(parent = emptyenv())
  .annotation_cache$order <- character()
  if (!memory_only || is.null(.annotation_cache$stats)) {
    .annotation_cache$stats <- list(memory_hits = 0L, disk_hits = 0L, misses = 0L, writes = 0L,
                                    evictions = 0L, disabled = 0L)
    .annotation_cache$logged <- character()
  }
  invisible(NULL)
}
annotation_cache_reset()

annotation_cache_stats <- function() .annotation_cache$stats

annotation_cache_bump <- function(field, n = 1L) {
  .annotation_cache$stats[[field]] <- .annotation_cache$stats[[field]] + n
  invisible(NULL)
}

# One log line per lookup; reasons that repeat (disabled, unsafe directory) are logged once.
annotation_cache_log <- function(msg, once = NULL) {
  if (!is.null(once)) {
    if (once %in% .annotation_cache$logged) return(invisible(NULL))
    .annotation_cache$logged <- c(.annotation_cache$logged, once)
  }
  message("[annotation-cache] ", msg)
  invisible(NULL)
}

annotation_org_package <- function(species) {
  tryCatch(richR:::.getdbname(species), error = function(e) NA_character_)
}

annotation_package_versions <- function(pkgs) {
  vapply(pkgs, function(p) {
    tryCatch(as.character(utils::packageVersion(p)), error = function(e) "absent")
  }, character(1))
}

annotation_remote_sha <- function(pkg) {
  d <- tryCatch(utils::packageDescription(pkg), error = function(e) NULL)
  if (!is.list(d)) return("")
  sha <- d$RemoteSha
  if (is.null(sha)) sha <- d$GithubSHA1
  if (is.null(sha)) "" else as.character(sha)
}

annotation_r_minor <- function() {
  paste(R.version$major, strsplit(R.version$minor, ".", fixed = TRUE)[[1L]][[1L]], sep = ".")
}

# Everything the build output depends on. GO term names come from GO.db (GO only); Reactome needs
# reactome.db; the organism package and AnnotationDbi shape every build.
annotation_cache_key <- function(species, keytype, anntype, stub = FALSE) {
  org <- annotation_org_package(species)
  pkgs <- unique(c("AnnotationDbi", if (!is.na(org)) org,
                   if (identical(anntype, "GO")) "GO.db",
                   if (identical(anntype, "Reactome")) "reactome.db",
                   if (identical(anntype, "KEGGM")) "KEGGREST"))
  vers <- annotation_package_versions(pkgs)
  parts <- c(schema = ANNOTATION_CACHE_SCHEMA, builder = if (stub) "stub" else "richR::buildAnnot",
             species = species, keytype = keytype, anntype = anntype, R = annotation_r_minor(),
             richR = annotation_package_versions("richR"), richR_sha = annotation_remote_sha("richR"),
             bioAnno = annotation_package_versions("bioAnno"), bioAnno_sha = annotation_remote_sha("bioAnno"),
             stats::setNames(vers, paste0("pkg:", names(vers))))
  text <- paste(names(parts), unname(parts), sep = "=", collapse = "|")
  list(text = text, hash = digest::digest(text, algo = "md5", serialize = FALSE))
}

# ---- memory level ---------------------------------------------------------------

annotation_memory_get <- function(hash) {
  if (!hash %in% .annotation_cache$order) return(NULL)
  .annotation_cache$order <- c(setdiff(.annotation_cache$order, hash), hash)
  .annotation_cache$store[[hash]]
}

annotation_memory_put <- function(hash, value) {
  .annotation_cache$store[[hash]] <- value
  .annotation_cache$order <- c(setdiff(.annotation_cache$order, hash), hash)
  while (length(.annotation_cache$order) > ANNOTATION_CACHE_MEMORY_MAX) {
    victim <- .annotation_cache$order[[1L]]
    rm(list = victim, envir = .annotation_cache$store)
    .annotation_cache$order <- .annotation_cache$order[-1L]
  }
  invisible(NULL)
}

# ---- disk level -------------------------------------------------------------------

annotation_cache_limits <- function() {
  list(max_bytes = getOption("richstudio.annotation_cache_max_bytes", 1024^3),
       max_entries = getOption("richstudio.annotation_cache_max_entries", 200L))
}

annotation_link_target <- function(p) {
  r <- Sys.readlink(p)
  !is.na(r) && nzchar(r)
}

annotation_owner_ok <- function(path) {
  info <- file.info(path)
  !is.na(info$uname) && identical(unname(info$uname), unname(Sys.info()[["effective_user"]]))
}

# TRUE when `dir` is a real directory, owned by the app user, mode 0700, and every parent up to
# the annotation parent is owned by the app user and not group/world-writable.
annotation_cache_dir_safe <- function(dir, annotation_parent) {
  info <- file.info(dir)
  if (is.na(info$isdir) || !info$isdir || annotation_link_target(dir)) return("not a real directory")
  if (!annotation_owner_ok(dir)) return("not owned by the app user")
  if (bitwAnd(as.integer(info$mode), 63L) != 0L) return("mode is not 0700")
  p <- dirname(dir)
  repeat {
    pinfo <- file.info(p)
    if (is.na(pinfo$isdir)) return(paste("unreadable parent", p))
    if (!identical(p, annotation_parent) && annotation_link_target(p)) return(paste("parent is a symlink:", p))
    if (!annotation_owner_ok(p)) return(paste("parent not owned by the app user:", p))
    if (bitwAnd(as.integer(pinfo$mode), 18L) != 0L) return(paste("parent is group/world-writable:", p))
    if (identical(p, annotation_parent) || identical(p, dirname(p))) break
    p <- dirname(p)
  }
  ""
}

# NULL when the disk level is unavailable (and why), otherwise the directory.
annotation_cache_dir <- function() {
  lib <- Sys.getenv("RICHSTUDIO_ANNOTATION_LIB")
  if (!nzchar(lib)) return(list(dir = NULL, reason = "RICHSTUDIO_ANNOTATION_LIB is unset", fatal = TRUE))
  lib <- sub("/+$", "", lib)
  parent <- dirname(lib)
  dir <- file.path(parent, "cache", basename(lib))
  if (!dir.exists(dir)) {
    ok <- tryCatch({
      cache_root <- file.path(parent, "cache")
      if (!dir.exists(cache_root)) dir.create(cache_root, mode = "0700", showWarnings = FALSE)
      dir.create(dir, mode = "0700", showWarnings = FALSE)
      dir.exists(dir)
    }, error = function(e) FALSE, warning = function(w) FALSE)
    if (!isTRUE(ok)) return(list(dir = NULL, reason = "cache directory cannot be created", fatal = TRUE))
  }
  if (file.access(dir, 2L) != 0L) return(list(dir = NULL, reason = "cache directory is not writable", fatal = TRUE))
  bad <- annotation_cache_dir_safe(dir, parent)
  if (nzchar(bad)) return(list(dir = NULL, reason = paste("unsafe cache directory:", bad), fatal = TRUE))
  list(dir = dir, reason = "", fatal = FALSE)
}

annotation_cache_valid <- function(obj, key_text) {
  is.list(obj) && identical(obj$key, key_text) && inherits(obj$annot, "Annot") &&
    is.data.frame(obj$annot@annot) && nrow(obj$annot@annot) > 0L && ncol(obj$annot@annot) >= 2L
}

annotation_disk_read <- function(dir, hash, key_text) {
  f <- file.path(dir, paste0(hash, ".rds"))
  if (!grepl(ANNOTATION_CACHE_FILE_RE, basename(f))) return(NULL)
  if (!file.exists(f) && !annotation_link_target(f)) return(NULL)
  info <- file.info(f)
  if (annotation_link_target(f) || is.na(info$isdir) || info$isdir || !annotation_owner_ok(f)) {
    annotation_cache_log(paste("ignoring an unsafe cache file", basename(f)), once = paste0("file:", basename(f)))
    return(NULL)
  }
  obj <- tryCatch(readRDS(f), error = function(e) NULL)
  if (!annotation_cache_valid(obj, key_text)) {
    annotation_cache_log(paste("invalid cache file", basename(f), "will be rebuilt"))
    return(NULL)
  }
  obj$annot
}

annotation_disk_evict <- function(dir, keep = NULL) {
  lim <- annotation_cache_limits()
  # Stale temporary files (a killed write) go after an hour; a younger one may be a live write.
  tmps <- list.files(dir, pattern = "^\\.tmp-", all.files = TRUE, full.names = TRUE)
  if (length(tmps)) unlink(tmps[difftime(Sys.time(), file.info(tmps)$mtime, units = "secs") > 3600])
  files <- list.files(dir, pattern = ANNOTATION_CACHE_FILE_RE, full.names = TRUE)
  if (!length(files)) return(invisible(NULL))
  info <- file.info(files)
  ord <- order(info$mtime, files)
  files <- files[ord]
  size <- info$size[ord]
  i <- 1L
  while (i <= length(files) && (length(files) - i + 1L > lim$max_entries || sum(size[i:length(files)]) > lim$max_bytes)) {
    if (!identical(basename(files[[i]]), keep)) {
      unlink(files[[i]])
      annotation_cache_bump("evictions")
    }
    i <- i + 1L
  }
  invisible(NULL)
}

# Temp file in the same directory, then an atomic rename: readers never see a partial file and
# concurrent writers are harmless (the last rename wins).
annotation_disk_write <- function(dir, hash, key_text, annot) {
  f <- file.path(dir, paste0(hash, ".rds"))
  tmp <- file.path(dir, sprintf(".tmp-%d-%s", Sys.getpid(), paste(sample(c(letters, 0:9), 8, TRUE), collapse = "")))
  ok <- tryCatch({
    saveRDS(list(key = key_text, annot = annot), tmp)
    file.rename(tmp, f)
  }, error = function(e) FALSE, warning = function(w) FALSE)
  if (!isTRUE(ok)) {
    unlink(tmp)
    annotation_cache_log("could not write the cache file")
    return(invisible(FALSE))
  }
  annotation_cache_bump("writes")
  annotation_disk_evict(dir, keep = basename(f))
  invisible(TRUE)
}

# ---- Reactome attach ---------------------------------------------------------------

# richR 0.1.x looks Reactome objects up on the search path; attach reactome.db inside the
# worker when it is installed (never at package load).
annotation_attach_reactome <- function(anntype) {
  if (!identical(anntype, "Reactome")) return(invisible(FALSE))
  if ("package:reactome.db" %in% search()) return(invisible(TRUE))
  if (!annotation_reactome_installed()) return(invisible(FALSE))
  invisible(tryCatch({ annotation_attach_ns("reactome.db"); TRUE }, error = function(e) FALSE))
}
annotation_reactome_installed <- function() requireNamespace("reactome.db", quietly = TRUE)
annotation_attach_ns <- function(pkg) attachNamespace(pkg)

# ---- the builder ---------------------------------------------------------------------

annotation_cache_source <- function(x, source) {
  attr(x, "cache_source") <- source
  x
}

# `.builder` is an internal seam for tests (counting stub): a stub never touches the disk cache.
# Production callers never pass it. On a miss the Reactome attach runs; on a hit it is not
# needed, because the cached object is already built. The result carries attr "cache_source"
# (memory | disk | built), never saved to disk. Any cache failure falls back to a plain build.
richstudio_build_annotation <- function(species, keytype, anntype, .builder = NULL) {
  t0 <- proc.time()[["elapsed"]]
  stub <- !is.null(.builder)
  build <- function() {
    annotation_attach_reactome(anntype)
    if (stub) .builder(species = species, keytype = keytype, anntype = anntype)
    else richR::buildAnnot(species = species, keytype = keytype, anntype = anntype)
  }
  done <- function(x, source) {
    annotation_cache_log(sprintf("annotation_cache: source=%s species=%s anntype=%s secs=%.2f", source, species, anntype,
                                 proc.time()[["elapsed"]] - t0))
    annotation_cache_source(x, source)
  }
  disk <- NULL
  if (!stub) {
    d <- annotation_cache_dir()
    if (is.null(d$dir)) {
      # Disabled for this call: behaves as before (a plain build), nothing read or written.
      annotation_cache_bump("disabled")
      annotation_cache_bump("misses")
      annotation_cache_log(paste("cache disabled:", d$reason), once = d$reason)
      return(done(build(), "built"))
    }
    disk <- d$dir
  }
  key <- tryCatch(annotation_cache_key(species, keytype, anntype, stub), error = function(e) NULL)
  if (is.null(key)) {
    annotation_cache_bump("misses")
    return(done(build(), "built"))
  }
  hit <- annotation_memory_get(key$hash)
  if (!is.null(hit)) {
    annotation_cache_bump("memory_hits")
    return(done(hit, "memory"))
  }
  if (!is.null(disk)) {
    hit <- annotation_disk_read(disk, key$hash, key$text)
    if (!is.null(hit)) {
      annotation_cache_bump("disk_hits")
      annotation_memory_put(key$hash, hit)
      return(done(hit, "disk"))
    }
  }
  annotation_cache_bump("misses")
  built <- build()
  if (!is.null(disk) && annotation_cache_valid(list(key = key$text, annot = built), key$text)) {
    annotation_disk_write(disk, key$hash, key$text, built)
  }
  annotation_memory_put(key$hash, built)
  done(built, "built")
}
