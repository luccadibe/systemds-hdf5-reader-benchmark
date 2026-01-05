#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

MODE="${1:-}"
DATASET="${2:-}"
HDF5_FILE="${3:-$REPO_DIR/data/validation.h5}"
CSV_FILE="${4:-$REPO_DIR/results/benchmarks.csv}"
TIMESTAMP="${5:-}"

if [ -z "$MODE" ] || [ -z "$DATASET" ]; then
    echo "Usage: $0 <read|compute-avg> <dataset> [hdf5_file] [csv_file] [timestamp]" >&2
    exit 1
fi

JAVA_DIR="$REPO_DIR/java-hdf5-jni"
JAR_PATH="$JAVA_DIR/target/hdf5-benchmark-jni-1.0.0-jar-with-dependencies.jar"

if [ ! -f "$HDF5_FILE" ]; then
    echo "Error: HDF5 file not found: $HDF5_FILE" >&2
    exit 1
fi

if [ ! -f "$JAR_PATH" ]; then
    echo "Error: Java benchmark jar not found: $JAR_PATH" >&2
    echo "Build it with: (cd $JAVA_DIR && bash build.sh)" >&2
    exit 1
fi

# Find Java 21 (same logic as build.sh)
JAVA21_HOME="${JAVA21_HOME:-}"
if [ -z "$JAVA21_HOME" ]; then
    if [ -d "/usr/lib/jvm/java-21-openjdk-amd64" ]; then
        JAVA21_HOME="/usr/lib/jvm/java-21-openjdk-amd64"
    else
        JAVA21_HOME=$(find /usr/lib/jvm -name "java-21-openjdk-amd64" -type d 2>/dev/null | head -1)
    fi
fi

if [ -z "$JAVA21_HOME" ] || [ ! -x "$JAVA21_HOME/bin/java" ]; then
    echo "Error: Java 21 not found. Set JAVA21_HOME or install openjdk-21-jdk." >&2
    exit 1
fi

JAVA_BIN="$JAVA21_HOME/bin/java"
JAVA_HEAP_OPTS="${JAVA_HEAP_OPTS:--Xmx56g -Xms56g}"
read -r -a JAVA_OPTS <<< "$JAVA_HEAP_OPTS"

# HDF5 native library (libhdf5_java.so) must be provided via HDF5_LIB_DIR
HDF5_LIB_DIR="${HDF5_LIB_DIR:-}"

if [ -z "$HDF5_LIB_DIR" ]; then
    echo "Error: HDF5_LIB_DIR environment variable is not set." >&2
    echo "Please set HDF5_LIB_DIR to the directory containing libhdf5_java.so" >&2
    echo "Example: export HDF5_LIB_DIR=/path/to/hdf5/lib" >&2
    exit 1
fi

if [ ! -f "$HDF5_LIB_DIR/libhdf5_java.so" ]; then
    echo "Error: libhdf5_java.so not found in $HDF5_LIB_DIR" >&2
    echo "Please set HDF5_LIB_DIR to the directory containing libhdf5_java.so" >&2
    exit 1
fi

# Set up library paths
# Add HDF5 library directory to both java.library.path and LD_LIBRARY_PATH
LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}"
LD_LIBRARY_PATH="$HDF5_LIB_DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# Also add system library directories for HDF5 dependencies
if [ -d "/usr/lib/x86_64-linux-gnu" ]; then
    LD_LIBRARY_PATH="/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi
if [ -d "/usr/local/lib" ]; then
    LD_LIBRARY_PATH="/usr/local/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

# Set java.library.path to include HDF5 library directory
JAVA_LIBRARY_PATH="$HDF5_LIB_DIR"
if [ -d "/usr/lib/x86_64-linux-gnu" ]; then
    JAVA_LIBRARY_PATH="$JAVA_LIBRARY_PATH:/usr/lib/x86_64-linux-gnu"
fi
if [ -d "/usr/local/lib" ]; then
    JAVA_LIBRARY_PATH="$JAVA_LIBRARY_PATH:/usr/local/lib"
fi

if [ -n "$TIMESTAMP" ]; then
    LD_LIBRARY_PATH="$LD_LIBRARY_PATH" "$JAVA_BIN" \
        -Djava.library.path="$JAVA_LIBRARY_PATH" \
        "${JAVA_OPTS[@]}" \
        -jar "$JAR_PATH" \
        --test "$MODE" \
        --file "$HDF5_FILE" \
        --csv "$CSV_FILE" \
        --dataset "$DATASET" \
        --timestamp "$TIMESTAMP"
else
    LD_LIBRARY_PATH="$LD_LIBRARY_PATH" "$JAVA_BIN" \
        -Djava.library.path="$JAVA_LIBRARY_PATH" \
        "${JAVA_OPTS[@]}" \
        -jar "$JAR_PATH" \
        --test "$MODE" \
        --file "$HDF5_FILE" \
        --csv "$CSV_FILE" \
        --dataset "$DATASET"
fi
