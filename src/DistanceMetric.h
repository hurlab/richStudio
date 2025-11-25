#ifndef DISTANCEMETRIC_H
#define DISTANCEMETRIC_H

#include <Rcpp.h>
#include <utility>
#include <unordered_set>
#include <string>
#include <stdexcept>


class DistanceMetric {
public:
  DistanceMetric(std::string distanceMetric, double distanceCutoff)
    : _distanceMetric(distanceMetric), _distanceCutoff(distanceCutoff) {};
  double calculateDistance(
      const std::unordered_set<std::string>& t1_genes,
      const std::unordered_set<std::string>& t2_genes,
      double totalGeneCount
  );

  // For getting/setting the current distance method/cutoff
  std::string getDistanceMethod() { return _distanceMetric; };
  double getDistanceCutoff() { return _distanceCutoff; };
  void setDistanceMetric(std::string distanceMetric)
  {
    _distanceMetric = distanceMetric;
  };
  void setDistanceCutoff(double distanceCutoff) { _distanceCutoff = distanceCutoff; };

private:
  std::string _distanceMetric;
  double _distanceCutoff;

  // Types of supported distance metrics
  double getKappa(const std::unordered_set<std::string>& t1_genes, const std::unordered_set<std::string>& t2_genes, double totalGeneCount);
  // double getJaccard();
  // double getCosineSimilarity();

  void updateDistanceFunction();
};

#endif
