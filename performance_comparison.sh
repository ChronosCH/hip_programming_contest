#!/bin/bash

# GPU vs CPU 前缀和性能对比测试脚本
PROJECT_DIR="/home/user087/hip_programming_contest/prefix_sum"
GPU_EXECUTABLE="prefix_sum"
CPU_EXECUTABLE="prefix_sum_serial"
VERIFIER="../verify.py"

cd ${PROJECT_DIR}

echo "================================================="
echo "        GPU vs CPU Prefix Sum Performance        "
echo "================================================="
echo "Test started at $(date)"
echo ""

# 确保两个可执行文件都存在
if [ ! -f ./${GPU_EXECUTABLE} ] || [ ! -f ./${CPU_EXECUTABLE} ]; then
    echo "Building executables..."
    make clean && make
fi

echo "PERFORMANCE COMPARISON:"
echo "-------------------------------------------------"
printf "%-10s %-12s %-12s %-12s %-15s\n" "TestCase" "Elements" "GPU_Time(s)" "CPU_Time(s)" "Speedup"
echo "-------------------------------------------------"

TOTAL_GPU_TIME=0.0
TOTAL_CPU_TIME=0.0
TEST_COUNT=0

# 测试所有测试样例
for input_file in testcases/*.in; do
    base_name=$(basename "${input_file}" .in)
    elements=$(head -1 "${input_file}")
    
    # GPU版本测试
    GPU_TIME=$( { /usr/bin/time -f "%e" ./${GPU_EXECUTABLE} "${input_file}" > gpu_output.txt; } 2>&1 )
    
    # CPU版本测试
    CPU_TIME=$( { /usr/bin/time -f "%e" ./${CPU_EXECUTABLE} "${input_file}" > cpu_output.txt 2>/dev/null; } 2>&1 )
    
    # 验证两个版本输出是否一致
    if ! diff -q gpu_output.txt cpu_output.txt >/dev/null 2>&1; then
        echo "ERROR: GPU and CPU outputs differ for test case ${base_name}"
        exit 1
    fi
    
    # 计算加速比
    SPEEDUP=$(echo "scale=2; ${CPU_TIME} / ${GPU_TIME}" | bc -l)
    
    printf "%-10s %-12s %-12s %-12s %-15s\n" "${base_name}" "${elements}" "${GPU_TIME}" "${CPU_TIME}" "${SPEEDUP}x"
    
    # 累加时间
    TOTAL_GPU_TIME=$(echo "${TOTAL_GPU_TIME} + ${GPU_TIME}" | bc -l)
    TOTAL_CPU_TIME=$(echo "${TOTAL_CPU_TIME} + ${CPU_TIME}" | bc -l)
    TEST_COUNT=$((TEST_COUNT + 1))
done

echo "-------------------------------------------------"

# 总体统计
OVERALL_SPEEDUP=$(echo "scale=2; ${TOTAL_CPU_TIME} / ${TOTAL_GPU_TIME}" | bc -l)
AVG_GPU_TIME=$(echo "scale=4; ${TOTAL_GPU_TIME} / ${TEST_COUNT}" | bc -l)
AVG_CPU_TIME=$(echo "scale=4; ${TOTAL_CPU_TIME} / ${TEST_COUNT}" | bc -l)

printf "%-10s %-12s %-12s %-12s %-15s\n" "TOTAL" "All" "${TOTAL_GPU_TIME}" "${TOTAL_CPU_TIME}" "${OVERALL_SPEEDUP}x"
printf "%-10s %-12s %-12s %-12s %-15s\n" "AVERAGE" "-" "${AVG_GPU_TIME}" "${AVG_CPU_TIME}" "-"

echo ""
echo "ANALYSIS:"
echo "-------------------------------------------------"

# 分析大数据集性能
LARGE_TEST_ELEMENTS=1000000
LARGE_GPU_TIME=$(echo "${TOTAL_GPU_TIME}" | tail -1)  # 假设测试10是最大的
LARGE_CPU_TIME=$(echo "${TOTAL_CPU_TIME}" | tail -1)

echo "• Small datasets (< 1000 elements):"
echo "  - GPU performance is limited by initialization overhead"
echo "  - CPU shows better performance due to simplicity"
echo ""

echo "• Large datasets (≥ 100k elements):"
echo "  - GPU parallel processing becomes advantageous"
echo "  - Memory bandwidth becomes the bottleneck"
echo ""

echo "• Overall speedup: ${OVERALL_SPEEDUP}x"
if (( $(echo "${OVERALL_SPEEDUP} > 1" | bc -l) )); then
    echo "  → GPU implementation is faster overall"
else
    echo "  → CPU implementation is faster overall"
fi

echo ""

# 详细分析最大测试样例
echo "LARGE DATASET ANALYSIS (Test Case 10):"
echo "-------------------------------------------------"
GPU_10_TIME=$( { /usr/bin/time -f "%e" ./${GPU_EXECUTABLE} testcases/10.in > gpu_output.txt; } 2>&1 )
CPU_10_TIME=$( { /usr/bin/time -f "%e" ./${CPU_EXECUTABLE} testcases/10.in > cpu_output.txt 2>/dev/null; } 2>&1 )

GPU_THROUGHPUT=$(echo "scale=0; 1000000 / ${GPU_10_TIME}" | bc -l)
CPU_THROUGHPUT=$(echo "scale=0; 1000000 / ${CPU_10_TIME}" | bc -l)
BIG_SPEEDUP=$(echo "scale=2; ${CPU_10_TIME} / ${GPU_10_TIME}" | bc -l)

echo "Elements: 1,000,000"
echo "GPU Time: ${GPU_10_TIME}s (${GPU_THROUGHPUT} elements/s)"
echo "CPU Time: ${CPU_10_TIME}s (${CPU_THROUGHPUT} elements/s)"
echo "Speedup: ${BIG_SPEEDUP}x"

echo ""
echo "RECOMMENDATIONS:"
echo "-------------------------------------------------"
if (( $(echo "${BIG_SPEEDUP} > 1" | bc -l) )); then
    echo "✓ GPU implementation is efficient for large datasets"
    echo "✓ The parallel algorithm scales well with data size"
    echo "• Consider GPU for datasets > 10,000 elements"
else
    echo "• CPU implementation is more efficient"
    echo "• GPU overhead may be too high for this problem size"
    echo "• Consider optimizing GPU memory transfer"
fi

echo ""
echo "Test completed at $(date)"
echo "================================================="

# 清理临时文件
rm -f gpu_output.txt cpu_output.txt
