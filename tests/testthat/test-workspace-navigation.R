# SPEC-WS-003 Home entry actions, active-workspace header and navigation
# continuity. Installed-module tests over synthetic stores and the bundled demo
# results only: no enrichment, clustering, browser or app.R execution.

ws3_tabs <- c("home_tab", "enrich_tab", "rr_visualize_tab", "cluster_upload_tab",
              "cluster_tab", "clus_visualize_tab", "update_tab", "save_tab")

ws3_count <- function(html, text) {
  lengths(regmatches(html, gregexpr(text, html, fixed = TRUE)))
}

ws3_html <- function(x) paste(as.character(x), collapse = "")

ws3_output_html <- function(value) paste(value$html, collapse = "")

# Sidebar captions keyed by their unchanged route strings.
ws3_captions <- function(html) {
  anchors <- regmatches(html, gregexpr('(?s)<a href="#shiny-tab-[A-Za-z_]+".*?</a>',
                                       html, perl = TRUE))[[1]]
  tabs <- sub('(?s)^<a href="#shiny-tab-([A-Za-z_]+)".*$', "\\1", anchors, perl = TRUE)
  text <- trimws(gsub("\\s+", " ", gsub("<[^>]+>", "", anchors)))
  stats::setNames(text, tabs)
}

# Session double: records every input update the server sends, through any scope.
ws3_record_inputs <- function(session) {
  root <- session$rootScope()
  log <- new.env(parent = emptyenv())
  log$calls <- list()
  if (bindingIsLocked("sendInputMessage", root)) unlockBinding("sendInputMessage", root)
  assign("sendInputMessage", function(inputId, message) {
    log$calls[[length(log$calls) + 1L]] <- list(id = inputId, message = message)
    invisible(NULL)
  }, envir = root)
  log
}

ws3_ids <- function(calls) vapply(calls, function(call) call$id, character(1))

ws3_since <- function(log, before) {
  if (length(log$calls) <= before) return(list())
  log$calls[seq.int(before + 1L, length(log$calls))]
}

ws3_is_own_select <- function(ids) grepl("(^|-)active_result$", ids)

ws3_last_select_update <- function(log) {
  ids <- ws3_ids(log$calls)
  hits <- which(ws3_is_own_select(ids))
  if (!length(hits)) return(NULL)
  log$calls[[max(hits)]]
}

ws3_sidebar_tabs <- function(calls) {
  calls <- Filter(function(call) identical(call$id, "workspace_sidebar"), calls)
  vapply(calls, function(call) call$message$value, character(1))
}

# Callback stubs for homeTabServer; events are recorded in activation order.
ws3_home_fixture <- function(results = FALSE, gene_lists = FALSE) {
  log <- new.env(parent = emptyenv())
  log$events <- character()
  # Production module id, so rendered button ids match the app ("home-...").
  list(log = log, args = list(
    id = "home",
    navigate = function(tab) {
      log$events <- c(log$events, paste0("navigate:", tab))
      invisible(TRUE)
    },
    load_demo = function() {
      log$events <- c(log$events, "load_demo")
      invisible(c("go1", "go2", "kegg1"))
    },
    has_results = shiny::reactiveVal(results),
    has_gene_lists = shiny::reactiveVal(gene_lists)
  ))
}

ws3_meta <- function(name, keytype, species) {
  data.frame(name = name, from_deg = "No", annot = "?", keytype = keytype,
             ontology = "?", species = species)
}

ws3_header_fixture <- function(labels = NULL, meta = NULL, active = NULL) {
  state <- ws_baseline_state()
  shiny::isolate({
    state$u_rrnames$labels <- labels
    state$u_big_rrdf$df <- meta
  })
  log <- new.env(parent = emptyenv())
  log$tabs <- character()
  # Production module id, so rendered button ids match the app ("workspace-...").
  list(log = log, args = list(
    id = "workspace",
    active_result = shiny::reactiveVal(active),
    u_rrnames = state$u_rrnames,
    u_big_rrdf = state$u_big_rrdf,
    navigate = function(tab) {
      log$tabs <- c(log$tabs, tab)
      invisible(TRUE)
    }
  ))
}

ws3_disabled <- function(html, id) {
  grepl(paste0('<button id="', id, '"[^>]*disabled'), html)
}

ws3_app_server <- function(mount_modules = FALSE) {
  function(input, output, session) {
    state <- ws_baseline_state()
    state$clus_intermed <- shiny::reactiveValues()
    mount <- function(fn, id) {
      do.call(fn, c(list(id), state[intersect(names(formals(fn)), names(state))]))
    }
    if (mount_modules) {
      mount(richStudio:::enrichTabServer, "enrich")
      mount(richStudio::clusterTabServer, "cluster")
      mount(richStudio:::rrVisTabServer, "rr_visualize")
    }
    nav <- richStudio:::workspace_navigation_server(session,
      u_degnames = state$u_degnames, u_rrnames = state$u_rrnames,
      u_rrdfs = state$u_rrdfs, u_big_rrdf = state$u_big_rrdf)
  }
}

