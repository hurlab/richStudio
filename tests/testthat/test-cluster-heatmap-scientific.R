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

test_that("individual hover explains raw probabilities and the zero display floor", {
  x <- scientific_heatmap_fixture()
  original <- x
  plot <- richStudio:::cluster_hmap(x$details, "Shared", x$summary)
  traces <- Filter(function(trace) identical(trace$type, "heatmap") &&
                     "case" %in% colnames(trace$z), plotly::plotly_build(plot)$x$data)
  main <- traces[[1]]
  hover <- as.character(main$text)
  expect_true(any(grepl("Padj: 0 (display floor)", hover, fixed=TRUE)))
  expect_true(any(grepl("Padj: 0.01", hover, fixed=TRUE)))
  expect_true(any(grepl("Padj: Not available", hover, fixed=TRUE)))
  expect_true(all(grepl("Term: Cluster", hover, fixed=TRUE)))
  expect_true(all(grepl("Analysis: case", hover, fixed=TRUE)))
  expect_true(all(grepl("-log10(Padj):", hover, fixed=TRUE)))
  expect_equal(sum(is.na(main$z)), 1L)
  expect_true(any(as.numeric(main$z) > 300, na.rm=TRUE))
  expect_identical(x, original)
})


test_that("all-missing individual heatmaps retain NA cells without palette errors", {
  for (n in c(1L, 3L)) {
    summary <- data.frame(Cluster=1L, Representative_Term="A", Padj_case=NA_real_)
    details <- data.frame(Cluster=rep(1L, n), Term=LETTERS[seq_len(n)],
                          Padj_case=NA_real_, Padj_control=NA_real_)
    original <- details
    if (n == 1L) details$Padj_control <- NULL
    built <- NULL
    expect_warning(built <- plotly::plotly_build(
      richStudio:::cluster_hmap(details, "cluster:1", summary)), NA)
    main <- Filter(function(trace) identical(trace$type, "heatmap"), built$x$data)[[1]]
    expect_true(all(is.na(main$z)))
    expect_equal(length(main$z), n * if (n == 1L) 1L else 2L)
    expect_true(all(grepl("Not available", as.character(main$text), fixed=TRUE)))
    expect_identical(built$x$layout$plot_bgcolor, "#eeeeee")
    expect_identical(details$Padj_case, original$Padj_case)
  }
})


test_that("all-missing summary heatmaps retain distinct cluster coordinates", {
  x <- scientific_heatmap_fixture()
  x$details$Padj_case <- NA_real_
  original <- x
  built <- NULL
  expect_warning(built <- plotly::plotly_build(
    richStudio:::comprehensive_hmap(x$summary, x$details)), NA)
  main <- built$x$data[[1]]
  expect_true(all(is.na(main$z)))
  expect_length(main$z, 4L)
  expect_equal(anyDuplicated(paste(main$x, main$y)), 0L)
  expect_true(all(grepl("Not available", main$text, fixed=TRUE)))
  expect_identical(x, original)
})

test_that("changing cluster results does not reset the result selectors", {
  state <- ws_baseline_state()
  state$u_clusnames$labels <- c("hierarchical", "DAVID")
  state$u_clusdfs$hierarchical <- data.frame(Cluster=1L, Representative_Term="first", Padj_case=.01)
  state$u_cluslists$hierarchical <- data.frame(Cluster=1L, Term="first", Padj_case=.01)
  state$u_clusdfs$DAVID <- data.frame(Cluster=30L, Representative_Term="second", Padj_case=.001)
  state$u_cluslists$DAVID <- data.frame(Cluster=30L, Term="second", Padj_case=.001)
  args <- state[intersect(names(state), names(formals(richStudio:::clusVisTabServer)))]
  mock <- shiny::MockShinySession$new()
  messages <- list()
  mock$sendInputMessage <- function(inputId, message) {
    messages[[length(messages) + 1L]] <<- list(id=inputId, message=message)
  }
  shiny::testServer(richStudio:::clusVisTabServer, args=args, session=mock, {
    session$setInputs(clusdf_select="hierarchical", big_value_type="Padj", value_by="mean",
                      small_value_type="Padj")
    session$flushReact()
    messages <<- list()
    session$setInputs(clusdf_select="DAVID")
    session$flushReact()
    ids <- vapply(messages, `[[`, character(1), "id")
    expect_false(any(grepl("clusdf_select$", ids)))
    expect_false(any(grepl("cluslist_select$", ids)))
    expect_true(any(grepl("indiv_clus_select$", ids)))
    expect_identical(unname(term_vec_reactive()), "cluster:30")
    trace <- plotly::plotly_build(summary_heatmap())$x$data[[1]]
    expect_identical(as.character(trace$y), "cluster:30")
    expect_identical(as.numeric(trace$z), 3)
  })
})
