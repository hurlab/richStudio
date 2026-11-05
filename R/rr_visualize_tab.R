# ENRICH TAB CONTENTS

sample_rr_path <- function(name) {
  pkg_path <- system.file("extdata", name, package = "richStudio")
  if (pkg_path != "") {
    return(pkg_path)
  }
  app_dir <- getOption("richStudio.appdir", default = ".")
  fallback <- file.path(app_dir, "inst", "extdata", name)
  if (!file.exists(fallback)) {
    stop("Sample file not found: ", name)
  }
  fallback
}

# The "Load enrichment result" box and its input review. It sits on the Data step
# (SPEC-WS-013 M6) under this module's namespace, so every id is unchanged.
rr_load_box_ui <- function(ns) {
  tagList(
    tabBox(
      title = "Load enrichment result",
      width = NULL,
      tabPanel(
        "File upload",
        fileInput(
          ns("rr_files"),
          "Select files",
          multiple = TRUE,
          accept = c(".csv", ".tsv", ".xls", ".txt")
        ),
        helpText("Accepted formats: .txt, .csv, .tsv"),
        hr(),
        h4("Load demo"),
        p("Loads sample enrichment results: 'go1', 'go2', 'kegg1'"),
        actionButton(ns("rr_load"), "Load data")
      )
    ),
    review_result_intake_ui(ns)
  )
}

# A figure takes the width of its container and grows the left margin for long term labels, so the
# labels stay inside the plot (SPEC-WS-013 M8, AC-024).
rr_fit_plot <- function(p) {
  if (!inherits(p, "plotly")) {
    return(p)
  }
  p$width <- NULL
  p$x$layout$width <- NULL
  p$x$layout$autosize <- TRUE
  p <- plotly::layout(p, yaxis = list(automargin = TRUE))
  # Plotly caps an automatic margin at about half the width, so on a narrow figure the tick labels
  # that still do not fit are shortened with an ellipsis (static script; hover text is untouched).
  htmlwidgets::onRender(
    p,
    "function(el, x) {
      var axis = (x.layout && x.layout.yaxis) || {};
      var full = axis.ticktext;
      var vals = axis.tickvals;
      if (!full || !full.length) {
        // A categorical y axis: the categories are the labels.
        var y = x.data && x.data[0] && x.data[0].y;
        if (!y || !y.length || typeof y[0] !== 'string') return;
        var seen = {};
        full = y.filter(function(v) { if (seen[v]) return false; seen[v] = true; return true; });
        vals = full;
      }
      var limit = Math.max(14, Math.floor(0.4 * el.clientWidth / 6.2));
      var cut = full.map(function(t) {
        t = String(t);
        return t.length > limit ? t.slice(0, limit - 1) + '\u2026' : t;
      });
      var update = {'yaxis.ticktext': cut};
      if (vals) { update['yaxis.tickmode'] = 'array'; update['yaxis.tickvals'] = vals; }
      Plotly.relayout(el, update);
    }"
  )
}

