legibility_fixture <- function(n, long_labels = FALSE) {
  ids <- seq_len(n) * 3L + 2L
  terms <- if (long_labels) {
    rep(
      c(
        paste(rep("공통 경로 α 🧬 é", 12), collapse = " "),
        paste0(
          "Shared <img src=x onerror=\"window.__heatmapInjected=1\"> ",
          paste(rep("long representative term", 8), collapse = " ")
        )
      ),
      length.out = n
    )
  } else {
    rep("Shared representative term", n)
  }
  adjusted <- rep(c(NA_real_, 1, 0, 0.01), length.out = n)
  control <- rep(c(0.5, NA_real_, 0.04, 0), length.out = n)
  summary <- data.frame(
    Cluster = ids,
    Representative_Term = terms,
    Padj_case = adjusted,
    Padj_control = control,
    Pvalue_case = adjusted / 2,
    Pvalue_control = control / 2,
    stringsAsFactors = FALSE
  )
  details <- summary
  details$Term <- terms
  list(summary = summary, details = details)
}

legibility_unescape <- function(x) {
  replacements <- c(
    "&quot;" = "\"", "&#39;" = "'", "&lt;" = "<", "&gt;" = ">",
    "&amp;" = "&"
  )
  for (entity in names(replacements)) {
    x <- gsub(entity, replacements[[entity]], x, fixed = TRUE)
  }
  x
}

test_that("legibility presentation keeps every scientific cell and missing value", {
  limit <- richStudio:::workspace_resource_policy()$limits$render_rows
  for (n in c(1L, 2L, 141L, 366L, 400L, 401L, limit)) {
    fixture <- legibility_fixture(n)
    original <- fixture
    plot <- richStudio:::comprehensive_hmap(
      fixture$summary, fixture$details
    )
    data <- plotly::plotly_data(plot)
    trace <- plotly::plotly_build(plot)$x$data[[1]]
    expect_length(trace$z, n * 2L)
    expect_setequal(
      unique(as.character(trace$y)),
      paste0("cluster:", fixture$summary$Cluster)
    )
    expect_equal(anyDuplicated(paste(trace$x, trace$y)), 0L)
    expect_identical(
      as.character(data$Representative_Term),
      rep(fixture$summary$Representative_Term, each = 2L)
    )
    expected_raw <- as.vector(t(as.matrix(
      fixture$summary[c("Padj_case", "Padj_control")]
    )))
    expect_equal(data$raw_value, expected_raw)
    expected_display <- expected_raw
    expected_display[!is.na(expected_display) & expected_display == 0] <-
      .Machine$double.xmin * .Machine$double.eps
    expected_display <- round(-log10(expected_display), 4)
    expect_equal(as.numeric(trace$z), expected_display)
    expect_identical(fixture, original)
  }
})

test_that("large default views retain data while bounding visible category rows", {
  limit <- richStudio:::workspace_resource_policy()$limits$render_rows
  for (n in c(401L, limit)) {
    fixture <- legibility_fixture(n)
    built <- plotly::plotly_build(richStudio:::comprehensive_hmap(
      fixture$summary, fixture$details
    ))
    expect_length(built$x$data[[1]]$z, n * 2L)
    range <- built$x$layout$yaxis$range
    expect_true(is.numeric(range) && length(range) == 2L)
    if (is.numeric(range) && length(range) == 2L) {
      expect_lte(abs(diff(range)), 400)
      expect_gt(abs(diff(range)), 0)
    }
    expect_identical(
      as.character(built$x$layout$yaxis$categoryarray),
      paste0("cluster:", fixture$summary$Cluster)
    )
  }
})

test_that("compact labels retain IDs and complete original Unicode hover choices", {
  fixture <- legibility_fixture(4L, long_labels = TRUE)
  fixture$summary <- fixture$summary[c(4, 1, 3, 2), ]
  original <- fixture
  plot <- richStudio:::comprehensive_hmap(
    fixture$summary, fixture$details
  )
  built <- plotly::plotly_build(plot)
  labels <- as.character(built$x$layout$yaxis$ticktext)
  ids <- as.character(fixture$summary$Cluster)
  full_labels <- paste0(
    "Cluster ", ids, " | ", fixture$summary$Representative_Term
  )
  expect_length(labels, nrow(fixture$summary))
  expect_true(all(nchar(labels, type = "width") <
    nchar(full_labels, type = "width")))
  first_numbers <- regmatches(labels, regexpr("[0-9]+", labels))
  expect_identical(first_numbers, ids)
  hover <- legibility_unescape(as.character(built$x$data[[1]]$text))
  for (term in unique(fixture$summary$Representative_Term)) {
    expect_true(any(grepl(term, hover, fixed = TRUE)))
  }
  expect_identical(
    names(richStudio:::hmap_cluster_choices(fixture$summary)),
    full_labels
  )
  expect_identical(fixture, original)
})

