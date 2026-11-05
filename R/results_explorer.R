# Unified result explorer (SPEC-WS-008). A result-first view placed above the existing
# table and figure modules: it summarizes a result, links a table, a figure and a
# multi-dataset comparison through one stable row identity, and exports exact values.
# Nothing here recomputes a statistic, clusters, or edits a stored result; every
# display step only reads the tables and formats copies of them.

# ---- dataset identity cues (REQ-003) ----------------------------------------------

# Palette and symbols from the workspace design system. Colour only carries dataset
# identity; the text code and the symbol carry it for readers who cannot see colour.
explorer_cue_colors <- c("#0f6fc5", "#21c4b6", "#6366f1")
explorer_cue_symbols <- c("circle", "square", "triangle")

# Order, code, symbol and colour are a pure function of the stable dataset IDs, so a
# rename, a reorder or a filter of the visible rows cannot move a dataset's cue.
explorer_dataset_cues <- function(ids) {
  ids <- unique(as.character(ids))
  ids <- ids[order(ids, method = "radix")]
  n <- length(ids)
  code <- if (!n) character() else if (n <= length(LETTERS)) paste0("D-", LETTERS[seq_len(n)]) else
    sprintf("D-%d", seq_len(n))
  data.frame(
    id = ids, code = code,
    symbol = explorer_cue_symbols[(seq_len(n) - 1L) %% length(explorer_cue_symbols) + 1L],
    color = explorer_cue_colors[(seq_len(n) - 1L) %% length(explorer_cue_colors) + 1L],
    stringsAsFactors = FALSE)
}

# ---- typed absence (REQ-004) --------------------------------------------------------

explorer_state_labels <- c(
  recorded = "\u25cf Recorded value",
  not_tested = "\u25cb Not tested",
  not_significant = "\u25b3 Not significant",
  not_supplied = "\u25a1 Not supplied",
  not_recorded = "? Not recorded",
  unsupported = "! Comparison unsupported")

explorer_stat_columns <- function(df) {
  list(padj = if ("Padj" %in% names(df)) "Padj" else NA_character_,
       p = if ("Pvalue" %in% names(df)) "Pvalue" else NA_character_)
}

# State of one term in one dataset. A missing row means "not tested" or "not
# significant" only when the dataset records its test family; with no provenance it is
# "not recorded". A NA statistic on a present row was not computed for that row.
explorer_term_state <- function(df, term_id, family) {
  cols <- workspace_term_columns(df)
  stat <- explorer_stat_columns(df)
  primary <- if (!is.na(stat$padj)) stat$padj else stat$p
  rows <- if (is.na(cols$id)) integer() else which(as.character(df[[cols$id]]) == term_id)
  row <- if (length(rows)) rows[1] else NA_integer_
  state <- if (is.na(primary)) {
    "not_supplied"
  } else if (!is.na(row)) {
    if (is.na(df[[primary]][row])) "not_tested" else "recorded"
  } else if (is.null(family)) {
    "not_recorded"
  } else if (term_id %in% as.character(family)) {
    "not_significant"
  } else {
    "not_tested"
  }
  list(state = state, row = row, primary = primary)
}

