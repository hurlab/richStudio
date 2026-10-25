dependency_annotation_fixture <- function(anntype, genes) {
  if (anntype == "GO") {
    return(data.frame(
      GeneID = genes,
      GOALL = rep(c("GO:TEST1", "GO:TEST2"), each = length(genes) / 2),
      ONTOLOGYALL = "BP",
      Annot = rep(c("GO test term 1", "GO test term 2"), each = length(genes) / 2)
    ))
  }
  terms <- if (anntype == "KEGG") c("01100", "01110") else c("R-HSA-TEST1", "R-HSA-TEST2")
  data.frame(GeneID = genes, Term = rep(terms, each = length(genes) / 2))
}

dependency_annot_object <- function(anntype, annot) {
  methods::new(
    methods::getClassDef("Annot", where = asNamespace("richR")),
    species = "custom", anntype = anntype, keytype = "SYMBOL", annot = annot
  )
}

test_that("enrichment wrappers dispatch GO, KEGG, and Reactome through richR", {
  suppressPackageStartupMessages(library(richR))
  genes <- paste0("g", seq_len(20))
  annotation_builder <- function(species, keytype, anntype) {
    dependency_annot_object(anntype, dependency_annotation_fixture(anntype, genes))
  }

  for (anntype in c("GO", "KEGG", "Reactome")) {
    result <- suppressMessages(shiny_enrich(
      data.frame(gene = genes[1:10]), "gene", "custom", anntype,
      "SYMBOL", "BP", annotation_builder = annotation_builder
    ))

    expect_s4_class(result, "richResult")
    expect_true(nrow(result@result) > 0)
    expect_true(all(c("Annot", "Term", "GeneID") %in% names(result@result)))
    expect_equal(result@result$GeneID[1], paste(genes[1:10], collapse = ","))
    expected_term <- switch(anntype, GO = "GO:TEST1", KEGG = "01100", Reactome = "R-HSA-TEST1")
    expect_identical(result@result$Annot, expected_term)
    if (anntype == "KEGG") {
      expect_true(all(c("Level1", "Level2", "Level3") %in% names(result@result)))
    }
  }
})

test_that("the future worker retains typed valid-empty results and rejects empty queries", {
  genes <- paste0("g", seq_len(20))
  annotation <- dependency_annot_object(
    "Reactome", data.frame(GeneID = genes, Term = "R-HSA-TEST")
  )
  annotation_builder <- function(...) annotation
  jobs <- list(list(
    name = "one", df = data.frame(gene = genes[1]), gene_header = "gene"
  ))

  result <- run_enrichment_jobs(
    jobs, cutoff = 0.05, species = "custom", anntype = "Reactome",
    keytype = "SYMBOL", ontology = "", annotation_builder = annotation_builder
  )
  empty <- result[[1]]$result
  expect_equal(nrow(empty), 0L)
  expect_type(empty$Annot, "character")
  expect_type(empty$Pvalue, "double")
  expect_type(empty$Padj, "double")
  expect_true(all(c("Annot", "Term", "Annotated", "Significant", "Pvalue",
                    "Padj", "GeneID") %in% names(empty)))

  filtered_out <- list(list(
    name = "filtered", df = data.frame(gene = genes[1], Padj = 1),
    gene_header = "gene"
  ))
  expect_error(run_enrichment_jobs(
    filtered_out, cutoff = 0.05, species = "custom", anntype = "Reactome",
    keytype = "SYMBOL", ontology = "", annotation_builder = annotation_builder
  ), "No query genes remain")

  unmapped <- list(list(
    name = "unmapped", df = data.frame(gene = "unmapped"), gene_header = "gene"
  ))
  expect_error(run_enrichment_jobs(
    unmapped, cutoff = 0.05, species = "custom", anntype = "Reactome",
    keytype = "SYMBOL", ontology = "", annotation_builder = annotation_builder
  ), "no query genes remain")

  malformed_builder <- function(...) dependency_annot_object("Reactome", data.frame())
  expect_error(run_enrichment_jobs(
    jobs, cutoff = 0.05, species = "custom", anntype = "Reactome",
    keytype = "SYMBOL", ontology = "", annotation_builder = malformed_builder
  ))
})

# Capture the loaded namespace as well as each declared library's resolution.
dependency_richr_identity <- function() {
  loadNamespace("richR")
  libraries <- .libPaths()
  list(
    pid = Sys.getpid(), lib_paths = libraries,
    environment = as.list(Sys.getenv(c("R_LIBS", "R_LIBS_USER", "R_LIBS_SITE",
                              "RENV_CONFIG_AUTOLOADER_ENABLED", "R_PROFILE_USER",
                              "R_ENVIRON_USER"))),
    namespace_path = normalizePath(getNamespaceInfo(asNamespace("richR"), "path"),
                                   winslash = "/", mustWork = TRUE),
    namespace_version = as.character(getNamespaceVersion("richR")),
    package_path = normalizePath(find.package("richR"), winslash = "/", mustWork = TRUE),
    package_version = as.character(utils::packageVersion("richR")),
    library_packages = lapply(libraries, function(library) {
      package <- find.package("richR", lib.loc = library, quiet = TRUE)
      list(library = library,
           path = if (length(package)) normalizePath(package, winslash = "/", mustWork = TRUE) else "",
           version = if (length(package)) as.character(utils::packageVersion("richR", lib.loc = library)) else "")
    })
  )
}

