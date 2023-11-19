
uploadTabUI <- function(id, tabName) {
  ns <- NS(id)
  tabItem(tabName = tabName,
    # UPLOAD TAB CONTENTS
    fluidRow(
      column(width = 6, 
        tabBox(title=span(icon("upload"), "File upload"), id='upload_box', width=NULL,
          # DEG upload panel
          tabPanel("DEG Sets",
            fileInput(ns('deg_files'), 'Select files', multiple=TRUE, accept=c('.csv', '.tsv', '.xls', '.txt')),
            helpText("Accepted formats: .txt, .csv, .tsv"),
            selectInput(ns('deg_sep'), "Element separator", c(Comma=",", Space=" ", Tab="\t", "Guess"), selected="Guess"),
            actionButton(ns('upload_deg_file'), "Upload")
          ),
          # Rich Result upload panel
          tabPanel("Enrichment Results",
            fileInput(ns('rr_files'), 'Select files', multiple=TRUE, accept=c('.csv', '.tsv', '.xls', '.txt')),
            helpText("Accepted formats: .txt, .csv, .tsv"),
            selectInput(ns('rr_sep'), "Element separator", c(Comma=",", Space=" ", Tab="\t", "Guess"), selected="Guess"),
            actionButton(ns('upload_rr_file'), "Upload")
          )
        ),
      ),
      column(width = 6,
        tabBox(title=span(icon("pencil"), "Text input"), id='text_upload', width=NULL, 
          tabPanel("DEG Sets",
            br(),
            textAreaInput(ns('deg_text'), "Text Input", placeholder="Paste list of significant genes"),
            textInput(ns('degtext_name'), "Name", placeholder="Set name for pasted gene list"),
            actionButton(ns('upload_degtext'), "Upload")
          ),
          tabPanel("Enrichment Results",
          )
        )
      ),
    ),
    tabBox(title="Table view/export", id='table_box', width=NULL, 
      tabPanel("DEG sets",
        fluidRow(
          column(4,
            selectInput(ns('deg_table_select'), "Select DEG set", choices=NULL),
          ),
          column(4,
            selectInput(ns('deg_export_type'), "Export as", choices=c(".txt", ".csv", ".tsv"))
          )
        ),
        downloadButton(ns("download_deg"), "Download"),
        br(),
        br(),
        br(),
        DT::dataTableOutput(ns('deg_table')),
      ),
      tabPanel("Enrichment results",
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
        DT::dataTableOutput(ns('rr_table')),
      ),
      tabPanel("Cluster results",
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
        DT::dataTableOutput(ns('clus_table')),
      )
    )
  )
}


