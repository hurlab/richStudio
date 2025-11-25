
clusterTabUI <- function(id, tabName) {
  ns <- NS(id)
  tabItem(tabName = tabName,
    box(title="Cluster", width = NULL,
        fluidRow(
          column(width = 6,
            h4("Select results"),
            selectInput(ns('selected_rrs'), "Select enrichment results to cluster", choices=NULL, multiple=TRUE),
          ), column(width = 6,
            h4("Name"),
            textInput(ns('cluster_name'), "Choose a descriptive name for the cluster group", value="Test group"),
      )),
      fluidRow(
        column(width = 6,
          h4("Similarity metric"),
          selectInput(ns('similarity_metric'), "Choose a similarity metric to cluster terms by", c("Kappa Score"="kappa")),
        ), column(width = 6,
          h4("Similarity cutoff"),
          numericInput(ns('similarity_cutoff'), "Set the minimum similarity value to create initial SeedMap from", value=.5, min=0, max=1),
      )),
      fluidRow(
        column(width = 4,
               h4("Merging criteria"),
               selectInput(ns('merge_strategy'), 
                           "Choose a merging strategy to cluster terms by", 
                           c("DAVID"="david")),
        ), 
        column(width = 4,
               h4("Membership method"),
               selectInput(ns('membership_strategy'), 
                           "Choose a membership method to define how cluster intrasimilarity should be defined", 
                           c("Multiple linkage"="multiple_linkage")),
        ),
        column(width = 4,
                  h4("Membership cutoff"),
                  numericInput(ns('membership_cutoff'), "Set the minimum similarity value to cluster by", value=.5, min=0, max=1),
        )),
      h4("Minimum cluster size"),
      numericInput(ns('min_size'), "At least how many terms should be in each cluster?", value=2, min=0),
      actionButton(ns('cluster'), "Cluster")
    ),
    shinyjs::hidden(tags$div(
      id=ns("cluster_intermediate_box"),
      tabBox(title="Intermediate results", width=NULL,
        tabPanel(title="DistanceMatrix",
          p("Stuff goes here..."),
          DT::DTOutput(ns('distanceMatrix_table'))
        ),
        tabPanel(title="SeedMap",
          p("Where all indices associated with a particular key represent another term which has a kappa score >= 0.50 with the key."),
          DT::DTOutput(ns('clusterMap_table'))
        ),
        tabPanel(title="FilteredSeeds",
          p("Yay..."),
          DT::DTOutput(ns('InitialSeeds_table'))
        ),
        tabPanel(title="MergedSeeds",
          p("Yay..."),
          DT::DTOutput(ns('MergeSeeds_table'))
        )
      ))
    )
  )
}


clusterTabServer <- function(id, u_degnames, u_degdfs, u_rrnames, u_rrdfs, u_big_rrdf,
                             u_clusnames, u_clusdfs, u_big_clusdf, u_cluslists, clus_intermed) {

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

    cluster_intermediate <- reactive(clus_intermed)


    # update select inputs based on # cluster results
    observe({
      updateSelectInput(session=getDefaultReactiveDomain(), 'selected_rrs', choices=u_rrnames_reactive())
    })

    # hide/show the distanceMatrix box
    observe ({
      # Show/hide entire box
      if (length(cluster_intermediate) == 0) {
        shinyjs::hide('cluster_intermediate_box')
      } else {
        shinyjs::show('cluster_intermediate_box')
      }
    })

    # <!----- CLUSTERING LOGIC -----!>
    # Clustering
    observeEvent(input$cluster, {
      req(input$selected_rrs) # Require rich result selection
      req(input$cluster_name) # Require cluster name

      withProgress(message="Clustering...", value=0, {
        selected_rrs <- as.vector(input$selected_rrs)
        genesets <- list()
        gs_names <- c()
        for (i in seq_along(selected_rrs)) {
          tmp <- selected_rrs[i]
          genesets <- c(genesets, list(u_rrdfs[[tmp]]))
        }
        names(genesets) <- selected_rrs
        gs_names <- names(genesets)
        
        if (length(selected_rrs) != 1){
          merged_gs <- merge_genesets(genesets)
        } else {
          merged_gs <- genesets[[1]]
        }
        incProgress(0.2, message=NULL, "Done merging")
        cluster_intermediate_tmp <- tryCatch(
          RichStudio::RichCluster(input$similarity_metric, input$similarity_cutoff,
                                  input$membership_strategy, input$membership_cutoff,
                                  merged_gs$Term, merged_gs$GeneID, merged_gs$Padj),
          error = function(e) {
            showNotification(e$message)
            return(NULL)
          }
        )
        if(!is.null(cluster_intermediate_tmp)) {
          incProgress(0.5, message=NULL, "Done clustering")
          showNotification("Yay it worked")
          for (name in names(cluster_intermediate_tmp)) {
            clus_intermed[[name]] <- cluster_intermediate_tmp[[name]]
            print(paste("adding", name, "to clus_intermed"))
          }
        }
      })
    })

    distanceMatrix_toTable <- reactive({
      clus_intermed[['DistanceMatrix']]
    })
    output$distanceMatrix_table = DT::renderDT(
      distanceMatrix_toTable()
    )

    clusterMap_toTable <- reactive({
      clus_intermed[['SeedMap']]
    })
    output$clusterMap_table = DT::renderDT(
      clusterMap_toTable()
    )

    InitialSeeds_toTable <- reactive({
      clus_intermed[['FilteredSeeds']]
    })
    output$InitialSeeds_table = DT::renderDT(
      InitialSeeds_toTable()
    )

    MergeSeeds_toTable <- reactive({
      clus_intermed[['MergedSeeds']]
    })
    output$MergeSeeds_table = DT::renderDT(
      MergeSeeds_toTable()
    )

  })
}
