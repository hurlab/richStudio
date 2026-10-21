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

test_that("save UI exposes namespaced session and export controls with format guidance", {
  html <- as.character(richStudio::saveTabUI("persist", "saved-analysis"))
  expect_match(html, 'id="shiny-tab-saved-analysis"', fixed = TRUE)
  expect_match(html, "Save &amp; Load Analysis Session", fixed = TRUE)
  for (control in c("session_name", "save_format", "download_session",
                    "load_session_file", "load_session", "deg_summary",
                    "rr_summary", "clus_summary", "export_rr_select",
                    "export_rr_format", "export_rr", "export_clus_select",
                    "export_clus_format", "export_clus", "export_all")) {
    expect_match(html, paste0('id="persist-', control, '"'), fixed = TRUE)
  }
  for (control in c("session_name", "load_session_file", "export_rr_select",
                    "export_rr_format", "export_clus_select", "export_clus_format")) {
    expect_match(html, paste0('for="persist-', control, '"'), fixed = TRUE)
  }
  expect_match(html, 'name="persist-save_format" value="rds" checked="checked"', fixed = TRUE)
  expect_match(html, 'name="persist-save_format" value="json"', fixed = TRUE)
  expect_match(html, 'accept=".rds,.json,.RDS,.JSON"', fixed = TRUE)
  expect_match(html, "RDS format preserves all R objects exactly.", fixed = TRUE)
  expect_match(html, "JSON format is more portable but may lose some data types.", fixed = TRUE)
  expect_match(html, "Loading a session will replace your current analysis state.", fixed = TRUE)
  expect_match(html, "Download all results as a ZIP archive", fixed = TRUE)
  for (kind in c("rr", "clus")) {
    select <- regmatches(html, regexpr(
      paste0('<select id="persist-export_', kind, '_format"[^>]*>[\\s\\S]*?</select>'),
      html, perl = TRUE))
    expect_length(select, 1L)
    expect_match(select, '<option value="csv" selected>CSV</option>', fixed = TRUE)
    expect_match(select, '<option value="tsv">TSV</option>', fixed = TRUE)
    expect_match(select, '<option value="xlsx">Excel</option>', fixed = TRUE)
  }
})

test_that("registered dataset downloads preserve enrichment and cluster content in each format", {
  state <- ws_baseline_state(populated = TRUE)
  expected <- list(rr = ws_baseline_results()$treated,
                   clus = ws_baseline_cluster_tables()$summary)
  expected$clus$provider_metric <- c(NA_real_, pi)
  state$u_rrdfs[["../treated:one"]] <- expected$rr
  state$u_clusdfs[["../cluster:one"]] <- expected$clus
  downloads <- new.env(parent = emptyenv())
  downloads$paths <- character()
  args <- state[c("u_degnames", "u_degdfs", "u_rrnames", "u_rrdfs",
                  "u_clusnames", "u_clusdfs", "u_cluslists")]
  shiny::testServer(richStudio::saveTabServer, args = args, {
    for (format in c("csv", "tsv", "xlsx")) {
      session$setInputs(export_rr_select = "../treated:one", export_rr_format = format,
                        export_clus_select = "../cluster:one", export_clus_format = format)
      for (kind in c("rr", "clus")) {
        path <- output[[paste0("export_", kind)]]
        downloads$paths <- c(downloads$paths, path)
        expect_true(file.exists(path))
        stem <- if (kind == "rr") "_treated_one" else "_cluster_one"
        expect_identical(basename(path), paste0(stem, ".", format))
        actual <- switch(format,
          csv = read.csv(path, check.names = FALSE),
          tsv = read.delim(path, check.names = FALSE),
          xlsx = as.data.frame(readxl::read_xlsx(path)))
        expect_identical(names(actual), names(expected[[kind]]))
        expect_equal(actual, expected[[kind]], tolerance = 1e-12)
        if (kind == "rr") {
          expect_identical(actual$Term, c("A", "C", "D"))
          expect_equal(actual$Pvalue, c(0.02, 0.03, 0.2), tolerance = 1e-12)
          expect_equal(actual$Padj, c(0.04, NA_real_, 0.3), tolerance = 1e-12)
          expect_identical(actual$ProviderExtra, c("retained-a", "retained-c", "strict-boundary"))
        } else {
          expect_equal(actual$Cluster, c(1, 2))
          expect_identical(actual$Representative_Term, c("A", "D"))
          expect_equal(actual$min_pvalue, c(0.9, 1e-5), tolerance = 1e-12)
          expect_equal(actual$provider_metric, c(NA_real_, pi), tolerance = 1e-12)
        }
      }
    }
    expect_identical(u_rrdfs[["../treated:one"]], expected$rr)
    expect_identical(u_clusdfs[["../cluster:one"]], expected$clus)
  })
  # MockShinySession registers each generated directory for session-end cleanup.
  expect_length(downloads$paths, 6L)
  expect_false(any(file.exists(downloads$paths)))
  expect_false(any(dir.exists(dirname(downloads$paths))))
})

