clusVisTabUI <- function(id, tabName) {
  ns <- NS(id)
  tabItem(tabName = tabName,
    # ENRICH TAB CONTENTS
    fluidRow(
      column(width = 4,
        tabBox(title="Load cluster result", width=NULL,
          tabPanel("File upload",
            helpText("Accepted formats: .txt, .csv, .tsv (Not currently supported)"),
            fileInput(ns('clus_files'), 'Select files', multiple=TRUE, accept=c('.csv', '.tsv', '.xls', '.txt'))
          ),
          tabPanel("Text input",
            helpText("This functionality is currently not available, but will be supported in the future."),
            textAreaInput(ns('rr_text'), "Text Input", placeholder="Paste dataframe-like object"),
            textInput(ns('clustext_name'), "Name", placeholder="Set name for pasted enrichment result"),
            actionButton(ns('upload_clustext'), "Upload")
          )
        ),
        shinyjs::hidden(tags$div(
          id=ns("cluslist_box"),
          box(title="Available cluster results", width=NULL,
            helpText("You can rename any cluster result by double-clicking on the relevant cell."),
            DT::DTOutput(ns('clus_list_table')),
            actionButton(ns('remove_clus'), "Delete")
          )
        ))
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
    
    observe ({
      if (is.null(u_big_clusdf[['df']])) {
        shinyjs::hide('cluslist_box')
      } else {
        shinyjs::show("cluslist_box")
      }
    })
    
  
    # Reactively update created cluster result dataframe
    big_clusdf_to_table <- reactive({
      u_big_clusdf[['df']]
    })
    # Output uploaded file table
    output$clus_list_table = DT::renderDT(
      big_clusdf_to_table(), editable='cell'
    )
    # Cluslist table editing code
    proxy = dataTableProxy('clus_list_table')
    observeEvent(input$clus_list_table_cell_edit, {
      info = input$clus_list_table_cell_edit
      str(info)
      i = info$row
      j = info$col
      v = info$value
      print(info$col)
      
      # Rename rr if changing a value in column 1 (name col)
      if (info$col == 1) {
        new_name <- v
        old_name <- u_big_clusdf[['df']][i, j]
        if (nchar(new_name) > 0 && nchar(old_name) > 0) {
          u_clusnames$labels <- c(u_clusnames$labels, new_name)
          u_clusnames$labels <- setdiff(u_clusnames$labels, old_name) # remove old name
          
          u_clusdfs[[new_name]] <- u_clusdfs[[old_name]] # Update clusdfs
          u_clusdfs <- setdiff(names(u_clusdfs), old_name)
          
          u_cluslists[[new_name]] <- u_cluslists[[old_name]] # Update cluslists
          u_cluslists <- setdiff(names(u_cluslists), old_name)
        }
      }
      # Update u_big_clusdf
      u_big_clusdf[['df']][i, j] <<- DT::coerceValue(v, u_big_clusdf[['df']][i, j])
    })
    
    # Remove clus from list of created cluster results
    observeEvent(input$remove_clus, {
      req(input$clus_list_table_rows_selected)
      
      # Also remove from clusdfs, cluslists, and clusnames
      for (clus in input$clus_list_table_rows_selected) {
        clus_to_rm <- u_big_clusdf[['df']][clus, ]
        clus_to_rm <- clus_to_rm$name
        
        u_clusdfs <- setdiff(names(u_clusdfs), clus_to_rm)
        u_cluslists <- setdiff(names(u_cluslists), clus_to_rm)
        u_clusnames$labels <- setdiff(u_clusnames$labels, clus_to_rm)
      }
      
      # Remove selection from u_big_clusdf
      rm_vec <- u_big_clusdf[['df']][input$clus_list_table_rows_selected, ]
      u_big_clusdf[['df']] <- rm_file_clusdf(u_big_clusdf[['df']], rm_vec)
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
    
    # Reactively update which cluster list table is read based on selection
    cluslist_to_table <- reactive ({
      req(input$cluslist_select)
      df <- u_cluslists[[input$cluslist_select]]
      return(df)
    })
    # Output cluslist table
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