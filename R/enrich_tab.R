# The "Upload DEG sets" box. It sits on the Data step (SPEC-WS-013 M6) under this
# module's namespace, so every id is unchanged.
enrich_upload_box_ui <- function(ns) {
  tabBox(
    title = span(icon("upload"), "Upload DEG sets"),
    id = "upload_box",
    width = NULL,
    tabPanel(
      "File upload",
      fileInput(
        ns("deg_files"),
        "Select files",
        multiple = TRUE,
        accept = c(".csv", ".tsv", ".xls", ".xlsx", ".txt")
      ),
      helpText("Accepted formats: .txt, .csv, .tsv, .xls, .xlsx"),
      textOutput(ns("deg_upload_status")),
      hr(),
      h4("Load demo"),
      p(
        paste0(
          "Loads sample DEG sets: 'deg_mouse1', ",
          "'deg_mouse2', 'deg_mouse3'"
        )
      ),
      actionButton(ns("deg_load"), "Load data")
    ),
    tabPanel(
      "Text input",
      helpText(
        "Separate genes with spaces, new lines, commas or semicolons"
      ),
      textAreaInput(
        ns("deg_text"),
        "Text Input",
        placeholder = paste0(
          "Paste list of significant genes or ",
          "dataframe-like object"
        )
      ),
      textInput(
        ns("degtext_name"),
        "Name",
        placeholder = "Set name for pasted DEG set"
      ),
      fluidRow(
        div(
          style = "display:inline-block; float:left",
          column(3, actionButton(ns("upload_degtext"), "Upload"))
        ),
        div(
          style = "display:inline-block; float:left",
          column(3, actionButton(ns("degtext_load"), "Load demo"))
        )
      )
    )
  )
}

# Plain-language species default (SPEC-WS-013 F6, OD-5): the species recorded with the results made
# from the selected gene lists, else the species the user chose earlier in the session, else the
# existing default, marked as a default. No species is inferred from gene identifiers.
enrich_species_default <- function(recorded = character(), chosen = NULL) {
  recorded <- unique(as.character(recorded))
  recorded <- recorded[!is.na(recorded) & !recorded %in% c("", "?", "NULL", "NA")]
  if (length(recorded) == 1L) {
    return(list(value = recorded, source = "recorded"))
  }
  chosen <- as.character(chosen)
  if (length(chosen) == 1L && !is.na(chosen) && nzchar(chosen)) {
    return(list(value = chosen, source = "chosen"))
  }
  list(value = "human", source = "default")
}

enrich_species_note <- function(source) {
  switch(
    source,
    recorded = "recorded with the gene lists",
    chosen = "your last choice",
    "default"
  )
}

# The settings in one plain sentence list; `s` holds the effective species (value and source),
# annotation, ontology, gene ID type and cutoff.
enrich_settings_summary <- function(s) {
  cutoff <- if (is.null(s$cutoff) || is.na(s$cutoff)) 0.05 else s$cutoff
  paste0(
    "Species: ",
    s$species$value,
    " (",
    enrich_species_note(s$species$source),
    "). Annotation: ",
    s$annotation,
    ". Ontology: ",
    s$ontology,
    ". Gene ID type: ",
    s$keytype,
    ". Cutoff: ",
    format(cutoff),
    "."
  )
}