dependency_richr_origin <- function(identity, expected_path, expected_version) {
  expected_path <- normalizePath(expected_path, winslash = "/", mustWork = TRUE)
  identical(identity$namespace_path, expected_path) &&
    identical(identity$package_path, expected_path) &&
    identical(identity$namespace_version, expected_version) &&
    identical(identity$package_version, expected_version) &&
    any(vapply(identity$library_packages, function(package) {
      identical(package$path, expected_path) && identical(package$version, expected_version)
    }, logical(1)))
}

test_that("the worker future uses the installed richR dispatch and preserves saved tables", {
  suppressPackageStartupMessages(library(richR))
  genes <- paste0("g", seq_len(20))
  parent <- dependency_richr_identity()
  cat("parent richR identity ", jsonlite::toJSON(parent, auto_unbox = TRUE), "\n", sep = "")
  expect_identical(parent$namespace_version, "0.1.5")
  expect_true(dependency_richr_origin(parent, parent$namespace_path, "0.1.5"))

  # Register before creating anything. Nested worker cleanup runs before this.
  temporary <- tempfile("richr-origin-")
  on.exit(unlink(temporary, recursive = TRUE), add = TRUE)
  dir.create(temporary)
  alias <- file.path(temporary, "alias")
  copied <- file.path(temporary, "copied")
  dir.create(alias)
  dir.create(copied)
  expect_true(file.symlink(parent$namespace_path, file.path(alias, "richR")))
  expect_true(file.copy(parent$namespace_path, copied, recursive = TRUE))
  copied_package <- normalizePath(file.path(copied, "richR"), winslash = "/", mustWork = TRUE)
  # A physical copy is required before any fixture metadata can be changed.
  stopifnot(startsWith(copied_package, paste0(normalizePath(temporary), "/")),
            !identical(copied_package, parent$namespace_path),
            !nzchar(Sys.readlink(file.path(copied, "richR"))))

  check_worker <- function(libraries, label, expected_origin, expected_version, routes) {
    old_plan <- future::plan()
    worker_pid <- integer()
    on.exit({
      future::plan(old_plan)
      deadline <- Sys.time() + 5
      while (length(worker_pid) && isTRUE(tools::pskill(worker_pid, 0L)) && Sys.time() < deadline) {
        Sys.sleep(0.01)
      }
      gone <- !length(worker_pid) || !isTRUE(tools::pskill(worker_pid, 0L))
      cat(sprintf("worker cleanup %s pid=%s gone=%s\n", label, paste(worker_pid, collapse = ","), gone))
      # Keep the alias/copy for diagnosis if shutdown was not acknowledged.
      if (!gone) {
        temporary <<- character()
        stop("Owned richR worker did not exit before fixture cleanup")
      }
    }, add = TRUE)
    future::plan(future::multisession, workers = I(1), rscript_libs = libraries)
    worker <- future::value(future::future({
      .libPaths(libraries, include.site = FALSE)
      dependency_richr_identity()
    }, packages = "richR", seed = TRUE))
    worker_pid <- worker$pid
    cat("worker richR identity ", label, " ", jsonlite::toJSON(worker, auto_unbox = TRUE), "\n", sep = "")
    expect_true(worker$pid != parent$pid)
    expect_identical(worker$namespace_version, expected_version)
    expect_identical(worker$package_version, expected_version)
    expect_identical(worker$namespace_path, if (label == "wrong-origin" || label == "wrong-version") copied_package else parent$namespace_path)
    expect_identical(dependency_richr_origin(worker, parent$namespace_path, "0.1.5"), expected_origin)
    if (label == "wrong-origin") {
      expect_true(dependency_richr_origin(worker, copied_package, "0.1.5"))
    }
    # Version rejection is independent of origin: use the copy's own true path.
    if (label == "wrong-version") {
      expect_false(dependency_richr_origin(worker, copied_package, "0.1.5"))
      expect_true(dependency_richr_origin(worker, copied_package, expected_version))
    }
    if (label == "valid-alias") {
      expect_false(any(grepl(dirname(worker$namespace_path), worker$lib_paths, fixed = TRUE)))
    }
    if (label == "ordinary") {
      unresolved <- future::value(future::future((function() {
        previous <- .libPaths()
        on.exit(.libPaths(previous), add = TRUE)
        .libPaths(previous[!vapply(previous, function(library) {
          package <- find.package("richR", lib.loc = library, quiet = TRUE)
          length(package) > 0L && identical(normalizePath(package, winslash = "/"), parent$namespace_path)
        }, logical(1))], include.site = FALSE)
        dependency_richr_identity()
      })(), packages = "richR", seed = TRUE))
      cat("worker richR identity undeclared-library ", jsonlite::toJSON(unresolved, auto_unbox = TRUE), "\n", sep = "")
      expect_identical(unresolved$namespace_path, parent$namespace_path)
      expect_identical(unresolved$namespace_version, "0.1.5")
      expect_false(dependency_richr_origin(unresolved, parent$namespace_path, "0.1.5"))
    }
    for (anntype in routes) {
      annotation <- dependency_annot_object(anntype, dependency_annotation_fixture(anntype, genes))
      job <- list(list(name = "one", df = data.frame(gene = genes[1:10]), gene_header = "gene"))
      task <- future::future({
        .libPaths(libraries, include.site = FALSE)
        list(identity = dependency_richr_identity(), results = run_enrichment_jobs(
          job, cutoff = 0.05, species = "custom", anntype = anntype,
          keytype = "SYMBOL", ontology = "BP", annotation_builder = function(...) annotation
        ))
      }, packages = "richR", seed = TRUE)
      observed <- future::value(task)
      cat(sprintf("worker route %s %s parent_pid=%d worker_pid=%d\n", label, anntype, parent$pid, observed$identity$pid))
      expect_identical(observed$identity, worker)
      result <- observed$results[[1]]$result
      expect_true(nrow(result) > 0)
      expect_identical(result$Annot, switch(
        anntype, GO = "GO:TEST1", KEGG = "01100", Reactome = "R-HSA-TEST1"
      ))
      expect_equal(result$GeneID[1], paste(genes[1:10], collapse = ","))
      expect_equal(result$Pvalue, stats::phyper(9, 10, 10, 10, lower.tail = FALSE))
      expect_equal(result$Padj, result$Pvalue)
      if (anntype == "KEGG") {
        expect_true(all(c("Level1", "Level2", "Level3") %in% names(result)))
      }

      legacy_session <- list(
        version = "1.0", created = Sys.time(), degnames = character(),
        degdfs = list(), rrnames = "one",
        rrdfs = list(one = result), clusnames = character(),
        clusdfs = list(), cluslists = list()
      )
      saved <- tempfile(fileext = ".json", tmpdir = temporary)
      richStudio:::session_json_write(legacy_session, saved)
      u_degnames <- shiny::reactiveValues(labels = character())
      u_degdfs <- shiny::reactiveValues()
      u_rrnames <- shiny::reactiveValues(labels = character())
      u_rrdfs <- shiny::reactiveValues()
      u_clusnames <- shiny::reactiveValues(labels = character())
      u_clusdfs <- shiny::reactiveValues()
      u_cluslists <- shiny::reactiveValues()
      shiny::testServer(
        saveTabServer,
        args = list(
          id = "save", u_degnames = u_degnames, u_degdfs = u_degdfs,
          u_rrnames = u_rrnames, u_rrdfs = u_rrdfs,
          u_clusnames = u_clusnames, u_clusdfs = u_clusdfs,
          u_cluslists = u_cluslists
        ),
        {
          session$setInputs(
            load_session_file = list(
              datapath = saved, name = "legacy.json", size = file.info(saved)$size,
              type = "application/octet-stream"
            ),
            load_session = 1
          )
          expect_identical(shiny::isolate(u_rrnames$labels), "one")
          expect_identical(shiny::isolate(u_rrdfs$one), result)
        }
      )
    }
  }
  routes <- c("GO", "KEGG", "Reactome")
  check_worker(parent$lib_paths, "ordinary", TRUE, "0.1.5", routes)
  # Preserve every other package and its precedence when replacing richR.
  other_libraries <- vapply(seq_along(parent$lib_paths), function(i) {
    library <- parent$lib_paths[[i]]
    if (!identical(parent$library_packages[[i]]$path, parent$namespace_path)) return(library)
    projection <- file.path(temporary, paste0("library-", i))
    stopifnot(dir.create(projection))
    projection <- normalizePath(projection, winslash = "/", mustWork = TRUE)
    stopifnot(startsWith(projection, paste0(normalizePath(temporary, winslash = "/"), "/")),
              !nzchar(Sys.readlink(projection)))
    packages <- list.files(library, full.names = TRUE)
    packages <- packages[basename(packages) != "richR" & dir.exists(packages) &
                           file.exists(file.path(packages, "DESCRIPTION"))]
    for (package in packages) {
      target <- normalizePath(package, winslash = "/", mustWork = TRUE)
      link <- file.path(projection, basename(package))
      stopifnot(identical(normalizePath(dirname(link), winslash = "/"), projection),
                file.symlink(target, link),
                identical(normalizePath(link, winslash = "/", mustWork = TRUE), target))
    }
    projection
  }, character(1))
  check_worker(c(alias, other_libraries), "valid-alias", TRUE, "0.1.5", routes)
  check_worker(c(copied, other_libraries), "wrong-origin", FALSE, "0.1.5", "Reactome")

  # Synthetic metadata-only mismatch, not an upstream richR release. Keep the
  # supported >=0.1.5 API so the actual route reaches the identity comparison.
  # Only the owned physical copy is changed; the valid alias is never written.
  description <- file.path(copied_package, "DESCRIPTION")
  metadata <- file.path(copied_package, "Meta", "package.rds")
  stopifnot(!nzchar(Sys.readlink(description)), !nzchar(Sys.readlink(metadata)),
            startsWith(normalizePath(description), paste0(copied_package, "/")),
            startsWith(normalizePath(metadata), paste0(copied_package, "/")))
  dcf <- read.dcf(description)
  dcf[1L, "Version"] <- "0.1.6"
  write.dcf(dcf, description)
  meta <- readRDS(metadata)
  meta$DESCRIPTION["Version"] <- "0.1.6"
  saveRDS(meta, metadata)
  check_worker(c(copied, other_libraries), "wrong-version", FALSE, "0.1.6", "Reactome")
})

