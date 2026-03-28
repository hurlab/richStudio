# Clustering Tab Module
#
# This module provides the UI and server logic for clustering enrichment results.
# It supports multiple clustering methods with dynamic parameter UI:
#   - richR (Original): Kappa-based clustering from richR package
#   - Hierarchical: Flexible clustering with selectable linkage methods
#   - DAVID: DAVID-style functional clustering algorithm
#
# @author richStudio Development Team

#' @importFrom dplyr %>% group_by mutate ungroup
#' @importFrom shiny NS moduleServer reactive observe observeEvent renderUI renderText
#'   updateSelectInput updateNumericInput req withProgress incProgress showNotification
#' @importFrom shinyjs hidden

# Null-coalescing operator
`%||%` <- function(x, y) if (is.null(x)) y else x

#' Cluster Tab UI
#'
#' @param id Module namespace ID
#' @param tabName Tab identifier for shinydashboard
#' @return A tabItem containing the clustering UI
#' @export
clusterTabUI <- function(id, tabName) {
  ns <- NS(id)
  tabItem(tabName = tabName,
    # Main clustering configuration box
    h2("Cluster Enrichment Results"),
    box(width = NULL,
      fluidRow(
        column(width = 6,
          h4("Select enrichment results"),
          selectInput(ns('selected_rrs'), "Select enrichment results to cluster",
                      choices = NULL, multiple = TRUE),
          helpText("Select one or more enrichment results to cluster together")
        ),
        column(width = 6,
          h4("Cluster group name"),
          textInput(ns('cluster_name'), "Choose a descriptive name", value = "Cluster_1"),
          helpText("This name will identify the clustering result")
        )
      ),
      hr(),

      # Clustering method selection
      fluidRow(
        column(width = 12,
          h4("Clustering Method"),
          uiOutput(ns('method_selector')),
          uiOutput(ns('method_description'))
        )
      ),
      hr(),

      # Dynamic parameter UI based on selected method
      uiOutput(ns('method_params_ui')),

      hr(),
      fluidRow(
        column(width = 12,
          actionButton(ns('cluster'), "Run Clustering",
                       icon = icon("play"), class = "btn-action-hero"),
          span(style = "margin-left: 16px;"),
          actionButton(ns('reset_params'), "Reset to Defaults",
                       icon = icon("rotate-left"), class = "btn-default")
        )
      )
    ),

    # Results display (hidden until clustering is done)
    shinyjs::hidden(tags$div(
      id = ns("cluster_results_box"),
      box(title = "Clustering Results", width = NULL, status = "success", solidHeader = TRUE,
        fluidRow(
          column(width = 6,
            h4("Cluster Summary"),
            DT::DTOutput(ns('cluster_summary_table'))
          ),
          column(width = 6,
            h4("Method Information"),
            verbatimTextOutput(ns('method_info'))
          )
        )
      )
    )),

    # Intermediate results (collapsible)
    shinyjs::hidden(tags$div(
      id = ns("cluster_intermediate_box"),
      box(title = "Intermediate Results (Advanced)", width = NULL, collapsible = TRUE, collapsed = TRUE,
        tabsetPanel(
          tabPanel(title = "Distance Matrix",
            p("Pairwise similarity scores between terms"),
            DT::DTOutput(ns('distanceMatrix_table'))
          ),
          tabPanel(title = "Cluster Details",
            p("Detailed cluster assignments"),
            DT::DTOutput(ns('cluster_details_table'))
          )
        )
      )
    ))
  )
}


