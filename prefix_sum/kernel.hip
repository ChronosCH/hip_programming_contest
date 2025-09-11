#include "hip/hip_runtime.h"
#include <iostream>
#include <cstdlib>

#define BLOCK_SIZE 512
#define WARP_SIZE 64  // AMD GPU warp size is 64, not 32

// AMD GPU优化的warp扫描
__device__ __forceinline__ int warp_scan_amd(int val) {
    #pragma unroll
    for (int offset = 1; offset < WARP_SIZE; offset <<= 1) {
        int n = __shfl_up(val, offset);
        if ((threadIdx.x & (WARP_SIZE - 1)) >= offset) val += n;
    }
    return val;
}

// 高效的单块扫描kernel - 针对AMD GPU优化
__global__ void efficient_single_block_scan(const int* input, int* output, int N) {
    extern __shared__ int sdata[];

    int tid = threadIdx.x;
    int i = tid;

    // 每个线程处理多个元素来提高内存利用率
    int sum = 0;
    while (i < N) {
        sum += input[i];
        i += blockDim.x;
    }
    sdata[tid] = sum;
    __syncthreads();

    // 块内前缀和扫描
    for (int stride = 1; stride < blockDim.x; stride <<= 1) {
        int temp = 0;
        if (tid >= stride) {
            temp = sdata[tid - stride];
        }
        __syncthreads();
        if (tid >= stride) {
            sdata[tid] += temp;
        }
        __syncthreads();
    }

    // 写回结果 - 每个线程处理多个输出
    int offset = (tid == 0) ? 0 : sdata[tid - 1];
    i = tid;
    int running_sum = offset;
    while (i < N) {
        running_sum += input[i];
        output[i] = running_sum;
        i += blockDim.x;
    }
}

// 高效的多块前缀和kernel - 包含扫描
__global__ void multi_block_scan(const int* input, int* output, int* block_sums, int N) {
    extern __shared__ int sdata[];

    int tid = threadIdx.x;
    int bid = blockIdx.x;
    int global_id = bid * blockDim.x + tid;

    // 加载数据到共享内存
    int val = (global_id < N) ? input[global_id] : 0;
    sdata[tid] = val;
    __syncthreads();

    // 块内包含扫描
    for (int stride = 1; stride < blockDim.x; stride <<= 1) {
        int temp = 0;
        if (tid >= stride) {
            temp = sdata[tid - stride];
        }
        __syncthreads();
        if (tid >= stride) {
            sdata[tid] += temp;
        }
        __syncthreads();
    }

    // 保存块总和
    if (tid == blockDim.x - 1 && block_sums) {
        block_sums[bid] = sdata[tid];
    }

    // 写回结果
    if (global_id < N) {
        output[global_id] = sdata[tid];
    }
}

// 块总和扫描 - 修复inclusive scan逻辑
__global__ void scan_block_sums(int* block_sums, int num_blocks) {
    extern __shared__ int shared[];
    int tid = threadIdx.x;

    // 加载块总和到shared memory
    if (tid < num_blocks) {
        shared[tid] = block_sums[tid];
    } else {
        shared[tid] = 0;
    }
    __syncthreads();

    // Inclusive scan算法
    for (int stride = 1; stride < blockDim.x; stride <<= 1) {
        int temp = 0;
        if (tid >= stride && tid < num_blocks) {
            temp = shared[tid - stride];
        }
        __syncthreads();
        if (tid >= stride && tid < num_blocks) {
            shared[tid] += temp;
        }
        __syncthreads();
    }

    // 写回结果 - 现在shared[tid]包含从块0到块tid的所有块的总和
    if (tid < num_blocks) {
        block_sums[tid] = shared[tid];
    }
}

// 添加块偏移到最终结果
__global__ void add_block_offsets(int* data, const int* block_offsets, int N) {
    int global_id = blockIdx.x * blockDim.x + threadIdx.x;

    if (global_id < N && blockIdx.x > 0) {
        data[global_id] += block_offsets[blockIdx.x - 1];
    }
}

