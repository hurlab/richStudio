# Save/Load Tab Module
#
# This module provides functionality to save and load analysis sessions,
# allowing users to continue their work without re-running analyses.
#
# @author richStudio Development Team

#' Save Tab UI
#'
#' @param id Module namespace ID
#' @param tabName Tab identifier for shinydashboard
#' @return A tabItem containing the save/load UI
#' @export
saveTabUI <- function(id, tabName) {
  ns <- NS(id)
  tabItem(tabName = tabName,
    h2("Save & Load Analysis Session"),
    p("Save your current analysis session or load a previously saved session."),

    fluidRow(
      # Save session box
      column(width = 6,
        box(title = "Save Session", status = "primary", width = NULL, solidHeader = TRUE,
          p("Download your current analysis state including:"),
          tags$ul(
            tags$li("DEG sets"),
            tags$li("Enrichment results"),
            tags$li("Clustering results"),
            tags$li("Session settings")
          ),
          hr(),
          textInput(ns('session_name'), "Session name",
                   value = paste0("richstudio_session_", format(Sys.Date(), "%Y%m%d"))),
          radioButtons(ns('save_format'), "Save format:",
            choices = c(
              "RDS (Recommended)" = "rds",
              "JSON (Portable)" = "json"
            ),
            selected = "rds"
          ),
          br(),
          downloadButton(ns('download_session'), "Download Session", class = "btn-primary btn-lg"),
          br(), br(),
          helpText("RDS format preserves all R objects exactly. JSON format is more portable but may lose some data types.")
        )
      ),

      # Load session box
      column(width = 6,
        box(title = "Load Session", status = "success", width = NULL, solidHeader = TRUE,
          p("Upload a previously saved session file to restore your analysis state."),
          hr(),
          fileInput(ns('load_session_file'), "Choose session file",
                   accept = c('.rds', '.json', '.RDS', '.JSON')),
          br(),
          actionButton(ns('load_session'), "Load Session", class = "btn-success btn-lg"),
          br(), br(),
          helpText("Loading a session will replace your current analysis state.")
        )
      )
    ),

    # Session info box
    fluidRow(
      column(width = 12,
        box(title = "Current Session Summary", status = "info", width = NULL, collapsible = TRUE,
          fluidRow(
            column(width = 4,
              h4("DEG Sets"),
              verbatimTextOutput(ns('deg_summary'))
            ),
            column(width = 4,
              h4("Enrichment Results"),
              verbatimTextOutput(ns('rr_summary'))
            ),
            column(width = 4,
              h4("Clustering Results"),
              verbatimTextOutput(ns('clus_summary'))
            )
          )
        )
      )
    ),

    # Export individual results
    fluidRow(
      column(width = 12,
        box(title = "Export Individual Results", status = "warning", width = NULL, collapsible = TRUE, collapsed = TRUE,
          p("Export specific results as individual files."),
          fluidRow(
            column(width = 4,
              h4("Export Enrichment Result"),
              selectInput(ns('export_rr_select'), "Select result", choices = NULL),
              selectInput(ns('export_rr_format'), "Format",
                         choices = c("CSV" = "csv", "TSV" = "tsv", "Excel" = "xlsx")),
              downloadButton(ns('export_rr'), "Export")
            ),
            column(width = 4,
              h4("Export Clustering Result"),
              selectInput(ns('export_clus_select'), "Select result", choices = NULL),
              selectInput(ns('export_clus_format'), "Format",
                         choices = c("CSV" = "csv", "TSV" = "tsv", "Excel" = "xlsx")),
              downloadButton(ns('export_clus'), "Export")
            ),
            column(width = 4,
              h4("Export All Results"),
              p("Download all results as a ZIP archive"),
              downloadButton(ns('export_all'), "Export All")
            )
          )
        )
      )
    )
  )
}


