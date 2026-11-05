# SPEC-WS-008: unified result exploration and linked multi-dataset selection.
# Identity, context compatibility, typed absence and exact-value export are pure
# functions; the module tests drive the real rr_vis_tab_server with testServer.

rx_ns <- function(name) getFromNamespace(name, "richStudio")

rx_ctx <- function(species = "human", keytype = "SYMBOL", annotation_type = "GO",
                   ontology = "BP") {
  list(species = species, keytype = keytype, annotation_type = annotation_type,
       ontology = ontology)
}

rx_df <- function(ids = c("GO:1", "GO:2", "GO:3"), labels = c("alpha", "beta", "gamma"),
                  padj = c(1e-300, 0.02, 0.4), p = c(1e-305, 0.01, 0.3),
                  genes = c("g1,g2,g3", "g2,g4", "g5")) {
  data.frame(Annot = ids, Term = labels, Annotated = 10L, Significant = 3L,
             Pvalue = p, Padj = padj, GeneID = genes, ProviderExtra = paste0("x-", ids),
             stringsAsFactors = FALSE)
}

rx_dataset <- function(df, label, context = rx_ctx(), family = NULL) {
  list(label = label, df = df, context = context, test_family = family,
       id = rx_ns("workspace_result_id")(df))
}

# ---- identity (REQ-002, AC-002) --------------------------------------------------

test_that("AC-002 identical labels with different IDs get different keys and select one row", {
  keys_fn <- rx_ns("workspace_row_keys")
  index <- rx_ns("workspace_selection_index")
  df <- rx_df(ids = c("GO:1", "GO:2", "GO:3"), labels = c("same", "same", "other"))
  keys <- keys_fn(df, "rs-aaa", "GO/BP/human/SYMBOL")
  expect_length(unique(keys), 3L)
  expect_identical(index(keys, keys[2]), 2L)
  expect_identical(index(keys, keys[1]), 1L)
  expect_identical(index(keys, "rk-unknown"), integer())
  # same IDs under another dataset or another namespace are different identities
  expect_false(any(keys %in% keys_fn(df, "rs-bbb", "GO/BP/human/SYMBOL")))
  expect_false(any(keys %in% keys_fn(df, "rs-aaa", "GO/MF/human/SYMBOL")))
})

test_that("row keys survive reordering and filtering of the source rows", {
  keys_fn <- rx_ns("workspace_row_keys")
  df <- rx_df()
  keys <- keys_fn(df, "rs-aaa", "ns")
  flipped <- df[3:1, ]
  expect_identical(keys_fn(flipped, "rs-aaa", "ns"), rev(keys))
  expect_identical(keys_fn(df[2, ], "rs-aaa", "ns"), keys[2])
})

test_that("numeric labels, empty, single and missing-ID tables are handled", {
  keys_fn <- rx_ns("workspace_row_keys")
  numeric <- data.frame(Term = c(1, 2, 10), Pvalue = c(0.1, 0.2, 0.3))
  k <- keys_fn(numeric, "rs-n", "ns")
  expect_length(unique(k), 3L)
  expect_identical(k, keys_fn(numeric, "rs-n", "ns"))
  expect_identical(keys_fn(rx_df()[0, ], "rs-e", "ns"), character())
  expect_length(keys_fn(rx_df()[1, ], "rs-e", "ns"), 1L)
  gap <- rx_df()
  gap$Annot[2] <- NA
  expect_true(is.na(keys_fn(gap, "rs-g", "ns")[2]))
  expect_false(anyNA(keys_fn(gap, "rs-g", "ns")[-2]))
  cols <- rx_ns("workspace_term_columns")
  expect_true(is.na(cols(data.frame(x = 1))$id))
  expect_identical(cols(rx_df())$id, "Annot")
  expect_identical(cols(rx_df())$label, "Term")
  expect_identical(cols(data.frame(Term = "a"))$id, "Term")
})