test_that("oversized results are rejected before heatmap preparation", {
  policy <- richStudio:::workspace_resource_policy()
  fixture <- legibility_fixture(policy$limits$render_rows + 1L)
  prepared <- FALSE
  testthat::local_mocked_bindings(
    change_finaldata_valueby = function(...) {
      prepared <<- TRUE
      stop("PREPARATION_REACHED", call. = FALSE)
    },
    .package = "richStudio"
  )
  error <- tryCatch({
    richStudio:::comprehensive_hmap(fixture$summary, fixture$details)
    NULL
  }, error = identity)
  expect_s3_class(error, "error")
  if (inherits(error, "error")) {
    expect_match(
      conditionMessage(error), "resource limit exceeded: render_rows",
      fixed = TRUE
    )
  }
  expect_false(prepared)
  expect_identical(richStudio:::workspace_resource_policy(), policy)
})

test_that("oversized ID displays stay distinct without changing actual keys", {
  fixture <- legibility_fixture(2L)
  ids <- paste0(paste(rep("long-cluster-id", 8), collapse = ""), c("A", "B"))
  fixture$summary$Cluster <- ids
  fixture$details$Cluster <- ids
  built <- plotly::plotly_build(richStudio:::comprehensive_hmap(
    fixture$summary, fixture$details
  ))
  expect_setequal(unique(as.character(built$x$data[[1]]$y)), paste0(
    "cluster:", ids
  ))
  labels <- as.character(built$x$layout$yaxis$ticktext)
  expect_length(unique(labels), 2L)
  expect_true(all(nchar(labels, type = "width") < 60L))
  hover <- legibility_unescape(as.character(built$x$data[[1]]$text))
  for (id in ids) expect_true(any(grepl(id, hover, fixed = TRUE)))
  expect_true(all(vapply(ids, function(id) {
    any(grepl(id, names(richStudio:::hmap_cluster_choices(fixture$summary)),
      fixed = TRUE))
  }, logical(1))))
})

test_that("long fitting IDs leave a visible representative term excerpt", {
  fixture <- legibility_fixture(2L)
  ids <- c("1234567890123456789", "1234567890123456780")
  fixture$summary$Cluster <- ids
  fixture$details$Cluster <- ids
  plot <- richStudio:::comprehensive_hmap(fixture$summary, fixture$details)
  built <- plotly::plotly_build(plot)
  labels <- legibility_unescape(as.character(built$x$layout$yaxis$ticktext))
  expect_true(all(grepl("Shared", labels, fixed = TRUE)))
  expect_setequal(unique(as.character(built$x$data[[1]]$y)), paste0(
    "cluster:", ids
  ))
  expect_identical(
    as.character(plotly::plotly_data(plot)$Representative_Term),
    rep(fixture$summary$Representative_Term, each = 2L)
  )
  hover <- legibility_unescape(as.character(built$x$data[[1]]$text))
  for (id in ids) {
    expect_true(any(grepl(id, hover, fixed = TRUE)))
  }
  expect_true(all(grepl(
    "Shared representative term", hover, fixed = TRUE
  )))
})

test_that("a fitting one-column representative term remains visible", {
  for (id in c("123456789012345", "1234567890123456")) {
    fixture <- legibility_fixture(1L)
    fixture$summary$Cluster <- id
    fixture$details$Cluster <- id
    fixture$summary$Representative_Term <- "A"
    fixture$details$Representative_Term <- "A"
    plot <- richStudio:::comprehensive_hmap(fixture$summary, fixture$details)
    built <- plotly::plotly_build(plot)
    label <- legibility_unescape(as.character(built$x$layout$yaxis$ticktext))
    if (nchar(id) == 15L) {
      expect_true(startsWith(label, paste0("Cluster ", id)))
    } else {
      expect_match(label, paste0(
        "^(Cluster ", id, "|Display row 1)([^0-9]|$)"
      ))
    }
    expect_match(label, "(^|[^A-Za-z])A$")
    expect_identical(as.character(plotly::plotly_data(plot)$Representative_Term),
      c("A", "A"))
    expect_identical(as.character(built$x$data[[1]]$y),
      rep(paste0("cluster:", id), 2L))
    hover <- legibility_unescape(as.character(built$x$data[[1]]$text))
    expect_true(all(grepl(id, hover, fixed = TRUE)))
    expect_true(all(grepl("<br>A<br>", hover, fixed = TRUE)))
  }
})

