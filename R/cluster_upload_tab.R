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

cluster_upload_tab_ui <- function(id, tabName) {
  ns <- NS(id)
  ui <- tabItem(
    tabName = tabName,
    # ENRICH TAB CONTENTS
    fluidRow(
      column(
        width = 4,
        tabBox(
          title = span(
            icon("upload"),
            "Upload enrichment results for clustering"
          ),
          width = NULL,
          tabPanel(
            "File upload",
            fileInput(
              ns("rr_files"),
              "Select files",
              multiple = TRUE,
              accept = c(".csv", ".tsv", ".xls", ".xlsx", ".txt")
            ),
            helpText("Accepted formats: .txt, .csv, .tsv, .xls, .xlsx"),
            hr(),
            h4("Load demo"),
            p("Loads sample enrichment results: 'go1', 'go2', 'kegg1'"),
            actionButton(ns("rr_load"), "Load data")
          ),
          tabPanel(
            "Text input",
            helpText(
              paste0(
                "This functionality is currently not available, ",
                "but will be supported in the future."
              )
            ),
            textAreaInput(
              ns("rr_text"),
              "Text Input",
              placeholder = "Paste dataframe-like object"
            ),
            textInput(
              ns("rrtext_name"),
              "Name",
              placeholder = "Set name for pasted enrichment result"
            ),
            actionButton(ns("upload_rrtext"), "Upload")
          )
        ),
        review_result_intake_ui(ns),
        # Historical inactive example: see the cluster_upload_tab.R section in
        # The reference is in `docs/development/historical-r-examples.md`.
      ),
      column(
        width = 8,
        shinyjs::hidden(tags$div(
          id = ns("list_box"),
          tabBox(
            title = "Uploaded files",
            width = NULL,
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
            ),
            tabPanel(
              "Cluster Results",
              tags$div(
                id = ns("cluslist_box"),
                div(
                  style = "display:inline-block; float:left",
                  helpText("Double-click on any cell to change its value.")
                ),
                div(
                  style = "display:inline-block; float:right",
                  shinyWidgets::actionBttn(
                    ns("cluslist_help"),
                    label = NULL,
                    style = "material-circle",
                    status = "primary",
                    icon = icon("info"),
                    size = "xs"
                  )
                ),
                br(),
                br(),
                DT::DTOutput(ns("clus_list_table")),
                actionButton(ns("remove_clus"), "Delete")
              )
            )
          )
        )),
        tabBox(
          title = "View files",
          width = NULL,
          tabPanel(
            title = "Enrichment results",
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
            DT::dataTableOutput(ns("rr_table"))
          ),
          tabPanel(
            title = "Cluster results",
            fluidRow(
              column(
                4,
                selectInput(
                  ns("clus_table_select"),
                  "Select cluster result",
                  choices = NULL
                ),
              ),
              column(
                4,
                selectInput(
                  ns("clus_export_type"),
                  "Export as",
                  choices = c(".txt", ".csv", ".tsv")
                )
              )
            ),
            downloadButton(ns("download_clus"), "Download"),
            br(),
            br(),
            br(),
            DT::dataTableOutput(ns("clus_table"))
          )
        )
      )
    )
  )
  htmltools::tagAppendAttributes(ui, class = "rs-compact-workflow")
}