test_that("repeated source IDs stay distinct without using row numbers for unique rows", {
  keys_fn <- rx_ns("workspace_row_keys")
  df <- rx_df(ids = c("GO:1", "GO:2", "GO:1"))
  k <- keys_fn(df, "rs-d", "ns")
  expect_length(unique(k), 3L)
  expect_identical(k[2], keys_fn(df[2, ], "rs-d", "ns"))
})

test_that("a result id depends on exact values and not on the display name", {
  id <- rx_ns("workspace_result_id")
  df <- rx_df()
  expect_identical(id(df), id(df))
  expect_match(id(df), "^rs-[0-9a-f]{12}$")
  changed <- df
  changed$Padj[2] <- 0.03
  expect_false(identical(id(df), id(changed)))
})

test_that("selection accepts only known project-local keys", {
  state <- rx_ns("workspace_selection_state")()
  set <- rx_ns("workspace_selection_set")
  known <- rx_ns("workspace_row_keys")(rx_df(), "rs-a", "ns")
  shiny::isolate({
    expect_null(state$key())
    expect_true(set(state, known[2], known))
    expect_identical(state$key(), known[2])
    hostile <- "'] ; document.body.remove(); //"
    expect_false(set(state, hostile, known))
    expect_false(set(state, NA_character_, known))
    expect_false(set(state, c(known[1], known[2]), known))
    expect_identical(state$key(), known[2])
    rx_ns("workspace_selection_clear")(state)
    expect_null(state$key())
  })
})

# ---- context (REQ-002, AC-002) -----------------------------------------------------

test_that("context comes from recorded background or run settings and unknown stays NA", {
  ctx <- rx_ns("workspace_result_context")
  df <- rx_df()
  expect_true(all(is.na(unlist(ctx(df)))))
  attr(df, "richstudio_background") <- list(annotation = list(
    species = "human", keytype = "SYMBOL", anntype = "GO", ontology = "BP"))
  got <- ctx(df)
  expect_identical(got$species, "human")
  expect_identical(got$annotation_type, "GO")
  from_run <- ctx(rx_df(), settings = list(species = "mouse", keytype = "?", anntype = "KEGG"))
  expect_identical(from_run$species, "mouse")
  expect_true(is.na(from_run$keytype))
  expect_identical(rx_ns("workspace_context_namespace")(got), "GO/BP/human/SYMBOL")
  expect_match(rx_ns("workspace_context_namespace")(ctx(rx_df())), "unknown")
})

test_that("AC-002 unknown or different species, keytype and annotation are unsupported", {
  compat <- rx_ns("workspace_context_compatible")
  expect_true(compat(rx_ctx(), rx_ctx())$supported)
  for (field in c("species", "keytype", "annotation_type")) {
    other <- rx_ctx()
    other[[field]] <- "different"
    res <- compat(rx_ctx(), other)
    expect_false(res$supported)
    expect_match(res$reason, "differ", ignore.case = TRUE)
    unknown <- rx_ctx()
    unknown[field] <- list(NA_character_)
    res <- compat(rx_ctx(), unknown)
    expect_false(res$supported)
    expect_match(res$reason, "not recorded", ignore.case = TRUE)
    expect_false(compat(unknown, rx_ctx())$supported)
  }
  expect_false(compat(rx_ctx(ontology = "BP"), rx_ctx(ontology = "MF"))$supported)
  expect_false(compat(rx_ctx(ontology = "BP"), rx_ctx(ontology = NA_character_))$supported)
  expect_true(compat(rx_ctx(ontology = NA_character_), rx_ctx(ontology = NA_character_))$supported)
})

# ---- stable dataset cues (REQ-003) ---------------------------------------------------

test_that("REQ-003 dataset cues are a pure function of the stable IDs", {
  cues <- rx_ns("explorer_dataset_cues")
  ids <- c("rs-ccc", "rs-aaa", "rs-bbb")
  a <- cues(ids)
  b <- cues(rev(ids))
  expect_identical(a[order(a$id), ], b[order(b$id), ])
  expect_identical(a$id, sort(ids))
  expect_identical(a$code[1:3], c("D-A", "D-B", "D-C"))
  expect_true(all(nzchar(a$symbol)) && all(grepl("^#", a$color)))
  expect_length(unique(a$symbol), 3L)
  many <- cues(sprintf("rs-%03d", 1:30))
  expect_length(unique(many$code), 30L)
  expect_identical(cues(character())$id, character())
  # relabelling does not exist as an input: the same IDs always give the same cues
  expect_identical(cues(ids), cues(ids))
})

