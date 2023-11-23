
enrichTabUI <- function(id, tabName) {
  ns <- NS(id)
  tabItem(tabName = tabName,
    # UPLOAD TAB CONTENTS
    useShinyjs(),
    column(width = 4,
      fluidRow( 
        tabBox(title=span(icon("upload"), "Upload DEG sets"), id='upload_box', width=NULL,
          tabPanel("File upload",
            helpText("Accepted formats: .txt, .csv, .tsv"),      
            fileInput(ns('deg_files'), 'Select files', multiple=TRUE, accept=c('.csv', '.tsv', '.xls', '.txt'))
          ),
          tabPanel("Text input",
            helpText("Genes can be separated by any non-alphanumeric character"),
            textAreaInput(ns('deg_text'), "Text Input", placeholder="Paste list of significant genes or dataframe-like object"),
            textInput(ns('degtext_name'), "Name", placeholder="Set name for pasted DEG set"),
            actionButton(ns('upload_degtext'), "Upload")
          )
        ),
        box(title="Enrich", status="primary", solidHeader=TRUE, width=NULL,
          br(),
          selectInput(ns('degs_to_enrich'), "Select DEG sets to enrich", choices=NULL, multiple=TRUE),
          selectInput(ns('anntype_select'), "Select annotation source", c("GO", "KEGG", "Reactome")),
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
    ),
    column(width = 8,
      shinyjs::hidden(tags$div(
        id=ns("list_box"),
        tabBox(title="Uploaded files", width=NULL,
          
          tabPanel("DEG sets",
            tags$div(id=ns("deglist_box"),
              div(style="display:inline-block; float:left", helpText("Double-click on any cell to change its value.")),
              div(style="display:inline-block; float:right", 
                  actionBttn(ns('deglist_help'), label=NULL, style='material-circle', status='primary', icon=icon('info'), size='xs')
              ),
              br(),
              br(),
              DT::DTOutput(ns('deg_list_table')),
              actionButton(ns('remove_deg'), "Delete")
            )
          ),
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
          )
        ))
      ), 
      tabBox(title="View files", width=NULL,
        tabPanel(title="DEG sets",
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
          DT::dataTableOutput(ns('deg_table'))
        ),
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
        )
      )
    )
  )
}


