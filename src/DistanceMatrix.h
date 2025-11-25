#ifndef DISTANCEMATRIX_H
#define DISTANCEMATRIX_H

#include <Rcpp.h>
#include <vector>


class DistanceMatrix {
public:
  DistanceMatrix(int nterms, std::vector<std::string>& termNames);
  int getDistanceIndex(int term1_index, int term2_index) const;
  double getDistance(int term1_index, int term2_index) const;
  void setDistance(double distance, int term1_index, int term2_index);

  // R conversion utils
  Rcpp::NumericMatrix export_RMatrix() const;
  Rcpp::NumericVector export_RVector() const {
    return Rcpp::wrap(distanceVector);
  }

private:
  std::vector<double> distanceVector; // Internally the DistanceMatrix is stored
                                      // flattened, as a vector
  int _nterms;
  std::vector<std::string> _termNames;
};

#endif
