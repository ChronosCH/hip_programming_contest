#!/bin/bash

# 简化的GPU vs CPU性能对比脚本
PROJECT_DIR="/home/user087/hip_programming_contest/prefix_sum"
GPU_EXECUTABLE="prefix_sum"
CPU_EXECUTABLE="prefix_sum_serial"

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
printf "%-10s %-12s %-15s %-15s %-10s\n" "TestCase" "Elements" "GPU_Total(s)" "CPU_Total(s)" "Speedup"
echo "-------------------------------------------------"

# 测试几个关键的测试样例
test_cases=(1 3 6 8 9 10)

for test_case in "${test_cases[@]}"; do
    if [ -f "testcases/${test_case}.in" ]; then
        elements=$(head -1 "testcases/${test_case}.in")
        
        # GPU版本测试 (总时间)
        GPU_TIME=$( { /usr/bin/time -f "%e" ./${GPU_EXECUTABLE} testcases/${test_case}.in > /dev/null; } 2>&1 )
        
        # CPU版本测试 (总时间)
        CPU_TIME=$( { /usr/bin/time -f "%e" ./${CPU_EXECUTABLE} testcases/${test_case}.in > /dev/null 2>&1; } 2>&1 )
        
        # 计算加速比
        if (( $(echo "${GPU_TIME} > 0" | bc -l) )) && (( $(echo "${CPU_TIME} > 0" | bc -l) )); then
            SPEEDUP=$(echo "scale=2; ${CPU_TIME} / ${GPU_TIME}" | bc -l)
            SPEEDUP_STR="${SPEEDUP}x"
        else
            SPEEDUP_STR="N/A"
        fi
        
        printf "%-10s %-12s %-15s %-15s %-10s\n" "${test_case}" "${elements}" "${GPU_TIME}" "${CPU_TIME}" "${SPEEDUP_STR}"
    fi
done

echo "-------------------------------------------------"
echo ""

# 详细分析大数据集 (测试样例10)
echo "DETAILED ANALYSIS - Large Dataset (1M elements):"
echo "-------------------------------------------------"

echo "=== GPU Version ==="
echo "Running GPU version 3 times for average..."
GPU_TIMES=()
for i in {1..3}; do
    GPU_TIME=$( { /usr/bin/time -f "%e" ./${GPU_EXECUTABLE} testcases/10.in > /dev/null; } 2>&1 )
    GPU_TIMES+=($GPU_TIME)
    echo "Run $i: ${GPU_TIME}s"
done

echo ""
echo "=== CPU Version ==="
echo "Running CPU version 3 times for average..."
CPU_TIMES=()
for i in {1..3}; do
    CPU_TIME=$( { /usr/bin/time -f "%e" ./${CPU_EXECUTABLE} testcases/10.in > /dev/null 2>&1; } 2>&1 )
    CPU_TIMES+=($CPU_TIME)
    echo "Run $i: ${CPU_TIME}s"
done

echo ""
echo "=== CPU Algorithm Performance (Pure Computation) ==="
echo "Measuring pure algorithm time..."
./${CPU_EXECUTABLE} testcases/10.in > /dev/null

echo ""
echo "PERFORMANCE SUMMARY:"
echo "-------------------------------------------------"

# 计算平均时间
GPU_AVG=$(echo "scale=4; (${GPU_TIMES[0]} + ${GPU_TIMES[1]} + ${GPU_TIMES[2]}) / 3" | bc -l)
CPU_AVG=$(echo "scale=4; (${CPU_TIMES[0]} + ${CPU_TIMES[1]} + ${CPU_TIMES[2]}) / 3" | bc -l)
FINAL_SPEEDUP=$(echo "scale=2; ${CPU_AVG} / ${GPU_AVG}" | bc -l)

echo "GPU Average Time: ${GPU_AVG}s"
echo "CPU Average Time: ${CPU_AVG}s"
echo "Overall Speedup: ${FINAL_SPEEDUP}x"
echo ""

# 分析结果
echo "ANALYSIS:"
echo "-------------------------------------------------"
if (( $(echo "${FINAL_SPEEDUP} > 1" | bc -l) )); then
    echo "✓ GPU implementation is ${FINAL_SPEEDUP}x faster than CPU"
    echo "✓ Parallel processing advantage overcomes GPU overhead"
else
    echo "• CPU implementation is $(echo "scale=2; 1 / ${FINAL_SPEEDUP}" | bc -l)x faster than GPU"
    echo "• GPU initialization overhead may be significant"
fi

echo ""
echo "KEY OBSERVATIONS:"
echo "-------------------------------------------------"
echo "1. GPU has significant initialization overhead (~0.6s)"
echo "2. CPU pure computation time is only ~2-3ms for 1M elements"
echo "3. CPU total time includes I/O and startup overhead"
echo "4. For very large datasets, GPU parallelism may show more advantage"
echo "5. The crossover point depends on data size and algorithm complexity"

echo ""
echo "Test completed at $(date)"
echo "================================================="
