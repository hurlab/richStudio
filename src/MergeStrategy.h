#ifndef MERGESTRATEGY_H
#define MERGESTRATEGY_H

#include "DistanceMetric.h"
#include <Rcpp.h>
#include <unordered_set>
#include <string>
#include <functional>


// Customizable control center for merging clusterGroups and computing membership
class MergeStrategy {
public:
  MergeStrategy(std::string mergeStrategy, double mergeCutoff,
                std::string membershipStrategy, double membershipCutoff)
    : _mergeStrategy(mergeStrategy), _mergeCutoff(mergeCutoff),
      _membershipStrategy(membershipStrategy), _membershipCutoff(membershipCutoff) {};
  
  double calculateMembership(
      const std::unordered_set<int>& clusterGroup, 
      std::function<double(int, int)> distanceFunction
  );
  
  // For getting/setting the current merge & membership strategy/cutoff
  // (not currently used, but just in case)
  std::string getMergeStrategy() { return _mergeStrategy; };
  double getMergeCutoff() { return _mergeCutoff; };
  void setMergeCutoff(double mergeCutoff) { _mergeCutoff = mergeCutoff; };

  std::string getMembershipStrategy() { return _membershipStrategy; };
  double getMembershipCutoff() { return _membershipCutoff; };
  void setMembershipCutoff(double membershipCutoff) { _membershipCutoff = membershipCutoff; };
  
  
private:
  std::string _mergeStrategy;
  double _mergeCutoff;
  
  std::string _membershipStrategy;
  double _membershipCutoff;
  
  // Types of supported membership strategies
  // double DAVID_multipleLinkage();
  // double ward(); // my not-so-"original" idea😭
  
  // void updateMembershipFunction();
};

#endif
