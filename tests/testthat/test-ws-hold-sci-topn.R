# WS-HOLD-SCI: top-N means the N most significant terms by the chosen statistic.

sci_unsorted <- function() {
  data.frame(
    Term = c("T1", "T2", "T3", "T4", "T5"),
    Annot = paste0("Annot", 1:5),
    GeneID = c("g1,g2", "g2,g3", "g3,g4", "g4,g5", "g5,g6"),
    Pvalue = c(0.04, 0.03, 0.0001, 0.02, 0.001),
    Padj = c(0.04, 0.03, 0.0001, 0.02, 0.001),
    Significant = 2L, Annotated = 10L,
    stringsAsFactors = FALSE
  )
}

test_that("top-N keeps the N most significant terms, not the first N rows", {
  x <- sci_unsorted()
  top <- richStudio:::add_topterm_gs(data.frame(), x, "g", "Pvalue", .05, 2)
  expect_setequal(top$Term, c("T3", "T5"))
  by_adj <- richStudio:::add_topterm_gs(data.frame(), x, "g", "Padj", .05, 3)
  expect_setequal(by_adj$Term, c("T3", "T5", "T4"))
  bar <- plotly::plotly_data(richStudio:::rr_bar(x, top = 2, pvalue = .05, value_type = "Pvalue"))
  expect_setequal(as.character(bar$Term), c("T3", "T5"))
  dot <- plotly::plotly_data(richStudio:::rr_dot(x, top = 2, value_cutoff = .05, value_type = "Pvalue"))
  expect_setequal(as.character(dot$Term), c("T3", "T5"))
})
