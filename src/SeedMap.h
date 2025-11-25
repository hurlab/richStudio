#ifndef SEEDMAP_H
#define SEEDMAP_H

#include <Rcpp.h>
#include <vector>
#include <string>

class SeedMap {
public:
  SeedMap(
    std::vector<std::string>* termNames,
    const std::vector<std::string>* geneIDs,
    const std::vector<double>* Pvalues
  );
  
  void addTermPair(int term1_index, int term2_index);
  bool term2Exists_in_term1Set(int term1_index, int term2_index);
  
  // Return reference to seedMap (used to initialize ClusterMap)
  const std::unordered_map<int, std::unordered_set<int>>& getSeedMap() const {
    return seedMap;
  }
  
  Rcpp::DataFrame export_RDataFrame(); // R conversion util
  std::vector<std::string>* _termNames;

private:
  // Private member variables
  std::unordered_map<int, std::unordered_set<int>> seedMap;
  const std::vector<std::string>* _geneIDs;
  const std::vector<double>* _Pvalues;
  int _nterms;
  // Private functions
  void addSingleTermPair(int key, int value);
};

#endif
