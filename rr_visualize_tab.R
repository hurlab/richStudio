# ENRICH TAB CONTENTS

rrVisTabUI <- function(id, tabName) {
  ns <- NS(id)
  tabItem(tabName = tabName,
    fluidRow(
      column(width = 4,
        tabBox(title="Load enrichment result", width=NULL,
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
        shinyjs::hidden(tags$div(
          id=ns("rrlist_box"),
          box(title="Available enrichment results", width=NULL,
            DT::DTOutput(ns('rr_list_table')),
            actionButton(ns('remove_rr'), "Delete")
          )
        ))
      ),
      
      # VISUALIZATION
      column(width = 8,
        h3("Enrichment Result Visualization"),
        tabsetPanel(
          
          # Table
          tabPanel("Table",
            box(title="Table View", width=NULL, status='primary', collapsible=TRUE,
              br(),
              selectInput(ns('select_table'), "Select enrichment result to view", choices=NULL, multiple=FALSE),
            ),
            box(title='Table View', width=NULL, status='info', solidHeader=TRUE,
              DT::dataTableOutput(ns('rr_table'))
            )
          ),
          
          # Bar plot
          tabPanel("Bar Plot",
            box(title="Bar Plot", width=NULL, status='primary', collapsible=TRUE,
              br(),
              selectInput(ns('select_bar'), "Select enrichment result to view", choices=NULL, multiple=FALSE),
              fluidRow(
                column(4,
                  selectInput(ns('bar_type'), "View rich score or p-value?", choices=c("Rich score"="rich", "P-value"="value"), multiple=FALSE)
                ),
                column(4,
                  selectInput(ns('bar_valtype'), "View Padj or Pvalue?", choices=c("Padj", "Pvalue"), multiple=FALSE)
                ),
                column(4,
                  numericInput(ns("bar_pvalue"), "P-value cutoff", value=0.05, min=0, max=1)
                )
              ),
              sliderInput(ns("bar_nterms"), "Number of terms to display", value=25, min=0, max=100)
            ),
            box(title='Bar Plot', width=NULL, status='info', solidHeader=TRUE,
              br(),
              plotlyOutput(ns("barplot"))
            )
          ),
          
          # Dot plot
          tabPanel("Dot Plot",
            box(title="Dot Plot", width=NULL, status='primary', collapsible=TRUE,
              br(),
              selectInput(ns('select_dot'), "Select enrichment result to view", choices=NULL, multiple=FALSE),
              fluidRow(
                column(4,
                  selectInput(ns('dot_valtype'), "View Padj or Pvalue?", choices=c("Padj", "Pvalue"), multiple=FALSE)
                ),
                column(4,
                  numericInput(ns("dot_cutoff"), "P-value cutoff", value=0.05, min=0, max=1)
                )
              ),
              sliderInput(ns("dot_nterms"), "Number of terms to display", value=25, min=0, max=100)
            ),
            box(title='Dot Plot', width=NULL, status='info', solidHeader=TRUE,
              br(),
              plotlyOutput(ns("dotplot"))
            )
          ),
          
          # Network
          tabPanel("Network",
            box(title="Network", width=NULL, status='primary', collapsible=TRUE,
              br(),
              selectInput(ns('select_net'), "Select enrichment result to view", choices=NULL, multiple=FALSE),
              fluidRow(
                column(4,
                  selectInput(ns('net_valtype'), "View Padj or Pvalue?", choices=c("Padj", "Pvalue"), multiple=FALSE)
                ),
                column(4,
                  numericInput(ns("net_cutoff"), "P-value cutoff", value=0.05, min=0, max=1)
                )
              ),
              sliderInput(ns("net_nterms"), "Number of terms to display", value=25, min=0, max=100)
            ),
            box(title='Network', width=NULL, status='info', solidHeader=TRUE,
              br(),
              plotOutput(ns("network"), height="800px")
            )
          ),
          
          # Heatmap
          tabPanel("Heatmap",
            tabBox(id="edit_hmap_box", width = NULL,
              # EZ heatmap
              tabPanel("Quick make",
                selectInput(ns("ez_add_select"), "Select enrichment results", choices=NULL, multiple=TRUE),
                fluidRow(
                  column(4, 
                    selectInput(ns("ez_value_by"), "Select top terms by", choices=c("Padj", "Pvalue")),
                  ),
                  column(4,
                    numericInput(ns("ez_value_cutoff"), "P-value cutoff", value=0.05, min=0, max=1)
                  )
                ),
                sliderInput(ns("ez_nterms"), "Number of terms per result to display", value=10, min=0, max=100)
              ),
              # add enrichment result to heatmap
              tabPanel("Add",
                selectInput(ns("rr_add_select"), "Select enrichment result", choices=NULL, multiple=FALSE),
                fluidRow(
                  column(4,
                    numericInput(ns('top_rr_terms'), "Select top ? terms", value = 20, min=0, max=100)
                  ),
                  column(4,
                    selectInput(ns('rr_top_value_by'), "Select top terms by", choices=c("Padj", "Pvalue"))
                  ),
                  column(4,
                    numericInput(ns("rr_value_cutoff"), "P-value cutoff", value=0.05, min=0, max=1)
                  )
                ),
                DT::dataTableOutput(ns('rr_select_table')),
                actionButton(ns('add_rr'), "Add terms")
              ),
              # delete result/terms from heatmap
              tabPanel("Delete",
                selectInput(ns("rr_delete_select"), "Select enrichment result", choices=NULL, multiple=FALSE),
                selectInput(ns("rr_term_delete_select"), "Select terms to delete", choices=NULL, multiple=TRUE),
                fluidRow(
                  column(4,
                    actionButton(ns('delete_rr_terms'), "Delete selected terms")
                  ),
                  column(4,
                    actionButton(ns('delete_rr'), "Delete entire result")
                  )
                )
              )
            ),
            br(),
            box(title="Enrichment Result Heatmap", status="info", width=NULL,
                solidHeader = TRUE,
                plotlyOutput(ns('rr_hmap'), height="800px")
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


rrVisTabServer <- function(id, u_degnames, u_degdfs, u_big_degdf, u_rrnames, u_rrdfs, u_big_rrdf, u_clusnames, u_clusdfs, u_cluslists) {
  
  moduleServer(id, function(input, output, session) {
    
    # Global reactive objects
    u_degnames_reactive <- reactive(u_degnames$labels) 
    u_degdfs_reactive <- reactive(u_degdfs) 
    u_big_degdf_reactive <- reactive(u_big_degdf)
    
    u_rrnames_reactive <- reactive(u_rrnames$labels) 
    u_rrdfs_reactive <- reactive(u_rrdfs)
    u_big_rrdf_reactive <- reactive(u_big_rrdf)
    
    u_clusnames_reactive <- reactive(u_clusnames$labels)
    u_clusdfs_reactive <- reactive(u_clusdfs)
    u_cluslists_reactive <- reactive(u_cluslists)
    
    # Local reactive objects
    rr_custom_list_reactive <- reactiveValues(labels=NULL)
    rr_term_vec_reactive <- reactiveValues()
    custom_data_reactive <- reactiveValues(df = data.frame())
    
    value_by_reactive <- reactiveVal()
    
    # update select inputs based on # file inputs
    observe ({
      updateSelectInput(session=getDefaultReactiveDomain(), 'selected_degs', choices=u_degnames_reactive())
      updateSelectInput(session=getDefaultReactiveDomain(), 'select_bar', choices=u_rrnames_reactive())
      updateSelectInput(session=getDefaultReactiveDomain(), 'select_dot', choices=u_rrnames_reactive())
      updateSelectInput(session=getDefaultReactiveDomain(), 'select_net', choices=u_rrnames_reactive())
      updateSelectInput(session=getDefaultReactiveDomain(), 'select_table', choices=u_rrnames_reactive())
      updateSelectInput(session=getDefaultReactiveDomain(), 'ez_add_select', choices=u_rrnames_reactive())
      updateSelectInput(session=getDefaultReactiveDomain(), 'rr_add_select', choices=u_rrnames_reactive())
    })
    
    observe ({
      if (is.null(u_big_rrdf[['df']])) {
        shinyjs::hide('rrlist_box')
      } else {
        shinyjs::show("rrlist_box")
      }
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
    
    get_rr_barplot <- reactive ({
      req(input$select_bar)
      df <- u_rrdfs[[input$select_bar]]
      mybar <- rr_bar(x=df, top=input$bar_nterms, pvalue=input$bar_pvalue, value_type=input$bar_valtype, view=input$bar_type)
      return(mybar)
    })
    output$barplot <- renderPlotly({
      get_rr_barplot()
    })
    
    get_rr_dotplot <- reactive ({
      req(input$select_dot)
      df <- u_rrdfs[[input$select_dot]]
      mydot <- rr_dot(x=df, top=input$dot_nterms, value_cutoff=input$dot_cutoff, value_type=input$dot_valtype)
      return(mydot)
    })
    output$dotplot <- renderPlotly ({
      get_rr_dotplot()
    })
    
    get_rr_network <- reactive ({
      req(input$select_net)
      df <- u_rrdfs[[input$select_net]]
      mynet <- rr_network(rr=df, deg=NULL)
      return(mynet)
    })
    output$network <- renderPlot ({
      get_rr_network()
    })
    
    output$dotplot <- renderPlotly ({
      get_rr_dotplot()
    })
    
    get_rr_table <- reactive ({
      req(input$select_table)
      df <- u_rrdfs[[input$select_table]]
      return(df)
    })
    output$rr_table <- DT::renderDataTable({
      get_rr_table()
    })
    
    # Enrichment Result Heatmap
    # quick make
    ez_listen <- reactive({
      list(input$ez_add_select, input$ez_value_by, input$ez_nterms, input$ez_value_cutoff)
    })
    observeEvent(ez_listen(), {
      req(input$ez_add_select)
      # reset custom_data and the list of added genesets and terms
      custom_data_reactive$df <- data.frame() 
      rr_custom_list_reactive <- NULL
      rr_term_vec_reactive <- NULL
      value_by_reactive(input$ez_value_by)
      
      if (input$ez_nterms != 0) {
        
        for (i in seq_along(input$ez_add_select)) {
          gs <- u_rrdfs[[input$ez_add_select[i]]]
          
          # add gs to list only if there exist values smaller than cutoff
          if (any(gs[, value_by_reactive()] < input$rr_value_cutoff)) {
            gs <- filter(gs, gs[, value_by_reactive()]<input$ez_value_cutoff)
            sliced_gs <- arrange(gs, value_by_reactive())
            sliced_gs <- slice_head(sliced_gs, n=input$ez_nterms)
            term_vec <- sliced_gs$Term
            
            # add gs to custom_data_reactive
            custom_data_reactive$df <- add_gs(custom_data=custom_data_reactive$df, gs=gs, 
                                              gs_name=input$ez_add_select[i], term_vec=term_vec)
            # add terms to rr_term_vec_reactive
            rr_term_vec_reactive[[input$rr_add_select]] <- term_vec
            # add gs name to rr_custom_list_reactive
            rr_custom_list_reactive$labels <- c(rr_custom_list_reactive$labels, input$rr_add_select)
          }
        }
      }
      
    })
    
    # add
    # reactively update which rr table is read based on selection
    rr_to_table <- reactive ({
      req(input$rr_add_select)
      df <- u_rrdfs[[input$rr_add_select]]
      return(df)
    })
    # output rr table
    output$rr_select_table = DT::renderDataTable(
      rr_to_table()
    )
    
    # add selected terms to heatmap
    observeEvent(input$add_rr, {
      req(input$rr_select_table_rows_selected)
      
      # set value_by
      value_by_reactive(input$rr_top_value_by)
      
      gs <- u_rrdfs[[input$rr_add_select]] # store df of selected rr
      
      # ensure there exist values smaller than cutoff before filtering
      if (any(gs[, value_by_reactive()] < input$rr_value_cutoff)) {
        gs <- filter(gs, gs[, value_by_reactive()]<input$rr_value_cutoff)
        term_vec <- gs[input$rr_select_table_rows_selected, ] # subset df with selected rows
        term_vec <- term_vec$Term # get only Term column of subsetted df
        
        # add gs to custom_data_reactive
        custom_data_reactive$df <- add_gs(custom_data=custom_data_reactive$df, gs=gs, 
                                          gs_name=input$rr_add_select, term_vec=term_vec)
        
        # add terms to rr_term_vec_reactive
        rr_term_vec_reactive[[input$rr_add_select]] <- term_vec
        # add gs name to rr_custom_list_reactive
        rr_custom_list_reactive$labels <- c(rr_custom_list_reactive$labels, input$rr_add_select)
      }
      
    })
    
    # remove selected terms from heatmap
    observeEvent(input$delete_rr_terms, {
      req(input$rr_term_delete_select)
      req(input$rr_delete_select)
      custom_data_reactive$df <- remove_gs(custom_data_reactive$df, input$rr_delete_select, input$rr_term_delete_select)
      
      tmp <- rr_term_vec_reactive[[input$rr_delete_select]]
      rr_term_vec_reactive[[input$rr_delete_select]] <- tmp[-which(tmp %in% input$rr_term_delete_select)]
      updateSelectInput(session=getDefaultReactiveDomain(), 'rr_term_delete_select', 
                        choices=rr_term_vec_reactive[[input$rr_delete_select]])
    })
    
    # delete entire result from heatmap
    observeEvent(input$delete_rr, {
      req(input$rr_delete_select)
      gs <- u_rrdfs[[input$rr_delete_select]]
      all_terms <- gs$Term
      custom_data_reactive$df <- remove_gs(custom_data=custom_data_reactive$df, gs_name=input$rr_delete_select, 
                                           input$rr_term_delete_select, all_terms)
      # remove result name from list
      rr_custom_list_reactive$labels <- setdiff(rr_custom_list_reactive$labels, input$rr_delete_select)
    })
    
    # plot enrichment result heatmap
    plot_custom_hmap <- reactive({
      if (nrow(custom_data_reactive$df) != 0) {
        hmap <- custom_hmap(custom_data=custom_data_reactive$df, value_type=value_by_reactive())
        return(hmap)
      }
    })
    output$rr_hmap <- renderPlotly({
      plot_custom_hmap()
    })
    
  })
}