test_that("REQ-001 AC-001 Home renders four native entry actions above About and links", {
  html <- ws3_html(richStudio:::homeTabUI("home", "home_tab", "fixture-version", enabled = TRUE))
  for (value in c('id="shiny-tab-home_tab"', "Welcome to richStudio", "Quick Start",
                  "vfixture-version", 'alt="richStudio logo"', 'id="home-context_actions"',
                  'id="home-demo_status"', "Hur Lab Homepage", "Citation:")) {
    expect_match(html, value, fixed = TRUE)
  }
  labels <- c(upload_gene_lists = "Upload gene lists",
              import_results = "Import enrichment results",
              open_saved = "Open saved analysis",
              load_demo = "Load demo results")
  for (id in names(labels)) {
    expect_match(html, paste0('<button id="home-', id, '" type="button"'), fixed = TRUE)
    expect_match(html, labels[[id]], fixed = TRUE)
    expect_false(ws3_disabled(html, paste0("home-", id)))
  }
  expect_match(html, "bundled demo results", ignore.case = TRUE)
  first_secondary <- min(regexpr("Hur Lab Homepage", html, fixed = TRUE),
                         regexpr("Citation:", html, fixed = TRUE))
  expect_gt(first_secondary, 0)
  expect_lt(regexpr("Welcome to richStudio", html, fixed = TRUE), regexpr("Quick Start", html, fixed = TRUE))
  for (label in labels) {
    position <- regexpr(label, html, fixed = TRUE)
    expect_gt(position, regexpr("Quick Start", html, fixed = TRUE))
    expect_lt(position, first_secondary)
  }
  # The numbered static stepper is replaced; context actions are server-rendered only.
  for (old in c("Upload &amp; Enrich", "Visualize &amp; Export", "step-card",
                "View results", "Continue setup")) {
    expect_false(grepl(old, html, fixed = TRUE))
  }
  # Heading outline never skips a level (h1 Welcome, h2 Quick Start, h3 box titles).
  levels <- as.integer(regmatches(html, gregexpr("(?<=<h)[1-6]", html, perl = TRUE))[[1]])
  expect_identical(levels[1:2], c(1L, 2L))
  expect_true(all(diff(levels) <= 1L))
  expect_match(html, '<h1 id="home-title" class="home-title">Welcome to richStudio</h1>', fixed = TRUE)
  expect_match(html, '<h2 id="home-quick_start_heading"', fixed = TRUE)
  expect_false(grepl("<h3>Quick Start", html, fixed = TRUE))
  # All Home content sits inside one named landmark; the entry actions in a nested one.
  expect_match(html, '^<div role="tabpanel"[^>]*>\\s*<section aria-labelledby="home-title">')
  expect_match(html, "</section>\\s*</div>$")
  expect_match(html, '<section class="workflow-stepper" aria-labelledby="home-quick_start_heading">',
               fixed = TRUE)
  expect_lt(regexpr("home-quick_start_heading", html, fixed = TRUE),
            regexpr("Upload gene lists", html, fixed = TRUE))
})

test_that("REQ-001 M15 enabled Home markup meets the accessibility contract", {
  html <- ws3_html(richStudio:::homeTabUI("home", "home_tab", "fixture-version", enabled = TRUE))
  # No element combines role="presentation" with an aria-label; icons are hidden instead.
  expect_false(grepl('<[^>]*role="presentation"[^>]*aria-label', html))
  expect_false(grepl('<[^>]*aria-label[^>]*role="presentation"', html))
  icons <- regmatches(html, gregexpr("<i [^>]*>", html))[[1]]
  expect_identical(icons, c('<i class="fas fa-globe" aria-hidden="true">',
                            rep('<i class="fab fa-github" aria-hidden="true">', 4L)))
  # Every link is named by its visible text; no aria-label is needed on the anchors.
  links <- regmatches(html, gregexpr('(?s)<a href="[^"]*" target="_blank"[^>]*>.*?</a>',
                                     html, perl = TRUE))[[1]]
  expect_identical(trimws(gsub("\\s+", " ", gsub("<[^>]+>", "", links))),
                   c("Hur Lab Homepage", "richStudio on GitHub", "richCluster",
                     "richR (0.1.5+)", "bioAnno", "Hur Lab"))
  expect_false(any(grepl("aria-label", links, fixed = TRUE)))
  # Info box titles: the colour sits on a child span, because .box-title is
  # #fff !important on the info header; the primary title keeps its 5.12:1 white.
  for (title in c("Quick Links", "About")) {
    expect_match(html, paste0('<h3 class="box-title">\\s*<span style="color: #1e293b;">',
                              title, '</span>\\s*</h3>'))
    expect_false(grepl(paste0('<h3 class="box-title"[^>]*style=[^>]*>\\s*', title), html))
  }
  expect_match(html, '<h3 class="box-title">Key Features</h3>', fixed = TRUE)
  # Inline text colours and the underlined inline link.
  expect_identical(ws3_count(html, '<p class="step-desc" style="color: #475569;">'), 2L)
  expect_match(html, '<div class="citation-block" style="color: #475569;">', fixed = TRUE)
  expect_match(html, '<small style="color: #475569;">richStudio vfixture-version', fixed = TRUE)
  expect_false(grepl("var(--rs-text-muted)", html, fixed = TRUE))
  expect_match(html, paste0('<a href="http://hurlab.med.und.edu/" target="_blank" ',
                            'style="text-decoration: underline;">Hur Lab</a>'), fixed = TRUE)
})