# One row per dataset for the selected term. Terms are matched by qualified ID within
# a compatible species/keytype/annotation context; an incompatible or unknown context
# is reported as unsupported, never assumed to match. Values are the stored values.
# `datasets` is a list named by stable dataset ID; each element carries label, df,
# context and an optional test_family (term IDs tested in that dataset).
explorer_term_comparison <- function(datasets, reference_id, term_id,
                                     cues = explorer_dataset_cues(names(datasets))) {
  ref <- datasets[[reference_id]]
  ref_genes <- NULL
  if (!is.null(ref)) {
    ref_cols <- workspace_term_columns(ref$df)
    ref_row <- if (is.na(ref_cols$id)) integer() else which(as.character(ref$df[[ref_cols$id]]) == term_id)
    if (length(ref_row) && "GeneID" %in% names(ref$df)) {
      ref_genes <- workspace_member_genes(ref$df$GeneID[ref_row[1]])
    }
  }
  ids <- cues$id[cues$id %in% names(datasets)]
  rows <- lapply(ids, function(id) {
    ds <- datasets[[id]]
    cue <- cues[cues$id == id, , drop = FALSE]
    out <- list(dataset_id = id, label = ds$label, code = cue$code, symbol = cue$symbol,
                color = cue$color, state = NA_character_, reason = NA_character_,
                Padj = NA_real_, Pvalue = NA_real_, plot_value = NA_real_,
                shared_genes = NA_character_)
    compat <- if (identical(id, reference_id) || is.null(ref)) {
      list(supported = TRUE, reason = NA_character_)
    } else {
      workspace_context_compatible(ref$context, ds$context)
    }
    if (!compat$supported) {
      out$state <- "unsupported"
      out$reason <- compat$reason
      return(out)
    }
    info <- explorer_term_state(ds$df, term_id, ds$test_family)
    out$state <- info$state
    if (!is.na(info$row)) {
      stat <- explorer_stat_columns(ds$df)
      if (!is.na(stat$padj)) out$Padj <- as.numeric(ds$df[[stat$padj]][info$row])
      if (!is.na(stat$p)) out$Pvalue <- as.numeric(ds$df[[stat$p]][info$row])
    }
    if (identical(info$state, "recorded")) {
      value <- as.numeric(ds$df[[info$primary]][info$row])
      if (is.finite(value) && value > 0) {
        out$plot_value <- -log10(value)
      } else {
        out$reason <- "A p-value of zero cannot be drawn on a log scale; the stored value is shown in the table"
      }
      if (!is.null(ref_genes) && "GeneID" %in% names(ds$df)) {
        shared <- intersect(ref_genes, workspace_member_genes(ds$df$GeneID[info$row]))
        out$shared_genes <- paste(shared, collapse = ", ")
      }
    }
    out
  })
  if (!length(rows)) {
    return(data.frame(dataset_id = character(), label = character(), code = character(),
                      symbol = character(), color = character(), state = character(),
                      state_label = character(), reason = character(), Padj = numeric(),
                      Pvalue = numeric(), plot_value = numeric(), shared_genes = character(),
                      stringsAsFactors = FALSE))
  }
  out <- do.call(rbind, lapply(rows, as.data.frame, stringsAsFactors = FALSE))
  out$state_label <- unname(explorer_state_labels[out$state])
  out[, c("dataset_id", "label", "code", "symbol", "color", "state", "state_label", "reason",
          "Padj", "Pvalue", "plot_value", "shared_genes")]
}

# Only datasets with a recorded plottable value get a bar. Every other state is named
# in the plot title, so an unavailable cell is neither drawn as zero nor left unsaid.
explorer_comparison_plot <- function(cmp) {
  drawn <- !is.na(cmp$plot_value)
  y <- paste(cmp$code, cmp$label, sep = " | ")[drawn]
  hover <- paste0(project_html_escape(cmp$code), " ", project_html_escape(cmp$label), "<br>",
                  project_html_escape(cmp$state_label))[drawn]
  skipped <- cmp[!drawn, , drop = FALSE]
  title <- if (nrow(skipped)) {
    paste0("Not drawn: ", paste0(project_html_escape(skipped$code), " ",
      project_html_escape(skipped$label), " (", project_html_escape(sub("^\\S+ ", "", skipped$state_label)),
      ")", collapse = "; "))
  } else ""
  p <- plotly::plot_ly(x = cmp$plot_value[drawn], y = factor(y, levels = rev(unique(y))),
                       type = "bar", orientation = "h", text = hover, hoverinfo = "text",
                       marker = list(color = cmp$color[drawn], line = list(color = "#1e293b", width = 1)))
  plotly::layout(p, title = list(text = title, font = list(size = 12)),
                 xaxis = list(title = "-log10(value)"), yaxis = list(title = ""),
                 margin = list(l = 200), showlegend = FALSE)
}

# ---- display and export (REQ-005) ----------------------------------------------------

explorer_display_labels <- function(columns) {
  known <- c(Annot = "Term ID", Term = "Term", Annotated = "Annotated genes",
             Significant = "Significant genes", Pvalue = "P-value",
             Padj = "Adjusted p-value", GeneID = "Member genes")
  out <- ifelse(columns %in% names(known), known[columns], columns)
  names(out) <- columns
  out
}

