#!/usr/bin/env python3
import numpy as np
import os
import random
import sys

def generate_test_case(N, filename_prefix, test_type="random"):
    """
    生成测试用例
    N: 数组大小
    filename_prefix: 文件名前缀
    test_type: 测试类型 (random, extreme, uniform, etc.)
    """
    input_filename = f"{filename_prefix}.in"
    
    print(f"Generating test case: N={N:,}, type={test_type}")
    
    if test_type == "random":
        # 随机浮点数，范围在-10到10之间
        data = np.random.uniform(-10.0, 10.0, N).astype(np.float32)
    elif test_type == "extreme":
        # 包含极值的数据，测试数值稳定性
        data = np.random.uniform(-100.0, 100.0, N).astype(np.float32)
        # 添加一些极值
        if N > 100:
            data[0] = 1000.0  # 大正值
            data[1] = -1000.0  # 大负值
            data[2] = 0.0     # 零值
    elif test_type == "uniform":
        # 相同的值，测试边界情况
        data = np.full(N, 1.0, dtype=np.float32)
    elif test_type == "ascending":
        # 递增序列
        data = np.linspace(-5.0, 5.0, N).astype(np.float32)
    elif test_type == "small_values":
        # 小数值，接近零
        data = np.random.uniform(-1e-3, 1e-3, N).astype(np.float32)
    else:
        data = np.random.uniform(-5.0, 5.0, N).astype(np.float32)
    
    # 写入文件
    with open(input_filename, 'w') as f:
        f.write(f"{N}\n")
        # 分批写入，避免内存问题
        batch_size = 10000
        for i in range(0, N, batch_size):
            end_idx = min(i + batch_size, N)
            batch_data = data[i:end_idx]
            f.write(" ".join(f"{x:.6f}" for x in batch_data))
            if end_idx < N:
                f.write(" ")
        f.write(" \n")
    
    print(f"Generated {input_filename}")
    return input_filename

def main():
    # 创建测试数据目录
    test_dir = "large_tests"
    os.makedirs(test_dir, exist_ok=True)
    
    # 定义测试用例规模和类型
    test_cases = [
        # 小规模测试 - 验证正确性
        (1000, "small_random", "random"),
        (10000, "medium_random", "random"),
        (100000, "large_random", "random"),
        
        # 中等规模测试
        (1000000, "1M_random", "random"),
        (5000000, "5M_random", "random"),
        (10000000, "10M_random", "random"),
        
        # 大规模测试 - 测试性能
        (50000000, "50M_random", "random"),
        (100000000, "100M_random", "random"),
        
        # 特殊情况测试
        (100000, "extreme_values", "extreme"),
        (100000, "uniform_values", "uniform"),
        (100000, "small_values", "small_values"),
        (100000, "ascending", "ascending"),
    ]
    
    generated_files = []
    
    for N, name, test_type in test_cases:
        try:
            filename_prefix = os.path.join(test_dir, name)
            input_file = generate_test_case(N, filename_prefix, test_type)
            generated_files.append((input_file, N, test_type))
        except Exception as e:
            print(f"Error generating test case {name}: {e}")
            continue
    
    # 生成测试脚本
    with open("run_large_tests.sh", 'w') as f:
        f.write("""#!/bin/bash

# 大规模测试脚本
set -e

echo "========================================"
echo "        Large Scale Softmax Test       "
echo "========================================"

# 编译程序
echo "Building programs..."
make clean
make

if [ ! -f ./softmax ] || [ ! -f ./softmax_serial ]; then
    echo "Build failed!"
    exit 1
fi

echo "Programs built successfully."
echo ""

# 创建输出目录
mkdir -p large_test_outputs/gpu
mkdir -p large_test_outputs/serial

echo "Running large scale tests..."
echo "Format: [TestCase] [Size] [GPU_Time] [Serial_Time] [Speedup] [Status]"
echo "-----------------------------------------------------------------------"

total_gpu_time=0
total_serial_time=0
test_count=0

""")
        
        for input_file, N, test_type in generated_files:
            base_name = os.path.basename(input_file).replace('.in', '')
            f.write(f"""
# Test case: {base_name} (N={N:,}, type={test_type})
if [ -f "{input_file}" ]; then
    echo -n "[{base_name}] [{N:,}] "
    
    # Run GPU version with timing
    gpu_start=$(date +%s.%N)
    timeout 300 ./softmax "{input_file}" > "large_test_outputs/gpu/{base_name}.out" 2>/dev/null
    gpu_end=$(date +%s.%N)
    gpu_time=$(echo "$gpu_end - $gpu_start" | bc)
    
    # Run serial version with timing
    serial_start=$(date +%s.%N)
    timeout 300 ./softmax_serial "{input_file}" > "large_test_outputs/serial/{base_name}.out" 2>/dev/null
    serial_end=$(date +%s.%N)
    serial_time=$(echo "$serial_end - $serial_start" | bc)
    
    # Verify correctness
    if python3 verify.py "large_test_outputs/gpu/{base_name}.out" "large_test_outputs/serial/{base_name}.out" >/dev/null 2>&1; then
        status="PASS"
        # Calculate speedup
        if [ "$(echo "$gpu_time > 0" | bc)" -eq 1 ]; then
            speedup=$(echo "scale=2; $serial_time / $gpu_time" | bc)
            total_gpu_time=$(echo "$total_gpu_time + $gpu_time" | bc)
            total_serial_time=$(echo "$total_serial_time + $serial_time" | bc)
            test_count=$((test_count + 1))
        else
            speedup="N/A"
        fi
    else
        status="FAIL"
        speedup="N/A"
    fi
    
    printf "[%.3fs] [%.3fs] [%s] [%s]\\n" "$gpu_time" "$serial_time" "$speedup" "$status"
    
    # If test failed, show difference
    if [ "$status" = "FAIL" ]; then
        echo "ERROR: Correctness verification failed!"
        echo "GPU output: large_test_outputs/gpu/{base_name}.out"
        echo "Serial output: large_test_outputs/serial/{base_name}.out"
        exit 1
    fi
else
    echo "Test file {input_file} not found, skipping..."
fi
""")
        
        f.write("""
echo "-----------------------------------------------------------------------"
echo "Test Summary:"
echo "  Total tests passed: $test_count"

if [ "$test_count" -gt 0 ]; then
    overall_speedup=$(echo "scale=2; $total_serial_time / $total_gpu_time" | bc)
    echo "  Total GPU time: ${total_gpu_time}s"
    echo "  Total Serial time: ${total_serial_time}s"
    echo "  Overall speedup: ${overall_speedup}x"
    
    if [ "$(echo "$overall_speedup > 1.0" | bc)" -eq 1 ]; then
        echo "🚀 GPU implementation shows ${overall_speedup}x speedup!"
    else
        echo "⚠️ GPU implementation is slower than serial version."
    fi
else
    echo "  No valid test results."
fi

echo ""
echo "All tests completed successfully!"
""")
    
    # 使测试脚本可执行
    os.chmod("run_large_tests.sh", 0o755)
    
    print(f"\nGenerated {len(generated_files)} test cases in '{test_dir}/' directory")
    print("Created test script: run_large_tests.sh")
    print("\nTo run the tests:")
    print("  ./run_large_tests.sh")
    print("\nNote: Large tests may take significant time and disk space.")
    print("Consider removing some existing large files if disk space is limited.")

if __name__ == "__main__":
    main()
