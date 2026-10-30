# SPEC-WS-004 intake review: upload admission, truthful query review, the worker
# rule and transactional result import. Fixtures are built here; only the named
# internal seams (review_read_text, review_read_excel, query_gene_ids) are stubbed.

# Copied from test-dependency-integration.R:1-19 (deterministic annotation fixtures).
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

# ---- helpers ---------------------------------------------------------------

ir_policy_message <- "Upload checks unavailable: resource policy missing or invalid"

ir_policy <- function(...) {
  policy <- richStudio:::workspace_resource_policy()
  changes <- list(...)
  for (key in names(changes)) policy$limits[[key]] <- changes[[key]]
  policy
}

ir_write <- function(text, ext) {
  path <- tempfile(fileext = ext)
  writeBin(if (is.raw(text)) text else charToRaw(text), path)
  path
}

ir_write_table <- function(df, ext = ".tsv") {
  path <- tempfile(fileext = ext)
  utils::write.table(df, path, sep = "\t", quote = FALSE, row.names = FALSE)
  path
}

ir_admit <- function(path, name = basename(path), kind = "deg", policy = NULL) {
  richStudio:::review_admit_file(path, name, kind, policy)
}

# Today's reader choice (enrich_tab.R:227-245 at the unchanged source).
ir_legacy_read <- function(path) {
  csv_n <- tryCatch(ncol(utils::read.csv(path)), error = function(e) 0)
  tsv_n <- tryCatch(ncol(utils::read.delim(path)), error = function(e) 0)
  if (tsv_n == 0 || csv_n > tsv_n) utils::read.csv(path) else utils::read.delim(path)
}

# Call-through spies on the two reader seams; counts prove a reader was not reached.
ir_spy_readers <- function(env = parent.frame()) {
  calls <- new.env(parent = emptyenv())
  calls$text <- 0L
  calls$excel <- 0L
  real_text <- richStudio:::review_read_text
  real_excel <- richStudio:::review_read_excel
  testthat::local_mocked_bindings(
    review_read_text = function(...) {
      calls$text <- calls$text + 1L
      real_text(...)
    },
    review_read_excel = function(...) {
      calls$excel <- calls$excel + 1L
      real_excel(...)
    },
    .package = "richStudio", .env = env)
  calls
}

# A comma-separated cell of short identifiers (each at most 6 bytes), exactly `bytes` long.
ir_ids_cell <- function(bytes) {
  cell <- substr(paste(sprintf("G%05d", seq_len(bytes)), collapse = ","), 1L, bytes)
  if (endsWith(cell, ",")) cell <- paste0(substr(cell, 1L, bytes - 1L), "X")
  cell
}

# Annotation where `genes` (padded to richR's default minGSSize of 10) form one
# significant term among 200 filler genes, so the enriched GeneID column reports
# exactly the query genes the worker submitted.
ir_rich_builder <- function(genes) {
  query_term <- c(genes, sprintf("PAD%02d", 1:10))
  annot <- data.frame(GeneID = c(query_term, sprintf("FILL%03d", 1:200)),
                      Term = c(rep("R-HSA-QUERY", length(query_term)), rep("R-HSA-FILL", 200)))
  function(species, keytype, anntype) dependency_annot_object("Reactome", annot)
}

ir_enriched_ids <- function(result) {
  row <- result[result$Term == "R-HSA-QUERY", , drop = FALSE]
  if (!nrow(row)) return(character())
  sort(strsplit(row$GeneID[[1]], ",", fixed = TRUE)[[1]])
}

ir_settle <- function(session, rounds = 20L) {
  for (i in seq_len(rounds)) {
    later::run_now(timeoutSecs = 0.01)
    session$flushReact()
  }
}

ir_deg_state <- function(datasets) {
  state <- ws_baseline_state()
  shiny::isolate({
    meta <- NULL
    for (name in names(datasets)) {
      state$u_degdfs[[name]] <- datasets[[name]]
      meta <- richStudio::add_file_degdf(meta, name, datasets[[name]])
    }
    state$u_degnames$labels <- names(datasets)
    state$u_big_degdf$df <- meta
  })
  state
}

# Runner recorder: stores what the observer submitted, then runs the real worker.
ir_recorder <- function(builder) {
  rec <- new.env(parent = emptyenv())
  rec$calls <- list()
  rec$errors <- list()
  rec$runner <- function(deg_inputs, cutoff, species, anntype, keytype, ontology) {
    rec$calls[[length(rec$calls) + 1L]] <- list(deg_inputs = deg_inputs, cutoff = cutoff,
      species = species, anntype = anntype, keytype = keytype, ontology = ontology)
    tryCatch(richStudio:::run_enrichment_jobs(deg_inputs, cutoff = cutoff, species = species,
      anntype = anntype, keytype = keytype, ontology = ontology, annotation_builder = builder),
      error = function(e) {
        rec$errors[[length(rec$errors) + 1L]] <- conditionMessage(e)
        stop(e)
      })
  }
  rec
}

ir_sequential <- function(env = parent.frame()) {
  previous <- future::plan()
  withr::defer(future::plan(previous), envir = env)
  future::plan(future::sequential)
}

ir_attach_ui_packages <- function(env = parent.frame()) {
  for (package in c("shinyjs", "shinyWidgets")) {
    attached <- paste0("package:", package)
    if (!attached %in% search()) {
      do.call(withr::defer, list(
        substitute(detach(name = NAME, character.only = TRUE), list(NAME = attached)),
        envir = env))
      library(package, character.only = TRUE)
    }
  }
}

ir_owned_session <- function(env = parent.frame()) {
  session <- shiny::MockShinySession$new()
  withr::defer(session$close(), envir = env)
  sent <- new.env(parent = emptyenv())
  sent$ids <- character()
  original <- session$sendInputMessage
  session$sendInputMessage <- function(inputId, message) {
    sent$ids <- c(sent$ids, inputId)
    original(inputId, message)
  }
  list(session = session, sent = sent)
}

ir_rr_snapshot <- function(state) {
  shiny::isolate(list(labels = state$u_rrnames$labels,
                      dfs = shiny::reactiveValuesToList(state$u_rrdfs),
                      meta = state$u_big_rrdf$df))
}

ir_result_servers <- list(
  cluster_upload = richStudio:::cluster_upload_tab_server,
  rr_visualize = richStudio:::rr_vis_tab_server
)

ir_html <- function(x) if (is.list(x)) x$html else as.character(x)

ir_selection_messages <- function(sent) {
  any(endsWith(sent$ids, "rr_table_select") | endsWith(sent$ids, "-select_table"))
}

# ---- case 1: admission before expensive parsing ------------------------------

test_that("case 1 a missing or incomplete resource policy rejects before any reader", {
  calls <- ir_spy_readers()
  path <- ir_write("gene\tp\ng1\t0.1\n", ".tsv")
  missing <- ir_admit(path, "genes.tsv", policy = tempfile(fileext = ".json"))
  expect_false(missing$ok)
  expect_identical(missing$message, ir_policy_message)
  expect_null(missing$df)
  incomplete <- richStudio:::workspace_resource_policy()
  incomplete$limits$rows <- NULL
  removed <- ir_admit(path, "genes.tsv", policy = incomplete)
  expect_false(removed$ok)
  expect_identical(removed$message, ir_policy_message)
  expect_null(removed$df)
  expect_identical(c(calls$text, calls$excel), c(0L, 0L))
})

test_that("case 1 byte and archive bounds reject before any reader", {
  calls <- ir_spy_readers()
  path <- ir_write("gene\tp\ng1\t0.1\n", ".tsv")
  over <- ir_admit(path, "genes.tsv", policy = ir_policy(upload_bytes = 5))
  expect_false(over$ok)
  expect_identical(over$field, "upload_bytes")
  xlsx <- tempfile(fileext = ".xlsx")
  writexl::write_xlsx(data.frame(Term = c("A", "B"), Pvalue = c(0.01, 0.2)), xlsx)
  for (key in c("archive_members", "archive_expanded_bytes", "archive_bytes")) {
    rejected <- ir_admit(xlsx, "result.xlsx", kind = "result",
                         policy = do.call(ir_policy, stats::setNames(list(5), key)))
    expect_false(rejected$ok)
    expect_identical(rejected$field, key)
  }
  expect_identical(c(calls$text, calls$excel), c(0L, 0L))
  admitted <- ir_admit(xlsx, "result.xlsx", kind = "result")
  expect_true(admitted$ok)
  expect_equal(admitted$df, data.frame(Term = c("A", "B"), Pvalue = c(0.01, 0.2)))
  expect_gt(calls$excel, 0L)
  expect_identical(calls$text, 0L)
})