rr_vis_tab_ui <- function(id, tabName) {
  ns <- NS(id)
  ui <- tabItem(
    tabName = tabName,
    fluidRow(
      column(
        width = 12,
        h2(class = "rs-sr-only", "Enrichment Result Visualization"),
        # Plot type is one segmented control; the term table is always the master (SPEC-WS-013 M8).
        tags$div(
          class = "rs-results-bar",
          tags$div(
            class = "rs-segmented",
            radioButtons(
              ns("plot_type"),
              label = NULL,
              choices = c(
                "Terms" = "terms",
                "Bar" = "bar",
                "Dot" = "dot",
                "Network" = "network",
                "Heatmap" = "heatmap"
              ),
              selected = "terms",
              inline = TRUE
            )
          )
        ),
        tags$details(
          class = "rs-figure-settings",
          tags$summary("Figure settings"),
          selectInput(ns("ex_result"), "Enrichment result", choices = NULL, multiple = FALSE),
            conditionalPanel(
              condition = "input.plot_type == 'bar'",
              ns = ns,
            div(
              class = "rs-figure-options",
              selectInput(
                ns("select_bar"),
                "Select enrichment result to view",
                choices = NULL,
                multiple = FALSE
              ),
              fluidRow(
                column(
                  4,
                  selectInput(
                    ns("bar_type"),
                    "Show rich score or p-value",
                    choices = c("Rich score" = "rich", "P-value" = "value"),
                    multiple = FALSE
                  )
                ),
                column(
                  4,
                  selectInput(
                    ns("bar_valtype"),
                    "P-value type",
                    choices = c("Padj", "Pvalue"),
                    multiple = FALSE
                  )
                ),
                column(
                  4,
                  numericInput(
                    ns("bar_pvalue"),
                    "P-value cutoff",
                    value = 0.05,
                    min = 0,
                    max = 1
                  )
                )
              ),
              sliderInput(
                ns("bar_nterms"),
                "Number of terms to display",
                value = 25,
                min = 1,
                max = 100
              )
            )
            ),
            conditionalPanel(
              condition = "input.plot_type == 'dot'",
              ns = ns,
            div(
              class = "rs-figure-options",
              selectInput(
                ns("select_dot"),
                "Select enrichment result to view",
                choices = NULL,
                multiple = FALSE
              ),
              fluidRow(
                column(
                  4,
                  selectInput(
                    ns("dot_valtype"),
                    "P-value type",
                    choices = c("Padj", "Pvalue"),
                    multiple = FALSE
                  )
                ),
                column(
                  4,
                  numericInput(
                    ns("dot_cutoff"),
                    "P-value cutoff",
                    value = 0.05,
                    min = 0,
                    max = 1
                  )
                )
              ),
              sliderInput(
                ns("dot_nterms"),
                "Number of terms to display",
                value = 25,
                min = 1,
                max = 100
              )
            )
            ),
            conditionalPanel(
              condition = "input.plot_type == 'network'",
              ns = ns,
            div(
              class = "rs-figure-options",
              selectInput(
                ns("select_net"),
                "Select enrichment result to view",
                choices = NULL,
                multiple = FALSE
              ),
              fluidRow(
                column(
                  4,
                  selectInput(
                    ns("net_valtype"),
                    "P-value type",
                    choices = c("Padj", "Pvalue"),
                    multiple = FALSE
                  )
                ),
                column(
                  4,
                  numericInput(
                    ns("net_cutoff"),
                    "P-value cutoff",
                    value = 0.05,
                    min = 0,
                    max = 1
                  )
                )
              ),
              sliderInput(
                ns("net_nterms"),
                "Number of terms to display",
                value = 25,
                min = 1,
                max = 100
              )
            )
            ),
            conditionalPanel(
              condition = "input.plot_type == 'heatmap'",
              ns = ns,
            tabBox(
              id = ns("edit_hmap_box"),
              width = NULL,
              # Top terms heatmap
              tabPanel(
                title = "Top terms",
                fluidRow(
                  column(
                    4,
                    selectInput(
                      ns("select_tophmap"),
                      "Select enrichment results",
                      choices = NULL,
                      multiple = TRUE
                    ),
                    selectInput(
                      ns("tophmap_valtype"),
                      "Select top terms by",
                      choices = c("Padj", "Pvalue")
                    ),
                    numericInput(
                      ns("tophmap_cutoff"),
                      "P-value cutoff",
                      value = 0.05,
                      min = 0,
                      max = 1
                    ),
                    sliderInput(
                      ns("tophmap_nterms"),
                      "Number of terms per result to display",
                      value = 10,
                      min = 1,
                      max = 100
                    )
                  ),
                  column(
                    8,
                    h3("Enrichment results in heatmap"),
                    p("Double click any cell to change its value."),
                    DT::DTOutput(ns("tophmap_table"))
                  )
                )
              ),
              # add enrichment result to heatmap
              tabPanel(
                title = "Custom terms",
                selectInput(
                  ns("select_cushmap"),
                  "Select enrichment result",
                  choices = NULL,
                  multiple = FALSE
                ),
                fluidRow(
                  column(
                    4,
                    selectInput(
                      ns("cushmap_valtype"),
                      "Select top terms by",
                      choices = c("Padj", "Pvalue")
                    )
                  ),
                  column(
                    4,
                    textInput(ns("cushmap_title"), "Title", value = NULL)
                  )
                ),
                DT::dataTableOutput(ns("cushmap_select_table")),
                actionButton(ns("cushmap_add_rr"), "Add terms")
              )
            ),
            # Delete result/terms from custom heatmap
            shinyjs::hidden(tags$div(
              id = ns("delete_custom_hmap_box"),
              box(
                title = "Delete",
                status = "info",
                width = NULL,
                solidHeader = TRUE,
                selectInput(
                  ns("rr_delete_select"),
                  "Select enrichment result",
                  choices = NULL,
                  multiple = FALSE
                ),
                selectInput(
                  ns("rr_term_delete_select"),
                  "Select terms to delete",
                  choices = NULL,
                  multiple = TRUE
                ),
                fluidRow(
                  column(
                    4,
                    actionButton(ns("delete_rr_terms"), "Delete selected terms")
                  ),
                  column(
                    4,
                    actionButton(ns("delete_rr"), "Delete entire result")
                  )
                )
              )
            ))
            )
        ),
        tags$div(
          class = "rs-master-detail",
          tags$div(
            class = "rs-figure",
            # On a narrow screen the figure sits in a closed disclosure above the term table (no id, so
            # it is not an input of the module); on a wide screen it is always shown.
            tags$label(
              class = "rs-figure-toggle",
              tags$input(type = "checkbox", class = "rs-fig-check"),
              "Figure"
            ),
            tags$div(
              class = "rs-figure-body",
            conditionalPanel(
              condition = "input.plot_type == 'terms'",
              ns = ns,
              plotly::plotlyOutput(ns("ex_plot"))
            ),
            conditionalPanel(
              condition = "input.plot_type == 'bar'",
              ns = ns,
            box(
              title = "Bar Plot",
              width = NULL,
              status = "info",
              solidHeader = TRUE,
              div(
                id = ns("bar_empty"),
                class = "empty-state",
                icon("chart-bar", class = "empty-icon"),
                h4("No data to display"),
                p("Load demo results from Home or import an enrichment result, then select it above.")
              ),
              jqui_resizable(plotlyOutput(ns("barplot")))
            )
            ),
            conditionalPanel(
              condition = "input.plot_type == 'dot'",
              ns = ns,
            box(
              title = "Dot Plot",
              width = NULL,
              status = "info",
              solidHeader = TRUE,
              div(
                id = ns("dot_empty"),
                class = "empty-state",
                icon("chart-line", class = "empty-icon"),
                h4("No data to display"),
                p("Load demo results from Home or import an enrichment result, then select it above.")
              ),
              jqui_resizable(plotlyOutput(ns("dotplot")))
            )
            ),
            conditionalPanel(
              condition = "input.plot_type == 'network'",
              ns = ns,
            box(
              title = "Network",
              width = NULL,
              status = "info",
              solidHeader = TRUE,
              div(
                id = ns("net_empty"),
                class = "empty-state",
                icon("project-diagram", class = "empty-icon"),
                h4("No data to display"),
                p("Load demo results from Home or import an enrichment result, then select it above.")
              ),
              jqui_resizable(plotOutput(ns("network")))
            )
            ),
            conditionalPanel(
              condition = "input.plot_type == 'heatmap'",
              ns = ns,
            # Shown by the server while the visible heatmap has nothing to draw.
            div(
              id = ns("hmap_empty"),
              class = "empty-state",
              icon("table-cells", class = "empty-icon"),
              h4("No data to display"),
              p("Choose enrichment results under Top terms, or add terms under Custom terms.")
            ),
            # The actual heatmap plots
            shinyjs::hidden(tags$div(
              id = ns("top_hmap_box"),
              box(
                title = "Top Terms Heatmap",
                status = "info",
                width = NULL,
                solidHeader = TRUE,
                jqui_resizable(plotlyOutput(ns("topterm_hmap")))
              )
            )),
            shinyjs::hidden(tags$div(
              id = ns("custom_hmap_box"),
              box(
                title = "Custom Terms Heatmap",
                status = "info",
                width = NULL,
                solidHeader = TRUE,
                jqui_resizable(plotlyOutput(ns("custom_hmap")))
              )
            ))
            )
            )
          ),
          tags$div(
            class = "rs-master",
            shiny::uiOutput(ns("ex_notice")),
            DT::DTOutput(ns("ex_table")),
            shiny::downloadButton(ns("ex_download_exact"), "Download exact values (CSV)"),
            shiny::downloadButton(ns("ex_download_safe"), "Download spreadsheet-safe copy (CSV)"),
            shiny::tags$p(
              id = ns("ex_table_help"),
              class = "help-block",
              "Select a row to link it to the figure, the comparison and the cluster view. Values are shown to 3 significant digits; the downloads keep the stored values."
            )
          ),
          tags$div(
            class = "rs-panel",
            shiny::uiOutput(ns("ex_plot_note")),
            uiOutput(ns("ex_actions")),
            tags$div(
              class = "rs-selected",
              shiny::uiOutput(ns("ex_selected"), `aria-live` = "off"),
              shiny::actionButton(ns("ex_clear"), "Clear selection")
            ),
            tags$div(
              class = "rs-compare",
              tags$h3("Compare datasets"),
              shiny::selectInput(ns("ex_compare"), "Datasets to compare", choices = NULL, multiple = TRUE),
              shiny::uiOutput(ns("ex_compare_table")),
              plotly::plotlyOutput(ns("ex_compare_plot"), height = "260px")
            ),
            tags$div(
              class = "rs-cluster-link",
              tags$h3("Cluster link"),
              shiny::uiOutput(ns("ex_cluster"))
            ),
            tags$details(
              class = "rs-details",
              tags$summary("Details"),
              shiny::uiOutput(ns("ex_summary")),
              # The complete table (every column, full table view) stays available here.
              tags$h4("Result table"),
              selectInput(
                ns("select_table"),
                "Select enrichment result to view",
                choices = NULL,
                multiple = FALSE
              ),
              DT::dataTableOutput(ns("rr_table"))
            )
          )
        ),
        shinyjs::hidden(tags$div(
          id = ns("rrlist_box"),
          box(
            title = "Available enrichment results",
            width = NULL,
            helpText(
              paste0(
                "You can rename any enrichment result by ",
                "double-clicking on the relevant cell."
              )
            ),
            DT::DTOutput(ns("rr_list_table")),
            actionButton(ns("remove_rr"), "Delete")
          )
        ))
      )
    )
  )
  htmltools::tagAppendAttributes(ui, class = "rs-compact-workflow")
}


