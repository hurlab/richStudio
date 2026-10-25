# WS-HOLD-SCI B3-OBS-002: whole-result deletion.

test_that("whole-result deletion drops exclusive terms and keeps shared ones", {
  rr <- ws_baseline_results()
  control <- richStudio:::add_custom_gs(NULL, rr$untreated, "control", c("A", "B"))
  both <- richStudio:::add_custom_gs(control, rr$treated, "case", c("C", "D"))
  gone <- richStudio:::remove_gs(both, "control", c("A", "B"), delete_all = c("A", "B"))
  expect_identical(gone$Term, c("D", "C"))
  expect_equal(gone$Pvalue_case, c(.2, .03))
  expect_equal(gone$Padj_case, c(.3, NA_real_))
  expect_identical(gone$GeneID_case, c("g5,g6,g8", "g5,g6,g7"))
  expect_false(any(grepl("_control$", colnames(gone))))
  # Overlap variant: C selected in both datasets survives with the case values.
  c1 <- richStudio:::add_custom_gs(NULL, rr$untreated, "control", c("A", "C"))
  c2 <- richStudio:::add_custom_gs(c1, rr$treated, "case", c("C", "D"))
  gone2 <- richStudio:::remove_gs(c2, "control", c("A", "C"), delete_all = c("A", "C"))
  expect_identical(sort(gone2$Term), c("C", "D"))
  expect_equal(gone2$Pvalue_case[gone2$Term == "C"], .03)
  # Deleting the only dataset leaves an empty table.
  only <- richStudio:::remove_gs(control, "control", c("A", "B"), delete_all = c("A", "B"))
  expect_identical(nrow(only), 0L)
})

test_that("delete_rr observer removes the result's rows and resets its term vector", {
  state <- ws_baseline_state()
  raw <- ws_baseline_results()
  state$u_rrnames$labels <- c("control", "case")
  state$u_rrdfs$control <- raw$untreated
  state$u_rrdfs$case <- raw$treated
  args <- state[intersect(names(state), names(formals(richStudio:::rrVisTabServer)))]
  shiny::testServer(richStudio:::rrVisTabServer, args = args, {
    session$flushReact()
    session$setInputs(select_cushmap = "control", cushmap_select_table_rows_selected = 1:2,
      cushmap_valtype = "Padj", rr_delete_select = "control", cushmap_add_rr = 1L)
    session$setInputs(select_cushmap = "case", cushmap_select_table_rows_selected = 2:3,
                      cushmap_add_rr = 2L)
    session$setInputs(delete_rr = 1L)
    actual <- custom_data_reactive$df[, c("Term", "GeneID_case", "Pvalue_case", "Padj_case")]
    rownames(actual) <- NULL
    expected <- data.frame(Term = c("D", "C"), GeneID_case = c("g5,g6,g8", "g5,g6,g7"),
                           Pvalue_case = c(.2, .03), Padj_case = c(.3, NA_real_))
    expect_identical(actual, expected)
    expect_false(any(grepl("_control$", colnames(custom_data_reactive$df))))
    expect_identical(rr_term_vec_reactive[["control"]], character())
  })
})
