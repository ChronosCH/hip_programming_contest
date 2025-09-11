#!/bin/bash

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


# Test case: small_random (N=1,000, type=random)
if [ -f "large_tests/small_random.in" ]; then
    echo -n "[small_random] [1,000] "
    
    # Run GPU version with timing
    gpu_start=$(date +%s.%N)
    timeout 300 ./softmax "large_tests/small_random.in" > "large_test_outputs/gpu/small_random.out" 2>/dev/null
    gpu_end=$(date +%s.%N)
    gpu_time=$(echo "$gpu_end - $gpu_start" | bc)
    
    # Run serial version with timing
    serial_start=$(date +%s.%N)
    timeout 300 ./softmax_serial "large_tests/small_random.in" > "large_test_outputs/serial/small_random.out" 2>/dev/null
    serial_end=$(date +%s.%N)
    serial_time=$(echo "$serial_end - $serial_start" | bc)
    
    # Verify correctness
    if python3 verify.py "large_test_outputs/gpu/small_random.out" "large_test_outputs/serial/small_random.out" >/dev/null 2>&1; then
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
    
    printf "[%.3fs] [%.3fs] [%s] [%s]\n" "$gpu_time" "$serial_time" "$speedup" "$status"
    
    # If test failed, show difference
    if [ "$status" = "FAIL" ]; then
        echo "ERROR: Correctness verification failed!"
        echo "GPU output: large_test_outputs/gpu/small_random.out"
        echo "Serial output: large_test_outputs/serial/small_random.out"
        exit 1
    fi
else
    echo "Test file large_tests/small_random.in not found, skipping..."
fi

# Test case: medium_random (N=10,000, type=random)
if [ -f "large_tests/medium_random.in" ]; then
    echo -n "[medium_random] [10,000] "
    
    # Run GPU version with timing
    gpu_start=$(date +%s.%N)
    timeout 300 ./softmax "large_tests/medium_random.in" > "large_test_outputs/gpu/medium_random.out" 2>/dev/null
    gpu_end=$(date +%s.%N)
    gpu_time=$(echo "$gpu_end - $gpu_start" | bc)
    
    # Run serial version with timing
    serial_start=$(date +%s.%N)
    timeout 300 ./softmax_serial "large_tests/medium_random.in" > "large_test_outputs/serial/medium_random.out" 2>/dev/null
    serial_end=$(date +%s.%N)
    serial_time=$(echo "$serial_end - $serial_start" | bc)
    
    # Verify correctness
    if python3 verify.py "large_test_outputs/gpu/medium_random.out" "large_test_outputs/serial/medium_random.out" >/dev/null 2>&1; then
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
    
    printf "[%.3fs] [%.3fs] [%s] [%s]\n" "$gpu_time" "$serial_time" "$speedup" "$status"
    
    # If test failed, show difference
    if [ "$status" = "FAIL" ]; then
        echo "ERROR: Correctness verification failed!"
        echo "GPU output: large_test_outputs/gpu/medium_random.out"
        echo "Serial output: large_test_outputs/serial/medium_random.out"
        exit 1
    fi
else
    echo "Test file large_tests/medium_random.in not found, skipping..."
fi

# Test case: large_random (N=100,000, type=random)
if [ -f "large_tests/large_random.in" ]; then
    echo -n "[large_random] [100,000] "
    
    # Run GPU version with timing
    gpu_start=$(date +%s.%N)
    timeout 300 ./softmax "large_tests/large_random.in" > "large_test_outputs/gpu/large_random.out" 2>/dev/null
    gpu_end=$(date +%s.%N)
    gpu_time=$(echo "$gpu_end - $gpu_start" | bc)
    
    # Run serial version with timing
    serial_start=$(date +%s.%N)
    timeout 300 ./softmax_serial "large_tests/large_random.in" > "large_test_outputs/serial/large_random.out" 2>/dev/null
    serial_end=$(date +%s.%N)
    serial_time=$(echo "$serial_end - $serial_start" | bc)
    
    # Verify correctness
    if python3 verify.py "large_test_outputs/gpu/large_random.out" "large_test_outputs/serial/large_random.out" >/dev/null 2>&1; then
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
    
    printf "[%.3fs] [%.3fs] [%s] [%s]\n" "$gpu_time" "$serial_time" "$speedup" "$status"
    
    # If test failed, show difference
    if [ "$status" = "FAIL" ]; then
        echo "ERROR: Correctness verification failed!"
        echo "GPU output: large_test_outputs/gpu/large_random.out"
        echo "Serial output: large_test_outputs/serial/large_random.out"
        exit 1
    fi
else
    echo "Test file large_tests/large_random.in not found, skipping..."
