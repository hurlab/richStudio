#include "ClusterList.h"
#include "MergeStrategy.h"
#include "DistanceMatrix.h"
#include "StringUtils.h"
#include <functional>




// void ClusterMap::mergeSeeds(MembershipStrategy MS, const DistanceMatrix& DM) 
// {
//   auto distanceFunction = [&DM](int a, int b) { return DM.getDistance(a, b); };
//   for (const auto& cluster1 : clusterList) {
//     for (const auto& cluster2 : clusterList) 
//     {
//       std::unordered_set<int> clusterGroup = cluster1;
//       clusterGroup.insert(cluster2.begin(), cluster2.end());
//       
//       double membership = MS.calculateMembership(clusterGroup, distanceFunction);
//       if (membership >= MS.getMembershipCutoff()) {
//         // merge the two clusters
//       }
//     }
//     
//   }
// }

void ClusterList::filterSeeds(MergeStrategy MS) {
  const auto& seedMapInstance = _seedMap.getSeedMap();
  
  for (const auto& termPair : seedMapInstance) {
    std::unordered_set<int> clusterGroup;
    clusterGroup.insert(termPair.first);
    clusterGroup.insert(termPair.second.begin(), termPair.second.end());
    
    double membership = MS.calculateMembership(clusterGroup, _distanceFunction);
    if (membership >= MS.getMembershipCutoff()) {
      clusterList.push_back(clusterGroup);
    }
  }
}

// void ClusterList::mergeClusters(MergeStrategy MS) {
//   bool mergingPossible = true;
//   while (mergingPossible) {
//     int group1Index = 0;
//     for (auto clusterGroup1 : clusterList) 
//     {
//       int n_MergedGroups = 0; // stopping criteria, if 0 after outer loop then exit while loop
//       
//       /* GetBestMergePartner loop*/
//       int partnerIndex = 0;
//       int bestMergePartner = -1; // index of mergePartner
//       double bestMergeMembership = -99; // change to -inf later, (but mergeScore must be between 0-1 anyways)
//       auto bestMergePartnerIt = clusterList.end();
//       for (auto clusterGroup2 : clusterList) 
//       {
//         if (clusterGroup1 == clusterGroup2) { 
//           ++group2Index;
//           continue; // skip
//         }
//         std::unordered_set<int> mergedCluster;
//         mergedCluster.insert(clusterGroup1.begin(), clusterGroup2.end()); 
//         double mergeMembership = MS.calculateMembership(mergedCluster, _distanceFunction);
//         
//         if (mergeMembership >= MS.getMembershipCutoff()) {
//           if (mergeMembership >= bestMergeMembership) 
//           {
//             int bestMergePartner = partnerIndex;
//             int bestMergeMembership = mergeMembership;
//             bestMergePartnerIt = clusterGroup2;
//           }
//         }
//         ++group2Index;
//       }
//       /* End GetBestMergePartner loop*/
//       
//       if (bestMergePartnerIndex != -1 && bestMergeMembership >= MS.getMembershipCutoff()) {
//         std::unordered_set<int> mergedCluster = mergeSets(*clusterGroup1, *bestMergePartnerIt);
//         
//         // Remove clusterGroup1 and clusterGroup2 from clusterList
//         clusterGroup1 = clusterList.erase(clusterGroup1);
//         if (bestMergePartnerIt != clusterList.end()) {
//           clusterList.erase(bestMergePartnerIt);
//         }
//         
//         // Add mergedCluster to clusterList
//         clusterList.push_back(mergedCluster);
//         
//         n_MergedGroups++;
//         mergingPossible = true;
//         break; // Restart the loop after merging
//       }
//       ++group1Index;
//     }
//     if (n_MergedGroups == 0) {
//       return;
//     }
//   }
// }

void ClusterList::mergeClusters(MergeStrategy MS) {
  bool mergingPossible = true;
  while (mergingPossible) {
    mergingPossible = false;
    int n_MergedGroups = 0; // stopping criteria, if 0 after outer loop then exit while loop
    
    auto it1 = clusterList.begin();
    while (it1 != clusterList.end()) {
      auto clusterGroup1 = *it1;
      
      int partnerIndex = 0;
      int bestMergePartnerIndex = -1; // index of mergePartner
      double bestMergeMembership = -99; // change to -inf later, (but mergeScore must be between 0-1 anyways)
      auto bestMergePartnerIt = clusterList.end();
      
      auto it2 = clusterList.begin();
      while (it2 != clusterList.end()) {
        if (it1 == it2) {
          ++it2;
          continue; // skip
        }
        
        auto clusterGroup2 = *it2;
        
        std::unordered_set<int> mergedCluster;
        mergedCluster.insert(clusterGroup1.begin(), clusterGroup1.end());
        mergedCluster.insert(clusterGroup2.begin(), clusterGroup2.end());
        
        double mergeMembership = MS.calculateMembership(mergedCluster, _distanceFunction);
        
        if (mergeMembership >= MS.getMembershipCutoff()) {
          if (mergeMembership >= bestMergeMembership) {
            bestMergePartnerIndex = partnerIndex;
            bestMergeMembership = mergeMembership;
            bestMergePartnerIt = it2;
          }
        }
        ++it2;
        ++partnerIndex;
      }
      
      if (bestMergePartnerIndex != -1 && bestMergeMembership >= MS.getMembershipCutoff()) {
        std::unordered_set<int> mergedCluster;
        mergedCluster.insert(clusterGroup1.begin(), clusterGroup1.end());
        mergedCluster.insert(bestMergePartnerIt->begin(), bestMergePartnerIt->end());
        
        // Remove clusterGroup1 and clusterGroup2 from clusterList
        it1 = clusterList.erase(it1);
        if (bestMergePartnerIt != clusterList.end()) {
          clusterList.erase(bestMergePartnerIt);
        }
        
        // Add mergedCluster to clusterList
        clusterList.push_back(mergedCluster);
        
        n_MergedGroups++;
        mergingPossible = true;
        break; // Restart the loop after merging
      } else {
        ++it1;
      }
    }
    
    if (n_MergedGroups == 0) {
      return;
    }
  }
}

// Export ClusterList as a R dataframe with termNames and index values
Rcpp::DataFrame ClusterList::export_RDataFrame() {
  std::vector<std::string> clusterIndicesColumn;
  std::vector<std::string> clusterColumn;
  
  std::vector<std::string>& termNames = *(_seedMap._termNames); // dereference pointer
  
  // Iterate through ClusterList and convert to vectors
  for (const auto& clusterGroup : clusterList) {
    // Turn the ints into a string
    std::string clusterIndicesString = StringUtils::unorderedSetToString(clusterGroup, ", ");
    clusterIndicesColumn.push_back(clusterIndicesString);
    
    std::vector<std::string> clusterGroupTerms;
    for (const auto& term_index : clusterGroup) {
      std::string term = termNames[term_index];
      clusterGroupTerms.push_back(term);
    }
    // Convert vector/unordered_set to one comma-delimited string
    std::string clusterGroupTerms_string = StringUtils::vectorToString(clusterGroupTerms, ", ");
    clusterColumn.push_back(clusterGroupTerms_string);
  }
  
  // Create and return a DataFrame using Rcpp
  return Rcpp::DataFrame::create(Rcpp::Named("Cluster") = clusterColumn,
                                 Rcpp::Named("ClusterIndices") = clusterIndicesColumn);
}
