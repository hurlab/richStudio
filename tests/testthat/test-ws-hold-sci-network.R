# WS-HOLD-SCI SCI-NETWORK-002: default network gene set.

test_that("default network uses the union of all term genes (SCI-NETWORK-002)", {
  withr::local_seed(42)
  rr <- ws_baseline_results()$untreated
  original <- rr
  p <- richStudio:::rr_network(rr)
  expect_s3_class(p, "ggplot")
  expect_setequal(p$data$label, c("A", "B"))
  expect_gt(length(ggplot2::ggplot_build(p)$data), 0L)
  expect_identical(rr, original)
  withr::local_seed(42)
  explicit <- richStudio:::rr_network(rr, deg = paste0("g", 1:8))
  expect_equal(p$data$label, explicit$data$label)
  expect_equal(p$data$x, explicit$data$x)
  expect_error(richStudio:::rr_network(rr[, setdiff(colnames(rr), "GeneID")]), "GeneID")
})
