#!/bin/bash

# APSP Performance Comparison Script
# Compares serial vs parallel (GPU) implementation performance

echo "=== APSP Performance Comparison ==="
echo "Comparing Serial CPU vs Parallel GPU implementations"
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if executables exist
if [ ! -f "apsp" ] || [ ! -f "apsp_serial" ]; then
    echo -e "${RED}Error: Executables not found. Please run 'make' first.${NC}"
    exit 1
fi

# Test cases to run
TEST_CASES=(1 2 3 4 5 6 7 8 9 10)

echo -e "${BLUE}Building executables...${NC}"
make clean && make
if [ $? -ne 0 ]; then
    echo -e "${RED}Build failed!${NC}"
    exit 1
fi

echo -e "${GREEN}Build successful!${NC}"
echo

# Function to run performance test
run_performance_test() {
    local test_case=$1
    local input_file="testcases/${test_case}.in"
    local expected_output="testcases/${test_case}.out"
    
    if [ ! -f "$input_file" ]; then
        echo -e "${YELLOW}Warning: Test case $test_case not found, skipping...${NC}"
        return
    fi
    
    echo -e "${BLUE}Testing case $test_case...${NC}"
    
    # Get graph size for reference
    local vertices=$(head -n 1 "$input_file" | cut -d' ' -f1)
    local edges=$(head -n 1 "$input_file" | cut -d' ' -f2)
    echo "  Graph: $vertices vertices, $edges edges"
    
    # Test serial version
    echo "  Running serial version..."
    local serial_output="output_serial_${test_case}.txt"
    local serial_time_output="time_serial_${test_case}.txt"
    
    /usr/bin/time -f "%e" -o "$serial_time_output" ./apsp_serial "$input_file" > "$serial_output" 2>/dev/null
    local serial_exit_code=$?
    local serial_time=$(cat "$serial_time_output" 2>/dev/null || echo "N/A")
    
    # Test GPU version
    echo "  Running GPU version..."
    local gpu_output="output_gpu_${test_case}.txt"
    local gpu_time_output="time_gpu_${test_case}.txt"
    
    /usr/bin/time -f "%e" -o "$gpu_time_output" ./apsp "$input_file" > "$gpu_output" 2>/dev/null
    local gpu_exit_code=$?
    local gpu_time=$(cat "$gpu_time_output" 2>/dev/null || echo "N/A")
    
    # Verify correctness
    local serial_correct="UNKNOWN"
    local gpu_correct="UNKNOWN"
    
    if [ $serial_exit_code -eq 0 ] && [ -f "$serial_output" ]; then
        if python3 verify.py "$serial_output" "$expected_output" >/dev/null 2>&1; then
            serial_correct="PASS"
        else
            serial_correct="FAIL"
        fi
    else
        serial_correct="ERROR"
    fi
    
    if [ $gpu_exit_code -eq 0 ] && [ -f "$gpu_output" ]; then
        if python3 verify.py "$gpu_output" "$expected_output" >/dev/null 2>&1; then
            gpu_correct="PASS"
        else
            gpu_correct="FAIL"
        fi
    else
        gpu_correct="ERROR"
    fi
    
    # Calculate speedup
    local speedup="N/A"
    if [[ "$serial_time" != "N/A" && "$gpu_time" != "N/A" && "$gpu_time" != "0" ]]; then
        speedup=$(echo "scale=2; $serial_time / $gpu_time" | bc -l 2>/dev/null || echo "N/A")
    fi
    
    # Display results
    printf "  %-12s %-10s %-10s %-10s\n" "Version" "Time(s)" "Correct" "Speedup"
    printf "  %-12s %-10s %-10s %-10s\n" "--------" "-------" "-------" "-------"
    printf "  %-12s %-10s %-10s %-10s\n" "Serial" "$serial_time" "$serial_correct" "1.00x"
    printf "  %-12s %-10s %-10s %-10s\n" "GPU" "$gpu_time" "$gpu_correct" "${speedup}x"
    echo
    
    # Clean up temporary files
    rm -f "$serial_output" "$gpu_output" "$serial_time_output" "$gpu_time_output"
}

# Function to run comprehensive performance analysis
run_comprehensive_test() {
    echo -e "${YELLOW}=== Comprehensive Performance Analysis ===${NC}"
    echo
    
    local total_serial_time=0
    local total_gpu_time=0
    local valid_tests=0
    
    for test_case in "${TEST_CASES[@]}"; do
        local input_file="testcases/${test_case}.in"
        
        if [ ! -f "$input_file" ]; then
            continue
        fi
        
        echo -e "${BLUE}Analyzing test case $test_case...${NC}"
        
        # Run multiple iterations for more accurate timing
        local iterations=3
        local serial_times=()
        local gpu_times=()
        
        for ((i=1; i<=iterations; i++)); do
            # Serial timing
            local serial_time_file="temp_serial_time.txt"
            /usr/bin/time -f "%e" -o "$serial_time_file" ./apsp_serial "$input_file" >/dev/null 2>&1
            if [ -f "$serial_time_file" ]; then
                serial_times+=($(cat "$serial_time_file"))
            fi
            
            # GPU timing
            local gpu_time_file="temp_gpu_time.txt"
            /usr/bin/time -f "%e" -o "$gpu_time_file" ./apsp "$input_file" >/dev/null 2>&1
            if [ -f "$gpu_time_file" ]; then
                gpu_times+=($(cat "$gpu_time_file"))
            fi
            
            rm -f "$serial_time_file" "$gpu_time_file"
        done
        
        # Calculate average times
        if [ ${#serial_times[@]} -gt 0 ] && [ ${#gpu_times[@]} -gt 0 ]; then
            local avg_serial=$(echo "${serial_times[@]}" | tr ' ' '\n' | awk '{sum+=$1} END {print sum/NR}')
            local avg_gpu=$(echo "${gpu_times[@]}" | tr ' ' '\n' | awk '{sum+=$1} END {print sum/NR}')
            
            total_serial_time=$(echo "$total_serial_time + $avg_serial" | bc -l)
            total_gpu_time=$(echo "$total_gpu_time + $avg_gpu" | bc -l)
            valid_tests=$((valid_tests + 1))
            
            local speedup=$(echo "scale=2; $avg_serial / $avg_gpu" | bc -l 2>/dev/null || echo "N/A")
            
            printf "  Test %2d: Serial=%.3fs, GPU=%.3fs, Speedup=%.2fx\n" "$test_case" "$avg_serial" "$avg_gpu" "$speedup"
        fi
    done
    
    echo
    echo -e "${GREEN}=== Summary ===${NC}"
    if [ $valid_tests -gt 0 ]; then
        local overall_speedup=$(echo "scale=2; $total_serial_time / $total_gpu_time" | bc -l 2>/dev/null || echo "N/A")
        printf "Total Serial Time: %.3fs\n" "$total_serial_time"
        printf "Total GPU Time: %.3fs\n" "$total_gpu_time"
        printf "Overall Speedup: %.2fx\n" "$overall_speedup"
        printf "Tests Analyzed: %d\n" "$valid_tests"
    else
        echo "No valid test results obtained."
    fi
}

# Main execution
echo -e "${YELLOW}Running individual test cases...${NC}"
echo

for test_case in "${TEST_CASES[@]}"; do
    run_performance_test "$test_case"
done

echo
run_comprehensive_test

echo
echo -e "${GREEN}Performance comparison complete!${NC}"