test_that("REQ-001 release switch off restores the previous Home content without entry actions", {
  html <- ws3_html(richStudio:::homeTabUI("home", "home_tab", "fixture-version", enabled = FALSE))
  for (value in c('id="shiny-tab-home_tab"', "Welcome to richStudio", "Quick Start",
                  "Upload &amp; Enrich", "Visualize &amp; Export", "vfixture-version")) {
    expect_match(html, value, fixed = TRUE)
  }
  # The previous stepper prose already contains "Import enrichment results from any
  # tool", so absence of entry actions is asserted on the action markup instead.
  for (absent in c("Upload gene lists", "Open saved analysis", "Load demo results",
                   'id="home-', "action-label", "<button")) {
    expect_false(grepl(absent, html, fixed = TRUE))
  }
  # The previous markup is kept: h3 Quick Start, no added landmark or heading ids.
  expect_match(html, "<h3>Quick Start</h3>", fixed = TRUE)
  for (absent in c("<section", "<h2", 'id="home-title"', "aria-labelledby")) {
    expect_false(grepl(absent, html, fixed = TRUE))
  }
  # Enabled-only accessibility adjustments do not leak into the previous Home.
  expect_match(html, 'role="presentation" aria-label="github icon"', fixed = TRUE)
  expect_match(html, '<small style="color: var(--rs-text-muted);">', fixed = TRUE)
  for (absent in c("aria-hidden", "text-decoration: underline", "#475569", "#1e293b")) {
    expect_false(grepl(absent, html, fixed = TRUE))
  }
})

test_that("REQ-002 sidebar relabels figure destinations and keeps every route in both switch states", {
  on <- ws3_html(richStudio:::workspace_sidebar_menu(enabled = TRUE))
  off <- ws3_html(richStudio:::workspace_sidebar_menu(enabled = FALSE))
  # The two menu groups keep their existing group tabNames as well.
  shared <- c(home_tab = "Home", enrich_tab_group = "Enrichment", enrich_tab = "Enrich",
              cluster_tab_group = "Clustering", cluster_upload_tab = "Upload files",
              cluster_tab = "Cluster", update_tab = "Manage Files", save_tab = "Save/Load")
  for (html in list(on, off)) {
    captions <- ws3_captions(html)
    expect_setequal(names(captions), c(ws3_tabs, "enrich_tab_group", "cluster_tab_group"))
    expect_identical(captions[names(shared)], shared)
  }
  expect_identical(ws3_captions(on)[c("rr_visualize_tab", "clus_visualize_tab")],
                   c(rr_visualize_tab = "Enrichment figures", clus_visualize_tab = "Cluster figures"))
  expect_identical(ws3_captions(off)[c("rr_visualize_tab", "clus_visualize_tab")],
                   c(rr_visualize_tab = "Visualize", clus_visualize_tab = "Visualize"))
  expect_match(on, 'id="workspace_sidebar"', fixed = TRUE)
  expect_false(grepl("figures", off, fixed = TRUE))
})

test_that("REQ-003 S11 header is an accessible region with a native dataset chooser and no provenance marker", {
  on <- ws3_html(richStudio:::workspace_header_ui("workspace", enabled = TRUE))
  for (value in c('id="workspace-header"', 'aria-label="Active workspace"',
                  '<select class="shiny-input-select form-control" id="workspace-active_result">',
                  "Change dataset", '<option value="" selected>Choose a result</option>',
                  'id="workspace-summary"', 'id="workspace-actions"')) {
    expect_match(on, value, fixed = TRUE)
  }
  expect_false(grepl('data-for="workspace-active_result"', on, fixed = TRUE))
  expect_false(grepl("<h[1-6]", on))
  for (kind in c("rs-workspace-kind", "Setup draft", "Captured run settings", "Display filter",
                 "Committed input revision", "Unsaved project changes")) {
    expect_false(grepl(kind, on, fixed = TRUE))
  }
  expect_identical(ws3_html(shiny::tagList(
    richStudio:::workspace_header_ui("workspace", enabled = FALSE))), "")
})