test_that("case 1 column bounds count every record before the parser runs (B12 B13 M20)", {
  calls <- ir_spy_readers()
  header25 <- paste(sprintf("c%d", 1:25), collapse = "\t")
  wide <- ir_write(paste0(header25, "\n", paste(rep(1, 25), collapse = "\t"), "\n"), ".tsv")
  expect_identical(ir_admit(wide)$field, "columns")
  blank_first <- ir_write(paste0("\n", header25, "\nx", strrep("\t1", 24), "\n"), ".tsv")
  expect_identical(ir_admit(blank_first)$field, "columns")
  hash_first <- ir_write(paste0("#", strrep("\t", 30), "\ngene\tp\ng1\t0.1\n"), ".tsv")
  expect_identical(ir_admit(hash_first)$field, "columns")
  hash_second <- ir_write(paste0("a\t#", strrep("\t", 30), "\nx\ty\n"), ".tsv")
  expect_identical(ir_admit(hash_second)$field, "columns")
  quote_spans <- ir_write(paste0("\"\nx\"", strrep("\tc", 25), "\n1", strrep("\t1", 25), "\n"), ".tsv")
  expect_false(ir_admit(quote_spans)$ok)
  expect_identical(calls$text, 0L)
  header24 <- paste(sprintf("c%d", 1:24), collapse = "\t")
  row_named <- ir_write(paste0(header24, "\nr1\t", paste(rep(1, 24), collapse = "\t"),
                               "\nr2\t", paste(rep(2, 24), collapse = "\t"), "\n"), ".tsv")
  admitted <- ir_admit(row_named)
  expect_true(admitted$ok)
  expect_identical(ncol(admitted$df), 24L)
  expect_identical(admitted$df, utils::read.delim(row_named))
})

test_that("case 1 the legacy reader result is kept for well-formed text (B12b S25 S19)", {
  calls <- ir_spy_readers()
  leading_blank <- ir_write("\ngene,pvalue,padj\ng1,0.01,0.02\n", ".csv")
  admitted <- ir_admit(leading_blank)
  expect_true(admitted$ok)
  expect_identical(ncol(admitted$df), 3L)
  expect_identical(admitted$df, utils::read.csv(leading_blank))
  hash_cell <- ir_write("gene\tnote\ng1\tsee #3\n", ".tsv")
  expect_identical(ir_admit(hash_cell)$df, utils::read.delim(hash_cell))
  latin1 <- ir_write(c(charToRaw("gene\tnote\ng1\tcaf"), as.raw(0xe9), charToRaw("\n")), ".tsv")
  latin1_admitted <- ir_admit(latin1)
  expect_true(latin1_admitted$ok)
  expect_identical(latin1_admitted$df, utils::read.delim(latin1))
  crlf <- ir_write("gene,pvalue\r\ng1,0.01\r\ng2,0.2\r\n", ".csv")
  expect_identical(ir_admit(crlf)$df, ir_legacy_read(crlf))
  bom <- ir_write(c(as.raw(c(0xef, 0xbb, 0xbf)), charToRaw("gene\tp\ng1\t0.1\n")), ".tsv")
  expect_identical(ir_admit(bom)$df, ir_legacy_read(bom))
  normal <- ir_write("gene\tpvalue\tpadj\ng1\t0.01\t0.02\ng2\t0.2\t0.3\n", ".tsv")
  header_kept <- ir_admit(normal)$df
  expect_identical(names(header_kept), c("gene", "pvalue", "padj"))
  expect_identical(header_kept$gene, c("g1", "g2"))
  expect_gt(calls$text, 0L)
})

test_that("case 1 malformed structure, row windows, empty files and long lines reject (B14 S26)", {
  calls <- ir_spy_readers()
  for (text in c("gene,\"note\ng1,abc\n", "gene,note\ng1,\"a\nb\"\n")) {
    rejected <- ir_admit(ir_write(text, ".csv"))
    expect_false(rejected$ok)
    expect_identical(rejected$message, "File structure could not be read")
  }
  wide_after_blank <- ir_write(paste0(strrep("\n", 50002L), "a", strrep("\t", 30), "\nx\n"), ".tsv")
  expect_identical(ir_admit(wide_after_blank)$field, "rows")
  valid_after_blank <- ir_write(paste0(strrep("\n", 50001L), "gene\tp\ng1\t0.1\n"), ".tsv")
  expect_identical(ir_admit(valid_after_blank)$field, "rows")
  wide_inside <- ir_write(paste0(strrep("\n", 49000L), "a", strrep("\t", 29), "\nx\n"), ".tsv")
  expect_identical(ir_admit(wide_inside)$field, "columns")
  empty <- ir_admit(ir_write("\n\n\n", ".tsv"))
  expect_false(empty$ok)
  expect_identical(empty$message, "File is empty")
  long <- ir_write(paste0("gene\tnote\n", "g1\t", strrep("A", 262142L), "\n"), ".tsv")
  long_rejected <- ir_admit(long)
  expect_false(long_rejected$ok)
  expect_identical(long_rejected$message, "Line too long")
  rows <- ir_write(paste0("gene\tp\n", paste0("g", seq_len(50001L), "\t0.01\n", collapse = "")), ".tsv")
  expect_identical(ir_admit(rows)$field, "rows")
  expect_identical(calls$text, 0L)
  # A 200,000-byte membership cell of short identifiers passes the line bound and,
  # in a result file, the per-identifier string bound.
  wide_cell <- ir_write(paste0("Term\tPvalue\tGeneID\nA\t0.01\t", ir_ids_cell(200000L), "\n"), ".tsv")
  admitted <- ir_admit(wide_cell, kind = "result")
  expect_true(admitted$ok)
  expect_identical(nchar(admitted$df$GeneID, type = "bytes"), 200000L)
})

test_that("case 1 content sniffing rejects mismatched, compressed and non-data input (B9)", {
  calls <- ir_spy_readers()
  xlsx <- tempfile(fileext = ".xlsx")
  writexl::write_xlsx(data.frame(gene = "g1"), xlsx)
  disguised <- ir_admit(xlsx, "genes.csv")
  expect_false(disguised$ok)
  expect_identical(disguised$message, "File content does not match its extension")
  not_excel <- ir_admit(ir_write("gene\tp\ng1\t0.1\n", ".xlsx"), "genes.xlsx")
  expect_identical(not_excel$message, "File content does not match its extension")
  gz <- tempfile(fileext = ".csv")
  connection <- gzfile(gz, "w")
  writeLines(c("gene,p", "g1,0.1"), connection)
  close(connection)
  compressed <- ir_admit(gz, "genes.csv")
  expect_false(compressed$ok)
  expect_identical(compressed$message, "Compressed files are not accepted")
  expect_identical(c(calls$text, calls$excel), c(0L, 0L))
})

test_that("case 1 a non-atomic column from the reader is rejected before publication", {
  listed <- data.frame(a = 1:2)
  listed$b <- list(1, 2)
  testthat::local_mocked_bindings(review_read_text = function(...) listed, .package = "richStudio")
  rejected <- ir_admit(ir_write("a\tb\n1\t2\n2\t3\n", ".tsv"))
  expect_false(rejected$ok)
  expect_identical(rejected$message, "Unsupported cell types in column b")
})

# ---- case 2: string limit per cell and per membership identifier -------------

test_that("case 2 membership cells are bounded per identifier and other cells per cell", {
  go2like <- data.frame(Term = "T1", Annot = "GO:1", Pvalue = 0.01, Padj = 0.02,
                        GeneID = ir_ids_cell(1163L))
  path <- ir_write_table(go2like)
  admitted <- ir_admit(path, "go2like.tsv", kind = "result")
  expect_true(admitted$ok)
  imported <- richStudio:::review_import(admitted$df, "go2like.tsv", character())
  expect_identical(imported$status, "imported")
  expect_identical(imported$df, admitted$df)

  gene_list <- go2like
  names(gene_list)[5] <- "gene list"
  pending <- richStudio:::review_import(
    ir_admit(ir_write_table(gene_list), "list.tsv", kind = "result")$df, "list.tsv", character())
  expect_identical(pending$status, "pending")
  expect_true(any(grepl("looks like a gene list; map it as GeneID", pending$messages, fixed = TRUE)))

  genes <- go2like
  names(genes)[5] <- "Genes"
  genes_df <- ir_admit(ir_write_table(genes), "genes.tsv", kind = "result")$df
  genes_pending <- richStudio:::review_import(genes_df, "genes.tsv", character())
  expect_identical(genes_pending$status, "pending")
  expect_true(any(grepl(paste("Column Genes looks like a gene list; map it as GeneID, or Import",
    "will refuse the file because the column exceeds the string limit"), genes_pending$messages, fixed = TRUE)))
  mapped <- richStudio:::review_import(genes_df, "genes.tsv", character(),
    mapping = c(Term = "Term", Annot = "Annot", Pvalue = "Pvalue", Padj = "Padj", GeneID = "Genes"))
  expect_identical(mapped$status, "imported")
  expect_identical(mapped$df$GeneID, genes$Genes)
  expect_false("Genes" %in% names(mapped$df))

  note <- data.frame(Term = "T1", Annot = "GO:1", Pvalue = 0.01, Padj = 0.02, GeneID = "g1,g2",
                     ProviderNote = ir_ids_cell(1040L))
  note_df <- ir_admit(ir_write_table(note), "note.tsv", kind = "result")$df
  note_pending <- richStudio:::review_import(note_df, "note.tsv", character())
  expect_identical(note_pending$status, "pending")
  expect_true(any(grepl("Column ProviderNote looks like a gene list", note_pending$messages, fixed = TRUE)))
  refused <- richStudio:::review_import(note_df, "note.tsv", character(),
    mapping = c(Term = "Term", Annot = "Annot", Pvalue = "Pvalue", Padj = "Padj", GeneID = "GeneID"))
  expect_identical(refused$status, "rejected")
  expect_true(any(grepl("Column ProviderNote exceeds the string limit", refused$messages, fixed = TRUE)))

  long_id <- go2like
  long_id$GeneID <- strrep("A", 1031L)
  expect_identical(ir_admit(ir_write_table(long_id), "id.tsv", kind = "result")$field, "string_bytes")
  long_term <- go2like
  long_term$Term <- strrep("T", 1031L)
  expect_identical(ir_admit(ir_write_table(long_term), "term.tsv", kind = "result")$field, "string_bytes")
  pasted <- richStudio:::review_admit_text(paste("TP53", strrep("B", 1031L)), "pasted")
  expect_false(pasted$ok)
  expect_identical(pasted$field, "string_bytes")
})

