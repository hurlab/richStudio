#!/usr/bin/env Rscript
# Run from an external CWD with the candidate's installed library first.
# timeout 120s /usr/bin/time -v Rscript --vanilla <script> <case> <output.json>
args <- commandArgs(trailingOnly = TRUE)
measurement_script <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[[1]]))
measurement_sha256 <- digest::digest(file = measurement_script, algo = "sha256")
if (length(args) != 2L || !args[1] %in% c("small", "representative", "upper", "render", "worker", "worker-error")) {
  stop("Usage: measure-workspace-resources.R small|representative|upper|render|worker|worker-error output.json")
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
  receipt <- list(schema_version = 1L, case = case, seed = 17001L, script_sha256 = measurement_sha256,
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

measure_render <- function(output) {
  directory <- normalizePath(dirname(output), mustWork = TRUE)
  policy <- richStudio:::workspace_resource_policy()
  rows <- policy$limits$render_rows
  columns <- policy$limits$columns
  nodes <- policy$limits$graph_nodes
  stopifnot(rows == 2000L, columns == 24L, nodes == 400L,
            policy$limits$graph_edges == 800L)
  set.seed(17001)
  labels <- vapply(seq_len(rows), function(i) {
    paste0(i, ":", paste(sample(c(letters, LETTERS, 0:9), 1024L, TRUE), collapse = ""))
  }, character(1))
  table <- as.data.frame(setNames(c(list(labels), rep(list(seq_len(rows)), columns - 1L)),
                                paste0("column", seq_len(columns))))
  richStudio:::workspace_check_resources(list(render_rows = rows, columns = columns,
    string_bytes = max(nchar(labels, type = "bytes"))), policy)
  widget <- DT::datatable(table, rownames = FALSE, elementId = "resource-table",
                         options = list(pageLength = 10L, scrollX = TRUE))
  htmlwidgets::saveWidget(widget, file.path(directory, "actual-table.html"),
    selfcontained = FALSE, libdir = file.path(directory, "widget-libs"),
    title = "Measured table at 2000 rows and 24 columns")

  # One distinct gene per undirected ring edge: each term has four genes.
  edges <- data.frame(from = rep(seq_len(nodes), 2L),
    to = c((seq_len(nodes) %% nodes) + 1L, ((seq_len(nodes) + 1L) %% nodes) + 1L))
  genes <- paste0("edge", seq_len(nrow(edges)))
  term_genes <- lapply(seq_len(nodes), function(i) genes[edges$from == i | edges$to == i])
  input <- data.frame(Term = paste0("term", seq_len(nodes)),
    Annot = paste0("T", seq_len(nodes)),
    GeneID = vapply(term_genes, paste, collapse = ",", character(1)),
    Significant = lengths(term_genes),
    Pvalue = seq(0.0001, 0.01, length.out = nodes),
    Padj = seq(0.0002, 0.02, length.out = nodes))
  richStudio:::workspace_check_resources(list(graph_nodes = nodes, graph_edges = nrow(edges)), policy)
  plot <- richR::ggnetwork(input, gene = genes, top = nodes, weightcut = 0)
  built <- ggplot2::ggplot_build(plot)
  layers <- lapply(seq_along(plot$layers), function(i) {
    list(geometry = class(plot$layers[[i]]$geom)[[1]], rows = nrow(built$data[[i]]))
  })
  stopifnot(any(vapply(layers, function(x) x$geometry == "GeomPoint" && x$rows == nodes, logical(1))),
            any(vapply(layers, function(x) x$geometry == "GeomSegment" && x$rows == nrow(edges), logical(1))))
  image <- file.path(directory, "actual-network.png")
  grDevices::png(image, width = 1280L, height = 720L, res = 96L)
  tryCatch(print(plot), finally = grDevices::dev.off())
  stopifnot(file.info(image)$size > 0)
  writeLines(paste0('<!doctype html><html lang="en"><head><title>Measured network</title></head>',
    '<body><img alt="Measured enrichment network at 400 nodes and 800 edges" ',
    'src="actual-network.png"></body></html>'), file.path(directory, "actual-network.html"))
  jsonlite::write_json(list(schema_version = 1L, script_sha256 = measurement_sha256, runtime = R.version.string,
    scope = "Actual DT widget and richR/GGally backend; not a new app UI graph limit",
    packages = lapply(c("richStudio", "richR", "GGally", "DT", "htmlwidgets", "igraph", "intergraph", "ggrepel", "ggplot2"),
      function(p) list(name = p, version = as.character(utils::packageVersion(p)), path = find.package(p))),
    table = list(rows = nrow(table), columns = ncol(table), first_label = labels[[1]],
      last_label = labels[[rows]], data_sha256 = digest::digest(table, algo = "sha256")),
    graph = list(nodes = nodes, edges = nrow(edges), actual_plot_layers = layers,
      input_sha256 = digest::digest(input, algo = "sha256"), image_bytes = unname(file.info(image)$size)),
    vm_hwm = grep("VmHWM", readLines("/proc/self/status"), value = TRUE)),
    output, pretty = TRUE, auto_unbox = TRUE)
  cat("ACTUAL_RENDER DT rows", rows, "columns", columns, "network nodes", nodes,
      "edges", nrow(edges), "\n")
}

measure_worker <- function(output, expected_error = FALSE) {
  script <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[[1]]))
  fixture <- file.path(dirname(dirname(script)), "tests/fixtures/workspace/imported-results.tsv")
  root <- tempfile("workspace-owned-worker-")
  dir.create(root)
  started <- file.path(root, "started")
  release <- file.path(root, "release")
  pid <- NA_integer_
  old_plan <- future::plan()
  cleaned <- FALSE
  cleanup <- function() {
    if (!cleaned) {
      future::plan(old_plan)
      unlink(root, recursive = TRUE)
      cleaned <<- TRUE
    }
  }
  on.exit(cleanup(), add = TRUE)
  future::plan(future::multisession, workers = I(1))
  factory_calls <- 0L
  launch <- function(workers) {
    richStudio:::workspace_check_resources(list(workers = workers))
    factory_calls <<- factory_calls + 1L
    future::future({
      worker_pid <- Sys.getpid()
      writeLines(as.character(worker_pid), started)
      deadline <- Sys.time() + 15
      while (!file.exists(release)) {
        if (Sys.time() > deadline) stop("Worker latch timed out")
        Sys.sleep(0.01)
      }
      if (expected_error) stop("Intentional owned worker failure")
      input <- read.delim(fixture)
      records <- list()
      for (method in c("richR", "hierarchical", "david")) {
        params <- list(cutoff = 0.1, overlap = 0, minSize = 2, min_value = 0.05,
          distance_metric = "jaccard", distance_cutoff = 0.1, linkage_cutoff = 1,
          min_terms = 1, similarity_threshold = 0.1, initial_group_membership = 1,
          final_group_membership = 1, multiple_linkage_threshold = 0.5)
        before <- proc.time()[["elapsed"]]
        result <- richStudio::perform_clustering(input, method = method, params = params,
          gs_names = "fixture", raw_genesets = list(fixture = input))
        stopifnot(nrow(result$cluster_df) > 0L)
        records[[method]] <- list(method = method, pid = Sys.getpid(), params = params,
          result_rows = nrow(result$cluster_df), result_columns = names(result$cluster_df),
          elapsed_seconds = proc.time()[["elapsed"]] - before,
          vm_hwm = grep("VmHWM", readLines("/proc/self/status"), value = TRUE))
      }
      list(pid = worker_pid, engines = records,
        libraries = .libPaths(), packages = lapply(c("richStudio", "richR", "richCluster"),
          function(p) list(name = p, version = as.character(utils::packageVersion(p)), path = find.package(p))))
    }, seed = TRUE)
  }
  task <- launch(1L)
  deadline <- Sys.time() + 15
  while (!file.exists(started)) {
    if (Sys.time() > deadline) stop("Owned worker did not report its PID")
    Sys.sleep(0.01)
  }
  pid <- as.integer(readLines(started))
  stopifnot(pid != Sys.getpid(), !future::resolved(task))
  rejection <- tryCatch({ launch(2L); NULL }, error = conditionMessage)
  stopifnot(is.character(rejection), grepl("workers", rejection, fixed = TRUE),
            factory_calls == 1L, !future::resolved(task))
  writeLines("release", release)
  result <- tryCatch(future::value(task), error = function(e) list(error = conditionMessage(e)))
  if (expected_error) {
    stopifnot(identical(result$error, "Intentional owned worker failure"))
  } else {
    stopifnot(identical(names(result$engines), c("richR", "hierarchical", "david")),
              all(vapply(result$engines, function(x) identical(x$pid, pid), logical(1))))
  }
  cleanup()
  deadline <- Sys.time() + 10
  while (dir.exists(file.path("/proc", pid)) && Sys.time() < deadline) Sys.sleep(0.01)
  gone <- !dir.exists(file.path("/proc", pid))
  stopifnot(gone, !dir.exists(root))
  jsonlite::write_json(list(schema_version = 1L, script_sha256 = measurement_sha256, runtime = R.version.string,
    scope = "One active owned worker and four-term engine fixture; not global scheduler or 50000-term capacity",
    parent_pid = Sys.getpid(), launched_pids = pid, factory_calls = factory_calls,
    active_before_rejection = TRUE, admitted_workers = 1L, rejected_workers = 2L,
    rejection = rejection, expected_error = expected_error, result = result,
    worker_pid_gone = gone, temporary_cleanup = !dir.exists(root),
    fixture_sha256 = digest::digest(file = fixture, algo = "sha256"),
    policy_sha256 = digest::digest(file = system.file("config", "workspace-resources.json", package = "richStudio"), algo = "sha256")),
    output, pretty = TRUE, auto_unbox = TRUE)
  cat("OWNED_WORKER admitted1 rejected2 factory_calls1 pid", pid,
      "gone", gone, "cleanup", !dir.exists(root), "expected_error", expected_error, "\n")
}

switch(args[1], render = measure_render(args[2]),
       worker = measure_worker(args[2]),
       `worker-error` = measure_worker(args[2], expected_error = TRUE),
       measure(args[1], args[2]))
