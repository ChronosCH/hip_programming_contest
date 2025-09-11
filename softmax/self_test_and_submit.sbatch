#!/bin/bash
#SBATCH -J YourTeamName_SelfTest    # 作业名称，可以修改为自己的队名
#SBATCH --ntasks-per-node=1         # 每个节点运行 1 个任务
#SBATCH --cpus-per-task=8           # 每个任务使用 8 个 CPU核心
#SBATCH --gres=gpu:1                # 申请 1 张 GPU 卡
#SBATCH -o output_%j.log            # 将日志输出到 output_<job_id>.log 文件
#SBATCH --mem=32G

# --- Script Configuration ---
# C++ 编译器及参数
COMPILER="hipcc"
CXX_FLAGS=" "

# GPU版本源文件和可执行文件名
GPU_SOURCE_FILES="main.cpp kernel.hip" # 如果有多个.cpp文件，用空格隔开
GPU_EXECUTABLE="softmax"

# 串行版本源文件和可执行文件名
SERIAL_SOURCE_FILES="main_serial.cpp"
SERIAL_EXECUTABLE="softmax_serial"
SERIAL_COMPILER="g++"

# 测试用例和输出结果的目录
TEST_CASE_DIR="testcases"
GOLDEN_DIR="testcases"
GPU_OUTPUT_DIR="my_outputs_gpu" # 存放GPU程序输出的临时目录
SERIAL_OUTPUT_DIR="my_outputs_serial" # 存放串行程序输出的临时目录

# 正确性验证脚本
VERIFIER="verify.py"

# --- Script Body ---

# 遇到任何错误立即退出
set -e

# 1. 准备工作
echo "================================================="
echo "           CCF TCARCH Performance Test           "
echo "================================================="
echo "Job started on $(hostname) at $(date)"
echo ""

# 清理旧的输出和可执行文件
rm -f ${GPU_EXECUTABLE} ${SERIAL_EXECUTABLE}
rm -rf ${GPU_OUTPUT_DIR} ${SERIAL_OUTPUT_DIR}
mkdir -p ${GPU_OUTPUT_DIR} ${SERIAL_OUTPUT_DIR}

# 2. 编译代码
echo "STEP 1: Compiling source code..."

echo "  Compiling GPU version..."
${COMPILER} ${CXX_FLAGS} -o ${GPU_EXECUTABLE} ${GPU_SOURCE_FILES}

# 检查GPU版本编译是否成功
if [ ! -f ./${GPU_EXECUTABLE} ]; then
    echo "GPU COMPILATION FAILED! Please check your code."
    exit 1
fi
echo "  GPU compilation successful. Executable '${GPU_EXECUTABLE}' created."

echo "  Compiling Serial version..."
${SERIAL_COMPILER} ${CXX_FLAGS} -O2 -ffast-math -o ${SERIAL_EXECUTABLE} ${SERIAL_SOURCE_FILES} -lm

# 检查串行版本编译是否成功
if [ ! -f ./${SERIAL_EXECUTABLE} ]; then
    echo "SERIAL COMPILATION FAILED! Please check your code."
    exit 1
fi
echo "  Serial compilation successful. Executable '${SERIAL_EXECUTABLE}' created."
echo ""