test_that("case 2 the pending card maps a gene list and refuses an over-limit unmapped column", {
  genes <- data.frame(Term = "T1", Annot = "GO:1", Pvalue = 0.01, Padj = 0.02, Genes = ir_ids_cell(1163L))
  note <- data.frame(Term = "T2", Annot = "GO:2", Pvalue = 0.01, Padj = 0.02, GeneID = "g1,g2",
                     ProviderNote = ir_ids_cell(1040L))
  genes_path <- ir_write_table(genes)
  note_path <- ir_write_table(note)
  state <- ws_baseline_state()
  shiny::testServer(richStudio:::cluster_upload_tab_server,
    args = state[intersect(names(formals(richStudio:::cluster_upload_tab_server)), names(state))], {
      session$flushReact()
      session$setInputs(rr_files = data.frame(name = "genes.tsv", datapath = genes_path))
      expect_match(ir_html(output$intake_pending), "Column Genes looks like a gene list", fixed = TRUE)
      expect_null(u_rrnames$labels)
      session$setInputs(intake_map_GeneID = "Genes", intake_import = 1L)
      expect_identical(u_rrnames$labels, "genes.tsv")
      expect_identical(u_rrdfs[["genes.tsv"]]$GeneID, genes$Genes)
      before <- ir_rr_snapshot(state)
      session$setInputs(rr_files = data.frame(name = "note.tsv", datapath = note_path))
      expect_match(ir_html(output$intake_pending), "Column ProviderNote looks like a gene list", fixed = TRUE)
      session$setInputs(intake_map_GeneID = "GeneID", intake_import = 2L)
      card <- ir_html(output$intake_pending)
      expect_match(card, "note.tsv", fixed = TRUE)
      expect_match(card, "Column ProviderNote exceeds the string limit", fixed = TRUE)
      expect_identical(ir_rr_snapshot(state), before)
    })
})

test_that("case 2 a pasted gene list with an over-limit token is refused", {
  state <- ws_baseline_state()
  shiny::testServer(richStudio:::enrich_tab_server,
    args = state[intersect(names(formals(richStudio:::enrich_tab_server)), names(state))], {
      session$flushReact()
      session$setInputs(deg_text = paste("TP53", strrep("B", 1031L)), degtext_name = "long",
                        upload_degtext = 1L)
      expect_null(u_degnames$labels)
      expect_null(u_degdfs$long)
      expect_true(any(grepl("string_bytes", review_messages(), fixed = TRUE)))
    })
})

# ---- case 3: escaping of labels and column names -------------------------------

test_that("case 3 hostile labels and column names render as text in every review card", {
  ir_sequential()
  hostile <- "<img src=x onerror=alert(1)>.csv"
  deg_text <- ir_write("gene,padj\ng1,0.01\ng2,0.02\n", ".csv")
  deg_xlsx <- tempfile(fileext = ".xlsx")
  writexl::write_xlsx(data.frame(check.names = FALSE, `<b>x</b>` = c("g1", "g2"), Term = c("A", "B")), deg_xlsx)
  escaped <- function(html) {
    expect_false(grepl("<img", html, fixed = TRUE))
    expect_false(grepl("<b>", html, fixed = TRUE))
  }
  state <- ws_baseline_state()
  shiny::testServer(richStudio:::enrich_tab_server,
    args = state[intersect(names(formals(richStudio:::enrich_tab_server)), names(state))], {
      session$flushReact()
      session$setInputs(deg_files = data.frame(name = c(hostile, "names.xlsx"),
                                               datapath = c(deg_text, deg_xlsx)))
      expect_identical(u_degnames$labels, c(hostile, "names.xlsx"))
      session$setInputs(degs_to_enrich = c(hostile, "names.xlsx"), deg_table_select = "names.xlsx",
                        species_select = "human", anntype_select = "GO", keytype_select = "SYMBOL",
                        ont_select = "BP")
      card <- ir_html(output$review_card)
      expect_match(card, "&lt;img src=x onerror=alert(1)&gt;.csv", fixed = TRUE)
      expect_match(card, "&lt;b&gt;x&lt;/b&gt;", fixed = TRUE)
      escaped(card)
      preview <- ir_html(output$review_preview_ui)
      expect_match(preview, "&lt;b&gt;x&lt;/b&gt;", fixed = TRUE)
      escaped(preview)
    })

  result_text <- ir_write("description,pvalue\nA,0.01\nB,0.02\n", ".csv")
  result_xlsx <- tempfile(fileext = ".xlsx")
  writexl::write_xlsx(data.frame(check.names = FALSE, `<b>x</b>` = c(0.01, 0.02),
                                 Description = c("A", "B")), result_xlsx)
  for (server in ir_result_servers) {
    state <- ws_baseline_state()
    shiny::testServer(server, args = state[intersect(names(formals(server)), names(state))], {
      session$flushReact()
      session$setInputs(rr_files = data.frame(name = c(hostile, "names.xlsx"),
                                              datapath = c(result_text, result_xlsx)))
      first <- ir_html(output$intake_pending)
      expect_match(first, "&lt;img src=x onerror=alert(1)&gt;.csv", fixed = TRUE)
      expect_match(first, "names.xlsx", fixed = TRUE)
      escaped(first)
      session$setInputs(intake_map_Term = "description", intake_map_Pvalue = "pvalue", intake_import = 1L)
      expect_true(hostile %in% u_rrnames$labels)
      second <- ir_html(output$intake_pending)
      expect_match(second, "&lt;b&gt;x&lt;/b&gt;", fixed = TRUE)
      escaped(second)
      session$setInputs(intake_map_Term = "Description", intake_map_Pvalue = "<b>x</b>", intake_import = 2L)
      expect_true("names.xlsx" %in% u_rrnames$labels)
      imported <- ir_html(output$imported_results_card)
      expect_match(imported, "&lt;img src=x onerror=alert(1)&gt;.csv", fixed = TRUE)
      expect_match(imported, "Mapped from &lt;b&gt;x&lt;/b&gt;", fixed = TRUE)
      escaped(imported)
    })
  }
})

# ---- case 4: the default rule is the legacy rule (literal vectors) -------------

ir_case4_fixtures <- function() {
  genes <- c("a", "b", "c", "d", "e", "f")
  mouse <- utils::read.delim(system.file("extdata", "deg_mouse1.txt", package = "richStudio"))
  list(
    discordant = list(df = data.frame(gene = genes, Pvalue = c(0.5, 0.6, 0.01, 0.02, 0.03, 0.9),
                                      Padj = c(0.01, 0.02, 0.03, 0.5, 0.6, 0.7)),
                      header = "gene", expected = c("a", "b", "c")),
    edger = list(df = data.frame(gene = genes, PValue = c(0.01, 0.2, 0.03, 0.04, 0.5, 0.6),
                                 FDR = c(0.9, 0.9, 0.9, 0.9, 0.9, 0.9)),
                 header = "gene", expected = c("a", "c", "d")),
    fdr_only = list(df = data.frame(gene = genes, FDR = c(0.001, 0.9, 0.9, 0.9, 0.9, 0.9)),
                    header = "gene", expected = genes),
    limma = list(df = data.frame(gene = genes, P.Value = rep(0.001, 6), adj.P.Val = rep(0.9, 6)),
                 header = "gene", expected = genes),
    # padj < 0.05 genes of inst/extdata/deg_mouse1.txt, computed at the unchanged source.
    deg_mouse1 = list(df = mouse, header = "geneID", expected = c(
      "Wnt10a", "Rxrg", "Myh2", "Cd68", "Kcnj2", "Grin2c", "Lsmem1",
      "Asb2", "Gpr141", "Trim38", "Fam151b", "Ppard", "Ppargc1b", "Stard6",
      "4931408D14Rik", "Sp9", "4921507L20Rik", "1500004A13Rik", "Foxe3",
      "Myom3", "Ogg1", "Vmn1r181", "Olfr539", "Tssk6", "Nxnl1", "Ctu2",
      "Kbtbd3", "E030011O05Rik", "Ccdc22", "Smim9", "Pdzd11"))
  )
}