test_that("standalone hierarchical clustering uses public paths and strict raw-Pvalue filtering", {
  first <- data.frame(
    Term = c("T1", "T2"), GeneID = c("g1,g2", "g2,g3"),
    Annot = c("one", "two"), Pvalue = c(0.01, 0.05), Padj = c(0.9, 0.001)
  )
  second <- data.frame(
    Term = c("T3", "T4"), GeneID = c("g1,g2", "g4,g5"),
    Annot = c("three", "four"), Pvalue = c(0.02, 0.05), Padj = c(1, 0.001)
  )
  empty <- data.frame(
    Term = "T5", GeneID = "g6,g7", Annot = "five",
    Pvalue = 0.05, Padj = 0.001
  )
  merged <- merge_genesets(list(first = first, second = second))
  result <- perform_clustering(
    merged, method = "hierarchical",
    params = list(min_terms = 1, min_value = 0.05),
    gs_names = c("first", "second", "empty"),
    raw_genesets = list(first = first, second = second, empty = empty)
  )

  expect_identical(names(result$raw_result$df_list), c("first", "second"))
  expect_identical(result$raw_result$df_list$first$Term, "T1")
  expect_identical(result$raw_result$df_list$second$Term, "T3")
  expect_false("empty" %in% names(result$raw_result$df_list))
  expect_identical(result$raw_result$cluster_options$filter_on, "Pvalue")
  expect_identical(result$raw_result$cluster_options$min_value, 1)
  expect_true(is.data.frame(result$cluster_df))

  one <- perform_clustering(
    merge_genesets(list(first = first)), method = "hierarchical",
    params = list(min_terms = 1, min_value = 0.05), gs_names = "first",
    raw_genesets = list(first = first)
  )
  expect_identical(one$raw_result$df_list$first$Term, "T1")
  expect_false(any(c("T2") %in% one$raw_result$merged_df$Term))
})

