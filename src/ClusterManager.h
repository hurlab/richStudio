#ifndef CLUSTERMANAGER_H
#define CLUSTERMANAGER_H

#include <Rcpp.h>
#include <string>
#include "DistanceMetric.h"
#include "DistanceMatrix.h"
#include "SeedMap.h"
#include "MergeStrategy.h"
#include "ClusterList.h"

// ClusterManager: For efficiently clustering a single dataset in multiple ways
class ClusterManager {
public:
  static constexpr double SAME_TERM_DISTANCE = -99;
  
  ClusterManager(Rcpp::CharacterVector termNameColumn,
                 Rcpp::CharacterVector geneIDColumn,
                 Rcpp::NumericVector PvalueColumn);
  
  void calculateDistanceScores(DistanceMetric distanceMetric);
  void filterSeeds(MergeStrategy mergeStrategy);
  void mergeSeeds(MergeStrategy mergeStrategy);
  
  Rcpp::NumericMatrix exportR_DistanceMatrix() {
    return distanceMatrix.export_RMatrix();
  }
  
  Rcpp::DataFrame exportR_SeedMap() {
    return seedMap.export_RDataFrame();
  }
  
  Rcpp::DataFrame exportR_ClusterList() {
    return clusterList.export_RDataFrame();
  }
  
private:
  std::vector<std::string> _termNames;
  std::vector<std::string> _geneIDstrings; // Each string contains all geneIDs for a single term
  std::vector<double> _Pvalues;
  int _nterms;
  DistanceMatrix distanceMatrix;
  SeedMap seedMap;
  ClusterList clusterList;
};

#endif