test_that("case 4 characterization: the no-rule worker submits the legacy literal sets", {
  suppressPackageStartupMessages(library(richR))
  for (name in names(fixtures <- ir_case4_fixtures())) {
    fixture <- fixtures[[name]]
    builder <- ir_rich_builder(as.character(fixture$df[[fixture$header]]))
    result <- suppressMessages(richStudio:::run_enrichment_jobs(
      list(list(name = name, df = fixture$df, gene_header = fixture$header)),
      cutoff = 0.05, species = "custom", anntype = "Reactome", keytype = "SYMBOL",
      ontology = "", annotation_builder = builder))[[1]]$result
    expect_identical(ir_enriched_ids(result), sort(fixture$expected), info = name)
  }
})

test_that("case 4 the default review snapshot equals the legacy literal sets", {
  for (name in names(fixtures <- ir_case4_fixtures())) {
    fixture <- fixtures[[name]]
    snapshot <- richStudio:::review_resolve(fixture$df, gene_header = fixture$header,
                                            cutoff = 0.05, name = name)
    expect_true(snapshot$ok, info = name)
    expect_identical(snapshot$submitted, fixture$expected, info = name)
    expect_identical(snapshot$gene_col, fixture$header, info = name)
  }
  expect_identical(richStudio:::review_resolve(ir_case4_fixtures()$edger$df, gene_header = "gene",
                                               cutoff = 0.05, name = "e")$query_rule$role, "raw")
  expect_identical(richStudio:::review_resolve(ir_case4_fixtures()$limma$df, gene_header = "gene",
                                               cutoff = 0.05, name = "l")$query_rule$role, "none")
})

# ---- case 5: gene column precedence, field messages and counts -----------------

test_that("case 5 gene column precedence and field-specific messages", {
  resolve <- richStudio:::review_resolve
  ids <- data.frame(symbol = c("S1", "S2"), ensembl = c("E1", "E2"), Padj = c(0.01, 0.02),
                    label = c("x", "y"), wide = c(0.01, 1.5))
  expect_identical(resolve(ids, gene_header = "symbol", gene_col = "ensembl", cutoff = 0.05,
                           name = "x")$gene_col, "ensembl")
  exact <- data.frame(gene_symbol = c("X1", "X2"), gene = c("g1", "g2"))
  expect_identical(resolve(exact, gene_header = "gene", cutoff = 0.05, name = "x")$gene_col, "gene")
  prefix <- data.frame(gene_symbol = c("X1", "X2"), Gene_ID = c("g1", "g2"))
  expect_identical(resolve(prefix, gene_header = "gene", cutoff = 0.05, name = "x")$gene_col, "gene_symbol")
  none <- resolve(data.frame(a = "1", b = "2"), gene_header = "gene", cutoff = 0.05, name = "x")
  expect_false(none$ok)
  expect_identical(none$message, "Gene identifier column was not found.")
  rule <- function(column, role = "raw") list(column = column, role = role)
  non_numeric <- resolve(ids, gene_header = "symbol", rule = rule("label"), cutoff = 0.05, name = "x")
  expect_false(non_numeric$ok)
  expect_match(non_numeric$message, "label", fixed = TRUE)
  expect_match(non_numeric$message, "not numeric", fixed = TRUE)
  out_of_range <- resolve(ids, gene_header = "symbol", rule = rule("wide"), cutoff = 0.05, name = "x")
  expect_false(out_of_range$ok)
  expect_match(out_of_range$message, "outside [0, 1]", fixed = TRUE)
  twice <- resolve(ids, gene_header = "symbol", gene_col = "Padj", rule = rule("Padj"),
                   cutoff = 0.05, name = "x")
  expect_false(twice$ok)
  expect_match(twice$message, "must differ", fixed = TRUE)
  zero_cutoff <- resolve(ids, gene_header = "symbol", rule = rule("Padj", "adjusted"), cutoff = 0, name = "x")
  expect_false(zero_cutoff$ok)
  expect_match(zero_cutoff$message, "Cutoff", fixed = TRUE)
  nothing <- resolve(ids, gene_header = "symbol", rule = rule("Padj", "adjusted"), cutoff = 0.001, name = "x")
  expect_false(nothing$ok)
  expect_identical(nothing$message, "No genes remain after the rule for x")
})

test_that("case 5 NA, blank, whitespace, duplicate and case IDs are counted as specified", {
  df <- data.frame(gene = c("A", NA, "", "  ", "A", "a", " D ", "B", "C"),
                   Padj = c(0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, NA, 0.9))
  snapshot <- richStudio:::review_resolve(df, gene_header = "gene", cutoff = 0.05, name = "x")
  expect_true(snapshot$ok)
  expect_identical(snapshot$submitted, c("A", "A", "a", " D "))
  expect_identical(snapshot$counts$kept, 7L)
  expect_identical(snapshot$counts$submitted, 4L)
  expect_identical(snapshot$counts$distinct, 3L)
  expect_identical(snapshot$counts$duplicates, 1L)
  expect_identical(snapshot$counts$excluded,
                   c(p_missing = 1L, p_cutoff = 1L, id_blank = 3L))
  legacy_text <- data.frame(gene = c("g1", "g2"), padj = c("0.01", "0.5"))
  text_rule <- richStudio:::review_resolve(legacy_text, gene_header = "gene", cutoff = 0.05, name = "t")
  expect_identical(text_rule$submitted, "g1")
  expect_identical(text_rule$note, "Column is not numeric; compared as before")
})

# ---- cases 6-10: the enrichment module review, commit and Run -----------------

test_that("case 6 AC-001 REQ-001 recorded worker IDs equal the card and revision IDs", {
  suppressPackageStartupMessages(library(richR))
  ir_sequential()
  fx <- data.frame(symbol = paste0("S", 1:6), ensembl = paste0("E", 1:6),
                   Padj = c(0.01, 0.02, 0.5, 0.6, 0.7, 0.8),
                   Pvalue = c(0.5, 0.6, 0.01, 0.02, 0.03, 0.9))
  builder <- function(species, keytype, anntype) {
    dependency_annot_object("Reactome", dependency_annotation_fixture("Reactome", c(fx$symbol, fx$ensembl)))
  }
  rec <- ir_recorder(builder)
  real_ids <- richStudio:::query_gene_ids
  rec$ids <- list()
  testthat::local_mocked_bindings(query_gene_ids = function(x, header) {
    ids <- real_ids(x, header)
    rec$ids[[length(rec$ids) + 1L]] <- ids
    ids
  }, .package = "richStudio")
  state <- ir_deg_state(list(fx = fx, fx_default = fx))
  args <- state[intersect(names(formals(richStudio:::enrich_tab_server)), names(state))]
  args$enrichment_runner <- rec$runner
  shiny::testServer(richStudio:::enrich_tab_server, args = args, {
    session$flushReact()
    session$setInputs(species_select = "human", anntype_select = "Reactome", keytype_select = "SYMBOL",
                      ont_select = "BP", deg_filter_cutoff = 0.05, deg_table_select = "fx",
                      review_gene_col = "ensembl", review_p_col = "Padj", review_p_role = "adjusted",
                      review_cutoff = 0.05, review_commit = 1L)
    expect_identical(review_revisions[["fx"]]$snapshot$submitted, c("E1", "E2"))
    session$setInputs(degs_to_enrich = "fx", enrich_deg = 1L)
    ir_settle(session)
    expect_length(rec$errors, 0L)
    call <- rec$calls[[1]]
    expect_identical(call$deg_inputs[[1]]$ids, c("E1", "E2"))
    expect_identical(rec$ids[[length(rec$ids)]], c("E1", "E2"))
    expect_identical(review_card_data()[["fx"]]$snapshot$submitted, c("E1", "E2"))
    expect_identical(call$deg_inputs[[1]]$query_rule$cutoff,
                     review_card_data()[["fx"]]$snapshot$query_rule$cutoff)
    card <- ir_html(output$review_card)
    for (value in c(call$species, call$keytype, call$anntype, call$ontology)) {
      expect_match(card, value, fixed = TRUE)
    }
    session$setInputs(review_p_col = "Pvalue", review_p_role = "raw", review_commit = 2L)
    expect_identical(review_revisions[["fx"]]$snapshot$submitted, c("E3", "E4", "E5"))
    session$setInputs(enrich_deg = 2L)
    ir_settle(session)
    expect_length(rec$errors, 0L)
    expect_identical(rec$calls[[2]]$deg_inputs[[1]]$ids, c("E3", "E4", "E5"))
    expect_identical(rec$ids[[length(rec$ids)]], c("E3", "E4", "E5"))
    expect_identical(rec$calls[[2]]$deg_inputs[[1]]$query_rule$role, "raw")
    # Positive control: the default rule on an uncommitted list keeps the Padj set by symbol.
    session$setInputs(degs_to_enrich = "fx_default", enrich_deg = 3L)
    ir_settle(session)
    expect_length(rec$errors, 0L)
    expect_identical(rec$calls[[3]]$deg_inputs[[1]]$ids, c("S1", "S2"))
    expect_identical(rec$ids[[length(rec$ids)]], c("S1", "S2"))
    expect_identical(review_card_data()[["fx_default"]]$snapshot$submitted, c("S1", "S2"))
  })
})