fi

# Test case: 1M_random (N=1,000,000, type=random)
if [ -f "large_tests/1M_random.in" ]; then
    echo -n "[1M_random] [1,000,000] "
    
    # Run GPU version with timing
    gpu_start=$(date +%s.%N)
    timeout 300 ./softmax "large_tests/1M_random.in" > "large_test_outputs/gpu/1M_random.out" 2>/dev/null
    gpu_end=$(date +%s.%N)
    gpu_time=$(echo "$gpu_end - $gpu_start" | bc)
    
    # Run serial version with timing
    serial_start=$(date +%s.%N)
    timeout 300 ./softmax_serial "large_tests/1M_random.in" > "large_test_outputs/serial/1M_random.out" 2>/dev/null
    serial_end=$(date +%s.%N)
    serial_time=$(echo "$serial_end - $serial_start" | bc)
    
    # Verify correctness
    if python3 verify.py "large_test_outputs/gpu/1M_random.out" "large_test_outputs/serial/1M_random.out" >/dev/null 2>&1; then
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
    
    printf "[%.3fs] [%.3fs] [%s] [%s]\n" "$gpu_time" "$serial_time" "$speedup" "$status"
    
    # If test failed, show difference
    if [ "$status" = "FAIL" ]; then
        echo "ERROR: Correctness verification failed!"
        echo "GPU output: large_test_outputs/gpu/1M_random.out"
        echo "Serial output: large_test_outputs/serial/1M_random.out"
        exit 1
    fi
else
    echo "Test file large_tests/1M_random.in not found, skipping..."
fi

# Test case: 5M_random (N=5,000,000, type=random)
if [ -f "large_tests/5M_random.in" ]; then
    echo -n "[5M_random] [5,000,000] "
    
    # Run GPU version with timing
    gpu_start=$(date +%s.%N)
    timeout 300 ./softmax "large_tests/5M_random.in" > "large_test_outputs/gpu/5M_random.out" 2>/dev/null
    gpu_end=$(date +%s.%N)
    gpu_time=$(echo "$gpu_end - $gpu_start" | bc)
    
    # Run serial version with timing
    serial_start=$(date +%s.%N)
    timeout 300 ./softmax_serial "large_tests/5M_random.in" > "large_test_outputs/serial/5M_random.out" 2>/dev/null
    serial_end=$(date +%s.%N)
    serial_time=$(echo "$serial_end - $serial_start" | bc)
    
    # Verify correctness
    if python3 verify.py "large_test_outputs/gpu/5M_random.out" "large_test_outputs/serial/5M_random.out" >/dev/null 2>&1; then
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
    
    printf "[%.3fs] [%.3fs] [%s] [%s]\n" "$gpu_time" "$serial_time" "$speedup" "$status"
    
    # If test failed, show difference
    if [ "$status" = "FAIL" ]; then
        echo "ERROR: Correctness verification failed!"
        echo "GPU output: large_test_outputs/gpu/5M_random.out"
        echo "Serial output: large_test_outputs/serial/5M_random.out"
        exit 1
    fi
else
    echo "Test file large_tests/5M_random.in not found, skipping..."
fi

# Test case: 10M_random (N=10,000,000, type=random)
if [ -f "large_tests/10M_random.in" ]; then
    echo -n "[10M_random] [10,000,000] "
    
    # Run GPU version with timing
    gpu_start=$(date +%s.%N)
    timeout 300 ./softmax "large_tests/10M_random.in" > "large_test_outputs/gpu/10M_random.out" 2>/dev/null
    gpu_end=$(date +%s.%N)
    gpu_time=$(echo "$gpu_end - $gpu_start" | bc)
    
    # Run serial version with timing
    serial_start=$(date +%s.%N)
    timeout 300 ./softmax_serial "large_tests/10M_random.in" > "large_test_outputs/serial/10M_random.out" 2>/dev/null
    serial_end=$(date +%s.%N)
    serial_time=$(echo "$serial_end - $serial_start" | bc)
    
    # Verify correctness
    if python3 verify.py "large_test_outputs/gpu/10M_random.out" "large_test_outputs/serial/10M_random.out" >/dev/null 2>&1; then
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
    
    printf "[%.3fs] [%.3fs] [%s] [%s]\n" "$gpu_time" "$serial_time" "$speedup" "$status"
    
    # If test failed, show difference
    if [ "$status" = "FAIL" ]; then
        echo "ERROR: Correctness verification failed!"
        echo "GPU output: large_test_outputs/gpu/10M_random.out"
        echo "Serial output: large_test_outputs/serial/10M_random.out"
        exit 1
    fi
else
    echo "Test file large_tests/10M_random.in not found, skipping..."
