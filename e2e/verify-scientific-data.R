# Independent checks of actual browser downloads and trace values. No clustering
# rerun or richStudio plotting helper is used here.
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 1L, dir.exists(args[[1]]))
artifacts <- normalizePath(args[[1]])
files <- list.files(artifacts, recursive = TRUE, full.names = TRUE)
evidence_names <- c("scientific-boundary-evidence.json", "synthetic-gui-evidence.json",
                    "gse63310-gui-evidence.json", "bundled-go-evidence.json")
evidence_files <- files[basename(files) %in% evidence_names]
stopifnot(length(evidence_files) == 8L)
smallest <- .Machine$double.xmin * .Machine$double.eps
records <- list()

same_payload <- function(a, b) {
  for (field in c("rrnames", "clusnames")) stopifnot(identical(a[[field]], b[[field]]))
  for (field in c("rrdfs", "clusdfs", "cluslists", "big_rrdf", "big_clusdf")) {
    stopifnot(setequal(names(a[[field]]), names(b[[field]])))
    for (name in names(a[[field]])) stopifnot(identical(a[[field]][[name]], b[[field]][[name]]))
  }
}

main_trace <- function(traces) {
  is_main <- vapply(traces, function(trace) {
    any(vapply(trace$cells, function(cell) is.numeric(cell$z) && cell$z > 1, logical(1)))
  }, logical(1))
  stopifnot(sum(is_main) == 1L)
  traces[[which(is_main)]]
}

verify_trace <- function(trace, detail) {
  keys <- character()
  n_missing <- 0L
  for (cell in trace$cells) {
    stopifnot(grepl("^cluster:[0-9]+$", cell$y))
    cluster <- sub("^cluster:", "", cell$y)
    column <- paste0("Padj_", cell$x)
    stopifnot(column %in% names(detail))
    values <- detail[as.character(detail$Cluster) == cluster, column]
    stopifnot(length(values) > 0L)
    if (all(is.na(values))) {
      stopifnot(is.null(cell$z))
      n_missing <- n_missing + 1L
    } else {
      raw <- mean(values, na.rm = TRUE)
      if (raw == 0) raw <- smallest
      expected <- round(-log10(raw), 4)
      if (!is.numeric(cell$z) || !isTRUE(all.equal(cell$z, expected, tolerance = 1e-10))) {
        cat("TRACE_MISMATCH", "x=", cell$x, "y=", cell$y,
            "actual=", cell$z, "expected=", expected, "raw_mean=", mean(values, na.rm = TRUE),
            "members=", length(values), "\n")
        stop("Trace value differs from saved cluster-detail mean")
      }
    }
    keys <- c(keys, paste(cell$x, cell$y, sep = "::"))
  }
  stopifnot(!anyDuplicated(keys))
  list(cells = length(keys), missing = n_missing)
}

for (file in evidence_files) {
  cat("VERIFY_FILE", file, "\n")
  evidence <- jsonlite::read_json(file, simplifyVector = FALSE)
  folder <- dirname(file)
  kind <- basename(file)
  if (kind == "scientific-boundary-evidence.json") {
    saved <- readRDS(file.path(folder, "scientific-boundary-roundtrip.rds"))
    restored <- readRDS(file.path(folder, "scientific-boundary-restored.rds"))
    source <- readRDS("tests/fixtures/workspace/scientific-cluster-session-v1.rds")
    same_payload(saved, restored)
    stopifnot(identical(saved$clusdfs$Scientific_fixture, source$clusdfs$Scientific_fixture),
              identical(saved$cluslists$Scientific_fixture, source$cluslists$Scientific_fixture))
    verified <- verify_trace(evidence$summary, source$cluslists$Scientific_fixture)
    stopifnot(verified$cells == 4L, verified$missing == 1L)
    records[[file]] <- list(kind = kind, project = evidence$project, checks = verified)
  } else if (kind %in% c("synthetic-gui-evidence.json", "gse63310-gui-evidence.json")) {
    real <- kind == "gse63310-gui-evidence.json"
    stem <- if (real) "gse63310-gui" else "synthetic-gui"
    saved <- readRDS(file.path(folder, paste0(stem, "-roundtrip.rds")))
    restored <- readRDS(file.path(folder, paste0(stem, "-restored.rds")))
    same_payload(saved, restored)
    expected_names <- unlist(evidence$inputs, use.names = FALSE)
    stopifnot(setequal(saved$rrnames, expected_names))
    input_root <- if (real) "tests/fixtures/workspace/gse63310" else "tests/fixtures/workspace"
    for (name in expected_names) {
      raw <- read.delim(file.path(input_root, name), check.names = FALSE)
      stopifnot(identical(saved$rrdfs[[name]], raw))
    }
    verified <- lapply(names(evidence$traces), function(name) {
      stopifnot(name %in% saved$clusnames)
      detail <- saved$cluslists[[name]]
      row <- saved$big_clusdf$df[saved$big_clusdf$df$name == name, ]
      stopifnot(nrow(row) == 1L, row$n_clusters == length(unique(detail$Cluster)),
                row$n_terms == nrow(detail))
      verify_trace(main_trace(evidence$traces[[name]]), detail)
    })
    names(verified) <- names(evidence$traces)
    records[[file]] <- list(kind = kind, project = evidence$project,
                            input_tables_exact = length(expected_names), checks = verified)
  } else {
    saved <- readRDS(file.path(folder, "bundled-go-session.rds"))
    stopifnot(setequal(saved$rrnames, c("go1", "go2", "kegg1")))
    for (name in c("go1", "go2", "kegg1")) {
      raw <- read.delim(file.path("inst/extdata", paste0(name, ".txt")))
      stopifnot(identical(saved$rrdfs[[name]], raw))
    }
    verified <- verify_trace(evidence$trace, saved$cluslists$Bundled_GO_hierarchical)
    records[[file]] <- list(kind = kind, project = evidence$project,
                            input_tables_exact = 3L, checks = verified)
  }
  cat("PASS", evidence$project, kind, "raw data, row identities and independent mean-Padj trace values\n")
}
jsonlite::write_json(list(passed = TRUE, journeys = records,
                          scope = "Actual GUI input/session/download artifacts; independent raw-data and mean-Padj checks"),
                     file.path(artifacts, "independent-data-receipt.json"), auto_unbox = TRUE, pretty = TRUE)
