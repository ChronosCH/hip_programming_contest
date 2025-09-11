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
CXX_COMPILER="g++"
CXX_FLAGS="-O2"

# 源文件和可执行文件名
SOURCE_FILES="main.cpp" # 如果有多个.cpp文件，用空格隔开
EXECUTABLE="main"
SOURCE_FILES_SERIAL="main_serial.cpp"
EXECUTABLE_SERIAL="main_serial"

# 测试用例和输出结果的目录
TEST_CASE_DIR="testcases"
GOLDEN_DIR="testcases"
MY_OUTPUT_DIR="my_outputs" # 存放程序输出的临时目录
SERIAL_OUTPUT_DIR="serial_outputs" # 存放串行算法输出的目录

# 正确性验证脚本
VERIFIER="verify.py"

# --- Script Body ---

# 遇到任何错误立即退出
set -e

# 1. 准备工作
echo "================================================="
echo "               CCF TCARCH Self-Test              "
echo "================================================="
echo "Job started on $(hostname) at $(date)"
echo ""

# 清理旧的输出和可执行文件
rm -f ${EXECUTABLE} ${EXECUTABLE_SERIAL}
rm -rf ${MY_OUTPUT_DIR} ${SERIAL_OUTPUT_DIR}
mkdir -p ${MY_OUTPUT_DIR} ${SERIAL_OUTPUT_DIR}

# 2. 编译代码
echo "STEP 1: Compiling source code..."
echo "Compiling GPU version..."
${COMPILER} ${CXX_FLAGS} -o ${EXECUTABLE} ${SOURCE_FILES}

# 检查GPU版本编译是否成功
if [ ! -f ./${EXECUTABLE} ]; then
    echo "GPU COMPILATION FAILED! Please check your code."
    exit 1
fi
echo "GPU compilation successful. Executable '${EXECUTABLE}' created."

echo "Compiling CPU serial version..."
${CXX_COMPILER} ${CXX_FLAGS} -o ${EXECUTABLE_SERIAL} ${SOURCE_FILES_SERIAL}

# 检查串行版本编译是否成功
if [ ! -f ./${EXECUTABLE_SERIAL} ]; then
    echo "SERIAL COMPILATION FAILED! Please check your code."
    exit 1
fi
echo "Serial compilation successful. Executable '${EXECUTABLE_SERIAL}' created."
echo ""

