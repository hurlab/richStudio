# Historical R examples

These inactive examples were retained during the LSP cleanup. They are reference
material, not executable application code. Existing runtime behavior is unchanged.

## cluster_upload_tab.R, reference 61

Original source comments:

```r
        # tabBox(title="Cluster", width = NULL,
        #   tabPanel("Kappa clustering",
        #     br(),
        #     selectInput(ns('selected_rrs'), "Select enrichment results to cluster", choices=NULL, multiple=TRUE),
        #     textInput(ns('cluster_name'), "Name", value="Test group"),
        #     selectInput(ns('cluster_by'), "Cluster by", c("Mean Pvalue", "Median Pvalue", "Min Pvalue", "Mean Padj", "Median Padj", "Min Padj")),
        #     numericInput(ns('cutoff'), "Cutoff", value=.5, min=0, max=1),
        #     numericInput(ns('overlap'), "Overlap", value=.5, min=0, max=1),
        #     numericInput(ns('min_size'), "Min size", value=2, min=0),
        #     actionButton(ns('cluster'), "Cluster")
        #   )
        # )
```

## deg_enrich.R, reference 160

Original source comments:

```r
# deg2_test <- shiny_enrich(deg2, 'geneID', 'mouse',  "GO", "SYMBOL", "BP")
# no need to support david/msigdb at moment
```

## deg_enrich.R, reference 5

Original source comments:

```r
## build Annotation package
# fromKEGG(species="hsa")  # from KEGG
# fromAnnHub(species="human")  # from AnnotationHub
```

## deg_enrich.R, reference 3

Original source comments:

```r
# deg2 <- read.delim('/Users/sarahhong/Desktop/Hur Lab/enrichment-analysis/data/degs/HF_12wk_SCN_vs_WT_12wk_SCN_DE_12_19.txt')
```

## enrich_tab.R, reference 620

Original source comments:

```r
    # deg_to_table <- reactive(NULL)
    # Output individual deg preview table
```

## enrich_tab.R, reference 617

Original source comments:

```r
      # df <- round_tbl(df, 3)
```

## file_handling.R, reference 279

Original source comments:

```r
  # df <- df[df %!in% rm_vec]
```

## file_handling.R, reference 205

Original source comments:

```r
  # df <- df[df %!in% rm_vec]
```

## file_handling.R, reference 98

Original source comments:

```r
  # df <- df[df %!in% rm_vec]
```

## round_table.R, reference 10

Original source comments:

```r
    # return(as.numeric(sprintf(paste0("%.", n, "f"), as.numeric(x))))
```

## round_table.R, reference 8

Original source comments:

```r
    # return(format(signif(x, digits=n), scientific=FALSE))
```

## round_table.R, reference 5

Original source comments:

```r
    # return(format(x, scientific=TRUE, digits=n))
```

## rr_hmap.R, reference 147

Original source comments:

```r
  # else { # Set gs to NULL vector
  #   gs <- setNames(replicate(ncol(gs), NULL), colnames(gs))
  #   gs <- data.frame(gs)
  # }
```

## rr_hmap.R, reference 132

Original source comments:

```r
  # Fix top_nterms later...
  # if (top_nterms == 0) {
  #   same_gs_cols <- grepl(gs_name, colnames(custom_data))
  #   if (!is.null(same_gs_cols)) { # Gs already in custom_data
  #     null_vec <- replicate(length(same_gs_cols), NULL) # Number of NULL = ncol
  #     null_vec <- setNames(null_vec, colnames(custom_data))
  #   }
  # }
```

## rr_network.R, reference 141

Original source comments:

```r
# net1 <- ggnetwork(deg1_enriched, weightcut=.2)
# net2 <- ggnetwork(deg1_enriched, weightcut=.5)
```