# 3. 初始化计时器和计数器
GPU_TOTAL_TIME=0.0
SERIAL_TOTAL_TIME=0.0
PASSED_COUNT=0
TEST_COUNT=$(ls -1q ${TEST_CASE_DIR}/*.in | wc -l)

echo "STEP 2: Running test cases and performance comparison..."
echo "Found ${TEST_COUNT} test cases in ${TEST_CASE_DIR}"
echo "-------------------------------------------------"
printf "%-10s %-12s %-12s %-10s %-15s\n" "Test Case" "GPU Time(s)" "Serial Time(s)" "Speedup" "Status"
echo "-------------------------------------------------"

# 4. 循环执行所有测试用例
for input_file in ${TEST_CASE_DIR}/*.in; do
    # 从输入文件名派生出基础名和对应的输出文件名
    base_name=$(basename "${input_file}" .in)
    golden_output_file="${GOLDEN_DIR}/${base_name}.out"
    gpu_output_file="${GPU_OUTPUT_DIR}/${base_name}.gpu.out"
    serial_output_file="${SERIAL_OUTPUT_DIR}/${base_name}.serial.out"

    # 检查标准答案文件是否存在
    if [ ! -f "${golden_output_file}" ]; then
        printf "%-10s %-12s %-12s %-10s %-15s\n" "${base_name}" "SKIPPED" "SKIPPED" "N/A" "No Golden File"
        continue
    fi
    
    # 运行GPU版本并计时
    GPU_TIME=$( { /usr/bin/time -f "%e" ./${GPU_EXECUTABLE} "${input_file}" > "${gpu_output_file}"; } 2>&1 )
    
    # 运行串行版本并计时
    SERIAL_TIME=$( { /usr/bin/time -f "%e" ./${SERIAL_EXECUTABLE} "${input_file}" > "${serial_output_file}"; } 2>&1 )
    
    # 验证GPU版本输出的正确性
    GPU_CORRECT=false
    if python3 ${VERIFIER} "${gpu_output_file}" "${golden_output_file}" >/dev/null 2>&1; then
        GPU_CORRECT=true
    fi
    
    # 验证串行版本输出的正确性
    SERIAL_CORRECT=false
    if python3 ${VERIFIER} "${serial_output_file}" "${golden_output_file}" >/dev/null 2>&1; then
        SERIAL_CORRECT=true
    fi
    
    # 计算加速比
    if [ "${SERIAL_TIME}" != "0.00" ] && [ "${GPU_TIME}" != "0.00" ]; then
        SPEEDUP=$(echo "scale=2; ${SERIAL_TIME} / ${GPU_TIME}" | bc)
    else
        SPEEDUP="N/A"
    fi
    
    # 判断整体状态
    if [ "$GPU_CORRECT" = true ] && [ "$SERIAL_CORRECT" = true ]; then
        STATUS="PASS"
        PASSED_COUNT=$((PASSED_COUNT + 1))
        # 累加时间
        GPU_TOTAL_TIME=$(echo "${GPU_TOTAL_TIME} + ${GPU_TIME}" | bc)
        SERIAL_TOTAL_TIME=$(echo "${SERIAL_TOTAL_TIME} + ${SERIAL_TIME}" | bc)
    elif [ "$GPU_CORRECT" = false ] && [ "$SERIAL_CORRECT" = true ]; then
        STATUS="GPU FAIL"
    elif [ "$GPU_CORRECT" = true ] && [ "$SERIAL_CORRECT" = false ]; then
        STATUS="SERIAL FAIL"
    else
        STATUS="BOTH FAIL"
    fi
    
    # 输出结果
    printf "%-10s %-12s %-12s %-10s %-15s\n" "${base_name}" "${GPU_TIME}" "${SERIAL_TIME}" "${SPEEDUP}" "${STATUS}"
    
    # 如果GPU版本失败则终止测试
    if [ "$GPU_CORRECT" = false ]; then
        echo "-------------------------------------------------"
        echo "ERROR: GPU output mismatch on test case [${base_name}]."
        echo "GPU output is in: ${gpu_output_file}"
        echo "The correct output is in: ${golden_output_file}"
        echo "You can use 'diff -u ${golden_output_file} ${gpu_output_file}' to see the difference."
        echo "Aborting tests."
        exit 1
    fi
done

# 5. 输出最终总结
echo "-------------------------------------------------"
echo "FINAL RESULT: ALL TESTS PASSED!"
echo ""
echo "    Passed cases: ${PASSED_COUNT} / ${TEST_COUNT}"
echo ""

# 计算总体加速比
if [ "${SERIAL_TOTAL_TIME}" != "0.00" ] && [ "${GPU_TOTAL_TIME}" != "0.00" ]; then
    OVERALL_SPEEDUP=$(echo "scale=2; ${SERIAL_TOTAL_TIME} / ${GPU_TOTAL_TIME}" | bc)
else
    OVERALL_SPEEDUP="N/A"
fi

echo "PERFORMANCE SUMMARY:"
echo "    GPU total execution time:    ${GPU_TOTAL_TIME} seconds"
echo "    Serial total execution time: ${SERIAL_TOTAL_TIME} seconds"
echo "    Overall speedup:             ${OVERALL_SPEEDUP}x"
echo ""

# 性能分析
if [ "${OVERALL_SPEEDUP}" != "N/A" ]; then
    SPEEDUP_COMPARISON=$(echo "${OVERALL_SPEEDUP} > 1.0" | bc)
    if [ "${SPEEDUP_COMPARISON}" -eq 1 ]; then
        echo "🚀 GPU implementation is faster than serial implementation!"
        EFFICIENCY=$(echo "scale=1; ${OVERALL_SPEEDUP} * 100 / 1" | bc)
        echo "   Performance improvement: ${EFFICIENCY}% faster"
    else
        echo "⚠️  GPU implementation is slower than serial implementation."
        echo "   Consider optimizing memory access patterns or kernel design."
    fi
fi

echo ""
echo "Job finished at $(date)"
echo "================================================="
