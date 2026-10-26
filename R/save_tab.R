# Save/Load Tab Module
#
# This module provides functionality to save and load analysis sessions,
# allowing users to continue their work without re-running analyses.
#
# @author richStudio Development Team

#' Sanitize a string for safe use as a filename
#'
#' Removes path separators, shell-dangerous characters, and leading dots
#' to prevent path traversal and hidden file creation.
#'
#' @param name Character string to sanitize
#' @return A safe filename string
sanitize_filename <- function(name) {
  # Remove path separators and dangerous characters
  name <- gsub("[/\\\\:*?\"<>|]", "_", name)
  # Remove leading dots (hidden files)
  name <- gsub("^\\.+", "", name)
  # Fallback if empty
  if (nchar(name) == 0) name <- "export"
  return(name)
}

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
                   value = paste0("richstudio_session_",
                                  format(Sys.time(), "%Y%m%d_%H%M%S"), "_",
                                  paste0(sample(c(letters, 0:9), 8, replace = TRUE), collapse = ""))),
          br(),
          downloadButton(ns('download_session'), "Download Session", class = "btn-primary btn-lg"),
          br(), br(),
          helpText("Sessions are saved as JSON with full numeric precision, so values reload exactly. Older .rds session files cannot be uploaded; convert them locally first (see docs/SESSION_FILES.md)."),
          hr(),
          h4("Reproducible project"),
          p("A project (.zip) adds a manifest with parameters, versions, statistics and a generated methods summary to the exact tables."),
          downloadButton(ns('download_project'), "Download Project", class = "btn-default")
        )
      ),

      # Load session box
      column(width = 6,
        box(title = "Load Session", status = "success", width = NULL, solidHeader = TRUE,
          p("Upload a previously saved JSON session file to restore your analysis state."),
          hr(),
          fileInput(ns('load_session_file'), "Choose session file",
                   accept = c('.json', '.JSON')),
          br(),
          actionButton(ns('load_session'), "Load Session", class = "btn-success btn-lg"),
          br(), br(),
          helpText("Loading a session will replace your current analysis state."),
          hr(),
          h4("Open a project"),
          fileInput(ns('load_project_file'), "Choose project file",
                   accept = c('.zip', '.ZIP')),
          actionButton(ns('load_project'), "Open Project", class = "btn-default"),
          helpText("A project is checked completely before anything is replaced; a rejected project changes nothing.")
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
          checkboxInput(ns('export_safe'),
                        "Spreadsheet-safe text (prefix cells that begin with = + - @ so a spreadsheet does not run them as formulas)",
                        value = TRUE),
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
#' @param download_handler Download handler factory; defaults to Shiny's handler
#' @export
saveTabServer <- function(id, u_degnames, u_degdfs, u_rrnames, u_rrdfs,
                          u_clusnames, u_clusdfs, u_cluslists,
                          download_handler = downloadHandler) {

  moduleServer(id, function(input, output, session) {
    jobs <- workspace_jobs_peek(session)

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

    # Cleared entries stay as NULL-valued keys in a reactiveValues; they are not data.
    # all.names keeps labels that start with a dot.
    live_values <- function(rv) Filter(Negate(is.null), reactiveValuesToList(rv, all.names = TRUE))

    # The session as a plain list: what both the JSON session and the project save.
    session_snapshot <- function() {
      list(
        version = "1.0",
        created = Sys.time(),
        degnames = u_degnames$labels,
        degdfs = live_values(u_degdfs),
        rrnames = u_rrnames$labels,
        rrdfs = live_values(u_rrdfs),
        clusnames = u_clusnames$labels,
        clusdfs = live_values(u_clusdfs),
        cluslists = live_values(u_cluslists)
      )
    }

    stores <- list(u_degnames = u_degnames, u_degdfs = u_degdfs, u_rrnames = u_rrnames,
                   u_rrdfs = u_rrdfs, u_clusnames = u_clusnames, u_clusdfs = u_clusdfs,
                   u_cluslists = u_cluslists)

    # Download session handler
    output$download_session <- download_handler(
      filename = function() {
        paste0(sanitize_filename(input$session_name), ".json")
      },
      content = function(file) {
        # Collect all session data
        session_data <- session_snapshot()
        if (!is.null(jobs)) session_data$run_records_json <- workspace_run_records_json(workspace_run_records(jobs))

        # Use advisory file locking to prevent concurrent write corruption
        lock_path <- paste0(file, ".lock")
        lock_conn <- tryCatch(file(lock_path, open = "w"), error = function(e) NULL)
        if (is.null(lock_conn)) {
          showNotification("Could not acquire file lock. Save aborted.", type = "error")
          return(NULL)
        }
        on.exit({ close(lock_conn); unlink(lock_path) }, add = TRUE)

        session_json_write(session_data, file)

        showNotification("Session saved successfully!", type = "message")
      }
    )

    # Download project handler: manifest + exact tables + methods text in one ZIP.
    # Plain downloadHandler: download_handler stays the JSON session's injection seam.
    output$download_project <- downloadHandler(
      filename = function() {
        paste0(sanitize_filename(input$session_name), ".zip")
      },
      content = function(file) {
        records <- if (is.null(jobs)) list() else workspace_run_records(jobs)
        saved <- tryCatch({
          project_write(session_snapshot(), records, file)
          TRUE
        }, error = function(e) {
          showNotification(paste("Project could not be saved:", conditionMessage(e)), type = "error")
          FALSE
        })
        if (saved) showNotification("Project saved successfully!", type = "message")
      }
    )

    # Load session handler
    observeEvent(input$load_session, {
      req(input$load_session_file)

      tryCatch({
        file_path <- input$load_session_file$datapath
        file_ext <- tools::file_ext(input$load_session_file$name)

        # Refuse anything but JSON before the file is opened: deserializing an
        # uploaded RDS can execute attacker-chosen code on the server.
        if (tolower(file_ext) != "json" || session_json_looks_like_rds(file_path)) {
          showNotification(
            paste("Only JSON session files can be uploaded. RDS session files are not",
                  "accepted because loading them is unsafe on a shared server. To convert",
                  "an .rds file you trust, run on your own computer:",
                  "Rscript scripts/convert-trusted-session.R session.rds session.json",
                  "and upload the .json file (see docs/SESSION_FILES.md)."),
            type = "error", duration = NULL
          )
          return(NULL)
        }

        # Check for advisory lock from a concurrent save operation
        lock_path <- paste0(file_path, ".lock")
        if (file.exists(lock_path)) {
          # Wait briefly for lock to clear (up to 3 seconds)
          lock_cleared <- FALSE
          for (i in seq_len(6)) {
            Sys.sleep(0.5)
            if (!file.exists(lock_path)) {
              lock_cleared <- TRUE
              break
            }
          }
          if (!lock_cleared) {
            showNotification(
              "Session file is currently being written. Please try again shortly.",
              type = "warning"
            )
            return(NULL)
          }
        }

        session_data <- session_json_read(file_path)
        if (is.null(session_data$version)) {
          showNotification("Invalid session file format", type = "error")
          return(NULL)
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

        # Validate the whole candidate, then apply it in one swap (job generation
        # invalidated first); a malformed file never reaches the stores.
        candidate <- project_legacy_candidate(session_data)
        project_commit_candidate(candidate, stores, jobs)

        showNotification(
          paste("Session loaded successfully! Created:", session_data$created),
          type = "message",
          duration = 5
        )

      }, error = function(e) {
        showNotification(paste("Error loading session:", e$message), type = "error")
      })
    })

    # Open project handler: the archive is validated completely into a data-only
    # candidate before the workspace or any job is touched.
    observeEvent(input$load_project, {
      req(input$load_project_file)
      file_path <- input$load_project_file$datapath
      candidate <- tryCatch(project_import_read(file_path), error = function(e) e)
      if (inherits(candidate, "error")) {
        # Only validation messages (written for the user) are shown; anything else,
        # which may carry server paths, is replaced by a generic text.
        reason <- if (inherits(candidate, "richstudio_project_invalid")) conditionMessage(candidate) else
          "The file could not be read as a project"
        showNotification(paste("Project could not be opened:", reason),
                         type = "error", duration = NULL)
        return(NULL)
      }
      project_commit_candidate(candidate, stores, jobs)
      showNotification("Project opened successfully!", type = "message", duration = 5)
    })

    # Export enrichment result
    output$export_rr <- downloadHandler(
      filename = function() {
        req(input$export_rr_select)
        paste0(sanitize_filename(input$export_rr_select), ".", input$export_rr_format)
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

        if (isTRUE(input$export_safe) && input$export_rr_format != "xlsx") df <- project_spreadsheet_safe(df)
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
        paste0(sanitize_filename(input$export_clus_select), ".", input$export_clus_format)
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

        if (isTRUE(input$export_safe) && input$export_clus_format != "xlsx") df <- project_spreadsheet_safe(df)
        if (input$export_clus_format == "csv") {
          write.csv(df, file, row.names = FALSE)
        } else if (input$export_clus_format == "tsv") {
          write.table(df, file, sep = "\t", row.names = FALSE)
        } else if (input$export_clus_format == "xlsx") {
          writexl::write_xlsx(df, file)
        }
      }
    )

    # Labels are user text: archive members get a safe, unique file name instead.
    export_member_names <- function(labels) {
      paste0(make.unique(vapply(labels, sanitize_filename, character(1), USE.NAMES = FALSE), sep = "_"), ".csv")
    }

    # Export all results as ZIP
    output$export_all <- downloadHandler(
      filename = function() {
        paste0("richstudio_export_", format(Sys.time(), "%Y%m%d_%H%M%S"), "_",
               paste0(sample(c(letters, 0:9), 8, replace = TRUE), collapse = ""), ".zip")
      },
      content = function(file) {
        # Create a unique temporary directory per export to avoid collisions
        temp_dir <- tempfile(pattern = "richstudio_export_")
        dir.create(temp_dir, showWarnings = FALSE, recursive = TRUE)
        on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)
        export_dir <- file.path(temp_dir, "richstudio_export")
        dir.create(export_dir, showWarnings = FALSE, recursive = TRUE)

        # Export DEG sets
        if (length(u_degnames$labels) > 0) {
          deg_dir <- file.path(export_dir, "deg_sets")
          dir.create(deg_dir, showWarnings = FALSE)
          member_names <- export_member_names(u_degnames$labels)
          for (i in seq_along(u_degnames$labels)) {
            df <- u_degdfs[[u_degnames$labels[i]]]
            if (!is.null(df)) {
              if (isTRUE(input$export_safe)) df <- project_spreadsheet_safe(df)
              write.csv(df, file.path(deg_dir, member_names[i]), row.names = FALSE)
            }
          }
        }

        # Export enrichment results
        if (length(u_rrnames$labels) > 0) {
          rr_dir <- file.path(export_dir, "enrichment_results")
          dir.create(rr_dir, showWarnings = FALSE)
          member_names <- export_member_names(u_rrnames$labels)
          for (i in seq_along(u_rrnames$labels)) {
            df <- u_rrdfs[[u_rrnames$labels[i]]]
            if (!is.null(df)) {
              if (isTRUE(input$export_safe)) df <- project_spreadsheet_safe(df)
              write.csv(df, file.path(rr_dir, member_names[i]), row.names = FALSE)
            }
          }
        }

        # Export clustering results
        if (length(u_clusnames$labels) > 0) {
          clus_dir <- file.path(export_dir, "clustering_results")
          dir.create(clus_dir, showWarnings = FALSE)
          member_names <- export_member_names(u_clusnames$labels)
          for (i in seq_along(u_clusnames$labels)) {
            df <- u_clusdfs[[u_clusnames$labels[i]]]
            if (!is.null(df)) {
              if (isTRUE(input$export_safe)) df <- project_spreadsheet_safe(df)
              write.csv(df, file.path(clus_dir, member_names[i]), row.names = FALSE)
            }
          }
        }

        # Create ZIP file (use on.exit to safely restore working directory)
        old_wd <- getwd()
        on.exit(setwd(old_wd), add = TRUE)
        setwd(temp_dir)
        zip::zip(file, files = "richstudio_export", recurse = TRUE)

        showNotification("All results exported!", type = "message")
      }
    )
  })
}
