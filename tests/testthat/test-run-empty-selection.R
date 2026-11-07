# Run with no gene list selected: never silent, always logged; the selection survives new results.

test_that("the Run blocker names what is missing and is NULL when Run can start", {
  lists <- data.frame(name = "set1")
  expect_match(enrich_run_blocker("set1", NULL), "Upload gene lists", fixed = TRUE)
  expect_match(enrich_run_blocker("set1", lists[0, , drop = FALSE]), "Upload gene lists", fixed = TRUE)
  expect_match(enrich_run_blocker(NULL, lists), "Select one or more gene lists", fixed = TRUE)
  expect_match(enrich_run_blocker(character(), lists), "Select one or more gene lists", fixed = TRUE)
  expect_match(enrich_run_blocker("", lists), "Select one or more gene lists", fixed = TRUE)
  expect_null(enrich_run_blocker("set1", lists))
})

test_that("the selection keeps only gene lists that still exist", {
  expect_identical(enrich_keep_selection(c("a", "b"), c("b", "c")), "b")
  expect_identical(enrich_keep_selection(NULL, c("a")), character())
  expect_identical(enrich_keep_selection("a", c("a", "z")), "a")
})

test_that("the Run log line names the outcome and the settings", {
  expect_message(enrich_run_log("blocked", character(), list(species = "yeast", anntype = "GO", keytype = "GENENAME")),
                 "[richStudio] Run: blocked (lists=0 species=yeast annotation=GO keytype=GENENAME)", fixed = TRUE)
  expect_message(enrich_run_log(NULL, "a"), "[richStudio] Run: unknown (lists=1", fixed = TRUE)
})

rs_tab_args <- function() {
  state <- ws_baseline_state()
  shiny::isolate({
    df <- data.frame(gene = c("g1", "g2"))
    state$u_degdfs[["set1"]] <- df
    state$u_degnames$labels <- "set1"
    state$u_big_degdf$df <- richStudio::add_file_degdf(NULL, "set1", df)
  })
  list(args = state[intersect(names(formals(richStudio:::enrich_tab_server)), names(state))], state = state)
}

test_that("in the tab, a Run click with nothing selected says why and is logged, and runs nothing", {
  tab <- rs_tab_args()
  notes <- character()
  ran <- 0L
  tab$args$enrichment_runner <- function(...) { ran <<- ran + 1L; list() }
  testthat::local_mocked_bindings(showNotification = function(ui, ...) { notes <<- c(notes, as.character(ui)); invisible(NULL) })
  shiny::testServer(richStudio:::enrich_tab_server, args = tab$args, {
    session$setInputs(species_select = "human", anntype_select = "GO", keytype_select = "SYMBOL",
                      ont_select = "BP", deg_filter_cutoff = 0.05, degs_to_enrich = character())
    expect_message(session$setInputs(enrich_deg = 1L), "[richStudio] Run: blocked (lists=0", fixed = TRUE)
    expect_true(any(grepl("Run not started. Select one or more gene lists to run.", notes, fixed = TRUE)))
    expect_identical(ran, 0L)
  })
})

test_that("in the tab, a new enrichment result does not reset the gene-list selection", {
  tab <- rs_tab_args()
  sent <- list()
  testthat::local_mocked_bindings(updateSelectInput = function(session, inputId, ...) {
    sent[[length(sent) + 1L]] <<- c(list(id = inputId), list(...)); invisible(NULL)
  })
  shiny::testServer(richStudio:::enrich_tab_server, args = tab$args, {
    session$setInputs(degs_to_enrich = "set1")
    session$flushReact()
    before <- Filter(function(m) identical(m$id, "degs_to_enrich"), sent)
    shiny::isolate(tab$state$u_rrnames$labels <- c(tab$state$u_rrnames$labels, "set1_enriched"))
    session$flushReact()
    after <- Filter(function(m) identical(m$id, "degs_to_enrich"), sent)
    expect_length(after, length(before))
    # A change to the gene lists themselves keeps the lists that still exist.
    shiny::isolate(tab$state$u_degnames$labels <- c("set1", "set2"))
    session$flushReact()
    last <- tail(Filter(function(m) identical(m$id, "degs_to_enrich"), sent), 1L)[[1L]]
    expect_identical(last$selected, "set1")
    expect_identical(as.character(last$choices), c("set1", "set2"))
  })
})
