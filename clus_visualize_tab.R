
clusVisTabUI <- function(id, tabName) {
  ns <- NS(id)
  tabItem(tabName = tabName,
    # ENRICH TAB CONTENTS
    fluidRow(
      column(width = 4,
        tabBox(title=span(icon("upload"), "Upload enrichment results"), width=NULL,
          tabPanel("File upload",
            helpText("Accepted formats: .txt, .csv, .tsv"),      
            fileInput(ns('rr_files'), 'Select files', multiple=TRUE, accept=c('.csv', '.tsv', '.xls', '.txt'))
          ),
          tabPanel("Text input",
            helpText("This functionality is currently not available, but will be supported in the future."),
            textAreaInput(ns('rr_text'), "Text Input", placeholder="Paste dataframe-like object"),
            textInput(ns('rrtext_name'), "Name", placeholder="Set name for pasted enrichment result"),
            actionButton(ns('upload_rrtext'), "Upload")
          )
        ),
        tabBox(title="Cluster", width = NULL,
          tabPanel("Kappa clustering",
            br(),
            selectInput(ns('selected_rrs'), "Select enrichment results to cluster", choices=NULL, multiple=TRUE),
            textInput(ns('cluster_name'), "Name", value="Test group"),
            selectInput(ns('cluster_by'), "Cluster by", c("Mean Pvalue", "Median Pvalue", "Min Pvalue", "Mean Padj", "Median Padj", "Min Padj")),
            numericInput(ns('cutoff'), "Cutoff", value=.5, min=0, max=1),
            numericInput(ns('overlap'), "Overlap", value=.5, min=0, max=1),
            numericInput(ns('min_size'), "Min size", value=2, min=0),
            actionButton(ns('cluster'), "Cluster")
          )
        )
      ),
      column(width = 8,
        h3("Cluster Result Visualization"),
        tabsetPanel(
          # HEATMAP
          tabPanel("Heatmap",
                   
            # Cluster heatmap
            box(title = "Cluster Heatmap", status = "primary", width = NULL, collapsible = TRUE,
              p("Select cluster result to view comprehensive heatmap displaying values for each cluster"),
              selectInput(ns("clusdf_select"), "Select cluster result", choices=NULL, multiple=FALSE),
              fluidRow(
                column(4,
                  selectInput(ns('big_value_type'), "Select value to show", choices=c("Padj", "Pvalue"))
                ),
                column(4,
                  selectInput(ns('value_by'), "Calculate value by", choices=c("mean", "median", "min", "max"))
                )
              )
            ),
            br(),
            box(title = "Cluster Heatmap", status = "info", width = NULL, solidHeader = TRUE,
              plotlyOutput(ns('clusdf_hmap'), height="800px")
            ),
            br(),
            # Term heatmap
            box(title = "Term Heatmap", status = "primary", width = NULL, collapsible = TRUE,
              p("Select individual clusters to view heatmap of values for each term in cluster"),
              selectInput(ns("indiv_clus_select"), "Select individual clusters", choices=NULL, multiple=TRUE),
              selectInput(ns('small_value_type'), "Select value to show", choices=c("Padj", "Pvalue"))
            ),
            br(),
            box(title = "Term Heatmap", status = "info", width = NULL,
              solidHeader = TRUE,
              plotlyOutput(ns('indiv_clus_hmap'))
            )
          ),
          tabPanel("Cluster info",
            br(),
            box(title = "Detailed Cluster Info", status = "info", width = NULL,
              solidHeader = TRUE,
              p("View and export individual term data for cluster results"),
              fluidRow(
                column(4,
                  selectInput(ns("cluslist_select"), "Select cluster result", choices=NULL, multiple=FALSE),
                ),
                column(4,
                  selectInput(ns('cluslist_export_type'), "Export as", choices=c(".txt", ".csv", ".tsv"))
                )
              ),
              downloadButton(ns("download_cluslist"), "Download"),
              br(),
              br(),
              br(),
              DT::dataTableOutput(ns('cluslist_table')),
              br(),
            )
          )
        )
      )
    ),
    tags$head(
      tags$style(
        HTML(".box-title { font-size: 20px; }")  # Adjust the font size as needed
      )
    )
  )
}


