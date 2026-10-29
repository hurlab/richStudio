# Synthetic saved-session regression, not a biological or clustering fixture.
summary <- data.frame(
  Cluster = c(10L, 30L), Representative_Term = rep("Same representative", 2),
  Pvalue_alpha = c(NA_real_, .001), Padj_alpha = c(NA_real_, .01),
  Pvalue_beta = c(1, 0), Padj_beta = c(1, 0)
)
detail <- data.frame(
  Cluster = c(10L, 10L, 30L, 30L),
  Term = c("Ten first", "Ten second", "Thirty first", "Thirty second"),
  Representative_Term = rep("Same representative", 4),
  GeneID = c("g1,g2", "g1,g3", "g4,g5", "g4,g6"),
  Annot = c("GO:SYNTH10A", "GO:SYNTH10B", "GO:SYNTH30A", "GO:SYNTH30B"),
  Pvalue_alpha = c(NA_real_, NA_real_, .001, .001),
  Padj_alpha = c(NA_real_, NA_real_, .01, .01),
  Pvalue_beta = c(1, 1, 0, 0), Padj_beta = c(1, 1, 0, 0)
)
session <- list(
  version = "1.0", created = as.POSIXct("2026-10-29 00:00:00", tz = "UTC"),
  degnames = character(), degdfs = list(), rrnames = character(), rrdfs = list(),
  clusnames = "Scientific_fixture", clusdfs = list(Scientific_fixture = summary),
  cluslists = list(Scientific_fixture = detail),
  big_rrdf = list(df = data.frame(name = character(), from_deg = character(),
                                 annot = character(), keytype = character(),
                                 ontology = character(), species = character())),
  big_clusdf = list(df = data.frame(name = "Scientific_fixture", method = "hierarchical",
                                   n_clusters = 2L, n_terms = 4L))
)
target <- "tests/fixtures/workspace/scientific-cluster-session-v1.rds"
saveRDS(session, target, version = 2)
stopifnot(identical(session, readRDS(target)))
cat("Synthetic scientific-session fixture read-back PASS\n")

# Separate boundary: known enrichment rows with no adjusted probabilities.
for (field in c("clusdfs", "cluslists")) {
  columns <- grep("^Padj_", names(session[[field]]$Scientific_fixture), value=TRUE)
  session[[field]]$Scientific_fixture[columns] <- NA_real_
}
target <- "tests/fixtures/workspace/scientific-all-missing-session-v1.rds"
saveRDS(session, target, version=2)
stopifnot(identical(session, readRDS(target)))
cat("All-missing session fixture read-back PASS\n")
