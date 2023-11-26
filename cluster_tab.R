
clusterTabUI <- function(id, tabName) {
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
        shinyjs::hidden(tags$div(
          id=ns("list_box"),
          tabBox(title="Uploaded files", width=NULL,
                  
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
            ),
            tabPanel("Cluster Results",
              tags$div(id=ns("cluslist_box"),
                div(style="display:inline-block; float:left", helpText("Double-click on any cell to change its value.")),
                div(style="display:inline-block; float:right", 
                  actionBttn(ns('cluslist_help'), label=NULL, style='material-circle', status='primary', icon=icon('info'), size='xs')
                ),
                br(),
                br(),
                DT::DTOutput(ns('clus_list_table')),
                actionButton(ns('remove_clus'), "Delete")
              )
            )
         ))
        ), 
        tabBox(title="View files", width=NULL,
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
          ),
          tabPanel(title="Cluster results",
            fluidRow(
              column(4,
                selectInput(ns('clus_table_select'), "Select cluster result", choices=NULL),
              ),
              column(4,
                selectInput(ns('clus_export_type'), "Export as", choices=c(".txt", ".csv", ".tsv"))
              )
            ),
            downloadButton(ns("download_clus"), "Download"),
            br(),
            br(),
            br(),
            DT::dataTableOutput(ns('clus_table'))
          )
        )
      )
    )
  )
}