test_that("standalone richCluster availability requires the supported API version", {
  expect_true(is_richCluster_available())
  expect_false(is_richCluster_available(
    require_package = function(package, quietly) TRUE,
    package_version = function(package) package_version("1.0.2")
  ))
  expect_true(is_richCluster_available(
    require_package = function(package, quietly) TRUE,
    package_version = function(package) package_version("2.0.1")
  ))
  expect_false(is_richCluster_available(
    require_package = function(package, quietly) FALSE,
    package_version = function(package) stop("version should not be read")
  ))
})

test_that("DAVID public clustering retains terms without adding a significance filter", {
  genes <- paste0("g", seq_len(12))
  first <- data.frame(
    Term = paste0("T", seq_len(12)),
    GeneID = vapply(seq_len(12), function(i) paste(genes[i:(i + 2)], collapse = ","), character(1)),
    Annot = paste0("term", seq_len(12)), Pvalue = rep(0.9, 12), Padj = rep(0.99, 12)
  )
  second <- first
  second$Term <- paste0("S", seq_len(12))
  merged <- merge_genesets(list(first = first, second = second))

  result <- perform_clustering(
    merged, method = "david",
    params = list(initial_group_membership = 2, final_group_membership = 2),
    gs_names = c("first", "second"), raw_genesets = list(first = first, second = second)
  )

  expect_identical(result$raw_result$cluster_options$initial_group_membership, 2)
  expect_setequal(result$raw_result$df_list$first$Term, first$Term)
  expect_setequal(result$raw_result$df_list$second$Term, second$Term)
  expect_true(is.data.frame(result$cluster_df))

  single <- perform_clustering(
    merge_genesets(list(first = first)), method = "david",
    params = list(initial_group_membership = 2, final_group_membership = 2),
    gs_names = "first", raw_genesets = list(first = first)
  )
  expect_setequal(single$raw_result$df_list$first$Term, first$Term)
  expect_true(all(single$cluster_df$Term %in% single$raw_result$merged_df$Term))
  expect_true(all(single$cluster_df$Cluster %in% seq_len(nrow(single$cluster_summary))))
})