fi

# Test case: 50M_random (N=50,000,000, type=random)
if [ -f "large_tests/50M_random.in" ]; then
    echo -n "[50M_random] [50,000,000] "
    
    # Run GPU version with timing
    gpu_start=$(date +%s.%N)
    timeout 300 ./softmax "large_tests/50M_random.in" > "large_test_outputs/gpu/50M_random.out" 2>/dev/null
    gpu_end=$(date +%s.%N)
    gpu_time=$(echo "$gpu_end - $gpu_start" | bc)
    
    # Run serial version with timing
    serial_start=$(date +%s.%N)
    timeout 300 ./softmax_serial "large_tests/50M_random.in" > "large_test_outputs/serial/50M_random.out" 2>/dev/null
    serial_end=$(date +%s.%N)
    serial_time=$(echo "$serial_end - $serial_start" | bc)
    
    # Verify correctness
    if python3 verify.py "large_test_outputs/gpu/50M_random.out" "large_test_outputs/serial/50M_random.out" >/dev/null 2>&1; then
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
    
    printf "[%.3fs] [%.3fs] [%s] [%s]\n" "$gpu_time" "$serial_time" "$speedup" "$status"
    
    # If test failed, show difference
    if [ "$status" = "FAIL" ]; then
        echo "ERROR: Correctness verification failed!"
        echo "GPU output: large_test_outputs/gpu/50M_random.out"
        echo "Serial output: large_test_outputs/serial/50M_random.out"
        exit 1
    fi
else
    echo "Test file large_tests/50M_random.in not found, skipping..."
fi

# Test case: 100M_random (N=100,000,000, type=random)
if [ -f "large_tests/100M_random.in" ]; then
    echo -n "[100M_random] [100,000,000] "
    
    # Run GPU version with timing
    gpu_start=$(date +%s.%N)
    timeout 300 ./softmax "large_tests/100M_random.in" > "large_test_outputs/gpu/100M_random.out" 2>/dev/null
    gpu_end=$(date +%s.%N)
    gpu_time=$(echo "$gpu_end - $gpu_start" | bc)
    
    # Run serial version with timing
    serial_start=$(date +%s.%N)
    timeout 300 ./softmax_serial "large_tests/100M_random.in" > "large_test_outputs/serial/100M_random.out" 2>/dev/null
    serial_end=$(date +%s.%N)
    serial_time=$(echo "$serial_end - $serial_start" | bc)
    
    # Verify correctness
    if python3 verify.py "large_test_outputs/gpu/100M_random.out" "large_test_outputs/serial/100M_random.out" >/dev/null 2>&1; then
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
    
    printf "[%.3fs] [%.3fs] [%s] [%s]\n" "$gpu_time" "$serial_time" "$speedup" "$status"
    
    # If test failed, show difference
    if [ "$status" = "FAIL" ]; then
        echo "ERROR: Correctness verification failed!"
        echo "GPU output: large_test_outputs/gpu/100M_random.out"
        echo "Serial output: large_test_outputs/serial/100M_random.out"
        exit 1
    fi
else
    echo "Test file large_tests/100M_random.in not found, skipping..."
fi

# Test case: extreme_values (N=100,000, type=extreme)
if [ -f "large_tests/extreme_values.in" ]; then
    echo -n "[extreme_values] [100,000] "
    
    # Run GPU version with timing
    gpu_start=$(date +%s.%N)
    timeout 300 ./softmax "large_tests/extreme_values.in" > "large_test_outputs/gpu/extreme_values.out" 2>/dev/null
    gpu_end=$(date +%s.%N)
    gpu_time=$(echo "$gpu_end - $gpu_start" | bc)
    
    # Run serial version with timing
    serial_start=$(date +%s.%N)
    timeout 300 ./softmax_serial "large_tests/extreme_values.in" > "large_test_outputs/serial/extreme_values.out" 2>/dev/null
    serial_end=$(date +%s.%N)
    serial_time=$(echo "$serial_end - $serial_start" | bc)
    
    # Verify correctness
    if python3 verify.py "large_test_outputs/gpu/extreme_values.out" "large_test_outputs/serial/extreme_values.out" >/dev/null 2>&1; then
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
    
    printf "[%.3fs] [%.3fs] [%s] [%s]\n" "$gpu_time" "$serial_time" "$speedup" "$status"
    
    # If test failed, show difference
    if [ "$status" = "FAIL" ]; then
        echo "ERROR: Correctness verification failed!"
        echo "GPU output: large_test_outputs/gpu/extreme_values.out"
        echo "Serial output: large_test_outputs/serial/extreme_values.out"
        exit 1
    fi
else
    echo "Test file large_tests/extreme_values.in not found, skipping..."