# ---- typed absence in comparisons (REQ-004, AC-003) ----------------------------------

test_that("AC-003 not tested, not significant, not supplied and not recorded stay distinct", {
  compare <- rx_ns("explorer_term_comparison")
  ref <- rx_dataset(rx_df(), "ref")
  absent <- rx_df(ids = c("GO:2", "GO:3"), labels = c("beta", "gamma"),
                  padj = c(0.02, 0.4), p = c(0.01, 0.3), genes = c("g2,g4", "g5"))
  b_sig <- rx_dataset(absent, "family-has-term", family = c("GO:1", "GO:2", "GO:3"))
  c_not <- rx_dataset(absent, "family-lacks-term", family = c("GO:2", "GO:3"))
  d_unknown <- rx_dataset(absent, "no-provenance")
  na_row <- rx_df()
  na_row$Padj[1] <- NA
  e_na <- rx_dataset(na_row, "na-stat")
  nostat <- rx_df()[, c("Annot", "Term", "GeneID")]
  f_none <- rx_dataset(nostat, "no-stat-column")
  g_ok <- rx_dataset(rx_df(padj = c(0.001, 0.02, 0.4)), "recorded")
  sets <- list(ref, b_sig, c_not, d_unknown, e_na, f_none, g_ok)
  names(sets) <- vapply(sets, function(d) paste0(d$id, "-", d$label), "")
  for (i in seq_along(sets)) sets[[i]]$id <- names(sets)[i]
  out <- compare(sets, reference_id = names(sets)[1], term_id = "GO:1")
  state <- stats::setNames(out$state, out$label)
  expect_identical(state[["ref"]], "recorded")
  expect_identical(state[["family-has-term"]], "not_significant")
  expect_identical(state[["family-lacks-term"]], "not_tested")
  expect_identical(state[["no-provenance"]], "not_recorded")
  expect_identical(state[["na-stat"]], "not_tested")
  expect_identical(state[["no-stat-column"]], "not_supplied")
  expect_identical(state[["recorded"]], "recorded")
  non_values <- out[out$state != "recorded", ]
  expect_true(all(is.na(non_values$plot_value)))
  expect_false(any(non_values$plot_value %in% 0, na.rm = TRUE))
  expect_true(all(is.na(non_values$Padj)))
  # distinct text cue per state, each naming the state in words
  cue <- unique(out[, c("state", "state_label")])
  expect_length(unique(cue$state_label), nrow(cue))
  expect_match(cue$state_label[cue$state == "not_tested"], "Not tested")
  expect_match(cue$state_label[cue$state == "not_significant"], "Not significant")
  expect_match(cue$state_label[cue$state == "not_supplied"], "Not supplied")
  expect_match(cue$state_label[cue$state == "not_recorded"], "Not recorded")
  # raw values pass through unrounded
  expect_identical(out$Padj[out$label == "ref"], 1e-300)
  expect_identical(out$Pvalue[out$label == "ref"], 1e-305)
})