clusterTabServer <- function(id, u_degnames, u_degdfs, u_rrnames, u_rrdfs, u_big_rrdf, u_clusnames, u_clusdfs, u_big_clusdf, u_cluslists) {
  
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
    
    
    # update select inputs based on # cluster results
    observe({
      updateSelectInput(session=getDefaultReactiveDomain(), 'selected_rrs', choices=u_rrnames_reactive())
      updateSelectInput(session=getDefaultReactiveDomain(), 'clusdf_select', choices=u_clusnames_reactive())
      updateSelectInput(session=getDefaultReactiveDomain(), 'cluslist_select', choices=u_clusnames_reactive())
      updateSelectInput(session=getDefaultReactiveDomain(), 'rr_table_select', choices=u_rrnames_reactive())
      updateSelectInput(session=getDefaultReactiveDomain(), 'clus_table_select', choices=u_clusnames_reactive())
    })
    
    
    observe ({
      # Show/hide entire box
      if (is.null(u_big_rrdf[['df']]) && is.null(u_big_clusdf[['df']])) {
        shinyjs::hide('list_box')
      } else if (!is.null(u_big_rrdf[['df']]) || !is.null(u_big_clusdf[['df']])) {
        shinyjs::show("list_box")
        # Show/hide delete rr button
        if (is.null(u_big_rrdf[['df']])) {
          shinyjs::hide('rrlist_box')
        } else if (!is.null(u_big_rrdf[['df']])){
          shinyjs::show('rrlist_box')
        }
        # Show/hide delete clus button
        if (is.null(u_big_clusdf[['df']])) {
          shinyjs::hide('cluslist_box')
        } else if (!is.null(u_big_clusdf[['df']])){
          shinyjs::show('cluslist_box')
        }
      }
    })
      
    observeEvent(input$rrlist_help, {
      showModal(modalDialog(
        title="Help",
        "If annotation, ontology, keytype, or species data is marked with '?', you
        can update it by double-clicking on the relevant cell. If you started from
        an enrichment output but wish to link corresponding differential expression data
        to it, you can update the 'from_deg' value to the name of a DEG set uploaded to
        RichStudio."
      ))
    })
    observeEvent(input$cluslist_help, {
      showModal(modalDialog(
        title="Help",
        "Display some informational message here..."
      ))
    })
    
    # <!----- UPLOAD LOGIC -----!>
    observeEvent(input$rr_files, {
      req(input$rr_files) # Make sure file uploaded
      
      for (i in seq_along(input$rr_files$name)) {
        lab <- input$rr_files$name[i]
        
        ext <- tools::file_ext(input$rr_files$name[i])
        path <- input$rr_files$datapath[i]
        
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
        
        #u_rrdfs[[lab]] <- select_required_columns(df) # set u_rrdfs
        u_rrdfs[[lab]] <- df # set u_rrdfs
        u_rrnames$labels <- c(u_rrnames$labels, lab) # set u_rrnames
        u_big_rrdf[['df']] <- add_file_rrdf(df=u_big_rrdf[['df']], name=lab, file=TRUE)
      }
      
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
    proxy = dataTableProxy('rr_list_table')
    observeEvent(input$rr_list_table_cell_edit, {
      info = input$rr_list_table_cell_edit
      str(info)
      i = info$row
      j = info$col
      v = info$value
      print(info$col)
      
      # Rename rr if changing a value in column 1 (name col)
      if (info$col == 1) {
        new_name <- v
        old_name <- u_big_rrdf[['df']][i, j]
        if (nchar(new_name) > 0 && nchar(old_name) > 0) {
          u_rrnames$labels <- c(u_rrnames$labels, new_name)
          u_rrnames$labels <- setdiff(u_rrnames$labels, old_name) # remove old name
          
          u_rrdfs[[new_name]] <- u_rrdfs[[old_name]]
          u_rrdfs <- setdiff(names(u_rrdfs), old_name)
        }
      }
      
      u_big_rrdf[['df']][i, j] <<- DT::coerceValue(v, u_big_rrdf[['df']][i, j])
    })
    
    # Remove rr from uploaded rich results
    observeEvent(input$remove_rr, {
      req(input$rr_list_table_rows_selected)
      
      # Also remove from degdfs and degnames
      for (rr in input$rr_list_table_rows_selected) {
        rr_to_rm <- u_big_rrdf[['df']][rr, ]
        rr_to_rm <- rr_to_rm$name
        
        u_rrdfs <- setdiff(names(u_rrdfs), rr_to_rm)
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
      return(df)
    })
    
    # output rr table
    output$rr_table = DT::renderDataTable({
      rr_to_table()
    })
    
    # download rr
    output$download_rr <- downloadHandler(
      filename = function() {
        req(input$rr_table_select)
        paste0(input$rr_table_select, input$rr_export_type)
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
          cluster(merged_gs=merged_gs, cutoff=input$cutoff, overlap=input$overlap, 
                  minSize=input$min_size),
          error = function(e) {
            showNotification(e$message)
            return(NULL)
          }
        )
        if(!is.null(clustered_gs)) {
          incProgress(0.5, message=NULL, "Done clustering")
          cluster_list <- get_cluster_list(clustered_gs=clustered_gs, merged_gs=merged_gs, 
                                           gs_names=gs_names) # get cluster info
          final_data <- hmap_prepare(clustered_gs, gs_names=gs_names) # final data
          final_data <- change_finaldata_valueby(final_data=final_data, 
                                                 cluster_list=cluster_list, value_by="mean")
          
          # Store in reactive
          lab <- input$cluster_name
          u_clusdfs[[lab]] <- final_data # set u_clusdfs
          u_cluslists[[lab]] <- cluster_list # set u_cluslists
          u_clusnames$labels <- c(u_clusnames$labels, lab) # set u_clusnames
          u_big_clusdf[['df']] <- add_file_clusdf(df=u_big_clusdf[['df']], clusdf=final_data, 
                                                  name=lab, from_vec=input$selected_rrs) # add to u_big_clusdf
        }
      })
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
    
    
    # Reactively update which rr table is read based on selection
    rr_to_table <- reactive ({
      req(input$rr_table_select)
      df <- u_rrdfs[[input$rr_table_select]]
      return(df)
    })
    
    # output rr table
    output$rr_table = DT::renderDataTable({
      rr_to_table()
    })
    
    # download rr
    output$download_rr <- downloadHandler(
      filename = function() {
        req(input$rr_table_select)
        paste0(input$rr_table_select, input$rr_export_type)
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
    
    # Reactively update which cluster result is read based on selection
    clusdf_to_table <- reactive ({
      req(input$clus_table_select)
      df <- u_clusdfs[[input$clus_table_select]]
      return(df)
    })
    # Output cluster result table
    output$clus_table = DT::renderDataTable({
      clusdf_to_table()
    })
    
    # Download cluster result
    output$download_clus <- downloadHandler(
      filename = function() {
        req(input$clus_table_select)
        paste0(input$clus_table_select, input$clus_export_type)
      },
      content = function(file) {
        ext_type <- input$clus_export_type
        if (ext_type == ".txt") {
          write.table(u_clusdfs[[input$clus_table_select]], file, sep='\t', row.names=FALSE)
        } else if (ext_type == ".csv") {
          write.csv(u_clusdfs[[input$clus_table_select]], file, row.names=FALSE)
        } else if (ext_type == ".tsv") {
          write.table(u_clusdfs[[input$clus_table_select]], file, sep='\t', row.names=FALSE)
        }
      }
    )
    
  })
}