# SPEC-WS-013 M0 (AC-027): the goldens in tests/fixtures/ui-baseline/ are reproduced
# from the untouched R/ and inst/ sources. Later milestones (AC-008, AC-013,
# AC-021, AC-025) compare their outputs against these same files. Comparison is
# keyed by term (figures) or by name (downloads), never by position.

ui_baseline_json <- function(x) {
  jsonlite::fromJSON(
    jsonlite::toJSON(x, auto_unbox = TRUE, digits = I(17), na = "null", null = "null"),
    simplifyVector = FALSE
  )
}

ui_baseline_golden <- function(name) {
  jsonlite::fromJSON(ui_baseline_fixture_path(name), simplifyVector = FALSE)
}

ui_baseline_demo_cached <- local({
  cache <- NULL
  function() {
    if (is.null(cache)) cache <<- ui_baseline_demo()
    cache
  }
})

test_that("fixture files exist and the demo clustering is a deterministic non-empty result", {
  for (name in c("figure-values.json", "demo-downloads.json", "input-revision.json",
                 "project-baseline.zip")) {
    expect_true(file.exists(ui_baseline_fixture_path(name)), info = name)
  }
  demo <- ui_baseline_demo_cached()
  expect_identical(names(demo$rr), c("go1", "go2", "kegg1"))
  expect_identical(names(demo$deg), c("deg_mouse1", "deg_mouse2", "deg_mouse3"))
  expect_gt(nrow(demo$cluster$summary_df), 0L)
  again <- richStudio:::workspace_cluster_compute(
    demo$rr[c("go1", "go2")], "richR", ui_baseline_cluster_params, "clus1"
  )
  expect_identical(again$summary_df, demo$cluster$summary_df)
  expect_identical(again$cluster_df, demo$cluster$cluster_df)
})

test_that("built figure objects reproduce the golden values keyed by term", {
  golden <- ui_baseline_golden("figure-values.json")
  current <- ui_baseline_json(ui_baseline_figures(ui_baseline_demo_cached()))
  expect_identical(names(current), names(golden))
  for (section in names(golden)) {
    expect_identical(current[[section]], golden[[section]], info = section)
  }
  # N6 context: every demo result builds a network with at least one node.
  expect_true(all(unlist(current$network_has_nodes)))
  # Keys are terms, not positions: the golden contains no positional index keys.
  bar_keys <- names(golden$bar[["go1:Padj:rich"]]$values)
  expect_true(all(nzchar(bar_keys)) && !any(grepl("^[0-9]+$", bar_keys)))
})

test_that("download handlers write the golden names and full-precision content", {
  golden <- ui_baseline_golden("demo-downloads.json")
  current <- ui_baseline_json(ui_baseline_downloads(ui_baseline_demo_cached()))
  expect_identical(names(current), names(golden))
  expect_identical(current, golden)
  # Original column names and full precision are what the handlers write.
  head_line <- golden[["cluster_upload:rr go1 .csv"]]$head[[1]]
  expect_identical(head_line, "\"Annot\",\"Term\",\"Annotated\",\"Significant\",\"Pvalue\",\"Padj\",\"GeneID\"")
  expect_match(golden[["cluster_upload:rr go1 .csv"]]$head[[2]], "2.27e-08", fixed = TRUE)
})

test_that("input revision and query snapshot equal the golden for fixed inputs", {
  golden <- ui_baseline_golden("input-revision.json")
  current <- ui_baseline_json(ui_baseline_revision(ui_baseline_demo_cached()))
  expect_identical(current, golden)
})

test_that("the project saved at the baseline is reproduced and opens with equal data", {
  demo <- ui_baseline_demo_cached()
  baseline_zip <- ui_baseline_fixture_path("project-baseline.zip")
  fresh <- withr::local_tempfile(fileext = ".zip")
  ui_baseline_project_write(fresh, demo)
  # tables.json and tracking.json are compared as bytes, the manifest after the
  # version-dependent fields (versions, files) are excluded.
  expect_identical(ui_baseline_project_members(fresh), ui_baseline_project_members(baseline_zip))

  opened <- richStudio:::project_import_read(baseline_zip)
  expect_identical(opened$degnames, names(demo$deg))
  expect_identical(opened$rrnames, names(demo$rr))
  for (lab in names(demo$rr)) expect_equal(opened$rrdfs[[lab]], demo$rr[[lab]], ignore_attr = TRUE)
  for (lab in names(demo$deg)) expect_equal(opened$degdfs[[lab]], demo$deg[[lab]], ignore_attr = TRUE)
  expect_equal(opened$clusdfs$clus1, demo$cluster$summary_df, ignore_attr = TRUE)
  expect_equal(opened$cluslists$clus1, demo$cluster$cluster_df, ignore_attr = TRUE)
})