test_that("case 7 REQ-002 AC-004 preview, commit and cutoff authority agree", {
  suppressPackageStartupMessages(library(richR))
  ir_sequential()
  c7 <- data.frame(gene = paste0("g", 1:6), Padj = c(0.005, 0.005, 0.05, 0.05, 0.15, 0.15))
  rec <- ir_recorder(function(species, keytype, anntype) {
    dependency_annot_object("Reactome", dependency_annotation_fixture("Reactome", c7$gene))
  })
  state <- ir_deg_state(list(c7 = c7, c7_default = c7, c7_live = c7))
  args <- state[intersect(names(formals(richStudio:::enrich_tab_server)), names(state))]
  args$enrichment_runner <- rec$runner
  expected_bytes <- function() {
    file <- tempfile(fileext = ".txt")
    utils::write.table(c7, file, sep = "\t", row.names = FALSE)
    readBin(file, "raw", file.info(file)$size)
  }
  download_bytes <- function(path) readBin(path, "raw", file.info(path)$size)
  shiny::testServer(richStudio:::enrich_tab_server, args = args, {
    session$flushReact()
    session$setInputs(species_select = "human", anntype_select = "Reactome", keytype_select = "SYMBOL",
                      ont_select = "BP", deg_export_type = ".txt", deg_table_select = "c7",
                      review_gene_col = "__default__", review_p_col = "Padj", review_p_role = "adjusted",
                      review_cutoff = 0.1, review_commit = 1L)
    expect_identical(review_revisions[["c7"]]$revision, 1L)
    first_digest <- review_revisions[["c7"]]$snapshot$digest
    session$setInputs(review_cutoff = 0.2)
    expect_identical(review_preview()$counts$submitted, 6L)
    session$setInputs(review_p_role = "raw")
    session$setInputs(review_p_col = "__none__")
    expect_identical(review_revisions[["c7"]]$revision, 1L)
    expect_identical(review_revisions[["c7"]]$snapshot$digest, first_digest)
    expect_identical(u_degdfs$c7, c7)
    expect_identical(download_bytes(output$download_deg), expected_bytes())
    session$setInputs(review_p_col = "Padj", review_p_role = "adjusted", review_cutoff = 0.01,
                      review_commit = 2L)
    expect_identical(review_revisions[["c7"]]$revision, 2L)
    expect_false(identical(review_revisions[["c7"]]$snapshot$digest, first_digest))
    session$setInputs(review_cutoff = 0.1, deg_filter_cutoff = 0.2)
    expect_identical(review_preview()$counts$submitted, 4L)
    session$setInputs(degs_to_enrich = "c7", enrich_deg = 1L)
    ir_settle(session)
    expect_length(rec$errors, 0L)
    expect_identical(rec$calls[[1]]$deg_inputs[[1]]$ids, c("g1", "g2"))
    expect_identical(rec$calls[[1]]$deg_inputs[[1]]$query_rule$cutoff, 0.01)
    expect_match(ir_html(output$review_card), "Committed revision 2", fixed = TRUE)
    # Default rule: preview, commit and worker share review_cutoff (0.1), not 0.2.
    session$setInputs(deg_table_select = "c7_default", review_p_col = "__default__",
                      review_cutoff = 0.1, deg_filter_cutoff = 0.2)
    preview_count <- review_preview()$counts$submitted
    session$setInputs(review_commit = 3L)
    committed_count <- review_revisions[["c7_default"]]$snapshot$counts$submitted
    session$setInputs(degs_to_enrich = "c7_default", enrich_deg = 2L)
    ir_settle(session)
    expect_length(rec$errors, 0L)
    expect_identical(c(preview_count, committed_count, length(rec$calls[[2]]$deg_inputs[[1]]$ids)),
                     c(4L, 4L, 4L))
    # Uncommitted: the card counts with the live default cutoff that Run submits.
    session$setInputs(degs_to_enrich = "c7_live")
    expect_identical(review_card_data()[["c7_live"]]$snapshot$counts$submitted, 6L)
    expect_match(ir_html(output$review_card), "Default rule (not customized)", fixed = TRUE)
    session$setInputs(enrich_deg = 3L)
    ir_settle(session)
    expect_length(rec$errors, 0L)
    expect_identical(rec$calls[[3]]$deg_inputs[[1]]$ids, paste0("g", 1:6))
    expect_identical(rec$calls[[3]]$deg_inputs[[1]]$query_rule$cutoff, 0.2)
    session$setInputs(deg_table_select = "c7")
    expect_identical(u_degdfs$c7, c7)
    expect_identical(download_bytes(output$download_deg), expected_bytes())
  })
})

test_that("case 8 a committed list that changed blocks Run; rename moves and removal drops it", {
  ir_sequential()
  c8 <- data.frame(gene = c("g1", "g2"), Padj = c(0.01, 0.02))
  calls <- new.env(parent = emptyenv())
  calls$n <- 0L
  state <- ir_deg_state(list(c8 = c8))
  args <- state[intersect(names(formals(richStudio:::enrich_tab_server)), names(state))]
  args$enrichment_runner <- function(...) {
    calls$n <- calls$n + 1L
    list()
  }
  shiny::testServer(richStudio:::enrich_tab_server, args = args, {
    session$flushReact()
    session$setInputs(deg_table_select = "c8", review_gene_col = "__default__",
                      review_p_col = "__default__", review_cutoff = 0.05, review_commit = 1L)
    expect_identical(review_revisions[["c8"]]$revision, 1L)
    u_degdfs$c8 <- data.frame(gene = c("g1", "g3"), Padj = c(0.01, 0.02))
    session$setInputs(degs_to_enrich = "c8", enrich_deg = 1L)
    ir_settle(session, 3L)
    expect_identical(calls$n, 0L)
    expect_true("Input changed since commit for c8; review again" %in% review_messages())
    session$setInputs(deg_list_table_cell_edit = list(row = 1L, col = 1L, value = "renamed"))
    expect_null(review_revisions[["c8"]])
    expect_identical(review_revisions[["renamed"]]$revision, 1L)
    session$setInputs(deg_list_table_rows_selected = 1L, remove_deg = 1L)
    expect_null(review_revisions[["renamed"]])
  })
})

test_that("case 9 S11 zero genes at Run stop with the field message and keep result stores", {
  ir_sequential()
  c9 <- data.frame(gene = c("g1", "g2"), Padj = c(0.9, 0.8))
  calls <- new.env(parent = emptyenv())
  calls$n <- 0L
  state <- ir_deg_state(list(c9 = c9))
  shiny::isolate({
    state$u_rrnames$labels <- "old_enriched"
    state$u_rrdfs$old_enriched <- data.frame(Term = "old", GeneID = "g1,g2")
    state$u_big_rrdf$df <- richStudio::add_file_rrdf(NULL, "old", file = FALSE)
  })
  before <- ir_rr_snapshot(state)
  args <- state[intersect(names(formals(richStudio:::enrich_tab_server)), names(state))]
  args$enrichment_runner <- function(...) {
    calls$n <- calls$n + 1L
    list()
  }
  shiny::testServer(richStudio:::enrich_tab_server, args = args, {
    session$flushReact()
    session$setInputs(rr_table_select = "old_enriched", degs_to_enrich = "c9", enrich_deg = 1L)
    ir_settle(session, 3L)
    expect_identical(calls$n, 0L)
    expect_true("No genes remain after the rule for c9" %in% review_messages())
    expect_identical(input$rr_table_select, "old_enriched")
    expect_identical(ir_rr_snapshot(state), before)
  })
})

test_that("case 10 REQ-005 unmeasured mapping counts are marked unavailable without numbers", {
  df <- data.frame(gene = c("g1", "g2"), Padj = c(0.01, 0.02))
  state <- ir_deg_state(list(c10 = df))
  shiny::testServer(richStudio:::enrich_tab_server,
    args = state[intersect(names(formals(richStudio:::enrich_tab_server)), names(state))], {
      session$flushReact()
      session$setInputs(degs_to_enrich = "c10", deg_filter_cutoff = 0.05)
      card <- ir_html(output$review_card)
      expect_match(card, "Mapped / unmapped: Not available (not measured)", fixed = TRUE)
      expect_false(grepl("Not available \\(not measured\\)[^<]*[0-9]", card))
    })
  results <- data.frame(Term = c("A", "B"), Annot = c("X", "Y"), Padj = c(0.01, 0.2))
  path <- ir_write_table(results)
  for (server in ir_result_servers) {
    state <- ws_baseline_state()
    shiny::testServer(server, args = state[intersect(names(formals(server)), names(state))], {
      session$flushReact()
      session$setInputs(rr_files = data.frame(name = "padj-only.tsv", datapath = path))
      card <- ir_html(output$imported_results_card)
      expect_match(card, paste("Raw p-values: not provided. Hierarchical clustering requires",
                               "raw p-values (column Pvalue)."), fixed = TRUE)
      expect_match(card, paste("Gene membership: not provided. Clustering needs gene",
                               "membership (column GeneID)."), fixed = TRUE)
      expect_false(grepl("Not available \\(not measured\\)[^<]*[0-9]", card))
    })
  }
})

# ---- case 11: the worker applies the reviewed rule ----------------------------

