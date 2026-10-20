# Characterize the installed legacy module with owned synthetic session files.
# RDS cases describe trusted compatibility only, not untrusted-input safety.

test_that("RDS session save and restore preserves multidataset values and types", {
  state <- ws_baseline_state(populated = TRUE)
  empty <- ws_baseline_results()$treated[FALSE, , drop = FALSE]
  state$u_rrnames$labels <- c("untreated", "treated", "empty")
  state$u_rrdfs$empty <- empty
  saved <- withr::local_tempfile(pattern = "B5-owned-session-", fileext = ".rds")
  withr::defer(unlink(paste0(saved, ".lock")))
  callbacks <- new.env(parent = emptyenv())
  capture_download <- function(filename, content, ...) {
    callbacks$filename <- filename
    callbacks$content <- content
    shiny::downloadHandler(filename, content, ...)
  }
  args <- state[c("u_degnames", "u_degdfs", "u_rrnames", "u_rrdfs",
                  "u_clusnames", "u_clusdfs", "u_cluslists")]
  args$download_handler <- capture_download
  shiny::testServer(richStudio::saveTabServer, args = args, {
    session$setInputs(session_name = "../study:one", save_format = "rds")
    expect_identical(callbacks$filename(), "_study_one.rds")
    callbacks$content(saved)
    expect_false(file.exists(paste0(saved, ".lock")))
    expect_identical(output$rr_summary,
                     "3 enrichment result(s):\nuntreated\ntreated\nempty")
  })
  payload <- readRDS(saved)
  expect_identical(payload$version, "1.0")
  expect_s3_class(payload$created, "POSIXct")
  expect_identical(payload$rrdfs$empty, empty)
  expect_identical(payload$rrdfs$treated$Padj, c(0.04, NA_real_, 0.3))
  expect_identical(payload$cluslists$fixture$Padj_treated,
                   c(0.04, NA_real_, NA_real_, 0.3))

  restored <- ws_baseline_state()
  args <- restored[names(args)[names(args) != "download_handler"]]
  shiny::testServer(richStudio::saveTabServer, args = args, {
    expect_identical(output$deg_summary, "No DEG sets loaded")
    expect_identical(output$rr_summary, "No enrichment results")
    expect_identical(output$clus_summary, "No clustering results")
    session$setInputs(load_session_file = list(name = "owned.RDS", datapath = saved))
    session$setInputs(load_session = 1L)
    expect_identical(u_degnames$labels, payload$degnames)
    expect_identical(u_rrnames$labels, payload$rrnames)
    expect_identical(u_clusnames$labels, payload$clusnames)
    for (name in names(payload$degdfs)) {
      expect_identical(u_degdfs[[name]], payload$degdfs[[name]])
    }
    for (name in names(payload$rrdfs)) {
      expect_identical(u_rrdfs[[name]], payload$rrdfs[[name]])
    }
    expect_identical(u_clusdfs$fixture, payload$clusdfs$fixture)
    expect_identical(u_cluslists$fixture, payload$cluslists$fixture)
    expect_identical(output$clus_summary, "1 clustering result(s):\nfixture")
  })
})

