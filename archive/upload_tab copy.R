# 
# uploadTabCopyUI <- function(id, tabName) {
#   ns <- NS(id)
#   # Edit Files Subtab
#   tabItem(tabName = tabName,
#           tabBox(title="Edit", id="edit_files", width=NULL,
#                  tabPanel("Rename",
#                           selectInput(ns("rename_deg_select"), "Select DEG set", choices=NULL, multiple=FALSE),
#                           textInput(ns("new_deg_name"), "Name", placeholder="New DEG set name"),
#                           # rename enrichment results
#                           selectInput(ns("rename_rr_select"), "Select enrichment result", choices=NULL, multiple=FALSE),
#                           textInput(ns("new_rr_name"), "Name", placeholder="New enrichment result name"),
#                           # rename cluster results
#                           selectInput(ns("rename_clus_select"), "Select cluster result", choices=NULL, multiple=FALSE),
#                           textInput(ns("new_clus_name"), "Name", placeholder="New cluster result name"),
#                           br(),
#                           actionButton(ns('rename_btn'), "Rename selection")
#                  ),
#                  tabPanel("Remove",
#                           selectInput(ns("remove_deg_select"), "Select DEG sets to remove", choices=NULL, multiple=TRUE),
#                           selectInput(ns("remove_rr_select"), "Select enrichment results to remove", choices=NULL, multiple=TRUE),
#                           selectInput(ns("remove_clus_select"), "Select cluster results to remove", choices=NULL, multiple=TRUE),
#                           br(),
#                           actionButton(ns('remove_btn'), "Remove selection")
#                  )
#           )
#   )
# }
# 
# 
# uploadTabCopyServer <- function(id, u_degnames, u_degdfs, u_rrnames, u_rrdfs, u_clusnames, u_clusdfs, u_cluslists) {
#   
#   moduleServer(id, function(input, output, session) {
#     
#     # create reactive objs to make accessible in other modules
#     u_degnames_reactive <- reactive(u_degnames$labels) 
#     u_degdfs_reactive <- reactive(u_degdfs) 
#     u_rrnames_reactive <- reactive(u_rrnames$labels) 
#     u_rrdfs_reactive <- reactive(u_rrdfs)
#     u_clusnames_reactive <- reactive(u_clusnames$labels)
#     u_clusdfs_reactive <- reactive(u_clusdfs)
#     u_cluslists_reactive <- reactive(u_cluslists)
#     
#     # update select inputs based on # file inputs
#     observe({
#       updateSelectInput(session=getDefaultReactiveDomain(), 'rename_deg_select', choices=u_degnames_reactive())
#       updateSelectInput(session=getDefaultReactiveDomain(), 'remove_deg_select', choices=u_degnames_reactive())
#       updateSelectInput(session=getDefaultReactiveDomain(), 'deg_table_select', choices=u_degnames_reactive())
#       
#       updateSelectInput(session=getDefaultReactiveDomain(), 'rename_rr_select', choices=u_rrnames_reactive())
#       updateSelectInput(session=getDefaultReactiveDomain(), 'remove_rr_select', choices=u_rrnames_reactive())
#       updateSelectInput(session=getDefaultReactiveDomain(), 'rr_table_select', choices=u_rrnames_reactive())
#       
#       updateSelectInput(session=getDefaultReactiveDomain(), 'rename_clus_select', choices=u_clusnames_reactive())
#       updateSelectInput(session=getDefaultReactiveDomain(), 'remove_clus_select', choices=u_clusnames_reactive())
#       updateSelectInput(session=getDefaultReactiveDomain(), 'clus_table_select', choices=u_clusnames_reactive())
#     })
#     
#     # <!----- EDIT FILES -----!>
#     # Rename files
#     observeEvent(input$rename_btn, {
#       # rename deg
#       new_name <- input$new_deg_name
#       old_name <- input$rename_deg_select
#       if (nchar(new_name) > 0 && nchar(old_name) > 0) {
#         u_degnames$labels <- c(u_degnames$labels, new_name)
#         u_degnames$labels <- setdiff(u_degnames$labels, old_name) # remove old name
#         
#         u_degdfs[[new_name]] <- u_degdfs[[old_name]]
#         u_degdfs <- setdiff(names(u_degdfs), old_name)
#       }
#       
#       # rename rr
#       new_name <- input$new_rr_name
#       old_name <- input$rename_rr_select
#       if (nchar(new_name) > 0 && nchar(old_name) > 0) {
#         u_rrnames$labels <- c(u_rrnames$labels, new_name)
#         u_rrnames$labels <- setdiff(u_rrnames$labels, old_name) # remove old name
#         
#         u_rrdfs[[new_name]] <- u_rrdfs[[old_name]]
#         u_rrdfs <- setdiff(names(u_rrdfs), old_name)
#       }
#       
#       # rename clus
#       new_name <- input$new_clus_name
#       old_name <- input$rename_clus_select
#       if (nchar(new_name) > 0 && nchar(old_name) > 0) {
#         # update clusnames
#         u_clusnames$labels <- c(u_clusnames$labels, new_name)
#         u_clusnames$labels <- setdiff(u_clusnames$labels, old_name) # remove old name
#         
#         # update clusdfs
#         u_clusdfs[[new_name]] <- u_clusdfs[[old_name]]
#         u_clusdfs <- setdiff(names(u_clusdfs), old_name)
#         
#         # update cluslists
#         u_cluslists[[new_name]] <- u_cluslists[[old_name]]
#         u_cluslists <- setdiff(names(u_cluslists), old_name) 
#       }
#     })
#     
#     # Remove files
#     observeEvent(input$remove_btn, {
#       if (!is.null(input$remove_deg_select)) {
#         u_degdfs <- setdiff(names(u_degdfs), input$remove_deg_select)
#         u_degnames$labels <- setdiff(u_degnames$labels, input$remove_deg_select)
#       }
#       if (!is.null(input$remove_rr_select)) {
#         u_rrdfs <- setdiff(names(u_rrdfs), input$remove_rr_select)
#         u_rrnames$labels <- setdiff(u_rrnames$labels, input$remove_rr_select)
#       }
#       if (!is.null(input$remove_clus_select)) {
#         u_clusdfs <- setdiff(names(u_clusdfs), input$remove_clus_select)
#         u_cluslists <- setdiff(names(u_cluslists), input$remove_clus_select)
#         u_clusnames$labels <- setdiff(u_clusnames$labels, input$remove_clus_select)
#       }
#     })
#     
#     # <!----- DEG FILE MANAGEMENT -----!>
#     # when deg upload button clicked
#     observeEvent(input$upload_deg_file, {
#       req(input$deg_files) # Make sure file uploaded
#       
#       for (i in seq_along(input$deg_files$name)) {
#         lab <- input$deg_files$name[i]
#         
#         ext <- tools::file_ext(input$deg_files$name[i])
#         path <- input$deg_files$datapath[i]
#         
#         # read file based on file extension
#         if (ext != "txt") {
#           df <- switch(ext,
#                        csv = read.csv(path),
#                        tsv = read.delim(path),
#                        xls = readxl::read_excel(path)
#           )
#         } else if (ext == "txt" && input$deg_sep != "Guess") {
#           df <- read.csv(path, sep=input$deg_sep)
#         } 
#         # GUESS separator logic
#         else if (ext == "txt" && input$deg_sep == "Guess") {
#           # try to read file as csv
#           csv_ncol <- tryCatch({
#             csvdf <- read.csv(path)
#             ncol(csvdf)
#           }, error = function(err) {
#             0
#           })
#           # try to read file as tsv
#           tsv_ncol <- tryCatch({
#             tsvdf <- read.delim(path)
#             ncol(tsvdf)
#           }, error = function(err) {
#             0
#           })
#           # decide which df to store
#           if (tsv_ncol == 0 || csv_ncol > tsv_ncol) {
#             df <- read.csv(path)
#           } else {
#             df <- read.delim(path)
#           }
#         }
#         
#         u_degdfs[[lab]] <- df # set u_degdfs
#         u_degnames$labels <- c(u_degnames$labels, lab) # set u_degnames 
#       }
#       
#     })
#     
#     observeEvent(input$upload_degtext, {
#       req(input$deg_text, input$degtext_name)
#       x <- strsplit(input$deg_text, "[^[:alnum:]]+")
#       df <- data.frame(GeneID = x)
#       colnames(df) <- c("GeneID")
#       lab <- input$degtext_name
#       
#       u_degdfs[[lab]] <- df # set u_degdfs
#       u_degnames$labels <- c(u_degnames$labels, lab)
#     })
#     
#     # reactively update which deg table is read based on selection
#     deg_to_table <- reactive ({
#       req(input$deg_table_select)
#       df <- u_degdfs[[input$deg_table_select]]
#       return(df)
#     })
#     
#     # output deg table
#     output$deg_table = DT::renderDataTable({
#       deg_to_table()
#     })
#     
#     # download deg
#     output$download_deg <- downloadHandler(
#       filename = function() {
#         req(input$deg_table_select)
#         paste0(input$deg_table_select, input$deg_export_type)
#       },
#       content = function(file) {
#         ext_type <- input$deg_export_type
#         if (ext_type == ".txt") {
#           write.table(u_degdfs[[input$deg_table_select]], file, sep='\t', row.names=FALSE)
#         } else if (ext_type == ".csv") {
#           write.csv(u_degdfs[[input$deg_table_select]], file, row.names=FALSE)
#         } else if (ext_type == ".tsv") {
#           write.table(u_degdfs[[input$deg_table_select]], file, sep='\t', row.names=FALSE)
#         }
#       }
#     )
#     
#     
#     # <!----- RICH RESULT FILE MANAGEMENT -----!>
#     # when rich result upload button clicked
#     observeEvent(input$upload_rr_file, {
#       req(input$rr_files) # Make sure file uploaded
#       
#       for (i in seq_along(input$rr_files$name)) {
#         lab <- input$rr_files$name[i]
#         
#         ext <- tools::file_ext(input$rr_files$name[i])
#         path <- input$rr_files$datapath[i]
#         
#         # read file based on file extension
#         if (ext != "txt") {
#           df <- switch(ext,
#                        csv = read.csv(path),
#                        tsv = read.delim(path),
#                        xls = readxl::read_excel(path)
#           )
#         } else if (ext == "txt" && input$rr_sep != "Guess") {
#           df <- read.csv(path, sep=input$rr_sep)
#         } 
#         # GUESS separator logic
#         else if (ext == "txt" && input$rr_sep == "Guess") {
#           # try to read file as csv
#           csv_ncol <- tryCatch({
#             csvdf <- read.csv(path)
#             ncol(csvdf)
#           }, error = function(err) {
#             0
#           })
#           # try to read file as tsv
#           tsv_ncol <- tryCatch({
#             tsvdf <- read.delim(path)
#             ncol(tsvdf)
#           }, error = function(err) {
#             0
#           })
#           # decide which df to store
#           if (tsv_ncol == 0 || csv_ncol > tsv_ncol) {
#             df <- read.csv(path)
#           } else {
#             df <- read.delim(path)
#           }
#         }
#         
#         u_rrdfs[[lab]] <- df # set u_rrdfs
#         u_rrnames$labels <- c(u_rrnames$labels, lab) # set u_rrnames 
#       }
#       
#     })
#     
#     
#     # reactively update which rr table is read based on selection
#     rr_to_table <- reactive ({
#       req(input$rr_table_select)
#       df <- u_rrdfs[[input$rr_table_select]]
#       return(df)
#     })
#     
#     # output rr table
#     output$rr_table = DT::renderDataTable({
#       rr_to_table()
#     })
#     
#     # download rr
#     output$download_rr <- downloadHandler(
#       filename = function() {
#         req(input$rr_table_select)
#         paste0(input$rr_table_select, input$rr_export_type)
#       },
#       content = function(file) {
#         ext_type <- input$rr_export_type
#         if (ext_type == ".txt") {
#           write.table(u_rrdfs[[input$rr_table_select]], file, sep='\t', row.names=FALSE)
#         } else if (ext_type == ".csv") {
#           write.csv(u_rrdfs[[input$rr_table_select]], file, row.names=FALSE)
#         } else if (ext_type == ".tsv") {
#           write.table(u_rrdfs[[input$rr_table_select]], file, sep='\t', row.names=FALSE)
#         }
#       }
#     )
#     
#     
#     # <!----- CLUSTER RESULT LOGIC -----!>
#     
#     # reactively update which cluster table is read based on selection
#     clus_to_table <- reactive ({
#       req(input$clus_table_select)
#       df <- u_clusdfs[[input$clus_table_select]]
#       return(df)
#     })
#     
#     # output cluster result table
#     output$clus_table = DT::renderDataTable({
#       clus_to_table()
#     })
#     
#     # download cluster result
#     output$download_clus <- downloadHandler(
#       filename = function() {
#         req(input$clus_table_select)
#         paste0(input$clus_table_select, input$clus_export_type)
#       },
#       content = function(file) {
#         ext_type <- input$clus_export_type
#         if (ext_type == ".txt") {
#           write.table(u_clusdfs[[input$clus_table_select]], file, sep='\t', row.names=FALSE)
#         } else if (ext_type == ".csv") {
#           write.csv(u_clusdfs[[input$clus_table_select]], file, row.names=FALSE)
#         } else if (ext_type == ".tsv") {
#           write.table(u_clusdfs[[input$clus_table_select]], file, sep='\t', row.names=FALSE)
#         }
#       }
#     )
#     
#   })
#   
# }