uploadTabServer <- function(id, u_degnames, u_degdfs, u_rrnames, u_rrdfs, u_clusnames, u_clusdfs, u_cluslists) {
  
  moduleServer(id, function(input, output, session) {
    
    # create reactive objs to make accessible in other modules
    u_degnames_reactive <- reactive(u_degnames$labels) 
    u_degdfs_reactive <- reactive(u_degdfs) 
    u_rrnames_reactive <- reactive(u_rrnames$labels) 
    u_rrdfs_reactive <- reactive(u_rrdfs)
    u_clusnames_reactive <- reactive(u_clusnames$labels)
    u_clusdfs_reactive <- reactive(u_clusdfs)
    u_cluslists_reactive <- reactive(u_cluslists)
    
    # update select inputs based on # file inputs
    observe({
      updateSelectInput(session=getDefaultReactiveDomain(), 'deg_table_select', choices=u_degnames_reactive())
      updateSelectInput(session=getDefaultReactiveDomain(), 'rr_table_select', choices=u_rrnames_reactive())
      updateSelectInput(session=getDefaultReactiveDomain(), 'clus_table_select', choices=u_clusnames_reactive())
    })
    
    # <!----- DEG FILE MANAGEMENT -----!>
    # when deg upload button clicked
    observeEvent(input$upload_deg_file, {
      req(input$deg_files) # Make sure file uploaded
      
      for (i in seq_along(input$deg_files$name)) {
        lab <- input$deg_files$name[i]
        
        ext <- tools::file_ext(input$deg_files$name[i])
        path <- input$deg_files$datapath[i]
        
        # read file based on file extension
        if (ext != "txt") {
          df <- switch(ext,
            csv = read.csv(path),
            tsv = read.delim(path),
            xls = readxl::read_excel(path)
          )
        } else if (ext == "txt" && input$deg_sep != "Guess") {
          df <- read.csv(path, sep=input$deg_sep)
        } 
        # GUESS separator logic
        else if (ext == "txt" && input$deg_sep == "Guess") {
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
        }
        
        u_degdfs[[lab]] <- df # set u_degdfs
        u_degnames$labels <- c(u_degnames$labels, lab) # set u_degnames 
      }
      
    })
    
    observeEvent(input$upload_degtext, {
      req(input$deg_text, input$degtext_name)
      x <- strsplit(input$deg_text, "[^[:alnum:]]+")
      df <- data.frame(GeneID = x)
      colnames(df) <- c("GeneID")
      lab <- input$degtext_name
      
      u_degdfs[[lab]] <- df # set u_degdfs
      u_degnames$labels <- c(u_degnames$labels, lab)
    })

    # reactively update which deg table is read based on selection
    deg_to_table <- reactive ({
      req(input$deg_table_select)
      df <- u_degdfs[[input$deg_table_select]]
      #df <- round_tbl(df, 3)
      return(df)
    })
    
    # output deg table
    output$deg_table = DT::renderDataTable({
      deg_to_table()
    })
    
    # download deg
    output$download_deg <- downloadHandler(
      filename = function() {
        req(input$deg_table_select)
        paste0(input$deg_table_select, input$deg_export_type)
      },
      content = function(file) {
        ext_type <- input$deg_export_type
        if (ext_type == ".txt") {
          write.table(u_degdfs[[input$deg_table_select]], file, sep='\t', row.names=FALSE)
        } else if (ext_type == ".csv") {
          write.csv(u_degdfs[[input$deg_table_select]], file, row.names=FALSE)
        } else if (ext_type == ".tsv") {
          write.table(u_degdfs[[input$deg_table_select]], file, sep='\t', row.names=FALSE)
        }
      }
    )
    
    
    # <!----- RICH RESULT FILE MANAGEMENT -----!>
    # when rich result upload button clicked
    observeEvent(input$upload_rr_file, {
      req(input$rr_files) # Make sure file uploaded
      
      for (i in seq_along(input$rr_files$name)) {
        lab <- input$rr_files$name[i]
        
        ext <- tools::file_ext(input$rr_files$name[i])
        path <- input$rr_files$datapath[i]
        
        # read file based on file extension
        if (ext != "txt") {
          df <- switch(ext,
            csv = read.csv(path),
            tsv = read.delim(path),
            xls = readxl::read_excel(path)
          )
        } else if (ext == "txt" && input$rr_sep != "Guess") {
          df <- read.csv(path, sep=input$rr_sep)
        } 
        # GUESS separator logic
        else if (ext == "txt" && input$rr_sep == "Guess") {
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
        }
        
        #u_rrdfs[[lab]] <- select_required_columns(df) # set u_rrdfs
        u_rrdfs[[lab]] <- df # set u_rrdfs
        u_rrnames$labels <- c(u_rrnames$labels, lab) # set u_rrnames 
      }
      
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
    
    
    # <!----- CLUSTER RESULT LOGIC -----!>
    
    # reactively update which cluster table is read based on selection
    clus_to_table <- reactive ({
      req(input$clus_table_select)
      df <- u_clusdfs[[input$clus_table_select]]
      return(df)
    })
    
    # output cluster result table
    output$clus_table = DT::renderDataTable({
      clus_to_table()
    })
    
    # download cluster result
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