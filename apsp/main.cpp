#include "main.h"

// Block size for optimized Floyd-Warshall
#define B 32
#define PAD (B+1)

// Keep original INF value for output compatibility
#define INF 1073741823  // 2^30 - 1

// Device function for min operation
__device__ __forceinline__ int device_min(int a, int b) {
    return (a < b) ? a : b;
}

// Saturated addition to prevent overflow
__device__ __forceinline__ int add_sat(int a, int b) {
    if (a >= INF || b >= INF) return INF;
    int s = a + b;
    // Overflow detection (if a, b non-negative and s < a, then overflow)
    if (s < a) return INF;
    return s;
}

// Check HIP errors
void check_hip_error(hipError_t err, const char* msg) {
    if (err != hipSuccess) {
        fprintf(stderr, "HIP Error %s: %s\n", msg, hipGetErrorString(err));
        exit(1);
    }
}

// Initialize distance matrix with INF and 0 on diagonal
void initialize_distance_matrix(int* dist, int V) {
    for (int i = 0; i < V; i++) {
        for (int j = 0; j < V; j++) {
            if (i == j) {
                dist[i * V + j] = 0;
            } else {
                dist[i * V + j] = INF;
            }
        }
    }
}

// Add edge to distance matrix
void add_edge(int* dist, int V, int src, int dst, int weight) {
    dist[src * V + dst] = weight;
}

// Helper functions for boundary-safe memory access
__device__ __forceinline__ int load_or_inf(const int* __restrict__ a, int V, int i, int j) {
    return (i < V && j < V) ? a[i * V + j] : INF;
}

__device__ __forceinline__ void store_if_valid(int* __restrict__ a, int V, int i, int j, int v) {
    if (i < V && j < V) a[i * V + j] = v;
}

// Phase 1: Update pivot block (kb,kb)
__global__ __launch_bounds__(1024, 2) void fw_phase1(int* __restrict__ dist, int V, int kb) {
    __shared__ int s[B][PAD];

    const int i = kb * B + threadIdx.y;
    const int j = kb * B + threadIdx.x;

    // Load into shared memory with padding
    s[threadIdx.y][threadIdx.x] = load_or_inf(dist, V, i, j);
    __syncthreads();

    const int KLEN = device_min(B, V - kb * B);

    // Inner k loop in shared memory
    #pragma unroll
    for (int kk = 0; kk < KLEN; ++kk) {
        int via = add_sat(s[threadIdx.y][kk], s[kk][threadIdx.x]);
        int cur = s[threadIdx.y][threadIdx.x];
        if (via < cur) s[threadIdx.y][threadIdx.x] = via;
        __syncthreads();
    }

    store_if_valid(dist, V, i, j, s[threadIdx.y][threadIdx.x]);
}

// Phase 1 specialized for full tiles (KLEN == B)
__global__ __launch_bounds__(1024, 2) void fw_phase1_full(int* __restrict__ dist, int V, int kb) {
    __shared__ int s[B][PAD];

    const int i = kb * B + threadIdx.y;
    const int j = kb * B + threadIdx.x;

    // Load into shared memory with padding
    s[threadIdx.y][threadIdx.x] = load_or_inf(dist, V, i, j);
    __syncthreads();

    // Fully unrolled k loop for complete tiles
    #pragma unroll 32
    for (int kk = 0; kk < B; ++kk) {
        int via = add_sat(s[threadIdx.y][kk], s[kk][threadIdx.x]);
        int cur = s[threadIdx.y][threadIdx.x];
        if (via < cur) s[threadIdx.y][threadIdx.x] = via;
        __syncthreads();
    }

    store_if_valid(dist, V, i, j, s[threadIdx.y][threadIdx.x]);
}

