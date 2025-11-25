#include "StringUtils.h"
#include <sstream>
#include <vector>
#include <unordered_set>
#include <string>
#include <regex>

// Split a string into a vector using a string delimiter
std::vector<std::string> StringUtils::splitStringToVector(const std::string& input, const std::string& delimiter) {
  std::vector<std::string> result;
  size_t start = 0, end = 0;
  while ((end = input.find(delimiter, start)) != std::string::npos) {
    result.push_back(input.substr(start, end - start));
    start = end + delimiter.length();
  }
  result.push_back(input.substr(start));  // Add the last token
  return result;
}

// Split a string into an unordered_set using a string delimiter
std::unordered_set<std::string> StringUtils::splitStringToUnorderedSet(const std::string& input, const std::string& delimiter) {
  std::unordered_set<std::string> result;
  size_t start = 0, end = 0;
  while ((end = input.find(delimiter, start)) != std::string::npos) {
    result.insert(input.substr(start, end - start));
    start = end + delimiter.length();
  }
  result.insert(input.substr(start));  // Add the last token
  return result;
}

// Overloaded splitString methods
// Split into alphanumeric values with no delimiter specified
std::vector<std::string> StringUtils::splitStringToVector(const std::string& input) {
  std::vector<std::string> result;
  std::regex word_regex("[\\w-]+");
  auto words_begin = std::sregex_iterator(input.begin(), input.end(), word_regex);
  auto words_end = std::sregex_iterator();

  for (std::sregex_iterator i = words_begin; i != words_end; ++i) {
    result.push_back(i->str());
  }
  return result;
}

std::unordered_set<std::string> StringUtils::splitStringToUnorderedSet(const std::string& input) {
  std::unordered_set<std::string> result;
  std::regex word_regex("[\\w-]+");
  auto words_begin = std::sregex_iterator(input.begin(), input.end(), word_regex);
  auto words_end = std::sregex_iterator();

  for (std::sregex_iterator i = words_begin; i != words_end; ++i) {
    result.insert(i->str());
  }
  return result;
}


// Join a vector of strings into a single string with a string delimiter
std::string StringUtils::vectorToString(const std::vector<std::string>& vector, const std::string& delimiter) {
  std::ostringstream oss;
  if (!vector.empty()) {
    auto it = vector.begin();
    oss << *it;  // Output the first element directly
    ++it;
    for (; it != vector.end(); ++it) {
      oss << delimiter << *it;
    }
  }
  return oss.str();
}

// Template method for std::unordered_set<T>, outputs as string with a string delimiter
// Use cases: int, string
template <typename T>
std::string StringUtils::unorderedSetToString(const std::unordered_set<T>& set, const std::string& delimiter) {
  std::ostringstream oss;
  auto it = set.begin();
  if (it != set.end()) {
    oss << *it;  // Output the first element directly
    ++it;
  }
  for (; it != set.end(); ++it) {
    oss << delimiter << *it;
  }
  return oss.str();
}

// Uses unordered_sets to count the # of unique elements in an vector
// containing stringified, comma-separated element data (used for counting total geneIDs)
//
// Ex: input vector contains ["hi,how,are,you", "hi,hi,today"]
// Output: 5 unique elements
int StringUtils::countUniqueElements(const std::vector<std::string>& stringifiedVector) {
  std::unordered_set<std::string> uniqueElements;

  // For each value in the input vector (analogous to iterating through rows in a column)
  for (const std::string& elementString : stringifiedVector) {
    std::unordered_set<std::string> currentElements = StringUtils::splitStringToUnorderedSet(elementString, ",");

    // For each indiv element in the string (ex: "hi,how,are,you")
    for (const std::string& element : currentElements) {
      uniqueElements.insert(element); // Yay sets!
    }
  }
  return uniqueElements.size(); // Return number of unique elements
}


// Explicit instantiation for commonly used types
template std::string StringUtils::unorderedSetToString<int>(const std::unordered_set<int>&, const std::string&);
template std::string StringUtils::unorderedSetToString<std::string>(const std::unordered_set<std::string>&, const std::string&);
