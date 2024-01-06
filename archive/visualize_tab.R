# Old visualize tab
# visualizeTabUI <- function(id, tabName) {
#   ns <- NS(id)
#   tabItem(tabName = tabName,
#     tabsetPanel(
#       tabPanel("Cluster Result Heatmap",
#         br(),
#         
#         # CLUSTER HEATMAP
#         box(title = "Cluster Heatmap", status = "primary", width = 12, collapsible = TRUE,
#           p("Select cluster result to view comprehensive heatmap displaying values for each cluster"),
#           selectInput(ns("clusdf_select"), "Select cluster result", choices=NULL, multiple=FALSE),
#           fluidRow(
#             column(4,
#               selectInput(ns('big_value_type'), "Select value to show", choices=c("Padj", "Pvalue"))
#             ),
#             column(4,
#               selectInput(ns('value_by'), "Calculate value by", choices=c("mean", "median", "min", "max"))
#             )
#           )
#         ),
#         br(),
#         box(title = "Cluster Heatmap", status = "primary", width = 12,
#           solidHeader = TRUE,
#           plotlyOutput(ns('clusdf_hmap')),
#         ),
#         br(),
#         
#         # TERM HEATMAP
#         box(title = "Term Heatmap", status = "primary", width = 12, collapsible = TRUE,
#           p("Select individual clusters to view heatmap of values for each term in cluster"),
#           selectInput(ns("indiv_clus_select"), "Select individual clusters", choices=NULL, multiple=TRUE),
#           selectInput(ns('small_value_type'), "Select value to show", choices=c("Padj", "Pvalue"))
#         ),
#         br(),
#         box(title = "Term Heatmap", status = "primary", width = 12,
#           solidHeader = TRUE,
#           plotlyOutput(ns('indiv_clus_hmap'))
#         )
#       ),
#       
#       # ENRICHMENT RESULT HEATMAP
#       tabPanel("Enrichment Result Heatmap",
#         br(),
#         tabBox(title = "Edit Heatmap", id="edit_hmap_box", width = 12,
#           # EZ heatmap
#           tabPanel("Quick make",
#             selectInput(ns("ez_add_select"), "Select enrichment results", choices=NULL, multiple=TRUE),
#             fluidRow(
#               column(4, 
#                 selectInput(ns("ez_value_by"), "Select top terms by", choices=c("Padj", "Pvalue")),
#               ),
#               column(4,
#                 numericInput(ns("ez_value_cutoff"), "P-value cutoff", value=0.05, min=0, max=1)
#               )
#             ),
#             sliderInput(ns("ez_nterms"), "Number of terms per result to display", value=10, min=0, max=100)
#           ),
#           # add enrichment result to heatmap
#           tabPanel("Add",
#             selectInput(ns("rr_add_select"), "Select enrichment result", choices=NULL, multiple=FALSE),
#             fluidRow(
#               column(4,
#                 numericInput(ns('top_rr_terms'), "Select top ? terms", value = 20, min=0, max=100)
#               ),
#               column(4,
#                 selectInput(ns('rr_top_value_by'), "Select top terms by", choices=c("Padj", "Pvalue"))
#               ),
#               column(4,
#                 numericInput(ns("rr_value_cutoff"), "P-value cutoff", value=0.05, min=0, max=1)
#               )
#             ),
#             DT::dataTableOutput(ns('rr_select_table')),
#             actionButton(ns('add_rr'), "Add terms")
#           ),
#           # delete result/terms from heatmap
#           tabPanel("Delete",
#             selectInput(ns("rr_delete_select"), "Select enrichment result", choices=NULL, multiple=FALSE),
#             selectInput(ns("rr_term_delete_select"), "Select terms to delete", choices=NULL, multiple=TRUE),
#             fluidRow(
#               column(4,
#                 actionButton(ns('delete_rr_terms'), "Delete selected terms")
#               ),
#               column(4,
#                 actionButton(ns('delete_rr'), "Delete entire result")
#               )
#             )
#           )
#         ),
#         br(),
#         box(title="Enrichment Result Heatmap", status="primary", width=12,
#           solidHeader = TRUE,
#           plotlyOutput(ns('rr_hmap')),
#         )
#       ),
#       
#       # CLUSTER INFO TABLE
#       tabPanel("Cluster Info",
#         br(),
#         box(title = "Detailed Cluster Info", status = "primary", width = 12,
#           solidHeader = TRUE,
#           p("View and export individual term data for cluster results"),
#           fluidRow(
#             column(4,
#               selectInput(ns("cluslist_select"), "Select cluster result", choices=NULL, multiple=FALSE),
#             ),
#             column(4,
#               selectInput(ns('cluslist_export_type'), "Export as", choices=c(".txt", ".csv", ".tsv"))
#             )
#           ),
#           DT::dataTableOutput(ns('cluslist_table')),
#           br(),
#           downloadButton(ns("download_cluslist"), "Download"),
#         )
#       )
#     )
#   )
# }
# 
# 
# visualizeTabServer <- function(id, u_rrnames, u_rrdfs, u_clusnames, u_clusdfs, u_cluslists) {
#   
#   moduleServer(id, function(input, output, session) {
#     
#     # create reactive objs to make accessible in other modules
#     u_rrnames_reactive <- reactive(u_rrnames$labels) 
#     u_rrdfs_reactive <- reactive(u_rrdfs)
#     u_clusnames_reactive <- reactive(u_clusnames$labels)
#     u_clusdfs_reactive <- reactive(u_clusdfs)
#     u_cluslists_reactive <- reactive(u_cluslists)
#     
#     term_vec_reactive <- reactiveVal(NULL)
#     
#     rr_custom_list_reactive <- reactiveValues(labels=NULL)
#     rr_term_vec_reactive <- reactiveValues()
#     custom_data_reactive <- reactiveValues(df = data.frame())
#     
#     value_by_reactive <- reactiveVal()
#     
#     #custom_data <- data.frame()
#     # custom_data_reactive <- reactive({
#     #   data.frame()
#     # })
#     
#     # update select inputs based on # cluster results
#     observe({
#       updateSelectInput(session=getDefaultReactiveDomain(), 'clusdf_select', choices=u_clusnames_reactive())
#       updateSelectInput(session=getDefaultReactiveDomain(), 'indiv_clus_select', choices=term_vec_reactive())
#       updateSelectInput(session=getDefaultReactiveDomain(), 'ez_add_select', choices=u_rrnames_reactive())
#       updateSelectInput(session=getDefaultReactiveDomain(), 'rr_add_select', choices=u_rrnames_reactive())
#       updateSelectInput(session=getDefaultReactiveDomain(), 'cluslist_select', choices=u_clusnames_reactive())
#       updateSelectInput(session=getDefaultReactiveDomain(), 'rr_delete_select', choices=rr_custom_list_reactive$labels)
#     })
#     
#     # Update term_vec_reactive when cluster result selection changes
#     observeEvent(input$clusdf_select, {
#       req(input$clusdf_select)
#       
#       df <- u_clusdfs[[input$clusdf_select]]
#       term_vec_reactive(unique(df$Representative_Term))
#       
#       df <- u_clusdfs[[input$clusdf_select]]
#       cluslist_df <- u_cluslists[[input$clusdf_select]]
#       
#       hmap <- comprehensive_hmap(final_data=df, cluster_list=cluslist_df, 
#                                  value_type=input$big_value_type, value_by=input$value_by)
#       
#       output$clusdf_hmap <- renderPlotly({
#         hmap
#       })
#       
#     })
#     observeEvent(input$rr_delete_select, {
#       req(input$rr_delete_select)
#       if (!is.null(rr_term_vec_reactive)) {
#         tmp <- rr_term_vec_reactive[[input$rr_delete_select]]
#         updateSelectInput(session=getDefaultReactiveDomain(), 'rr_term_delete_select', choices=tmp)
#       }
#     })
#     
#     # # plot cluster result
#     # plot_clusdf_hmap <- reactive({
#     #   req(input$clusdf_select)
#     #   
#     #   df <- u_clusdfs[[input$clusdf_select]]
#     #   cluslist_df <- u_cluslists[[input$clusdf_select]]
#     #   
#     #   hmap <- comprehensive_hmap(final_data=df, cluster_list=cluslist_df, 
#     #                              value_type=input$big_value_type, value_by=input$value_by)
#     #   return(hmap)
#     # })
#     # output$clusdf_hmap <- renderPlotly({
#     #   plot_clusdf_hmap()
#     # })
#     
#     
#     # Enrichment Result Heatmap
#     # quick make
#     ez_listen <- reactive({
#       list(input$ez_add_select, input$ez_value_by, input$ez_nterms, input$ez_value_cutoff)
#     })
#     observeEvent(ez_listen(), {
#       req(input$ez_add_select)
#       # reset custom_data and the list of added genesets and terms
#       custom_data_reactive$df <- data.frame() 
#       rr_custom_list_reactive <- NULL
#       rr_term_vec_reactive <- NULL
#       value_by_reactive(input$ez_value_by)
#       
#       if (input$ez_nterms != 0) {
#         
#         for (i in seq_along(input$ez_add_select)) {
#           gs <- u_rrdfs[[input$ez_add_select[i]]]
#           
#           # add gs to list only if there exist values smaller than cutoff
#           if (any(gs[, value_by_reactive()] < input$rr_value_cutoff)) {
#             gs <- filter(gs, gs[, value_by_reactive()]<input$ez_value_cutoff)
#             sliced_gs <- arrange(gs, value_by_reactive())
#             sliced_gs <- slice_head(sliced_gs, n=input$ez_nterms)
#             term_vec <- sliced_gs$Term
#             
#             # add gs to custom_data_reactive
#             custom_data_reactive$df <- add_gs(custom_data=custom_data_reactive$df, gs=gs, 
#                                               gs_name=input$ez_add_select[i], term_vec=term_vec)
#             # add terms to rr_term_vec_reactive
#             rr_term_vec_reactive[[input$rr_add_select]] <- term_vec
#             # add gs name to rr_custom_list_reactive
#             rr_custom_list_reactive$labels <- c(rr_custom_list_reactive$labels, input$rr_add_select)
#           }
#         }
#       }
#       
#     })
#     
#     # add
#     # reactively update which rr table is read based on selection
#     rr_to_table <- reactive ({
#       req(input$rr_add_select)
#       df <- u_rrdfs[[input$rr_add_select]]
#       return(df)
#     })
#     # output rr table
#     output$rr_select_table = DT::renderDataTable(
#       rr_to_table()
#     )
#     
#     # add selected terms to heatmap
#     observeEvent(input$add_rr, {
#       req(input$rr_select_table_rows_selected)
#       
#       # set value_by
#       value_by_reactive(input$rr_top_value_by)
#       
#       gs <- u_rrdfs[[input$rr_add_select]] # store df of selected rr
#       
#       # ensure there exist values smaller than cutoff before filtering
#       if (any(gs[, value_by_reactive()] < input$rr_value_cutoff)) {
#         gs <- filter(gs, gs[, value_by_reactive()]<input$rr_value_cutoff)
#         term_vec <- gs[input$rr_select_table_rows_selected, ] # subset df with selected rows
#         term_vec <- term_vec$Term # get only Term column of subsetted df
#         
#         # add gs to custom_data_reactive
#         custom_data_reactive$df <- add_gs(custom_data=custom_data_reactive$df, gs=gs, 
#                                           gs_name=input$rr_add_select, term_vec=term_vec)
#         
#         # add terms to rr_term_vec_reactive
#         rr_term_vec_reactive[[input$rr_add_select]] <- term_vec
#         # add gs name to rr_custom_list_reactive
#         rr_custom_list_reactive$labels <- c(rr_custom_list_reactive$labels, input$rr_add_select)
#       }
#       
#     })
#     
#     # remove selected terms from heatmap
#     observeEvent(input$delete_rr_terms, {
#       req(input$rr_term_delete_select)
#       req(input$rr_delete_select)
#       custom_data_reactive$df <- remove_gs(custom_data_reactive$df, input$rr_delete_select, input$rr_term_delete_select)
#       
#       tmp <- rr_term_vec_reactive[[input$rr_delete_select]]
#       rr_term_vec_reactive[[input$rr_delete_select]] <- tmp[-which(tmp %in% input$rr_term_delete_select)]
#       updateSelectInput(session=getDefaultReactiveDomain(), 'rr_term_delete_select', 
#                         choices=rr_term_vec_reactive[[input$rr_delete_select]])
#     })
#     
#     # delete entire result from heatmap
#     observeEvent(input$delete_rr, {
#       req(input$rr_delete_select)
#       gs <- u_rrdfs[[input$rr_delete_select]]
#       all_terms <- gs$Term
#       custom_data_reactive$df <- remove_gs(custom_data=custom_data_reactive$df, gs_name=input$rr_delete_select, 
#                                            input$rr_term_delete_select, all_terms)
#       # remove result name from list
#       rr_custom_list_reactive$labels <- setdiff(rr_custom_list_reactive$labels, input$rr_delete_select)
#     })
#     
#     # plot enrichment result heatmap
#     plot_custom_hmap <- reactive({
#       if (nrow(custom_data_reactive$df) != 0) {
#         hmap <- custom_hmap(custom_data=custom_data_reactive$df, value_type=value_by_reactive())
#         return(hmap)
#       }
#     })
#     output$rr_hmap <- renderPlotly({
#       plot_custom_hmap()
#     })
#     
#     # plot indiv cluster hmap
#     plot_cluslist_hmap <- reactive({
#       req(input$indiv_clus_select)
#       
#       df <- u_clusdfs[[input$clusdf_select]]
#       cluslist_df <- u_cluslists[[input$clusdf_select]]
#       
#       hmap <- cluster_hmap(cluster_list=cluslist_df, term_vec=input$indiv_clus_select, 
#                            final_data=df, value_type=input$small_value_type)
#       
#       return(hmap)
#     })
#     output$indiv_clus_hmap <- renderPlotly({
#       plot_cluslist_hmap()
#     })
#     
#     # reactively update which cluster list table is read based on selection
#     cluslist_to_table <- reactive ({
#       req(input$cluslist_select)
#       df <- u_cluslists[[input$cluslist_select]]
#       return(df)
#     })
#     # output cluslist table
#     output$cluslist_table = DT::renderDataTable({
#       cluslist_to_table()
#     })
#     
#     # download cluslist table
#     output$download_cluslist <- downloadHandler(
#       filename = function() {
#         req(input$cluslist_select)
#         paste0(input$cluslist_select, input$cluslist_export_type)
#       },
#       content = function(file) {
#         ext_type <- input$cluslist_export_type
#         if (ext_type == ".txt") {
#           write.table(u_cluslists[[input$cluslist_select]], file, sep='\t', row.names=FALSE)
#         } else if (ext_type == ".csv") {
#           write.csv(u_cluslists[[input$cluslist_select]], file, row.names=FALSE)
#         } else if (ext_type == ".tsv") {
#           write.table(u_cluslists[[input$cluslist_select]], file, sep='\t', row.names=FALSE)
#         }
#       }
#     )
#   })
#   
# }