// Phase 2-row: Update row blocks (kb, jb), jb != kb
__global__ __launch_bounds__(1024, 2) void fw_phase2_row(int* __restrict__ dist, int V, int kb) {
    __shared__ int sPivot[B][PAD];
    __shared__ int sRow[B][PAD];

    const int jb = blockIdx.x;
    if (jb == kb) return;

    const int i = kb * B + threadIdx.y;
    const int j = jb * B + threadIdx.x;

    // Load pivot block and current row block
    sPivot[threadIdx.y][threadIdx.x] = load_or_inf(dist, V, kb * B + threadIdx.y, kb * B + threadIdx.x);
    sRow[threadIdx.y][threadIdx.x] = load_or_inf(dist, V, i, j);
    __syncthreads();

    const int KLEN = device_min(B, V - kb * B);

    // Inner k loop in shared memory
    #pragma unroll
    for (int kk = 0; kk < KLEN; ++kk) {
        int via = add_sat(sPivot[threadIdx.y][kk], sRow[kk][threadIdx.x]);
        int cur = sRow[threadIdx.y][threadIdx.x];
        if (via < cur) sRow[threadIdx.y][threadIdx.x] = via;
        __syncthreads();
    }

    store_if_valid(dist, V, i, j, sRow[threadIdx.y][threadIdx.x]);
}

// Phase 2-col: Update column blocks (ib, kb), ib != kb
__global__ __launch_bounds__(1024, 2) void fw_phase2_col(int* __restrict__ dist, int V, int kb) {
    __shared__ int sPivot[B][PAD];
    __shared__ int sCol[B][PAD];

    const int ib = blockIdx.x;
    if (ib == kb) return;

    const int i = ib * B + threadIdx.y;
    const int j = kb * B + threadIdx.x;

    // Load pivot block and current column block
    sPivot[threadIdx.y][threadIdx.x] = load_or_inf(dist, V, kb * B + threadIdx.y, kb * B + threadIdx.x);
    sCol[threadIdx.y][threadIdx.x] = load_or_inf(dist, V, i, j);
    __syncthreads();

    const int KLEN = device_min(B, V - kb * B);

    // Inner k loop in shared memory
    #pragma unroll
    for (int kk = 0; kk < KLEN; ++kk) {
        int via = add_sat(sCol[threadIdx.y][kk], sPivot[kk][threadIdx.x]);
        int cur = sCol[threadIdx.y][threadIdx.x];
        if (via < cur) sCol[threadIdx.y][threadIdx.x] = via;
        __syncthreads();
    }

    store_if_valid(dist, V, i, j, sCol[threadIdx.y][threadIdx.x]);
}

// Phase 2-row specialized for full tiles (KLEN == B)
__global__ __launch_bounds__(1024, 2) void fw_phase2_row_full(int* __restrict__ dist, int V, int kb) {
    __shared__ int sPivot[B][PAD];
    __shared__ int sRow[B][PAD];

    const int jb = blockIdx.x;
    if (jb == kb) return;

    const int i = kb * B + threadIdx.y;
    const int j = jb * B + threadIdx.x;

    // Load pivot block and current row block
    sPivot[threadIdx.y][threadIdx.x] = load_or_inf(dist, V, kb * B + threadIdx.y, kb * B + threadIdx.x);
    sRow[threadIdx.y][threadIdx.x] = load_or_inf(dist, V, i, j);
    __syncthreads();

    // Fully unrolled k loop for complete tiles
    #pragma unroll 32
    for (int kk = 0; kk < B; ++kk) {
        int via = add_sat(sPivot[threadIdx.y][kk], sRow[kk][threadIdx.x]);
        int cur = sRow[threadIdx.y][threadIdx.x];
        if (via < cur) sRow[threadIdx.y][threadIdx.x] = via;
        __syncthreads();
    }

    store_if_valid(dist, V, i, j, sRow[threadIdx.y][threadIdx.x]);
}

// Phase 2-col specialized for full tiles (KLEN == B)
__global__ __launch_bounds__(1024, 2) void fw_phase2_col_full(int* __restrict__ dist, int V, int kb) {
    __shared__ int sPivot[B][PAD];
    __shared__ int sCol[B][PAD];

    const int ib = blockIdx.x;
    if (ib == kb) return;

    const int i = ib * B + threadIdx.y;
    const int j = kb * B + threadIdx.x;

    // Load pivot block and current column block
    sPivot[threadIdx.y][threadIdx.x] = load_or_inf(dist, V, kb * B + threadIdx.y, kb * B + threadIdx.x);
    sCol[threadIdx.y][threadIdx.x] = load_or_inf(dist, V, i, j);
    __syncthreads();

    // Fully unrolled k loop for complete tiles
    #pragma unroll 32
    for (int kk = 0; kk < B; ++kk) {
        int via = add_sat(sCol[threadIdx.y][kk], sPivot[kk][threadIdx.x]);
        int cur = sCol[threadIdx.y][threadIdx.x];
        if (via < cur) sCol[threadIdx.y][threadIdx.x] = via;
        __syncthreads();
    }

    store_if_valid(dist, V, i, j, sCol[threadIdx.y][threadIdx.x]);
}