test_that("AC-002 comparisons across incompatible or unknown context are unsupported", {
  compare <- rx_ns("explorer_term_comparison")
  ref <- rx_dataset(rx_df(), "ref")
  mouse <- rx_dataset(rx_df(), "mouse", context = rx_ctx(species = "mouse"))
  unknown <- rx_dataset(rx_df(), "unknown", context = rx_ctx(keytype = NA_character_))
  same <- rx_dataset(rx_df(padj = c(0.5, 0.5, 0.5)), "same")
  sets <- list(ref = ref, mouse = mouse, unknown = unknown, same = same)
  for (nm in names(sets)) sets[[nm]]$id <- nm
  out <- compare(sets, reference_id = "ref", term_id = "GO:1")
  rownames(out) <- out$label
  expect_identical(out["ref", "state"], "recorded")
  expect_identical(out["same", "state"], "recorded")
  expect_identical(out["mouse", "state"], "unsupported")
  expect_identical(out["unknown", "state"], "unsupported")
  expect_match(out["mouse", "state_label"], "unsupported", ignore.case = TRUE)
  expect_match(out["mouse", "reason"], "species")
  expect_match(out["unknown", "reason"], "not recorded")
  expect_true(all(is.na(out[c("mouse", "unknown"), "plot_value"])))
  expect_true(all(is.na(out[c("mouse", "unknown"), "shared_genes"])))
  expect_identical(out["same", "shared_genes"], "g1, g2, g3")
})

test_that("a term is matched by qualified ID, never by an identical label", {
  compare <- rx_ns("explorer_term_comparison")
  ref <- rx_dataset(rx_df(ids = "GO:1", labels = "same", padj = 0.1, p = 0.1, genes = "a"), "ref")
  other <- rx_dataset(rx_df(ids = "GO:9", labels = "same", padj = 0.2, p = 0.2, genes = "b"), "other",
                      family = "GO:9")
  sets <- list(ref = ref, other = other)
  for (nm in names(sets)) sets[[nm]]$id <- nm
  out <- compare(sets, reference_id = "ref", term_id = "GO:1")
  rownames(out) <- out$label
  expect_identical(out["other", "state"], "not_tested")
  expect_true(is.na(out["other", "Padj"]))
})

test_that("comparison plot leaves unavailable cells empty instead of zero", {
  compare <- rx_ns("explorer_term_comparison")
  ref <- rx_dataset(rx_df(), "ref")
  b <- rx_dataset(rx_df(ids = "GO:2", labels = "beta", padj = 0.5, p = 0.5, genes = "g"), "b",
                  family = c("GO:1", "GO:2"))
  sets <- list(ref = ref, b = b)
  for (nm in names(sets)) sets[[nm]]$id <- nm
  out <- compare(sets, "ref", "GO:1")
  p <- plotly::plotly_build(rx_ns("explorer_comparison_plot")(out))
  x <- unlist(lapply(p$x$data, function(tr) unlist(tr$x)))
  expect_false(any(x %in% 0))
  expect_length(x, 1L)
  expect_match(p$x$layout$title$text, "Not drawn")
  expect_match(p$x$layout$title$text, "Not significant")
})

# ---- exact values (REQ-005, AC-004) --------------------------------------------------

test_that("REQ-005 exact download keeps raw values and provider columns", {
  frame <- rx_ns("explorer_exact_frame")
  df <- rx_df(padj = c(1e-300, 0.1 + 0.2, 1 / 3), p = c(5e-324, 0.1, 2/3))
  df$Term[1] <- "=SUM(A1)"
  before <- rx_ns("project_table_digest")(df)
  out <- frame(df)
  expect_identical(names(out), names(df))
  expect_identical(rx_ns("project_table_digest")(df), before)
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path), add = TRUE)
  utils::write.csv(out, path, row.names = FALSE)
  back <- utils::read.csv(path, stringsAsFactors = FALSE)
  expect_identical(back$Padj, df$Padj)
  expect_identical(back$Pvalue, df$Pvalue)
  expect_identical(back$Term, df$Term)
  expect_identical(back$ProviderExtra, df$ProviderExtra)
  expect_identical(back$GeneID, df$GeneID)
})

test_that("display labels are readable and leave unknown provider columns alone", {
  labels <- rx_ns("explorer_display_labels")(names(rx_df()))
  expect_identical(unname(labels[c("Annot", "Term", "Pvalue", "Padj", "GeneID")]),
                   c("Term ID", "Term", "P-value", "Adjusted p-value", "Member genes"))
  expect_identical(unname(labels["ProviderExtra"]), "ProviderExtra")
})

# ---- result-first summary and actions (REQ-001, AC-004) -------------------------------

