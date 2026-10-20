workspace_fixture <- function(name) {
  root <- Sys.getenv("WORKSPACE_SOURCE_ROOT", unset = "")
  if (nzchar(root)) file.path(root, "tests", "fixtures", "workspace", name) else
    testthat::test_path("..", "fixtures", "workspace", name)
}

test_that("installed scientific routes retain the annotated-universe oracle", {
  suppressPackageStartupMessages(library(richR))
  annotation <- read.delim(workspace_fixture("annotation.tsv"))
  query <- read.delim(workspace_fixture("query.tsv"))
  background <- read.delim(workspace_fixture("background.tsv"))$gene
  expect_identical(sort(unique(annotation$GeneID)), sort(background))
  expected <- 1 / choose(20, 10)
  for (route in c("GO", "KEGG", "Reactome")) {
    builder <- function(...) {
      annot <- annotation
      if (route == "GO") {
        annot$GOALL <- paste0("GO:", annot$Term)
        annot$ONTOLOGYALL <- "BP"
        annot$Annot <- annot$GOALL
      }
      if (route == "KEGG") annot$Term <- ifelse(annot$Term == "A", "01100", "01110")
      methods::new(methods::getClassDef("Annot", where = asNamespace("richR")),
                   species = "custom", anntype = route, keytype = "SYMBOL", annot = annot)
    }
    result <- richStudio:::run_enrichment_jobs(list(list(name = "query", df = query, gene_header = "gene")),
      cutoff = 0.05, species = "custom", anntype = route, keytype = "SYMBOL",
      ontology = "BP", annotation_builder = builder)[[1]]$result
    expect_equal(nrow(result), 1L)
    expect_equal(result$Pvalue, expected, tolerance = 1e-12)
    expect_equal(result$Padj, expected, tolerance = 1e-12)
    expect_equal(result$Annotated, 10)
    expect_equal(result$Significant, 10)
  }
  # Explicit two-term family: 3 of 4 query genes in A (K=5,N=10),
  # 1 in B. BH over A,B gives min(1, 2 * 11/42) and 41/42.
  annot <- data.frame(GeneID = paste0("g", 1:10), Term = rep(c("A", "B"), each = 5))
  object <- methods::new("Annot", species = "custom", anntype = "Reactome", keytype = "SYMBOL", annot = annot)
  family <- richR::enrich(x = c("g1", "g2", "g3", "g6"), object = object,
    universe = paste0("g", 1:10), pvalue = 1, minGSSize = 1, minSize = 1)@result
  expect_setequal(family$Term, c("A", "B"))
  expect_equal(family$Pvalue[match("A", family$Term)], 11 / 42, tolerance = 1e-12)
  expect_equal(family$Padj[match("A", family$Term)], 11 / 21, tolerance = 1e-12)
  expect_equal(family$Padj[match("B", family$Term)], 41 / 42, tolerance = 1e-12)
})

test_that("all three installed engines preserve their distinct threshold semantics", {
  input <- read.delim(workspace_fixture("imported-results.tsv"))
  original <- input
  for (method in c("richR", "hierarchical", "david")) {
    params <- list(cutoff = 0.1, overlap = 0, minSize = 2, min_value = 0.05,
      distance_metric = "jaccard", distance_cutoff = 0.1, linkage_cutoff = 1,
      min_terms = 1, similarity_threshold = 0.1, initial_group_membership = 1,
      final_group_membership = 1, multiple_linkage_threshold = 0.5)
    result <- richStudio::perform_clustering(input, method = method, params = params,
      gs_names = "fixture", raw_genesets = list(fixture = input))
    expect_identical(result$method, method)
    expect_gt(nrow(result$cluster_df), 0L)
    expect_true(all(result$cluster_df$Term %in% input$Term))
    if (method == "hierarchical") {
      expect_false("D" %in% result$cluster_df$Term)
      expect_true("A" %in% result$cluster_df$Term)
    }
    if (method == "david") expect_true("D" %in% result$cluster_df$Term)
    if (method == "richR") {
      union <- unique(unlist(strsplit(input$GeneID, ",", fixed = TRUE)))
      expect_equal(result$raw_result, richR::richCluster(input, gene = union, cutoff = 0.1, overlap = 0, minSize = 2))
    }
  }
  expect_identical(input, original)
})

test_that("version 1.0 data-only fixture generates a trusted disposable RDS", {
  fixture <- jsonlite::fromJSON(workspace_fixture("legacy-session-v1.json"), simplifyVector = TRUE)
  expect_identical(fixture$version, "1.0")
  file <- tempfile(fileext = ".rds")
  on.exit(unlink(file), add = TRUE)
  saveRDS(fixture, file)
  expect_identical(readRDS(file), fixture)
  expect_equal(fixture$rrdfs$imported$Pvalue, 1e-8)
  expect_identical(fixture$rrdfs$imported$ProviderExtra, "retained-a")
})
