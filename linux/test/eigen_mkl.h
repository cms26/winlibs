#pragma once
#include <string>

// Eigen with MKL, built like an application library (see CMakeLists.txt):
// true if MKL computed correct results; info describes MKL and the checks.
bool eigenMklCheck(std::string &info);