test_that("REQ-001 summary leads with facts and actions need no clustering", {
  facts <- rx_ns("explorer_summary_facts")
  df <- rx_df()
  out <- facts(df, "imported", rx_ns("workspace_result_id")(df), rx_ctx(species = NA_character_),
               run = NULL)
  expect_identical(out[["Terms"]], "3")
  expect_identical(out[["Species"]], "Not recorded")
  expect_identical(out[["Run"]], "Not recorded")
  expect_true(all(c("Result", "Result ID", "Terms", "Adjusted p-value column") %in% names(out)))
  actions <- rx_ns("explorer_actions")
  none <- actions(n_results = 0L, has_run = FALSE)
  expect_false(none$view$available)
  expect_match(none$view$reason, "Import")
  imported <- actions(n_results = 1L, has_run = FALSE)
  expect_true(imported$view$available)
  expect_true(imported$figure$available)
  expect_true(imported$cluster$available)
  expect_false(imported$rerun$available)
  expect_match(imported$rerun$reason, "recorded run")
  expect_true(actions(1L, TRUE)$rerun$available)
})

test_that("AC-004 imported enrichment without clusters offers a figure and exact export in the UI", {
  html <- as.character(richStudio:::rr_vis_tab_ui("results", "result_tab"))
  for (id in c("ex_result", "ex_table", "ex_plot", "ex_download_exact", "ex_download_safe",
               "ex_summary", "ex_actions", "ex_selected", "ex_compare_table")) {
    expect_match(html, paste0('id="results-', id, '"'), fixed = TRUE)
  }
  # no Explorer tab any more (SPEC-WS-013 M8): the term table is the page
  expect_false(grepl("Explorer", html, fixed = TRUE))
  # the existing figure routes remain reachable
  for (id in c("select_bar", "select_dot", "select_table", "select_net")) {
    expect_match(html, paste0('id="results-', id, '"'), fixed = TRUE)
  }
})

# ---- figures and tooltips (REQ-002, AC-001, security) -------------------------------

test_that("AC-001 the plot carries the stable keys and marks the selected term", {
  keys_fn <- rx_ns("workspace_row_keys")
  df <- rx_df()
  keys <- keys_fn(df, "rs-p", "ns")
  plot_fn <- rx_ns("explorer_term_plot")
  p <- plotly::plotly_build(plot_fn(df, keys, selected_key = keys[2], top = 2L, source = "s"))
  tr <- p$x$data[[1]]
  expect_true(keys[2] %in% unlist(tr$customdata))
  flags <- unlist(tr$marker$line$width)
  chosen <- unlist(tr$customdata) == keys[2]
  expect_true(all(flags[chosen] > flags[!chosen]))
  none <- plotly::plotly_build(plot_fn(df, keys, selected_key = NULL, top = 3L, source = "s"))
  expect_setequal(unlist(none$x$data[[1]]$customdata), keys)
})

test_that("selected term is always plotted even outside the top terms", {
  df <- rx_df(padj = c(0.001, 0.002, 0.9))
  keys <- rx_ns("workspace_row_keys")(df, "rs-p", "ns")
  p <- plotly::plotly_build(rx_ns("explorer_term_plot")(df, keys, selected_key = keys[3], top = 1L,
                                                         source = "s"))
  expect_true(keys[3] %in% unlist(p$x$data[[1]]$customdata))
  expect_length(unlist(p$x$data[[1]]$customdata), 2L)
})

test_that("tooltips and selection text escape imported terms", {
  df <- rx_df(labels = c("<img src=x onerror=alert(1)>", "b", "c"))
  keys <- rx_ns("workspace_row_keys")(df, "rs-p", "ns")
  p <- plotly::plotly_build(rx_ns("explorer_term_plot")(df, keys, selected_key = NULL, top = 3L,
                                                         source = "s"))
  hover <- paste(unlist(p$x$data[[1]]$text), collapse = " ")
  expect_false(grepl("<img", hover, fixed = TRUE))
  expect_match(hover, "&lt;img", fixed = TRUE)
  ui <- as.character(rx_ns("explorer_selection_ui")(df, 1L, keys[1], "rs-p", "ns"))
  expect_false(grepl("<img", ui, fixed = TRUE))
  expect_match(ui, "&lt;img", fixed = TRUE)
  expect_match(ui, "g1", fixed = TRUE)
})