test_that("the vendored richStudio cluster wrapper retains its independent API", {
  terms <- c("term-a", "term-b", "term-c")
  genes <- c("g1,g2,g3", "g2,g3,g4", "g8,g9,g10")
  pvalues <- c(0.001, 0.01, 0.2)
  result <- richCluster(
    "kappa", 0.5, "DAVID", 0.7, terms, genes, pvalues
  )

  expect_named(result, c("DistanceMatrix", "SeedMap", "FilteredSeeds", "MergedSeeds"))
  expect_equal(dim(result$DistanceMatrix), c(3L, 3L))
  expect_identical(rownames(result$DistanceMatrix), terms)
  expect_identical(colnames(result$DistanceMatrix), terms)
  expect_true(all(diag(result$DistanceMatrix) == -99))
  expect_named(result$SeedMap, c("Term", "SignificantTermPairs", "Term_Index", "SignificantTermPair_Indices"))
  expect_named(result$FilteredSeeds, c("Term", "SignificantTermPairs", "Term_Index", "SignificantTermPair_Indices"))
  expect_named(result$MergedSeeds, c("Cluster", "ClusterIndices"))
  expect_equal(nrow(result$SeedMap), 0L)
  expect_equal(nrow(result$FilteredSeeds), 0L)
  expect_equal(nrow(result$MergedSeeds), 0L)
})

test_that("standalone clustering publishes exact memberships without positional aliases", {
  first <- data.frame(
    Term = c("shared", "first-only"), GeneID = c("a,b", "a,b"),
    Annot = c("shared", "first-only"), Pvalue = c(0.01, 0.02), Padj = c(0.9, 0.8)
  )
  second <- data.frame(
    Term = c("shared", "second-only"), GeneID = c("a,b", "x,y"),
    Annot = c("shared", "second-only"), Pvalue = c(0.05, 0.02), Padj = c(0.001, 0.9)
  )
  hierarchical <- perform_clustering(
    merge_genesets(list(first = first, second = second)), method = "hierarchical",
    params = list(min_terms = 1, min_value = 0.05, distance_metric = "jaccard",
                 distance_cutoff = 0.1, linkage_cutoff = 0.99),
    gs_names = c("first", "second"), raw_genesets = list(first = first, second = second)
  )

  expect_setequal(hierarchical$raw_result$df_list$first$Term, c("shared", "first-only"))
  expect_identical(hierarchical$raw_result$df_list$second$Term, "second-only")
  index_memberships <- lapply(strsplit(hierarchical$raw_result$all_clusters$TermIndices, ", "), function(x) {
    hierarchical$raw_result$merged_df$Term[as.integer(x) + 1L]
  })
  names(index_memberships) <- as.character(hierarchical$raw_result$all_clusters$Cluster)
  expect_identical(unname(index_memberships), list(c("first-only", "shared"), "second-only"))
  expect_setequal(hierarchical$cluster_df$Term, c("first-only", "shared", "second-only"))
  shared <- hierarchical$cluster_df[hierarchical$cluster_df$Term == "shared", , drop = FALSE]
  expect_equal(shared$GeneID_first, "a,b")
  expect_true(is.na(shared$GeneID_second))
  expect_equal(shared$Pvalue_first, 0.01)
  expect_true(is.na(shared$Pvalue_second))
  expect_false(any(grepl("^(Pvalue|Padj|GeneID)_[0-9]+$", names(hierarchical$cluster_df))))
  summary_metrics <- grep("^(Pvalue_|Padj_)", names(hierarchical$cluster_df), value = TRUE)
  expect_setequal(summary_metrics, c("Pvalue_first", "Padj_first", "Pvalue_second", "Padj_second"))
  expect_identical(hierarchical$raw_result$cluster_df$GeneID_1[
    match("shared", hierarchical$raw_result$cluster_df$Term)
  ], "a,b")

  single <- perform_clustering(
    merge_genesets(list(first = first)), method = "hierarchical",
    params = list(min_terms = 1, min_value = 0.05, distance_metric = "jaccard",
                 distance_cutoff = 0.1, linkage_cutoff = 0.99),
    gs_names = "first", raw_genesets = list(first = first)
  )
  expect_identical(single$raw_result$df_list$first$Term, c("shared", "first-only"))
  expect_false(any(grepl("^(Pvalue|Padj|GeneID)_[0-9]+$", names(single$cluster_df))))

  genes <- paste0("g", seq_len(8))
  david_input <- data.frame(
    Term = paste0("D", seq_len(8)),
    GeneID = vapply(seq_len(8), function(i) paste(genes[i:(i + 2)], collapse = ","), character(1)),
    Annot = paste0("david", seq_len(8)), Pvalue = rep(0.9, 8), Padj = rep(0.99, 8)
  )
  david <- perform_clustering(
    merge_genesets(list(first = david_input)), method = "david",
    params = list(initial_group_membership = 2, final_group_membership = 2),
    gs_names = "first", raw_genesets = list(first = david_input)
  )
  expect_true(nrow(david$cluster_df) > 0)
  expect_setequal(david$cluster_df$Term, c("D7", "D8"))
  expect_false(any(grepl("^(Pvalue|Padj|GeneID)_[0-9]+$", names(david$cluster_df))))
  expect_true(all(david$cluster_df$Pvalue_first == 0.9))
  expect_true(any(grepl("^(Pvalue|Padj|GeneID)_[0-9]+$", names(david$raw_result$cluster_df))))

  david_second <- david_input
  david_second$Term <- paste0("S", seq_len(8))
  david_second$Annot <- paste0("second", seq_len(8))
  david_multi <- perform_clustering(
    merge_genesets(list(first = david_input, second = david_second)), method = "david",
    params = list(initial_group_membership = 2, final_group_membership = 2),
    gs_names = c("first", "second"),
    raw_genesets = list(first = david_input, second = david_second)
  )
  memberships <- split(david_multi$cluster_df$Term, david_multi$cluster_df$Cluster)
  expect_identical(unname(lapply(memberships, sort)), list(
    c("D1", "S1"), c("D2", "S2"), c("D3", "S3"), c("D4", "S4"),
    c("D5", "S5"), c("D6", "S6"), c("D7", "D8", "S7", "S8")
  ))
  expect_true(all(is.na(david_multi$cluster_df$GeneID_second[
    startsWith(david_multi$cluster_df$Term, "D")
  ])))
  expect_true(all(is.na(david_multi$cluster_df$GeneID_first[
    startsWith(david_multi$cluster_df$Term, "S")
  ])))
  expect_false(any(grepl("^(Pvalue|Padj|GeneID)_[0-9]+$", names(david_multi$cluster_df))))
})