test_that("REQ-001 AC-001 demo loader reproduces the bundled results once and skips present labels", {
  state <- ws_baseline_state()
  load <- function() shiny::isolate(richStudio:::workspace_load_demo_results(
    state$u_rrnames, state$u_rrdfs, state$u_big_rrdf))
  expect_identical(load(), c("go1", "go2", "kegg1"))
  expected_meta <- NULL
  shiny::isolate({
    expect_identical(state$u_rrnames$labels, c("go1", "go2", "kegg1"))
    for (label in c("go1", "go2", "kegg1")) {
      expect_identical(state$u_rrdfs[[label]],
                       read.delim(richStudio:::sample_rr_path(paste0(label, ".txt"))))
      expected_meta <- richStudio::add_file_rrdf(expected_meta, name = label, file = TRUE)
    }
    expect_identical(state$u_big_rrdf$df, expected_meta)
  })
  expect_identical(load(), character())
  shiny::isolate({
    expect_identical(state$u_rrnames$labels, c("go1", "go2", "kegg1"))
    expect_identical(state$u_big_rrdf$df, expected_meta)
  })

  # A user result already named go2 is never replaced by the demo copy.
  state <- ws_baseline_state()
  user_go2 <- data.frame(Term = "user", Pvalue = 0.5)
  shiny::isolate({
    state$u_rrnames$labels <- "go2"
    state$u_rrdfs$go2 <- user_go2
  })
  expect_identical(load(), c("go1", "kegg1"))
  shiny::isolate({
    expect_identical(state$u_rrnames$labels, c("go2", "go1", "kegg1"))
    expect_identical(state$u_rrdfs$go2, user_go2)
  })
})

test_that("REQ-001 AC-001 Home actions call only their navigation callback and demo loads only on demand", {
  routes <- list(upload_gene_lists = "navigate:enrich_tab",
                 import_results = "navigate:cluster_upload_tab",
                 open_saved = "navigate:save_tab",
                 load_demo = c("load_demo", "navigate:rr_visualize_tab"))
  for (action in names(routes)) {
    fixture <- ws3_home_fixture()
    shiny::testServer(richStudio:::homeTabServer, args = fixture$args, {
      inputs <- ws3_record_inputs(session)
      session$flushReact()
      expect_identical(fixture$log$events, character())
      do.call(session$setInputs, stats::setNames(list(1L), action))
      expect_identical(fixture$log$events, routes[[action]])
      expect_length(inputs$calls, 0L)
      if (identical(action, "load_demo")) {
        expect_match(output$demo_status, "bundled demo results", ignore.case = TRUE)
      }
    })
  }
})

test_that("REQ-001 Home context actions are absent without data and route only when enabled", {
  fixture <- ws3_home_fixture()
  shiny::testServer(richStudio:::homeTabServer, args = fixture$args, {
    session$flushReact()
    html <- ws3_output_html(output$context_actions)
    expect_false(grepl("View results", html, fixed = TRUE))
    expect_false(grepl("Continue setup", html, fixed = TRUE))
    session$setInputs(view_results = 1L, continue_setup = 1L)
    expect_identical(fixture$log$events, character())

    # Gene lists only: View results is visible but disabled with its reason.
    fixture$args$has_gene_lists(TRUE)
    session$flushReact()
    html <- ws3_output_html(output$context_actions)
    expect_match(html, "View results", fixed = TRUE)
    expect_match(html, "Continue setup", fixed = TRUE)
    expect_true(ws3_disabled(html, "home-view_results"))
    expect_match(html, "Import or load enrichment results first", fixed = TRUE)
    expect_false(ws3_disabled(html, "home-continue_setup"))
    session$setInputs(view_results = 2L)
    expect_identical(fixture$log$events, character())
    session$setInputs(continue_setup = 2L)
    expect_identical(fixture$log$events, "navigate:enrich_tab")

    fixture$args$has_results(TRUE)
    session$flushReact()
    html <- ws3_output_html(output$context_actions)
    expect_false(ws3_disabled(html, "home-view_results"))
    session$setInputs(view_results = 3L)
    expect_identical(fixture$log$events, c("navigate:enrich_tab", "navigate:rr_visualize_tab"))

    # Results only: Continue setup is visible but disabled.
    fixture$args$has_gene_lists(FALSE)
    session$flushReact()
    html <- ws3_output_html(output$context_actions)
    expect_true(ws3_disabled(html, "home-continue_setup"))
    session$setInputs(continue_setup = 3L)
    expect_identical(fixture$log$events, c("navigate:enrich_tab", "navigate:rr_visualize_tab"))
  })
})

