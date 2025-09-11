#ifndef MAIN_SERIAL_H
#define MAIN_SERIAL_H

#include <iostream>
#include <iomanip>
#include <vector>
#include <fstream>
#include <cstring>
#include <climits>
#include <algorithm>
#include <chrono>

// Keep original INF value for output compatibility
#define INF 1073741823  // 2^30 - 1

// Helper functions
void initialize_distance_matrix(int* dist, int V);
void add_edge(int* dist, int V, int src, int dst, int weight);

// Serial algorithm functions
void solve_apsp_serial(int* dist, int V);

#endif