test_that("hierarchical output maps retained datasets after first or middle datasets drop", {
  geneset <- function(prefix, pvalue, gene_prefix) {
    data.frame(
      Term = paste0(prefix, seq_len(2)),
      GeneID = paste0(gene_prefix, seq_len(2), ",", gene_prefix, seq_len(2) + 10L),
      Annot = paste0(prefix, seq_len(2)),
      Pvalue = rep(pvalue, 2), Padj = rep(pvalue + 0.2, 2),
      stringsAsFactors = FALSE
    )
  }
  dropped <- geneset("drop", 0.05, "x")
  first <- geneset("first", 0.01, "a")
  middle <- geneset("middle", 0.05, "m")
  last <- geneset("last", 0.02, "z")
  params <- list(
    min_terms = 1, min_value = 0.05, distance_metric = "jaccard",
    distance_cutoff = 0.1, linkage_cutoff = 0.99
  )

  first_dropped <- perform_clustering(
    merge_genesets(list(dropped = dropped, `2` = first)),
    method = "hierarchical", params = params,
    gs_names = c("dropped", "2"),
    raw_genesets = list(dropped = dropped, `2` = first)
  )
  expect_identical(names(first_dropped$raw_result$df_list), "2")
  expect_setequal(first_dropped$cluster_df$Term, first$Term)
  for (i in seq_along(first$Term)) {
    row <- first_dropped$cluster_df[first_dropped$cluster_df$Term == first$Term[[i]], , drop = FALSE]
    expect_identical(row$GeneID_2, first$GeneID[[i]])
    expect_equal(row$Pvalue_2, first$Pvalue[[i]])
    expect_equal(row$Padj_2, first$Padj[[i]])
    expect_true(!"GeneID_dropped" %in% names(first_dropped$cluster_df) || is.na(row$GeneID_dropped))
  }
  expect_identical(first_dropped$raw_result$cluster_df$GeneID_1,
                   first$GeneID[match(first_dropped$raw_result$cluster_df$Term, first$Term)])

  middle_dropped <- perform_clustering(
    merge_genesets(list(`2` = first, dropped = middle, `1` = last)),
    method = "hierarchical", params = params,
    gs_names = c("2", "dropped", "1"),
    raw_genesets = list(`2` = first, dropped = middle, `1` = last)
  )
  expect_identical(names(middle_dropped$raw_result$df_list), c("2", "1"))
  expect_setequal(middle_dropped$cluster_df$Term, c(first$Term, last$Term))
  retained <- list(`2` = first, `1` = last)
  for (dataset_name in names(retained)) {
    frame <- retained[[dataset_name]]
    for (i in seq_along(frame$Term)) {
      row <- middle_dropped$cluster_df[middle_dropped$cluster_df$Term == frame$Term[[i]], , drop = FALSE]
      expect_identical(row[[paste0("GeneID_", dataset_name)]], frame$GeneID[[i]])
      expect_equal(row[[paste0("Pvalue_", dataset_name)]], frame$Pvalue[[i]])
      expect_equal(row[[paste0("Padj_", dataset_name)]], frame$Padj[[i]])
      expect_true(!"GeneID_dropped" %in% names(middle_dropped$cluster_df) || is.na(row$GeneID_dropped))
    }
  }
  expect_true(all(middle_dropped$raw_result$merged_df$Term %in% c(first$Term, last$Term)))
  expect_identical(middle_dropped$raw_result$cluster_df$GeneID_2,
                   last$GeneID[match(middle_dropped$raw_result$cluster_df$Term, last$Term)])
})