test_that("four-digit row aliases keep eight display columns of CJK terms", {
  fixture <- legibility_fixture(2000L)
  ids <- paste0("long-cluster-identifier-", seq_len(2000L))
  terms <- rep(c(
    paste(rep("경로", 10L), collapse = ""), "A中中中中中"
  ), length.out = 2000L)
  fixture$summary$Cluster <- ids
  fixture$details$Cluster <- ids
  fixture$summary$Representative_Term <- terms
  fixture$details$Representative_Term <- terms
  plot <- richStudio:::comprehensive_hmap(fixture$summary, fixture$details)
  built <- plotly::plotly_build(plot)
  labels <- legibility_unescape(as.character(built$x$layout$yaxis$ticktext))
  for (i in 1:2) {
    boundary <- labels[grepl(paste0(
      "^Display row ", 2001L - i, "([^0-9]|$)"
    ), labels)]
    expect_length(boundary, 1L)
    excerpt <- sub("^Display row [0-9]+[^경A]*", "", boundary)
    excerpt <- sub("…$", "", excerpt)
    expect_gte(nchar(excerpt, type = "width"), 8L)
    expect_true(startsWith(terms[i], excerpt))
  }
  expect_equal(anyDuplicated(labels), 0L)
  expect_setequal(unique(as.character(built$x$data[[1]]$y)), paste0(
    "cluster:", ids
  ))
  data <- plotly::plotly_data(plot)
  expect_identical(
    as.character(data$Representative_Term),
    terms[match(as.character(data$cluster_key), paste0("cluster:", ids))]
  )
  hover <- legibility_unescape(as.character(built$x$data[[1]]$text))
  expect_true(all(vapply(unique(terms), function(term) {
    any(grepl(term, hover, fixed = TRUE))
  }, logical(1))))
  expect_true(any(grepl(ids[1L], hover, fixed = TRUE)))
})

test_that("single-row figures retain a drawable axis band and every trace cell", {
  for (n in c(1L, 401L)) {
    fixture <- legibility_fixture(n)
    plot <- richStudio:::comprehensive_hmap(fixture$summary, fixture$details)
    if (n > 400L) {
      plot <- richStudio:::hmap_row_view(plot, n, 401L)
    }
    built <- plotly::plotly_build(plot)
    layout <- built$x$layout
    drawable <- layout$height - layout$margin$t - layout$margin$b
    # The bundled Plotly renderer suppresses these ticks at 30 through 80px;
    # a measured 90px band keeps the one admitted row visible.
    expect_gte(drawable, 90)
    expect_lt(layout$height, 800)
    expect_length(built$x$data[[1]]$z, n * 2L)
    expect_setequal(unique(as.character(built$x$data[[1]]$y)), paste0(
      "cluster:", fixture$summary$Cluster
    ))
  }
})

test_that("all-missing and zero displays remain honest under layout changes", {
  fixture <- legibility_fixture(141L)
  fixture$summary$Padj_case <- NA_real_
  fixture$summary$Padj_control <- NA_real_
  fixture$details$Padj_case <- NA_real_
  fixture$details$Padj_control <- NA_real_
  built <- plotly::plotly_build(richStudio:::comprehensive_hmap(
    fixture$summary, fixture$details
  ))
  expect_length(built$x$data[[1]]$z, 282L)
  expect_true(all(is.na(built$x$data[[1]]$z)))
  expect_true(all(grepl(
    "Not available", built$x$data[[1]]$text, fixed = TRUE
  )))
  fixture <- legibility_fixture(4L)
  built <- plotly::plotly_build(richStudio:::comprehensive_hmap(
    fixture$summary, fixture$details
  ))
  expect_true(any(grepl(
    "display floor", built$x$data[[1]]$text, fixed = TRUE
  )))
  expect_true(any(as.numeric(built$x$data[[1]]$z) == 0, na.rm = TRUE))
})
