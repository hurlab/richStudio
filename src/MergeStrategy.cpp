#include "MergeStrategy.h"

// currently, this computes david multiple linkage membership
// (separate into separate function in future)
double MergeStrategy::calculateMembership(
    const std::unordered_set<int>& clusterGroup, 
    std::function<double(int, int)> distanceFunction
) {
  int totalPairs = 0;
  int significantClosePairs = 0;
  for (auto it1 = clusterGroup.begin(); it1 != clusterGroup.end(); ++it1) 
  {
    for (auto it2 = std::next(it1); it2 != clusterGroup.end(); ++it2) 
    {
      // Dereference term iterators (we passed in reference to clusterGroup)
      int term1 = *it1;
      int term2 = *it2;
      // Get distance (ex: the Kappa score) between them
      double termDistance = distanceFunction(term1, term2);
      totalPairs++;
      if (termDistance >= _membershipCutoff) {
        significantClosePairs++;
      }
    }
  }
  if (totalPairs == 0) {
    // throw error
    return 0;
  }
  double membershipScore = significantClosePairs / totalPairs;
  return membershipScore;
}