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

PYTHON_SCRIPT="$SCRIPT_DIR/python/benchmark_h5py.py"

if [ ! -f "$PYTHON_SCRIPT" ]; then
    echo "Error: Python benchmark script not found: $PYTHON_SCRIPT" >&2
    exit 1
fi

if [ ! -f "$HDF5_FILE" ]; then
    echo "Error: HDF5 file not found: $HDF5_FILE" >&2
    exit 1
fi

if command -v uv >/dev/null 2>&1; then
    RUNNER=(uv run python3)
else
    RUNNER=(python3)
fi

if [ -n "$TIMESTAMP" ]; then
    "${RUNNER[@]}" "$PYTHON_SCRIPT" \
        --test "$MODE" \
        --file "$HDF5_FILE" \
        --csv "$CSV_FILE" \
        --dataset "$DATASET" \
        --timestamp "$TIMESTAMP"
else
    "${RUNNER[@]}" "$PYTHON_SCRIPT" \
        --test "$MODE" \
        --file "$HDF5_FILE" \
        --csv "$CSV_FILE" \
        --dataset "$DATASET"
fi
