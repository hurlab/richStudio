#include "SeedMap.h"
#include "StringUtils.h"

SeedMap::SeedMap(
  std::vector<std::string>* termNames,
  const std::vector<std::string>* geneIDs,
  const std::vector<double>* Pvalues
) : _termNames(termNames), 
    _geneIDs(geneIDs), 
    _Pvalues(Pvalues),
    _nterms(termNames ? termNames->size() : 0)
{
  // Make sure none of the pointers are nullptr
  if (!termNames || !geneIDs || !Pvalues) {
    throw std::invalid_argument("SeedMap constructor received null pointer(s).");
  }
}

void SeedMap::addTermPair(int term1_index, int term2_index) {
  // Add the pair both ways to ensure the relationship is bidirectional
  SeedMap::addSingleTermPair(term1_index, term2_index);
  SeedMap::addSingleTermPair(term2_index, term1_index);
};


// Add a pair of terms with significantly high similarity to SeedMap
void SeedMap::addSingleTermPair(int key_termIndex, int value_termIndex) {
  auto it = seedMap.find(key_termIndex);
  if (it != seedMap.end()) { // key term exists
    it->second.insert(value_termIndex);
  } else {
    seedMap[key_termIndex] = {value_termIndex}; // create new set for that key
  }
}

// Returns true if term2 is present in SeedMap[term1]'s unordered_set
bool SeedMap::term2Exists_in_term1Set(int term1_index, int term2_index) {
  auto it = seedMap.find(term1_index);
  if (it != seedMap.end()) { // key term exists
    const auto& term1_set = it->second;
    bool term2_existsInSet = term1_set.find(term2_index) != term1_set.end(); // O(1) complexity!
    return term2_existsInSet;
  }
  return false;
}

Rcpp::DataFrame SeedMap::export_RDataFrame() {

  std::vector<std::string> keyTermsColumn;
  std::vector<int> keyTermIndicesColumn;

  std::vector<std::string> valueTermsColumn;
  std::vector<std::string> valueTermIndicesColumn;

  // For each row in SeedMap
  // Where row = tuple (int, unordered_set<int>)
  for (const auto& termPair : seedMap) {
    // Find the corresponding term name from _termNames vector pointer
    int keyTerm_index = termPair.first;
    std::string keyTerm = (*_termNames)[keyTerm_index]; // Deref. and index

    // Add term name and index to final column vectors
    keyTermsColumn.push_back(keyTerm);
    keyTermIndicesColumn.push_back(keyTerm_index);

    // Repeat for term names from associated values unordered_set
    std::vector<std::string> valueTerms;
    for (const auto& valueTerm_index : termPair.second) {
      std::string valueTerm = (*_termNames)[valueTerm_index]; // deref. and index
      valueTerms.push_back(valueTerm);
    }

    // Convert vector/unordered_set to one comma-delimited string
    std::string valueTerms_string = StringUtils::vectorToString(valueTerms, ", ");
    valueTermsColumn.push_back(valueTerms_string);
    
    std::string valueTermIndices_string = StringUtils::unorderedSetToString(termPair.second, ", ");
    valueTermIndicesColumn.push_back(valueTermIndices_string);
  }

  return Rcpp::DataFrame::create(
    Rcpp::_["Term"] = keyTermsColumn,
    Rcpp::_["SignificantTermPairs"] = valueTermsColumn,
    Rcpp::_["Term_Index"] = keyTermIndicesColumn,
    Rcpp::_["SignificantTermPair_Indices"] = valueTermIndicesColumn
  );
}