enrich_tab_ui <- function(id, tabName, upload = TRUE) {
  ns <- NS(id)
  htmltools::tagAppendAttributes(
    tabItem(
      tabName = tabName,
      shinyjs::useShinyjs(),
      fluidRow(
        if (upload) {
          column(width = 4, enrich_upload_box_ui(ns))
        },
        column(
          width = if (upload) 8 else 12,
          # The Run control and a one-line summary stay at the top of the column while scrolling.
          tags$div(
            class = "rs-run-bar",
            actionButton(
              ns("enrich_deg"),
              "Run Enrichment",
              icon = icon("play"),
              class = "btn-action-hero"
            ),
            tags$div(class = "rs-run-bar-text", uiOutput(ns("run_summary")))
          ),
          tags$div(
            class = "rs-enrich-part",
            `data-part` = "genes",
            h3("Gene lists"),
            selectInput(
              ns("degs_to_enrich"),
              "Select DEG sets to enrich",
              choices = NULL,
              multiple = TRUE
            ),
            helpText("Click a row to look at that list or result."),
            DT::DTOutput(ns("files_table")),
            uiOutput(ns("plain_preview"))
          ),
          tags$div(
            class = "rs-enrich-part",
            `data-part` = "settings",
            h3("Settings"),
            uiOutput(ns("settings_summary")),
            tags$details(
              class = "rs-adjust",
              tags$summary("Adjust"),
            tags$div(
              class = "rs-compact-fields",
              selectInput(
                ns("anntype_select"),
                "Select annotation source",
                c("GO", "KEGG", "Reactome")
              ),
              selectInput(
                ns("keytype_select"),
                "Select gene ID type",
                c(
                  "SYMBOL",
                  "ENSEMBL",
                  "ENTREZID",
                  "REFSEQ",
                  "UNIPROT",
                  "GENENAME",
                  "ACCNUM",
                  "ALIAS",
                  "ENSEMBLPROT",
                  "ENSEMBLTRANS",
                  "ENZYME",
                  "EVIDENCE",
                  "EVIDENCEALL",
                  "FLYBASE",
                  "FLYBASECG",
                  "FLYBASEPROT",
                  "GO",
                  "GOALL",
                  "MAP",
                  "ONTOLOGY",
                  "ONTOLOGYALL",
                  "PATH",
                  "PMID",
                  "UNIGENE"
                ),
                selected = "SYMBOL"
              ),
              selectInput(
                ns("ont_select"),
                "Select ontology",
                c("BP", "MF", "CC")
              ),
              selectInput(
                ns("species_select"),
                "Select species",
                annotation_species_choices(c(
                  "human",
                  "mouse",
                  "rat",
                  "zebrafish",
                  "fly",
                  "celegans",
                  "yeast",
                  "chicken",
                  "bovine",
                  "pig",
                  "canine",
                  "xenopus",
                  "rhesus",
                  "arabidopsis",
                  "anopheles",
                  "ecoli",
                  "malaria",
                  "chipm"
                )),
                selected = "human"
              )
            ),
              uiOutput(ns("background_ui")),
              uiOutput(ns("background_review")),
              numericInput(
                ns("deg_filter_cutoff"),
                paste0(
                  "Default cutoff (used for gene lists without a ",
                  "committed revision)"
                ),
                value = NULL
              )
            )
          ),
          tags$div(
            class = "rs-enrich-part",
            `data-part` = "review",
            h3("Review and run"),
            uiOutput(ns("review_plain")),
            uiOutput(ns("review_messages")),
            tags$details(
              class = "rs-advanced",
              tags$summary("Advanced: technical review and stored data"),
              h4("Review before Run"),
              tags$div(class = "rs-compact-review", uiOutput(ns("review_card"))),
              h4("Preprocess data"),
              selectInput(
                ns("deg_table_select"),
                "Select DEG set",
                choices = NULL
              ),
              tags$div(
                class = "review-preview",
                h4("Preview \u2014 not committed"),
                fluidRow(
                  column(
                    6,
                    selectInput(
                      ns("review_gene_col"),
                      "Gene column",
                      choices = c("Default (GeneID header)" = "__default__")
                    )
                  ),
                  column(
                    6,
                    selectInput(
                      ns("review_p_col"),
                      "P-value column",
                      choices = c(
                        "Default (current rule)" = "__default__",
                        "None \u2014 all rows" = "__none__"
                      )
                    )
                  )
                ),
                fluidRow(
                  column(
                    6,
                    selectInput(
                      ns("review_p_role"),
                      "P-value role",
                      choices = c("Adjusted" = "adjusted", "Raw" = "raw")
                    )
                  ),
                  column(
                    6,
                    numericInput(
                      ns("review_cutoff"),
                      "Preview cutoff",
                      value = 0.05,
                      min = 0,
                      max = 1,
                      step = 0.01
                    )
                  )
                ),
                uiOutput(ns("review_preview_ui")),
                actionButton(ns("review_commit"), "Use these settings"),
                helpText(
                  "Use these settings records the preview as a committed input revision (Commit input revision)."
                )
              ),
              br(),
              h4("Stored rows"),
              DT::dataTableOutput(ns("deg_table")),
              br(),
              hr(),
              h4("Export data"),
              selectInput(
                ns("deg_export_type"),
                "Export as",
                choices = c(".txt", ".csv", ".tsv")
              ),
              downloadButton(ns("download_deg"), "Download"),
              hr(),
              h4("Enrichment results"),
              fluidRow(
                column(
                  4,
                  selectInput(
                    ns("rr_table_select"),
                    "Select enrichment result",
                    choices = NULL
                  ),
                ),
                column(
                  4,
                  selectInput(
                    ns("rr_export_type"),
                    "Export as",
                    choices = c(".txt", ".csv", ".tsv")
                  )
                )
              ),
              downloadButton(ns("download_rr"), "Download"),
              br(),
              br(),
              br(),
              DT::dataTableOutput(ns("rr_table")),
          shinyjs::hidden(tags$div(
            id = ns("list_box"),
            tabBox(
              title = "Uploaded files",
              width = NULL,
              tabPanel(
                "DEG sets",
                tags$div(
                  id = ns("deglist_box"),
                  div(
                    style = "display:inline-block; float:left",
                    helpText("Double-click on any cell to change its value.")
                  ),
                  div(
                    style = "display:inline-block; float:right",
                    shinyWidgets::actionBttn(
                      ns("deglist_help"),
                      label = NULL,
                      style = "material-circle",
                      status = "primary",
                      icon = icon("info"),
                      size = "xs"
                    )
                  ),
                  br(),
                  br(),
                  DT::DTOutput(ns("deg_list_table")),
                  actionButton(ns("remove_deg"), "Delete")
                )
              ),
              tabPanel(
                "Enrichment Results",
                tags$div(
                  id = ns("rrlist_box"),
                  div(
                    style = "display:inline-block; float:left",
                    helpText("Double-click on any cell to change its value.")
                  ),
                  div(
                    style = "display:inline-block; float:right",
                    shinyWidgets::actionBttn(
                      ns("rrlist_help"),
                      label = NULL,
                      style = "material-circle",
                      status = "primary",
                      icon = icon("info"),
                      size = "xs"
                    )
                  ),
                  br(),
                  br(),
                  DT::DTOutput(ns("rr_list_table")),
                  actionButton(ns("remove_rr"), "Delete")
                )
              )
            )
          )),

            )
          )
        )
      )
    ),
    class = "rs-compact-workflow"
  )
}