# Shortest decimal text that parses back to the identical double (15, 16 or 17 digits).
explorer_exact_numbers <- function(x) {
  out <- rep(NA_character_, length(x))
  finite <- is.finite(x)
  for (digits in 15:17) {
    todo <- which(finite & is.na(out))
    if (!length(todo)) break
    text <- formatC(x[todo], digits = digits, format = "g")
    hit <- as.numeric(text) == x[todo]
    out[todo[hit]] <- text[hit]
  }
  out[is.nan(x)] <- "NaN"
  out[is.infinite(x) & x > 0] <- "Inf"
  out[is.infinite(x) & x < 0] <- "-Inf"
  out
}

# Copy of the stored table whose doubles are written at full round-trip precision.
# Names, row order, text and provider columns are unchanged.
explorer_exact_frame <- function(df) {
  for (i in seq_along(df)) {
    if (is.double(df[[i]])) df[[i]] <- explorer_exact_numbers(df[[i]])
  }
  df
}

explorer_write_exact <- function(df, file) {
  keep_unquoted <- which(vapply(df, is.double, logical(1)))
  frame <- explorer_exact_frame(df)
  utils::write.csv(frame, file, row.names = FALSE,
                   quote = setdiff(seq_along(frame), keep_unquoted))
  invisible(file)
}

# ---- summary and actions (REQ-001) ----------------------------------------------------

explorer_summary_facts <- function(df, label, id, context, run) {
  unknown <- "Not recorded"
  fact <- function(x) if (is.null(x) || length(x) != 1L || is.na(x) || !nzchar(x)) unknown else as.character(x)
  stat <- explorer_stat_columns(df)
  list(
    "Result" = fact(label),
    "Result ID" = fact(id),
    "Terms" = as.character(nrow(df)),
    "Species" = fact(context$species),
    "Key type" = fact(context$keytype),
    "Annotation" = fact(context$annotation_type),
    "Ontology" = fact(context$ontology),
    "P-value column" = if (is.na(stat$p)) "Not supplied" else "Present",
    "Adjusted p-value column" = if (is.na(stat$padj)) "Not supplied" else "Present",
    "Run" = fact(if (is.null(run)) NULL else run$run_id))
}

# Valid next actions for the shown result. None of them starts work: View and Create
# figure open the existing table and figure views, Cluster and Run again only navigate.
explorer_actions <- function(n_results, has_run) {
  have <- n_results > 0L
  none <- "Import or load enrichment results first"
  list(
    view = list(id = "ex_view", label = "View results", available = have, reason = none),
    figure = list(id = "ex_figure", label = "Create figure", available = have, reason = none),
    cluster = list(id = "ex_cluster_go", label = "Cluster these results", available = have, reason = none),
    rerun = list(id = "ex_rerun", label = "Run again", available = have && has_run,
                 reason = if (!have) none else
                   "No recorded run for this result; imported results cannot be run again"))
}

explorer_summary_ui <- function(facts, cue = NULL) {
  shiny::tags$section(class = "rs-workspace rs-workspace-card",
    shiny::tags$h4("Result summary"),
    if (!is.null(cue)) shiny::tags$p(cue),
    shiny::tags$dl(lapply(seq_along(facts), function(i) shiny::tagList(
      shiny::tags$dt(workspace_text(names(facts)[i])),
      shiny::tags$dd(workspace_text(facts[[i]], "fact", missing = TRUE))))))
}

# ---- selection panel, figures and links (REQ-002) -----------------------------------

# Text-only view of the selected row: term, ID, namespace, dataset and member genes.
explorer_selection_ui <- function(df, index, key, dataset_id, namespace) {
  cols <- workspace_term_columns(df)
  label <- as.character(df[[cols$label]][index])
  id <- as.character(df[[cols$id]][index])
  genes <- if ("GeneID" %in% names(df)) workspace_member_genes(df$GeneID[index]) else NULL
  shiny::tags$section(class = "rs-workspace rs-workspace-card",
    shiny::tags$h3("Selected term"),
    shiny::tags$dl(
      shiny::tags$dt("Term"), shiny::tags$dd(workspace_text(label, "label", missing = TRUE)),
      shiny::tags$dt("Term ID"), shiny::tags$dd(workspace_text(id, "id", missing = TRUE)),
      shiny::tags$dt("Member genes"),
      shiny::tags$dd(if (is.null(genes)) "Not supplied" else if (!length(genes)) "None listed" else
        workspace_text(paste(genes, collapse = ", ")))),
    shiny::tags$p("Highlighted in the table and in the figure."),
    shiny::tags$details(class = "rs-details",
      shiny::tags$summary("Details"),
      shiny::tags$dl(
        shiny::tags$dt("Annotation namespace"), shiny::tags$dd(workspace_text(namespace)),
        shiny::tags$dt("Result ID"), shiny::tags$dd(workspace_text(dataset_id)))))
}