#' Save Tab Server
#'
#' @param id Module namespace ID
#' @param u_degnames Reactive values for DEG names
#' @param u_degdfs Reactive values for DEG dataframes
#' @param u_rrnames Reactive values for enrichment result names
#' @param u_rrdfs Reactive values for enrichment result dataframes
#' @param u_clusnames Reactive values for cluster result names
#' @param u_clusdfs Reactive values for cluster result dataframes
#' @param u_cluslists Reactive values for cluster list details
#' @export
saveTabServer <- function(id, u_degnames, u_degdfs, u_rrnames, u_rrdfs,
                          u_clusnames, u_clusdfs, u_cluslists) {

  moduleServer(id, function(input, output, session) {

    # Update select inputs
    observe({
      updateSelectInput(session, 'export_rr_select', choices = u_rrnames$labels)
      updateSelectInput(session, 'export_clus_select', choices = u_clusnames$labels)
    })

    # Session summaries
    output$deg_summary <- renderText({
      n <- length(u_degnames$labels)
      if (n == 0) {
        "No DEG sets loaded"
      } else {
        paste0(n, " DEG set(s):\n", paste(u_degnames$labels, collapse = "\n"))
      }
    })

    output$rr_summary <- renderText({
      n <- length(u_rrnames$labels)
      if (n == 0) {
        "No enrichment results"
      } else {
        paste0(n, " enrichment result(s):\n", paste(u_rrnames$labels, collapse = "\n"))
      }
    })

    output$clus_summary <- renderText({
      n <- length(u_clusnames$labels)
      if (n == 0) {
        "No clustering results"
      } else {
        paste0(n, " clustering result(s):\n", paste(u_clusnames$labels, collapse = "\n"))
      }
    })

    # Download session handler
    output$download_session <- downloadHandler(
      filename = function() {
        ext <- if (input$save_format == "rds") ".rds" else ".json"
        paste0(input$session_name, ext)
      },
      content = function(file) {
        # Collect all session data
        session_data <- list(
          version = "1.0",
          created = Sys.time(),
          degnames = u_degnames$labels,
          degdfs = reactiveValuesToList(u_degdfs),
          rrnames = u_rrnames$labels,
          rrdfs = reactiveValuesToList(u_rrdfs),
          clusnames = u_clusnames$labels,
          clusdfs = reactiveValuesToList(u_clusdfs),
          cluslists = reactiveValuesToList(u_cluslists)
        )

        if (input$save_format == "rds") {
          saveRDS(session_data, file)
        } else {
          # JSON export (convert data frames appropriately)
          json_data <- session_data
          json_data$degdfs <- lapply(json_data$degdfs, function(df) {
            if (is.data.frame(df)) as.list(df) else df
          })
          json_data$rrdfs <- lapply(json_data$rrdfs, function(df) {
            if (is.data.frame(df)) as.list(df) else df
          })
          json_data$clusdfs <- lapply(json_data$clusdfs, function(df) {
            if (is.data.frame(df)) as.list(df) else df
          })
          json_data$cluslists <- lapply(json_data$cluslists, function(df) {
            if (is.data.frame(df)) as.list(df) else df
          })
          jsonlite::write_json(json_data, file, auto_unbox = TRUE, pretty = TRUE)
        }

        showNotification("Session saved successfully!", type = "message")
      }
    )

    # Load session handler
    observeEvent(input$load_session, {
      req(input$load_session_file)

      tryCatch({
        file_path <- input$load_session_file$datapath
        file_ext <- tools::file_ext(input$load_session_file$name)

        if (tolower(file_ext) == "rds") {
          session_data <- readRDS(file_path)
        } else if (tolower(file_ext) == "json") {
          session_data <- jsonlite::read_json(file_path, simplifyVector = TRUE)
          # Convert lists back to data frames
          session_data$degdfs <- lapply(session_data$degdfs, as.data.frame)
          session_data$rrdfs <- lapply(session_data$rrdfs, as.data.frame)
          session_data$clusdfs <- lapply(session_data$clusdfs, as.data.frame)
          session_data$cluslists <- lapply(session_data$cluslists, as.data.frame)
        } else {
          stop("Unsupported file format. Use .rds or .json files.")
        }

        # Validate session version compatibility
        current_version <- "1.0"
        if (!is.null(session_data$version)) {
          session_version <- as.character(session_data$version)
          # Compare major versions (before the decimal)
          current_major <- as.integer(strsplit(current_version, "\\.")[[1]][1])
          session_major <- as.integer(strsplit(session_version, "\\.")[[1]][1])

          if (session_major > current_major) {
            showNotification(
              paste("Warning: This session was created with a newer version of richStudio (v",
                    session_version, "). Some features may not work correctly."),
              type = "warning",
              duration = 10
            )
          }
        } else {
          # Very old session without version info
          showNotification(
            "Note: This session was created with an older version of richStudio.",
            type = "message",
            duration = 5
          )
        }

        # Restore session data
        u_degnames$labels <- session_data$degnames
        for (name in names(session_data$degdfs)) {
          u_degdfs[[name]] <- session_data$degdfs[[name]]
        }

        u_rrnames$labels <- session_data$rrnames
        for (name in names(session_data$rrdfs)) {
          u_rrdfs[[name]] <- session_data$rrdfs[[name]]
        }

        u_clusnames$labels <- session_data$clusnames
        for (name in names(session_data$clusdfs)) {
          u_clusdfs[[name]] <- session_data$clusdfs[[name]]
        }
        for (name in names(session_data$cluslists)) {
          u_cluslists[[name]] <- session_data$cluslists[[name]]
        }

        showNotification(
          paste("Session loaded successfully! Created:", session_data$created),
          type = "message",
          duration = 5
        )

      }, error = function(e) {
        showNotification(paste("Error loading session:", e$message), type = "error")
      })
    })

    # Export enrichment result
    output$export_rr <- downloadHandler(
      filename = function() {
        req(input$export_rr_select)
        paste0(input$export_rr_select, ".", input$export_rr_format)
      },
      content = function(file) {
        req(input$export_rr_select)
        df <- u_rrdfs[[input$export_rr_select]]

        # Validate data exists before export
        if (is.null(df)) {
          showNotification(
            paste("No data found for:", input$export_rr_select),
            type = "error"
          )
          return(NULL)
        }

        if (nrow(df) == 0) {
          showNotification(
            paste("Dataset is empty:", input$export_rr_select),
            type = "warning"
          )
        }

        if (input$export_rr_format == "csv") {
          write.csv(df, file, row.names = FALSE)
        } else if (input$export_rr_format == "tsv") {
          write.table(df, file, sep = "\t", row.names = FALSE)
        } else if (input$export_rr_format == "xlsx") {
          writexl::write_xlsx(df, file)
        }
      }
    )

    # Export clustering result
    output$export_clus <- downloadHandler(
      filename = function() {
        req(input$export_clus_select)
        paste0(input$export_clus_select, ".", input$export_clus_format)
      },
      content = function(file) {
        req(input$export_clus_select)
        df <- u_clusdfs[[input$export_clus_select]]

        # Validate data exists before export
        if (is.null(df)) {
          showNotification(
            paste("No data found for:", input$export_clus_select),
            type = "error"
          )
          return(NULL)
        }

        if (nrow(df) == 0) {
          showNotification(
            paste("Dataset is empty:", input$export_clus_select),
            type = "warning"
          )
        }

        if (input$export_clus_format == "csv") {
          write.csv(df, file, row.names = FALSE)
        } else if (input$export_clus_format == "tsv") {
          write.table(df, file, sep = "\t", row.names = FALSE)
        } else if (input$export_clus_format == "xlsx") {
          writexl::write_xlsx(df, file)
        }
      }
    )

    # Export all results as ZIP
    output$export_all <- downloadHandler(
      filename = function() {
        paste0("richstudio_export_", format(Sys.Date(), "%Y%m%d"), ".zip")
      },
      content = function(file) {
        # Create temporary directory
        temp_dir <- tempdir()
        export_dir <- file.path(temp_dir, "richstudio_export")
        dir.create(export_dir, showWarnings = FALSE, recursive = TRUE)

        # Export DEG sets
        if (length(u_degnames$labels) > 0) {
          deg_dir <- file.path(export_dir, "deg_sets")
          dir.create(deg_dir, showWarnings = FALSE)
          for (name in u_degnames$labels) {
            df <- u_degdfs[[name]]
            if (!is.null(df)) {
              write.csv(df, file.path(deg_dir, paste0(name, ".csv")), row.names = FALSE)
            }
          }
        }

        # Export enrichment results
        if (length(u_rrnames$labels) > 0) {
          rr_dir <- file.path(export_dir, "enrichment_results")
          dir.create(rr_dir, showWarnings = FALSE)
          for (name in u_rrnames$labels) {
            df <- u_rrdfs[[name]]
            if (!is.null(df)) {
              write.csv(df, file.path(rr_dir, paste0(name, ".csv")), row.names = FALSE)
            }
          }
        }

        # Export clustering results
        if (length(u_clusnames$labels) > 0) {
          clus_dir <- file.path(export_dir, "clustering_results")
          dir.create(clus_dir, showWarnings = FALSE)
          for (name in u_clusnames$labels) {
            df <- u_clusdfs[[name]]
            if (!is.null(df)) {
              write.csv(df, file.path(clus_dir, paste0(name, ".csv")), row.names = FALSE)
            }
          }
        }

        # Create ZIP file
        old_wd <- getwd()
        setwd(temp_dir)
        zip::zip(file, files = "richstudio_export", recurse = TRUE)
        setwd(old_wd)

        showNotification("All results exported!", type = "message")
      }
    )
  })
}