enrichTabServer <- function(id, u_degnames, u_degdfs, u_big_degdf, u_rrnames, u_rrdfs, u_big_rrdf) {
  
  moduleServer(id, function(input, output, session) {
    # Create reactive objs to make accessible in other modules
    u_degnames_reactive <- reactive(u_degnames$labels) 
    u_degdfs_reactive <- reactive(u_degdfs)
    u_rrnames_reactive <- reactive(u_rrnames$labels) 
    u_rrdfs_reactive <- reactive(u_rrdfs)
    
    # Create reactive to store dataframe of uploaded deg/rr
    u_big_degdf_reactive <- reactive(u_big_degdf)
    u_big_rrdf_reactive <- reactive(u_big_rrdf)
    
    # Update select inputs based on # file inputs
    observe ({
      updateSelectInput(session=getDefaultReactiveDomain(), 'deg_table_select', choices= u_degnames_reactive())
      updateSelectInput(session=getDefaultReactiveDomain(), 'degs_to_enrich', choices= u_degnames_reactive())
      updateSelectInput(session=getDefaultReactiveDomain(), 'rr_table_select', choices= u_rrnames_reactive())
    })
    
    observe ({
      # Show/hide entire box
      if (is.null(u_big_degdf[['df']]) && is.null(u_big_rrdf[['df']])) {
        shinyjs::hide('list_box')
      } else if (!is.null(u_big_degdf[['df']]) || !is.null(u_big_rrdf[['df']])) {
        shinyjs::show("list_box")
        # Show/hide delete deg button
        if (is.null(u_big_degdf[['df']])) {
          shinyjs::hide('deglist_box')
        } else if (!is.null(u_big_degdf[['df']])){
          shinyjs::show('deglist_box')
        }
        # Show/hide delete rr button
        if (is.null(u_big_rrdf[['df']])) {
          shinyjs::hide('rrlist_box')
        } else if (!is.null(u_big_rrdf[['df']])){
          shinyjs::show('rrlist_box')
        }
      }
    })
    
    observeEvent(input$deglist_help, {
      showModal(modalDialog(
        title="Help",
        "'GeneID_header' value indicates the column name containing relevant geneID 
        information, and 'has_expr_data' value indicates whether relevant gene expression 
        data is included."
      ))
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
    
    # When deg upload button clicked
    observeEvent(input$deg_files, {
      for (i in seq_along(input$deg_files$name)) {
        lab <- input$deg_files$name[i]
        
        ext <- tools::file_ext(input$deg_files$name[i])
        path <- input$deg_files$datapath[i]
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
        
        u_degdfs[[lab]] <- df # set u_degdfs
        u_degnames$labels <- c(u_degnames$labels, lab) # set u_degnames 
        print("does this work?")
        u_big_degdf[['df']] <- add_file_degdf(u_big_degdf[['df']], lab, df)
        print("yes!")
      }
      
      # Show file list
      # if (!is.null(u_big_degdf[['df']])) {
      #   shinyjs::show("list_box")
      #   print("showing...")
      # }
      
    })
    
    # Parse pasted text inputs
    observeEvent(input$upload_degtext, {
      req(input$deg_text, input$degtext_name)
      x <- strsplit(input$deg_text, "[^[:alnum:]]+")
      df <- data.frame(GeneID = x)
      colnames(df) <- c("GeneID")
      lab <- input$degtext_name
      
      u_degdfs[[lab]] <- df # set u_degdfs
      u_degnames$labels <- c(u_degnames$labels, lab)
      u_big_degdf[['df']] <- add_file_degdf(u_big_degdf[['df']], lab, df)
      
      # Show file list
      # if (!is.null(u_big_degdf[['df']])) {
      #   shinyjs::show("list_box")
      #   print("showing...")
      # }
      
    })

    # Reactively update uploaded file dataframe
    big_degdf_to_table <- reactive({
      u_big_degdf[['df']]
    })
    # Output uploaded file table
    output$deg_list_table = DT::renderDT(
      big_degdf_to_table(), editable='cell'
    )
    # Code from https://github.com/rstudio/DT/pull/480
    proxy = dataTableProxy('deg_list_table')
    observeEvent(input$deg_list_table_cell_edit, {
      info = input$deg_list_table_cell_edit
      str(info)
      i = info$row
      j = info$col
      v = info$value
      print(info$col)
      
      # Rename deg if changing a value in column 1 (name col)
      if (info$col == 1) {
        new_name <- v
        old_name <- u_big_degdf[['df']][i, j]
        if (nchar(new_name) > 0 && nchar(old_name) > 0) {
          u_degnames$labels <- c(u_degnames$labels, new_name)
          u_degnames$labels <- setdiff(u_degnames$labels, old_name) # remove old name
          
          u_degdfs[[new_name]] <- u_degdfs[[old_name]]
          u_degdfs <- setdiff(names(u_degdfs), old_name)
        }
      }
      
      u_big_degdf[['df']][i, j] <<- DT::coerceValue(v, u_big_degdf[['df']][i, j])
    })
    
    # Remove deg from uploaded degs
    observeEvent(input$remove_deg, {
      req(input$deg_list_table_rows_selected)
      
      # Also remove from degdfs and degnames
      for (deg in input$deg_list_table_rows_selected) {
        deg_to_rm <- u_big_degdf[['df']][deg, ]
        deg_to_rm <- deg_to_rm$name
        
        u_degdfs <- setdiff(names(u_degdfs), deg_to_rm)
        u_degnames$labels <- setdiff(u_degnames$labels, deg_to_rm)
      }
      
      # Remove selection from u_big_degdf
      rm_vec <- u_big_degdf[['df']][input$deg_list_table_rows_selected, ]
      u_big_degdf[['df']] <- rm_file_degdf(u_big_degdf[['df']], rm_vec)
      
      # if (is.null(u_big_degdf[['df']])) {
      #   shinyjs::hide("list_box")
      #   print("hide")
      # }
    })
    
    # Reactively update which deg table is read based on selection
    deg_to_table <- reactive ({
      req(input$deg_table_select)
      df <- u_degdfs[[input$deg_table_select]]
      #df <- round_tbl(df, 3)
      return(df)
    })
    
    # Output individual deg preview table
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
    
    # Enrich selected degs
    # test text inputs:
    # Xkr4 Rp1 Sox17
    # Mrpl15 Lypla1 Tcea1
    observeEvent(input$enrich_deg, {
      req(input$degs_to_enrich)
      
      withProgress(message="Enriching DEG sets...", value=0, {
        
        for (i in seq_along(input$degs_to_enrich)) {
          x <- u_degdfs[[input$degs_to_enrich[i]]]
          
          lab <- input$degs_to_enrich[i]
          big_degdf <- u_big_degdf[['df']]
          
          gene_header <- big_degdf[big_degdf$name %in% lab, ]
          gene_header <- gene_header$GeneID_header
          
          # enrich
          df <- shiny_enrich(x=x, header=gene_header, species=input$species_select,
                             anntype=as.character(input$anntype_select), keytype=as.character(input$keytype_select), ontology=as.character(input$ont_select))
          incProgress(1/length(input$degs_to_enrich), message=NULL, detail=paste("Done enriching", input$degs_to_enrich[i]))
          
          u_big_rrdf[['df']] <- add_file_rrdf(u_big_rrdf[['df']], name=lab, annot=as.character(input$anntype_select), 
                                              keytype=as.character(input$keytype_select), ontology=as.character(input$ont_select), 
                                              species=input$species_select, file=FALSE)
          lab <- paste0(lab, "_enriched")
          u_rrdfs[[lab]] <- df@result # set u_rrdfs
          u_rrnames$labels <- c(u_rrnames$labels, lab) # set u_rrnames 
          
        }
        
      })
      
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
    
    
  })
  
}