test_that("JSON session download restores populated tables and missing values", {
  state <- ws_baseline_state(populated = TRUE)
  saved <- withr::local_tempfile(pattern = "B5-owned-session-", fileext = ".json")
  withr::defer(unlink(paste0(saved, ".lock")))
  callbacks <- new.env(parent = emptyenv())
  args <- state[c("u_degnames", "u_degdfs", "u_rrnames", "u_rrdfs",
                  "u_clusnames", "u_clusdfs", "u_cluslists")]
  args$download_handler <- function(filename, content, ...) {
    callbacks$filename <- filename
    callbacks$content <- content
    shiny::downloadHandler(filename, content, ...)
  }
  shiny::testServer(richStudio::saveTabServer, args = args, {
    session$setInputs(session_name = "...", save_format = "json")
    expect_identical(callbacks$filename(), "export.json")
    callbacks$content(saved)
    expect_false(file.exists(paste0(saved, ".lock")))
  })
  serialized <- jsonlite::read_json(saved, simplifyVector = TRUE)
  expect_identical(serialized$rrnames, c("untreated", "treated"))
  expect_equal(serialized$rrdfs$treated$Padj, c(0.04, NA_real_, 0.3))
  restored <- ws_baseline_state()
  args <- restored[names(args)[names(args) != "download_handler"]]
  expected <- ws_baseline_session()
  shiny::testServer(richStudio::saveTabServer, args = args, {
    session$setInputs(load_session_file = list(name = "owned.JSON", datapath = saved))
    session$setInputs(load_session = 1L)
    expect_identical(u_rrnames$labels, c("untreated", "treated"))
    for (name in expected$rrnames) {
      expect_equal(u_rrdfs[[name]], expected$rrdfs[[name]], tolerance = 1e-12)
    }
    expect_equal(u_degdfs$query, expected$degdfs$query)
    expect_equal(u_clusdfs$fixture, expected$clusdfs$fixture, tolerance = 1e-12)
    expect_equal(u_cluslists$fixture, expected$cluslists$fixture, tolerance = 1e-12)
    expect_true(is.na(u_rrdfs$treated$Padj[2L]))
    expect_false("B" %in% u_rrdfs$treated$Term)
  })
})

test_that("empty RDS sessions restore empty labels and typed empty tables", {
  payload <- ws_baseline_session()
  payload$degnames <- character()
  payload$degdfs <- list()
  payload$rrnames <- "empty"
  payload$rrdfs <- list(empty = payload$rrdfs$treated[FALSE, , drop = FALSE])
  payload$clusnames <- character()
  payload$clusdfs <- list()
  payload$cluslists <- list()
  saved <- withr::local_tempfile(pattern = "B5-owned-session-", fileext = ".rds")
  saveRDS(payload, saved)
  state <- ws_baseline_state()
  args <- state[c("u_degnames", "u_degdfs", "u_rrnames", "u_rrdfs",
                  "u_clusnames", "u_clusdfs", "u_cluslists")]
  shiny::testServer(richStudio::saveTabServer, args = args, {
    session$setInputs(load_session_file = list(name = "empty.rds", datapath = saved))
    session$setInputs(load_session = 1L)
    expect_identical(u_degnames$labels, character())
    expect_identical(u_clusnames$labels, character())
    expect_identical(u_rrdfs$empty, payload$rrdfs$empty)
    expect_identical(output$deg_summary, "No DEG sets loaded")
    expect_identical(output$rr_summary, "1 enrichment result(s):\nempty")
    expect_identical(output$clus_summary, "No clustering results")
  })
})

test_that("rejected session files leave populated analysis state unchanged", {
  state <- ws_baseline_state(populated = TRUE)
  expected <- ws_baseline_session()
  saved <- withr::local_tempfile(pattern = "B5-owned-session-", fileext = ".rds")
  locked <- withr::local_tempfile(pattern = "B5-owned-session-", fileext = ".rds")
  lock <- paste0(locked, ".lock")
  withr::defer(unlink(lock))
  saveRDS(list(created = "not a versioned session"), saved)
  saveRDS(expected, locked)
  expect_true(file.create(lock))
  args <- state[c("u_degnames", "u_degdfs", "u_rrnames", "u_rrdfs",
                  "u_clusnames", "u_clusdfs", "u_cluslists")]
  shiny::testServer(richStudio::saveTabServer, args = args, {
    uploads <- list(
      list(name = "invalid.rds", datapath = saved),
      list(name = "unsupported.txt", datapath = saved),
      list(name = "locked.rds", datapath = locked)
    )
    for (i in seq_along(uploads)) {
      session$setInputs(load_session_file = uploads[[i]])
      session$setInputs(load_session = i)
      expect_identical(u_degnames$labels, expected$degnames)
      expect_identical(u_rrnames$labels, expected$rrnames)
      expect_identical(u_clusnames$labels, expected$clusnames)
      expect_identical(u_degdfs$query, expected$degdfs$query)
      expect_identical(u_rrdfs$untreated, expected$rrdfs$untreated)
      expect_identical(u_rrdfs$treated, expected$rrdfs$treated)
      expect_identical(u_clusdfs$fixture, expected$clusdfs$fixture)
      expect_identical(u_cluslists$fixture, expected$cluslists$fixture)
      expect_identical(output$rr_summary, "2 enrichment result(s):\nuntreated\ntreated")
    }
  })
  expect_true(file.exists(lock))
})

