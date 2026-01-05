#!/bin/bash

# Disk Speed Benchmark Script
# Tests sequential read/write speeds to establish baseline for HDF5 loading

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
TEST_FILE="disk_benchmark_test.tmp"
TEST_SIZE_GB=5  # Size of test file in GB (adjust if needed)
BLOCK_SIZE="1M"
ITERATIONS=3  # Number of iterations for averaging

# Function to format bytes
format_size() {
    local bytes=$1
    if [ $bytes -ge 1073741824 ]; then
        echo "$(echo "scale=2; $bytes/1073741824" | bc) GB"
    elif [ $bytes -ge 1048576 ]; then
        echo "$(echo "scale=2; $bytes/1048576" | bc) MB"
    elif [ $bytes -ge 1024 ]; then
        echo "$(echo "scale=2; $bytes/1024" | bc) KB"
    else
        echo "${bytes} B"
    fi
}

# Function to format speed
format_speed() {
    local speed=$1
    if [ $(echo "$speed >= 1073741824" | bc) -eq 1 ]; then
        echo "$(echo "scale=2; $speed/1073741824" | bc) GB/s"
    elif [ $(echo "$speed >= 1048576" | bc) -eq 1 ]; then
        echo "$(echo "scale=2; $speed/1048576" | bc) MB/s"
    elif [ $(echo "$speed >= 1024" | bc) -eq 1 ]; then
        echo "$(echo "scale=2; $speed/1024" | bc) KB/s"
    else
        echo "${speed} B/s"
    fi
}

# Get current directory
CURRENT_DIR=$(pwd)
TEST_PATH="${CURRENT_DIR}/${TEST_FILE}"

echo "=========================================="
echo "Disk Speed Benchmark"
echo "=========================================="
echo "Test directory: ${CURRENT_DIR}"
echo "Test file: ${TEST_PATH}"
echo "Test size: ${TEST_SIZE_GB} GB"
echo "Block size: ${BLOCK_SIZE}"
echo "Iterations: ${ITERATIONS}"
echo "=========================================="
echo ""

# Check if bc is available
if ! command -v bc &> /dev/null; then
    echo -e "${YELLOW}Warning: 'bc' not found. Installing...${NC}"
    sudo apt-get update && sudo apt-get install -y bc
fi

# Get disk info
echo "Disk Information:"
echo "-----------------"
df -h "${CURRENT_DIR}" | head -2
echo ""

# Cleanup function
cleanup() {
    echo ""
    echo "Cleaning up..."
    if [ -f "${TEST_PATH}" ]; then
        rm -f "${TEST_PATH}"
        echo "Test file removed."
    fi
}

# Set trap to cleanup on exit
trap cleanup EXIT

# Sequential Write Test
echo "=========================================="
echo "Sequential Write Test"
echo "=========================================="
write_speeds=()
for i in $(seq 1 $ITERATIONS); do
    echo -n "  Iteration $i/$ITERATIONS: "
    
    # Clear cache before write test
    sync
    if [ -w /proc/sys/vm/drop_caches ]; then
        echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null 2>&1 || true
    fi
    
    start_time=$(date +%s.%N)
    dd if=/dev/zero of="${TEST_PATH}" bs=${BLOCK_SIZE} count=$((TEST_SIZE_GB * 1024)) oflag=direct 2>&1 | tail -1
    end_time=$(date +%s.%N)
    
    # Calculate speed
    elapsed=$(echo "$end_time - $start_time" | bc)
    test_size_bytes=$((TEST_SIZE_GB * 1024 * 1024 * 1024))
    speed=$(echo "scale=2; $test_size_bytes / $elapsed" | bc)
    write_speeds+=($speed)
    
    echo "    Speed: $(format_speed $speed)"
    sync
    sleep 1
done

# Calculate average write speed
total_write=0
for speed in "${write_speeds[@]}"; do
    total_write=$(echo "$total_write + $speed" | bc)
done
avg_write=$(echo "scale=2; $total_write / ${#write_speeds[@]}" | bc)
echo ""
echo -e "${GREEN}Average Write Speed: $(format_speed $avg_write)${NC}"
echo ""

