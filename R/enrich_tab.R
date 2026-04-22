
enrichTabUI <- function(id, tabName) {
  ns <- NS(id)
  tabItem(tabName = tabName,
    # UPLOAD TAB CONTENTS
    useShinyjs(),
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
            helpText("Genes can be separated by any non-alphanumeric character"),
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
          fluidRow(column(5,
            selectInput(ns('deg_header_select'), "GeneID header", choices=NULL)
          )),
          fluidRow(
            column(5,
              selectInput(ns('deg_filter_by'), "Filter by", choices=NULL)
            ),
            column(5,
              numericInput(ns('deg_filter_cutoff'), "Cutoff", value=NULL)
            ),
          ),
          checkboxInput(ns('deg_remove_na'), "Remove NA?", value=TRUE),
          br(),
          DT::dataTableOutput(ns('deg_table')),
          br(),
          actionButton(ns('deg_filter_btn'), "Filter"),
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
}


enrichTabServer <- function(id, u_degnames, u_degdfs, u_big_degdf, u_rrnames, u_rrdfs, u_big_rrdf) {

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

    # Update select inputs based on # file inputs
    observe ({
      updateSelectInput(session=shiny::getDefaultReactiveDomain(), 'deg_table_select', choices= u_degnames_reactive())
      updateSelectInput(session=shiny::getDefaultReactiveDomain(), 'degs_to_enrich', choices= u_degnames_reactive())
      updateSelectInput(session=shiny::getDefaultReactiveDomain(), 'deg_header_select', choices= deg_colnames_reactive())
      updateSelectInput(session=shiny::getDefaultReactiveDomain(), 'deg_filter_by', choices= deg_colnames_reactive())
      updateSelectInput(session=shiny::getDefaultReactiveDomain(), 'rr_table_select', choices= u_rrnames_reactive())
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
      for (i in seq_along(input$deg_files$name)) {
        # Validate file size before processing
        file_size_mb <- file.info(input$deg_files$datapath[i])$size / (1024 * 1024)
        if (!is.na(file_size_mb) && file_size_mb > 100) {
          showNotification(
            paste0("File '", input$deg_files$name[i], "' too large (max 100MB)"),
            type = "error"
          )
          next
        }

        lab <- input$deg_files$name[i]

        ext <- tools::file_ext(input$deg_files$name[i])
        path <- input$deg_files$datapath[i]

        # Handle Excel files directly
        if (tolower(ext) %in% c("xls", "xlsx")) {
          df <- tryCatch({
            as.data.frame(readxl::read_excel(path))
          }, error = function(e) {
            showNotification(paste0("Error reading '", lab, "': ", e$message), type = "error")
            NULL
          })
          if (is.null(df)) next
        } else {
          # try to read file as csv
          csv_ncol <- tryCatch({
            csvdf <- read.csv(path)
            ncol(csvdf)
          }, error = function(err) {
            0
          })
          # try to read file as tsv
          tsv_ncol <- tryCatch({
            tsvdf <- read.delim(path)
            ncol(tsvdf)
          }, error = function(err) {
            0
          })
          # decide which df to store
          if (tsv_ncol == 0 || csv_ncol > tsv_ncol) {
            df <- read.csv(path)
          } else {
            df <- read.delim(path)
          }
        }

        u_degdfs[[lab]] <- df # set u_degdfs
        u_degnames$labels <- c(u_degnames$labels, lab) # set u_degnames
        u_big_degdf[['df']] <- add_file_degdf(u_big_degdf[['df']], lab, df)
      }

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
      x <- strsplit(input$deg_text, "[^[:alnum:]]+")
      df <- data.frame(GeneID = x)
      colnames(df) <- c("GeneID")
      lab <- input$degtext_name

      u_degdfs[[lab]] <- df # set u_degdfs
      u_degnames$labels <- c(u_degnames$labels, lab)
      u_big_degdf[['df']] <- add_file_degdf(u_big_degdf[['df']], lab, df)

      # Show file list
      # if (!is.null(u_big_degdf[['df']])) {
      #   shinyjs::show("list_box")
      #   print("showing...")
      # }

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
      # Debug: str(info)
      i = info$row
      j = info$col
      v = info$value
      # Debug: print(info$col)

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

    # Enrich selected degs
    # test text inputs:
    # Xkr4 Rp1 Sox17
    # Mrpl15 Lypla1 Tcea1
    observeEvent(input$enrich_deg, {
      req(input$degs_to_enrich)

      # 1. Collect ALL reactive inputs BEFORE entering future
      req(u_big_degdf[['df']])
      deg_inputs <- lapply(input$degs_to_enrich, function(name) {
        x <- u_degdfs[[name]]
        big_df <- u_big_degdf[['df']]
        gene_hdr <- big_df[big_df$name %in% name, "GeneID_header"]
        list(name = name, df = x, gene_header = gene_hdr)
      })
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
      p <- future::future({
        results <- list()
        for (i in seq_along(deg_inputs)) {
          inp <- deg_inputs[[i]]
          x_use <- inp$df

          # Case-insensitive column matching for filtering
          col_lower <- tolower(colnames(x_use))
          padj_idx <- which(col_lower == "padj")
          pval_idx <- which(col_lower == "pvalue")
          if (length(padj_idx) > 0) {
            padj_col <- colnames(x_use)[padj_idx[1]]
            x_use <- x_use[!is.na(x_use[[padj_col]]) & x_use[[padj_col]] < cutoff_val, , drop = FALSE]
          } else if (length(pval_idx) > 0) {
            pval_col <- colnames(x_use)[pval_idx[1]]
            x_use <- x_use[!is.na(x_use[[pval_col]]) & x_use[[pval_col]] < cutoff_val, , drop = FALSE]
          }
          if (nrow(x_use) == 0) x_use <- inp$df

          enriched <- shiny_enrich(x = x_use, header = inp$gene_header,
                                   species = species_val, anntype = anntype_val,
                                   keytype = keytype_val, ontology = ontology_val)
          results[[i]] <- list(
            name = inp$name,
            result = enriched@result,
            anntype = anntype_val,
            keytype = keytype_val,
            ontology = ontology_val,
            species = species_val
          )
        }
        results
      }, seed = TRUE)

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
      # Debug: str(info)
      i = info$row
      j = info$col
      v = info$value
      # Debug: print(info$col)

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