test_that("case 11 the worker applies query_rule, checks the snapshot and prefers exact headers", {
  suppressPackageStartupMessages(library(richR))
  c7 <- data.frame(gene = paste0("g", 1:6), Padj = c(0.005, 0.005, 0.05, 0.05, 0.15, 0.15))
  builder <- ir_rich_builder(c7$gene)
  run <- function(job, cutoff = 0.05, data_builder = builder) {
    suppressMessages(richStudio:::run_enrichment_jobs(list(job), cutoff = cutoff, species = "custom",
      anntype = "Reactome", keytype = "SYMBOL", ontology = "", annotation_builder = data_builder))[[1]]
  }
  rule <- list(gene_col = "gene", column = "Padj", role = "adjusted", cutoff = 0.01)
  expect_error(run(list(name = "w", df = c7, gene_header = "gene", ids = "g9", query_rule = rule)),
               "Submitted genes differ from the reviewed snapshot for w", fixed = TRUE)
  ruled <- run(list(name = "w", df = c7, gene_header = "gene", ids = c("g1", "g2"),
                    query_rule = rule, revision_digest = "d"), cutoff = 0.2)
  expect_identical(ir_enriched_ids(ruled$result), c("g1", "g2"))
  expect_false(identical(ir_enriched_ids(ruled$result), sort(c7$gene)))
  expect_identical(ruled$n_submitted, 2L)
  expect_identical(ruled$query_rule, rule)
  expect_identical(ruled$revision_digest, "d")
  all_rows <- run(list(name = "w", df = c7, gene_header = "gene", ids = c7$gene,
                       query_rule = list(gene_col = "gene", column = NA_character_, role = "none",
                                         cutoff = 0.05)))
  expect_identical(ir_enriched_ids(all_rows$result), sort(c7$gene))
  prefixed <- data.frame(gene_symbol = c("X1", "X2"), gene = c("g1", "g2"))
  exact <- run(list(name = "p", df = prefixed, gene_header = "gene"))
  expect_identical(ir_enriched_ids(exact$result), c("g1", "g2"))
  expect_null(exact$query_rule)
  regex <- data.frame(check.names = FALSE, `Gene (ID)` = c("g1", "g2"), Padj = c(0.01, 0.01))
  found <- run(list(name = "r", df = regex, gene_header = "Gene (ID)"))
  expect_identical(ir_enriched_ids(found$result), c("g1", "g2"))
})

# ---- case 12: pasted gene lists ----------------------------------------------

test_that("case 12 pasted lists split on whitespace, commas and semicolons only", {
  state <- ws_baseline_state()
  shiny::testServer(richStudio:::enrich_tab_server,
    args = state[intersect(names(formals(richStudio:::enrich_tab_server)), names(state))], {
      session$flushReact()
      session$setInputs(deg_text = "HLA-A ENSG00000141510.18, TP53;BRCA1", degtext_name = "p1",
                        upload_degtext = 1L)
      expect_identical(u_degdfs$p1, data.frame(GeneID = c("HLA-A", "ENSG00000141510.18", "TP53", "BRCA1")))
      session$setInputs(deg_text = "TP53/BRCA1", degtext_name = "p2", upload_degtext = 2L)
      expect_identical(u_degdfs$p2, data.frame(GeneID = "TP53/BRCA1"))
      session$setInputs(deg_text = "g1, g2;g3\ng4", degtext_name = "p3", upload_degtext = 3L)
      expect_identical(u_degdfs$p3, data.frame(GeneID = c("g1", "g2", "g3", "g4")))
      session$setInputs(deg_text = "other", degtext_name = "p1", upload_degtext = 4L)
      expect_identical(u_degnames$labels, c("p1", "p2", "p3"))
      expect_identical(u_degdfs$p1, data.frame(GeneID = c("HLA-A", "ENSG00000141510.18", "TP53", "BRCA1")))
      expect_true("A gene list named p1 already exists" %in% review_messages())
    })
  ir_attach_ui_packages()
  html <- as.character(richStudio:::enrich_tab_ui("enrich", "enrich_tab"))
  expect_match(html, "Separate genes with spaces, new lines, commas or semicolons", fixed = TRUE)
  expect_false(grepl("any non-alphanumeric character", html, fixed = TRUE))
  for (text in c("Preview — not committed", "Commit input revision",
                 "Default cutoff (used for gene lists without a committed revision)")) {
    expect_match(html, text, fixed = TRUE)
  }
})

# ---- case 13: result imports through both uploaders ---------------------------

ir_import_base <- function() {
  data.frame(Term = c("A", "B"), Annot = c("X1", "X2"), Pvalue = c(0.01, 0.02),
             Padj = c(0.03, 0.04), GeneID = c("g1,g2", "g3"))
}

test_that("case 13 validation lists every failure and never synthesizes p-values", {
  import <- richStudio:::review_import
  base <- ir_import_base()
  several <- base
  several$Pvalue <- c(1.5, 0.02)
  several$Term <- c("A", "")
  bad <- import(several, "bad.tsv", character())
  expect_identical(bad$status, "rejected")
  expect_true(any(grepl("Column Pvalue has values outside [0, 1]", bad$messages, fixed = TRUE)))
  expect_true(any(grepl("Term is blank", bad$messages, fixed = TRUE)))
  expect_true(any(grepl("already exists", import(base, "dup", "dup")$messages, fixed = TRUE)))
  duplicated_annot <- base
  duplicated_annot$Annot <- c("X1", "X1")
  expect_true(any(grepl("Duplicate Annot", import(duplicated_annot, "d", character())$messages, fixed = TRUE)))
  blank_member <- base
  blank_member$GeneID <- c("g1", "")
  expect_true(any(grepl("GeneID is blank", import(blank_member, "m", character())$messages, fixed = TRUE)))
  mixed <- base
  mixed$GeneID <- c("g1,g2", "g3;g4")
  expect_true(any(grepl("mixed delimiters", import(mixed, "x", character())$messages, fixed = TRUE)))
  no_term <- base[c("Annot", "Pvalue", "Padj", "GeneID")]
  expect_identical(import(no_term, "n", character())$status, "pending")
  missing_term <- import(no_term, "n", character(), mapping = c(Annot = "Annot", Pvalue = "Pvalue"))
  expect_identical(missing_term$status, "rejected")
  expect_true(any(grepl("Term column is required", missing_term$messages, fixed = TRUE)))
  p_twice <- data.frame(Description = c("A", "B"), p = c(0.01, 0.02))
  twice <- import(p_twice, "t", character(), mapping = c(Term = "Description", Pvalue = "p", Padj = "p"))
  expect_true(any(grepl("Column p is mapped to more than one role", twice$messages, fixed = TRUE)))
  collision <- data.frame(Description = c("A", "B"), Padj = c(0.01, 0.02), FDR = c(0.03, 0.04))
  expect_identical(import(collision, "c", character())$status, "pending")
  collided <- import(collision, "c", character(), mapping = c(Term = "Description", Padj = "FDR"))
  expect_true(any(grepl("Cannot rename FDR to Padj: column Padj already exists", collided$messages, fixed = TRUE)))
  accepted <- data.frame(Term = c("A", "B"), Pvalue = c(0.01, NA), Padj = c(NA, 0.2), GeneID = c("g1", "g2,g3"))
  expect_identical(import(accepted, "ok", character())$status, "imported")
  candidate <- data.frame(Term = c("A", "B"), Padj = c(0.01, 0.2), FDR = c(0.5, 0.6))
  immediate <- import(candidate, "fdr", character())
  expect_identical(immediate$status, "imported")
  expect_identical(immediate$df, candidate)
  expect_false("Pvalue" %in% names(immediate$df))
})

test_that("case 13 AC-003 both uploaders reject invalid files and keep stores and selections", {
  base <- ir_import_base()
  invalid <- list(
    "probability.tsv" = transform(base, Pvalue = c(1.5, 0.02)),
    "blank-term.tsv" = transform(base, Term = c("A", "")),
    "untreated" = base,
    "dup-annot.tsv" = transform(base, Annot = c("X1", "X1")),
    "blank-member.tsv" = transform(base, GeneID = c("g1", "")),
    "mixed.tsv" = transform(base, GeneID = c("g1,g2", "g3;g4"))
  )
  messages <- c("probability.tsv" = "Column Pvalue has values outside [0, 1]",
                "blank-term.tsv" = "Term is blank", "untreated" = "already exists",
                "dup-annot.tsv" = "Duplicate Annot", "blank-member.tsv" = "GeneID is blank",
                "mixed.tsv" = "mixed delimiters")
  paths <- vapply(invalid, function(df) {
    path <- tempfile(fileext = ".tsv")
    utils::write.table(df, path, sep = "\t", quote = FALSE, row.names = FALSE, na = "")
    path
  }, character(1))
  for (server in ir_result_servers) {
    state <- ws_baseline_state(populated = TRUE)
    before <- ir_rr_snapshot(state)
    owned <- ir_owned_session()
    shiny::testServer(server, args = state[intersect(names(formals(server)), names(state))],
                      session = owned$session, {
      session$flushReact()
      session$setInputs(rr_table_select = "treated", select_table = "treated")
      owned$sent$ids <- character()
      for (label in names(invalid)) {
        session$setInputs(rr_files = data.frame(name = label, datapath = paths[[label]]))
        expect_match(ir_html(output$intake_status), messages[[label]], fixed = TRUE)
      }
      expect_false(ir_selection_messages(owned$sent))
      expect_identical(input$rr_table_select, "treated")
      expect_identical(input$select_table, "treated")
      expect_identical(ir_rr_snapshot(state), before)
    })
  }
})

