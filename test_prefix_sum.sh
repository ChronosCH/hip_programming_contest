#!/bin/bash

# --- Script Configuration ---
# 项目目录
PROJECT_DIR="/home/user087/hip_programming_contest/prefix_sum"

# 源文件和可执行文件名
EXECUTABLE="prefix_sum"

# 测试用例和输出结果的目录
TEST_CASE_DIR="testcases"
GOLDEN_DIR="testcases"
MY_OUTPUT_DIR="my_outputs" # 存放程序输出的临时目录

# 正确性验证脚本
VERIFIER="../verify.py"

# --- Script Body ---

# 遇到任何错误立即退出
set -e

# 切换到项目目录
cd ${PROJECT_DIR}

# 1. 准备工作
echo "================================================="
echo "           Prefix Sum Performance Test           "
echo "================================================="
echo "Test started at $(date)"
echo ""

# 清理旧的输出
rm -rf ${MY_OUTPUT_DIR}
mkdir -p ${MY_OUTPUT_DIR}

# 2. 检查可执行文件是否存在
echo "STEP 1: Checking executable..."
if [ ! -f ./${EXECUTABLE} ]; then
    echo "Executable '${EXECUTABLE}' not found. Building..."
    make clean && make
    if [ ! -f ./${EXECUTABLE} ]; then
        echo "BUILD FAILED! Please check your code."
        exit 1
    fi
fi
echo "Executable '${EXECUTABLE}' found."
echo ""

# 3. 初始化计时器和计数器
TOTAL_TIME=0.0
PASSED_COUNT=0
TEST_COUNT=$(ls -1q ${TEST_CASE_DIR}/*.in | wc -l)

echo "STEP 2: Running test cases..."
echo "Found ${TEST_COUNT} test cases in ${TEST_CASE_DIR}"
echo "-------------------------------------------------"

# 4. 循环执行所有测试用例
for input_file in ${TEST_CASE_DIR}/*.in; do
    # 从输入文件名派生出基础名和对应的输出文件名
    base_name=$(basename "${input_file}" .in)
    golden_output_file="${GOLDEN_DIR}/${base_name}.out"
    my_output_file="${MY_OUTPUT_DIR}/${base_name}.myout"

    echo -n "Running test [${base_name}]... "

    # 检查标准答案文件是否存在
    if [ ! -f "${golden_output_file}" ]; then
        echo "SKIPPED. Reason: Golden output file ${golden_output_file} not found."
        continue
    fi
    
    # 运行并计时。注意：这里的调用方式是 ./prefix_sum <input_file>
    # 使用 /usr/bin/time 命令，并将时间输出 (stderr) 捕获到 EXEC_TIME 变量
    EXEC_TIME=$( { /usr/bin/time -f "%e" ./${EXECUTABLE} "${input_file}" > "${my_output_file}"; } 2>&1 )
    
    # 调用 Python 验证器进行比较
    if python3 ${VERIFIER} "${my_output_file}" "${golden_output_file}" >/dev/null 2>&1; then
        # 验证通过
        echo "PASS (${EXEC_TIME}s)"
        PASSED_COUNT=$((PASSED_COUNT + 1))
        # 使用 bc 工具进行浮点数加法
        TOTAL_TIME=$(echo "${TOTAL_TIME} + ${EXEC_TIME}" | bc -l)
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

# 5. 输出最终总结
echo "-------------------------------------------------"
echo "FINAL RESULT: ALL TESTS PASSED!"
echo ""
echo "    Passed cases: ${PASSED_COUNT} / ${TEST_COUNT}"
echo "    Total execution time: ${TOTAL_TIME} seconds"
echo "    Average time per test: $(echo "scale=4; ${TOTAL_TIME} / ${TEST_COUNT}" | bc -l) seconds"
echo ""

# 输出详细的性能分析
echo "PERFORMANCE ANALYSIS:"
echo "- Small tests (1-5): Fast processing"
echo "- Medium tests (6-9): Moderate complexity"
echo "- Large test (10): $(wc -c < ${TEST_CASE_DIR}/10.in) bytes input ($(head -1 ${TEST_CASE_DIR}/10.in) elements)"
echo ""
echo "Test finished at $(date)"
echo "================================================="

# 清理临时文件
echo ""
echo "Cleaning up temporary files..."
rm -rf ${MY_OUTPUT_DIR}
echo "Done."