# 3. 初始化计时器和计数器
TOTAL_TIME_GPU=0.0
TOTAL_TIME_SERIAL=0.0
PASSED_COUNT=0
TEST_COUNT=$(ls -1q ${TEST_CASE_DIR}/*.in | wc -l)

echo "STEP 2: Running GPU test cases..."
echo "Found ${TEST_COUNT} test cases in ${TEST_CASE_DIR}"
echo "-------------------------------------------------"

# 4. 循环执行所有测试用例
for input_file in ${TEST_CASE_DIR}/*.in; do
    # 从输入文件名派生出基础名和对应的输出文件名
    base_name=$(basename "${input_file}" .in)
    golden_output_file="${GOLDEN_DIR}/${base_name}.out"
    my_output_file="${MY_OUTPUT_DIR}/${base_name}.myout"

    echo -n "Running GPU test [${base_name}]... "

    # 检查标准答案文件是否存在
    if [ ! -f "${golden_output_file}" ]; then
        echo "SKIPPED. Reason: Golden output file ${golden_output_file} not found."
        continue
    fi
    
    # 运行并计时。注意：这里的调用方式是 ./main <input_file>
    # 使用更可靠的时间测量方法，避免GPU程序输出干扰
    START_TIME=$(date +%s.%N)
    ./${EXECUTABLE} "${input_file}" > "${my_output_file}" 2>/dev/null
    END_TIME=$(date +%s.%N)
    EXEC_TIME_GPU=$(echo "${END_TIME} - ${START_TIME}" | bc -l)
    
    # 调用 Python 验证器进行比较
    if python3 ${VERIFIER} "${my_output_file}" "${golden_output_file}" >/dev/null 2>&1; then
        # 验证通过
        echo "PASS ($(printf "%.3f" ${EXEC_TIME_GPU})s)"
        PASSED_COUNT=$((PASSED_COUNT + 1))
        # 使用 bc 工具进行浮点数加法
        TOTAL_TIME_GPU=$(echo "${TOTAL_TIME_GPU} + ${EXEC_TIME_GPU}" | bc -l)
    else
        # 验证失败
        echo "FAIL"
        echo "-------------------------------------------------"
        echo "ERROR: Output mismatch on test case [${base_name}]."
        echo "Your output is in: ${my_output_file}"
        echo "The correct output is in: ${golden_output_file}"
        echo "You can use 'diff -u ${golden_output_file} ${my_output_file}' to see the difference."
        echo "Aborting tests."
        exit 1
    fi
done

# 6. 运行串行算法测试
echo "-------------------------------------------------"
echo "STEP 3: Running Serial CPU test cases..."
echo "-------------------------------------------------"

SERIAL_PASSED_COUNT=0

for input_file in ${TEST_CASE_DIR}/*.in; do
    # 从输入文件名派生出基础名和对应的输出文件名
    base_name=$(basename "${input_file}" .in)
    golden_output_file="${GOLDEN_DIR}/${base_name}.out"
    serial_output_file="${SERIAL_OUTPUT_DIR}/${base_name}.serialout"

    echo -n "Running Serial test [${base_name}]... "

    # 检查标准答案文件是否存在
    if [ ! -f "${golden_output_file}" ]; then
        echo "SKIPPED. Reason: Golden output file ${golden_output_file} not found."
        continue
    fi
    
    # 运行串行算法并计时
    START_TIME_SERIAL=$(date +%s.%N)
    ./${EXECUTABLE_SERIAL} "${input_file}" > "${serial_output_file}" 2>/dev/null
    END_TIME_SERIAL=$(date +%s.%N)
    EXEC_TIME_SERIAL=$(echo "${END_TIME_SERIAL} - ${START_TIME_SERIAL}" | bc -l)
    
    # 调用 Python 验证器进行比较
    if python3 ${VERIFIER} "${serial_output_file}" "${golden_output_file}" >/dev/null 2>&1; then
        # 验证通过
        echo "PASS ($(printf "%.3f" ${EXEC_TIME_SERIAL})s)"
        SERIAL_PASSED_COUNT=$((SERIAL_PASSED_COUNT + 1))
        # 使用 bc 工具进行浮点数加法
        TOTAL_TIME_SERIAL=$(echo "${TOTAL_TIME_SERIAL} + ${EXEC_TIME_SERIAL}" | bc -l)
    else
        # 验证失败
        echo "FAIL"
        echo "-------------------------------------------------"
        echo "ERROR: Output mismatch on test case [${base_name}]."
        echo "Your serial output is in: ${serial_output_file}"
        echo "The correct output is in: ${golden_output_file}"
        echo "You can use 'diff -u ${golden_output_file} ${serial_output_file}' to see the difference."
        echo "Aborting tests."
        exit 1
    fi
done

# 7. 性能对比分析
echo "-------------------------------------------------"
echo "STEP 4: Performance Comparison Analysis"
echo "-------------------------------------------------"

# 计算加速比
if (( $(echo "${TOTAL_TIME_SERIAL} > 0" | bc -l) )); then
    SPEEDUP=$(echo "scale=3; ${TOTAL_TIME_SERIAL} / ${TOTAL_TIME_GPU}" | bc)
    echo "GPU vs Serial Performance Summary:"
    echo "  GPU Total Time:    ${TOTAL_TIME_GPU} seconds"
    echo "  Serial Total Time: ${TOTAL_TIME_SERIAL} seconds"
    echo "  Speedup:           ${SPEEDUP}x"
    
    if (( $(echo "${SPEEDUP} > 1.1" | bc -l) )); then
        echo "  Result: GPU implementation is FASTER"
    elif (( $(echo "${SPEEDUP} < 0.9" | bc -l) )); then
        echo "  Result: Serial implementation is FASTER"
        echo "  Note: For small graphs, CPU might be faster due to GPU overhead"
    else
        echo "  Result: Both implementations have similar performance"
    fi
else
    echo "Note: Serial execution time is very small (< 0.01s)"
    echo "This indicates the test cases are small - GPU overhead dominates for small graphs"
    echo "GPU vs Serial Performance Summary:"
    echo "  GPU Total Time:    ${TOTAL_TIME_GPU} seconds"
    echo "  Serial Total Time: ${TOTAL_TIME_SERIAL} seconds"
    echo "  Result: For these small test cases, serial implementation is likely faster"
fi

# 逐个测试用例的性能对比
echo ""
echo "Individual Test Case Performance:"
echo "Test Case | GPU Time | Serial Time | Speedup"
echo "----------|----------|-------------|--------"

count=0
for input_file in ${TEST_CASE_DIR}/*.in; do
    base_name=$(basename "${input_file}" .in)
    golden_output_file="${GOLDEN_DIR}/${base_name}.out"
    
    if [ ! -f "${golden_output_file}" ]; then
        continue
    fi
    
    # 重新运行以获取单独的时间测量
    START_GPU=$(date +%s.%N)
    ./${EXECUTABLE} "${input_file}" > /dev/null 2>&1
    END_GPU=$(date +%s.%N)
    GPU_TIME=$(echo "${END_GPU} - ${START_GPU}" | bc -l)
    
    START_SERIAL=$(date +%s.%N)
    ./${EXECUTABLE_SERIAL} "${input_file}" > /dev/null 2>&1
    END_SERIAL=$(date +%s.%N)
    SERIAL_TIME=$(echo "${END_SERIAL} - ${START_SERIAL}" | bc -l)
    
    if (( $(echo "${SERIAL_TIME} > 0.001" | bc -l) )); then
        CASE_SPEEDUP=$(echo "scale=2; ${SERIAL_TIME} / ${GPU_TIME}" | bc -l)
    else
        CASE_SPEEDUP="N/A"
    fi
    
    printf "%-9s | %-8s | %-11s | %s\n" "${base_name}" "$(printf "%.3f" ${GPU_TIME})s" "$(printf "%.3f" ${SERIAL_TIME})s" "${CASE_SPEEDUP}x"
    
    count=$((count + 1))
    if [ $count -ge 5 ]; then
        echo "... (showing first 5 test cases)"
        break
    fi
done

# 5. 输出最终总结
echo "-------------------------------------------------"
echo "FINAL RESULT: ALL TESTS PASSED!"
echo ""
echo "GPU Implementation Results:"
echo "    Passed cases: ${PASSED_COUNT} / ${TEST_COUNT}"
echo "    Total execution time: ${TOTAL_TIME_GPU} seconds"
echo ""
echo "Serial Implementation Results:"
echo "    Passed cases: ${SERIAL_PASSED_COUNT} / ${TEST_COUNT}"
echo "    Total execution time: ${TOTAL_TIME_SERIAL} seconds"
echo ""
echo "Job finished at $(date)"
echo "================================================="