rr_vis_tab_server <- function(
  id,
  u_degnames,
  u_degdfs,
  u_big_degdf,
  u_rrnames,
  u_rrdfs,
  u_big_rrdf,
  u_clusnames,
  u_clusdfs,
  u_cluslists,
  selection = NULL
) {
  moduleServer(id, function(input, output, session) {
    # Global reactive objects
    u_degnames_reactive <- reactive(u_degnames$labels)

    u_rrnames_reactive <- reactive(u_rrnames$labels)

    # Local reactive objects
    rr_custom_list_reactive <- reactiveValues(labels = NULL)
    rr_term_vec_reactive <- reactiveValues()
    tt_custom_data_reactive <- reactiveValues(df = data.frame())
    custom_data_reactive <- reactiveValues(df = data.frame())
    top_hmap_df_reactive <- reactiveValues(df = data.frame())

    tt_valueby_reactive <- reactiveVal()
    cus_valueby_reactive <- reactiveVal()

    # update select inputs based on # file inputs
    observe({
      updateSelectInput(
        session = getDefaultReactiveDomain(),
        "selected_degs",
        choices = u_degnames_reactive()
      )
      updateSelectInput(
        session = getDefaultReactiveDomain(),
        "select_bar",
        choices = u_rrnames_reactive()
      )
      updateSelectInput(
        session = getDefaultReactiveDomain(),
        "select_dot",
        choices = u_rrnames_reactive()
      )
      updateSelectInput(
        session = getDefaultReactiveDomain(),
        "select_net",
        choices = u_rrnames_reactive()
      )
      updateSelectInput(
        session = getDefaultReactiveDomain(),
        "select_table",
        choices = u_rrnames_reactive()
      )
      # The heatmap result selector defaults to an existing result (SPEC-WS-013 F3): the
      # selection the user already made is kept, an empty one takes the first result.
      kept <- intersect(
        shiny::isolate(input$select_tophmap),
        as.character(u_rrnames_reactive())
      )
      updateSelectInput(
        session = getDefaultReactiveDomain(),
        "select_tophmap",
        choices = u_rrnames_reactive(),
        selected = if (length(kept)) {
          kept
        } else {
          utils::head(as.character(u_rrnames_reactive()), 1L)
        }
      )
      updateSelectInput(
        session = getDefaultReactiveDomain(),
        "select_cushmap",
        choices = u_rrnames_reactive()
      )
      updateSelectInput(
        session = getDefaultReactiveDomain(),
        "rr_delete_select",
        choices = rr_custom_list_reactive$labels
      )
    })

    # <!----- SHINYJS LOGIC -----!>
    # Don't show list of rr if none uploaded
    observe({
      if (is.null(u_big_rrdf[["df"]])) {
        shinyjs::hide("rrlist_box")
      } else {
        shinyjs::show("rrlist_box")
      }
    })
    # Empty states follow the data: each view hides its message while the
    # selected result has rows and shows it otherwise.
    rr_has_rows <- function(label) {
      if (is.null(label) || length(label) != 1L || is.na(label) || !nzchar(label)) {
        return(FALSE)
      }
      df <- u_rrdfs[[label]]
      is.data.frame(df) && nrow(df) > 0L
    }
    rr_toggle_empty <- function(id, has_rows) {
      if (has_rows) shinyjs::hide(id) else shinyjs::show(id)
    }
    observe(rr_toggle_empty("table_empty", rr_has_rows(input$select_table)))
    observe(rr_toggle_empty("bar_empty", rr_has_rows(input$select_bar)))
    observe(rr_toggle_empty("dot_empty", rr_has_rows(input$select_dot)))
    observe(rr_toggle_empty("net_empty", rr_has_rows(input$select_net)))

    # Which heatmap box is shown: only the active sub-tab's box, and only when it
    # has a heatmap to draw; otherwise the one empty state.
    observe({
      top_mode <- !identical(input$edit_hmap_box, "Custom terms")
      has_plot <- if (top_mode) {
        inherits(plot_topterm_heatmap(), "plotly")
      } else {
        inherits(plot_custom_hmap(), "plotly")
      }
      rr_toggle_empty("hmap_empty", has_plot)
      if (top_mode && has_plot) shinyjs::show("top_hmap_box") else shinyjs::hide("top_hmap_box")
      if (!top_mode && has_plot) shinyjs::show("custom_hmap_box") else shinyjs::hide("custom_hmap_box")
      if (top_mode) shinyjs::hide("delete_custom_hmap_box") else shinyjs::show("delete_custom_hmap_box")
    })

    # <!----- UPLOAD LOGIC -----!>
    # Admission, validation and transactional publication (SPEC-WS-004).
    result_intake <- review_result_intake(
      input,
      output,
      session,
      u_rrnames,
      u_rrdfs,
      u_big_rrdf
    )

    # Unified result explorer (SPEC-WS-008). The selection is session-local display
    # state shared with the cluster views; the stored results are only read.
    if (is.null(selection)) {
      selection <- workspace_selection_state()
    }
    explorer <- results_explorer_server(
      input,
      output,
      session,
      u_rrnames = u_rrnames,
      u_rrdfs = u_rrdfs,
      u_clusnames = u_clusnames,
      u_cluslists = u_cluslists,
      selection = selection
    )
    explorer_state <- explorer$state
    explorer_comparison <- explorer$comparison

    observeEvent(input$rr_load, {
      # go1 and go2
      for (i in 1:2) {
        lab <- paste0("go", i)
        path <- sample_rr_path(paste0(lab, ".txt"))
        df <- read.delim(path)

        u_rrdfs[[lab]] <- df # Add datafrane to u_rrdfs
        u_rrnames$labels <- c(u_rrnames$labels, lab) # Add df name to u_rrnames
        u_big_rrdf[["df"]] <- add_file_rrdf(
          df = u_big_rrdf[["df"]],
          name = lab,
          file = TRUE
        ) # Add to big rr list
      }
      # kegg1
      lab <- "kegg1"
      path <- sample_rr_path(paste0(lab, ".txt"))
      df <- read.delim(path)

      u_rrdfs[[lab]] <- df # Add datafrane to u_rrdfs
      u_rrnames$labels <- c(u_rrnames$labels, lab) # Add df name to u_rrnames
      u_big_rrdf[["df"]] <- add_file_rrdf(
        df = u_big_rrdf[["df"]],
        name = lab,
        file = TRUE
      ) # Add to big rr list
    })

    # Reactively update uploaded file dataframe
    big_rrdf_to_table <- reactive({
      u_big_rrdf[["df"]]
    })
    # Output uploaded file table
    output$rr_list_table <- DT::renderDT(
      workspace_display_dt(big_rrdf_to_table(), editable = "cell")
    )
    # Table editing code
    observeEvent(input$rr_list_table_cell_edit, {
      info <- input$rr_list_table_cell_edit
      i <- info$row
      j <- info$col
      v <- info$value

      # Rename rr if changing a value in column 1 (name col)
      if (info$col == 1) {
        new_name <- v
        old_name <- u_big_rrdf[["df"]][i, j]
        if (nchar(new_name) > 0 && nchar(old_name) > 0) {
          # Copy data to new name
          u_rrdfs[[new_name]] <- u_rrdfs[[old_name]]
          # Remove old name from reactive values
          u_rrdfs[[old_name]] <- NULL
          # Update labels
          u_rrnames$labels <- setdiff(u_rrnames$labels, old_name)
          u_rrnames$labels <- c(u_rrnames$labels, new_name)
          review_move_record(result_intake$maps, old_name, new_name)
        }
      }
      # Fix anti-pattern: Modify data frame locally, then assign once
      updated_df <- u_big_rrdf[["df"]]
      updated_df[i, j] <- DT::coerceValue(v, updated_df[i, j])
      u_big_rrdf[["df"]] <- updated_df
    })

    # Remove rr from uploaded rich results
    observeEvent(input$remove_rr, {
      req(input$rr_list_table_rows_selected)

      # Also remove from rrdfs and rrnames
      for (rr in input$rr_list_table_rows_selected) {
        rr_to_rm <- u_big_rrdf[["df"]][rr, ]
        rr_to_rm <- rr_to_rm$name

        # Properly remove from reactive values using NULL assignment
        u_rrdfs[[rr_to_rm]] <- NULL
        u_rrnames$labels <- setdiff(u_rrnames$labels, rr_to_rm)
        result_intake$maps[[rr_to_rm]] <- NULL
      }

      # Remove selection from u_big_rrdf
      rm_vec <- u_big_rrdf[["df"]][input$rr_list_table_rows_selected, ]
      u_big_rrdf[["df"]] <- rm_file_rrdf(u_big_rrdf[["df"]], rm_vec)
    })

    # PLOTS

    get_rr_table <- reactive({
      req(input$select_table)
      df <- u_rrdfs[[input$select_table]]
      req(df)
      return(df)
    })
    output$rr_table <- DT::renderDT(
      workspace_display_dt(get_rr_table(), filter = "top")
    )

    get_rr_barplot <- reactive({
      req(input$select_bar)
      df <- u_rrdfs[[input$select_bar]]
      req(df, nrow(df) > 0)
      mybar <- rr_bar(
        x = df,
        top = input$bar_nterms,
        pvalue = input$bar_pvalue,
        value_type = input$bar_valtype,
        view = input$bar_type
      )
      return(mybar)
    })
    # Long term labels grow the left margin instead of running outside the plot (SPEC-WS-013 M8).
    output$barplot <- renderPlotly({
      rr_fit_plot(get_rr_barplot())
    })

    get_rr_dotplot <- reactive({
      req(input$select_dot)
      df <- u_rrdfs[[input$select_dot]]
      req(df, nrow(df) > 0)
      mydot <- rr_dot(
        x = df,
        top = input$dot_nterms,
        value_cutoff = input$dot_cutoff,
        value_type = input$dot_valtype
      )
      return(mydot)
    })
    output$dotplot <- renderPlotly({
      rr_fit_plot(get_rr_dotplot())
    })

    get_rr_network <- reactive({
      req(input$select_net)
      df <- u_rrdfs[[input$select_net]]
      req(df, nrow(df) > 0)
      mynet <- rr_network(rr = df, deg = NULL)
      return(mynet)
    })
    output$network <- renderPlot({
      get_rr_network()
    })

    # Enrichment Result Heatmaps
    # Top Terms
    observeEvent(
      {
        # Update heatmap whenever these change
        c(
          input$select_tophmap,
          input$tophmap_valtype,
          input$tophmap_cutoff,
          input$tophmap_nterms
        )
      },
      {
        req(input$edit_hmap_box == "Top terms")

        # Set value_by
        tt_valueby_reactive(input$tophmap_valtype)

        # Reset custom_data and the list of added genesets and terms
        tt_custom_data_reactive$df <- data.frame()
        top_hmap_df_reactive$df <- data.frame()

        if (!is.null(input$select_tophmap)) {
          for (i in seq_along(input$select_tophmap)) {
            gs <- u_rrdfs[[input$select_tophmap[i]]]
            gs_name <- input$select_tophmap[i]

            # add gs to list only if there exist values smaller than cutoff
            if (any(gs[, tt_valueby_reactive()] < input$tophmap_cutoff)) {
              # Add gs to custom_data_reactive
              if (input$tophmap_nterms != 0) {
                tt_custom_data_reactive$df <- add_topterm_gs(
                  custom_data = tt_custom_data_reactive$df,
                  gs = gs,
                  gs_name = gs_name,
                  value_type = tt_valueby_reactive(),
                  value_cutoff = input$tophmap_cutoff,
                  top_nterms = input$tophmap_nterms
                )
              }
              # Add gs to top_hmap_df_reactive
              top_hmap_df_reactive$df <- add_rr_tophmap(
                df = top_hmap_df_reactive$df,
                name = gs_name,
                value_type = tt_valueby_reactive(),
                value_cutoff = input$tophmap_cutoff,
                top_nterms = input$tophmap_nterms
              )
            }
          }
        }
      }
    )

    # Reactively update top_hmap_df
    top_hmap_to_table <- reactive({
      req(!is.null(top_hmap_df_reactive))
      return(top_hmap_df_reactive$df)
    })
    # Plot tabled list of gs in top terms hmap
    output$tophmap_table <- DT::renderDT(
      top_hmap_to_table(),
      editable = list(target = "cell", disable = list(columns = c(1:2)))
    )
    # Table editing code
    observeEvent(input$tophmap_table_cell_edit, {
      info <- input$tophmap_table_cell_edit
      i <- info$row
      j <- info$col
      v <- info$value

      # Fix anti-pattern: Modify data frame locally, then assign once
      updated_df <- top_hmap_df_reactive$df
      updated_df[i, j] <- DT::coerceValue(v, updated_df[i, j])
      top_hmap_df_reactive$df <- updated_df
      gs_name <- top_hmap_df_reactive$df[i, 1]
      top_nterms <- top_hmap_df_reactive$df[i, 4]

      if (top_nterms != 0) {
        tt_custom_data_reactive$df <- tryCatch(
          {
            add_topterm_gs(
              custom_data = tt_custom_data_reactive$df,
              gs = u_rrdfs[[gs_name]],
              gs_name = gs_name,
              value_type = tt_valueby_reactive(),
              value_cutoff = top_hmap_df_reactive$df[i, 3],
              top_nterms = top_hmap_df_reactive$df[i, 4]
            )
          },
          error = function(e) {
            showModal(modalDialog(
              title = "Input error",
              e$message,
              easyClose = TRUE
            ))
            tt_custom_data_reactive$df
          }
        )
      } else {
        showModal(modalDialog(
          title = "Input error",
          "Please input a non-zero number of top terms.",
          easyClose = TRUE
        ))
      }
    })

    # Custom terms heatmap
    # Reactively update custom term select table based on selection
    rr_to_table <- reactive({
      req(input$select_cushmap)
      df <- u_rrdfs[[input$select_cushmap]]
      return(df)
    })
    # Plot custom term select table
    output$cushmap_select_table <- DT::renderDT(
      rr_to_table(),
      filter = "top",
      options = list(
        pageLength = 5
      ),
    )

    # Add custom selected terms to heatmap
    observeEvent(input$cushmap_add_rr, {
      req(input$select_cushmap)
      req(input$cushmap_select_table_rows_selected)

      # Set value_by
      cus_valueby_reactive(input$cushmap_valtype)

      gs_name <- input$select_cushmap
      gs <- u_rrdfs[[gs_name]] # Store df of selected rr

      # Subset df with selected term rows
      term_df <- gs[input$cushmap_select_table_rows_selected, ]
      term_vec <- term_df$Term # get only Term column of subsetted df

      # Add gs to custom_data_reactive
      custom_data_reactive$df <- add_custom_gs(
        custom_data = custom_data_reactive$df,
        gs = gs,
        gs_name = gs_name,
        term_vec = term_vec
      )

      # Add only unique terms to rr_term_vec_reactive
      # If gs already added
      if (gs_name %in% names(rr_term_vec_reactive)) {
        unique_term_vec <- setdiff(term_vec, rr_term_vec_reactive[[gs_name]])
        rr_term_vec_reactive[[gs_name]] <- c(
          rr_term_vec_reactive[[gs_name]],
          unique_term_vec
        )

        # Update selectInput if gs is currently selected in delete box
        if (input$rr_delete_select == gs_name) {
          updateSelectInput(
            session = getDefaultReactiveDomain(),
            "rr_term_delete_select",
            choices = rr_term_vec_reactive[[gs_name]]
          )
        }
      } else {
        # No previous term_vec_reactive for that gs
        rr_term_vec_reactive[[gs_name]] <- term_vec
      }

      # Add gs name to rr_custom_list_reactive
      rr_custom_list_reactive$labels <- c(
        rr_custom_list_reactive$labels,
        input$select_cushmap
      )
    })

    # Update term delete select based on rr selected
    observeEvent(input$rr_delete_select, {
      req(input$rr_delete_select)
      if (!is.null(rr_term_vec_reactive)) {
        updateSelectInput(
          session = getDefaultReactiveDomain(),
          "rr_term_delete_select",
          choices = rr_term_vec_reactive[[input$rr_delete_select]]
        )
      }
    })

    # Remove selected terms from heatmap
    observeEvent(input$delete_rr_terms, {
      req(input$rr_term_delete_select)
      req(input$rr_delete_select)

      custom_data_reactive$df <- remove_gs(
        custom_data = custom_data_reactive$df,
        gs_name = input$rr_delete_select,
        term_vec = input$rr_term_delete_select
      )

      # Remove terms from rr_term_vec_reactive
      prev_terms <- rr_term_vec_reactive[[input$rr_delete_select]]
      rr_term_vec_reactive[[input$rr_delete_select]] <- prev_terms[
        !(prev_terms %in% input$rr_term_delete_select)
      ]

      # Reflect new changes
      updateSelectInput(
        session = getDefaultReactiveDomain(),
        "rr_term_delete_select",
        choices = rr_term_vec_reactive[[input$rr_delete_select]]
      )
    })

    # Delete entire result from heatmap
    observeEvent(input$delete_rr, {
      req(input$rr_delete_select)
      gs_name <- input$rr_delete_select
      # Terms selected for this result; shared terms survive via other results
      selected_terms <- as.character(rr_term_vec_reactive[[gs_name]])
      custom_data_reactive$df <- remove_gs(
        custom_data = custom_data_reactive$df,
        gs_name = gs_name,
        term_vec = input$rr_term_delete_select,
        delete_all = selected_terms,
        gs_cols = colnames(u_rrdfs[[gs_name]])
      )
      rr_term_vec_reactive[[gs_name]] <- character()
      # Remove result name from list
      rr_custom_list_reactive$labels <- setdiff(
        rr_custom_list_reactive$labels,
        gs_name
      )
    })

    # Reactively update whenever valtype changes
    observeEvent(input$cushmap_valtype, {
      cus_valueby_reactive(input$cushmap_valtype)
    })

    # Plot enrichment result heatmaps
    plot_topterm_heatmap <- reactive({
      if (nrow(tt_custom_data_reactive$df) != 0) {
        hmap <- custom_hmap(
          custom_data = tt_custom_data_reactive$df,
          value_type = tt_valueby_reactive()
        )
        return(hmap)
      }
    })
    output$topterm_hmap <- renderPlotly({
      rr_fit_plot(plot_topterm_heatmap())
    })

    plot_custom_hmap <- reactive({
      if (nrow(custom_data_reactive$df) != 0) {
        hmap <- custom_hmap(
          custom_data = custom_data_reactive$df,
          value_type = cus_valueby_reactive()
        )
        return(hmap)
      }
    })
    output$custom_hmap <- renderPlotly({
      rr_fit_plot(plot_custom_hmap())
    })
  })
}
