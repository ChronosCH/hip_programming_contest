#ifndef MAIN_H
#define MAIN_H

#include <iostream>
#include <iomanip>
#include <vector>
#include <hip/hip_runtime.h>
#include <fstream>
#include <cstring>
#include <climits>
#include <algorithm>
#include <chrono>

// Keep original INF value for output compatibility
#define INF 1073741823  // 2^30 - 1

// GPU kernel declarations for optimized blocked Floyd-Warshall
__global__ void fw_phase1(int* __restrict__ dist, int V, int kb);
__global__ void fw_phase1_full(int* __restrict__ dist, int V, int kb);
__global__ void fw_phase2_row(int* __restrict__ dist, int V, int kb);
__global__ void fw_phase2_row_full(int* __restrict__ dist, int V, int kb);
__global__ void fw_phase2_col(int* __restrict__ dist, int V, int kb);
__global__ void fw_phase2_col_full(int* __restrict__ dist, int V, int kb);
__global__ void fw_phase3(int* __restrict__ dist, int V, int kb);
__global__ void fw_phase3_full_microtiled(int* __restrict__ dist, int V, int kb);

// Helper functions
void check_hip_error(hipError_t err, const char* msg);
void initialize_distance_matrix(int* dist, int V);
void add_edge(int* dist, int V, int src, int dst, int weight);
void solve_apsp_gpu(int* dist, int V);

#endif