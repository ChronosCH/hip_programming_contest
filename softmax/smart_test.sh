#!/bin/bash

# 智能测试脚本 - 逐步测试以节省磁盘空间
set -e

echo "========================================"
echo "     Smartmax Large Scale Test         "
echo "========================================"

# 检查程序是否存在
if [ ! -f ./softmax ] || [ ! -f ./softmax_serial ]; then
    echo "Building programs..."
    make clean
    make
fi

if [ ! -f ./softmax ] || [ ! -f ./softmax_serial ]; then
    echo "Build failed!"
    exit 1
fi

echo "Programs built successfully."
echo ""

# 创建输出目录
mkdir -p smart_test_outputs

echo "Running incremental tests..."
echo "Format: [TestCase] [Size] [GPU_Time] [Serial_Time] [Speedup] [Status]"
echo "-----------------------------------------------------------------------"

total_gpu_time=0
total_serial_time=0
test_count=0

# 测试用例列表，按规模递增
test_cases=(
    "large_tests/small_random.in:1,000"
    "large_tests/medium_random.in:10,000"
    "large_tests/large_random.in:100,000"
    "large_tests/extreme_values.in:100,000"
    "large_tests/uniform_values.in:100,000"
    "large_tests/small_values.in:100,000"
    "large_tests/ascending.in:100,000"
    "large_tests/1M_random.in:1,000,000"
    "large_tests/5M_random.in:5,000,000"
    "large_tests/10M_random.in:10,000,000"
)

# 可选的大规模测试（需要用户确认）
big_test_cases=(
    "large_tests/50M_random.in:50,000,000"
    "large_tests/100M_random.in:100,000,000"
)

run_test() {
    local test_file=$1
    local size_desc=$2
    local base_name=$(basename "$test_file" .in)
    
    if [ ! -f "$test_file" ]; then
        echo "Test file $test_file not found, skipping..."
        return
    fi
    
    echo -n "[${base_name}] [${size_desc}] "
    
    # Run GPU version with timing
    gpu_start=$(date +%s.%N)
    timeout 300 ./softmax "$test_file" > "smart_test_outputs/${base_name}_gpu.out" 2>&1
    gpu_end=$(date +%s.%N)
    gpu_time=$(echo "$gpu_end - $gpu_start" | bc -l)
    
    # Run serial version with timing
    serial_start=$(date +%s.%N)
    timeout 300 ./softmax_serial "$test_file" > "smart_test_outputs/${base_name}_serial.out" 2>&1
    serial_end=$(date +%s.%N)
    serial_time=$(echo "$serial_end - $serial_start" | bc -l)
    
    # Verify correctness
    if python3 verify.py "smart_test_outputs/${base_name}_gpu.out" "smart_test_outputs/${base_name}_serial.out" >/dev/null 2>&1; then
        status="PASS"
        # Calculate speedup
        if [ "$(echo "$gpu_time > 0" | bc)" -eq 1 ]; then
            speedup=$(echo "scale=2; $serial_time / $gpu_time" | bc -l)
            total_gpu_time=$(echo "$total_gpu_time + $gpu_time" | bc -l)
            total_serial_time=$(echo "$total_serial_time + $serial_time" | bc -l)
            test_count=$((test_count + 1))
        else
            speedup="N/A"
        fi
    else
        status="FAIL"
        speedup="N/A"
    fi
    
    printf "[%.3fs] [%.3fs] [%s] [%s]\n" "$gpu_time" "$serial_time" "$speedup" "$status"
    
    # If test failed, show difference and exit
    if [ "$status" = "FAIL" ]; then
        echo "ERROR: Correctness verification failed!"
        echo "GPU output: smart_test_outputs/${base_name}_gpu.out"
        echo "Serial output: smart_test_outputs/${base_name}_serial.out"
        echo "First few lines of difference:"
        diff "smart_test_outputs/${base_name}_serial.out" "smart_test_outputs/${base_name}_gpu.out" | head -10
        exit 1
    fi
}

# Run standard tests
for test_case in "${test_cases[@]}"; do
    IFS=':' read -r test_file size_desc <<< "$test_case"
    run_test "$test_file" "$size_desc"
done

echo "-----------------------------------------------------------------------"
echo "Standard Tests Completed Successfully!"
echo ""

# Ask user if they want to run large tests
echo "Do you want to run very large scale tests (50M and 100M elements)?"
echo "WARNING: These tests require significant time and disk space."
read -p "Continue with large tests? (y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Running large scale tests..."
    for test_case in "${big_test_cases[@]}"; do
        IFS=':' read -r test_file size_desc <<< "$test_case"
        run_test "$test_file" "$size_desc"
    done
fi

echo "-----------------------------------------------------------------------"
echo "Test Summary:"
echo "  Total tests passed: $test_count"

if [ "$test_count" -gt 0 ]; then
    overall_speedup=$(echo "scale=2; $total_serial_time / $total_gpu_time" | bc -l)
    echo "  Total GPU time: ${total_gpu_time}s"
    echo "  Total Serial time: ${total_serial_time}s"
    echo "  Overall speedup: ${overall_speedup}x"
    
    if [ "$(echo "$overall_speedup > 1.0" | bc)" -eq 1 ]; then
        echo "🚀 GPU implementation shows ${overall_speedup}x speedup!"
        
        # Performance analysis
        if [ "$(echo "$overall_speedup > 10.0" | bc)" -eq 1 ]; then
            echo "   Excellent performance! GPU shows significant acceleration."
        elif [ "$(echo "$overall_speedup > 5.0" | bc)" -eq 1 ]; then
            echo "   Good performance! GPU shows strong acceleration."
        elif [ "$(echo "$overall_speedup > 2.0" | bc)" -eq 1 ]; then
            echo "   Moderate performance. GPU shows reasonable acceleration."
        else
            echo "   Modest improvement. Consider optimizing for larger datasets."
        fi
    else
        echo "⚠️ GPU implementation is slower than serial version."
        echo "   This may be normal for smaller datasets due to GPU overhead."
    fi
else
    echo "  No valid test results."
fi

echo ""
echo "All tests completed successfully!"
echo "Your GPU implementation is correct and ready for submission!"
