
enrichTabUI <- function(id, tabName) {
  ns <- NS(id)
  tabItem(tabName = tabName,
    # UPLOAD TAB CONTENTS
    useShinyjs(),
    fluidRow(
    column(width = 4,
      fluidRow(
        tabBox(title=span(icon("upload"), "Upload DEG sets"), id='upload_box', width=NULL,
          tabPanel("File upload",
            h4('Upload files'),
            p('Upload gene differential expression data from local computer'),
            helpText("Accepted formats: .txt, .csv, .tsv, .xls, .xlsx"),
            fileInput(ns('deg_files'), 'Select files', multiple=TRUE, accept=c('.csv', '.tsv', '.xls', '.xlsx', '.txt')),
            hr(),
            h4('Load demo'),
            p("Loads sample DEG sets: 'deg_mouse1', 'deg_mouse2', 'deg_mouse3'"),
            actionButton(ns('deg_load'), 'Load data')
          ),
          tabPanel("Text input",
            helpText("Separate genes with spaces, new lines, commas or semicolons"),
            textAreaInput(ns('deg_text'), "Text Input", placeholder="Paste list of significant genes or dataframe-like object"),
            textInput(ns('degtext_name'), "Name", placeholder="Set name for pasted DEG set"),
            fluidRow(
              div(style="display:inline-block; float:left", column(3, actionButton(ns('upload_degtext'), "Upload"))),
              div(style="display:inline-block; float:left", column(3, actionButton(ns('degtext_load'), "Load demo")))
            )

          )
        ),
        box(title="Enrich", status="primary", solidHeader=TRUE, width=NULL,
          br(),
          selectInput(ns('degs_to_enrich'), "Select DEG sets to enrich", choices=NULL, multiple=TRUE),
          selectInput(ns('anntype_select'), "Select annotation source", c("GO", "KEGG", "Reactome")),
          selectInput(ns('keytype_select'), "Select keytype",
                      c("SYMBOL", "ENSEMBL", "ENTREZID", "REFSEQ", "UNIPROT", "GENENAME",
                        "ACCNUM", "ALIAS", "ENSEMBLPROT", "ENSEMBLTRANS",
                        "ENZYME", "EVIDENCE", "EVIDENCEALL", "FLYBASE",
                        "FLYBASECG", "FLYBASEPROT", "GO", "GOALL", "MAP",
                        "ONTOLOGY", "ONTOLOGYALL", "PATH", "PMID",
                        "UNIGENE"), selected="SYMBOL"),
          selectInput(ns('ont_select'), "Select ontology", c("BP", "MF", "CC")),
          selectInput(ns('species_select'), "Select species",
                      c('human', 'mouse', 'rat', 'zebrafish', 'fly', 'celegans', 'yeast',
                        'chicken', 'bovine', 'pig', 'canine', 'xenopus', 'rhesus',
                        'arabidopsis', 'anopheles', 'ecoli', 'malaria', 'chipm',
                        'toxoplasma', 'sco'), selected='human'),
          br(),
          h4("Review before Run"),
          uiOutput(ns('review_card')),
          uiOutput(ns('review_messages')),
          numericInput(ns('deg_filter_cutoff'),
                       "Default cutoff (used for gene lists without a committed revision)", value=NULL),
          actionButton(ns('enrich_deg'), "Run Enrichment",
                       icon = icon("play"),
                       class = "btn-action-hero btn-block")
        )
      ),
    ),
    column(width = 8,
      shinyjs::hidden(tags$div(
        id=ns("list_box"),
        tabBox(title="Uploaded files", width=NULL,

          tabPanel("DEG sets",
            tags$div(id=ns("deglist_box"),
              div(style="display:inline-block; float:left", helpText("Double-click on any cell to change its value.")),
              div(style="display:inline-block; float:right",
                  actionBttn(ns('deglist_help'), label=NULL, style='material-circle', status='primary', icon=icon('info'), size='xs')
              ),
              br(),
              br(),
              DT::DTOutput(ns('deg_list_table')),
              actionButton(ns('remove_deg'), "Delete")
            )
          ),
          tabPanel("Enrichment Results",
            tags$div(id=ns("rrlist_box"),
              div(style="display:inline-block; float:left", helpText("Double-click on any cell to change its value.")),
              div(style="display:inline-block; float:right",
                actionBttn(ns('rrlist_help'), label=NULL, style='material-circle', status='primary', icon=icon('info'), size='xs')
              ),
              br(),
              br(),
              DT::DTOutput(ns('rr_list_table')),
              actionButton(ns('remove_rr'), "Delete")
            )
          )
        ))
      ),
      tabBox(title="View files", width=NULL,
        tabPanel(title="DEG sets",
          h4("Preprocess data"),
          selectInput(ns('deg_table_select'), "Select DEG set", choices=NULL),
          tags$div(class = "review-preview",
            h4("Preview \u2014 not committed"),
            fluidRow(
              column(6, selectInput(ns('review_gene_col'), "Gene column",
                                    choices = c("Default (GeneID header)" = "__default__"))),
              column(6, selectInput(ns('review_p_col'), "P-value column",
                                    choices = c("Default (current rule)" = "__default__",
                                                "None \u2014 all rows" = "__none__")))
            ),
            fluidRow(
              column(6, selectInput(ns('review_p_role'), "P-value role",
                                    choices = c("Adjusted" = "adjusted", "Raw" = "raw"))),
              column(6, numericInput(ns('review_cutoff'), "Preview cutoff", value = 0.05,
                                     min = 0, max = 1, step = 0.01))
            ),
            uiOutput(ns('review_preview_ui')),
            actionButton(ns('review_commit'), "Commit input revision")
          ),
          br(),
          h4("Stored rows"),
          DT::dataTableOutput(ns('deg_table')),
          br(),
          hr(),
          h4("Export data"),
          selectInput(ns('deg_export_type'), "Export as", choices=c(".txt", ".csv", ".tsv")),
          downloadButton(ns("download_deg"), "Download")
        ),
        tabPanel(title="Enrichment results",
          fluidRow(
            column(4,
              selectInput(ns('rr_table_select'), "Select enrichment result", choices=NULL),
            ),
            column(4,
              selectInput(ns('rr_export_type'), "Export as", choices=c(".txt", ".csv", ".tsv"))
            )
          ),
          downloadButton(ns("download_rr"), "Download"),
          br(),
          br(),
          br(),
          DT::dataTableOutput(ns('rr_table'))
        )
      )
    )
    )
  )
}