enrich_tab_server <- function(
  id,
  u_degnames,
  u_degdfs,
  u_big_degdf,
  u_rrnames,
  u_rrdfs,
  u_big_rrdf,
  enrichment_runner = run_enrichment_jobs,
  annotation_builder = richstudio_build_annotation
) {
  moduleServer(id, function(input, output, session) {
    # Session job registry (SPEC-WS-006), shared through session$userData.
    jobs <- workspace_jobs_for(session)

    # Create reactive objs to make accessible in other modules
    u_degnames_reactive <- reactive(u_degnames$labels)
    u_rrnames_reactive <- reactive(u_rrnames$labels)

    # Create reactive to store dataframe of uploaded deg/rr

    # Tab-local reactive objects
    deg_colnames_reactive <- shiny::reactiveVal(NULL)
    # Committed input revisions keyed by gene-list name; preview changes never
    # touch them.
    review_revisions <- shiny::reactiveValues()
    review_messages <- shiny::reactiveVal(character())

    review_report <- function(messages) {
      review_messages(messages)
      showNotification(paste(messages, collapse = "\n"), type = "error")
    }
    review_settings <- reactive(list(
      species = input$species_select,
      anntype = input$anntype_select,
      keytype = input$keytype_select,
      ontology = input$ont_select
    ))
    review_gene_header <- function(name) {
      big <- u_big_degdf[["df"]]
      if (
        !is.data.frame(big) || !all(c("name", "GeneID_header") %in% names(big))
      ) {
        return(NULL)
      }
      header <- big[big$name %in% name, "GeneID_header"]
      if (length(header)) as.character(header[[1]]) else NULL
    }

    # Update select inputs based on # file inputs
    observe({
      updateSelectInput(
        session = shiny::getDefaultReactiveDomain(),
        "deg_table_select",
        choices = u_degnames_reactive()
      )
      updateSelectInput(
        session = shiny::getDefaultReactiveDomain(),
        "degs_to_enrich",
        choices = u_degnames_reactive()
      )
      updateSelectInput(
        session = shiny::getDefaultReactiveDomain(),
        "rr_table_select",
        choices = u_rrnames_reactive()
      )
    })

    # Preview selectors take their choices from the selected list's columns;
    # recognized p-value names come first, others need the user's confirmation.
    observe({
      columns <- as.character(deg_colnames_reactive())
      recognized <- tolower(c(
        "padj",
        "pvalue",
        expanded_col_dictionary$Pvalue,
        expanded_col_dictionary$Padj
      ))
      known <- columns[tolower(columns) %in% recognized]
      other <- setdiff(columns, known)
      updateSelectInput(
        session,
        "review_gene_col",
        choices = c(
          "Default (GeneID header)" = "__default__",
          stats::setNames(columns, columns)
        )
      )
      updateSelectInput(
        session,
        "review_p_col",
        choices = c(
          "Default (current rule)" = "__default__",
          review_column_choices(known, other),
          "None \u2014 all rows" = "__none__"
        )
      )
    })

    observe({
      # Show/hide entire box
      if (is.null(u_big_degdf[["df"]]) && is.null(u_big_rrdf[["df"]])) {
        shinyjs::hide("list_box")
      } else if (
        !is.null(u_big_degdf[["df"]]) || !is.null(u_big_rrdf[["df"]])
      ) {
        shinyjs::show("list_box")
        # Show/hide delete deg button
        if (is.null(u_big_degdf[["df"]])) {
          shinyjs::hide("deglist_box")
        } else if (!is.null(u_big_degdf[["df"]])) {
          shinyjs::show("deglist_box")
        }
        # Show/hide delete rr button
        if (is.null(u_big_rrdf[["df"]])) {
          shinyjs::hide("rrlist_box")
        } else if (!is.null(u_big_rrdf[["df"]])) {
          shinyjs::show("rrlist_box")
        }
      }
    })

    observeEvent(input$deglist_help, {
      shiny::showModal(shiny::modalDialog(
        title = "Help",
        paste0(
          "'Gene ID column' shows the column that holds the gene identifiers, ",
          "and 'Has expression data' shows whether expression values are included."
        )
      ))
    })
    observeEvent(input$rrlist_help, {
      shiny::showModal(shiny::modalDialog(
        title = "Help",
        paste0(
          "If annotation, ontology, gene ID type or species is shown as a dash, ",
          "you can update it by double-clicking the cell. If you started from an ",
          "enrichment output but want to link the matching differential expression ",
          "data to it, set 'Source gene list' to the name of a gene list uploaded ",
          "to richStudio."
        )
      ))
    })

    # Gene lists admitted but without a recognized gene-identifier column wait
    # here (file name and table) until the user picks the column or cancels;
    # nothing is stored for them meanwhile.
    deg_pending <- shiny::reactiveVal(list())
    deg_upload_status <- shiny::reactiveVal("")
    output$deg_upload_status <- shiny::renderText(deg_upload_status())

    deg_add_list <- function(lab, df) {
      meta <- add_file_degdf(u_big_degdf[["df"]], lab, df)
      u_degdfs[[lab]] <- df # set u_degdfs
      # set u_degnames
      u_degnames$labels <- c(u_degnames$labels, lab)
      u_big_degdf[["df"]] <- meta
      review_revisions[[lab]] <- NULL
      column <- as.character(meta[meta$name %in% lab, "GeneID_header"][[1L]])
      sprintf("Added %s: gene column %s, %d rows.", lab, column, nrow(df))
    }

    deg_prompt_next <- function() {
      pending <- deg_pending()
      if (!length(pending)) {
        return(invisible(NULL))
      }
      item <- pending[[1L]]
      shiny::showModal(shiny::modalDialog(
        title = "Choose the gene column",
        shiny::p(sprintf(
          paste0(
            "No gene identifier column was recognized in %s (%d rows). ",
            "Columns found: %s."
          ),
          item$lab,
          item$rows,
          paste(item$columns, collapse = ", ")
        )),
        shiny::selectInput(
          session$ns("deg_pick_col"),
          "Which column holds the gene identifiers?",
          choices = item$columns
        ),
        footer = shiny::tagList(
          shiny::actionButton(session$ns("deg_pick_cancel"), "Cancel"),
          shiny::actionButton(
            session$ns("deg_pick_ok"),
            "Use this column",
            class = "btn-primary"
          )
        ),
        easyClose = FALSE
      ))
    }

    # When deg upload button clicked
    observeEvent(input$deg_files, {
      problems <- character()
      confirmations <- character()
      for (i in seq_along(input$deg_files$name)) {
        lab <- input$deg_files$name[i]
        # An unexpected error becomes a message for this file; stores stay
        # unchanged.
        problems <- c(
          problems,
          review_contain(
            {
              if (lab %in% u_degnames$labels) {
                paste("A gene list named", lab, "already exists")
              } else {
                # Admission bounds the file before it is parsed; nothing is
                # stored on rejection.
                admitted <- review_admit_file(
                  input$deg_files$datapath[i],
                  lab,
                  "deg"
                )
                if (!isTRUE(admitted$ok)) {
                  paste0(lab, ": ", admitted$message)
                } else {
                  df <- admitted$df
                  detected <- deg_detect_gene_column(df)
                  if (is.na(detected$column)) {
                    pending <- deg_pending()
                    pending[[length(pending) + 1L]] <- list(
                      lab = lab,
                      df = df,
                      columns = detected$columns,
                      rows = detected$rows
                    )
                    deg_pending(pending)
                    confirmations <- c(
                      confirmations,
                      sprintf(
                        paste0(
                          "%s was not added yet: no gene identifier column ",
                          "was recognized among its columns (%s; %d rows)."
                        ),
                        lab,
                        paste(detected$columns, collapse = ", "),
                        detected$rows
                      )
                    )
                  } else {
                    confirmations <- c(confirmations, deg_add_list(lab, df))
                  }
                  NULL
                }
              }
            },
            function() paste0(lab, ": the file could not be processed")
          )
        )
      }
      deg_upload_status(paste(confirmations, collapse = "\n"))
      if (length(problems)) {
        review_report(problems)
      } else {
        review_messages(character())
      }
      deg_prompt_next()
    })

    observeEvent(input$deg_pick_ok, {
      pending <- deg_pending()
      shiny::removeModal()
      if (!length(pending)) {
        return()
      }
      item <- pending[[1L]]
      column <- input$deg_pick_col
      deg_pending(pending[-1L])
      if (is.null(column) || !column %in% item$columns) {
        deg_upload_status(paste0(item$lab, " was not added: no column chosen."))
      } else {
        review_contain(
          deg_upload_status(deg_add_list(
            item$lab,
            deg_with_gene_column(item$df, column)
          )),
          function() {
            review_report(paste0(item$lab, ": the file could not be processed"))
          }
        )
      }
      deg_prompt_next()
    })

    observeEvent(input$deg_pick_cancel, {
      pending <- deg_pending()
      shiny::removeModal()
      if (!length(pending)) {
        return()
      }
      deg_upload_status(paste0(pending[[1L]]$lab, " was not added."))
      deg_pending(pending[-1L])
      deg_prompt_next()
    })

    # Load demo DEG data
    observeEvent(input$deg_load, {
      for (i in 1:3) {
        lab <- paste0("deg_mouse", i)
        path <- sample_deg_path(paste0(lab, ".txt"))
        df <- read.delim(path)

        if (lab %in% u_degnames$labels) {
          workspace_jobs_touch(jobs, "deg", lab)
        }
        u_degdfs[[lab]] <- df # set u_degdfs
        u_degnames$labels <- c(u_degnames$labels, lab) # set u_degnames
        u_big_degdf[["df"]] <- add_file_degdf(u_big_degdf[["df"]], lab, df)
      }
    })

    # Parse pasted text inputs
    observeEvent(input$upload_degtext, {
      req(input$deg_text, input$degtext_name)
      lab <- input$degtext_name
      review_contain(
        {
          if (lab %in% u_degnames$labels) {
            review_report(paste("A gene list named", lab, "already exists"))
            return(NULL)
          }
          # Tokens split on whitespace, commas and semicolons only.
          admitted <- review_admit_text(input$deg_text, lab)
          if (!isTRUE(admitted$ok)) {
            review_report(paste0(lab, ": ", admitted$message))
            return(NULL)
          }
          df <- data.frame(GeneID = admitted$tokens)
          meta <- add_file_degdf(u_big_degdf[["df"]], lab, df)

          u_degdfs[[lab]] <- df # set u_degdfs
          u_degnames$labels <- c(u_degnames$labels, lab)
          u_big_degdf[["df"]] <- meta
          review_revisions[[lab]] <- NULL
          review_messages(character())
        },
        function() {
          review_report(paste0(lab, ": the pasted text could not be processed"))
        }
      )
    })

    # Reactively update uploaded file dataframe
    big_degdf_to_table <- reactive({
      u_big_degdf[["df"]]
    })
    # Output uploaded file table
    output$deg_list_table <- DT::renderDT(
      workspace_display_dt(
        big_degdf_to_table(),
        editable = list(target = "cell", disable = list(columns = c(3)))
      )
    )
    # Table editing code (ref: https://github.com/rstudio/DT/pull/480)
    observeEvent(input$deg_list_table_cell_edit, {
      info <- input$deg_list_table_cell_edit
      i <- info$row
      j <- info$col
      v <- info$value

      # Rename deg if changing a value in column 1 (name col)
      if (info$col == 1) {
        new_name <- v
        old_name <- u_big_degdf[["df"]][i, j]
        if (nchar(new_name) > 0 && nchar(old_name) > 0) {
          workspace_jobs_touch(jobs, "deg", old_name)
          # Copy data to new name
          u_degdfs[[new_name]] <- u_degdfs[[old_name]]
          # Remove old name from reactive values
          u_degdfs[[old_name]] <- NULL
          # Update labels
          u_degnames$labels <- setdiff(u_degnames$labels, old_name)
          u_degnames$labels <- c(u_degnames$labels, new_name)
          # The committed revision follows the gene list
          review_move_record(review_revisions, old_name, new_name)
        }
      }

      # Fix anti-pattern: Modify data frame locally, then assign once
      updated_df <- u_big_degdf[["df"]]
      updated_df[i, j] <- DT::coerceValue(v, updated_df[i, j])
      u_big_degdf[["df"]] <- updated_df
    })

    # Remove deg from uploaded degs
    observeEvent(input$remove_deg, {
      req(input$deg_list_table_rows_selected)

      # Also remove from degdfs and degnames
      for (deg in input$deg_list_table_rows_selected) {
        deg_to_rm <- u_big_degdf[["df"]][deg, ]
        deg_to_rm <- deg_to_rm$name

        # Properly remove from reactive values using NULL assignment
        workspace_jobs_touch(jobs, "deg", deg_to_rm)
        u_degdfs[[deg_to_rm]] <- NULL
        u_degnames$labels <- setdiff(u_degnames$labels, deg_to_rm)
        review_revisions[[deg_to_rm]] <- NULL
      }

      # Remove selection from u_big_degdf
      rm_vec <- u_big_degdf[["df"]][input$deg_list_table_rows_selected, ]
      u_big_degdf[["df"]] <- rm_file_degdf(u_big_degdf[["df"]], rm_vec)
    })

    # Reactively update which deg table is read based on selection
    deg_to_table <- reactive({
      req(input$deg_table_select)
      df <- u_degdfs[[input$deg_table_select]]
      req(df)
      # Historical inactive example: see the enrich_tab.R section in
      # The reference is in `docs/development/historical-r-examples.md`.
      return(df)
    })
    # Historical inactive example: see the enrich_tab.R section in
    # The reference is in `docs/development/historical-r-examples.md`.
    output$deg_table <- DT::renderDT({
      workspace_display_dt(deg_to_table(), labels = FALSE)
    })

    # Update column names when DEG table selection changes
    observeEvent(input$deg_table_select, {
      req(input$deg_table_select)
      df <- u_degdfs[[input$deg_table_select]]
      if (!is.null(df)) {
        deg_colnames_reactive(colnames(df))
      }
      # The preview cutoff starts from the default cutoff for each selected
      # list.
      updateNumericInput(
        session,
        "review_cutoff",
        value = review_cutoff_value(input$deg_filter_cutoff)
      )
    })

    # download deg
    output$download_deg <- shiny::downloadHandler(
      filename = function() {
        req(input$deg_table_select)
        paste0(sanitize_filename(input$deg_table_select), input$deg_export_type)
      },
      content = function(file) {
        ext_type <- input$deg_export_type
        if (ext_type == ".txt") {
          write.table(
            u_degdfs[[input$deg_table_select]],
            file,
            sep = "\t",
            row.names = FALSE
          )
        } else if (ext_type == ".csv") {
          write.csv(u_degdfs[[input$deg_table_select]], file, row.names = FALSE)
        } else if (ext_type == ".tsv") {
          write.table(
            u_degdfs[[input$deg_table_select]],
            file,
            sep = "\t",
            row.names = FALSE
          )
        }
      }
    )

    # Preview: always uses review_cutoff, so the previewed snapshot is what
    # Commit freezes.
    review_preview <- reactive({
      name <- input$deg_table_select
      req(name)
      df <- u_degdfs[[name]]
      req(df)
      gene_col <- input$review_gene_col
      if (is.null(gene_col) || identical(gene_col, "__default__")) {
        gene_col <- NULL
      }
      review_resolve(
        df,
        gene_header = review_gene_header(name),
        gene_col = gene_col,
        rule = review_rule_from_inputs(input$review_p_col, input$review_p_role),
        cutoff = review_cutoff_value(input$review_cutoff),
        name = name,
        settings = review_settings()
      )
    })
    output$review_preview_ui <- renderUI(review_preview_card(review_preview()))

    observeEvent(input$review_commit, {
      name <- input$deg_table_select
      req(name, u_degdfs[[name]])
      review_contain(
        {
          snapshot <- review_preview()
          if (!isTRUE(snapshot$ok)) {
            review_report(snapshot$message)
            return(NULL)
          }
          previous <- review_revisions[[name]]
          revision <- if (is.null(previous)) 1L else previous$revision + 1L
          review_revisions[[name]] <- list(
            revision = revision,
            snapshot = snapshot,
            source_digest = snapshot$source_digest
          )
          review_messages(sprintf(
            "Committed revision %d for %s",
            revision,
            name
          ))
        },
        function() {
          review_report(paste0(
            name,
            ": the input revision could not be committed"
          ))
        }
      )
    })

    # Cutoff authority: a committed list runs its revision's rule; an
    # uncommitted one
    # runs the default rule with the live default cutoff.
    review_card_data <- reactive({
      selected <- input$degs_to_enrich
      if (!length(selected)) {
        return(list())
      }
      cutoff <- review_cutoff_value(input$deg_filter_cutoff)
      settings <- review_settings()
      entries <- lapply(selected, function(name) {
        df <- u_degdfs[[name]]
        revision <- review_revisions[[name]]
        if (is.null(df)) {
          return(list(
            name = name,
            committed = FALSE,
            changed = FALSE,
            snapshot = list(
              ok = FALSE,
              message = paste("Gene list", name, "is not available")
            )
          ))
        }
        if (!is.null(revision)) {
          return(list(
            name = name,
            committed = TRUE,
            revision = revision$revision,
            snapshot = revision$snapshot,
            changed = !identical(revision$source_digest, digest::digest(df))
          ))
        }
        list(
          name = name,
          committed = FALSE,
          changed = FALSE,
          snapshot = review_resolve(
            df,
            gene_header = review_gene_header(name),
            cutoff = cutoff,
            name = name,
            settings = settings
          )
        )
      })
      stats::setNames(entries, selected)
    })
    output$review_card <- renderUI(review_deg_card(
      review_card_data(),
      review_settings()
    ))
    output$review_messages <- renderUI({
      messages <- review_messages()
      if (length(messages)) {
        tags$ul(class = "review-messages", lapply(messages, tags$li))
      }
    })

    # ---- progressive disclosure (SPEC-WS-013 M7) ----------------------------------
    # The technical review above sits under Advanced; these outputs give the plain
    # version, and none of them changes a recorded revision or snapshot.
    species_chosen <- shiny::reactiveVal(NULL)
    species_sent <- new.env(parent = emptyenv())
    species_sent$value <- NULL
    observeEvent(
      input$species_select,
      {
        value <- input$species_select
        if (!is.null(species_sent$value) && identical(value, species_sent$value)) {
          species_sent$value <- NULL
          return()
        }
        species_chosen(value)
      },
      ignoreInit = TRUE
    )
    recorded_species <- reactive({
      selected <- input$degs_to_enrich
      big <- u_big_rrdf[["df"]]
      if (
        !length(selected) ||
          !is.data.frame(big) ||
          !all(c("from_deg", "species") %in% names(big))
      ) {
        return(character())
      }
      as.character(big$species[big$from_deg %in% selected])
    })
    # The recorded species becomes the selection; with none recorded the selection stays what
    # the user chose (or the default).
    observe({
      default <- enrich_species_default(recorded_species(), NULL)
      if (identical(default$source, "recorded")) {
        shiny::isolate({
          if (!identical(input$species_select, default$value)) {
            species_sent$value <- default$value
            updateSelectInput(
              session = shiny::getDefaultReactiveDomain(),
              "species_select",
              selected = default$value
            )
          }
        })
      }
    })
    species_summary <- reactive({
      current <- input$species_select
      if (is.null(current) || !nzchar(current)) {
        current <- "human"
      }
      recorded <- enrich_species_default(recorded_species(), NULL)
      source <- if (identical(recorded$source, "recorded") && identical(current, recorded$value)) {
        "recorded"
      } else if (!is.null(species_chosen())) {
        "chosen"
      } else {
        "default"
      }
      list(value = current, source = source)
    })
    settings_text <- reactive(enrich_settings_summary(list(
      species = species_summary(),
      annotation = input$anntype_select %||% "GO",
      ontology = input$ont_select %||% "BP",
      keytype = input$keytype_select %||% "SYMBOL",
      cutoff = review_cutoff_value(input$deg_filter_cutoff)
    )))
    output$settings_summary <- renderUI(tags$p(class = "rs-settings-summary", settings_text()))
    output$run_summary <- renderUI({
      selected <- input$degs_to_enrich
      lead <- if (length(selected)) {
        paste0("Run on ", paste(selected, collapse = ", "), ".")
      } else {
        "Select gene lists to run."
      }
      tags$span(lead, " ", settings_text())
    })

    # One table for gene lists and enrichment results; a row drives the preview.
    files_rows <- reactive({
      deg <- as.character(u_degnames$labels)
      rr <- as.character(u_rrnames$labels)
      data.frame(
        Name = c(deg, rr),
        Type = c(rep("Gene list", length(deg)), rep("Enrichment result", length(rr))),
        Size = c(
          vapply(deg, function(n) {
            d <- u_degdfs[[n]]
            if (is.data.frame(d)) paste(nrow(d), "rows") else ""
          }, character(1)),
          vapply(rr, function(n) {
            d <- u_rrdfs[[n]]
            if (is.data.frame(d)) paste(nrow(d), "terms") else ""
          }, character(1))
        ),
        stringsAsFactors = FALSE,
        row.names = NULL
      )
    })
    output$files_table <- DT::renderDT(
      files_rows(),
      selection = "single",
      rownames = FALSE,
      options = list(dom = "tp", pageLength = 5, ordering = FALSE)
    )
    observeEvent(input$files_table_rows_selected, {
      rows <- files_rows()
      row <- input$files_table_rows_selected
      if (!length(row) || row > nrow(rows)) {
        return()
      }
      if (identical(rows$Type[[row]], "Gene list")) {
        updateSelectInput(
          session = shiny::getDefaultReactiveDomain(),
          "deg_table_select",
          selected = rows$Name[[row]]
        )
      } else {
        updateSelectInput(
          session = shiny::getDefaultReactiveDomain(),
          "rr_table_select",
          selected = rows$Name[[row]]
        )
      }
    })
    output$plain_preview <- renderUI({
      rows <- files_rows()
      row <- input$files_table_rows_selected
      if (!length(row) || row > nrow(rows)) {
        return(NULL)
      }
      name <- rows$Name[[row]]
      line <- paste0(name, ": ", tolower(rows$Type[[row]]), ", ", rows$Size[[row]], ".")
      if (identical(rows$Type[[row]], "Gene list")) {
        snapshot <- review_card_entry_snapshot(name)
        if (isTRUE(snapshot$ok)) {
          line <- paste0(
            line,
            " With the current rule ",
            snapshot$counts$submitted,
            " genes would be submitted."
          )
        }
      }
      tags$p(class = "rs-plain-preview", line)
    })
    review_card_entry_snapshot <- function(name) {
      df <- u_degdfs[[name]]
      if (!is.data.frame(df)) {
        return(list(ok = FALSE))
      }
      review_resolve(
        df,
        gene_header = review_gene_header(name),
        cutoff = review_cutoff_value(input$deg_filter_cutoff),
        name = name,
        settings = review_settings()
      )
    }

    # Plain review above Run: what will be submitted per list, in words.
    output$review_plain <- renderUI({
      entries <- review_card_data()
      if (!length(entries)) {
        return(tags$p("Select gene lists to see what will be submitted."))
      }
      tags$div(
        class = "rs-review-plain",
        lapply(entries, function(entry) {
          snapshot <- entry$snapshot
          text <- if (!isTRUE(snapshot$ok)) {
            snapshot$message
          } else {
            counts <- snapshot$counts
            paste0(
              counts$submitted,
              " genes will be submitted, keeping rows with ",
              review_rule_text(snapshot$query_rule),
              "; ",
              counts$excluded[["p_cutoff"]] + counts$excluded[["p_missing"]],
              " rows are left out."
            )
          }
          note <- if (isTRUE(entry$committed)) {
            if (isTRUE(entry$changed)) {
              " The list changed since you saved these settings; save them again."
            } else {
              " Your settings are saved for this list."
            }
          } else {
            ""
          }
          tags$p(tags$strong(paste0(entry$name, ": ")), paste0(text, note))
        })
      )
    })

    # ---- background selector (SPEC-WS-005) --------------------------------------
    # The default is the annotation universe. A custom background is offered only when
    # the installed richR passes the public-route check, and it can only be submitted
    # after a passing "Check background" for the exact lists and settings being run.
    background_capability <- enrichment_background_capability()
    background_check <- shiny::reactiveVal(NULL)
    output$background_ui <- renderUI({
      ns <- session$ns
      default_note <- helpText(
        "Default background: annotation universe, the genes the selected annotation source",
        "assigns to a term. It is not your measured gene list.")
      if (!isTRUE(background_capability$available)) {
        return(tagList(default_note, helpText(paste("Custom background unavailable:", background_capability$reason))))
      }
      tagList(
        radioButtons(ns('background_mode'), "Background (universe)", inline = TRUE,
                     choices = c("Annotation universe (default)" = "annotation",
                                 "Custom background (measured and annotated genes)" = "explicit")),
        default_note,
        conditionalPanel(sprintf("input['%s'] == 'explicit'", ns('background_mode')),
          helpText("Only background genes found in the annotation are used (measured and annotated).",
                   "Every query gene that is annotated must be in the background."),
          textAreaInput(ns('background_text'), "Background genes",
                        placeholder = "Paste genes separated by spaces, new lines, commas or semicolons"),
          fileInput(ns('background_file'), "Or upload a background list (text, up to 5 MB)",
                    accept = c('.txt', '.csv', '.tsv')),
          actionButton(ns('background_check'), "Check background"))
      )
    })
    background_active <- reactive({
      isTRUE(background_capability$available) && identical(input$background_mode, "explicit")
    })
    background_ids <- reactive({
      texts <- character()
      if (isTRUE(nzchar(input$background_text))) texts <- input$background_text
      file <- input$background_file
      if (!is.null(file) && nrow(file)) {
        size <- file.size(file$datapath[[1]])
        if (is.na(size) || size > 5e6) {
          return(list(ok = FALSE, message = "The background file exceeds 5 MB", ids = character()))
        }
        texts <- c(texts, paste(readLines(file$datapath[[1]], warn = FALSE), collapse = "\n"))
      }
      if (!length(texts)) {
        return(list(ok = FALSE, message = "Paste or upload a background gene list", ids = character()))
      }
      enrichment_background_admit_text(paste(texts, collapse = "\n"))
    })
    # Identity of what a check covers: the background, each query list, and the settings.
    background_key <- function(ids, entries) {
      digest::digest(list(enrichment_background_digest(ids),
                          lapply(entries, function(e) e$snapshot$submitted), review_settings()))
    }
    # The check builds the annotation, which can take seconds to minutes, so it runs in a
    # future like the enrichment itself and never blocks the shared R process. A newer
    # check, or a change to the background, lists or settings, discards an older result.
    background_pending <- shiny::reactiveVal(FALSE)
    background_seq <- shiny::reactiveVal(0L)
    observeEvent(input$background_check, {
      req(background_active())
      review_contain({
        admitted <- background_ids()
        if (!isTRUE(admitted$ok)) {
          background_check(NULL)
          return(review_report(admitted$message))
        }
        entries <- review_card_data()
        if (!length(entries)) {
          background_check(NULL)
          return(review_report("Select gene lists to check the background against"))
        }
        problems <- unlist(lapply(entries, function(e) if (!isTRUE(e$snapshot$ok)) e$snapshot$message))
        if (length(problems)) {
          background_check(NULL)
          return(review_report(problems))
        }
        seq_id <- shiny::isolate(background_seq()) + 1L
        background_seq(seq_id)
        launch_key <- background_key(admitted$ids, entries)
        names_launched <- vapply(entries, function(e) e$name, character(1))
        job_builder <- annotation_builder
        job_settings <- review_settings()
        job_universe <- admitted$ids
        job_queries <- unname(lapply(entries, function(e) e$snapshot$submitted))
        background_check(NULL)
        background_pending(TRUE)
        shinyjs::disable("background_check")
        current <- function() identical(shiny::isolate(background_seq()), seq_id)
        finish <- function() {
          background_pending(FALSE)
          shinyjs::enable("background_check")
        }
        future_check <- workspace_jobs_future(
          enrichment_background_check_job(job_builder, job_settings, job_universe, job_queries),
          packages = "richR", seed = TRUE)
        promises::then(
          promises::as.promise(future_check),
          onFulfilled = function(reviews) {
            if (!current()) return(invisible(NULL))
            finish()
            now <- shiny::isolate({
              ids_now <- background_ids()
              if (isTRUE(ids_now$ok)) background_key(ids_now$ids, review_card_data()) else NA_character_
            })
            if (!identical(now, launch_key)) return(invisible(NULL))
            background_check(list(
              key = launch_key, ok = all(vapply(reviews, function(r) r$ok, logical(1))),
              entries = stats::setNames(reviews, names_launched)))
          },
          onRejected = function(e) {
            if (!current()) return(invisible(NULL))
            finish()
            review_report("The background could not be checked")
          })
        NULL
      }, function() {
        background_check(NULL)
        review_report("The background could not be checked")
      })
    })
    output$background_review <- renderUI({
      if (!background_active()) return(NULL)
      if (isTRUE(background_pending())) return(tags$p(class = "help-block", "Checking background..."))
      check <- background_check()
      if (is.null(check)) return(NULL)
      tags$div(class = "review-card", lapply(names(check$entries), function(name) {
        review <- check$entries[[name]]
        tags$div(class = "review-card-entry", tags$h5(paste("Background check:", name)),
          tags$ul(lapply(enrichment_background_review_lines(review), tags$li),
                  lapply(review$problems, function(p) tags$li(class = "text-danger", p))))
      }))
    })

    # Enrich selected degs
    # test text inputs:
    # Xkr4 Rp1 Sox17
    # Mrpl15 Lypla1 Tcea1
    observeEvent(input$enrich_deg, {
      req(input$degs_to_enrich)

      # 1. Collect ALL reactive inputs BEFORE entering future
      req(u_big_degdf[["df"]])
      # A missing policy, a changed committed input or an empty rule stops Run
      # before
      # any runner call; stores and selections stay unchanged. So does an
      # unexpected error.
      deg_inputs <- review_contain(
        {
          if (is.null(review_resolve_policy())) {
            review_report(review_policy_message)
            return(NULL)
          }
          entries <- review_card_data()
          problems <- unlist(lapply(entries, function(entry) {
            if (isTRUE(entry$changed)) {
              sprintf(
                "Input changed since commit for %s; review again",
                entry$name
              )
            } else if (!isTRUE(entry$snapshot$ok)) {
              entry$snapshot$message
            }
          }))
          if (length(problems)) {
            review_report(problems)
            return(NULL)
          }
          review_messages(character())
          unname(lapply(entries, function(entry) {
            snapshot <- entry$snapshot
            list(
              name = entry$name,
              df = u_degdfs[[entry$name]],
              gene_header = snapshot$query_rule$gene_col,
              ids = snapshot$submitted,
              query_rule = snapshot$query_rule,
              revision_digest = snapshot$digest
            )
          }))
        },
        function() {
          review_report(paste(
            "Run stopped:",
            paste(input$degs_to_enrich, collapse = ", "),
            "could not be reviewed"
          ))
          NULL
        }
      )
      if (is.null(deg_inputs)) {
        return(NULL)
      }
      background_val <- NULL
      if (background_active()) {
        admitted <- background_ids()
        check <- background_check()
        if (!isTRUE(admitted$ok)) {
          review_report(admitted$message)
          return(NULL)
        }
        if (
          is.null(check) ||
            !identical(
              check$key,
              background_key(admitted$ids, review_card_data())
            )
        ) {
          review_report(paste(
            "Check the background before running; the lists or settings",
            "changed since the last check"
          ))
          return(NULL)
        }
        if (!isTRUE(check$ok)) {
          review_report(unlist(lapply(check$entries, function(r) r$problems)))
          return(NULL)
        }
        background_val <- list(mode = "explicit", ids = admitted$ids)
      }
      species_val <- input$species_select
      anntype_val <- input$anntype_select
      keytype_val <- input$keytype_select
      ontology_val <- input$ont_select
      cutoff_val <- input$deg_filter_cutoff
      if (is.null(cutoff_val) || is.na(cutoff_val)) {
        cutoff_val <- 0.05
      }

      # 2. Everything below is the job admission, captured as one closure so that it can start either
      # now or, when an annotation package must be installed first (SPEC-WS-014 M2), when the install
      # has finished. Inputs, settings and input values were all captured above.
      start_job <- function() {
        # 2. Admit the job. Inputs, settings and the input values are captured
        # now; the
        #    session job registry queues the job and launches it when a worker is
        # free.
        runner <- enrichment_runner
        labels <- vapply(deg_inputs, function(x) x$name, character(1))
        sources <- lapply(labels, function(label) {
          list(
            store = "deg",
            label = label,
            rv = u_degdfs,
            value = u_degdfs[[label]]
          )
        })
        settings <- list(
          species = species_val,
          anntype = anntype_val,
          keytype = keytype_val,
          ontology = ontology_val,
          cutoff = cutoff_val,
          background = if (is.null(background_val)) {
            "annotation universe"
          } else {
            sprintf(
              "explicit %s",
              substr(enrichment_background_digest(background_val$ids), 1, 12)
            )
          },
          query = lapply(deg_inputs, function(x) {
            list(
              name = x$name,
              query_rule = x$query_rule,
              n_submitted = length(x$ids),
              revision_digest = x$revision_digest
            )
          })
        )

        # 3. Launch future (no reactive reads inside)
        runner_args <- list(
          deg_inputs = deg_inputs,
          cutoff = cutoff_val,
          species = species_val,
          anntype = anntype_val,
          keytype = keytype_val,
          ontology = ontology_val
        )
        if (!is.null(background_val)) {
          runner_args$background <- background_val
        }
        launch <- function() {
          workspace_jobs_future(
            do.call(runner, runner_args),
            packages = "richR",
            seed = TRUE
          )
        }

        # 4. Publish an authorized result (runs in Shiny session context); an
        # earlier
        #    run's label is never overwritten: <name>_enriched, then
        # <name>_enriched_<k>.
        publish <- function(results) {
          outputs <- character()
          for (res in results) {
            base <- paste0(res$name, "_enriched")
            lab <- workspace_jobs_free_label(
              base,
              shiny::isolate(c(u_rrnames$labels, names(u_rrdfs)))
            )
            result_df <- res$result
            # The universe that produced this result travels with it (SPEC-WS-005).
            attr(result_df, "richstudio_background") <- res$background
            u_rrdfs[[lab]] <- result_df
            u_rrnames$labels <- unique(c(shiny::isolate(u_rrnames$labels), lab))
            if (identical(lab, base)) {
              u_big_rrdf[["df"]] <- add_file_rrdf(
                shiny::isolate(u_big_rrdf[["df"]]),
                name = res$name,
                annot = res$anntype,
                keytype = res$keytype,
                ontology = res$ontology,
                species = res$species,
                file = FALSE
              )
            } else {
              u_big_rrdf[["df"]] <- workspace_jobs_rrdf_row(
                shiny::isolate(u_big_rrdf[["df"]]),
                lab,
                res$name,
                res
              )
            }
            outputs <- c(outputs, lab)
          }
          showNotification(
            paste(length(results), "DEG set(s) enriched successfully!"),
            type = "message"
          )
          outputs
        }
        workspace_jobs_submit(
          jobs,
          "enrichment",
          sources,
          settings,
          launch,
          publish,
          session,
          "enrich_deg",
          progress = "Enrichment analysis running in background..."
        )
      }
      annotation_install_gate(
        jobs, session, species_val, anntype_val, keytype_val, start_job
      )

      # Return NULL so Shiny knows this observer is async
      NULL
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
          workspace_jobs_touch(jobs, "rr", old_name)
          # Copy data to new name
          u_rrdfs[[new_name]] <- u_rrdfs[[old_name]]
          # Remove old name from reactive values
          u_rrdfs[[old_name]] <- NULL
          # Update labels
          u_rrnames$labels <- setdiff(u_rrnames$labels, old_name)
          u_rrnames$labels <- c(u_rrnames$labels, new_name)
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
        workspace_jobs_touch(jobs, "rr", rr_to_rm)
        u_rrdfs[[rr_to_rm]] <- NULL
        u_rrnames$labels <- setdiff(u_rrnames$labels, rr_to_rm)
      }

      # Remove selection from u_big_rrdf
      rm_vec <- u_big_rrdf[["df"]][input$rr_list_table_rows_selected, ]
      u_big_rrdf[["df"]] <- rm_file_rrdf(u_big_rrdf[["df"]], rm_vec)
    })

    # reactively update which rr table is read based on selection
    rr_to_table <- reactive({
      req(input$rr_table_select)
      df <- u_rrdfs[[input$rr_table_select]]
      req(df)
      return(df)
    })

    # output rr table
    output$rr_table <- DT::renderDT({
      workspace_display_dt(rr_to_table(), labels = FALSE)
    })

    # download rr
    output$download_rr <- shiny::downloadHandler(
      filename = function() {
        req(input$rr_table_select)
        paste0(sanitize_filename(input$rr_table_select), input$rr_export_type)
      },
      content = function(file) {
        ext_type <- input$rr_export_type
        if (ext_type == ".txt") {
          write.table(
            u_rrdfs[[input$rr_table_select]],
            file,
            sep = "\t",
            row.names = FALSE
          )
        } else if (ext_type == ".csv") {
          write.csv(u_rrdfs[[input$rr_table_select]], file, row.names = FALSE)
        } else if (ext_type == ".tsv") {
          write.table(
            u_rrdfs[[input$rr_table_select]],
            file,
            sep = "\t",
            row.names = FALSE
          )
        }
      }
    )

    # Outputs inside the closed disclosures still render, so their content is current when opened.
    # (The tables render when their disclosure is opened, as before.)
    for (name in c("review_card", "review_preview_ui", "files_table")) {
      shiny::outputOptions(output, name, suspendWhenHidden = FALSE)
    }
  })
}
sample_deg_path <- function(name) {
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
