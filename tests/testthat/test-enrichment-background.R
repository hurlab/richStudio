# SPEC-WS-005: verified explicit enrichment background.
# Oracle: independent base-R phyper upper tail, computed here from the committed
# membership fixture (tests/fixtures/workspace/universe-oracle.tsv), never from richR.

eb_fixture <- function() {
  path <- testthat::test_path("..", "fixtures", "workspace", "universe-oracle.tsv")
  fx <- utils::read.delim(path, stringsAsFactors = FALSE, na.strings = character())
  members <- fx[fx$role == "member", ]
  list(
    terms = split(members$gene, factor(members$term, levels = unique(members$term))),
    long = data.frame(GeneID = members$gene, Term = members$term, stringsAsFactors = FALSE),
    query = fx$gene[fx$role == "query"],
    query_extra = fx$gene[fx$role == "query_extra"],
    universe = fx$gene[fx$role == "universe"]
  )
}

eb_annot <- function(anntype, df) {
  methods::new(methods::getClassDef("Annot", where = asNamespace("richR")),
               species = "custom", anntype = anntype, keytype = "SYMBOL", annot = df)
}

# Route-shaped annotation objects, as the probe verified them.
eb_routes <- function(fx) {
  go_ids <- stats::setNames(paste0("GO:TEST", 1:5), names(fx$terms))
  kegg_ids <- stats::setNames(c("00010", "00020", "00030", "00040", "00051"), names(fx$terms))
  long <- fx$long
  list(
    generic = list(anntype = "Reactome", label = identity,
                   df = data.frame(GeneID = long$GeneID, Annot = paste0("R-HSA-", long$Term)),
                   relabel = function(x) sub("^R-HSA-", "", x)),
    GO = list(anntype = "GO", df = data.frame(GeneID = long$GeneID, GOALL = go_ids[long$Term],
                EVIDENCEALL = "IEA", ONTOLOGYALL = "BP", Annot = paste("GO", long$Term)),
              relabel = function(x) names(go_ids)[match(x, go_ids)]),
    KEGG = list(anntype = "KEGG", df = data.frame(GeneID = long$GeneID, PATH = kegg_ids[long$Term],
                Annot = paste("kegg", long$Term)),
                relabel = function(x) names(kegg_ids)[match(x, kegg_ids)])
  )
}

# Permissive reporting options so every tested term is reported.
eb_open <- list(pvalue = 1, minSize = 1, minGSSize = 1, maxSize = 500, maxGSSize = 500,
                keepRich = TRUE, padj.method = "BH")

eb_call <- function(route, x, universe = NULL) {
  args <- c(list(x = x, universe = universe), eb_open)
  suppressWarnings(suppressMessages(switch(route$anntype,
    GO = do.call(richR::richGO, c(args, list(godata = eb_annot("GO", route$df), ontology = "BP"))),
    KEGG = do.call(richR::richKEGG, c(args, list(kodata = eb_annot("KEGG", route$df)))),
    do.call(richR::enrich, c(args, list(object = eb_annot("Reactome", route$df)))))))
}

eb_compare <- function(result, route, oracle) {
  r <- result@result
  r$term <- route$relabel(r$Annot)
  merged <- merge(oracle, r[, c("term", "Annotated", "Significant", "Pvalue", "Padj")], by = "term")
  expect_setequal(r$term, oracle$term)
  expect_identical(nrow(merged), nrow(oracle))
  expect_equal(merged$Annotated, merged$K)
  expect_equal(merged$Significant, merged$k)
  expect_equal(merged$Pvalue, merged$p, tolerance = 1e-12)
  expect_equal(merged$Padj, merged$padj, tolerance = 1e-12)
}

