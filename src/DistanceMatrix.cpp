#include "DistanceMatrix.h"
#include <Rcpp.h>

// DistanceMatrix constructor: Initializes an indexable, flattened list of distances
// Note: Distances are defined as similarity scores between two terms
//
// @param n: int, the size of the DistanceMatrix (number of terms)
DistanceMatrix::DistanceMatrix(int nterms, std::vector<std::string>& termNames)
  : _nterms(nterms), _termNames(termNames) {
  distanceVector.resize(nterms * nterms); // Initialize vector size as nterms^2
}


// Converts two termVec indices into a single index into DistanceMatrix vector
int DistanceMatrix::getDistanceIndex(int term1_index, int term2_index) const {
  int row_index = term1_index;
  int col_index = term2_index;
  return (row_index * _nterms) + col_index;
}


// getDistance: Get distance between terms with indices (i, j) from the DistanceMap
double DistanceMatrix::getDistance(int term1_index, int term2_index) const {
  int distanceIndex = DistanceMatrix::getDistanceIndex(term1_index, term2_index);
  return distanceVector[distanceIndex];
}


// setDistance: Set the distance (similarity score) between each term pair
void DistanceMatrix::setDistance(double distance, int term1_index, int term2_index) {
  int distanceIndex = DistanceMatrix::getDistanceIndex(term1_index, term2_index);
  distanceVector[distanceIndex] = distance;

  // Ensures that in getDistance(t1, t2), order of t1 or t2 doesn't matter
  int distanceIndex2 = DistanceMatrix::getDistanceIndex(term2_index, term1_index);
  distanceVector[distanceIndex2] = distance;
}


//' Convert distanceVector to 2-dimensional NumericMatrix with dimnames
 //'
 //' @param termNames CharacterVector, R vector with names of all terms in dataset
 //' @return distanceRMatrix NumericMatrix, the distance matrix as an R matrix with dimnames
 Rcpp::NumericMatrix DistanceMatrix::export_RMatrix() const {
   
   Rcpp::NumericMatrix distanceRMatrix(_nterms, _nterms);
   
   for (int i = 0; i < _nterms; ++i) {
     for (int j = 0; j < _nterms; ++j) {
       distanceRMatrix(i, j) = getDistance(i, j);
     }
   }
   
   // Set dimnames for the matrix
   Rcpp::List dimnames = Rcpp::List::create(_termNames, _termNames);
   distanceRMatrix.attr("dimnames") = dimnames;
   
   return distanceRMatrix;
 }
