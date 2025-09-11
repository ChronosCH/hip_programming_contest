#!/bin/bash

# 详细性能测试脚本 - 专注于大数据量测试
PROJECT_DIR="/home/user087/hip_programming_contest/prefix_sum"
EXECUTABLE="prefix_sum"
VERIFIER="../verify.py"

cd ${PROJECT_DIR}

echo "================================================="
echo "       Prefix Sum Detailed Performance Test     "
echo "================================================="
echo "Test started at $(date)"
echo ""

# 确保可执行文件存在
if [ ! -f ./${EXECUTABLE} ]; then
    echo "Building executable..."
    make clean && make
fi

echo "Testing large dataset performance..."
echo ""

# 多次测试大数据集以获得更稳定的性能数据
echo "Test Case 10 (1,000,000 elements) - Multiple runs:"
echo "-------------------------------------------------"

TOTAL_TIME=0.0
NUM_RUNS=5

for i in $(seq 1 ${NUM_RUNS}); do
    echo -n "Run ${i}/${NUM_RUNS}: "
    
    # 运行并计时
    EXEC_TIME=$( { /usr/bin/time -f "%e" ./${EXECUTABLE} testcases/10.in > temp_output.txt; } 2>&1 )
    
    # 验证正确性
    if python3 ${VERIFIER} temp_output.txt testcases/10.out >/dev/null 2>&1; then
        echo "PASS (${EXEC_TIME}s)"
        TOTAL_TIME=$(echo "${TOTAL_TIME} + ${EXEC_TIME}" | bc -l)
    else
        echo "FAIL - correctness check failed"
        exit 1
    fi
done

# 计算统计数据
AVG_TIME=$(echo "scale=4; ${TOTAL_TIME} / ${NUM_RUNS}" | bc -l)
ELEMENTS_PER_SEC=$(echo "scale=0; 1000000 / ${AVG_TIME}" | bc -l)

echo ""
echo "PERFORMANCE STATISTICS:"
echo "-------------------------------------------------"
echo "Total runs: ${NUM_RUNS}"
echo "Total time: ${TOTAL_TIME}s"
echo "Average time: ${AVG_TIME}s"
echo "Processing rate: ${ELEMENTS_PER_SEC} elements/second"
echo ""

# 计算内存带宽（估算）
INPUT_SIZE_MB=$(echo "scale=2; 1000000 * 4 / 1024 / 1024" | bc -l)  # 4 bytes per int
OUTPUT_SIZE_MB=${INPUT_SIZE_MB}  # 输出同样大小
TOTAL_DATA_MB=$(echo "scale=2; ${INPUT_SIZE_MB} + ${OUTPUT_SIZE_MB}" | bc -l)
BANDWIDTH_MBPS=$(echo "scale=2; ${TOTAL_DATA_MB} / ${AVG_TIME}" | bc -l)

echo "MEMORY ANALYSIS:"
echo "-------------------------------------------------"
echo "Input data size: ${INPUT_SIZE_MB} MB"
echo "Output data size: ${OUTPUT_SIZE_MB} MB"
echo "Total data transferred: ${TOTAL_DATA_MB} MB"
echo "Estimated memory bandwidth: ${BANDWIDTH_MBPS} MB/s"
echo ""

# 测试不同大小的数据集性能对比
echo "SCALABILITY TEST:"
echo "-------------------------------------------------"
for test_case in {1..9}; do
    if [ -f "testcases/${test_case}.in" ]; then
        elements=$(head -1 "testcases/${test_case}.in")
        echo -n "Test ${test_case} (${elements} elements): "
        
        EXEC_TIME=$( { /usr/bin/time -f "%e" ./${EXECUTABLE} testcases/${test_case}.in > temp_output.txt; } 2>&1 )
        
        if python3 ${VERIFIER} temp_output.txt testcases/${test_case}.out >/dev/null 2>&1; then
            if [ ${elements} -gt 0 ]; then
                RATE=$(echo "scale=0; ${elements} / ${EXEC_TIME}" | bc -l)
                echo "PASS (${EXEC_TIME}s, ${RATE} elements/s)"
            else
                echo "PASS (${EXEC_TIME}s)"
            fi
        else
            echo "FAIL"
        fi
    fi
done

echo ""
echo "Test completed at $(date)"
echo "================================================="

# 清理
rm -f temp_output.txt
