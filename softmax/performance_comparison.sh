#!/bin/bash

# 性能对比脚本 - Softmax GPU vs CPU
# 比较并行 GPU 实现与串行 CPU 实现的性能

echo "=============================================="
echo "      Softmax 性能对比测试"
echo "      GPU (HIP) vs CPU (串行)"
echo "=============================================="
echo ""

# 确保代码已编译
echo "编译代码..."
make clean
make
if [ $? -ne 0 ]; then
    echo "编译失败！"
    exit 1
fi
echo "编译成功"
echo ""

# 测试用例目录
TEST_DIR="testcases"
TEMP_DIR="temp_perf_test"
mkdir -p $TEMP_DIR

# 检查测试用例是否存在
if [ ! -d "$TEST_DIR" ]; then
    echo "错误：测试用例目录 $TEST_DIR 不存在"
    exit 1
fi

echo "开始性能测试..."
echo ""
echo "测试用例 | 数据大小 | GPU 时间(s) | CPU 时间(s) | 加速比 | 正确性"
echo "---------|----------|-------------|-------------|-------|--------"

total_gpu_time=0
total_cpu_time=0
test_count=0
large_scale_gpu_time=0
large_scale_cpu_time=0
large_scale_count=0

# 遍历所有测试用例
for input_file in $TEST_DIR/*.in; do
    if [ ! -f "$input_file" ]; then
        continue
    fi

    # 获取测试用例名称
    base_name=$(basename "$input_file" .in)
    golden_file="$TEST_DIR/${base_name}.out"
    gpu_output="$TEMP_DIR/${base_name}_gpu.out"
    cpu_output="$TEMP_DIR/${base_name}_cpu.out"

    # 检查是否有对应的标准答案
    if [ ! -f "$golden_file" ]; then
        continue
    fi

    # 获取数据大小
    data_size=$(head -1 "$input_file")

    # 测试 GPU 版本性能（多次运行取平均值，特别是大数据集）
    if [ "$data_size" -gt 10000 ]; then
        # 大数据集运行3次取平均
        gpu_times=""
        for run in {1..3}; do
            start_time=$(date +%s.%N)
            ./softmax "$input_file" > "$gpu_output" 2>/dev/null
            end_time=$(date +%s.%N)
            run_time=$(echo "$end_time - $start_time" | bc)
            gpu_times="$gpu_times $run_time"
        done
        gpu_time=$(echo "$gpu_times" | awk '{sum=0; for(i=1;i<=NF;i++) sum+=$i; print sum/NF}')
    else
        # 小数据集运行1次
        start_time=$(date +%s.%N)
        ./softmax "$input_file" > "$gpu_output" 2>/dev/null
        end_time=$(date +%s.%N)
        gpu_time=$(echo "$end_time - $start_time" | bc)
    fi

    # 测试 CPU 版本性能
    if [ "$data_size" -gt 10000 ]; then
        # 大数据集运行3次取平均
        cpu_times=""
        for run in {1..3}; do
            start_time=$(date +%s.%N)
            ./softmax_serial "$input_file" > "$cpu_output" 2>/dev/null
            end_time=$(date +%s.%N)
            run_time=$(echo "$end_time - $start_time" | bc)
            cpu_times="$cpu_times $run_time"
        done
        cpu_time=$(echo "$cpu_times" | awk '{sum=0; for(i=1;i<=NF;i++) sum+=$i; print sum/NF}')
    else
        # 小数据集运行1次
        start_time=$(date +%s.%N)
        ./softmax_serial "$input_file" > "$cpu_output" 2>/dev/null
        end_time=$(date +%s.%N)
        cpu_time=$(echo "$end_time - $start_time" | bc)
    fi

    # 计算加速比
    speedup=$(echo "scale=2; $cpu_time / $gpu_time" | bc)

    # 验证正确性
    gpu_correct="❌"
    cpu_correct="❌"

    if python3 verify.py "$gpu_output" "$golden_file" >/dev/null 2>&1; then
        gpu_correct="✓"
    fi

    if python3 verify.py "$cpu_output" "$golden_file" >/dev/null 2>&1; then
        cpu_correct="✓"
    fi

    # 格式化数据大小显示
    if [ "$data_size" -ge 1000000 ]; then
        size_display="${data_size:0:-6}M"
    elif [ "$data_size" -ge 1000 ]; then
        size_display="${data_size:0:-3}K"
    else
        size_display="$data_size"
    fi

    # 格式化输出
    printf "%-8s | %8s | %11.6f | %11.6f | %5.2fx | GPU:%s CPU:%s\n" \
           "$base_name" "$size_display" "$gpu_time" "$cpu_time" "$speedup" "$gpu_correct" "$cpu_correct"

    # 累加总时间
    total_gpu_time=$(echo "$total_gpu_time + $gpu_time" | bc)
    total_cpu_time=$(echo "$total_cpu_time + $cpu_time" | bc)
    test_count=$((test_count + 1))

    # 统计大规模数据的性能
    if [ "$data_size" -gt 10000 ]; then
        large_scale_gpu_time=$(echo "$large_scale_gpu_time + $gpu_time" | bc)
        large_scale_cpu_time=$(echo "$large_scale_cpu_time + $cpu_time" | bc)
        large_scale_count=$((large_scale_count + 1))
    fi
done

echo "---------|----------|-------------|-------------|-------|--------"

# 计算平均性能
if [ $test_count -gt 0 ]; then
    avg_gpu_time=$(echo "scale=6; $total_gpu_time / $test_count" | bc)
    avg_cpu_time=$(echo "scale=6; $total_cpu_time / $test_count" | bc)
    total_speedup=$(echo "scale=2; $total_cpu_time / $total_gpu_time" | bc)
    avg_speedup=$(echo "scale=2; $avg_cpu_time / $avg_gpu_time" | bc)

    printf "%-8s | %8s | %11.6f | %11.6f | %5.2fx | 平均值\n" \
           "平均" "ALL" "$avg_gpu_time" "$avg_cpu_time" "$avg_speedup"
    printf "%-8s | %8s | %11.6f | %11.6f | %5.2fx | 总计\n" \
           "总计" "ALL" "$total_gpu_time" "$total_cpu_time" "$total_speedup"
fi

# 计算大规模数据的性能
if [ $large_scale_count -gt 0 ]; then
    large_avg_gpu_time=$(echo "scale=6; $large_scale_gpu_time / $large_scale_count" | bc)
    large_avg_cpu_time=$(echo "scale=6; $large_scale_cpu_time / $large_scale_count" | bc)
    large_total_speedup=$(echo "scale=2; $large_scale_cpu_time / $large_scale_gpu_time" | bc)
    large_avg_speedup=$(echo "scale=2; $large_avg_cpu_time / $large_avg_gpu_time" | bc)

    printf "%-8s | %8s | %11.6f | %11.6f | %5.2fx | 大数据集\n" \
           "大数据" ">10K" "$large_avg_gpu_time" "$large_avg_cpu_time" "$large_avg_speedup"
fi

echo ""
echo "性能分析总结："
echo "- 测试用例数量: $test_count"
echo "- GPU 总执行时间: ${total_gpu_time}s"
echo "- CPU 总执行时间: ${total_cpu_time}s"
echo "- 总体加速比: ${total_speedup}x"

if [ $test_count -gt 0 ]; then
    echo "- 平均 GPU 执行时间: ${avg_gpu_time}s"
    echo "- 平均 CPU 执行时间: ${avg_cpu_time}s"
    echo "- 平均加速比: ${avg_speedup}x"
fi

if [ $large_scale_count -gt 0 ]; then
    echo ""
    echo "大规模数据集性能 (>10K 元素):"
    echo "- 大数据集数量: $large_scale_count"
    echo "- 大数据集 GPU 平均时间: ${large_avg_gpu_time}s"
    echo "- 大数据集 CPU 平均时间: ${large_avg_cpu_time}s"
    echo "- 大数据集平均加速比: ${large_avg_speedup}x"
fi

echo ""

# 性能分析
if [ $large_scale_count -gt 0 ] && (( $(echo "$large_avg_speedup > 1" | bc -l) )); then
    echo "✓ 在大规模数据集上，GPU 实现比 CPU 实现快 ${large_avg_speedup}x"
elif (( $(echo "$total_speedup > 1" | bc -l) )); then
    echo "✓ GPU 实现比 CPU 实现快 ${total_speedup}x"
else
    echo "⚠ GPU 实现比 CPU 实现慢，分析："
    echo "  - 小数据集 (≤10K): GPU 启动开销 > 计算收益"
    echo "  - 内存传输开销在小数据集上占主导地位"
    if [ $large_scale_count -gt 0 ]; then
        echo "  - 大数据集加速比: ${large_avg_speedup}x"
        if (( $(echo "$large_avg_speedup > 1" | bc -l) )); then
            echo "  ✓ 大数据集上 GPU 显示出优势"
        else
            echo "  - 算法实现可能需要进一步优化"
        fi
    fi
fi

echo ""
echo "注意："
echo "- 小规模数据集可能无法充分体现 GPU 并行优势"
echo "- GPU 实现包含内存传输开销"
echo "- 实际加速比取决于数据大小和硬件特性"
echo ""

# 清理临时文件
rm -rf $TEMP_DIR

echo "性能测试完成！"