test_that("case 13 pending remapping failures keep the card open and stores unchanged", {
  no_term <- ir_write_table(ir_import_base()[c("Annot", "Pvalue", "Padj", "GeneID")])
  twice <- ir_write_table(data.frame(Description = c("A", "B"), p = c(0.01, 0.02)))
  collision <- ir_write_table(data.frame(Description = c("A", "B"), Padj = c(0.01, 0.02),
                                         FDR = c(0.03, 0.04)))
  profiler <- ir_write_table(data.frame(ID = c("GO:1", "GO:2"), Description = c("A", "B"),
                                        pvalue = c(0.01, 0.02), p.adjust = c(0.03, 0.04),
                                        geneID = c("g1/g2", "g3")))
  na_rows <- tempfile(fileext = ".tsv")
  utils::write.table(data.frame(Term = c("A", "B"), Pvalue = c(0.01, NA), Padj = c(NA, 0.2),
                                GeneID = c("g1", "g2,g3")), na_rows, sep = "\t", quote = FALSE,
                     row.names = FALSE)
  candidate <- ir_write_table(data.frame(Term = c("A", "B"), Padj = c(0.01, 0.2), FDR = c(0.5, 0.6)))
  for (server in ir_result_servers) {
    state <- ws_baseline_state(populated = TRUE)
    before <- ir_rr_snapshot(state)
    shiny::testServer(server, args = state[intersect(names(formals(server)), names(state))], {
      session$flushReact()
      session$setInputs(rr_files = data.frame(name = "no-term.tsv", datapath = no_term))
      session$setInputs(intake_map_Term = "", intake_map_Annot = "Annot", intake_import = 1L)
      expect_match(ir_html(output$intake_pending), "Term column is required", fixed = TRUE)
      session$setInputs(intake_discard = 1L)
      session$setInputs(rr_files = data.frame(name = "twice.tsv", datapath = twice))
      session$setInputs(intake_map_Term = "Description", intake_map_Annot = "", intake_map_Pvalue = "p",
                        intake_map_Padj = "p", intake_import = 2L)
      expect_match(ir_html(output$intake_pending), "Column p is mapped to more than one role", fixed = TRUE)
      session$setInputs(intake_discard = 2L)
      session$setInputs(rr_files = data.frame(name = "collision.tsv", datapath = collision))
      session$setInputs(intake_map_Term = "Description", intake_map_Pvalue = "", intake_map_Padj = "FDR",
                        intake_import = 3L)
      expect_match(ir_html(output$intake_pending),
                   "Cannot rename FDR to Padj: column Padj already exists", fixed = TRUE)
      session$setInputs(intake_discard = 3L)
      expect_identical(ir_rr_snapshot(state), before)
      session$setInputs(rr_files = data.frame(name = "na-rows.tsv", datapath = na_rows))
      expect_true("na-rows.tsv" %in% u_rrnames$labels)
      session$setInputs(rr_files = data.frame(name = "candidate.tsv", datapath = candidate))
      expect_true("candidate.tsv" %in% u_rrnames$labels)
      session$setInputs(rr_files = data.frame(name = "profiler.tsv", datapath = profiler))
      expect_false("profiler.tsv" %in% u_rrnames$labels)
      session$setInputs(intake_map_Annot = "ID", intake_map_Term = "Description", intake_map_Pvalue = "pvalue",
                        intake_map_Padj = "p.adjust", intake_map_GeneID = "geneID", intake_import = 4L)
      expect_true("profiler.tsv" %in% u_rrnames$labels)
      expect_identical(u_rrdfs[["profiler.tsv"]]$GeneID, c("g1/g2", "g3"))
      quoted <- sub("^<span>(.*)</span>$", "\\1", as.character(shiny::tags$span("'/'")))
      expect_match(ir_html(output$imported_results_card),
                   paste0("Clustering reads comma-separated genes; this file uses ", quoted), fixed = TRUE)
    })
  }
})

# ---- case 14: AC-002 adjusted-only import through confirmation ----------------

test_that("case 14 AC-002 an adjusted-only import invents no raw p-values and explains clustering", {
  fdr_only <- data.frame(Term = c("A", "B"), Annot = c("X1", "X2"), FDR = c(0.01, 0.2),
                         GeneID = c("g1,g2", "g3"))
  fdr_path <- ir_write_table(fdr_only)
  no_genes <- ir_write_table(data.frame(Term = c("A", "B"), Annot = c("X1", "X2"),
                                        Pvalue = c(0.01, 0.02), Padj = c(0.03, 0.04)))
  hierarchical <- "Raw p-values: not provided. Hierarchical clustering requires raw p-values (column Pvalue)."
  state <- ws_baseline_state()
  shiny::testServer(richStudio:::rr_vis_tab_server,
    args = state[intersect(names(formals(richStudio:::rr_vis_tab_server)), names(state))], {
      session$flushReact()
      session$setInputs(rr_files = data.frame(name = "fdr.tsv", datapath = fdr_path))
      expect_null(u_rrnames$labels)
      expect_match(ir_html(output$intake_pending), "fdr.tsv", fixed = TRUE)
      session$setInputs(intake_map_Padj = "FDR", intake_import = 1L)
      published <- u_rrdfs[["fdr.tsv"]]
      expect_false("Pvalue" %in% names(published))
      expect_false("FDR" %in% names(published))
      expect_identical(published$Padj, fdr_only$FDR)
      card <- ir_html(output$imported_results_card)
      expect_match(card, "Mapped from FDR", fixed = TRUE)
      expect_match(card, hierarchical, fixed = TRUE)
      session$setInputs(rr_files = data.frame(name = "no-genes.tsv", datapath = no_genes))
      expect_match(ir_html(output$imported_results_card),
                   "Gene membership: not provided. Clustering needs gene membership (column GeneID).",
                   fixed = TRUE)
    })
  shiny::testServer(richStudio:::cluster_upload_tab_server,
    args = state[intersect(names(formals(richStudio:::cluster_upload_tab_server)), names(state))], {
      session$flushReact()
      card <- ir_html(output$imported_results_card)
      expect_match(card, "fdr.tsv", fixed = TRUE)
      expect_match(card, hierarchical, fixed = TRUE)
    })
})

# ---- cases 15-19: invalid UTF-8 intake, observer containment, missing policy ----

# A text file with a lone Latin-1 byte 0xF6 between `before` and `after`.
ir_latin1_file <- function(before, after) {
  ir_write(c(charToRaw(before), as.raw(0xf6), charToRaw(after)), ".tsv")
}

ir_deg_snapshot <- function(state) {
  shiny::isolate(list(labels = state$u_degnames$labels,
                      dfs = shiny::reactiveValuesToList(state$u_degdfs),
                      meta = state$u_big_degdf$df))
}

test_that("case 15 F1 a Latin-1 Term or GeneID result imports exactly as legacy did", {
  files <- list(
    "latin1-term.tsv" = ir_latin1_file("Term\tPvalue\tGeneID\nSj", "gren syndrome\t0.01\tA,B\nT2\t0.02\tC\n"),
    "latin1-gene.tsv" = ir_latin1_file("Term\tPvalue\tGeneID\nT1\t0.01\tA,Sj", "\nT2\t0.02\tC\n")
  )
  for (label in names(files)) {
    admitted <- ir_admit(files[[label]], label, "result")
    expect_true(admitted$ok)
    result <- tryCatch(richStudio:::review_import(admitted$df, label, character()),
                       error = function(e) list(status = paste("error:", conditionMessage(e))))
    expect_identical(result$status, "imported")
    expect_identical(result$df, ir_legacy_read(files[[label]]))
  }
  for (server in ir_result_servers) {
    state <- ws_baseline_state()
    done <- new.env(parent = emptyenv())
    shiny::testServer(server, args = state[intersect(names(formals(server)), names(state))], {
      session$flushReact()
      for (label in names(files)) {
        before <- length(u_rrnames$labels)
        session$setInputs(rr_files = data.frame(name = label, datapath = files[[label]]))
        expect_false(session$isClosed())
        expect_identical(length(u_rrnames$labels), before + 1L)
        expect_identical(u_rrdfs[[label]], ir_legacy_read(files[[label]]))
        expect_match(ir_html(output$imported_results_card), label, fixed = TRUE)
      }
      done$ok <- TRUE
    })
    expect_true(isTRUE(done$ok))
  }
})