test_that("enrichment observer publishes valid-empty results and rejects batches atomically", {
  old_plan <- future::plan()
  on.exit(future::plan(old_plan), add = TRUE)
  future::plan(future::multisession, workers = I(1))

  deg_names <- shiny::reactiveValues(labels = c("first", "second"))
  deg_dfs <- shiny::reactiveValues(
    first = data.frame(gene = "g1"), second = data.frame(gene = "g2")
  )
  big_deg <- shiny::reactiveValues(df = data.frame(
    name = c("first", "second"), GeneID_header = c("gene", "gene")
  ))
  rr_names <- shiny::reactiveValues(labels = "old_enriched")
  old_result <- data.frame(Term = "old", GeneID = "old1,old2")
  rr_dfs <- shiny::reactiveValues(old_enriched = old_result)
  big_rr <- shiny::reactiveValues(df = add_file_rrdf(NULL, "old", file = FALSE))

  empty_state <- new.env(parent = emptyenv())
  empty_state$done <- tempfile()
  empty_runner <- function(deg_inputs, ...) {
    on.exit(file.create(empty_state$done), add = TRUE)
    list(list(name = deg_inputs[[1]]$name, result = data.frame(
      Annot = character(), Term = character(), Pvalue = double(), Padj = double(), GeneID = character()
    ), anntype = "Reactome", keytype = "SYMBOL", ontology = "", species = "custom"))
  }
  wait_until <- function(predicate, timeout = 10) {
    deadline <- Sys.time() + timeout
    while (!predicate() && Sys.time() < deadline) later::run_now(timeoutSecs = 0.1)
    predicate()
  }
  shiny::testServer(enrichTabServer, args = list(
    id = "enrich", u_degnames = deg_names, u_degdfs = deg_dfs, u_big_degdf = big_deg,
    u_rrnames = rr_names, u_rrdfs = rr_dfs, u_big_rrdf = big_rr,
    enrichment_runner = empty_runner
  ), {
    session$setInputs(degs_to_enrich = "first", enrich_deg = 1)
    expect_true(wait_until(function() identical(shiny::isolate(u_rrnames$labels),
                                                c("old_enriched", "first_enriched"))))
    expect_true(file.exists(empty_state$done))
    expect_identical(shiny::isolate(u_rrnames$labels), c("old_enriched", "first_enriched"))
    expect_equal(nrow(shiny::isolate(u_rrdfs$first_enriched)), 0L)
    expect_true("first_enriched" %in% shiny::isolate(u_big_rrdf$df$name))
  })

  rr_names$labels <- "old_enriched"
  rr_dfs$first_enriched <- NULL
  big_rr$df <- add_file_rrdf(NULL, "old", file = FALSE)
  failing_state <- new.env(parent = emptyenv())
  failing_state$done <- tempfile()
  failing_runner <- function(deg_inputs, ...) {
    on.exit(file.create(failing_state$done), add = TRUE)
    results <- list()
    for (job in deg_inputs) {
      if (job$name == "second") stop("second job failed")
      results[[length(results) + 1L]] <- list(
        name = job$name, result = data.frame(Term = "partial"), anntype = "Reactome",
        keytype = "SYMBOL", ontology = "", species = "custom"
      )
    }
    results
  }
  shiny::testServer(enrichTabServer, args = list(
    id = "enrich", u_degnames = deg_names, u_degdfs = deg_dfs, u_big_degdf = big_deg,
    u_rrnames = rr_names, u_rrdfs = rr_dfs, u_big_rrdf = big_rr,
    enrichment_runner = failing_runner
  ), {
    session$setInputs(degs_to_enrich = c("first", "second"), enrich_deg = 1)
    expect_true(wait_until(function() file.exists(failing_state$done)))
    later::run_now(timeoutSecs = 0.2)
    expect_identical(shiny::isolate(u_rrnames$labels), "old_enriched")
    expect_identical(shiny::isolate(u_rrdfs$old_enriched), old_result)
    expect_null(shiny::isolate(u_rrdfs$first_enriched))
    expect_identical(shiny::isolate(u_big_rrdf$df$name), "old_enriched")
  })
})

