#!/usr/bin/env Rscript
# Run from an external CWD with the candidate's installed library first.
# timeout 120s /usr/bin/time -v Rscript --vanilla <script> <case> <output.json>
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L || !args[1] %in% c("small", "representative", "upper")) {
  stop("Usage: measure-workspace-resources.R small|representative|upper output.json")
}
measure <- function(case, output) {
  root <- tempfile("workspace-measure-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  shape <- switch(case, small = c(100L, 7L, 32L, 2L, 1L, 20L, 40L, 2L),
                  representative = c(25000L, 12L, 256L, 8L, 2L, 200L, 400L, 10L),
                  upper = c(50000L, 24L, 1024L, 16L, 4L, 400L, 800L, 20L))
  set.seed(17001)
  labels <- vapply(seq_len(shape[1]), function(i) paste0(i, ":", paste(sample(c(letters, LETTERS, 0:9), shape[3], TRUE), collapse = "")), character(1))
  table <- as.data.frame(setNames(c(list(labels), rep(list(seq_len(shape[1])), shape[2] - 1L)), paste0("column", seq_len(shape[2]))))
  table_path <- file.path(root, "table.tsv")
  write.table(table, table_path, sep = "\t", row.names = FALSE, quote = FALSE)
  decoded <- read.delim(table_path, check.names = FALSE)
  members <- file.path(paste(rep("level", shape[5]), collapse = "/"), paste0("table", seq_len(shape[4]), ".tsv"))
  dir.create(dirname(file.path(root, members[1])), recursive = TRUE)
  for (i in seq_along(members)) {
    part <- table[seq.int(i, nrow(table), by = length(members)), , drop = FALSE]
    write.table(part, file.path(root, members[i]), sep = "\t", row.names = FALSE, quote = FALSE)
  }
  archive <- file.path(root, "tables.zip")
  zip::zipr(archive, members, root = root, include_directories = FALSE, mode = "mirror")
  archive_info <- zip::zip_list(archive)
  stopifnot(setequal(archive_info$filename, members))
  expanded <- file.path(root, "expanded")
  dir.create(expanded)
  zip::unzip(archive, exdir = expanded)
  graph <- list(nodes = data.frame(id = seq_len(shape[6])), edges = data.frame(
    from = rep(seq_len(shape[6]), length.out = shape[7]),
    to = rep(rev(seq_len(shape[6])), length.out = shape[7])))
  render <- decoded[seq_len(min(nrow(decoded), shape[6] * 5L)), , drop = FALSE]
  history <- rep(list(list(status = "completed", table = render)), shape[8])
  history_path <- file.path(root, "history.json")
  jsonlite::write_json(history, history_path)
  old_plan <- future::plan()
  on.exit(future::plan(old_plan), add = TRUE)
  future::plan(future::multisession, workers = I(1))
  parent_pid <- Sys.getpid()
  worker <- future::value(future::future(list(pid = Sys.getpid(), bytes = as.numeric(object.size(render))), seed = TRUE))
  stopifnot(worker$pid != parent_pid)
  metrics <- list(upload_bytes = unname(file.info(table_path)$size), rows = nrow(decoded),
    columns = ncol(decoded), string_bytes = max(nchar(labels, type = "bytes")),
    decoded_bytes = as.numeric(object.size(decoded)), archive_bytes = unname(file.info(archive)$size),
    archive_expanded_bytes = sum(archive_info$uncompressed_size), archive_members = nrow(archive_info),
    archive_depth = max(lengths(strsplit(archive_info$filename, "/", fixed = TRUE))),
    render_rows = nrow(render), graph_nodes = nrow(graph$nodes), graph_edges = nrow(graph$edges),
    workers = 1L, history_runs = length(history),
    temp_bytes = sum(file.info(list.files(root, recursive = TRUE, full.names = TRUE))$size))
  receipt <- list(schema_version = 1L, case = case, seed = 17001L,
    runtime = R.version.string, os = Sys.info(), libs = .libPaths(),
    packages = lapply(c("richStudio", "richR", "richCluster", "future", "zip", "jsonlite"), function(p) list(name = p, version = as.character(utils::packageVersion(p)), path = find.package(p))),
    fixture_sha256 = digest::digest(file = table_path, algo = "sha256"),
    metrics = metrics, worker = worker, parent_pid = parent_pid,
    measured_objects_bytes = list(table = as.numeric(object.size(decoded)), graph = as.numeric(object.size(graph)), history = as.numeric(object.size(history))),
    vm_hwm = if (file.exists("/proc/self/status")) grep("VmHWM", readLines("/proc/self/status"), value = TRUE) else "unavailable")
  future::plan(old_plan)
  unlink(root, recursive = TRUE)
  receipt$temporary_cleanup <- !dir.exists(root)
  stopifnot(receipt$temporary_cleanup)
  jsonlite::write_json(receipt, output, pretty = TRUE, auto_unbox = TRUE)
  cat("MEASURED", case, "output", output, "cleanup", receipt$temporary_cleanup, "\n")
}
measure(args[1], args[2])