test_that("REQ-003 S9r header shows recorded organism and identifier type for a one-row match", {
  meta <- rbind(ws3_meta("go1", "SYMBOL", "human"), ws3_meta("kegg1", "ENTREZID", "mouse"))
  fixture <- ws3_header_fixture(c("go1", "go2", "kegg1"), meta, "kegg1")
  shiny::testServer(richStudio:::workspaceHeaderServer, args = fixture$args, {
    session$flushReact()
    html <- ws3_output_html(output$summary)
    for (value in c("kegg1", "Recorded organism", "Recorded identifier type",
                    "From the recorded result details", "mouse", "ENTREZID", "Run")) {
      expect_match(html, value, fixed = TRUE)
    }
    # Only the run is unrecorded; the other result's facts are never borrowed.
    expect_identical(ws3_count(html, "Not recorded"), 1L)
    expect_false(grepl("<h[1-6]", html))
    for (absent in c("human", "SYMBOL", "Recorded details unavailable for this result name",
                     "No dataset selected")) {
      expect_false(grepl(absent, html, fixed = TRUE))
    }
  })
})

test_that("REQ-003 unknown recorded values are shown as not recorded", {
  for (value in list("?", "NULL", NA_character_, "")) {
    meta <- rbind(ws3_meta("go1", "SYMBOL", "human"), ws3_meta("kegg1", value, value))
    fixture <- ws3_header_fixture(c("go1", "kegg1"), meta, "kegg1")
    shiny::testServer(richStudio:::workspaceHeaderServer, args = fixture$args, {
      session$flushReact()
      html <- ws3_output_html(output$summary)
      expect_match(html, "kegg1", fixed = TRUE)
      expect_identical(ws3_count(html, "Not recorded"), 3L)
      # One matching row: its (unknown) recorded details are shown with the source note.
      expect_match(html, "From the recorded result details", fixed = TRUE)
      expect_false(grepl("Recorded details unavailable for this result name", html, fixed = TRUE))
      for (absent in c("human", "SYMBOL", ">?<", ">NULL<", ">NA<")) {
        expect_false(grepl(absent, html, fixed = TRUE))
      }
    })
  }
})

test_that("REQ-003 zero or repeated recorded rows never guess and say details are unavailable", {
  cases <- list(
    zero = ws3_meta("go1", "SYMBOL", "human"),
    two = rbind(ws3_meta("kegg1", "ENTREZID", "mouse"), ws3_meta("kegg1", "SYMBOL", "rat")))
  for (case in names(cases)) {
    fixture <- ws3_header_fixture(c("go1", "kegg1"), cases[[case]], "kegg1")
    shiny::testServer(richStudio:::workspaceHeaderServer, args = fixture$args, {
      session$flushReact()
      html <- ws3_output_html(output$summary)
      expect_match(html, "kegg1", fixed = TRUE)
      expect_identical(ws3_count(html, "Not recorded"), 3L)
      expect_match(html, "Recorded details unavailable for this result name", fixed = TRUE)
      # The source note accompanies shown details only, never the unavailable line.
      for (absent in c("human", "mouse", "rat", "SYMBOL", "ENTREZID",
                       "From the recorded result details")) {
        expect_false(grepl(absent, html, fixed = TRUE))
      }
    })
  }
})

test_that("REQ-003 M12 no active result shows no dataset and disables both actions with the right reason", {
  cases <- list(list(labels = NULL, reason = "Import or load enrichment results first"),
                list(labels = c("go1", "kegg1"), reason = "Choose a result first"))
  for (case in cases) {
    fixture <- ws3_header_fixture(case$labels, NULL, NULL)
    shiny::testServer(richStudio:::workspaceHeaderServer, args = fixture$args, {
      inputs <- ws3_record_inputs(session)
      session$flushReact()
      expect_match(ws3_output_html(output$summary), "No dataset selected", fixed = TRUE)
      actions <- ws3_output_html(output$actions)
      expect_match(actions, "Create figure", fixed = TRUE)
      expect_match(actions, "Cluster results", fixed = TRUE)
      expect_true(ws3_disabled(actions, "workspace-create_figure"))
      expect_true(ws3_disabled(actions, "workspace-cluster_results"))
      expect_match(actions, case$reason, fixed = TRUE)
      before <- length(inputs$calls)
      session$setInputs(create_figure = 1L, cluster_results = 1L)
      expect_length(ws3_since(inputs, before), 0L)
      expect_identical(fixture$log$tabs, character())
    })
  }
})