test_that("case 16 F2 a Latin-1 gene ID previews, commits and reaches the worker kept", {
  suppressPackageStartupMessages(library(richR))
  ir_sequential()
  path <- ir_latin1_file("gene\tpadj\nG1\t0.01\ncaf", "\t0.02\nG3\t0.5\n")
  legacy <- ir_legacy_read(path)
  expected <- as.character(legacy$gene[1:2])
  rec <- ir_recorder(ir_rich_builder(expected))
  state <- ws_baseline_state()
  args <- state[intersect(names(formals(richStudio:::enrich_tab_server)), names(state))]
  args$enrichment_runner <- rec$runner
  done <- new.env(parent = emptyenv())
  shiny::testServer(richStudio:::enrich_tab_server, args = args, {
    session$flushReact()
    session$setInputs(species_select = "human", anntype_select = "Reactome", keytype_select = "SYMBOL",
                      ont_select = "BP", deg_filter_cutoff = 0.05,
                      deg_files = data.frame(name = "latin1.tsv", datapath = path))
    expect_identical(u_degdfs[["latin1.tsv"]], legacy)
    session$setInputs(deg_table_select = "latin1.tsv", review_gene_col = "__default__",
                      review_p_col = "__default__", review_cutoff = 0.05, review_commit = 1L)
    expect_false(session$isClosed())
    expect_identical(review_revisions[["latin1.tsv"]]$snapshot$submitted, expected)
    preview <- tryCatch(review_preview(), error = function(e) list(submitted = conditionMessage(e)))
    expect_identical(preview$submitted, expected)
    expect_identical(preview$counts$submitted, 2L)
    session$setInputs(degs_to_enrich = "latin1.tsv", enrich_deg = 1L)
    ir_settle(session)
    expect_false(session$isClosed())
    expect_length(rec$calls, 1L)
    expect_identical(rec$calls[[1]]$deg_inputs[[1]]$ids, expected)
    # The worker's snapshot check accepts the ID; richR's own annotation step then
    # refuses invalid UTF-8 (as at 9fc6b21), reported through the Run onRejected path.
    expect_false(any(grepl("differ from the reviewed snapshot", unlist(rec$errors), fixed = TRUE)))
    done$ok <- TRUE
  })
  expect_true(isTRUE(done$ok))
  expect_identical(richStudio:::query_gene_ids(legacy, "gene"), as.character(legacy$gene))
})

test_that("case 17 review_is_blank equals the trimws rule on valid text and never errors", {
  valid <- c("", " ", "\t", NA, "a", " a ", "\r\n", "x y")
  expect_identical(richStudio:::review_is_blank(valid), is.na(valid) | !nzchar(trimws(valid)))
  invalid <- c(rawToChar(as.raw(c(0x63, 0x61, 0x66, 0xf6))), rawToChar(as.raw(c(0x20, 0xf6, 0x20))), " ")
  expect_no_error(blank <- richStudio:::review_is_blank(invalid))
  expect_identical(blank, c(FALSE, FALSE, TRUE))
  # The other byte-safe string helpers on the same invalid input.
  latin <- invalid[[1]]
  expect_identical(richStudio:::review_lower(c("PADJ", latin)), c("padj", latin))
  expect_identical(richStudio:::review_file_ext(c(paste0(latin, ".XLSX"))), "xlsx")
  expect_identical(vapply(c("a.tsv", "a.b.csv", "noext", "a.", "a.t-v"), richStudio:::review_file_ext,
                          character(1), USE.NAMES = FALSE),
                   tolower(tools::file_ext(c("a.tsv", "a.b.csv", "noext", "a.", "a.t-v"))))
  expect_identical(richStudio:::review_delimiters(paste0(latin, ";x")), ";")
  expect_identical(richStudio:::review_admit_text(paste(latin, "g2,g3"), "pasted")$tokens,
                   c(latin, "g2", "g3"))
})

test_that("case 18 F1 F2 an unexpected error in an intake observer becomes a message", {
  ir_sequential()
  boom <- function(...) stop("injected failure")
  valid <- ir_write_table(ir_import_base())
  no_term <- ir_write_table(ir_import_base()[c("Annot", "Pvalue", "Padj", "GeneID")])
  # Characterization: a failing reader is already contained by admission.
  local({
    testthat::local_mocked_bindings(review_read_text = boom, .package = "richStudio")
    expect_identical(ir_admit(valid, "valid.tsv", "result")$message, "File structure could not be read")
  })
  for (server in ir_result_servers) {
    state <- ws_baseline_state(populated = TRUE)
    before <- ir_rr_snapshot(state)
    owned <- ir_owned_session()
    done <- new.env(parent = emptyenv())
    shiny::testServer(server, args = state[intersect(names(formals(server)), names(state))],
                      session = owned$session, {
      session$flushReact()
      session$setInputs(rr_table_select = "treated", select_table = "treated")
      owned$sent$ids <- character()
      session$setInputs(rr_files = data.frame(name = "no-term.tsv", datapath = no_term))
      local({
        testthat::local_mocked_bindings(review_import = boom, .package = "richStudio")
        session$setInputs(rr_files = data.frame(name = "valid.tsv", datapath = valid))
        expect_false(session$isClosed())
        expect_match(ir_html(output$intake_status),
                     "valid.tsv was not imported: the file could not be processed", fixed = TRUE)
        session$setInputs(intake_map_Term = "Annot", intake_import = 1L)
        expect_false(session$isClosed())
        expect_match(ir_html(output$intake_pending),
                     "no-term.tsv: the file could not be processed", fixed = TRUE)
      })
      expect_false(ir_selection_messages(owned$sent))
      expect_identical(ir_rr_snapshot(state), before)
      done$ok <- TRUE
    })
    expect_true(isTRUE(done$ok))
  }
  calls <- new.env(parent = emptyenv())
  calls$n <- 0L
  state <- ir_deg_state(list(c18 = data.frame(gene = c("g1", "g2"), Padj = c(0.01, 0.02))))
  shiny::isolate({
    state$u_rrnames$labels <- "old_enriched"
    state$u_rrdfs$old_enriched <- data.frame(Term = "old", GeneID = "g1,g2")
  })
  deg_before <- ir_deg_snapshot(state)
  rr_before <- ir_rr_snapshot(state)
  args <- state[intersect(names(formals(richStudio:::enrich_tab_server)), names(state))]
  args$enrichment_runner <- function(...) {
    calls$n <- calls$n + 1L
    list()
  }
  deg_file <- ir_write_table(data.frame(gene = "g9", Padj = 0.01))
  done <- new.env(parent = emptyenv())
  shiny::testServer(richStudio:::enrich_tab_server, args = args, {
    session$flushReact()
    session$setInputs(deg_table_select = "c18", review_gene_col = "__default__",
                      review_p_col = "__default__", review_cutoff = 0.05, rr_table_select = "old_enriched")
    local({
      testthat::local_mocked_bindings(review_admit_file = boom, review_admit_text = boom,
                                      review_resolve = boom, .package = "richStudio")
      session$setInputs(deg_files = data.frame(name = "new.tsv", datapath = deg_file))
      expect_false(session$isClosed())
      expect_true("new.tsv: the file could not be processed" %in% review_messages())
      session$setInputs(deg_text = "g1 g2", degtext_name = "pasted", upload_degtext = 1L)
      expect_false(session$isClosed())
      expect_true("pasted: the pasted text could not be processed" %in% review_messages())
      session$setInputs(review_cutoff = 0.04, review_commit = 1L)
      expect_false(session$isClosed())
      expect_true("c18: the input revision could not be committed" %in% review_messages())
      session$setInputs(degs_to_enrich = "c18", enrich_deg = 1L)
      ir_settle(session, 3L)
      expect_false(session$isClosed())
      expect_true("Run stopped: c18 could not be reviewed" %in% review_messages())
    })
    expect_identical(calls$n, 0L)
    expect_null(review_revisions[["c18"]])
    expect_identical(input$rr_table_select, "old_enriched")
    expect_identical(ir_deg_snapshot(state), deg_before)
    expect_identical(ir_rr_snapshot(state), rr_before)
    done$ok <- TRUE
  })
  expect_true(isTRUE(done$ok))
})

test_that("case 19 F6 a missing resource policy blocks Run and paste", {
  ir_sequential()
  calls <- new.env(parent = emptyenv())
  calls$n <- 0L
  state <- ir_deg_state(list(c19 = data.frame(gene = c("g1", "g2"), Padj = c(0.01, 0.02))))
  shiny::isolate({
    state$u_rrnames$labels <- "old_enriched"
    state$u_rrdfs$old_enriched <- data.frame(Term = "old", GeneID = "g1,g2")
  })
  deg_before <- ir_deg_snapshot(state)
  rr_before <- ir_rr_snapshot(state)
  args <- state[intersect(names(formals(richStudio:::enrich_tab_server)), names(state))]
  args$enrichment_runner <- function(...) {
    calls$n <- calls$n + 1L
    list()
  }
  testthat::local_mocked_bindings(workspace_resource_policy = function(...) stop("policy missing"),
                                  .package = "richStudio")
  done <- new.env(parent = emptyenv())
  shiny::testServer(richStudio:::enrich_tab_server, args = args, {
    session$flushReact()
    session$setInputs(degs_to_enrich = "c19", enrich_deg = 1L)
    ir_settle(session, 3L)
    expect_identical(calls$n, 0L)
    expect_true(ir_policy_message %in% review_messages())
    session$setInputs(deg_text = "g1 g2", degtext_name = "pasted", upload_degtext = 1L)
    expect_true(paste0("pasted: ", ir_policy_message) %in% review_messages())
    expect_false("pasted" %in% u_degnames$labels)
    expect_identical(ir_deg_snapshot(state), deg_before)
    expect_identical(ir_rr_snapshot(state), rr_before)
    done$ok <- TRUE
  })
  expect_true(isTRUE(done$ok))
})