test_that("session download handler writes an enrichment result that reloads", {
  produced <- data.frame(
    Annot = c("Term one", "Term two"), Term = c("T1", "T2"),
    Pvalue = c(0.01, 0.02), Padj = c(0.03, 0.04),
    GeneID = c("g1,g2", "g2,g3"), Level1 = c("L1", "L1"),
    stringsAsFactors = FALSE
  )
  deg_names <- shiny::reactiveValues(labels = "deg1")
  deg_dfs <- shiny::reactiveValues(deg1 = data.frame(gene = c("g1", "g2", "g3")))
  rr_names <- shiny::reactiveValues(labels = "deg1_enriched")
  rr_dfs <- shiny::reactiveValues(deg1_enriched = produced)
  clus_names <- shiny::reactiveValues(labels = character())
  clus_dfs <- shiny::reactiveValues()
  clus_lists <- shiny::reactiveValues()
  download_capture <- new.env(parent = emptyenv())
  download_factory <- function(filename, content, ...) {
    download_capture$handler <- list(filename = filename, content = content)
    shiny::downloadHandler(filename = filename, content = content, ...)
  }
  saved <- tempfile(fileext = ".json")

  shiny::testServer(saveTabServer, args = list(
    id = "save", u_degnames = deg_names, u_degdfs = deg_dfs,
    u_rrnames = rr_names, u_rrdfs = rr_dfs,
    u_clusnames = clus_names, u_clusdfs = clus_dfs, u_cluslists = clus_lists,
    download_handler = download_factory
  ), {
    session$setInputs(session_name = "dependency roundtrip")
    expect_identical(download_capture$handler$filename(), "dependency roundtrip.json")
    download_capture$handler$content(saved)
  })

  expect_true(file.exists(saved))
  session_data <- jsonlite::read_json(saved, simplifyVector = TRUE)
  expect_identical(session_data$version, "1.0")
  expect_identical(session_data$rrnames, "deg1_enriched")

  loaded_rr_names <- shiny::reactiveValues(labels = character())
  loaded_rr_dfs <- shiny::reactiveValues()
  shiny::testServer(saveTabServer, args = list(
    id = "load", u_degnames = shiny::reactiveValues(labels = character()),
    u_degdfs = shiny::reactiveValues(), u_rrnames = loaded_rr_names,
    u_rrdfs = loaded_rr_dfs, u_clusnames = shiny::reactiveValues(labels = character()),
    u_clusdfs = shiny::reactiveValues(), u_cluslists = shiny::reactiveValues()
  ), {
    session$setInputs(
      load_session_file = list(datapath = saved, name = basename(saved),
                               size = file.info(saved)$size, type = "application/octet-stream"),
      load_session = 1
    )
    expect_identical(shiny::isolate(u_rrnames$labels), "deg1_enriched")
    expect_identical(shiny::isolate(u_rrdfs$deg1_enriched), produced)
  })
})

test_that("numeric dataset labels keep their positional values in reversed order", {
  clustered <- data.frame(
    Term = "shared", Pvalue_1 = 0.01, Padj_1 = 0.1, GeneID_1 = "g1,g2",
    Pvalue_2 = 0.02, Padj_2 = 0.2, GeneID_2 = "g3,g4"
  )
  merged <- data.frame(
    Term = "shared", Pvalue_2 = 0.99, Padj_2 = 0.99, GeneID_2 = "wrong-2",
    Pvalue_1 = 0.98, Padj_1 = 0.98, GeneID_1 = "wrong-1"
  )
  mapped <- add_geneset_columns(clustered, merged, c("2", "1"))
  mapped <- drop_numeric_dataset_aliases(mapped, c("2", "1"))

  expect_equal(mapped$Pvalue_2, 0.01)
  expect_equal(mapped$Padj_2, 0.1)
  expect_equal(mapped$GeneID_2, "g1,g2")
  expect_equal(mapped$Pvalue_1, 0.02)
  expect_equal(mapped$Padj_1, 0.2)
  expect_equal(mapped$GeneID_1, "g3,g4")
  expect_setequal(names(mapped), c(
    "Term", "Pvalue_1", "Padj_1", "GeneID_1", "Pvalue_2", "Padj_2", "GeneID_2"
  ))
})
