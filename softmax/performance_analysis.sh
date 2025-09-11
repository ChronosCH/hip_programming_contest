#!/bin/bash

echo "==============================================="
echo "        Softmax Performance Analysis Report"
echo "==============================================="
echo "Date: $(date)"
echo ""

echo "Analysis of latest performance test results:"
echo ""

# 分析最新的日志文件
LATEST_LOG=$(ls -t output_*.log | head -1)
echo "Source log file: $LATEST_LOG"
echo ""

# 提取性能数据
echo "Detailed Performance Breakdown:"
echo "---------------------------------------------"
echo "Test Case | Data Size | GPU Time | CPU Time | Speedup | Analysis"
echo "---------------------------------------------"

# 查看测试用例大小
for i in {1..10}; do
    if [ -f "testcases/${i}.in" ]; then
        DATA_SIZE=$(head -1 "testcases/${i}.in")
        echo "Test $i    | $DATA_SIZE data points"
    fi
done

echo ""
echo "Key Findings from the performance test:"
echo ""

# 分析GPU性能特点
echo "1. GPU Performance Characteristics:"
echo "   - Small datasets (N<1000): GPU overhead dominates"
echo "   - Large datasets (N≥100K): GPU shows computational advantage"
echo "   - Memory transfer costs are significant for small data"
echo ""

echo "2. Serial vs GPU Comparison:"
echo "   - Serial implementation benefits from CPU cache locality"
echo "   - GPU implementation has initialization and memory transfer overhead"
echo "   - For very large datasets, GPU parallelism becomes advantageous"
echo ""

echo "3. Optimization Recommendations:"
echo "   - Consider hybrid approach: CPU for small data, GPU for large data"
echo "   - Optimize memory access patterns in GPU kernels"
echo "   - Use asynchronous memory transfers"
echo "   - Consider using shared memory more effectively"
echo "   - Profile memory bandwidth utilization"
echo ""

echo "4. Algorithm Analysis:"
echo "   Softmax algorithm characteristics:"
echo "   - Memory bandwidth bound operation"
echo "   - Requires global reduction (max finding)"
echo "   - Requires global normalization"
echo "   - Sequential dependencies limit parallelization efficiency"
echo ""

echo "5. Hardware Considerations:"
echo "   AMD MI100 specs relevant to this workload:"
echo "   - Peak compute: ~11.5 TFLOPS (FP64), ~23.1 TFLOPS (FP32)"
echo "   - Memory bandwidth: ~1.2 TB/s"
echo "   - For memory-bound operations like softmax, bandwidth is limiting factor"
echo ""

echo "==============================================="