test_that("plot clicks resolve only to known keys", {
  handle <- rx_ns("explorer_click_key")
  keys <- rx_ns("workspace_row_keys")(rx_df(), "rs-p", "ns")
  expect_identical(handle(data.frame(customdata = keys[2]), keys), keys[2])
  expect_null(handle(data.frame(customdata = "'] #x"), keys))
  expect_null(handle(NULL, keys))
  expect_null(handle(data.frame(customdata = NA_character_), keys))
})

# ---- cluster linkage (REQ-002) -----------------------------------------------------

test_that("cluster links use term IDs and report unsupported when the detail has none", {
  links <- rx_ns("explorer_cluster_links")
  detail <- data.frame(Cluster = c(1, 1, 2), Annot = c("GO:1", "GO:2", "GO:3"),
                       Term = c("same", "same", "same"), GeneID_a = c("g1,g2", "g3", "g9"),
                       stringsAsFactors = FALSE)
  one <- links(detail, "GO:2")
  expect_true(one$supported)
  expect_identical(one$clusters, "1")
  expect_setequal(one$genes, c("g1", "g2", "g3"))
  expect_identical(links(detail, "GO:404")$clusters, character())
  bare <- detail[, c("Cluster", "Term")]
  res <- links(bare, "GO:2")
  expect_false(res$supported)
  expect_match(res$reason, "term ID")
  expect_false(links(data.frame(), "GO:2")$supported)
})

# ---- module integration -------------------------------------------------------------

rx_args <- function(state) {
  state[intersect(names(state), names(formals(richStudio:::rr_vis_tab_server)))]
}

rx_state <- function() {
  state <- ws_baseline_state()
  state$u_rrnames$labels <- c("one", "two")
  state$u_rrdfs$one <- rx_df()
  state$u_rrdfs$two <- rx_df(ids = c("GO:1", "GO:2"), labels = c("alpha", "beta"),
                            padj = c(0.5, 0.6), p = c(0.4, 0.5), genes = c("g1", "g2"))
  state
}

test_that("AC-001 table selection after sorting resolves the source row and its genes", {
  state <- rx_state()
  args <- rx_args(state)
  shiny::testServer(richStudio:::rr_vis_tab_server, args = args, {
    session$setInputs(ex_result = "one")
    session$flushReact()
    keys <- explorer_state()$keys
    expect_length(keys, 3L)
    # DT server mode reports the ORIGINAL row index whatever the client sort order
    session$setInputs(ex_table_rows_selected = 2L)
    session$flushReact()
    expect_identical(selection$key(), keys[2])
    html <- paste(as.character(output$ex_selected$html), collapse = "")
    expect_match(html, "beta", fixed = TRUE)
    expect_match(html, "GO:2", fixed = TRUE)
    expect_match(html, "g4", fixed = TRUE)
    expect_false(grepl("alpha", html, fixed = TRUE))
    session$setInputs(ex_table_rows_selected = integer())
    session$flushReact()
    expect_null(selection$key())
  })
})

test_that("switching result clears a selection that belongs to another dataset", {
  state <- rx_state()
  args <- rx_args(state)
  shiny::testServer(richStudio:::rr_vis_tab_server, args = args, {
    session$setInputs(ex_result = "one")
    session$setInputs(ex_table_rows_selected = 1L)
    session$flushReact()
    expect_false(is.null(selection$key()))
    session$setInputs(ex_result = "two")
    session$flushReact()
    expect_null(selection$key())
  })
})

