#ifndef STRING_UTILS_H
#define STRING_UTILS_H

#include <string>
#include <sstream>
#include <vector>
#include <unordered_set>

class StringUtils {
public:
  // Methods for splitting strings to vectors and unordered_sets (specifying delimiter)
  static std::vector<std::string> splitStringToVector(const std::string& input, const std::string& delimiter);
  static std::unordered_set<std::string> splitStringToUnorderedSet(const std::string& input, const std::string& delimiter);

  // (Slow) Overloaded methods for splitting strings using regex (no delimiter specified)
  static std::vector<std::string> splitStringToVector(const std::string& input);
  static std::unordered_set<std::string> splitStringToUnorderedSet(const std::string& input);

  // Convering vectors and sets to strings
  static std::string vectorToString(const std::vector<std::string>& vector, const std::string& delimiter);
  // Template method for converting any std::unordered_set<T> to string
  template <typename T>
  static std::string unorderedSetToString(const std::unordered_set<T>& set, const std::string& delimiter);

  // Used for counting total # geneIDs
  static int countUniqueElements(const std::vector<std::string>& stringifiedVector);

};

#endif