test_that("REQ-003 hostile result labels and recorded values render as escaped text", {
  label <- "<img src=x onerror=alert(1)>"
  meta <- ws3_meta(label, "<b>key</b>", "<script>sp()</script>")
  fixture <- ws3_header_fixture(label, meta, label)
  shiny::testServer(richStudio:::workspaceHeaderServer, args = fixture$args, {
    session$flushReact()
    html <- ws3_output_html(output$summary)
    expect_match(html, "&lt;img src=x onerror=alert(1)&gt;", fixed = TRUE)
    expect_match(html, "&lt;b&gt;key&lt;/b&gt;", fixed = TRUE)
    for (raw in c("<img src=x", "<b>key", "<script>")) expect_false(grepl(raw, html, fixed = TRUE))
  })
})

test_that("REQ-003 S8 M13 Change dataset never auto-selects, ignores unknown values and clears removals", {
  fixture <- ws3_header_fixture()
  active <- fixture$args$active_result
  names_store <- fixture$args$u_rrnames
  shiny::testServer(richStudio:::workspaceHeaderServer, args = fixture$args, {
    inputs <- ws3_record_inputs(session)
    session$flushReact()
    names_store$labels <- c("go1", "go2", "kegg1")
    session$flushReact()
    expect_null(active())
    update <- ws3_last_select_update(inputs)
    expect_false(is.null(update))
    expect_identical(update$message$value, "")
    expect_match(update$message$options, "Choose a result", fixed = TRUE)
    for (label in c("go1", "go2", "kegg1")) {
      expect_match(update$message$options, paste0('value="', label, '"'), fixed = TRUE)
    }

    session$setInputs(active_result = "kegg1")
    expect_identical(active(), "kegg1")
    names_store$labels <- c(names_store$labels, "extra")
    session$flushReact()
    expect_identical(active(), "kegg1")
    expect_identical(ws3_last_select_update(inputs)$message$value, "kegg1")

    session$setInputs(active_result = "not-a-result")
    expect_identical(active(), "kegg1")

    names_store$labels <- setdiff(names_store$labels, "kegg1")
    session$flushReact()
    expect_null(active())
    update <- ws3_last_select_update(inputs)
    expect_identical(update$message$value, "")
    expect_match(update$message$options, "Choose a result", fixed = TRUE)
    expect_false(grepl('value="kegg1"', update$message$options, fixed = TRUE))
    expect_match(ws3_output_html(output$summary), "No dataset selected", fixed = TRUE)

    session$setInputs(active_result = "go2")
    expect_identical(active(), "go2")
    session$setInputs(active_result = "")
    expect_null(active())
  })
})

test_that("REQ-002 AC-002 M14 Create figure selects the active result in both figure selectors only", {
  meta <- ws3_meta("kegg1", "ENTREZID", "mouse")
  fixture <- ws3_header_fixture(c("go1", "go2", "kegg1"), meta, "kegg1")
  shiny::testServer(richStudio:::workspaceHeaderServer, args = fixture$args, {
    inputs <- ws3_record_inputs(session)
    session$flushReact()
    actions <- ws3_output_html(output$actions)
    expect_false(ws3_disabled(actions, "workspace-create_figure"))
    expect_false(ws3_disabled(actions, "workspace-cluster_results"))

    before <- length(inputs$calls)
    session$setInputs(create_figure = 1L)
    sent <- ws3_since(inputs, before)
    expect_setequal(ws3_ids(sent), c("rr_visualize-select_bar", "rr_visualize-select_dot"))
    expect_length(sent, 2L)
    for (call in sent) {
      expect_identical(call$message$value, "kegg1")
      expect_null(call$message$options)
    }
    expect_identical(fixture$log$tabs, "rr_visualize_tab")

    before <- length(inputs$calls)
    session$setInputs(cluster_results = 1L)
    expect_length(ws3_since(inputs, before), 0L)
    expect_identical(fixture$log$tabs, c("rr_visualize_tab", "cluster_tab"))
  })
})