test_that("the oracle reproduces a hand-computed hypergeometric tail", {
  fx <- eb_fixture()
  oracle <- richStudio:::enrichment_background_oracle(fx$terms, fx$query, unlist(fx$terms))
  t1 <- oracle[oracle$term == "T1", ]
  expect_identical(c(t1$N, t1$K, t1$n, t1$k), c(20L, 5L, 4L, 3L))
  hand <- (choose(5, 3) * choose(15, 1) + choose(5, 4)) / choose(20, 4)
  expect_equal(t1$p, hand, tolerance = 1e-12)
  expect_identical(oracle$term, c("T1", "T2", "T3"))
})

test_that("AC-001 REQ-002 default and explicit routes reproduce the oracle on GO, KEGG and Reactome", {
  suppressPackageStartupMessages(library(richR))
  fx <- eb_fixture()
  explicit_query <- c(fx$query, fx$query_extra)
  for (name in names(eb_routes(fx))) {
    route <- eb_routes(fx)[[name]]
    default <- richStudio:::enrichment_background_oracle(fx$terms, fx$query, unlist(fx$terms))
    eb_compare(eb_call(route, fx$query), route, default)
    explicit <- richStudio:::enrichment_background_oracle(fx$terms, explicit_query, fx$universe)
    expect_identical(explicit$N[[1]], 13L)
    eb_compare(eb_call(route, explicit_query, fx$universe), route, explicit)
  }
})

test_that("REQ-002 the denominator changes with the universe and the family is every tested term", {
  suppressPackageStartupMessages(library(richR))
  fx <- eb_fixture()
  route <- eb_routes(fx)$generic
  default <- eb_call(route, fx$query)
  explicit <- eb_call(route, c(fx$query, fx$query_extra), fx$universe)
  expect_identical(richR::enrichmentInfo(default)$testing$effective_N, 20L)
  expect_identical(richR::enrichmentInfo(explicit)$testing$effective_N, 13L)
  p_default <- default@result$Pvalue[default@result$Annot == "R-HSA-T1"]
  p_explicit <- explicit@result$Pvalue[explicit@result$Annot == "R-HSA-T1"]
  expect_false(isTRUE(all.equal(p_default, p_explicit)))
})

# ---- review of a (background, query) pair -------------------------------------

test_that("AC-002 REQ-003 duplicates, blanks and unmapped ids are counted and an outside query is blocked", {
  fx <- eb_fixture()
  annotation <- unique(unlist(fx$terms))
  universe <- c(fx$universe, NA, "", "  ")
  review <- richStudio:::enrichment_background_review(universe, c(fx$query, fx$query_extra), annotation)
  expect_identical(review$original_count, 20L)
  expect_identical(review$blank_count, 3L)
  expect_identical(review$duplicate_count, 2L)
  expect_identical(review$unique_count, 15L)
  expect_identical(review$unmapped_count, 2L)
  expect_identical(review$effective_count, 13L)
  expect_identical(review$query_unmapped_count, 1L)
  expect_identical(review$query_excluded_ids, "g15")
  expect_identical(review$query_effective_count, 4L)
  expect_false(review$ok)
  expect_match(review$problems[[1]], "g15", fixed = TRUE)

  ok <- richStudio:::enrichment_background_review(fx$universe, fx$query, annotation)
  expect_true(ok$ok)
  none <- richStudio:::enrichment_background_review(c("x1", "x2"), fx$query, annotation)
  expect_false(none$ok)
  expect_match(none$problems[[1]], "no genes in the selected annotation", ignore.case = TRUE)
})

test_that("a background digest ignores order and duplicates, and text admission is bounded", {
  expect_identical(richStudio:::enrichment_background_digest(c("b", "a", "a", NA)),
                   richStudio:::enrichment_background_digest(c("a", "b")))
  expect_false(identical(richStudio:::enrichment_background_digest("a"),
                         richStudio:::enrichment_background_digest("b")))
  admitted <- richStudio:::enrichment_background_admit_text("g1, g2;g3\ng3")
  expect_true(admitted$ok)
  expect_identical(admitted$ids, c("g1", "g2", "g3", "g3"))
  expect_false(richStudio:::enrichment_background_admit_text("")$ok)
})

