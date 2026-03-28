# Update Tab Module
#
# This module provides functionality to rename and remove DEG sets,
# enrichment results, and clustering results.
#
# @author richStudio Development Team

#' Update Tab UI
#'
#' @param id Module namespace ID
#' @param tabName Tab identifier for shinydashboard
#' @return A tabItem containing the update UI
#' @export
updateTabUI <- function(id, tabName) {
  ns <- NS(id)
  tabItem(tabName = tabName,
    h2("Manage Files"),
    p("Rename or remove uploaded files and analysis results."),

    fluidRow(
      # Rename box
      column(width = 6,
        box(title = "Rename", status = "primary", width = NULL, solidHeader = TRUE,
          h4("Rename DEG Set"),
          selectInput(ns("rename_deg_select"), "Select DEG set", choices = NULL, multiple = FALSE),
          textInput(ns("new_deg_name"), "New name", placeholder = "Enter new name"),
          actionButton(ns('rename_deg_btn'), "Rename DEG", class = "btn-primary"),
          hr(),

          h4("Rename Enrichment Result"),
          selectInput(ns("rename_rr_select"), "Select enrichment result", choices = NULL, multiple = FALSE),
          textInput(ns("new_rr_name"), "New name", placeholder = "Enter new name"),
          actionButton(ns('rename_rr_btn'), "Rename Result", class = "btn-primary"),
          hr(),

          h4("Rename Cluster Result"),
          selectInput(ns("rename_clus_select"), "Select cluster result", choices = NULL, multiple = FALSE),
          textInput(ns("new_clus_name"), "New name", placeholder = "Enter new name"),
          actionButton(ns('rename_clus_btn'), "Rename Cluster", class = "btn-primary")
        )
      ),

      # Remove box
      column(width = 6,
        box(title = "Remove", status = "danger", width = NULL, solidHeader = TRUE,
          h4("Remove DEG Sets"),
          selectInput(ns("remove_deg_select"), "Select DEG sets to remove",
                     choices = NULL, multiple = TRUE),
          actionButton(ns('remove_deg_btn'), "Remove Selected DEGs", class = "btn-danger"),
          hr(),

          h4("Remove Enrichment Results"),
          selectInput(ns("remove_rr_select"), "Select enrichment results to remove",
                     choices = NULL, multiple = TRUE),
          actionButton(ns('remove_rr_btn'), "Remove Selected Results", class = "btn-danger"),
          hr(),

          h4("Remove Cluster Results"),
          selectInput(ns("remove_clus_select"), "Select cluster results to remove",
                     choices = NULL, multiple = TRUE),
          actionButton(ns('remove_clus_btn'), "Remove Selected Clusters", class = "btn-danger")
        )
      )
    )
  )
}