# Figure of the strongest terms plus the selected one. The y-axis names each point
# "label [ID]" so identical labels with different IDs stay separate; hover text is
# escaped; the stable row key rides along as customdata. Drawing uses -log10 of the
# stored value; a value of zero or NA is left out, never replaced by a floor.
explorer_term_plot <- function(df, keys, selected_key = NULL, top = 25L,
                               source = "explorer", highlight = "#b45309") {
  cols <- workspace_term_columns(df)
  stat <- explorer_stat_columns(df)
  column <- if (!is.na(stat$padj)) stat$padj else stat$p
  if (is.na(cols$id) || is.na(column)) return(NULL)
  value <- as.numeric(df[[column]])
  ok <- which(!is.na(keys) & is.finite(value) & value > 0)
  chosen <- ok[order(value[ok], seq_along(ok))][seq_len(min(top, length(ok)))]
  if (!is.null(selected_key)) chosen <- union(chosen, intersect(which(keys == selected_key), ok))
  chosen <- chosen[order(value[chosen], chosen)]
  label <- as.character(df[[cols$label]])[chosen]
  id <- as.character(df[[cols$id]])[chosen]
  if (identical(cols$id, cols$label)) axis <- label else axis <- paste0(label, " [", id, "]")
  axis <- make.unique(ifelse(is.na(axis), "(no label)", axis), sep = " #")
  is_sel <- !is.null(selected_key) & keys[chosen] %in% selected_key
  hover <- paste0("Term: ", project_html_escape(label), "<br>ID: ", project_html_escape(id),
                  "<br>", column, ": ", format(value[chosen], digits = 3),
                  ifelse(is_sel, "<br>Selected", ""))
  p <- plotly::plot_ly(x = -log10(value[chosen]), y = factor(axis, levels = rev(axis)),
                       type = "scatter", mode = "markers", customdata = keys[chosen],
                       text = hover, hoverinfo = "text", source = source,
                       marker = list(color = ifelse(is_sel, highlight, "#0f6fc5"),
                                     size = ifelse(is_sel, 16, 9),
                                     symbol = ifelse(is_sel, "diamond", "circle"),
                                     line = list(color = "#1e293b", width = ifelse(is_sel, 3, 1))))
  p <- plotly::layout(p, xaxis = list(title = paste0("-log10(", column, ")")),
                      yaxis = list(title = ""), margin = list(l = 220), showlegend = FALSE)
  plotly::event_register(p, "plotly_click")
}

# A plot click is accepted only when its customdata is one of the visible row keys.
explorer_click_key <- function(event, keys) {
  if (!is.data.frame(event) || !"customdata" %in% names(event) || !nrow(event)) return(NULL)
  key <- as.character(unlist(event$customdata))[1]
  if (is.na(key) || !key %in% keys) NULL else key
}

# Clusters of a cluster result that contain a term, matched by term ID. A cluster
# result without term IDs cannot be linked and says so.
explorer_cluster_links <- function(detail, term_id) {
  if (!is.data.frame(detail) || !all(c("Cluster", "Annot") %in% names(detail))) {
    return(list(supported = FALSE, clusters = character(), genes = character(),
                reason = "This cluster result carries no term ID column, so a term cannot be linked to a cluster"))
  }
  rows <- which(as.character(detail$Annot) == term_id)
  clusters <- unique(as.character(detail$Cluster[rows]))
  members <- which(as.character(detail$Cluster) %in% clusters)
  gene_cols <- grep("^GeneID", names(detail), value = TRUE)
  genes <- workspace_member_genes(unlist(detail[members, gene_cols, drop = FALSE], use.names = FALSE))
  list(supported = TRUE, clusters = clusters, genes = genes, reason = NA_character_)
}