# ---- application wrapper -------------------------------------------------------

# Larger hand-computable fixture so the app's default reporting filters
# (pvalue 0.05, minGSSize 10) report rows: 40 genes, three terms of 10.
eb_app_fixture <- function() {
  terms <- list(A = paste0("h", 1:10), B = paste0("h", 11:20), C = paste0("h", 21:30))
  list(terms = terms, annot_genes = paste0("h", 1:40),
       long = data.frame(GeneID = unlist(terms), Term = rep(names(terms), lengths(terms))),
       query = c(paste0("h", 1:6), "h11"))
}

eb_app_builder <- function(fx) {
  function(species, keytype, anntype) {
    eb_annot("Reactome", data.frame(GeneID = fx$long$GeneID, Annot = paste0("R-HSA-", fx$long$Term)))
  }
}

eb_app_inputs <- function(fx, query = fx$query) {
  list(list(name = "set1", df = data.frame(gene = query), gene_header = "gene", ids = query))
}

eb_run <- function(fx, ..., query = fx$query) {
  suppressWarnings(suppressMessages(richStudio:::run_enrichment_jobs(
    eb_app_inputs(fx, query), cutoff = 0.05, species = "custom", anntype = "Reactome",
    keytype = "SYMBOL", ontology = "BP", annotation_builder = eb_app_builder(fx), ...)))
}

test_that("AC-001 the app wrapper reports the oracle probabilities and the default background identity", {
  suppressPackageStartupMessages(library(richR))
  fx <- eb_app_fixture()
  out <- eb_run(fx)[[1]]
  oracle <- richStudio:::enrichment_background_oracle(fx$terms, fx$query, unlist(fx$terms))
  expect_identical(oracle$N[[1]], 30L)
  a <- out$result[out$result$Annot == "R-HSA-A", ]
  expect_equal(a$Pvalue, oracle$p[oracle$term == "A"], tolerance = 1e-12)
  # Padj keeps the full tested family (A and B), not the reported subset.
  expect_equal(a$Padj, oracle$padj[oracle$term == "A"], tolerance = 1e-12)
  expect_false(isTRUE(all.equal(a$Padj, a$Pvalue)))
  bg <- out$background
  expect_identical(bg$mode, "annotation")
  expect_match(bg$source, "Annotation universe")
  expect_identical(bg$mapped_size, 30L)
  expect_identical(bg$annotation$anntype, "Reactome")
  expect_identical(bg$annotation$annotation_genes, NA_integer_)
  expect_false(any(c("background_digest", "submitted_count") %in% bg$unavailable))
})

test_that("AC-001 REQ-001 an explicit background changes N and is recorded without gene lists", {
  suppressPackageStartupMessages(library(richR))
  fx <- eb_app_fixture()
  universe <- c(paste0("h", 1:25), "h1", "ghost", "h3")
  out <- eb_run(fx, background = list(mode = "explicit", ids = universe))[[1]]
  oracle <- richStudio:::enrichment_background_oracle(fx$terms, fx$query, universe)
  expect_identical(oracle$N[[1]], 25L)
  a <- out$result[out$result$Annot == "R-HSA-A", ]
  expect_equal(a$Pvalue, oracle$p[oracle$term == "A"], tolerance = 1e-12)
  expect_equal(a$Padj, oracle$padj[oracle$term == "A"], tolerance = 1e-12)
  bg <- out$background
  expect_identical(bg$mode, "explicit")
  expect_identical(bg$mapped_size, 25L)
  expect_identical(bg$submitted_count, 28L)
  expect_identical(bg$duplicate_count, 2L)
  expect_identical(bg$background_digest, richStudio:::enrichment_background_digest(universe))
  expect_identical(bg$annotation$annotation_genes, 30L)
  expect_false(any(grepl("ghost", unlist(bg), fixed = TRUE)))
  # REQ-005: never labelled as the complete measured gene list.
  expect_match(bg$source, "measured and annotated")
  expect_false(grepl("complete", bg$source, ignore.case = TRUE))
})