enrichTabServer <- function(id, u_degnames, u_degdfs, u_big_degdf, u_rrnames, u_rrdfs, u_big_rrdf, enrichment_runner = run_enrichment_jobs) {

  moduleServer(id, function(input, output, session) {
    # Create reactive objs to make accessible in other modules
    u_degnames_reactive <- reactive(u_degnames$labels)
    u_degdfs_reactive <- reactive(u_degdfs)
    u_rrnames_reactive <- reactive(u_rrnames$labels)
    u_rrdfs_reactive <- reactive(u_rrdfs)

    # Create reactive to store dataframe of uploaded deg/rr
    u_big_degdf_reactive <- reactive(u_big_degdf)
    u_big_rrdf_reactive <- reactive(u_big_rrdf)

    # Tab-local reactive objects
    deg_colnames_reactive <- shiny::reactiveVal(NULL)
    # Committed input revisions keyed by gene-list name; preview changes never touch them.
    review_revisions <- shiny::reactiveValues()
    review_messages <- shiny::reactiveVal(character())

    review_report <- function(messages) {
      review_messages(messages)
      showNotification(paste(messages, collapse = "\n"), type = "error")
    }
    review_settings <- reactive(list(species = input$species_select, anntype = input$anntype_select,
                                     keytype = input$keytype_select, ontology = input$ont_select))
    review_gene_header <- function(name) {
      big <- u_big_degdf[['df']]
      if (!is.data.frame(big) || !all(c("name", "GeneID_header") %in% names(big))) return(NULL)
      header <- big[big$name %in% name, "GeneID_header"]
      if (length(header)) as.character(header[[1]]) else NULL
    }

    # Update select inputs based on # file inputs
    observe ({
      updateSelectInput(session=shiny::getDefaultReactiveDomain(), 'deg_table_select', choices= u_degnames_reactive())
      updateSelectInput(session=shiny::getDefaultReactiveDomain(), 'degs_to_enrich', choices= u_degnames_reactive())
      updateSelectInput(session=shiny::getDefaultReactiveDomain(), 'rr_table_select', choices= u_rrnames_reactive())
    })

    # Preview selectors take their choices from the selected list's columns;
    # recognized p-value names come first, others need the user's confirmation.
    observe({
      columns <- as.character(deg_colnames_reactive())
      recognized <- tolower(c("padj", "pvalue", expanded_col_dictionary$Pvalue, expanded_col_dictionary$Padj))
      known <- columns[tolower(columns) %in% recognized]
      other <- setdiff(columns, known)
      updateSelectInput(session, 'review_gene_col',
        choices = c("Default (GeneID header)" = "__default__", stats::setNames(columns, columns)))
      updateSelectInput(session, 'review_p_col',
        choices = c("Default (current rule)" = "__default__", review_column_choices(known, other),
                    "None \u2014 all rows" = "__none__"))
    })

    observe ({
      # Show/hide entire box
      if (is.null(u_big_degdf[['df']]) && is.null(u_big_rrdf[['df']])) {
        shinyjs::hide('list_box')
      } else if (!is.null(u_big_degdf[['df']]) || !is.null(u_big_rrdf[['df']])) {
        shinyjs::show("list_box")
        # Show/hide delete deg button
        if (is.null(u_big_degdf[['df']])) {
          shinyjs::hide('deglist_box')
        } else if (!is.null(u_big_degdf[['df']])){
          shinyjs::show('deglist_box')
        }
        # Show/hide delete rr button
        if (is.null(u_big_rrdf[['df']])) {
          shinyjs::hide('rrlist_box')
        } else if (!is.null(u_big_rrdf[['df']])){
          shinyjs::show('rrlist_box')
        }
      }
    })

    observeEvent(input$deglist_help, {
      shiny::showModal(shiny::modalDialog(
        title="Help",
        "'GeneID_header' value indicates the column name containing relevant geneID
        information, and 'has_expr_data' value indicates whether relevant gene expression
        data is included."
      ))
    })
    observeEvent(input$rrlist_help, {
      shiny::showModal(shiny::modalDialog(
        title="Help",
        "If annotation, ontology, keytype, or species data is marked with '?', you
        can update it by double-clicking on the relevant cell. If you started from
        an enrichment output but wish to link corresponding differential expression data
        to it, you can update the 'from_deg' value to the name of a DEG set uploaded to
        richStudio."
      ))
    })

    # When deg upload button clicked
    observeEvent(input$deg_files, {
      problems <- character()
      for (i in seq_along(input$deg_files$name)) {
        lab <- input$deg_files$name[i]
        # An unexpected error becomes a message for this file; stores stay unchanged.
        problems <- c(problems, review_contain({
          if (lab %in% u_degnames$labels) {
            paste("A gene list named", lab, "already exists")
          } else {
            # Admission bounds the file before it is parsed; nothing is stored on rejection.
            admitted <- review_admit_file(input$deg_files$datapath[i], lab, "deg")
            if (!isTRUE(admitted$ok)) {
              paste0(lab, ": ", admitted$message)
            } else {
              df <- admitted$df
              meta <- add_file_degdf(u_big_degdf[['df']], lab, df)
              u_degdfs[[lab]] <- df # set u_degdfs
              u_degnames$labels <- c(u_degnames$labels, lab) # set u_degnames
              u_big_degdf[['df']] <- meta
              review_revisions[[lab]] <- NULL
              NULL
            }
          }
        }, function() paste0(lab, ": the file could not be processed")))
      }
      if (length(problems)) review_report(problems) else review_messages(character())
    })

    # Load demo DEG data
    observeEvent(input$deg_load, {
      for (i in 1:3) {
        lab <- paste0('deg_mouse', i)
        path <- sample_deg_path(paste0(lab, '.txt'))
        df <- read.delim(path)

        u_degdfs[[lab]] <- df # set u_degdfs
        u_degnames$labels <- c(u_degnames$labels, lab) # set u_degnames
        u_big_degdf[['df']] <- add_file_degdf(u_big_degdf[['df']], lab, df)
      }
    })

    # Parse pasted text inputs
    observeEvent(input$upload_degtext, {
      req(input$deg_text, input$degtext_name)
      lab <- input$degtext_name
      review_contain({
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
        meta <- add_file_degdf(u_big_degdf[['df']], lab, df)

        u_degdfs[[lab]] <- df # set u_degdfs
        u_degnames$labels <- c(u_degnames$labels, lab)
        u_big_degdf[['df']] <- meta
        review_revisions[[lab]] <- NULL
        review_messages(character())
      }, function() review_report(paste0(lab, ": the pasted text could not be processed")))
    })

    # Reactively update uploaded file dataframe
    big_degdf_to_table <- reactive({
      u_big_degdf[['df']]
    })
    # Output uploaded file table
    output$deg_list_table = DT::renderDT(
      big_degdf_to_table(),
      editable = list(target='cell', disable=list(columns = c(3)))
    )
    # Table editing code (ref: https://github.com/rstudio/DT/pull/480)
    observeEvent(input$deg_list_table_cell_edit, {
      info = input$deg_list_table_cell_edit
      i = info$row
      j = info$col
      v = info$value

      # Rename deg if changing a value in column 1 (name col)
      if (info$col == 1) {
        new_name <- v
        old_name <- u_big_degdf[['df']][i, j]
        if (nchar(new_name) > 0 && nchar(old_name) > 0) {
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
      updated_df <- u_big_degdf[['df']]
      updated_df[i, j] <- DT::coerceValue(v, updated_df[i, j])
      u_big_degdf[['df']] <- updated_df
    })

    # Remove deg from uploaded degs
    observeEvent(input$remove_deg, {
      req(input$deg_list_table_rows_selected)

      # Also remove from degdfs and degnames
      for (deg in input$deg_list_table_rows_selected) {
        deg_to_rm <- u_big_degdf[['df']][deg, ]
        deg_to_rm <- deg_to_rm$name

        # Properly remove from reactive values using NULL assignment
        u_degdfs[[deg_to_rm]] <- NULL
        u_degnames$labels <- setdiff(u_degnames$labels, deg_to_rm)
        review_revisions[[deg_to_rm]] <- NULL
      }

      # Remove selection from u_big_degdf
      rm_vec <- u_big_degdf[['df']][input$deg_list_table_rows_selected, ]
      u_big_degdf[['df']] <- rm_file_degdf(u_big_degdf[['df']], rm_vec)

    })

    # Reactively update which deg table is read based on selection
    deg_to_table <- reactive ({
      req(input$deg_table_select)
      df <- u_degdfs[[input$deg_table_select]]
      req(df)
      #df <- round_tbl(df, 3)
      return(df)
    })
    #deg_to_table <- reactive(NULL)
    # Output individual deg preview table
    output$deg_table = DT::renderDataTable({
      deg_to_table()
    })

    # Update column names when DEG table selection changes
    observeEvent(input$deg_table_select, {
      req(input$deg_table_select)
      df <- u_degdfs[[input$deg_table_select]]
      if (!is.null(df)) {
        deg_colnames_reactive(colnames(df))
      }
      # The preview cutoff starts from the default cutoff for each selected list.
      updateNumericInput(session, 'review_cutoff', value = review_cutoff_value(input$deg_filter_cutoff))
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
          write.table(u_degdfs[[input$deg_table_select]], file, sep='\t', row.names=FALSE)
        } else if (ext_type == ".csv") {
          write.csv(u_degdfs[[input$deg_table_select]], file, row.names=FALSE)
        } else if (ext_type == ".tsv") {
          write.table(u_degdfs[[input$deg_table_select]], file, sep='\t', row.names=FALSE)
        }
      }
    )

    # Preview: always uses review_cutoff, so the previewed snapshot is what Commit freezes.
    review_preview <- reactive({
      name <- input$deg_table_select
      req(name)
      df <- u_degdfs[[name]]
      req(df)
      gene_col <- input$review_gene_col
      if (is.null(gene_col) || identical(gene_col, "__default__")) gene_col <- NULL
      review_resolve(df, gene_header = review_gene_header(name), gene_col = gene_col,
                     rule = review_rule_from_inputs(input$review_p_col, input$review_p_role),
                     cutoff = review_cutoff_value(input$review_cutoff), name = name,
                     settings = review_settings())
    })
    output$review_preview_ui <- renderUI(review_preview_card(review_preview()))

    observeEvent(input$review_commit, {
      name <- input$deg_table_select
      req(name, u_degdfs[[name]])
      review_contain({
        snapshot <- review_preview()
        if (!isTRUE(snapshot$ok)) {
          review_report(snapshot$message)
          return(NULL)
        }
        previous <- review_revisions[[name]]
        revision <- if (is.null(previous)) 1L else previous$revision + 1L
        review_revisions[[name]] <- list(revision = revision, snapshot = snapshot,
                                         source_digest = snapshot$source_digest)
        review_messages(sprintf("Committed revision %d for %s", revision, name))
      }, function() review_report(paste0(name, ": the input revision could not be committed")))
    })

    # Cutoff authority: a committed list runs its revision's rule; an uncommitted one
    # runs the default rule with the live default cutoff.
    review_card_data <- reactive({
      selected <- input$degs_to_enrich
      if (!length(selected)) return(list())
      cutoff <- review_cutoff_value(input$deg_filter_cutoff)
      settings <- review_settings()
      entries <- lapply(selected, function(name) {
        df <- u_degdfs[[name]]
        revision <- review_revisions[[name]]
        if (is.null(df)) {
          return(list(name = name, committed = FALSE, changed = FALSE, snapshot = list(
            ok = FALSE, message = paste("Gene list", name, "is not available"))))
        }
        if (!is.null(revision)) {
          return(list(name = name, committed = TRUE, revision = revision$revision,
                      snapshot = revision$snapshot,
                      changed = !identical(revision$source_digest, digest::digest(df))))
        }
        list(name = name, committed = FALSE, changed = FALSE,
             snapshot = review_resolve(df, gene_header = review_gene_header(name), cutoff = cutoff,
                                       name = name, settings = settings))
      })
      stats::setNames(entries, selected)
    })
    output$review_card <- renderUI(review_deg_card(review_card_data(), review_settings()))
    output$review_messages <- renderUI({
      messages <- review_messages()
      if (length(messages)) tags$ul(class = "review-messages", lapply(messages, tags$li))
    })

    # Enrich selected degs
    # test text inputs:
    # Xkr4 Rp1 Sox17
    # Mrpl15 Lypla1 Tcea1
    observeEvent(input$enrich_deg, {
      req(input$degs_to_enrich)

      # 1. Collect ALL reactive inputs BEFORE entering future
      req(u_big_degdf[['df']])
      # A missing policy, a changed committed input or an empty rule stops Run before
      # any runner call; stores and selections stay unchanged. So does an unexpected error.
      deg_inputs <- review_contain({
        if (is.null(review_resolve_policy())) {
          review_report(review_policy_message)
          return(NULL)
        }
        entries <- review_card_data()
        problems <- unlist(lapply(entries, function(entry) {
          if (isTRUE(entry$changed)) {
            sprintf("Input changed since commit for %s; review again", entry$name)
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
          list(name = entry$name, df = u_degdfs[[entry$name]],
               gene_header = snapshot$query_rule$gene_col, ids = snapshot$submitted,
               query_rule = snapshot$query_rule, revision_digest = snapshot$digest)
        }))
      }, function() {
        review_report(paste("Run stopped:", paste(input$degs_to_enrich, collapse = ", "),
                            "could not be reviewed"))
        NULL
      })
      if (is.null(deg_inputs)) return(NULL)
      species_val <- input$species_select
      anntype_val <- input$anntype_select
      keytype_val <- input$keytype_select
      ontology_val <- input$ont_select
      cutoff_val <- input$deg_filter_cutoff
      if (is.null(cutoff_val) || is.na(cutoff_val)) cutoff_val <- 0.05

      # 2. Disable button and show notification
      shinyjs::disable("enrich_deg")
      showNotification("Enrichment analysis running in background...",
                       id = "enrich_progress", duration = NULL, type = "message")

      # 3. Launch future (no reactive reads inside)
      p <- future::future(
        enrichment_runner(
          deg_inputs = deg_inputs, cutoff = cutoff_val, species = species_val,
          anntype = anntype_val, keytype = keytype_val, ontology = ontology_val
        ),
        packages = "richR",
        seed = TRUE
      )

      # 4. Handle promise resolution (runs in Shiny session context)
      promises::then(p,
        onFulfilled = function(results) {
          for (res in results) {
            lab <- paste0(res$name, "_enriched")
            u_rrdfs[[lab]] <- res$result
            u_rrnames$labels <- unique(c(u_rrnames$labels, lab))
            u_big_rrdf[['df']] <- add_file_rrdf(u_big_rrdf[['df']],
              name = res$name, annot = res$anntype, keytype = res$keytype,
              ontology = res$ontology, species = res$species, file = FALSE)
          }
          shiny::removeNotification("enrich_progress")
          showNotification(paste(length(results), "DEG set(s) enriched successfully!"),
                           type = "message")
        },
        onRejected = function(err) {
          shiny::removeNotification("enrich_progress")
          showNotification(paste("Enrichment error:", conditionMessage(err)),
                           type = "error", duration = 10)
        }
      )

      # 5. Always re-enable button
      promises::finally(p, function() {
        shinyjs::enable("enrich_deg")
      })

      # Return NULL so Shiny knows this observer is async
      NULL
    })

    # Reactively update uploaded file dataframe
    big_rrdf_to_table <- reactive({
      u_big_rrdf[['df']]
    })
    # Output uploaded file table
    output$rr_list_table = DT::renderDT(
      big_rrdf_to_table(), editable='cell'
    )
    # Table editing code
    observeEvent(input$rr_list_table_cell_edit, {
      info = input$rr_list_table_cell_edit
      i = info$row
      j = info$col
      v = info$value

      # Rename rr if changing a value in column 1 (name col)
      if (info$col == 1) {
        new_name <- v
        old_name <- u_big_rrdf[['df']][i, j]
        if (nchar(new_name) > 0 && nchar(old_name) > 0) {
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
      updated_df <- u_big_rrdf[['df']]
      updated_df[i, j] <- DT::coerceValue(v, updated_df[i, j])
      u_big_rrdf[['df']] <- updated_df
    })

    # Remove rr from uploaded rich results
    observeEvent(input$remove_rr, {
      req(input$rr_list_table_rows_selected)

      # Also remove from rrdfs and rrnames
      for (rr in input$rr_list_table_rows_selected) {
        rr_to_rm <- u_big_rrdf[['df']][rr, ]
        rr_to_rm <- rr_to_rm$name

        # Properly remove from reactive values using NULL assignment
        u_rrdfs[[rr_to_rm]] <- NULL
        u_rrnames$labels <- setdiff(u_rrnames$labels, rr_to_rm)
      }

      # Remove selection from u_big_rrdf
      rm_vec <- u_big_rrdf[['df']][input$rr_list_table_rows_selected, ]
      u_big_rrdf[['df']] <- rm_file_rrdf(u_big_rrdf[['df']], rm_vec)
    })

    # reactively update which rr table is read based on selection
    rr_to_table <- reactive ({
      req(input$rr_table_select)
      df <- u_rrdfs[[input$rr_table_select]]
      req(df)
      return(df)
    })

    # output rr table
    output$rr_table = DT::renderDataTable({
      rr_to_table()
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
          write.table(u_rrdfs[[input$rr_table_select]], file, sep='\t', row.names=FALSE)
        } else if (ext_type == ".csv") {
          write.csv(u_rrdfs[[input$rr_table_select]], file, row.names=FALSE)
        } else if (ext_type == ".tsv") {
          write.table(u_rrdfs[[input$rr_table_select]], file, sep='\t', row.names=FALSE)
        }
      }
    )


  })

}
sample_deg_path <- function(name) {
  pkg_path <- system.file("extdata", name, package = "richStudio")
  if (pkg_path != "") {
    return(pkg_path)
  }
  app_dir <- getOption("richStudio.appdir", default = ".")
  fallback <- file.path(app_dir, "inst", "extdata", name)
  if (!file.exists(fallback)) stop("Sample file not found: ", name)
  fallback
}