explorer_cluster_ui <- function(label, links) {
  text <- if (!links$supported) {
    links$reason
  } else if (!length(links$clusters)) {
    "This term is not in any cluster of this result."
  } else {
    paste0("In cluster ", paste(links$clusters, collapse = ", "), ". Cluster member genes: ",
           if (length(links$genes)) paste(links$genes, collapse = ", ") else "none listed", ".")
  }
  shiny::tags$li(shiny::tags$strong(workspace_text(label)), ": ", workspace_text(text))
}

explorer_comparison_ui <- function(cmp) {
  number <- function(x) if (is.na(x)) "" else format(x, digits = 3)
  shiny::tags$div(class = "rs-workspace rs-workspace-table-scroll", role = "region", tabindex = "0",
    `aria-label` = "Dataset comparison",
    shiny::tags$table(shiny::tags$caption("Selected term across datasets"),
      shiny::tags$thead(shiny::tags$tr(lapply(
        c("Dataset", "State", "Adjusted p-value", "P-value", "Shared member genes"),
        function(x) shiny::tags$th(scope = "col", x)))),
      shiny::tags$tbody(lapply(seq_len(nrow(cmp)), function(i) shiny::tags$tr(
        shiny::tags$td(workspace_dataset_cue(cmp$code[i], cmp$label[i], cmp$dataset_id[i],
                                             cmp$symbol[i])),
        shiny::tags$td(workspace_text(cmp$state_label[i]),
          if (!is.na(cmp$reason[i])) shiny::tags$small(shiny::tags$br(), workspace_text(cmp$reason[i]))),
        shiny::tags$td(number(cmp$Padj[i])), shiny::tags$td(number(cmp$Pvalue[i])),
        shiny::tags$td(if (is.na(cmp$shared_genes[i])) "" else workspace_text(cmp$shared_genes[i])))))))
}

# ---- UI -----------------------------------------------------------------------------

resultsExplorerUI <- function(ns) {
  shiny::tabPanel("Explorer", value = "Explorer",
    shinydashboard::box(title = "Result", width = NULL, status = "primary",
      shiny::selectInput(ns("ex_result"), "Enrichment result", choices = NULL, multiple = FALSE),
      shiny::uiOutput(ns("ex_summary")),
      shiny::uiOutput(ns("ex_actions"))),
    shinydashboard::box(title = "Terms", width = NULL, status = "info", solidHeader = TRUE,
      shiny::uiOutput(ns("ex_notice")),
      shiny::tags$p(id = ns("ex_table_help"),
        "Select a row to link it to the figure, the comparison and the cluster view. Values are shown to 3 significant digits; the downloads keep the stored values."),
      DT::DTOutput(ns("ex_table")),
      shiny::downloadButton(ns("ex_download_exact"), "Download exact values (CSV)"),
      shiny::downloadButton(ns("ex_download_safe"), "Download spreadsheet-safe copy (CSV)")),
    shinydashboard::box(title = "Selected term", width = NULL, status = "info", solidHeader = TRUE,
      shiny::uiOutput(ns("ex_selected"), `aria-live` = "off"),
      shiny::actionButton(ns("ex_clear"), "Clear selection")),
    shinydashboard::box(title = "Figure", width = NULL, status = "info", solidHeader = TRUE,
      shiny::uiOutput(ns("ex_plot_note")),
      plotly::plotlyOutput(ns("ex_plot"))),
    shinydashboard::box(title = "Compare datasets", width = NULL, status = "info", solidHeader = TRUE,
      shiny::selectInput(ns("ex_compare"), "Datasets to compare", choices = NULL, multiple = TRUE),
      shiny::uiOutput(ns("ex_compare_table")),
      plotly::plotlyOutput(ns("ex_compare_plot"), height = "260px")),
    shinydashboard::box(title = "Cluster link", width = NULL, status = "info", solidHeader = TRUE,
      shiny::uiOutput(ns("ex_cluster"))))
}

# ---- server -------------------------------------------------------------------------

