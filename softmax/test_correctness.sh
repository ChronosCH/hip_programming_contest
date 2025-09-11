#!/bin/bash

# 正确性测试脚本 - 验证所有 Softmax 实现的正确性

echo "=============================================="
echo "         Softmax 正确性验证测试"
echo "=============================================="
echo ""

# 确保代码已编译
echo "编译代码..."
make clean > /dev/null 2>&1
make > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "❌ 编译失败！"
    exit 1
fi
echo "✓ 编译成功"
echo ""

# 测试用例目录
TEST_DIR="testcases"
TEMP_DIR="temp_correctness_test"
mkdir -p $TEMP_DIR

# 检查测试用例是否存在
if [ ! -d "$TEST_DIR" ]; then
    echo "❌ 错误：测试用例目录 $TEST_DIR 不存在"
    exit 1
fi

echo "开始正确性测试..."
echo ""
echo "测试用例 | 数据大小 | CPU | GPU | GPU优化 | 状态"
echo "---------|----------|-----|-----|---------|------"

total_tests=0
passed_tests=0
failed_tests=0

# 遍历所有测试用例
for input_file in $TEST_DIR/*.in; do
    if [ ! -f "$input_file" ]; then
        continue
    fi
    
    # 获取测试用例名称
    base_name=$(basename "$input_file" .in)
    golden_file="$TEST_DIR/${base_name}.out"
    cpu_output="$TEMP_DIR/${base_name}_cpu.out"
    gpu_output="$TEMP_DIR/${base_name}_gpu.out"
    gpu_opt_output="$TEMP_DIR/${base_name}_gpu_opt.out"
    
    # 检查是否有对应的标准答案
    if [ ! -f "$golden_file" ]; then
        continue
    fi
    
    # 获取数据大小
    data_size=$(head -1 "$input_file")
    
    # 运行所有版本
    ./softmax_serial "$input_file" > "$cpu_output" 2>/dev/null
    ./softmax "$input_file" > "$gpu_output" 2>/dev/null
    ./softmax_optimized "$input_file" > "$gpu_opt_output" 2>/dev/null
    
    # 验证正确性
    cpu_correct="❌"
    gpu_correct="❌"
    gpu_opt_correct="❌"
    
    if python3 verify.py "$cpu_output" "$golden_file" >/dev/null 2>&1; then
        cpu_correct="✓"
    fi
    
    if python3 verify.py "$gpu_output" "$golden_file" >/dev/null 2>&1; then
        gpu_correct="✓"
    fi
    
    if python3 verify.py "$gpu_opt_output" "$golden_file" >/dev/null 2>&1; then
        gpu_opt_correct="✓"
    fi
    
    # 格式化数据大小显示
    if [ "$data_size" -ge 1000000 ]; then
        size_display="${data_size:0:-6}M"
    elif [ "$data_size" -ge 1000 ]; then
        size_display="${data_size:0:-3}K"
    else
        size_display="$data_size"
    fi
    
    # 判断测试状态
    if [ "$cpu_correct" = "✓" ] && [ "$gpu_correct" = "✓" ] && [ "$gpu_opt_correct" = "✓" ]; then
        status="✓ 通过"
        passed_tests=$((passed_tests + 1))
    else
        status="❌ 失败"
        failed_tests=$((failed_tests + 1))
    fi
    
    # 格式化输出
    printf "%-8s | %8s | %3s | %3s | %7s | %s\n" \
           "$base_name" "$size_display" "$cpu_correct" "$gpu_correct" "$gpu_opt_correct" "$status"
    
    total_tests=$((total_tests + 1))
done

echo "---------|----------|-----|-----|---------|------"

# 输出测试总结
echo ""
echo "测试总结："
echo "- 总测试用例: $total_tests"
echo "- 通过测试: $passed_tests"
echo "- 失败测试: $failed_tests"

if [ $failed_tests -eq 0 ]; then
    echo "🎉 所有测试用例都通过了！"
    echo ""
    echo "✓ CPU 串行实现: 正确"
    echo "✓ GPU 并行实现: 正确"  
    echo "✓ GPU 优化实现: 正确"
    echo ""
    echo "所有实现都满足数值精度要求："
    echo "- 相对容忍度: 1e-5"
    echo "- 绝对容忍度: 1e-6"
else
    echo "⚠ 有 $failed_tests 个测试用例失败"
    echo ""
    echo "请检查失败的实现并修复问题。"
fi

# 清理临时文件
rm -rf $TEMP_DIR

echo ""
echo "正确性测试完成！"

# 返回适当的退出码
if [ $failed_tests -eq 0 ]; then
    exit 0
else
    exit 1
fi
