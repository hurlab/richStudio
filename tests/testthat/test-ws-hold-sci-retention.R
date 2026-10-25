# WS-HOLD-SCI SCI-RETENTION-001: dataset-label retention in merged tables.

test_that("overlapping dataset labels keep each other's columns (SCI-RETENTION-001)", {
  rr <- ws_baseline_results()
  top <- richStudio:::add_topterm_gs(data.frame(), rr$untreated,
                                    "untreated", "Pvalue", .05, 3)
  expect_identical(top$Term, c("A", "B", "C"))
  expect_equal(top$Pvalue_untreated, c(1e-8, 1e-7, 1e-6))
  top <- richStudio:::add_topterm_gs(top, rr$treated, "treated", "Pvalue", .05, 3)
  expect_identical(top$Term, c("A", "B", "C"))
  expect_equal(top$Pvalue_treated, c(.02, NA, .03))
  expect_equal(top$Pvalue_untreated, c(1e-8, 1e-7, 1e-6))
  top <- richStudio:::add_topterm_gs(top, rr$untreated, "untreated", "Padj", .05, 3)
  expect_identical(top$Term, c("A", "D", "C"))
  expect_equal(top$Padj_untreated, c(NA, 1e-5, NA))
  expect_equal(top$Pvalue_treated, c(.02, NA, .03))
})

test_that("custom add and whole-result removal match dataset columns exactly", {
  rr <- ws_baseline_results()
  # "case" is a prefix of "case2"; an unanchored pattern treats them as one dataset.
  joined <- richStudio:::add_custom_gs(NULL, rr$untreated, "case2", c("A", "B", "C", "D"))
  joined <- richStudio:::add_custom_gs(joined, rr$treated, "case", c("A", "C", "D"))
  expect_identical(joined$Term, c("A", "B", "D", "C"))
  expect_equal(joined$Pvalue_case, c(.02, NA, .2, .03))
  expect_equal(joined$Pvalue_case2, c(1e-8, 1e-7, .05, 1e-6))
  removed <- richStudio:::remove_gs(joined, "case", c("A", "C", "D"),
                                    delete_all = c("A", "C", "D"))
  expect_true(all(c("Pvalue_case2", "Padj_case2", "GeneID_case2") %in% colnames(removed)))
  expect_false(any(colnames(removed) %in% c("Pvalue_case", "Padj_case", "GeneID_case")))
  expect_identical(removed$Term, c("A", "B", "D", "C"))
})

test_that("dataset labels containing regex metacharacters are matched literally", {
  rr <- ws_baseline_results()
  top <- richStudio:::add_topterm_gs(data.frame(), rr$untreated,
                                    "ctl.(1)", "Pvalue", .05, 3)
  top <- richStudio:::add_topterm_gs(top, rr$treated, "ctlX1", "Pvalue", .05, 3)
  expect_equal(top$`Pvalue_ctl.(1)`, c(1e-8, 1e-7, 1e-6))
  expect_equal(top$Pvalue_ctlX1, c(.02, NA, .03))
  top <- richStudio:::add_topterm_gs(top, rr$untreated, "ctl.(1)", "Padj", .05, 3)
  expect_equal(top$Pvalue_ctlX1, c(.02, NA, .03))
  expect_identical(top$Term, c("A", "D", "C"))
  joined <- richStudio:::add_custom_gs(NULL, rr$untreated, "ctlX1", c("A", "B"))
  joined <- richStudio:::add_custom_gs(joined, rr$treated, "ctl.(1)", c("A", "C"))
  expect_true(all(c("Pvalue_ctlX1", "Pvalue_ctl.(1)") %in% colnames(joined)))
  gone <- richStudio:::remove_gs(joined, "ctl.(1)", c("A", "C"), delete_all = c("A", "C"))
  expect_true("Pvalue_ctlX1" %in% colnames(gone))
  expect_false("Pvalue_ctl.(1)" %in% colnames(gone))
})