test_that("AC-002 REQ-003 an incompatible pair stops the run and names the excluded genes", {
  fx <- eb_app_fixture()
  calls <- 0L
  builder <- eb_app_builder(fx)
  counting <- function(species, keytype, anntype) { calls <<- calls + 1L; builder(species, keytype, anntype) }
  universe <- paste0("h", 2:25)
  err <- expect_error(
    richStudio:::run_enrichment_jobs(
      eb_app_inputs(fx), cutoff = 0.05, species = "custom", anntype = "Reactome", keytype = "SYMBOL",
      ontology = "BP", annotation_builder = counting,
      background = list(mode = "explicit", ids = universe)),
    "Background rejected for 'set1'")
  expect_match(conditionMessage(err), "h1", fixed = TRUE)
  expect_identical(calls, 1L)
})

test_that("REQ-004 AC-003 an unsupported route leaves the control unavailable and default enrichment usable", {
  fx <- eb_app_fixture()
  state <- richStudio:::.enrichment_background_state
  saved <- state$capability
  on.exit(state$capability <- saved, add = TRUE)
  state$capability <- list(available = FALSE, reason = "The installed richR 0.0.1 does not accept an explicit universe in: enrich.")
  expect_error(eb_run(fx, background = list(mode = "explicit", ids = paste0("h", 1:30))),
               "Custom background is unavailable: The installed richR 0.0.1")
  expect_identical(eb_run(fx)[[1]]$background$mode, "annotation")

  fake <- new.env()
  fake$enrich <- function(x, object) NULL
  fake$richGO <- function(x, godata, universe = NULL) NULL
  fake$richKEGG <- function(x, kodata, universe = NULL) NULL
  expect_identical(richStudio:::enrichment_background_missing_routes(fake), "enrich")
})

test_that("the installed richR 0.1.5 passes the capability self-check", {
  cap <- richStudio:::enrichment_background_capability(refresh = TRUE)
  expect_true(cap$available)
  expect_null(cap$reason)
})

test_that("the default route is unchanged: shiny_enrich without a universe equals the bare richR call", {
  suppressPackageStartupMessages(library(richR))
  fx <- eb_app_fixture()
  via_app <- suppressMessages(richStudio:::shiny_enrich(
    data.frame(gene = fx$query), "gene", "custom", "Reactome", "SYMBOL", "BP",
    annotation_builder = eb_app_builder(fx)))
  direct <- suppressMessages(richR::enrich(x = fx$query, object = eb_app_builder(fx)("custom", "SYMBOL", "Reactome")))
  expect_identical(via_app@result, direct@result)
})

# ---- enrichment tab ------------------------------------------------------------

eb_tab_state <- function(fx) {
  state <- ws_baseline_state()
  shiny::isolate({
    df <- data.frame(gene = fx$query)
    state$u_degdfs[["set1"]] <- df
    state$u_degnames$labels <- "set1"
    state$u_big_degdf$df <- richStudio::add_file_degdf(NULL, "set1", df)
  })
  state
}

eb_tab_args <- function(fx, runner) {
  args <- eb_tab_state(fx)
  args <- args[intersect(names(formals(richStudio:::enrichTabServer)), names(args))]
  args$enrichment_runner <- runner
  args$annotation_builder <- eb_app_builder(fx)
  args
}

eb_settle <- function(session, rounds = 20L) {
  for (i in seq_len(rounds)) {
    later::run_now(timeoutSecs = 0.01)
    session$flushReact()
  }
}