fi

# Test case: uniform_values (N=100,000, type=uniform)
if [ -f "large_tests/uniform_values.in" ]; then
    echo -n "[uniform_values] [100,000] "
    
    # Run GPU version with timing
    gpu_start=$(date +%s.%N)
    timeout 300 ./softmax "large_tests/uniform_values.in" > "large_test_outputs/gpu/uniform_values.out" 2>/dev/null
    gpu_end=$(date +%s.%N)
    gpu_time=$(echo "$gpu_end - $gpu_start" | bc)
    
    # Run serial version with timing
    serial_start=$(date +%s.%N)
    timeout 300 ./softmax_serial "large_tests/uniform_values.in" > "large_test_outputs/serial/uniform_values.out" 2>/dev/null
    serial_end=$(date +%s.%N)
    serial_time=$(echo "$serial_end - $serial_start" | bc)
    
    # Verify correctness
    if python3 verify.py "large_test_outputs/gpu/uniform_values.out" "large_test_outputs/serial/uniform_values.out" >/dev/null 2>&1; then
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
    
    printf "[%.3fs] [%.3fs] [%s] [%s]\n" "$gpu_time" "$serial_time" "$speedup" "$status"
    
    # If test failed, show difference
    if [ "$status" = "FAIL" ]; then
        echo "ERROR: Correctness verification failed!"
        echo "GPU output: large_test_outputs/gpu/uniform_values.out"
        echo "Serial output: large_test_outputs/serial/uniform_values.out"
        exit 1
    fi
else
    echo "Test file large_tests/uniform_values.in not found, skipping..."
fi

# Test case: small_values (N=100,000, type=small_values)
if [ -f "large_tests/small_values.in" ]; then
    echo -n "[small_values] [100,000] "
    
    # Run GPU version with timing
    gpu_start=$(date +%s.%N)
    timeout 300 ./softmax "large_tests/small_values.in" > "large_test_outputs/gpu/small_values.out" 2>/dev/null
    gpu_end=$(date +%s.%N)
    gpu_time=$(echo "$gpu_end - $gpu_start" | bc)
    
    # Run serial version with timing
    serial_start=$(date +%s.%N)
    timeout 300 ./softmax_serial "large_tests/small_values.in" > "large_test_outputs/serial/small_values.out" 2>/dev/null
    serial_end=$(date +%s.%N)
    serial_time=$(echo "$serial_end - $serial_start" | bc)
    
    # Verify correctness
    if python3 verify.py "large_test_outputs/gpu/small_values.out" "large_test_outputs/serial/small_values.out" >/dev/null 2>&1; then
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
    
    printf "[%.3fs] [%.3fs] [%s] [%s]\n" "$gpu_time" "$serial_time" "$speedup" "$status"
    
    # If test failed, show difference
    if [ "$status" = "FAIL" ]; then
        echo "ERROR: Correctness verification failed!"
        echo "GPU output: large_test_outputs/gpu/small_values.out"
        echo "Serial output: large_test_outputs/serial/small_values.out"
        exit 1
    fi
else
    echo "Test file large_tests/small_values.in not found, skipping..."
fi

# Test case: ascending (N=100,000, type=ascending)
if [ -f "large_tests/ascending.in" ]; then
    echo -n "[ascending] [100,000] "
    
    # Run GPU version with timing
    gpu_start=$(date +%s.%N)
    timeout 300 ./softmax "large_tests/ascending.in" > "large_test_outputs/gpu/ascending.out" 2>/dev/null
    gpu_end=$(date +%s.%N)
    gpu_time=$(echo "$gpu_end - $gpu_start" | bc)
    
    # Run serial version with timing
    serial_start=$(date +%s.%N)
    timeout 300 ./softmax_serial "large_tests/ascending.in" > "large_test_outputs/serial/ascending.out" 2>/dev/null
    serial_end=$(date +%s.%N)
    serial_time=$(echo "$serial_end - $serial_start" | bc)
    
    # Verify correctness
    if python3 verify.py "large_test_outputs/gpu/ascending.out" "large_test_outputs/serial/ascending.out" >/dev/null 2>&1; then
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
    
    printf "[%.3fs] [%.3fs] [%s] [%s]\n" "$gpu_time" "$serial_time" "$speedup" "$status"
    
    # If test failed, show difference
    if [ "$status" = "FAIL" ]; then
        echo "ERROR: Correctness verification failed!"
        echo "GPU output: large_test_outputs/gpu/ascending.out"
        echo "Serial output: large_test_outputs/serial/ascending.out"
        exit 1
    fi
else
    echo "Test file large_tests/ascending.in not found, skipping..."
fi

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