// Phase 3: Update remaining blocks (ib, jb), ib != kb, jb != kb
// Optimized version that skips empty blocks at launch level
__global__ __launch_bounds__(1024, 2) void fw_phase3(int* __restrict__ dist, int V, int kb) {
    // Map reduced grid coordinates to actual block indices, skipping kb
    const int ib = blockIdx.y + (blockIdx.y >= kb);
    const int jb = blockIdx.x + (blockIdx.x >= kb);

    const int fullBlocks = V / B;
    // 如果这是内部整块位置（且 kb 也是整块），交给 micro-tiled 版本处理，这里直接跳过
    if ((kb < fullBlocks) && (ib < fullBlocks) && (jb < fullBlocks)) return;

    __shared__ int sRow[B][PAD];
    __shared__ int sCol[B][PAD];
    __shared__ int sBlk[B][PAD];

    const int i = ib * B + threadIdx.y;
    const int j = jb * B + threadIdx.x;

    // Load row block (ib,kb), column block (kb,jb), and current block (ib,jb)
    sRow[threadIdx.y][threadIdx.x] = load_or_inf(dist, V, i, kb * B + threadIdx.x);
    sCol[threadIdx.y][threadIdx.x] = load_or_inf(dist, V, kb * B + threadIdx.y, j);
    sBlk[threadIdx.y][threadIdx.x] = load_or_inf(dist, V, i, j);
    __syncthreads(); // Only sync after loading

    const int KLEN = device_min(B, V - kb * B);

    // Inner k loop in shared memory
    #pragma unroll
    for (int kk = 0; kk < KLEN; ++kk) {
        int via = add_sat(sRow[threadIdx.y][kk], sCol[kk][threadIdx.x]);
        int cur = sBlk[threadIdx.y][threadIdx.x];
        if (via < cur) sBlk[threadIdx.y][threadIdx.x] = via;
        // Note: No __syncthreads() needed here since sRow and sCol are read-only
        // and sBlk[ty][tx] is only updated by this thread
    }

    store_if_valid(dist, V, i, j, sBlk[threadIdx.y][threadIdx.x]);
}

// Phase 3 specialized for full tiles with micro-tiling optimization
// Each thread computes 2 columns to reduce shared memory pressure
// Use 16×32=512 threads for correct micro-tiling
__global__ __launch_bounds__(512, 4) void fw_phase3_full_microtiled(int* __restrict__ dist, int V, int kb) {
    const int ib = blockIdx.y + (blockIdx.y >= kb);
    const int jb = blockIdx.x + (blockIdx.x >= kb);

    __shared__ int sRow[B][PAD];
    __shared__ int sCol[B][PAD];
    __shared__ int sBlk[B][PAD];

    const int ty = threadIdx.y;       // 0..31
    const int tx = threadIdx.x;       // 0..15  (注意：threads.x = B/2)

    const int i  = ib * B + ty;
    const int j0 = jb * B + tx;
    const int j1 = jb * B + tx + (B >> 1); // +16

    // 加载：每线程为 sRow/sCol/sBlk 各加载 2 个列分片
    sRow[ty][tx]              = load_or_inf(dist, V, i,            kb * B + tx);
    sRow[ty][tx + (B >> 1)]   = load_or_inf(dist, V, i,            kb * B + tx + (B >> 1));

    sCol[ty][tx]              = load_or_inf(dist, V, kb * B + ty,  j0);
    sCol[ty][tx + (B >> 1)]   = load_or_inf(dist, V, kb * B + ty,  j1);

    sBlk[ty][tx]              = load_or_inf(dist, V, i,            j0);
    sBlk[ty][tx + (B >> 1)]   = load_or_inf(dist, V, i,            j1);
    __syncthreads();

    int acc0 = sBlk[ty][tx];
    int acc1 = sBlk[ty][tx + (B >> 1)];

    #pragma unroll 32
    for (int kk = 0; kk < B; ++kk) {
        int r = sRow[ty][kk];
        acc0 = device_min(acc0, add_sat(r, sCol[kk][tx]));
        acc1 = device_min(acc1, add_sat(r, sCol[kk][tx + (B >> 1)]));
    }

    store_if_valid(dist, V, i, j0, acc0);
    store_if_valid(dist, V, i, j1, acc1);
}