test_that("the tab offers the labelled default and gates a custom background behind a passing check", {
  fx <- eb_app_fixture()
  seen <- new.env()
  seen$calls <- list()
  runner <- function(...) {
    seen$calls[[length(seen$calls) + 1L]] <- list(...)
    list()
  }
  shiny::testServer(richStudio:::enrichTabServer, args = eb_tab_args(fx, runner), {
    session$flushReact()
    ui <- paste(as.character(output$background_ui$html), collapse = "")
    expect_match(ui, "Annotation universe", fixed = TRUE)
    expect_match(ui, "measured and annotated", fixed = TRUE)
    session$setInputs(species_select = "human", anntype_select = "Reactome", keytype_select = "SYMBOL",
                      ont_select = "BP", deg_filter_cutoff = 0.05, degs_to_enrich = "set1",
                      background_mode = "explicit", background_text = paste0("h", 2:25, collapse = " "))
    # Not yet checked: Run is blocked before the runner.
    session$setInputs(enrich_deg = 1L)
    eb_settle(session)
    expect_length(seen$calls, 0L)
    expect_true(any(grepl("Check the background", review_messages(), fixed = TRUE)))
    # The check rejects: h1 is annotated but missing from the background.
    session$setInputs(background_check = 1L)
    eb_settle(session)
    expect_match(paste(as.character(output$background_review$html), collapse = ""), "h1", fixed = TRUE)
    session$setInputs(enrich_deg = 2L)
    eb_settle(session)
    expect_length(seen$calls, 0L)
    # A compatible background passes the check and reaches the runner.
    session$setInputs(background_text = paste0("h", 1:25, collapse = " "), background_check = 2L)
    eb_settle(session)
    review_html <- paste(as.character(output$background_review$html), collapse = "")
    expect_match(review_html, "Effective universe", fixed = TRUE)
    session$setInputs(enrich_deg = 3L)
    eb_settle(session)
    expect_length(seen$calls, 1L)
    expect_identical(seen$calls[[1]]$background$mode, "explicit")
    expect_identical(sort(unique(seen$calls[[1]]$background$ids)), sort(paste0("h", 1:25)))
  })
})

test_that("an unavailable capability hides the control and a default run omits the background", {
  fx <- eb_app_fixture()
  state <- richStudio:::.enrichment_background_state
  saved <- state$capability
  on.exit(state$capability <- saved, add = TRUE)
  state$capability <- list(available = FALSE, reason = "The installed richR 0.0.1 does not accept an explicit universe in: enrich.")
  seen <- new.env()
  seen$calls <- list()
  runner <- function(...) { seen$calls[[length(seen$calls) + 1L]] <- list(...); list() }
  shiny::testServer(richStudio:::enrichTabServer, args = eb_tab_args(fx, runner), {
    session$flushReact()
    ui <- paste(as.character(output$background_ui$html), collapse = "")
    expect_match(ui, "0.0.1", fixed = TRUE)
    expect_false(grepl("background_text", ui, fixed = TRUE))
    session$setInputs(species_select = "human", anntype_select = "Reactome", keytype_select = "SYMBOL",
                      ont_select = "BP", deg_filter_cutoff = 0.05, degs_to_enrich = "set1",
                      background_mode = "explicit", background_text = "h1 h2", enrich_deg = 1L)
    eb_settle(session)
    expect_length(seen$calls, 1L)
    expect_null(seen$calls[[1]]$background)
  })
})

test_that("REQ-001 a published result carries its background identity", {
  suppressPackageStartupMessages(library(richR))
  previous <- future::plan()
  withr::defer(future::plan(previous))
  future::plan(future::sequential)
  fx <- eb_app_fixture()
  runner <- function(deg_inputs, cutoff, species, anntype, keytype, ontology, background = NULL) {
    richStudio:::run_enrichment_jobs(deg_inputs, cutoff = cutoff, species = species, anntype = anntype,
      keytype = keytype, ontology = ontology, annotation_builder = eb_app_builder(fx),
      background = background)
  }
  shiny::testServer(richStudio:::enrichTabServer, args = eb_tab_args(fx, runner), {
    session$flushReact()
    session$setInputs(species_select = "human", anntype_select = "Reactome", keytype_select = "SYMBOL",
                      ont_select = "BP", deg_filter_cutoff = 0.05, degs_to_enrich = "set1",
                      background_mode = "explicit", background_text = paste0("h", 1:25, collapse = " "))
    session$setInputs(background_check = 1L)
    eb_settle(session)
    session$setInputs(enrich_deg = 1L)
    eb_settle(session, 60L)
    labels <- shiny::isolate(u_rrnames$labels)
    expect_identical(labels, "set1_enriched")
    carried <- attr(shiny::isolate(u_rrdfs[["set1_enriched"]]), "richstudio_background")
    expect_identical(carried$mode, "explicit")
    expect_identical(carried$mapped_size, 25L)
    expect_identical(carried$background_digest,
                     richStudio:::enrichment_background_digest(paste0("h", 1:25)))
  })
})