test_that("REQ-001 REQ-002 M14 session wiring routes every action through the sidebar only", {
  shiny::testServer(ws3_app_server(), {
    inputs <- ws3_record_inputs(session)
    session$flushReact()
    expect_null(nav$active_result())
    act <- function(input, value = 1L) {
      before <- length(inputs$calls)
      do.call(session$setInputs, stats::setNames(list(value), input))
      sent <- ws3_since(inputs, before)
      ids <- ws3_ids(sent)
      expect_true(all(ids == "workspace_sidebar" | ws3_is_own_select(ids)), info = input)
      ws3_sidebar_tabs(sent)
    }
    expect_identical(act("home-upload_gene_lists"), "enrich_tab")
    expect_identical(act("home-import_results"), "cluster_upload_tab")
    expect_identical(act("home-open_saved"), "save_tab")
    expect_null(state$u_rrnames$labels)

    expect_identical(act("home-load_demo"), "rr_visualize_tab")
    expect_identical(state$u_rrnames$labels, c("go1", "go2", "kegg1"))
    expect_identical(nav$active_result(), "go1")

    expect_identical(act("workspace-active_result", "kegg1"), character())
    expect_identical(nav$active_result(), "kegg1")
    expect_identical(act("home-load_demo", 2L), "rr_visualize_tab")
    expect_identical(nav$active_result(), "kegg1")
    expect_identical(state$u_rrnames$labels, c("go1", "go2", "kegg1"))

    expect_identical(act("home-view_results"), "rr_visualize_tab")
    expect_identical(act("home-continue_setup"), character())
    state$u_degnames$labels <- "query"
    session$flushReact()
    expect_identical(act("home-continue_setup", 2L), "enrich_tab")
    expect_identical(act("workspace-cluster_results"), "cluster_tab")

    before <- length(inputs$calls)
    session$setInputs(`workspace-create_figure` = 1L)
    sent <- ws3_since(inputs, before)
    figure <- Filter(function(call) call$id != "workspace_sidebar", sent)
    expect_setequal(ws3_ids(figure), c("rr_visualize-select_bar", "rr_visualize-select_dot"))
    expect_true(all(vapply(figure, function(call) identical(call$message$value, "kegg1"), logical(1))))
    expect_identical(ws3_sidebar_tabs(sent), "rr_visualize_tab")
  })
})

test_that("REQ-001 navigation rejects unknown route names without sending an update", {
  shiny::testServer(ws3_app_server(), {
    inputs <- ws3_record_inputs(session)
    session$flushReact()
    # The header's own chooser initialisation may precede navigation; count from here.
    before <- length(inputs$calls)
    expect_true(all(ws3_is_own_select(ws3_ids(inputs$calls))))
    for (tab in list("not_a_tab", "", NA_character_, c("home_tab", "save_tab"),
                     "<script>alert(1)</script>", NULL, 1L)) {
      expect_false(isTRUE(nav$navigate(tab)))
    }
    expect_length(ws3_since(inputs, before), 0L)
    for (tab in ws3_tabs) expect_true(isTRUE(nav$navigate(tab)))
    expect_identical(ws3_sidebar_tabs(inputs$calls), ws3_tabs)
  })
})

test_that("REQ-003 two sessions keep independent active results", {
  captured <- new.env(parent = emptyenv())
  shiny::testServer(ws3_app_server(), {
    session$flushReact()
    session$setInputs(`home-load_demo` = 1L)
    expect_identical(nav$active_result(), "go1")
    captured$first <- nav
  })
  shiny::testServer(ws3_app_server(), {
    session$flushReact()
    expect_null(nav$active_result())
    expect_null(state$u_rrnames$labels)
    session$setInputs(`home-load_demo` = 1L)
    session$setInputs(`workspace-active_result` = "kegg1")
    expect_identical(nav$active_result(), "kegg1")
    captured$second <- nav
  })
  expect_identical(shiny::isolate(captured$first$active_result()), "go1")
  expect_identical(shiny::isolate(captured$second$active_result()), "kegg1")
})

test_that("REQ-001 REQ-003 F3 server-rendered action ids follow the session namespace", {
  home <- ws3_home_fixture(results = TRUE, gene_lists = TRUE)
  header <- ws3_header_fixture(c("go1", "kegg1"), NULL, "kegg1")
  # Mounted below another module, the raw module id ("home") would be wrong.
  outer <- function(id) shiny::moduleServer(id, function(input, output, session) {
    do.call(richStudio:::homeTabServer, home$args)
    do.call(richStudio:::workspaceHeaderServer, header$args)
  })
  shiny::testServer(outer, args = list(id = "outer"), {
    session$flushReact()
    context <- ws3_output_html(output[["home-context_actions"]])
    expect_match(context, '<button id="outer-home-view_results"', fixed = TRUE)
    expect_match(context, '<button id="outer-home-continue_setup"', fixed = TRUE)
    actions <- ws3_output_html(output[["workspace-actions"]])
    expect_match(actions, '<button id="outer-workspace-create_figure"', fixed = TRUE)
    expect_match(actions, '<button id="outer-workspace-cluster_results"', fixed = TRUE)
    expect_false(grepl('id="home-', context, fixed = TRUE))
    expect_false(grepl('id="workspace-', actions, fixed = TRUE))
    session$setInputs(`home-view_results` = 1L, `workspace-cluster_results` = 1L)
    expect_identical(home$log$events, "navigate:rr_visualize_tab")
    expect_identical(header$log$tabs, "cluster_tab")
  })
})