# Runs inside rr_vis_tab_server's moduleServer (same input/output/session). Reactives are
# created in that module's domain. Returns the handles tests and sibling views use.
results_explorer_server <- function(input, output, session, u_rrnames, u_rrdfs, u_clusnames,
                                    u_cluslists, selection, top = 25L) {
  plot_source <- session$ns("ex_plot")

  labels <- shiny::reactive(u_rrnames$labels)
  run_for <- function(label) {
    records <- tryCatch(workspace_run_records(session$userData$workspace_jobs), error = function(e) list())
    project_run_for(records, "enrichment", label)
  }
  dataset_ids <- shiny::reactive({
    labs <- labels()
    ids <- vapply(labs, function(l) {
      df <- u_rrdfs[[l]]
      if (is.data.frame(df)) workspace_result_id(df) else NA_character_
    }, character(1))
    # Identical content under two names still needs two IDs; the repeat gets a suffix.
    ids[!is.na(ids)] <- make.unique(ids[!is.na(ids)], sep = "-")
    names(ids) <- labs
    ids
  })
  cues <- shiny::reactive({
    ids <- dataset_ids()
    explorer_dataset_cues(ids[!is.na(ids)])
  })

  shiny::observe({
    labs <- labels()
    keep <- shiny::isolate(input$ex_result)
    prev <- shiny::isolate(input$ex_compare)
    shiny::updateSelectInput(session, "ex_result", choices = labs,
      selected = if (!is.null(keep) && keep %in% labs) keep else if (length(labs)) labs[[1]])
    shiny::updateSelectInput(session, "ex_compare", choices = labs,
      selected = if (is.null(prev)) labs else intersect(prev, labs))
  })

  # The figures follow the result shown in the table: choosing a result sets the bar, dot and network
  # selectors (SPEC-WS-013 M8). They stay free to change inside the Figure settings.
  shiny::observeEvent(list(input$ex_result, labels()), {
    chosen <- input$ex_result
    labs <- labels()
    if (is.null(chosen) || !nzchar(chosen) || !chosen %in% labs) return()
    for (id in c("select_bar", "select_dot", "select_net", "select_table")) {
      shiny::updateSelectInput(session, id, choices = labs, selected = chosen)
    }
  })

  explorer_state <- shiny::reactive({
    label <- input$ex_result
    if (is.null(label) || !nzchar(label) || !label %in% labels()) return(NULL)
    df <- u_rrdfs[[label]]
    if (!is.data.frame(df)) return(NULL)
    run <- run_for(label)
    context <- workspace_result_context(df, settings = if (is.null(run)) NULL else run$settings)
    namespace <- workspace_context_namespace(context)
    id <- unname(dataset_ids()[label])
    columns <- workspace_term_columns(df)
    list(label = label, df = df, id = id, context = context, namespace = namespace,
         columns = columns, run = run,
         keys = if (is.na(columns$id)) NULL else workspace_row_keys(df, id, namespace))
  })

  # A selection that is not a row of the shown result is dropped; one that still is
  # (the same table after a re-render) is kept.
  shiny::observe({
    st <- explorer_state()
    key <- selection$key()
    if (!is.null(key) && (is.null(st) || !key %in% st$keys)) workspace_selection_clear(selection)
  })

  output$ex_summary <- shiny::renderUI({
    st <- explorer_state()
    if (is.null(st)) {
      return(shiny::tags$p("No enrichment result yet. Import enrichment results or load the demo results from Home."))
    }
    cue <- cues()
    cue <- cue[cue$id == st$id, , drop = FALSE]
    explorer_summary_ui(explorer_summary_facts(st$df, st$label, st$id, st$context, st$run),
      if (nrow(cue)) workspace_dataset_cue(cue$code, st$label, st$id, cue$symbol))
  })

  output$ex_actions <- shiny::renderUI({
    st <- explorer_state()
    acts <- explorer_actions(length(labels()), has_run = !is.null(st) && !is.null(st$run))
    ns <- session$ns(NULL)
    shiny::tags$div(class = "rs-workspace rs-workspace-actions",
      # The table and the figure are the page itself, so View results and Create figure have no place
      # in the bar; Cluster these results and Run again remain.
      lapply(acts[c("cluster", "rerun")], function(a) workspace_action(ns, a$id, a$label, a$available, a$reason)))
  })

  output$ex_notice <- shiny::renderUI({
    st <- explorer_state()
    if (is.null(st)) return(shiny::tags$p("Choose an enrichment result to see its terms."))
    if (!nrow(st$df)) return(shiny::tags$p("This result has no terms. Nothing was removed; check the filters or the source file."))
    if (is.null(st$keys)) {
      return(shiny::tags$p("This result has no Term or Annot column, so its rows cannot be selected or compared."))
    }
    NULL
  })

  output$ex_table <- DT::renderDT({
    st <- explorer_state()
    shiny::req(st)
    initial <- workspace_selection_index(st$keys, shiny::isolate(selection$key()))
    mode <- list(mode = "single", target = "row")
    if (length(initial)) mode$selected <- initial
    table <- DT::datatable(st$df, rownames = FALSE, filter = "top", escape = TRUE,
      colnames = unname(explorer_display_labels(names(st$df))),
      class = "display compact rs-display-table",
      selection = mode, options = list(pageLength = 10, scrollX = TRUE))
    # Numbers show three significant figures and unknown text cells an em-dash
    # (display only; the stored values and the exact-value export are untouched).
    doubles <- names(st$df)[vapply(st$df, is.double, logical(1))]
    if (length(doubles)) table <- DT::formatSignif(table, doubles, digits = 3)
    text_columns <- which(!vapply(st$df, is.double, logical(1))) - 1L
    if (length(text_columns)) {
      table$x$options$columnDefs <- c(
        table$x$options$columnDefs,
        list(list(targets = text_columns, render = DT::JS(workspace_display_js_unknown)))
      )
    }
    table
  }, server = TRUE)
  table_proxy <- DT::dataTableProxy("ex_table", session = session)

  # DT in server mode reports the index into the ORIGINAL table, so the key stays the
  # same source row whatever sort or filter the reader applied.
  shiny::observeEvent(input$ex_table_rows_selected, ignoreNULL = FALSE, {
    st <- explorer_state()
    if (is.null(st) || is.null(st$keys)) return()
    rows <- input$ex_table_rows_selected
    if (!length(rows)) return(workspace_selection_clear(selection))
    i <- as.integer(rows[[1]])
    if (is.na(i) || i < 1L || i > length(st$keys)) return()
    cols <- st$columns
    info <- list(id = as.character(st$df[[cols$id]][i]), label = as.character(st$df[[cols$label]][i]),
                 dataset = st$label)
    workspace_selection_set(selection, st$keys[i], st$keys, info)
  })

  shiny::observeEvent(selection$key(), ignoreNULL = FALSE, {
    st <- explorer_state()
    if (is.null(st)) return()
    idx <- workspace_selection_index(st$keys, selection$key())
    shown <- input$ex_table_rows_selected
    if (!identical(as.integer(shown), as.integer(idx))) {
      DT::selectRows(table_proxy, if (length(idx)) idx else NULL)
    }
  })

  shiny::observeEvent(input$ex_clear, workspace_selection_clear(selection))

  # Figure clicks are read from the plotly input of this plot only.
  figure_click <- shiny::reactive({
    raw <- session$rootScope()$input[[paste0("plotly_click-", plot_source)]]
    if (is.null(raw)) return(NULL)
    tryCatch(jsonlite::parse_json(raw, simplifyVector = TRUE), error = function(e) NULL)
  })
  shiny::observeEvent(figure_click(), {
    st <- explorer_state()
    if (is.null(st) || is.null(st$keys)) return()
    key <- explorer_click_key(figure_click(), st$keys)
    i <- workspace_selection_index(st$keys, key)
    if (is.null(key) || !length(i)) return()
    cols <- st$columns
    info <- list(id = as.character(st$df[[cols$id]][i]), label = as.character(st$df[[cols$label]][i]),
                 dataset = st$label)
    workspace_selection_set(selection, key, st$keys, info)
  })

  output$ex_selected <- shiny::renderUI({
    st <- explorer_state()
    idx <- if (is.null(st)) integer() else workspace_selection_index(st$keys, selection$key())
    if (!length(idx)) {
      return(shiny::tags$p("No term selected. Select a row in the table or a point in the figure."))
    }
    explorer_selection_ui(st$df, idx[[1]], selection$key(), st$id, st$namespace)
  })

  output$ex_plot_note <- shiny::renderUI({
    st <- explorer_state()
    if (is.null(st) || is.null(st$keys)) return(NULL)
    if (is.null(explorer_term_plot(st$df, st$keys, NULL, top = top))) {
      return(shiny::tags$p("This result has no p-value column, so no figure can be drawn from it."))
    }
    shiny::tags$p(sprintf("Strongest %d terms by adjusted p-value (or p-value when it is the only one), plus the selected term. Terms with a value of zero or no value are not drawn.", top))
  })
  output$ex_plot <- plotly::renderPlotly({
    st <- explorer_state()
    shiny::req(st, st$keys)
    p <- explorer_term_plot(st$df, st$keys, selection$key(), top = top, source = plot_source)
    shiny::req(p)
    p
  })

  explorer_comparison <- shiny::reactive({
    st <- explorer_state()
    key <- selection$key()
    if (is.null(st) || is.null(key)) return(NULL)
    idx <- workspace_selection_index(st$keys, key)
    if (!length(idx)) return(NULL)
    term_id <- as.character(st$df[[st$columns$id]][idx[[1]]])
    ids <- dataset_ids()
    chosen <- union(st$label, intersect(input$ex_compare, labels()))
    sets <- lapply(chosen, function(l) {
      df <- u_rrdfs[[l]]
      run <- run_for(l)
      list(label = l, df = df,
           context = workspace_result_context(df, settings = if (is.null(run)) NULL else run$settings),
           test_family = attr(df, "richstudio_test_family", exact = TRUE))
    })
    names(sets) <- unname(ids[chosen])
    explorer_term_comparison(sets, reference_id = st$id, term_id = term_id, cues = cues())
  })
  output$ex_compare_table <- shiny::renderUI({
    cmp <- explorer_comparison()
    if (is.null(cmp)) return(shiny::tags$p("Select a term to compare it across datasets."))
    explorer_comparison_ui(cmp)
  })
  output$ex_compare_plot <- plotly::renderPlotly({
    cmp <- explorer_comparison()
    shiny::req(cmp, nrow(cmp) > 0L)
    explorer_comparison_plot(cmp)
  })

  output$ex_cluster <- shiny::renderUI({
    info <- selection$info()
    if (is.null(info)) return(shiny::tags$p("Select a term to see which clusters contain it."))
    clus <- u_clusnames$labels
    if (!length(clus)) {
      return(shiny::tags$p("No cluster results yet. The term can still be explored, plotted and exported without clustering."))
    }
    shiny::tags$ul(lapply(clus, function(l) explorer_cluster_ui(l, explorer_cluster_links(u_cluslists[[l]], info$id))))
  })

  output$ex_download_exact <- shiny::downloadHandler(
    filename = function() {
      st <- explorer_state()
      shiny::req(st)
      paste0(sanitize_filename(st$label), "-exact-values.csv")
    },
    content = function(file) {
      st <- explorer_state()
      shiny::req(st)
      explorer_write_exact(st$df, file)
    })
  output$ex_download_safe <- shiny::downloadHandler(
    filename = function() {
      st <- explorer_state()
      shiny::req(st)
      paste0(sanitize_filename(st$label), "-spreadsheet-safe.csv")
    },
    content = function(file) {
      st <- explorer_state()
      shiny::req(st)
      project_export_csv(st$df, file)
    })

  # Adapters to the existing modules: they only navigate or preselect, never run work.
  open_view <- function(tab, selects) {
    st <- explorer_state()
    if (is.null(st)) return()
    for (id in selects) shiny::updateSelectInput(session, id, selected = st$label)
    shiny::updateRadioButtons(session, "plot_type", selected = tab)
  }
  shiny::observeEvent(input$ex_view, open_view("terms", "select_table"))
  shiny::observeEvent(input$ex_figure, open_view("bar", c("select_bar", "select_dot")))
  shiny::observeEvent(input$ex_cluster_go, workspace_navigate(session, "cluster_tab"))
  shiny::observeEvent(input$ex_rerun, {
    st <- explorer_state()
    if (!is.null(st) && !is.null(st$run)) workspace_navigate(session, "enrich_tab")
  })

  list(state = explorer_state, comparison = explorer_comparison, selection = selection)
}
