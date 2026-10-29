scientific_heatmap_fixture <- function() {
  list(
    summary = data.frame(
      Cluster = c(5L, 20L, 30L, 40L), Representative_Term = rep("Shared", 4),
      Padj_case = c(NA_real_, 1, 0, 0.01), Pvalue_case = c(NA_real_, 1, 0, 0.001)
    ),
    details = data.frame(
      Cluster = c(5L, 20L, 30L, 40L), Term = rep("Shared", 4),
      Representative_Term = rep("Shared", 4),
      Padj_case = c(NA_real_, 1, 0, 0.01), Pvalue_case = c(NA_real_, 1, 0, 0.001)
    )
  )
}

test_that("cluster aggregation follows actual IDs and retains all-missing values", {
  x <- scientific_heatmap_fixture()
  x$details <- rbind(x$details, transform(x$details[x$details$Cluster == 40, ],
                                        Padj_case = 0.09, Pvalue_case = 0.009))
  original <- x
  expected <- c(mean = 0.05, median = 0.05, min = 0.01, max = 0.09)
  for (method in names(expected)) {
    result <- richStudio:::change_finaldata_valueby(x$summary, x$details, method)
    expect_identical(result$Cluster, x$summary$Cluster)
    expect_true(is.na(result$Padj_case[result$Cluster == 5]))
    expect_equal(result$Padj_case[result$Cluster == 40], unname(expected[[method]]))
  }
  expect_error(richStudio:::change_finaldata_valueby(x$summary, x$details, "sum"),
               "Invalid value_by")
  expect_identical(x, original)
})

test_that("summary coordinates identify clusters and distinguish missing zero and one", {
  x <- scientific_heatmap_fixture()
  x$summary$Cluster <- seq_len(nrow(x$summary))
  x$details$Cluster <- seq_len(nrow(x$details))
  original <- x
  plot <- richStudio:::comprehensive_hmap(x$summary, x$details)
  data <- plotly::plotly_data(plot)
  trace <- plotly::plotly_build(plot)$x$data[[1]]
  expect_identical(as.character(trace$y), c("cluster:1", "cluster:2", "cluster:3", "cluster:4"))
  expect_equal(anyDuplicated(paste(trace$x, trace$y)), 0L)
  expect_true(is.na(data$value[data$Cluster == 1]))
  expect_equal(data$value[data$Cluster == 2], 0)
  expect_true(is.finite(data$value[data$Cluster == 3]))
  expect_gt(data$value[data$Cluster == 3], 300)
  expect_equal(data$value[data$Cluster == 4], 2)
  expect_true(any(grepl("Not available", trace$text, fixed = TRUE)))
  expect_true(any(grepl("display floor", trace$text, fixed = TRUE)))
  expect_identical(x, original)
})

test_that("invalid probabilities are missing rather than averaged into valid values", {
  summary <- data.frame(Cluster = 1L, Representative_Term = "A", Padj_case = 0.01)
  details <- data.frame(Cluster = rep(1L, 4), Term = LETTERS[1:4],
                        Padj_case = c(-0.1, Inf, 2, 0.01))
  expect_warning(result <- richStudio:::change_finaldata_valueby(summary, details),
                 "outside.*\\[0, 1\\]")
  expect_equal(result$Padj_case, 0.01)
  expect_error(richStudio:::comprehensive_hmap(summary, details, "FDR"), "Invalid value_type")
})

test_that("individual ID selection is unambiguous while legacy names remain usable", {
  x <- scientific_heatmap_fixture()
  selected <- richStudio:::cluster_hmap(x$details, "cluster:20", x$summary)
  traces <- Filter(function(trace) identical(trace$type, "heatmap") &&
                     "case" %in% colnames(trace$z), plotly::plotly_build(selected)$x$data)
  expect_length(traces, 1L)
  expect_equal(as.numeric(traces[[1]]$z), 0)
  expect_equal(nrow(traces[[1]]$z), 1L)
  legacy <- richStudio:::cluster_hmap(x$details, "Shared", x$summary)
  traces <- Filter(function(trace) identical(trace$type, "heatmap") &&
                     "case" %in% colnames(trace$z), plotly::plotly_build(legacy)$x$data)
  main <- traces[[length(traces)]]
  expect_equal(nrow(main$z), 4L)
  expect_equal(anyDuplicated(rownames(main$z)), 0L)
  expect_equal(sum(is.na(main$z)), 1L)
  expect_error(richStudio:::cluster_hmap(x$details, "cluster:99", x$summary), "No matching clusters")
})

test_that("cluster UI choices use stable IDs despite repeated representative names", {
  state <- ws_baseline_state()
  x <- scientific_heatmap_fixture()
  state$u_clusnames$labels <- "duplicates"
  state$u_clusdfs$duplicates <- x$summary
  state$u_cluslists$duplicates <- x$details
  args <- state[intersect(names(state), names(formals(richStudio:::clusVisTabServer)))]
  shiny::testServer(richStudio:::clusVisTabServer, args = args, {
    session$setInputs(clusdf_select = "duplicates", big_value_type = "Padj", value_by = "mean",
                      small_value_type = "Padj")
    session$flushReact()
    expect_identical(unname(term_vec_reactive()), c("cluster:5", "cluster:20", "cluster:30", "cluster:40"))
    expect_identical(names(term_vec_reactive()), c("Cluster 5 | Shared", "Cluster 20 | Shared",
                                                  "Cluster 30 | Shared", "Cluster 40 | Shared"))
    session$setInputs(indiv_clus_select = "cluster:20")
    expect_s3_class(plot_cluslist_hmap(), "plotly")
  })
})