# Sequential Read Test (Direct I/O - bypasses page cache)
echo "=========================================="
echo "Sequential Read Test (Direct I/O)"
echo "=========================================="
echo "Note: Direct I/O bypasses OS page cache (raw disk speed)"
read_speeds_direct=()
for i in $(seq 1 $ITERATIONS); do
    echo -n "  Iteration $i/$ITERATIONS: "
    
    # Clear cache before read test
    sync
    if [ -w /proc/sys/vm/drop_caches ]; then
        echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null 2>&1 || true
    fi
    
    start_time=$(date +%s.%N)
    dd if="${TEST_PATH}" of=/dev/null bs=${BLOCK_SIZE} iflag=direct 2>&1 | tail -1
    end_time=$(date +%s.%N)
    
    # Calculate speed
    elapsed=$(echo "$end_time - $start_time" | bc)
    test_size_bytes=$((TEST_SIZE_GB * 1024 * 1024 * 1024))
    speed=$(echo "scale=2; $test_size_bytes / $elapsed" | bc)
    read_speeds_direct+=($speed)
    
    echo "    Speed: $(format_speed $speed)"
    sleep 1
done

# Calculate average direct read speed
total_read_direct=0
for speed in "${read_speeds_direct[@]}"; do
    total_read_direct=$(echo "$total_read_direct + $speed" | bc)
done
avg_read_direct=$(echo "scale=2; $total_read_direct / ${#read_speeds_direct[@]}" | bc)
echo ""
echo -e "${GREEN}Average Read Speed (Direct I/O): $(format_speed $avg_read_direct)${NC}"
echo ""

# Sequential Read Test (Buffered I/O - uses page cache like h5py)
echo "=========================================="
echo "Sequential Read Test (Buffered I/O - Cold Cache)"
echo "=========================================="
echo "Note: Buffered I/O uses OS page cache (comparable to h5py)"
echo "      Measuring first read only (cold cache) for fair comparison"
read_speeds_buffered=()
for i in $(seq 1 $ITERATIONS); do
    echo -n "  Iteration $i/$ITERATIONS: "
    
    # Clear cache before read test - CRITICAL for cold cache measurement
    sync
    if [ -w /proc/sys/vm/drop_caches ]; then
        echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null 2>&1 || true
    else
        echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null 2>&1 || true
    fi
    
    # Wait a moment to ensure cache is cleared
    sleep 0.5
    
    start_time=$(date +%s.%N)
    # No iflag=direct, so it uses normal buffered I/O
    # File will be cached during read, but we measure the cold cache read
    dd if="${TEST_PATH}" of=/dev/null bs=${BLOCK_SIZE} 2>&1 | tail -1
    end_time=$(date +%s.%N)
    
    # Calculate speed
    elapsed=$(echo "$end_time - $start_time" | bc)
    test_size_bytes=$((TEST_SIZE_GB * 1024 * 1024 * 1024))
    speed=$(echo "scale=2; $test_size_bytes / $elapsed" | bc)
    read_speeds_buffered+=($speed)
    
    echo "    Speed: $(format_speed $speed)"
    
    # Clear cache again before next iteration to ensure cold cache
    sync
    if [ -w /proc/sys/vm/drop_caches ]; then
        echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null 2>&1 || true
    else
        echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null 2>&1 || true
    fi
    sleep 1
done

# Calculate average buffered read speed (cold cache)
total_read_buffered=0
for speed in "${read_speeds_buffered[@]}"; do
    total_read_buffered=$(echo "$total_read_buffered + $speed" | bc)
done
avg_read_buffered=$(echo "scale=2; $total_read_buffered / ${#read_speeds_buffered[@]}" | bc)
echo ""
echo -e "${GREEN}Average Read Speed (Buffered I/O, Cold Cache): $(format_speed $avg_read_buffered)${NC}"
echo ""

# Use buffered speed for comparison (since h5py uses buffered I/O)
avg_read=$avg_read_buffered

# Summary
echo "=========================================="
echo "Summary"
echo "=========================================="
echo "Sequential Write: $(format_speed $avg_write)"
echo "Sequential Read (Direct I/O):  $(format_speed $avg_read_direct)"
echo "Sequential Read (Buffered I/O):  $(format_speed $avg_read_buffered)"
echo ""
echo "Note: Direct I/O bypasses OS page cache (raw disk speed)"
echo "      Buffered I/O uses page cache (comparable to h5py/SystemDS)"
echo ""
echo "      IMPORTANT: HDF5 loading speeds should be compared against"
echo "      Buffered I/O (Cold Cache) speed, NOT Direct I/O speed."
echo "      This is because HDF5 libraries use normal file I/O with"
echo "      OS page cache, not direct I/O."
echo ""
echo "      HDF5 speeds will typically be slower than buffered I/O due to:"
echo "      - File structure/metadata parsing overhead"
echo "      - Compression/decompression (if used)"
echo "      - Data type conversions"
echo "      - Non-sequential access patterns"
echo ""
echo "      If HDF5 reads are faster than buffered I/O, the file may"
echo "      be partially cached or there's a measurement issue."
echo "=========================================="