cluster_upload_tab_server <- function(
  id,
  u_degnames,
  u_degdfs,
  u_rrnames,
  u_rrdfs,
  u_big_rrdf,
  u_clusnames,
  u_clusdfs,
  u_big_clusdf,
  u_cluslists
) {
  moduleServer(id, function(input, output, session) {
    # Create reactive wrappers for select input updates
    u_rrnames_reactive <- reactive(u_rrnames$labels)
    u_clusnames_reactive <- reactive(u_clusnames$labels)

    # update select inputs based on # cluster results
    observe({
      updateSelectInput(
        session = getDefaultReactiveDomain(),
        "rr_table_select",
        choices = u_rrnames_reactive()
      )
      updateSelectInput(
        session = getDefaultReactiveDomain(),
        "clus_table_select",
        choices = u_clusnames_reactive()
      )
    })

    observe({
      # Show/hide entire box
      if (is.null(u_big_rrdf[["df"]]) && is.null(u_big_clusdf[["df"]])) {
        shinyjs::hide("list_box")
      } else if (
        !is.null(u_big_rrdf[["df"]]) || !is.null(u_big_clusdf[["df"]])
      ) {
        shinyjs::show("list_box")
        # Show/hide delete rr button
        if (is.null(u_big_rrdf[["df"]])) {
          shinyjs::hide("rrlist_box")
        } else if (!is.null(u_big_rrdf[["df"]])) {
          shinyjs::show("rrlist_box")
        }
        # Show/hide delete clus button
        if (is.null(u_big_clusdf[["df"]])) {
          shinyjs::hide("cluslist_box")
        } else if (!is.null(u_big_clusdf[["df"]])) {
          shinyjs::show("cluslist_box")
        }
      }
    })

    observeEvent(input$rrlist_help, {
      showModal(modalDialog(
        title = "Help",
        paste0(
          "If annotation, ontology, keytype, or species ",
          "data is marked with '?', you\n        can upda",
          "te it by double-clicking on the relevant cell",
          ". If you started from\n        an enrichment o",
          "utput but wish to link corresponding differen",
          "tial expression data\n        to it, you can u",
          "pdate the 'from_deg' value to the name of a D",
          "EG set uploaded to\n        richStudio."
        )
      ))
    })
    observeEvent(input$cluslist_help, {
      showModal(modalDialog(
        title = "Help",
        "Display some informational message here..."
      ))
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
      big_rrdf_to_table(),
      editable = "cell"
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

    # reactively update which rr table is read based on selection
    rr_to_table <- reactive({
      req(input$rr_table_select)
      df <- u_rrdfs[[input$rr_table_select]]
      return(df)
    })

    # output rr table
    output$rr_table <- DT::renderDataTable({
      rr_to_table()
    })

    # download rr
    output$download_rr <- downloadHandler(
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

    # NOTE: Old clustering logic removed. Clustering is now handled by
    # cluster_tab module
    # which uses perform_clustering() from rr_cluster.R

    # Reactively update created cluster result dataframe
    big_clusdf_to_table <- reactive({
      u_big_clusdf[["df"]]
    })
    # Output uploaded file table
    output$clus_list_table <- DT::renderDT(
      big_clusdf_to_table(),
      editable = "cell"
    )
    # Cluslist table editing code
    observeEvent(input$clus_list_table_cell_edit, {
      info <- input$clus_list_table_cell_edit
      i <- info$row
      j <- info$col
      v <- info$value

      # Rename clus if changing a value in column 1 (name col)
      if (info$col == 1) {
        new_name <- v
        old_name <- u_big_clusdf[["df"]][i, j]
        if (nchar(new_name) > 0 && nchar(old_name) > 0) {
          # Copy data to new name
          u_clusdfs[[new_name]] <- u_clusdfs[[old_name]]
          u_cluslists[[new_name]] <- u_cluslists[[old_name]]
          # Remove old name from reactive values
          u_clusdfs[[old_name]] <- NULL
          u_cluslists[[old_name]] <- NULL
          # Update labels
          u_clusnames$labels <- setdiff(u_clusnames$labels, old_name)
          u_clusnames$labels <- c(u_clusnames$labels, new_name)
        }
      }
      # Update u_big_clusdf - Fix anti-pattern: Modify data frame locally, then
      # assign once
      updated_df <- u_big_clusdf[["df"]]
      updated_df[i, j] <- DT::coerceValue(v, updated_df[i, j])
      u_big_clusdf[["df"]] <- updated_df
    })

    # Remove clus from list of created cluster results
    observeEvent(input$remove_clus, {
      req(input$clus_list_table_rows_selected)

      # Also remove from clusdfs, cluslists, and clusnames
      for (clus in input$clus_list_table_rows_selected) {
        clus_to_rm <- u_big_clusdf[["df"]][clus, ]
        clus_to_rm <- clus_to_rm$name

        # Properly remove from reactive values using NULL assignment
        u_clusdfs[[clus_to_rm]] <- NULL
        u_cluslists[[clus_to_rm]] <- NULL
        u_clusnames$labels <- setdiff(u_clusnames$labels, clus_to_rm)
      }

      # Remove selection from u_big_clusdf
      rm_vec <- u_big_clusdf[["df"]][input$clus_list_table_rows_selected, ]
      u_big_clusdf[["df"]] <- rm_file_clusdf(u_big_clusdf[["df"]], rm_vec)
    })

    # Reactively update which cluster result is read based on selection
    clusdf_to_table <- reactive({
      req(input$clus_table_select)
      df <- u_clusdfs[[input$clus_table_select]]
      return(df)
    })
    # Output cluster result table
    output$clus_table <- DT::renderDataTable({
      clusdf_to_table()
    })

    # Download cluster result
    output$download_clus <- downloadHandler(
      filename = function() {
        req(input$clus_table_select)
        paste0(
          sanitize_filename(input$clus_table_select),
          input$clus_export_type
        )
      },
      content = function(file) {
        ext_type <- input$clus_export_type
        if (ext_type == ".txt") {
          write.table(
            u_clusdfs[[input$clus_table_select]],
            file,
            sep = "\t",
            row.names = FALSE
          )
        } else if (ext_type == ".csv") {
          write.csv(
            u_clusdfs[[input$clus_table_select]],
            file,
            row.names = FALSE
          )
        } else if (ext_type == ".tsv") {
          write.table(
            u_clusdfs[[input$clus_table_select]],
            file,
            sep = "\t",
            row.names = FALSE
          )
        }
      }
    )
  })
}
