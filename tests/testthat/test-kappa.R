test_that("RcppKappaCluster returns expected output", {
  # Read the data files
  gs1 <- read.delim(system.file("extdata", "go1.txt", package = "RichStudio"))
  gs2 <- read.delim(system.file("extdata", "go2.txt", package = "RichStudio"))
  gs3 <- read.delim(system.file("extdata", "kegg1.txt", package = "RichStudio"))

  # Merge the gene sets
  mergelist <- list(gs1, gs2, gs3)
  names(mergelist) <- c("gs1", "gs2", "kegg1")
  merge <- RichStudio::merge_genesets(mergelist)

  # Test the second version of it!
  result <- RichStudio::KappaSimilarityMatrix(merge$Term, merge$GeneID, merge$Padj)

  # View files in window
  View(result[["SigTermIndices"]])
  View(result[["KappaSimilarityMatrix"]])
  View(result[["InitialSeeds"]])
  View(result[["MergeSeeds"]])


  geneIDs <- '139,214,331,623,637,643,658,660,678,687,724,726,732,733,734,740,741,784,828,838,858,908,924,957,959,966,979,980,984,985,1022,1025,1026,1028,1029,1034,1046,1051,1053,1054,1099,1105'
  # Split the string into indices
  indices <- as.integer(strsplit(geneIDs, ",")[[1]])

  # Find corresponding GeneID values
  corresponding_values <- merge$GeneID[indices]
  print(corresponding_values)

  print("1063:", merge[1063,"GeneID"])

  sigTermIndices <- result[["SigTermIndices"]]
  KappaSimilarityMatrix <- result[["KappaSimilarityMatrix"]]
  initialSeeds <- result[["InitialSeeds"]]

  write.csv(KappaSimilarityMatrix, "~/Desktop/KappaSimilarityMatrix.csv")

  library(writexl)
  write_xlsx(sigTermIndices, "~/Desktop/sigTermIndices.xlsx")

  kappa_matrix <- as.dist(kappa_mat)

  kappa_hclust <- hclust(kappa_matrix)
  plot(kappa_hclust, labels=FALSE)

  # Compare to richR
  #richRresult <- richR::richCluster(x=merge, gene=TRUE, cutoff=0.5, overlap=0.5, minSize=2)
  #richr_sigterms <- merge[merge$Annot %in% c("GO:0043624","GO:1902904","GO:0051261","GO:0032984","GO:0043241"),]

  # Check the structure of the result
  expect_is(result, "list")
  expect_named(result, c("SignifKappaTerms", "KappaScores"))
  expect_s3_class(result$SignifKappaTerms, "data.frame")
  expect_s3_class(result$KappaScores, "data.frame")

})