// Main GPU solver function
void solve_apsp_gpu(int* dist, int V) {
    int *d_dist = nullptr;
    size_t bytes = size_t(V) * size_t(V) * sizeof(int);
    check_hip_error(hipMalloc(&d_dist, bytes), "hipMalloc d_dist");
    check_hip_error(hipMemcpy(d_dist, dist, bytes, hipMemcpyHostToDevice), "H2D dist");

    const int nB = (V + B - 1) / B;
    dim3 threads(B, B);

    // Create independent streams for each phase to avoid default stream implicit sync
    hipStream_t s_p1, s_row, s_col, s_p3;
    check_hip_error(hipStreamCreate(&s_p1), "create phase1 stream");
    check_hip_error(hipStreamCreate(&s_row), "create row stream");
    check_hip_error(hipStreamCreate(&s_col), "create col stream");
    check_hip_error(hipStreamCreate(&s_p3), "create phase3 stream");
    
    // Persistent events with timing disabled for better performance
    hipEvent_t e_pivot_done, e_row_done, e_col_done, e_p3_done;
    check_hip_error(hipEventCreateWithFlags(&e_pivot_done, hipEventDisableTiming), "create pivot event");
    check_hip_error(hipEventCreateWithFlags(&e_row_done, hipEventDisableTiming), "create row event");
    check_hip_error(hipEventCreateWithFlags(&e_col_done, hipEventDisableTiming), "create col event");
    check_hip_error(hipEventCreateWithFlags(&e_p3_done, hipEventDisableTiming), "create phase3 event");

    // Timing events (separate from synchronization events)
    hipEvent_t e0, e1; 
    check_hip_error(hipEventCreate(&e0), "create start event");
    check_hip_error(hipEventCreate(&e1), "create end event");
    check_hip_error(hipEventRecord(e0), "record start");

    for (int kb = 0; kb < nB; ++kb) {
        // Wait for previous iteration's phase3 to complete (except first iteration)
        if (kb > 0) {
            check_hip_error(hipStreamWaitEvent(s_p1, e_p3_done, 0), "wait prev phase3");
        }

        // Phase 1: Update pivot block - choose specialized version for full tiles
        const int pivot_size = (B < V - kb * B) ? B : (V - kb * B);
        if (pivot_size == B) {
            fw_phase1_full<<<1, threads, 0, s_p1>>>(d_dist, V, kb);
        } else {
            fw_phase1<<<1, threads, 0, s_p1>>>(d_dist, V, kb);
        }
        check_hip_error(hipGetLastError(), "phase1 kernel launch");
        check_hip_error(hipEventRecord(e_pivot_done, s_p1), "record pivot done");

        // Phase 2: Concurrent row and column updates
        check_hip_error(hipStreamWaitEvent(s_row, e_pivot_done, 0), "row stream wait");
        check_hip_error(hipStreamWaitEvent(s_col, e_pivot_done, 0), "col stream wait");
        
        // Choose specialized version for full tiles in phase2 as well
        if (pivot_size == B) {
            fw_phase2_row_full<<<nB, threads, 0, s_row>>>(d_dist, V, kb);
            check_hip_error(hipGetLastError(), "phase2_row_full kernel launch");
            
            fw_phase2_col_full<<<nB, threads, 0, s_col>>>(d_dist, V, kb);
            check_hip_error(hipGetLastError(), "phase2_col_full kernel launch");
        } else {
            fw_phase2_row<<<nB, threads, 0, s_row>>>(d_dist, V, kb);
            check_hip_error(hipGetLastError(), "phase2_row kernel launch");
            
            fw_phase2_col<<<nB, threads, 0, s_col>>>(d_dist, V, kb);
            check_hip_error(hipGetLastError(), "phase2_col kernel launch");
        }
        
        check_hip_error(hipEventRecord(e_row_done, s_row), "record row done");
        check_hip_error(hipEventRecord(e_col_done, s_col), "record col done");

        // Phase 3: Wait for both phase2 kernels, then update remaining blocks
        check_hip_error(hipStreamWaitEvent(s_p3, e_row_done, 0), "phase3 wait row");
        check_hip_error(hipStreamWaitEvent(s_p3, e_col_done, 0), "phase3 wait col");
        
        // Phase 3: Wait for both phase2 kernels, then update remaining blocks
        check_hip_error(hipStreamWaitEvent(s_p3, e_row_done, 0), "phase3 wait row");
        check_hip_error(hipStreamWaitEvent(s_p3, e_col_done, 0), "phase3 wait col");
        
        if (nB > 1) {
            const int fullBlocks = V / B;      // 完整 32×32 块的数量
            const int rem        = V % B;      // 边界是否存在
            const bool pivot_full = (kb < fullBlocks);

            // 1) 内部 full tiles（不含 kb 行/列）
            if (pivot_full && fullBlocks >= 1) {
                dim3 grid_full(fullBlocks - 1, fullBlocks - 1);
                dim3 threads_full(B/2, B);     // 16×32=512 线程，匹配 micro-tiled kernel
                fw_phase3_full_microtiled<<<grid_full, threads_full, 0, s_p3>>>(d_dist, V, kb);
                check_hip_error(hipGetLastError(), "phase3 full microtiled launch");
            }

            // 2) 边界条带（最后一块行/列，或 pivot 是残块时的全体）
            //    简单起见，仍用通用 kernel 发 (nB-1)×(nB-1) 网格，
            //    但在 kernel 内加一行"跳过内核区"的判断，避免重复计算。
            if (rem > 0 || !pivot_full) {
                dim3 grid_edge(nB - 1, nB - 1);
                fw_phase3<<<grid_edge, threads, 0, s_p3>>>(d_dist, V, kb);
                check_hip_error(hipGetLastError(), "phase3 edge launch");
            }
        }
        
        check_hip_error(hipEventRecord(e_p3_done, s_p3), "record phase3 done");
    }

    // Wait for final phase3 to complete
    check_hip_error(hipEventSynchronize(e_p3_done), "final sync");
    
    check_hip_error(hipEventRecord(e1), "record end");
    check_hip_error(hipEventSynchronize(e1), "sync end");
    float ms=0; 
    check_hip_error(hipEventElapsedTime(&ms, e0, e1), "elapsed time");
    fprintf(stderr, "[GPU] APSP elapsed = %.3f ms\n", ms);

    check_hip_error(hipMemcpy(dist, d_dist, bytes, hipMemcpyDeviceToHost), "D2H dist");
    check_hip_error(hipFree(d_dist), "free d_dist");
    
    // Clean up streams and events
    check_hip_error(hipStreamDestroy(s_p1), "destroy phase1 stream");
    check_hip_error(hipStreamDestroy(s_row), "destroy row stream");
    check_hip_error(hipStreamDestroy(s_col), "destroy col stream");
    check_hip_error(hipStreamDestroy(s_p3), "destroy phase3 stream");
    check_hip_error(hipEventDestroy(e_pivot_done), "destroy pivot event");
    check_hip_error(hipEventDestroy(e_row_done), "destroy row event");
    check_hip_error(hipEventDestroy(e_col_done), "destroy col event");
    check_hip_error(hipEventDestroy(e_p3_done), "destroy phase3 event");
    check_hip_error(hipEventDestroy(e0), "destroy start event");
    check_hip_error(hipEventDestroy(e1), "destroy end event");
}

int main(int argc, char* argv[]) {
    if (argc != 2) {
        std::cerr << "Usage: " << argv[0] << " <input_file>" << std::endl;
        return 1;
    }
    
    std::ifstream input(argv[1]);
    if (!input) {
        std::cerr << "Error: Cannot open input file " << argv[1] << std::endl;
        return 1;
    }
    
    int V, E;
    input >> V >> E;
    
    // Allocate distance matrix
    int* dist = new int[V * V];
    
    // Initialize distance matrix
    initialize_distance_matrix(dist, V);
    
    // Read edges
    for (int i = 0; i < E; i++) {
        int src, dst, weight;
        input >> src >> dst >> weight;
        add_edge(dist, V, src, dst, weight);
    }
    
    input.close();
    
    // Solve APSP on GPU
    solve_apsp_gpu(dist, V);
    
    // Output result
    for (int i = 0; i < V; i++) {
        for (int j = 0; j < V; j++) {
            std::cout << dist[i * V + j];
            if (j < V - 1) std::cout << " ";
        }
        std::cout << std::endl;
    }
    
    delete[] dist;
    return 0;
}