# ---- asynchronous check --------------------------------------------------------


test_that("the background check runs in a future and publishes its review", {
  previous <- future::plan()
  withr::defer(future::plan(previous))
  future::plan(future::sequential)
  fx <- eb_app_fixture()
  shiny::testServer(richStudio:::enrichTabServer, args = eb_tab_args(fx, function(...) list()), {
    session$flushReact()
    session$setInputs(species_select = "human", anntype_select = "Reactome", keytype_select = "SYMBOL",
                      ont_select = "BP", deg_filter_cutoff = 0.05, degs_to_enrich = "set1",
                      background_mode = "explicit", background_text = paste0("h", 1:25, collapse = " "))
    session$setInputs(background_check = 1L)
    eb_settle(session)
    expect_false(shiny::isolate(background_pending()))
    check <- shiny::isolate(background_check())
    expect_true(check$ok)
    expect_identical(check$entries[["set1"]]$effective_count, 25L)
  })
})

test_that("a superseded or input-stale background check result is ignored", {
  fx <- eb_app_fixture()
  resolvers <- list()
  testthat::local_mocked_bindings(
    workspace_jobs_future = function(expr, ..., envir = parent.frame()) {
      promises::promise(function(resolve, reject) {
        resolvers[[length(resolvers) + 1L]] <<- list(resolve = resolve, reject = reject)
      })
    }, .package = "richStudio")
  annotation <- unique(fx$long$GeneID)
  bad <- list(richStudio:::enrichment_background_review(paste0("h", 2:25), fx$query, annotation))
  good <- list(richStudio:::enrichment_background_review(paste0("h", 1:25), fx$query, annotation))
  shiny::testServer(richStudio:::enrichTabServer, args = eb_tab_args(fx, function(...) list()), {
    session$flushReact()
    session$setInputs(species_select = "human", anntype_select = "Reactome", keytype_select = "SYMBOL",
                      ont_select = "BP", deg_filter_cutoff = 0.05, degs_to_enrich = "set1",
                      background_mode = "explicit", background_text = paste0("h", 2:25, collapse = " "))
    session$setInputs(background_check = 1L)
    session$setInputs(background_text = paste0("h", 1:25, collapse = " "))
    session$setInputs(background_check = 2L)
    expect_length(resolvers, 2L)
    # The first (superseded) check finishes last-but-one: its result is dropped.
    # While a check runs the button state is pending and nothing is published.
    expect_true(shiny::isolate(background_pending()))
    expect_null(shiny::isolate(background_check()))
    resolvers[[1]]$resolve(bad)
    eb_settle(session)
    expect_null(shiny::isolate(background_check()))
    expect_true(shiny::isolate(background_pending()))
    resolvers[[2]]$resolve(good)
    eb_settle(session)
    expect_false(shiny::isolate(background_pending()))
    expect_true(shiny::isolate(background_check())$ok)
    # Changing the background while a check runs discards that check's result.
    session$setInputs(background_check = 3L)
    session$setInputs(background_text = paste0("h", 1:26, collapse = " "))
    resolvers[[3]]$resolve(good)
    eb_settle(session)
    expect_null(shiny::isolate(background_check()))
    expect_false(shiny::isolate(background_pending()))
  })
})
