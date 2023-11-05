# ENRICH TAB CONTENTS

enrichTabUI <- function(id, tabName) {
  ns <- NS(id)
  tabItem(tabName = tabName,
    fluidRow(
      column(width = 4,
        box(title="Enrich", width=12, status="primary", solidHeader=TRUE,
          br(),
          selectInput(ns('selected_degs'), "Select DEG sets to enrich", choices=NULL, multiple=TRUE),
          textInput(ns('header_input'), "Header", value="geneID"),
          selectInput(ns('anntype_select'), "Select annotation source", c("GO", "KEGG", "Reactome", "KEGGM")),
          selectInput(ns('keytype_select'), "Select keytype", 
                      c("ACCNUM", "ALIAS", "ENSEMBL", "ENSEMBLPROT", "ENSEMBLTRANS",
                        "ENTREZID", "ENZYME", "EVIDENCE", "EVIDENCEALL", "FLYBASE",
                        "FLYBASECG", "FLYBASEPROT", "GENENAME", "GO", "GOALL", "MAP",
                        "ONTOLOGY", "ONTOLOGYALL", "PATH", "PMID", "REFSEQ", "SYMBOL",
                        "UNIGENE", "UNIPROT"), selected="SYMBOL"),
          selectInput(ns('ont_select'), "Select ontology", c("BP", "MF", "CC")),
          selectInput(ns('species_select'), "Select species", c('anopheles', 'arabidopsis', 'bovine', 'celegans', 'canine', 'fly', 'zebrafish',
                                                                'ecoli', 'chicken', 'human', 'mouse', 'rhesus', 'malaria', 'chipm', 'rat',
                                                                'toxoplasma', 'sco', 'pig', 'yeast', 'xenopus'), selected='human'),
          actionButton(ns('enrich_deg'), "Enrich")
        )
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
            tabBox(title = "Edit Heatmap", id="edit_hmap_box", width = NULL,
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


enrichTabServer <- function(id, u_degnames, u_degdfs, u_rrnames, u_rrdfs, u_clusnames, u_clusdfs, u_cluslists) {
  
  moduleServer(id, function(input, output, session) {
    
    # create reactive objs to make accessible in other modules
    u_degnames_reactive <- reactive(u_degnames$labels) 
    u_degdfs_reactive <- reactive(u_degdfs) 
    u_rrnames_reactive <- reactive(u_rrnames$labels) 
    u_rrdfs_reactive <- reactive(u_rrdfs)
    u_clusnames_reactive <- reactive(u_clusnames$labels)
    u_clusdfs_reactive <- reactive(u_clusdfs)
    u_cluslists_reactive <- reactive(u_cluslists)
    
    rr_custom_list_reactive <- reactiveValues(labels=NULL)
    rr_term_vec_reactive <- reactiveValues()
    custom_data_reactive <- reactiveValues(df = data.frame())
    
    value_by_reactive <- reactiveVal()
    
    # update select inputs based on # file inputs
    observe({
      updateSelectInput(session=getDefaultReactiveDomain(), 'selected_degs', choices=u_degnames_reactive())
      updateSelectInput(session=getDefaultReactiveDomain(), 'select_bar', choices=u_rrnames_reactive())
      updateSelectInput(session=getDefaultReactiveDomain(), 'select_dot', choices=u_rrnames_reactive())
      updateSelectInput(session=getDefaultReactiveDomain(), 'select_net', choices=u_rrnames_reactive())
      updateSelectInput(session=getDefaultReactiveDomain(), 'select_table', choices=u_rrnames_reactive())
      updateSelectInput(session=getDefaultReactiveDomain(), 'ez_add_select', choices=u_rrnames_reactive())
      updateSelectInput(session=getDefaultReactiveDomain(), 'rr_add_select', choices=u_rrnames_reactive())
    })
    
    
    # <!----- ENRICH LOGIC -----!>
    # enrich selected degs
    observeEvent(input$enrich_deg, {
      req(input$selected_degs)
      
      withProgress(message="Enriching DEG sets...", value=0, {
        
        for (i in seq_along(input$selected_degs)) {
          x <- u_degdfs[[input$selected_degs[i]]]
          
          # enrich
          df <- shiny_enrich(x=x, header=as.character(input$header_input), species=input$species_select,
                             anntype=as.character(input$anntype_select), keytype=as.character(input$keytype_select), ontology=as.character(input$ont_select))
          incProgress(1/length(input$selected_degs), message=NULL, detail=paste("Done enriching", input$selected_degs[i]))
          lab <- input$selected_degs[i]
          
          u_rrdfs[[lab]] <- df@result # set u_rrdfs
          u_rrnames$labels <- c(u_rrnames$labels, lab) # set u_rrnames 
        }
        
      })
      
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