test_that("exact download writes the stored table without changing it", {
  state <- rx_state()
  before <- richStudio:::project_table_digest(shiny::isolate(state$u_rrdfs$one))
  args <- rx_args(state)
  shiny::testServer(richStudio:::rr_vis_tab_server, args = args, {
    session$setInputs(ex_result = "one")
    session$flushReact()
    path <- output$ex_download_exact
    back <- utils::read.csv(path, stringsAsFactors = FALSE)
    expect_identical(back$Padj, c(1e-300, 0.02, 0.4))
    expect_identical(back$ProviderExtra, paste0("x-", c("GO:1", "GO:2", "GO:3")))
    safe <- utils::read.csv(output$ex_download_safe, stringsAsFactors = FALSE)
    expect_identical(nrow(safe), 3L)
  })
  expect_identical(richStudio:::project_table_digest(shiny::isolate(state$u_rrdfs$one)), before)
})

test_that("comparison panel reports unsupported context for unrecorded imported results", {
  state <- rx_state()
  args <- rx_args(state)
  shiny::testServer(richStudio:::rr_vis_tab_server, args = args, {
    session$setInputs(ex_result = "one", ex_compare = c("one", "two"))
    session$setInputs(ex_table_rows_selected = 1L)
    session$flushReact()
    cmp <- explorer_comparison()
    expect_identical(nrow(cmp), 2L)
    expect_true("unsupported" %in% cmp$state)
    expect_false(any(cmp$plot_value %in% 0))
    html <- paste(as.character(output$ex_compare_table$html), collapse = "")
    expect_match(html, "Comparison unsupported", fixed = TRUE)
  })
})

# ---- SPEC-WS-013 M1: one job live region (AC-006) and server-driven empty states (AC-001) ----

test_that("AC-006 the selected-term panel is not a live region", {
  df <- rx_df()
  keys <- rx_ns("workspace_row_keys")(df, "rs-p", "ns")
  ui <- as.character(rx_ns("explorer_selection_ui")(df, 1L, keys[1], "rs-p", "ns"))
  expect_false(grepl("aria-live", ui, fixed = TRUE))
  expect_false(grepl("role=\"status\"|role=\"alert\"|role=\"log\"", ui))
})

test_that("AC-001 each result view hides its empty state when rows exist and shows it otherwise", {
  state <- ws_baseline_state(populated = TRUE)
  args <- state[intersect(names(state), names(formals(richStudio:::rr_vis_tab_server)))]
  args$id <- "results"
  owned <- shiny::MockShinySession$new()
  withr::defer(owned$close())
  sent <- new.env(parent = emptyenv())
  sent$custom <- list()
  original <- owned$sendCustomMessage
  withr::defer(owned$sendCustomMessage <- original)
  owned$sendCustomMessage <- function(type, message) {
    sent$custom[[length(sent$custom) + 1L]] <- list(type = type, message = message)
    original(type, message)
  }
  last <- function(id) {
    hits <- Filter(function(x) x$type %in% c("shinyjs-show", "shinyjs-hide") &&
                     identical(x$message$id, paste0("results-", id)), sent$custom)
    if (length(hits)) hits[[length(hits)]]$type else NA_character_
  }
  views <- c(table = "select_table", bar = "select_bar", dot = "select_dot", net = "select_net")
  shiny::testServer(richStudio:::rr_vis_tab_server, args = args, session = owned, {
    session$flushReact()
    for (view in names(views)) expect_identical(last(paste0(view, "_empty")), "shinyjs-show", info = view)
    expect_identical(last("hmap_empty"), "shinyjs-show")
    do.call(session$setInputs, stats::setNames(rep(list("untreated"), 4L), views))
    session$flushReact()
    for (view in names(views)) expect_identical(last(paste0(view, "_empty")), "shinyjs-hide", info = view)
    session$setInputs(select_tophmap = "untreated", tophmap_valtype = "Pvalue",
                      tophmap_cutoff = .05, tophmap_nterms = 3, edit_hmap_box = "Top terms")
    session$flushReact()
    expect_identical(last("hmap_empty"), "shinyjs-hide")
    expect_identical(last("top_hmap_box"), "shinyjs-show")
    do.call(session$setInputs, stats::setNames(rep(list(""), 4L), views))
    session$flushReact()
    for (view in names(views)) expect_identical(last(paste0(view, "_empty")), "shinyjs-show", info = view)
  })
})

