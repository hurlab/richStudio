#ifndef CLUSTERLIST_H
#define CLUSTERLIST_H

#include "SeedMap.h"
#include "MergeStrategy.h"
#include "DistanceMatrix.h"
#include <list>
#include <unordered_set>

// Class for creating and merging clusters in place
class ClusterList {
public:
  // Constructor initializes and filters at same time
  // Maybe in future, can pass in R dataframe (maybe method of seedMap tho)
  ClusterList(SeedMap& seedMap, DistanceMatrix& DM)
    : _seedMap(seedMap), 
      _distanceMatrix(DM),
      _distanceFunction([&DM](int a, int b) { return DM.getDistance(a, b); }
  ) {};
  
  // Filters 'seeds' (initial cluster groups) in place based on if their members 
  // are above some defined membership cutoff (for a given strategy)
  // (Also used to fill clusterList with values if none exist yet)
  void filterSeeds(MergeStrategy MS);
  
  /*
  Keeps merging clusters in place until no more merges can be made,
  meaning all possible merges will result in 
  MergePartner.mergeScore < membershipCutoff for all possible combinations
   */
  void mergeClusters(MergeStrategy MS);
  
  struct MergePartner {
    int clusterNumber;
    double mergeScore;
  };
  
  MergePartner getBestMergePartner(const MergePartner& partner);
  Rcpp::DataFrame export_RDataFrame(); // R conversion util
  
private:
  std::list<std::unordered_set<int>> clusterList;
  SeedMap& _seedMap;
  DistanceMatrix& _distanceMatrix;
  std::function<double(int, int)> _distanceFunction;
};

#endif