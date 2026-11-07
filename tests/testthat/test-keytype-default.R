# Per-species default gene ID type, and the Run check against the installed package's ID types.

test_that("yeast defaults to GENENAME and every other species to SYMBOL", {
  expect_identical(enrich_keytype_default("yeast"), "GENENAME")
  for (sp in c("human", "mouse", "rat", "zebrafish", "celegans", "fly", "arabidopsis")) {
    expect_identical(enrich_keytype_default(sp), "SYMBOL")
  }
})

test_that("the gene ID type follows the species only while it holds the previous default", {
  expect_identical(enrich_keytype_follow(NULL, "yeast", "SYMBOL"), "GENENAME")
  expect_identical(enrich_keytype_follow("human", "yeast", "SYMBOL"), "GENENAME")
  expect_identical(enrich_keytype_follow("yeast", "mouse", "GENENAME"), "SYMBOL")
  expect_null(enrich_keytype_follow("human", "mouse", "SYMBOL"))
  expect_null(enrich_keytype_follow("human", "yeast", "ENSEMBL"))
  expect_null(enrich_keytype_follow("yeast", "human", "ORF"))
})

test_that("a gene ID type missing from the package gives a plain reason; unknown types never refuse", {
  yeast <- c("ENTREZID", "GENENAME", "ORF", "SGD")
  msg <- annotation_keytype_problem("yeast", "SYMBOL", yeast)
  expect_match(msg, "no 'SYMBOL' gene IDs", fixed = TRUE)
  expect_match(msg, "GENENAME, ENTREZID, ORF, SGD", fixed = TRUE)
  expect_null(annotation_keytype_problem("yeast", "GENENAME", yeast))
  expect_null(annotation_keytype_problem("yeast", "SYMBOL", NULL))
})

test_that("the Run gate refuses an installed species whose package lacks the gene ID type", {
  lib <- withr::local_tempdir()
  withr::local_envvar(RICHSTUDIO_ANNOTATION_LIB = lib)
  notes <- list()
  testthat::local_mocked_bindings(
    showNotification = function(ui, ...) { notes[[length(notes) + 1L]] <<- as.character(ui); invisible(NULL) },
    .package = "shiny")
  deps <- annotation_deps()
  deps$state <- function(lib, pkg) "present"
  asked <- character()
  deps$keytypes <- function(lib, pkg) { asked <<- c(asked, pkg); c("ENTREZID", "GENENAME", "ORF") }
  jobs <- new.env(parent = emptyenv())
  started <- 0L
  go <- function() started <<- started + 1L
  expect_identical(annotation_install_gate(jobs, NULL, "yeast", "GO", "SYMBOL", go, deps), "refused")
  expect_identical(started, 0L)
  expect_match(notes[[1L]], "Run not started. The yeast annotation has no 'SYMBOL'", fixed = TRUE)
  expect_identical(annotation_install_gate(jobs, NULL, "yeast", "GO", "GENENAME", go, deps), "started")
  expect_identical(started, 1L)
  expect_identical(unique(asked), "org.Sc.sgd.db")
  # Reactome with ENTREZID needs no organism package, so there is nothing to check.
  asked <- character()
  expect_identical(annotation_install_gate(jobs, NULL, "yeast", "Reactome", "ENTREZID", go, deps), "started")
  expect_length(asked, 0L)
})