test_that("AC-001 empty states name a next action", {
  ui <- as.character(richStudio:::rr_vis_tab_ui("results", "result_tab"))
  # table_empty went with the Table tab (SPEC-WS-013 M8): the master table speaks through ex_notice.
  for (id in c("bar_empty", "dot_empty", "net_empty", "hmap_empty")) {
    node <- regmatches(ui, regexpr(sprintf('id="results-%s".*?</div>', id), ui))
    expect_length(node, 1L)
    expect_match(node, "(Load|Import|Select|Choose)", info = id)
  }
})


# ---- SPEC-WS-013 M8: master-detail (AC-022, AC-024) -----------------------------------------

rx8_html <- function() as.character(richStudio:::rr_vis_tab_ui("results", "result_tab"))

test_that("AC-022 Results is a master-detail view: no tab set, one segmented plot-type control, closed figure settings", {
  html <- rx8_html()
  for (tab in c("Explorer", "Table", "Bar Plot", "Dot Plot", "Network")) {
    expect_false(grepl(paste0('data-value="', tab, '"'), html, fixed = TRUE), info = tab)
  }
  # at most one level of tabs remains (the heatmap Top/Custom choice inside the settings)
  expect_lte(lengths(regmatches(html, gregexpr('class="nav nav-tabs', html, fixed = TRUE)))[[1]], 1L)
  radios <- regmatches(html, gregexpr('<input type="radio" name="results-plot_type" value="[a-z]+"', html))[[1]]
  expect_identical(sub('.*value="([a-z]+)"', "\\1", radios), c("terms", "bar", "dot", "network", "heatmap"))
  settings <- regmatches(html, regexpr('(?s)<details class="rs-figure-settings"[^>]*>', html, perl = TRUE))
  expect_length(settings, 1L)
  expect_false(grepl(" open", settings, fixed = TRUE))
  # master (term table) and detail (figure) containers; the figure comes first in the DOM for narrow screens
  expect_match(html, 'class="rs-master-detail"', fixed = TRUE)
  expect_lt(regexpr('class="rs-detail"', html, fixed = TRUE), regexpr('class="rs-master"', html, fixed = TRUE))
  expect_match(html, 'id="results-ex_table"', fixed = TRUE)
  expect_match(html, 'id="results-ex_actions"', fixed = TRUE)
})

test_that("AC-024 Result ID and Annotation namespace are only inside a Details disclosure of the selected term", {
  df <- rx_df()
  html <- as.character(richStudio:::explorer_selection_ui(df, 1L, "k", "rs-1234", "GO:BP"))
  outside <- gsub("(?s)<details.*?</details>", "", html, perl = TRUE)
  for (term in c("Term", "Term ID", "Member genes")) expect_match(outside, term, fixed = TRUE)
  for (term in c("Result ID", "Annotation namespace")) {
    expect_false(grepl(term, outside, fixed = TRUE), info = term)
    expect_match(html, term, fixed = TRUE)
  }
  expect_match(html, "<details", fixed = TRUE)
})

test_that("AC-022 the cluster action is labelled for what it does", {
  expect_identical(rx_ns("explorer_actions")(1L, FALSE)$cluster$label, "Cluster these results")
})

test_that("AC-024 the Cluster figures page shows no linked-term paragraph until a term is selected", {
  selection <- rx_ns("workspace_selection_state")()
  shiny::testServer(rx_ns("clus_vis_tab_server"), args = list(
    u_degnames = shiny::reactiveValues(labels = NULL), u_degdfs = shiny::reactiveValues(),
    u_rrnames = shiny::reactiveValues(labels = NULL), u_rrdfs = shiny::reactiveValues(),
    u_big_rrdf = shiny::reactiveValues(), u_clusnames = shiny::reactiveValues(labels = NULL),
    u_clusdfs = shiny::reactiveValues(), u_big_clusdf = shiny::reactiveValues(),
    u_cluslists = shiny::reactiveValues(), selection = selection), {
    session$flushReact()
    expect_identical(paste(output$linked_term$html, collapse = ""), "")
  })
})
