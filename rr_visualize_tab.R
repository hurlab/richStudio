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
        shinyjs::hidden(tags$div(id=ns("rrlist_box"),
          box(title="Available enrichment results", width=NULL,
            helpText("You can rename any enrichment result by double-clicking on the relevant cell."),
            DT::DTOutput(ns('rr_list_table')),
            actionButton(ns('remove_rr'), "Delete")
          )))
      ),
      
      # VISUALIZATION
      column(width = 8,
        h3("Enrichment Result Visualization"),
        tabsetPanel(
          
          # Table
          tabPanel("Table",
            box(title="Table View", width=NULL, status='primary', collapsible=TRUE,
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
            tabBox(id=ns("edit_hmap_box"), width=NULL,
              # Top terms heatmap
              tabPanel(title="Top terms", 
                fluidRow(
                  column(4, 
                    selectInput(ns("select_tophmap"), "Select enrichment results", choices=NULL, multiple=TRUE),
                    selectInput(ns("tophmap_valtype"), "Select top terms by", choices=c("Padj", "Pvalue")),
                    numericInput(ns("tophmap_cutoff"), "P-value cutoff", value=0.05, min=0, max=1),
                    sliderInput(ns("tophmap_nterms"), "Number of terms per result to display", value=10, min=0, max=100)
                  ),
                  column(8,
                    h3("Enrichment results in heatmap"),
                    p("Double click any cell to change its value."),
                    DT::DTOutput(ns('tophmap_table'))
                  )
                )
              ),
              # add enrichment result to heatmap
              tabPanel(title="Custom terms",
                selectInput(ns("select_cushmap"), "Select enrichment result", choices=NULL, multiple=FALSE),
                fluidRow(
                  column(4,
                    selectInput(ns('cushmap_valtype'), "Select top terms by", choices=c("Padj", "Pvalue"))
                  ),
                  column(4,
                    textInput(ns("cushmap_title"), "Title", value=NULL)
                  )
                ),
                DT::dataTableOutput(ns('cushmap_select_table')),
                actionButton(ns('cushmap_add_rr'), "Add terms")
              )
            ),
            # Delete result/terms from custom heatmap
            shinyjs::hidden(tags$div(id=ns("delete_custom_hmap_box"),
              box(title="Delete", status="info", width=NULL, solidHeader=TRUE,
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
            ))),
            # The actual heatmap plots
            shinyjs::hidden(tags$div(id=ns("top_hmap_box"),
              box(title="Top Terms Heatmap", status="info", width=NULL, solidHeader=TRUE,
                plotlyOutput(ns('topterm_hmap'), height="800px")
            ))),
            shinyjs::hidden(tags$div(id=ns("custom_hmap_box"),
              box(title="Custom Terms Heatmap", status="info", width=NULL, solidHeader=TRUE,
                plotlyOutput(ns('custom_hmap'), height="800px")
            )))
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
    tt_custom_data_reactive <- reactiveValues(df = data.frame())
    custom_data_reactive <- reactiveValues(df = data.frame())
    top_hmap_df_reactive <- reactiveValues(df = data.frame())
    
    tt_valueby_reactive <- reactiveVal()
    cus_valueby_reactive <- reactiveVal()
    
    # update select inputs based on # file inputs
    observe ({
      updateSelectInput(session=getDefaultReactiveDomain(), 'selected_degs', choices=u_degnames_reactive())
      updateSelectInput(session=getDefaultReactiveDomain(), 'select_bar', choices=u_rrnames_reactive())
      updateSelectInput(session=getDefaultReactiveDomain(), 'select_dot', choices=u_rrnames_reactive())
      updateSelectInput(session=getDefaultReactiveDomain(), 'select_net', choices=u_rrnames_reactive())
      updateSelectInput(session=getDefaultReactiveDomain(), 'select_table', choices=u_rrnames_reactive())
      updateSelectInput(session=getDefaultReactiveDomain(), 'select_tophmap', choices=u_rrnames_reactive())
      updateSelectInput(session=getDefaultReactiveDomain(), 'select_cushmap', choices=u_rrnames_reactive())
      updateSelectInput(session=getDefaultReactiveDomain(), 'rr_delete_select', choices=rr_custom_list_reactive$labels)
    })
    
    # <!----- SHINYJS LOGIC -----!>
    # Don't show list of rr if none uploaded
    observe ({
      if (is.null(u_big_rrdf[['df']])) {
        shinyjs::hide('rrlist_box')
      } else {
        shinyjs::show("rrlist_box")
      }
    })
    # Toggle which heatmap box is shown
    observeEvent(input$edit_hmap_box, {
      if (input$edit_hmap_box == "Top terms") {
        shinyjs::show('top_hmap_box')
        shinyjs::hide('custom_hmap_box')
        shinyjs::hide('delete_custom_hmap_box')
      } else {
        shinyjs::hide('top_hmap_box')
        shinyjs::show('custom_hmap_box')
        shinyjs::show('delete_custom_hmap_box')
      }
    })
    
    # <!----- UPLOAD LOGIC -----!>
    observeEvent(input$rr_files, {
      req(input$rr_files) # Make sure file uploaded
      
      for (i in seq_along(input$rr_files$name)) {
        lab <- input$rr_files$name[i]
        
        ext <- tools::file_ext(input$rr_files$name[i])
        path <- input$rr_files$datapath[i]
        
        # Try to read file as csv
        csv_ncol <- tryCatch({
          csvdf <- read.csv(path)
          ncol(csvdf)
        }, error = function(err) {
          0
        })
        # Try to read file as tsv
        tsv_ncol <- tryCatch({
          tsvdf <- read.delim(path)
          ncol(tsvdf)
        }, error = function(err) {
          0
        })
        # Decide which df to store
        if (tsv_ncol == 0 || csv_ncol > tsv_ncol) {
          df <- read.csv(path)
        } else {
          df <- read.delim(path)
        }
        
        #u_rrdfs[[lab]] <- select_required_columns(df) # set u_rrdfs
        u_rrdfs[[lab]] <- df # Add datafrane to u_rrdfs
        u_rrnames$labels <- c(u_rrnames$labels, lab) # Add df name to u_rrnames
        u_big_rrdf[['df']] <- add_file_rrdf(df=u_big_rrdf[['df']], 
                                            name=lab, file=TRUE) # Add to big rr list
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
          u_rrnames$labels <- c(u_rrnames$labels, new_name) # Add new name
          u_rrnames$labels <- setdiff(u_rrnames$labels, old_name) # Remove old name
          
          u_rrdfs[[new_name]] <- u_rrdfs[[old_name]] # Add df under new name
          u_rrdfs <- setdiff(names(u_rrdfs), old_name) # Remove old df
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
    
    # PLOTS
    
    get_rr_table <- reactive ({
      req(input$select_table)
      df <- u_rrdfs[[input$select_table]]
      return(df)
    })
    output$rr_table <- DT::renderDT(
      get_rr_table(), filter="top"
    )
    
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
    
    
    # Enrichment Result Heatmaps
    # Top Terms
    observeEvent({
      # Update heatmap whenever these change
      c(input$select_tophmap, input$tophmap_valtype, input$tophmap_cutoff, input$tophmap_nterms)
    }, {
      req(input$edit_hmap_box == "Top terms")
      
      # Set value_by
      tt_valueby_reactive(input$tophmap_valtype)
      
      # Reset custom_data and the list of added genesets and terms
      tt_custom_data_reactive$df <- data.frame()
      top_hmap_df_reactive$df <- data.frame()
      
      if (!is.null(input$select_tophmap)) {
        
        for (i in seq_along(input$select_tophmap)) {
          gs <- u_rrdfs[[input$select_tophmap[i]]]
          gs_name <- input$select_tophmap[i]
          
          # add gs to list only if there exist values smaller than cutoff
          if (any(gs[, tt_valueby_reactive()] < input$tophmap_cutoff)) {
            # Add gs to custom_data_reactive
            if (input$tophmap_nterms != 0) {
              tt_custom_data_reactive$df <- add_topterm_gs(custom_data=tt_custom_data_reactive$df, 
                                                            gs=gs, 
                                                            gs_name=gs_name, 
                                                            value_type=tt_valueby_reactive(), 
                                                            value_cutoff=input$tophmap_cutoff, 
                                                            top_nterms=input$tophmap_nterms)
            }
            # Add gs to top_hmap_df_reactive
            top_hmap_df_reactive$df <- add_rr_tophmap(df=top_hmap_df_reactive$df, 
                                                      name=gs_name, 
                                                      value_type=tt_valueby_reactive(), 
                                                      value_cutoff=input$tophmap_cutoff,
                                                      top_nterms=input$tophmap_nterms)
          }
        }
      }
      
    })
    
    # Reactively update top_hmap_df
    top_hmap_to_table <- reactive ({
      req(!is.null(top_hmap_df_reactive))
      return(top_hmap_df_reactive$df)
    })
    # Plot tabled list of gs in top terms hmap
    output$tophmap_table = DT::renderDT(
      top_hmap_to_table(), 
      editable = list(target='cell', disable=list(columns = c(1:2)))
    )
    # Table editing code
    proxy = dataTableProxy('tophmap_table')
    observeEvent(input$tophmap_table_cell_edit, {
      info = input$tophmap_table_cell_edit
      str(info)
      i = info$row
      j = info$col
      v = info$value
      
      top_hmap_df_reactive$df[i, j] <<- DT::coerceValue(v, top_hmap_df_reactive$df[i, j])
      gs_name <- top_hmap_df_reactive$df[i, 1]
      top_nterms <- top_hmap_df_reactive$df[i, 4]

      if (top_nterms != 0) {
        tt_custom_data_reactive$df <- tryCatch ({
          add_topterm_gs(custom_data=tt_custom_data_reactive$df,
                         gs=u_rrdfs[[gs_name]],
                         gs_name=gs_name,
                         value_type=tt_valueby_reactive(),
                         value_cutoff=top_hmap_df_reactive$df[i, 3],
                         top_nterms=top_hmap_df_reactive$df[i, 4])
        }, error = function(e) {
          showModal(modalDialog(
            title = "Input error",
            e$message,
            easyClose = TRUE
          ))
          return(tt_custom_data_reactive$df)
        })
      } else {
        showModal(modalDialog(
          title = "Input error",
          "Please input a non-zero number of top terms.",
          easyClose = TRUE
        ))
      }
    })
    
    
    # Custom terms heatmap
    # Reactively update custom term select table based on selection
    rr_to_table <- reactive ({
      req(input$select_cushmap)
      df <- u_rrdfs[[input$select_cushmap]]
      return(df)
    })
    # Plot custom term select table
    output$cushmap_select_table = DT::renderDT(
      rr_to_table(),
      filter = "top",
      options = list(
        pageLength = 5
      ),
    )
    
    # Add custom selected terms to heatmap
    observeEvent(input$cushmap_add_rr, {
      req(input$select_cushmap)
      req(input$cushmap_select_table_rows_selected)
      
      # Set value_by
      cus_valueby_reactive(input$cushmap_valtype)
      
      gs_name <- input$select_cushmap
      gs <- u_rrdfs[[gs_name]] # Store df of selected rr
      
      term_df <- gs[input$cushmap_select_table_rows_selected, ] # Subset df with selected term rows
      term_vec <- term_df$Term # get only Term column of subsetted df
      
      # Add gs to custom_data_reactive
      custom_data_reactive$df <- add_custom_gs(custom_data=custom_data_reactive$df, 
                                        gs=gs, 
                                        gs_name=gs_name, 
                                        term_vec=term_vec)
      
      # Add only unique terms to rr_term_vec_reactive
      # If gs already added
      if (gs_name %in% names(rr_term_vec_reactive)) {
        unique_term_vec <- setdiff(term_vec, rr_term_vec_reactive[[gs_name]])
        rr_term_vec_reactive[[gs_name]] <- c(rr_term_vec_reactive[[gs_name]], unique_term_vec)
        
        # Update selectInput if gs is currently selected in delete box
        if (input$rr_delete_select == gs_name) {
          updateSelectInput(session=getDefaultReactiveDomain(), 'rr_term_delete_select',
                            choices=rr_term_vec_reactive[[gs_name]])
        }
      } 
      # No previous term_vec_reactive for that gs
      else {
        rr_term_vec_reactive[[gs_name]] <- term_vec
      }
      
      # Add gs name to rr_custom_list_reactive
      rr_custom_list_reactive$labels <- c(rr_custom_list_reactive$labels, input$select_cushmap)
      
    })
    
    # Update term delete select based on rr selected
    observeEvent(input$rr_delete_select, {
      req(input$rr_delete_select)
      if (!is.null(rr_term_vec_reactive)) {
        updateSelectInput(session=getDefaultReactiveDomain(), 'rr_term_delete_select',
                          choices=rr_term_vec_reactive[[input$rr_delete_select]])
      }
    })
    
    # Remove selected terms from heatmap
    observeEvent(input$delete_rr_terms, {
      req(input$rr_term_delete_select)
      req(input$rr_delete_select)
      
      custom_data_reactive$df <- remove_gs(custom_data=custom_data_reactive$df, 
                                           gs_name=input$rr_delete_select, 
                                           term_vec=input$rr_term_delete_select)
      
      # Remove terms from rr_term_vec_reactive
      prev_terms <- rr_term_vec_reactive[[input$rr_delete_select]]
      rr_term_vec_reactive[[input$rr_delete_select]] <- prev_terms[-which(prev_terms %in% input$rr_term_delete_select)]
      
      # Reflect new changes
      updateSelectInput(session=getDefaultReactiveDomain(), 'rr_term_delete_select',
                        choices=rr_term_vec_reactive[[input$rr_delete_select]])
    })
    
    # Delete entire result from heatmap
    observeEvent(input$delete_rr, {
      req(input$rr_delete_select)
      gs_name <- input$rr_delete_select
      gs <- u_rrdfs[[gs_name]]
      all_terms <- gs$Term
      custom_data_reactive$df <- remove_gs(custom_data=custom_data_reactive$df, 
                                           gs_name=gs_name, 
                                           term_vec=input$rr_term_delete_select, 
                                           delete_all=TRUE)
      # Remove result name from list
      rr_custom_list_reactive$labels <- setdiff(rr_custom_list_reactive$labels, gs_name)
    })
    
    # Reactively update whenever valtype changes
    observeEvent(input$cushmap_valtype, {
      cus_valueby_reactive(input$cushmap_valtype)
    })
    
    # Plot enrichment result heatmaps
    plot_topterm_heatmap <- reactive({
      if (nrow(tt_custom_data_reactive$df) != 0) {
        hmap <- custom_hmap(custom_data=tt_custom_data_reactive$df, value_type=tt_valueby_reactive())
        return(hmap)
      }
    })
    output$topterm_hmap <- renderPlotly({
      plot_topterm_heatmap()
    })
    
    plot_custom_hmap <- reactive({
      if (nrow(custom_data_reactive$df) != 0) {
        hmap <- custom_hmap(custom_data=custom_data_reactive$df, value_type=cus_valueby_reactive())
        return(hmap)
      }
    })
    output$custom_hmap <- renderPlotly({
      plot_custom_hmap()
    })
    
  })
}