#' Cluster Tab Server
#'
#' @param id Module namespace ID
#' @param u_degnames Reactive values for DEG names
#' @param u_degdfs Reactive values for DEG dataframes
#' @param u_rrnames Reactive values for enrichment result names
#' @param u_rrdfs Reactive values for enrichment result dataframes
#' @param u_big_rrdf Reactive values for combined enrichment data
#' @param u_clusnames Reactive values for cluster result names
#' @param u_clusdfs Reactive values for cluster result dataframes
#' @param u_big_clusdf Reactive values for combined cluster data
#' @param u_cluslists Reactive values for cluster list details
#' @param clus_intermed Reactive values for intermediate clustering results
#' @export
clusterTabServer <- function(id, u_degnames, u_degdfs, u_rrnames, u_rrdfs, u_big_rrdf,
                             u_clusnames, u_clusdfs, u_big_clusdf, u_cluslists, clus_intermed) {

  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Reactive for available enrichment results
    u_rrnames_reactive <- reactive(u_rrnames$labels)

    # Update enrichment result selector
    observe({
      updateSelectInput(session, 'selected_rrs', choices = u_rrnames_reactive())
    })

    # Dynamic method selector based on richCluster availability
    output$method_selector <- renderUI({
      # Check if richCluster is available
      richCluster_available <- is_richCluster_available()

      if (richCluster_available) {
        # All methods available, default to hierarchical
        radioButtons(ns('clustering_method'), NULL,
          choices = c(
            "Hierarchical Clustering" = "hierarchical",
            "DAVID Functional Clustering" = "david",
            "richR (Original Kappa)" = "richR"
          ),
          selected = "hierarchical",
          inline = TRUE
        )
      } else {
        # Only richR available
        tagList(
          radioButtons(ns('clustering_method'), NULL,
            choices = c(
              "richR (Original Kappa)" = "richR"
            ),
            selected = "richR",
            inline = TRUE
          ),
          tags$p(
            tags$em("Note: Install the richCluster package to enable Hierarchical and DAVID clustering methods."),
            style = "color: #856404; background-color: #fff3cd; padding: 8px; border-radius: 4px; margin-top: 5px;"
          )
        )
      }
    })

    # Method description output
    output$method_description <- renderUI({
      method <- input$clustering_method
      # Handle NULL case (when UI is first loading)
      if (is.null(method)) return(NULL)

      desc <- switch(method,
        "richR" = tags$span(
          tags$strong("Warning:", style = "color: #d9534f;"),
          " This method can be slow with large datasets. ",
          "Original Kappa-based clustering from the richR package. Groups terms based on gene overlap similarity using Cohen's Kappa coefficient."
        ),
        "hierarchical" = "Flexible hierarchical clustering with selectable distance metrics (Kappa/Jaccard) and linkage methods (single/complete/average/ward). Recommended for most use cases.",
        "david" = "DAVID-style functional clustering algorithm with multiple linkage thresholds for seed-based grouping.",
        NULL
      )
      if (is.null(desc)) return(NULL)
      tags$p(tags$em(desc), style = "color: #666; margin-top: 5px;")
    })

    # Dynamic parameter UI based on method
    output$method_params_ui <- renderUI({
      method <- input$clustering_method
      # Handle NULL case (when UI is first loading)
      if (is.null(method)) return(NULL)

      if (method == "richR") {
        # richR parameters
        fluidRow(
          column(width = 4,
            h4("Similarity Cutoff"),
            numericInput(ns('richR_cutoff'), "Kappa score cutoff",
                        value = 0.5, min = 0, max = 1, step = 0.05),
            helpText("Minimum Kappa similarity to consider terms related")
          ),
          column(width = 4,
            h4("Overlap"),
            numericInput(ns('richR_overlap'), "Overlap threshold",
                        value = 0.5, min = 0, max = 1, step = 0.05),
            helpText("Minimum overlap for cluster membership")
          ),
          column(width = 4,
            h4("Minimum Cluster Size"),
            numericInput(ns('richR_minSize'), "Min terms per cluster",
                        value = 2, min = 1, max = 20, step = 1),
            helpText("Clusters smaller than this are discarded")
          )
        )

      } else if (method == "hierarchical") {
        # Hierarchical clustering parameters
        tagList(
          fluidRow(
            column(width = 3,
              h4("Distance Metric"),
              selectInput(ns('hier_distance_metric'), NULL,
                choices = c("Kappa" = "kappa", "Jaccard" = "jaccard"),
                selected = "kappa"
              ),
              helpText("Similarity measure between terms")
            ),
            column(width = 3,
              h4("Distance Cutoff"),
              numericInput(ns('hier_distance_cutoff'), NULL,
                value = 0.5, min = 0, max = 1, step = 0.05
              ),
              helpText("Min similarity for initial grouping")
            ),
            column(width = 3,
              h4("Linkage Method"),
              selectInput(ns('hier_linkage_method'), NULL,
                choices = c("Average" = "average", "Single" = "single",
                           "Complete" = "complete", "Ward" = "ward"),
                selected = "average"
              ),
              helpText("How clusters are merged")
            ),
            column(width = 3,
              h4("Linkage Cutoff"),
              numericInput(ns('hier_linkage_cutoff'), NULL,
                value = 0.5, min = 0, max = 1, step = 0.05
              ),
              helpText("Cluster membership threshold")
            )
          ),
          fluidRow(
            column(width = 6,
              h4("Minimum Terms"),
              numericInput(ns('hier_min_terms'), "Min terms per cluster",
                value = 2, min = 1, max = 20, step = 1
              )
            ),
            column(width = 6,
              h4("P-value Filter"),
              numericInput(ns('hier_min_value'), "Max p-value to include",
                value = 0.1, min = 0, max = 1, step = 0.01
              ),
              helpText("Terms with higher p-values are excluded")
            )
          )
        )

      } else if (method == "david") {
        # DAVID parameters
        fluidRow(
          column(width = 3,
            h4("Similarity Threshold"),
            numericInput(ns('david_similarity'), "Kappa threshold",
              value = 0.5, min = 0, max = 1, step = 0.05
            ),
            helpText("Min Kappa for term similarity")
          ),
          column(width = 3,
            h4("Initial Group Size"),
            numericInput(ns('david_initial_membership'), "Initial membership",
              value = 3, min = 2, max = 10, step = 1
            ),
            helpText("Min terms for seed groups")
          ),
          column(width = 3,
            h4("Final Group Size"),
            numericInput(ns('david_final_membership'), "Final membership",
              value = 3, min = 2, max = 10, step = 1
            ),
            helpText("Min terms for final clusters")
          ),
          column(width = 3,
            h4("Linkage Threshold"),
            numericInput(ns('david_linkage'), "Multiple linkage",
              value = 0.5, min = 0, max = 1, step = 0.05
            ),
            helpText("Threshold for merging seeds")
          )
        )
      }
    })

    # Reset parameters to defaults
    observeEvent(input$reset_params, {
      method <- input$clustering_method

      if (method == "richR") {
        updateNumericInput(session, 'richR_cutoff', value = 0.5)
        updateNumericInput(session, 'richR_overlap', value = 0.5)
        updateNumericInput(session, 'richR_minSize', value = 2)
      } else if (method == "hierarchical") {
        updateSelectInput(session, 'hier_distance_metric', selected = "kappa")
        updateNumericInput(session, 'hier_distance_cutoff', value = 0.5)
        updateSelectInput(session, 'hier_linkage_method', selected = "average")
        updateNumericInput(session, 'hier_linkage_cutoff', value = 0.5)
        updateNumericInput(session, 'hier_min_terms', value = 2)
        updateNumericInput(session, 'hier_min_value', value = 0.1)
      } else if (method == "david") {
        updateNumericInput(session, 'david_similarity', value = 0.5)
        updateNumericInput(session, 'david_initial_membership', value = 3)
        updateNumericInput(session, 'david_final_membership', value = 3)
        updateNumericInput(session, 'david_linkage', value = 0.5)
      }

      showNotification("Parameters reset to defaults", type = "message")
    })

    # Main clustering logic
    observeEvent(input$cluster, {
      req(input$selected_rrs)
      req(input$cluster_name)

      # 1. Collect ALL reactive inputs before future
      selected_rrs <- as.vector(input$selected_rrs)
      cluster_name <- input$cluster_name
      method <- input$clustering_method
      params <- build_cluster_params(input, method)

      # Collect enrichment dataframes from reactive values
      genesets <- list()
      for (rr_name in selected_rrs) {
        genesets[[rr_name]] <- u_rrdfs[[rr_name]]
      }

      # 2. Clear stale intermediate results from previous runs
      # This prevents orphaned entries from accumulating across clustering sessions
      intermed_keys <- c("DistanceMatrix", "cluster_summary", "cluster_df", "method", "params")
      for (key in intermed_keys) {
        clus_intermed[[key]] <- NULL
      }

      # 3. Disable button and show notification
      shinyjs::disable("cluster")
      showNotification("Clustering running in background...",
                       id = "cluster_progress", duration = NULL, type = "message")

      # 4. Launch future with ALL computation
      p <- future::future({
        gs_names <- names(genesets)

        # Merge genesets
        merged_gs <- if (length(genesets) == 1) {
          normalize_geneset(genesets[[1]])
        } else {
          merge_genesets(genesets)
        }

        # Run clustering
        cluster_result <- perform_clustering(merged_gs, method = method,
                                             params = params, gs_names = gs_names,
                                             raw_genesets = genesets)

        # Process results (all pure data manipulation, no reactive access)
        cluster_df <- cluster_result$cluster_df

        if (!is.null(cluster_df) && nrow(cluster_df) > 0) {
          # Add Representative_Term for visualization compatibility
          if ("Padj" %in% colnames(cluster_df)) {
            cluster_df <- cluster_df %>%
              dplyr::group_by(Cluster) %>%
              dplyr::mutate(
                Representative_Term = {
                  padj_vals <- Padj
                  if (all(is.na(padj_vals))) {
                    Term[1]
                  } else {
                    Term[which.min(padj_vals)]
                  }
                }
              ) %>%
              dplyr::ungroup()
          } else if ("Pvalue" %in% colnames(cluster_df)) {
            cluster_df <- cluster_df %>%
              dplyr::group_by(Cluster) %>%
              dplyr::mutate(
                Representative_Term = {
                  pval_vals <- Pvalue
                  if (all(is.na(pval_vals))) {
                    Term[1]
                  } else {
                    Term[which.min(pval_vals)]
                  }
                }
              ) %>%
              dplyr::ungroup()
          } else {
            cluster_df <- cluster_df %>%
              dplyr::group_by(Cluster) %>%
              dplyr::mutate(Representative_Term = Term[1]) %>%
              dplyr::ungroup()
          }

          # Build summary data (one row per cluster) for visualization heatmap
          pval_padj_cols <- grep("^(Pvalue_|Padj_)", colnames(cluster_df), value = TRUE)
          summary_cols <- c("Cluster", "Representative_Term", pval_padj_cols)
          available_summary_cols <- intersect(summary_cols, colnames(cluster_df))

          if (length(available_summary_cols) >= 2) {
            summary_df <- cluster_df %>%
              dplyr::group_by(Cluster) %>%
              dplyr::slice(1) %>%
              dplyr::ungroup()
            summary_df <- as.data.frame(summary_df[, available_summary_cols, drop = FALSE])
          } else {
            summary_df <- cluster_df %>%
              dplyr::group_by(Cluster) %>%
              dplyr::slice(1) %>%
              dplyr::ungroup()
            summary_df <- as.data.frame(summary_df[, intersect(c("Cluster", "Representative_Term"), colnames(cluster_df)), drop = FALSE])
          }

          # Build tracking row
          new_row <- data.frame(
            name = cluster_name,
            method = method,
            n_clusters = length(unique(cluster_df$Cluster)),
            n_terms = nrow(cluster_df),
            stringsAsFactors = FALSE
          )

          list(
            success = TRUE,
            cluster_name = cluster_name,
            summary_df = summary_df,
            cluster_df = as.data.frame(cluster_df),
            cluster_result = cluster_result,
            method = method,
            params = params,
            new_row = new_row,
            gs_names = gs_names
          )
        } else {
          list(success = FALSE)
        }
      }, seed = TRUE)

      # 5. Update reactive values on success
      promises::then(p,
        onFulfilled = function(result) {
          if (result$success) {
            u_clusdfs[[result$cluster_name]] <- result$summary_df
            u_clusnames$labels <- unique(c(u_clusnames$labels, result$cluster_name))
            u_cluslists[[result$cluster_name]] <- result$cluster_df

            # Update big_clusdf for tracking
            if (is.null(u_big_clusdf[['df']])) {
              u_big_clusdf[['df']] <- result$new_row
            } else {
              u_big_clusdf[['df']] <- rbind(u_big_clusdf[['df']], result$new_row)
            }

            # Store intermediate results
            if (!is.null(result$cluster_result$distance_matrix)) {
              clus_intermed[['DistanceMatrix']] <- result$cluster_result$distance_matrix
            }
            clus_intermed[['cluster_summary']] <- result$cluster_result$cluster_summary
            clus_intermed[['cluster_df']] <- result$cluster_df
            clus_intermed[['method']] <- result$method
            clus_intermed[['params']] <- result$params

            removeNotification("cluster_progress")
            showNotification(
              paste("Clustering complete!", result$new_row$n_clusters,
                    "clusters found with", result$new_row$n_terms, "terms"),
              type = "message"
            )

            shinyjs::show(id = "cluster_results_box", anim = TRUE)
            shinyjs::show(id = "cluster_intermediate_box", anim = TRUE)
          } else {
            removeNotification("cluster_progress")
            showNotification(
              "No clusters found with current parameters. Try adjusting thresholds.",
              type = "warning"
            )
          }
        },
        onRejected = function(err) {
          removeNotification("cluster_progress")
          showNotification(paste("Clustering error:", conditionMessage(err)),
                           type = "error", duration = 10)
        }
      )

      # 6. Always re-enable button
      promises::finally(p, function() {
        shinyjs::enable("cluster")
      })

      # Return NULL so Shiny knows this observer is async
      NULL
    })

    # Cluster summary table output
    output$cluster_summary_table <- DT::renderDT({
      req(clus_intermed[['cluster_summary']])
      clus_intermed[['cluster_summary']]
    }, options = list(pageLength = 10, scrollX = TRUE))

    # Method info output
    output$method_info <- renderText({
      req(clus_intermed[['method']])
      params <- clus_intermed[['params']]
      method <- clus_intermed[['method']]

      info <- paste("Method:", method, "\n\nParameters:\n")
      for (name in names(params)) {
        info <- paste0(info, "  ", name, ": ", params[[name]], "\n")
      }
      info
    })

    # Distance matrix table (cap at 200x200 to prevent browser crash)
    output$distanceMatrix_table <- DT::renderDT({
      req(clus_intermed[['DistanceMatrix']])
      dm <- clus_intermed[['DistanceMatrix']]
      max_dim <- 200
      if (nrow(dm) > max_dim || ncol(dm) > max_dim) {
        dm <- dm[seq_len(min(nrow(dm), max_dim)), seq_len(min(ncol(dm), max_dim)), drop = FALSE]
        showNotification(
          paste("Distance matrix truncated to", max_dim, "x", max_dim,
                "for display. Full matrix is", nrow(clus_intermed[['DistanceMatrix']]),
                "x", ncol(clus_intermed[['DistanceMatrix']])),
          type = "warning"
        )
      }
      round(as.data.frame(dm), 4)
    }, options = list(pageLength = 10, scrollX = TRUE), server = TRUE)

    # Cluster details table
    output$cluster_details_table <- DT::renderDT({
      req(clus_intermed[['cluster_df']])
      clus_intermed[['cluster_df']]
    }, options = list(pageLength = 15, scrollX = TRUE))
  })
}


#' Build clustering parameters from UI inputs
#'
#' @param input Shiny input object
#' @param method Selected clustering method
#' @return Named list of parameters
#' @keywords internal
build_cluster_params <- function(input, method) {
  if (method == "richR") {
    list(
      cutoff = input$richR_cutoff %||% 0.5,
      overlap = input$richR_overlap %||% 0.5,
      minSize = input$richR_minSize %||% 2
    )
  } else if (method == "hierarchical") {
    list(
      distance_metric = input$hier_distance_metric %||% "kappa",
      distance_cutoff = input$hier_distance_cutoff %||% 0.5,
      linkage_method = input$hier_linkage_method %||% "average",
      linkage_cutoff = input$hier_linkage_cutoff %||% 0.5,
      min_terms = input$hier_min_terms %||% 2,
      min_value = input$hier_min_value %||% 0.1
    )
  } else if (method == "david") {
    list(
      similarity_threshold = input$david_similarity %||% 0.5,
      initial_group_membership = input$david_initial_membership %||% 3,
      final_group_membership = input$david_final_membership %||% 3,
      multiple_linkage_threshold = input$david_linkage %||% 0.5
    )
  } else {
    list()
  }
}

