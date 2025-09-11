#include "main.h"
#include <hip/hip_runtime.h>
#include <cfloat>

#define BLOCK_SIZE 512
#define WARP_SIZE 64

// Single-pass fused softmax kernel - most efficient for medium sizes
__global__ void softmax_single_pass(const float* __restrict__ input, 
                                    float* __restrict__ output, 
                                    int N) {
    extern __shared__ char shared_mem[];
    float* s_max = (float*)shared_mem;
    double* s_sum = (double*)(shared_mem + BLOCK_SIZE * sizeof(float));
    
    int tid = threadIdx.x;
    int bid = blockIdx.x;
    
    // Only use one block for moderate sizes
    if (bid > 0) return;
    
    // Phase 1: Find maximum
    float thread_max = -FLT_MAX;
    for (int i = tid; i < N; i += blockDim.x) {
        thread_max = fmaxf(thread_max, input[i]);
    }
    s_max[tid] = thread_max;
    __syncthreads();
    
    // Reduce maximum
    for (int s = blockDim.x / 2; s > 0; s >>= 1) {
        if (tid < s) {
            s_max[tid] = fmaxf(s_max[tid], s_max[tid + s]);
        }
        __syncthreads();
    }
    float global_max = s_max[0];
    __syncthreads();
    
    // Phase 2: Compute sum of exp(x - max)
    double thread_sum = 0.0;
    for (int i = tid; i < N; i += blockDim.x) {
        thread_sum += (double)expf(input[i] - global_max);
    }
    s_sum[tid] = thread_sum;
    __syncthreads();
    
    // Reduce sum
    for (int s = blockDim.x / 2; s > 0; s >>= 1) {
        if (tid < s) {
            s_sum[tid] += s_sum[tid + s];
        }
        __syncthreads();
    }
    double inv_sum = 1.0 / s_sum[0];
    __syncthreads();
    
    // Phase 3: Write final values
    for (int i = tid; i < N; i += blockDim.x) {
        output[i] = (float)((double)expf(input[i] - global_max) * inv_sum);
    }
}

// Multi-block implementation for very large arrays
__global__ void softmax_multi_block_reduce_max(const float* __restrict__ input,
                                               float* __restrict__ block_max,
                                               int N) {
    extern __shared__ float s_data[];
    int tid = threadIdx.x;
    int gid = blockIdx.x * blockDim.x + threadIdx.x;
    
    float thread_max = -FLT_MAX;
    for (int i = gid; i < N; i += blockDim.x * gridDim.x) {
        thread_max = fmaxf(thread_max, input[i]);
    }
    s_data[tid] = thread_max;
    __syncthreads();
    
    for (int s = blockDim.x / 2; s > 0; s >>= 1) {
        if (tid < s) {
            s_data[tid] = fmaxf(s_data[tid], s_data[tid + s]);
        }
        __syncthreads();
    }
    
    if (tid == 0) {
        block_max[blockIdx.x] = s_data[0];
    }
}

__global__ void softmax_multi_block_sum_exp(const float* __restrict__ input,
                                            double* __restrict__ block_sum,
                                            float global_max,
                                            int N) {
    extern __shared__ double s_sum_data[];
    int tid = threadIdx.x;
    int gid = blockIdx.x * blockDim.x + threadIdx.x;
    
    double thread_sum = 0.0;
    for (int i = gid; i < N; i += blockDim.x * gridDim.x) {
        thread_sum += (double)expf(input[i] - global_max);
    }
    s_sum_data[tid] = thread_sum;
    __syncthreads();
    
    for (int s = blockDim.x / 2; s > 0; s >>= 1) {
        if (tid < s) {
            s_sum_data[tid] += s_sum_data[tid + s];
        }
        __syncthreads();
    }
    
    if (tid == 0) {
        block_sum[blockIdx.x] = s_sum_data[0];
    }
}

__global__ void softmax_multi_block_normalize(const float* __restrict__ input,
                                              float* __restrict__ output,
                                              float global_max,
                                              double inv_sum,
                                              int N) {
    int gid = blockIdx.x * blockDim.x + threadIdx.x;
    
    for (int i = gid; i < N; i += blockDim.x * gridDim.x) {
        output[i] = (float)((double)expf(input[i] - global_max) * inv_sum);
    }
}

extern "C" void solve(const float* input, float* output, int N) {
    if (N <= 0) return;
    
    // Memory allocation
    float *d_input, *d_output;
    hipMalloc(&d_input, N * sizeof(float));
    hipMalloc(&d_output, N * sizeof(float));
    
    // Copy input
    hipMemcpy(d_input, input, N * sizeof(float), hipMemcpyHostToDevice);
    
    if (N <= 10000000) { // 10M elements threshold
        // Use single-block approach for moderate sizes
        size_t shared_mem_size = BLOCK_SIZE * sizeof(float) + BLOCK_SIZE * sizeof(double);
        hipLaunchKernelGGL(softmax_single_pass, dim3(1), dim3(BLOCK_SIZE), 
                          shared_mem_size, 0, d_input, d_output, N);
    } else {
        // Use multi-block approach for very large arrays
        int num_blocks = min((N + BLOCK_SIZE - 1) / BLOCK_SIZE, 1024);
        
        float *d_block_max;
        double *d_block_sum;
        hipMalloc(&d_block_max, num_blocks * sizeof(float));
        hipMalloc(&d_block_sum, num_blocks * sizeof(double));
        
        // Step 1: Find global maximum
        hipLaunchKernelGGL(softmax_multi_block_reduce_max, dim3(num_blocks), dim3(BLOCK_SIZE),
                          BLOCK_SIZE * sizeof(float), 0, d_input, d_block_max, N);
        
        // Reduce block maxima on host
        float *h_block_max = new float[num_blocks];
        hipMemcpy(h_block_max, d_block_max, num_blocks * sizeof(float), hipMemcpyDeviceToHost);
        float global_max = h_block_max[0];
        for (int i = 1; i < num_blocks; i++) {
            global_max = fmaxf(global_max, h_block_max[i]);
        }
        delete[] h_block_max;
        
        // Step 2: Compute sum of exp values
        hipLaunchKernelGGL(softmax_multi_block_sum_exp, dim3(num_blocks), dim3(BLOCK_SIZE),
                          BLOCK_SIZE * sizeof(double), 0, d_input, d_block_sum, global_max, N);
        
        // Reduce block sums on host
        double *h_block_sum = new double[num_blocks];
        hipMemcpy(h_block_sum, d_block_sum, num_blocks * sizeof(double), hipMemcpyDeviceToHost);
        double total_sum = 0.0;
        for (int i = 0; i < num_blocks; i++) {
            total_sum += h_block_sum[i];
        }
        delete[] h_block_sum;
        
        double inv_sum = 1.0 / total_sum;
        
        // Step 3: Normalize
        hipLaunchKernelGGL(softmax_multi_block_normalize, dim3(num_blocks), dim3(BLOCK_SIZE), 0, 0,
                          d_input, d_output, global_max, inv_sum, N);
        
        hipFree(d_block_max);
        hipFree(d_block_sum);
    }
    
    // Copy result back
    hipMemcpy(output, d_output, N * sizeof(float), hipMemcpyDeviceToHost);
    
    // Cleanup
    hipFree(d_input);
    hipFree(d_output);
}
