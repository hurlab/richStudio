#include "DistanceMetric.h"

double DistanceMetric::calculateDistance(const std::unordered_set<std::string>& t1_genes, const std::unordered_set<std::string>& t2_genes, double totalGeneCount) {
  if (_distanceMetric == "kappa") {
    return getKappa(t1_genes, t2_genes, totalGeneCount);
  } else {
    throw std::invalid_argument("Unsupported distance metric: " + _distanceMetric);
  }
}

//' Function to calculate kappa score between two terms
 //' @param t1_genes, vector containing term1's geneIDs
 //' @param t2_genes, vector containing term2's geneIDs
 //' @param totalGeneCount, double representing count of all unique genes in dataset of interest
 //' @return kappaScore, double
 //' @name kappa
 double DistanceMetric::getKappa(const std::unordered_set<std::string>& t1_genes, const std::unordered_set<std::string>& t2_genes, double totalGeneCount) {

   // Calculate the intersection of t1_genes and t2_genes
   std::unordered_set<std::string> intersection;
   std::set_intersection(t1_genes.begin(), t1_genes.end(), t2_genes.begin(), t2_genes.end(), std::inserter(intersection, intersection.begin()));

   double common = static_cast<double>(intersection.size()); // Number of common genes

   if (common == 0) {
     return 0.0; // return 0 if no overlapping genes
   }

   double t1_only = t1_genes.size() - common; // Genes unique to t1_genes
   double t2_only = t2_genes.size() - common; // Genes unique to t2_genes

   double unique = totalGeneCount - common - t1_only - t2_only; // Count of all genes not found in either term

   double relative_observed_agree = (common + unique) / totalGeneCount;
   double chance_yes = ((common + t1_only) / totalGeneCount) * ((common + t2_only) / totalGeneCount);
   double chance_no = ((unique + t1_only) / totalGeneCount) * ((unique + t2_only) / totalGeneCount);
   double chance_agree = chance_yes + chance_no;

   if (chance_agree == 1) {
     return 0.0; // Prevent divide by zero
   } else {
     return (relative_observed_agree - chance_agree) / (1 - chance_agree); // Return kappa!
   }
 }