test_that("DEG import metadata identifies headers without changing source values", {
  inputs <- list(
    symbol = data.frame(SYMBOL = c("g1", NA_character_, "g1")),
    fallback = data.frame(accession = c("g2", "g3"), effect = c(1.25, NA_real_)),
    ambiguous = data.frame(gene_id = c("g4", "g5"), SYMBOL = c("s4", "s5")),
    empty = data.frame(GeneID = character(), effect = double())
  )
  original <- inputs
  metadata <- NULL
  for (name in names(inputs)) {
    metadata <- richStudio::add_file_degdf(metadata, name, inputs[[name]])
  }
  expect_identical(metadata$name, names(inputs))
  expect_identical(metadata$GeneID_header, c("SYMBOL", "accession", "gene_id", "GeneID"))
  expect_identical(metadata$num_genes, c("3", "2", "2", "0"))
  expect_identical(metadata$has_expr_data, c("False", "True", "True", "True"))
  expect_identical(inputs, original)
  expect_identical(richStudio::add_file_degdf(metadata, "symbol", inputs$empty), metadata)
  remaining <- richStudio::rm_file_degdf(metadata, metadata[c(1L, 3L), , drop = FALSE])
  expect_identical(remaining$name, c("fallback", "empty"))
  expect_identical(remaining$num_genes, c("2", "0"))
})

test_that("result metadata preserves origin and cluster dataset relationships", {
  imported <- richStudio::add_file_rrdf(NULL, "external", file = TRUE)
  generated <- richStudio::add_file_rrdf(imported, "query", annot = "GO",
                                       keytype = "SYMBOL", ontology = "BP", species = "human")
  expect_identical(generated$name, c("external", "query_enriched"))
  expect_identical(generated$from_deg, c("No", "query"))
  expect_identical(generated$annot, c("?", "GO"))
  expect_identical(generated$keytype, c("?", "SYMBOL"))
  expect_identical(generated$ontology, c("?", "BP"))
  expect_identical(generated$species, c("?", "human"))
  expect_identical(richStudio::add_file_rrdf(generated, "external", file = TRUE), generated)
  expect_identical(richStudio::rm_file_rrdf(generated, imported)$name, "query_enriched")

  tables <- ws_baseline_cluster_tables()
  clusters <- richStudio::add_file_clusdf(NULL, tables$summary, "joint", c("untreated", "treated"))
  clusters <- richStudio::add_file_clusdf(clusters, tables$summary[FALSE, ], "empty", character())
  expect_identical(clusters$name, c("joint", "empty"))
  expect_identical(clusters$n_clusters, c("2", "0"))
  expect_identical(clusters$from, c("untreated, treated", ""))
  expect_identical(richStudio::add_file_clusdf(clusters, tables$summary, "joint", "other"), clusters)
  expect_identical(richStudio::rm_file_clusdf(clusters, clusters[1L, ])$name, "empty")
})

test_that("top-term heatmap settings update only the selected dataset", {
  settings <- richStudio::add_rr_tophmap(NULL, "untreated", "Padj", 0.05, 10L)
  settings <- richStudio::add_rr_tophmap(settings, "treated", "Pvalue", 0.01, 5L)
  other <- settings[2L, , drop = FALSE]
  updated <- richStudio::add_rr_tophmap(settings, "untreated", "Pvalue", 0.001, 3L)
  expect_identical(updated$name, c("untreated", "treated"))
  expect_identical(updated$value_type, c("Pvalue", "Pvalue"))
  expect_identical(updated$value_cutoff, c("0.001", "0.01"))
  expect_identical(updated$top_nterms, c("3", "5"))
  expect_identical(updated[2L, , drop = FALSE], other)
  expect_identical(settings$value_type, c("Padj", "Pvalue"))
})