test_that("registered dataset callbacks distinguish missing data from empty tables", {
  state <- ws_baseline_state()
  state$u_rrdfs$empty <- ws_baseline_results()$treated[FALSE, , drop = FALSE]
  state$u_clusdfs$empty <- ws_baseline_cluster_tables()$summary[FALSE, , drop = FALSE]
  missing <- withr::local_tempfile(pattern = "B5-owned-session-", fileext = ".csv")
  downloads <- new.env(parent = emptyenv())
  downloads$paths <- character()
  args <- state[c("u_degnames", "u_degdfs", "u_rrnames", "u_rrdfs",
                  "u_clusnames", "u_clusdfs", "u_cluslists")]
  shiny::testServer(richStudio::saveTabServer, args = args, {
    session$setInputs(export_rr_select = "missing", export_rr_format = "csv",
                      export_clus_select = "missing", export_clus_format = "csv")
    for (kind in c("rr", "clus")) {
      # Inspect the registration made by the real Shiny downloadHandler. Calling
      # getOutput here would add MockShinySession's separate no-file error.
      registered <- session$rootScope()$.__enclos_env__$private$file_generators$get(
        session$rootScope()$ns(session$ns(paste0("export_", kind))))
      expect_true(is.function(registered$content))
      registered$content(missing)
      expect_false(file.exists(missing))
    }
    session$setInputs(export_rr_select = "empty", export_clus_select = "empty")
    for (kind in c("rr", "clus")) {
      path <- output[[paste0("export_", kind)]]
      downloads$paths <- c(downloads$paths, path)
      actual <- read.csv(path, check.names = FALSE)
      expect_identical(basename(path), "empty.csv")
      expect_identical(nrow(actual), 0L)
      table <- if (kind == "rr") u_rrdfs$empty else u_clusdfs$empty
      expect_identical(names(actual), names(table))
    }
    expect_identical(nrow(u_rrdfs$empty), 0L)
    expect_identical(nrow(u_clusdfs$empty), 0L)
  })
  expect_false(any(dir.exists(dirname(downloads$paths))))
})

test_that("registered ZIP download includes each source group and omits missing datasets", {
  state <- ws_baseline_state(populated = TRUE)
  payload <- ws_baseline_session()
  for (kind in c("deg", "rr", "clus")) {
    state[[paste0("u_", kind, "names")]]$labels <- c(
      payload[[paste0(kind, "names")]], "empty", "missing")
    table <- payload[[paste0(kind, "dfs")]][[1L]]
    state[[paste0("u_", kind, "dfs")]]$empty <- table[FALSE, , drop = FALSE]
  }
  downloads <- new.env(parent = emptyenv())
  args <- state[c("u_degnames", "u_degdfs", "u_rrnames", "u_rrdfs",
                  "u_clusnames", "u_clusdfs", "u_cluslists")]
  cwd <- getwd()
  temporary_exports <- list.files(tempdir(), pattern = "^richstudio_export_", full.names = TRUE)
  shiny::testServer(richStudio::saveTabServer, args = args, {
    path <- output$export_all
    downloads$path <- path
    expect_match(basename(path), "^richstudio_export_[0-9]{8}_[0-9]{6}_[a-z0-9]{8}\\.zip$")
    expect_identical(getwd(), cwd)
    expect_identical(list.files(tempdir(), pattern = "^richstudio_export_", full.names = TRUE),
                     temporary_exports)
    members <- zip::zip_list(path)$filename
    files <- members[!endsWith(members, "/")]
    expect_setequal(files, paste0("richstudio_export/", c(
      "deg_sets/query.csv", "deg_sets/empty.csv", "enrichment_results/untreated.csv",
      "enrichment_results/treated.csv", "enrichment_results/empty.csv",
      "clustering_results/fixture.csv", "clustering_results/empty.csv")))
    read_member <- function(member) {
      connection <- unz(path, paste0("richstudio_export/", member), open = "r")
      on.exit(close(connection), add = TRUE)
      read.csv(connection, check.names = FALSE)
    }
    expect_equal(read_member("deg_sets/query.csv"), payload$degdfs$query)
    untreated <- read_member("enrichment_results/untreated.csv")
    treated <- read_member("enrichment_results/treated.csv")
    expect_equal(untreated, payload$rrdfs$untreated, tolerance = 1e-12)
    expect_equal(treated, payload$rrdfs$treated, tolerance = 1e-12)
    expect_equal(untreated$Pvalue, c(1e-8, 1e-7, 1e-6, 0.05), tolerance = 1e-12)
    expect_equal(treated$Padj, c(0.04, NA_real_, 0.3), tolerance = 1e-12)
    expect_equal(read_member("clustering_results/fixture.csv"), payload$clusdfs$fixture,
                 tolerance = 1e-12)
    for (group in c("deg_sets", "enrichment_results", "clustering_results")) {
      empty <- read_member(paste0(group, "/empty.csv"))
      expect_identical(nrow(empty), 0L)
    }
    expect_identical(u_rrdfs$treated, payload$rrdfs$treated)
    expect_identical(u_clusdfs$fixture, payload$clusdfs$fixture)
  })
  expect_false(dir.exists(dirname(downloads$path)))
  expect_identical(getwd(), cwd)
})

test_that("registered ZIP download supports a session with no source groups", {
  state <- ws_baseline_state()
  downloads <- new.env(parent = emptyenv())
  args <- state[c("u_degnames", "u_degdfs", "u_rrnames", "u_rrdfs",
                  "u_clusnames", "u_clusdfs", "u_cluslists")]
  cwd <- getwd()
  temporary_exports <- list.files(tempdir(), pattern = "^richstudio_export_", full.names = TRUE)
  shiny::testServer(richStudio::saveTabServer, args = args, {
    path <- output$export_all
    downloads$path <- path
    expect_true(file.exists(path))
    expect_identical(zip::zip_list(path)$filename, "richstudio_export/")
    expect_identical(getwd(), cwd)
    expect_identical(list.files(tempdir(), pattern = "^richstudio_export_", full.names = TRUE),
                     temporary_exports)
    expect_identical(output$deg_summary, "No DEG sets loaded")
    expect_identical(output$rr_summary, "No enrichment results")
    expect_identical(output$clus_summary, "No clustering results")
  })
  expect_false(dir.exists(dirname(downloads$path)))
})