// GPU前缀和实现 - 针对AMD MI100优化
extern "C" void solve__old(const int* input, int* output, int N) {
    if (N <= 0) return;

    // 分配GPU内存
    int* d_input;
    int* d_output;
    hipMalloc(&d_input, N * sizeof(int));
    hipMalloc(&d_output, N * sizeof(int));

    // 异步拷贝输入数据到GPU
    hipMemcpy(d_input, input, N * sizeof(int), hipMemcpyHostToDevice);

    if (N <= BLOCK_SIZE) {
        // 单块处理 - 适用于小到中等数据集
        int block_size = min(N, BLOCK_SIZE);
        // 确保block_size是2的幂次，便于算法实现
        int power_of_2 = 1;
        while (power_of_2 < block_size) power_of_2 <<= 1;
        if (power_of_2 > BLOCK_SIZE) power_of_2 = BLOCK_SIZE;

        dim3 grid(1);
        dim3 block(power_of_2);
        int shared_size = power_of_2 * sizeof(int);

        hipLaunchKernelGGL(efficient_single_block_scan, grid, block, shared_size, 0,
                           d_input, d_output, N);
    } else {
        // 多块处理 - 三阶段算法
        int num_blocks = (N + BLOCK_SIZE - 1) / BLOCK_SIZE;
        dim3 grid(num_blocks);
        dim3 block(BLOCK_SIZE);

        // 分配块总和数组
        int* d_block_sums;
        hipMalloc(&d_block_sums, num_blocks * sizeof(int));

        // 第一阶段：并行扫描每个块
        int shared_size = BLOCK_SIZE * sizeof(int);
        hipLaunchKernelGGL(multi_block_scan, grid, block, shared_size, 0,
                           d_input, d_output, d_block_sums, N);

        // 第二阶段：扫描块总和
        if (num_blocks > 1) {
            // 如果块数少于等于BLOCK_SIZE，可以一次处理完
            if (num_blocks <= BLOCK_SIZE) {
                int power_of_2 = 1;
                while (power_of_2 < num_blocks) power_of_2 <<= 1;

                dim3 sum_grid(1);
                dim3 sum_block(power_of_2);
                int sum_shared_size = power_of_2 * sizeof(int);

                hipLaunchKernelGGL(scan_block_sums, sum_grid, sum_block, sum_shared_size, 0,
                                   d_block_sums, num_blocks);
            } else {
                // 对于大量块，我们使用CPU来计算块前缀和
                // 虽然这不是纯GPU解决方案，但确保了正确性
                int* h_block_sums = new int[num_blocks];
                hipMemcpy(h_block_sums, d_block_sums, num_blocks * sizeof(int), hipMemcpyDeviceToHost);

                // 计算inclusive scan
                for (int i = 1; i < num_blocks; i++) {
                    h_block_sums[i] += h_block_sums[i-1];
                }

                hipMemcpy(d_block_sums, h_block_sums, num_blocks * sizeof(int), hipMemcpyHostToDevice);
                delete[] h_block_sums;
            }

            // 第三阶段：添加块偏移
            hipLaunchKernelGGL(add_block_offsets, grid, block, 0, 0,
                               d_output, d_block_sums, N);
        }

        hipFree(d_block_sums);
    }

    // 拷贝结果回主机
    hipMemcpy(output, d_output, N * sizeof(int), hipMemcpyDeviceToHost);

    // 清理内存
    hipFree(d_input);
    hipFree(d_output);
}

// ===== New pure-GPU hierarchical inclusive scan (MI100-optimized) =====
#ifndef BLOCK_THREADS
#define BLOCK_THREADS 512
#endif
#ifndef ITEMS_PER_THREAD
#define ITEMS_PER_THREAD 8
#endif
#define TILE_SIZE (BLOCK_THREADS * ITEMS_PER_THREAD)

__device__ __forceinline__ int warp_inclusive_scan_wf(int v){
    #pragma unroll
    for(int off=1; off<64; off<<=1){
        int n = __shfl_up(v, off, 64);
        if ((threadIdx.x & 63) >= off) v += n;
    }
    return v;
}