clusVisTabServer <- function(id, u_degnames, u_degdfs, u_rrnames, u_rrdfs, u_big_rrdf, u_clusnames, u_clusdfs, u_big_clusdf, u_cluslists) {
  
  moduleServer(id, function(input, output, session) {
    
    # create reactive objs to make accessible in other modules
    u_degnames_reactive <- reactive(u_degnames$labels) 
    u_degdfs_reactive <- reactive(u_degdfs) 
    
    u_rrnames_reactive <- reactive(u_rrnames$labels) 
    u_rrdfs_reactive <- reactive(u_rrdfs)
    u_big_rrdf_reactive <- reactive(u_big_rrdf)
    
    u_clusnames_reactive <- reactive(u_clusnames$labels)
    u_clusdfs_reactive <- reactive(u_clusdfs)
    u_big_clusdf_reactive <- reactive(u_big_clusdf)
    u_cluslists_reactive <- reactive(u_cluslists)
    
    term_vec_reactive <- reactiveVal(NULL)
    
    # update select inputs based on # cluster results
    observe({
      updateSelectInput(session=getDefaultReactiveDomain(), 'selected_rrs', choices=u_rrnames_reactive())
      updateSelectInput(session=getDefaultReactiveDomain(), 'clusdf_select', choices=u_clusnames_reactive())
      updateSelectInput(session=getDefaultReactiveDomain(), 'indiv_clus_select', choices=term_vec_reactive())
      updateSelectInput(session=getDefaultReactiveDomain(), 'cluslist_select', choices=u_clusnames_reactive())
    })
    
  
    # <!----- CLUSTERING LOGIC -----!>
    # Clustering
    observeEvent(input$cluster, {
      req(input$selected_rrs) # Require rich result selection
      req(input$cluster_name) # Require cluster name
      
      withProgress(message="Clustering...", value=0, {
        genesets <- list()
        gs_names <- c()
        for (i in seq_along(input$selected_rrs)) {
          tmp <- input$selected_rrs[i]
          genesets <- c(genesets, list(u_rrdfs[[tmp]]))
        }
        names(genesets) <- input$selected_rrs
        gs_names <- names(genesets)
        
        merged_gs <- merge_genesets(genesets)
        incProgress(0.2, message=NULL, "Done merging")
        clustered_gs <- tryCatch(
          cluster(merged_gs=merged_gs, cutoff=input$cutoff, overlap=input$overlap, minSize=input$min_size),
          error = function(e) {
            showNotification(e$message)
            return(NULL)
          }
        )
        if(!is.null(clustered_gs)) {
          incProgress(0.5, message=NULL, "Done clustering")
          cluster_list <- get_cluster_list(clustered_gs=clustered_gs, merged_gs=merged_gs, gs_names=gs_names) # get cluster info
          final_data <- hmap_prepare(clustered_gs, gs_names=gs_names) # final data
          final_data <- change_finaldata_valueby(final_data=final_data, cluster_list=cluster_list, value_by="mean")
          
          # store in reactive
          lab <- input$cluster_name
          u_clusdfs[[lab]] <- final_data # set u_clusdfs
          u_cluslists[[lab]] <- cluster_list # set u_cluslists
          u_clusnames$labels <- c(u_clusnames$labels, lab) # set u_clusnames
        }
      })
    })
      
    
    # Update heatmap when cluster result selection changes
    observeEvent(input$clusdf_select, {
      req(input$clusdf_select)
      
      df <- u_clusdfs[[input$clusdf_select]]
      term_vec_reactive(unique(df$Representative_Term))
      
      df <- u_clusdfs[[input$clusdf_select]]
      cluslist_df <- u_cluslists[[input$clusdf_select]]
      
      hmap <- comprehensive_hmap(final_data=df, cluster_list=cluslist_df, 
                                 value_type=input$big_value_type, value_by=input$value_by)
      
      output$clusdf_hmap <- renderPlotly({
        hmap
      })
    })
    
    # plot indiv cluster hmap
    plot_cluslist_hmap <- reactive({
      req(input$indiv_clus_select)
      
      df <- u_clusdfs[[input$clusdf_select]]
      cluslist_df <- u_cluslists[[input$clusdf_select]]
      
      hmap <- cluster_hmap(cluster_list=cluslist_df, term_vec=input$indiv_clus_select, 
                           final_data=df, value_type=input$small_value_type)
      return(hmap)
    })
    
    output$indiv_clus_hmap <- renderPlotly({
      plot_cluslist_hmap()
    })
    
    # reactively update which cluster list table is read based on selection
    cluslist_to_table <- reactive ({
      req(input$cluslist_select)
      df <- u_cluslists[[input$cluslist_select]]
      return(df)
    })
    # output cluslist table
    output$cluslist_table = DT::renderDataTable({
      cluslist_to_table()
    })
    
    # download cluslist table
    output$download_cluslist <- downloadHandler(
      filename = function() {
        req(input$cluslist_select)
        paste0(input$cluslist_select, input$cluslist_export_type)
      },
      content = function(file) {
        ext_type <- input$cluslist_export_type
        if (ext_type == ".txt") {
          write.table(u_cluslists[[input$cluslist_select]], file, sep='\t', row.names=FALSE)
        } else if (ext_type == ".csv") {
          write.csv(u_cluslists[[input$cluslist_select]], file, row.names=FALSE)
        } else if (ext_type == ".tsv") {
          write.table(u_cluslists[[input$cluslist_select]], file, sep='\t', row.names=FALSE)
        }
      }
    )
    
  })
}