test_that("REQ-001 F4 demo status names added and skipped bundled results precisely", {
  status <- richStudio:::workspace_demo_status
  all <- status(c("go1", "go2", "kegg1"))
  expect_identical(all, "Added bundled demo results: go1, go2, kegg1.")
  some <- status(c("go1", "kegg1"))
  expect_identical(some, paste("Added bundled demo results: go1, kegg1.",
    "Not added because a result with that name already exists: go2."))
  none <- status(character())
  expect_identical(none, paste("No bundled demo results added.",
    "Not added because a result with that name already exists: go1, go2, kegg1."))
})

test_that("REQ-001 REQ-003 F4 a user result named go1 is kept, reported and never activated", {
  shiny::testServer(ws3_app_server(), {
    user_go1 <- data.frame(Term = "user", Pvalue = 0.5)
    state$u_rrnames$labels <- "go1"
    state$u_rrdfs$go1 <- user_go1
    session$flushReact()
    session$setInputs(`home-load_demo` = 1L)
    expect_identical(state$u_rrnames$labels, c("go1", "go2", "kegg1"))
    expect_identical(state$u_rrdfs$go1, user_go1)
    expect_null(nav$active_result())
    expect_identical(output[["home-demo_status"]], paste(
      "Added bundled demo results: go2, kegg1.",
      "Not added because a result with that name already exists: go1."))
    # Activating again adds nothing and still activates nothing.
    session$setInputs(`home-load_demo` = 2L)
    expect_null(nav$active_result())
    expect_match(output[["home-demo_status"]], "No bundled demo results added.", fixed = TRUE)
  })
})

test_that("REQ-004 AC-002 AC-003 M10 entry and header actions start no enrichment or clustering", {
  old_plan <- future::plan("sequential")
  withr::defer(future::plan(old_plan))
  counts <- new.env(parent = emptyenv())
  entry_points <- c("run_enrichment_jobs", "shiny_enrich", "perform_clustering")
  stub <- function(name) {
    force(name)
    function(...) {
      counts[[name]] <- counts[[name]] + 1L
      NULL
    }
  }
  testthat::local_mocked_bindings(
    run_enrichment_jobs = stub("run_enrichment_jobs"),
    shiny_enrich = stub("shiny_enrich"),
    perform_clustering = stub("perform_clustering"),
    .package = "richStudio")
  # Positive control: a namespace call, as the modules make it, reaches each stub.
  for (name in entry_points) counts[[name]] <- 0L
  richStudio:::run_enrichment_jobs()
  richStudio:::shiny_enrich()
  richStudio:::perform_clustering()
  expect_identical(mget(entry_points, envir = counts), as.list(stats::setNames(rep(1L, 3L), entry_points)))
  for (name in entry_points) counts[[name]] <- 0L

  shiny::testServer(ws3_app_server(mount_modules = TRUE), {
    session$flushReact()
    for (input in c("home-upload_gene_lists", "home-import_results", "home-open_saved",
                    "home-load_demo")) {
      do.call(session$setInputs, stats::setNames(list(1L), input))
    }
    session$setInputs(`workspace-active_result` = "kegg1")
    state$u_degnames$labels <- "query"
    session$flushReact()
    for (input in c("home-view_results", "home-continue_setup", "workspace-create_figure",
                    "workspace-cluster_results")) {
      do.call(session$setInputs, stats::setNames(list(1L), input))
    }
    session$setInputs(`home-load_demo` = 2L)
    session$flushReact()
    expect_identical(state$u_rrnames$labels, c("go1", "go2", "kegg1"))
    expect_identical(nav$active_result(), "kegg1")
  })
  expect_identical(mget(entry_points, envir = counts), as.list(stats::setNames(rep(0L, 3L), entry_points)))
})

test_that("REQ-001 REQ-002 installed app wires the release switch, menu, header and captions", {
  path <- system.file("application", "app.R", package = "richStudio")
  expect_true(nzchar(path))
  text <- paste(readLines(path, warn = FALSE), collapse = "\n")
  expect_match(text, 'getOption\\(\\s*"richStudio\\.workspace_navigation"\\s*,\\s*TRUE\\s*\\)')
  for (call in c("workspace_sidebar_menu\\(", "workspace_header_ui\\(",
                 "workspace_navigation_server\\(", "homeTabUI\\([^)]*enabled")) {
    expect_match(text, call)
  }
  for (caption in c("'rr_visualize_tab': 'Enrichment / Enrichment figures'",
                    "'clus_visualize_tab': 'Clustering / Cluster figures'")) {
    expect_match(text, caption, fixed = TRUE)
  }
  expect_false(grepl('menuSubItem("Visualize"', text, fixed = TRUE))
})