#' Update Tab Server
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
updateTabServer <- function(id, u_degnames, u_degdfs, u_rrnames, u_rrdfs,
                            u_clusnames, u_clusdfs, u_cluslists) {

  moduleServer(id, function(input, output, session) {

    # Create reactive expressions for the labels
    u_degnames_reactive <- reactive({
      if (is.null(u_degnames$labels)) character(0) else u_degnames$labels
    })
    u_rrnames_reactive <- reactive({
      if (is.null(u_rrnames$labels)) character(0) else u_rrnames$labels
    })
    u_clusnames_reactive <- reactive({
      if (is.null(u_clusnames$labels)) character(0) else u_clusnames$labels
    })

    # Update select inputs based on available files
    observe({
      updateSelectInput(session, 'rename_deg_select', choices = u_degnames_reactive())
      updateSelectInput(session, 'remove_deg_select', choices = u_degnames_reactive())

      updateSelectInput(session, 'rename_rr_select', choices = u_rrnames_reactive())
      updateSelectInput(session, 'remove_rr_select', choices = u_rrnames_reactive())

      updateSelectInput(session, 'rename_clus_select', choices = u_clusnames_reactive())
      updateSelectInput(session, 'remove_clus_select', choices = u_clusnames_reactive())
    })

    # ============================================
    # RENAME FUNCTIONS
    # ============================================

    # Rename DEG
    observeEvent(input$rename_deg_btn, {
      old_name <- input$rename_deg_select
      new_name <- trimws(input$new_deg_name)

      if (is.null(old_name) || nchar(old_name) == 0) {
        showNotification("Please select a DEG set to rename", type = "warning")
        return()
      }
      if (nchar(new_name) == 0) {
        showNotification("Please enter a new name", type = "warning")
        return()
      }
      if (new_name %in% u_degnames$labels) {
        showNotification("A DEG set with this name already exists", type = "error")
        return()
      }

      # Copy data to new name
      u_degdfs[[new_name]] <- u_degdfs[[old_name]]
      # Remove old name from reactive values
      u_degdfs[[old_name]] <- NULL
      # Update labels
      u_degnames$labels <- setdiff(u_degnames$labels, old_name)
      u_degnames$labels <- c(u_degnames$labels, new_name)

      # Clear the text input
      updateTextInput(session, "new_deg_name", value = "")
      showNotification(paste("Renamed", old_name, "to", new_name), type = "message")
    })

    # Rename enrichment result
    observeEvent(input$rename_rr_btn, {
      old_name <- input$rename_rr_select
      new_name <- trimws(input$new_rr_name)

      if (is.null(old_name) || nchar(old_name) == 0) {
        showNotification("Please select an enrichment result to rename", type = "warning")
        return()
      }
      if (nchar(new_name) == 0) {
        showNotification("Please enter a new name", type = "warning")
        return()
      }
      if (new_name %in% u_rrnames$labels) {
        showNotification("An enrichment result with this name already exists", type = "error")
        return()
      }

      # Copy data to new name
      u_rrdfs[[new_name]] <- u_rrdfs[[old_name]]
      # Remove old name from reactive values
      u_rrdfs[[old_name]] <- NULL
      # Update labels
      u_rrnames$labels <- setdiff(u_rrnames$labels, old_name)
      u_rrnames$labels <- c(u_rrnames$labels, new_name)

      # Clear the text input
      updateTextInput(session, "new_rr_name", value = "")
      showNotification(paste("Renamed", old_name, "to", new_name), type = "message")
    })

    # Rename cluster result
    observeEvent(input$rename_clus_btn, {
      old_name <- input$rename_clus_select
      new_name <- trimws(input$new_clus_name)

      if (is.null(old_name) || nchar(old_name) == 0) {
        showNotification("Please select a cluster result to rename", type = "warning")
        return()
      }
      if (nchar(new_name) == 0) {
        showNotification("Please enter a new name", type = "warning")
        return()
      }
      if (new_name %in% u_clusnames$labels) {
        showNotification("A cluster result with this name already exists", type = "error")
        return()
      }

      # Copy data to new name
      u_clusdfs[[new_name]] <- u_clusdfs[[old_name]]
      u_cluslists[[new_name]] <- u_cluslists[[old_name]]
      # Remove old name from reactive values
      u_clusdfs[[old_name]] <- NULL
      u_cluslists[[old_name]] <- NULL
      # Update labels
      u_clusnames$labels <- setdiff(u_clusnames$labels, old_name)
      u_clusnames$labels <- c(u_clusnames$labels, new_name)

      # Clear the text input
      updateTextInput(session, "new_clus_name", value = "")
      showNotification(paste("Renamed", old_name, "to", new_name), type = "message")
    })

    # ============================================
    # REMOVE FUNCTIONS
    # ============================================

    # Remove DEG sets - show confirmation dialog
    observeEvent(input$remove_deg_btn, {
      to_remove <- input$remove_deg_select
      if (is.null(to_remove) || length(to_remove) == 0) {
        showNotification("Please select DEG sets to remove", type = "warning")
        return()
      }
      ns <- session$ns
      showModal(modalDialog(
        title = "Confirm Removal",
        div(class = "modal-confirm",
          p(icon("triangle-exclamation"),
            sprintf("Remove %d DEG set(s)?", length(to_remove))),
          tags$ul(lapply(to_remove, tags$li))
        ),
        footer = tagList(
          modalButton("Cancel"),
          actionButton(ns("confirm_remove_deg"), "Remove", class = "btn-danger")
        ),
        easyClose = TRUE
      ))
    })

    observeEvent(input$confirm_remove_deg, {
      to_remove <- input$remove_deg_select
      for (name in to_remove) {
        u_degdfs[[name]] <- NULL
      }
      u_degnames$labels <- setdiff(u_degnames$labels, to_remove)
      removeModal()
      showNotification(paste("Removed", length(to_remove), "DEG set(s)"), type = "message")
    })

    # Remove enrichment results - show confirmation dialog
    observeEvent(input$remove_rr_btn, {
      to_remove <- input$remove_rr_select
      if (is.null(to_remove) || length(to_remove) == 0) {
        showNotification("Please select enrichment results to remove", type = "warning")
        return()
      }
      ns <- session$ns
      showModal(modalDialog(
        title = "Confirm Removal",
        div(class = "modal-confirm",
          p(icon("triangle-exclamation"),
            sprintf("Remove %d enrichment result(s)?", length(to_remove))),
          tags$ul(lapply(to_remove, tags$li))
        ),
        footer = tagList(
          modalButton("Cancel"),
          actionButton(ns("confirm_remove_rr"), "Remove", class = "btn-danger")
        ),
        easyClose = TRUE
      ))
    })

    observeEvent(input$confirm_remove_rr, {
      to_remove <- input$remove_rr_select
      for (name in to_remove) {
        u_rrdfs[[name]] <- NULL
      }
      u_rrnames$labels <- setdiff(u_rrnames$labels, to_remove)
      removeModal()
      showNotification(paste("Removed", length(to_remove), "enrichment result(s)"), type = "message")
    })

    # Remove cluster results - show confirmation dialog
    observeEvent(input$remove_clus_btn, {
      to_remove <- input$remove_clus_select
      if (is.null(to_remove) || length(to_remove) == 0) {
        showNotification("Please select cluster results to remove", type = "warning")
        return()
      }
      ns <- session$ns
      showModal(modalDialog(
        title = "Confirm Removal",
        div(class = "modal-confirm",
          p(icon("triangle-exclamation"),
            sprintf("Remove %d cluster result(s)?", length(to_remove))),
          tags$ul(lapply(to_remove, tags$li))
        ),
        footer = tagList(
          modalButton("Cancel"),
          actionButton(ns("confirm_remove_clus"), "Remove", class = "btn-danger")
        ),
        easyClose = TRUE
      ))
    })

    observeEvent(input$confirm_remove_clus, {
      to_remove <- input$remove_clus_select
      for (name in to_remove) {
        u_clusdfs[[name]] <- NULL
        u_cluslists[[name]] <- NULL
      }
      u_clusnames$labels <- setdiff(u_clusnames$labels, to_remove)
      removeModal()
      showNotification(paste("Removed", length(to_remove), "cluster result(s)"), type = "message")
    })
  })
}