__global__ __launch_bounds__(BLOCK_THREADS)
void tile_inclusive_scan_kernel(const int* __restrict__ in,
                                int* __restrict__ out,
                                int* __restrict__ block_sums,
                                int N){
    const int tid  = threadIdx.x;
    const int bid  = blockIdx.x;
    const int lane = tid & 63;
    const int warp = tid >> 6;
    const int num_warps = BLOCK_THREADS / 64;
    const int tile_start = bid * TILE_SIZE;

    int vals[ITEMS_PER_THREAD];
    #pragma unroll
    for(int i=0;i<ITEMS_PER_THREAD;++i){
        int idx = tile_start + tid * ITEMS_PER_THREAD + i;
        vals[i] = (idx < N) ? in[idx] : 0;
    }
    #pragma unroll
    for(int i=1;i<ITEMS_PER_THREAD;++i) vals[i] += vals[i-1];

    int thread_total = vals[ITEMS_PER_THREAD-1];
    int warp_scan = warp_inclusive_scan_wf(thread_total);

    __shared__ int warp_sums[BLOCK_THREADS / 64];
    if (lane == 63) warp_sums[warp] = warp_scan;
    __syncthreads();

    if (warp == 0){
        int x = (tid < num_warps) ? warp_sums[lane] : 0;
        x = warp_inclusive_scan_wf(x);
        if (tid < num_warps) warp_sums[lane] = x;
    }
    __syncthreads();

    int block_prefix_before_this_warp = (warp==0)?0:warp_sums[warp-1];
    int thread_base = block_prefix_before_this_warp + (warp_scan - thread_total);

    #pragma unroll
    for(int i=0;i<ITEMS_PER_THREAD;++i) vals[i] += thread_base;

    #pragma unroll
    for(int i=0;i<ITEMS_PER_THREAD;++i){
        int idx = tile_start + tid * ITEMS_PER_THREAD + i;
        if (idx < N) out[idx] = vals[i];
    }

    if (block_sums && tid==0){
        block_sums[bid] = warp_sums[num_warps-1];
    }
}

__global__ __launch_bounds__(BLOCK_THREADS)
void add_uniform_offsets_kernel(int* __restrict__ out,
                                const int* __restrict__ block_offsets,
                                int N){
    int bid = blockIdx.x;
    if (bid==0) return;
    int add = block_offsets[bid-1];
    int tid = threadIdx.x;
    int base = bid * TILE_SIZE;
    #pragma unroll
    for(int i=0;i<ITEMS_PER_THREAD;++i){
        int idx = base + tid * ITEMS_PER_THREAD + i;
        if (idx < N) out[idx] += add;
    }
}

static void gpu_inclusive_scan_inplace(int* d_a, int len, hipStream_t stream){
    if (len<=0) return;
    int num_tiles = (len + TILE_SIZE - 1) / TILE_SIZE;
    int* d_block_sums = nullptr;
    if (num_tiles>1) hipMalloc(&d_block_sums, sizeof(int)*num_tiles);

    hipLaunchKernelGGL(tile_inclusive_scan_kernel,
                       dim3(num_tiles), dim3(BLOCK_THREADS), 0, stream,
                       d_a, d_a, d_block_sums, len);

    if (num_tiles<=1) return;

    gpu_inclusive_scan_inplace(d_block_sums, num_tiles, stream);

    hipLaunchKernelGGL(add_uniform_offsets_kernel,
                       dim3(num_tiles), dim3(BLOCK_THREADS), 0, stream,
                       d_a, d_block_sums, len);

    hipFree(d_block_sums);
}

extern "C" void solve(const int* input, int* output, int N){
    if (N<=0) return;
    hipStream_t stream = nullptr;
    int *d_in=nullptr, *d_out=nullptr;
    hipMalloc(&d_in,  sizeof(int)*N);
    hipMalloc(&d_out, sizeof(int)*N);
    hipMemcpyAsync(d_in, input, sizeof(int)*N, hipMemcpyHostToDevice, stream);

    int num_tiles = (N + TILE_SIZE - 1) / TILE_SIZE;
    int* d_block_sums = nullptr;
    if (num_tiles>1) hipMalloc(&d_block_sums, sizeof(int)*num_tiles);

    hipLaunchKernelGGL(tile_inclusive_scan_kernel,
                       dim3(num_tiles), dim3(BLOCK_THREADS), 0, stream,
                       d_in, d_out, d_block_sums, N);

    if (num_tiles>1){
        gpu_inclusive_scan_inplace(d_block_sums, num_tiles, stream);
        hipLaunchKernelGGL(add_uniform_offsets_kernel,
                           dim3(num_tiles), dim3(BLOCK_THREADS), 0, stream,
                           d_out, d_block_sums, N);
    }

    hipMemcpyAsync(output, d_out, sizeof(int)*N, hipMemcpyDeviceToHost, stream);
    hipStreamSynchronize(stream);
    if (d_block_sums) hipFree(d_block_sums);
    hipFree(d_in);
    hipFree(d_out);
}
