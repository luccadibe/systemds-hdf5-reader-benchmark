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

SYSTEMDS_SCRIPT="$REPO_DIR/systemds.sh"
DML_DIR="$SCRIPT_DIR/dml"
case "$MODE" in
    read) DML_SCRIPT="$DML_DIR/read.dml" ;;
    compute-avg) DML_SCRIPT="$DML_DIR/compute_avg.dml" ;;
    *)
        echo "Error: invalid mode: $MODE" >&2
        exit 1
        ;;
esac

if [ ! -f "$SYSTEMDS_SCRIPT" ]; then
    echo "Error: systemds.sh not found: $SYSTEMDS_SCRIPT" >&2
    exit 1
fi

if [ ! -f "$DML_SCRIPT" ]; then
    echo "Error: DML script not found: $DML_SCRIPT" >&2
    exit 1
fi

if [ ! -f "$HDF5_FILE" ]; then
    echo "Error: HDF5 file not found: $HDF5_FILE" >&2
    exit 1
fi

TEMP_OUTPUT="$(mktemp)"
trap 'rm -f "$TEMP_OUTPUT"' EXIT

if command -v uv >/dev/null 2>&1; then
    PYTHON_RUNNER=(uv run python3)
else
    PYTHON_RUNNER=(python3)
fi

set +e
output=$(
    "$SYSTEMDS_SCRIPT" \
        -f "$DML_SCRIPT" \
        -exec singlenode \
        -stats \
        -nvargs HDF5_FILE="$HDF5_FILE" DATASET_NAME="$DATASET" OUTPUT_FILE="$TEMP_OUTPUT" \
        2>&1
)
exit_code=$?
set -e

if [ $exit_code -ne 0 ]; then
    echo "$output" >&2
    exit $exit_code
fi

# Extract "Total execution time: X.XXX sec." from SystemDS stats output
ELAPSED_SECONDS=$(echo "$output" | grep -E "Total execution time:" | sed -E 's/.*Total execution time:[[:space:]]*([0-9]+\.[0-9]+)[[:space:]]*sec\..*/\1/')

if [ -z "$ELAPSED_SECONDS" ]; then
    echo "Error: Could not extract execution time from SystemDS output" >&2
    echo "$output" >&2
    exit 1
fi

if [ -z "$TIMESTAMP" ]; then
    TIMESTAMP=$("${PYTHON_RUNNER[@]}" - <<'PY'
from datetime import datetime, timezone
ts = datetime.now(timezone.utc).isoformat(timespec="seconds")
print(ts.replace("+00:00", "Z"))
PY
)
fi

DATASET_BYTES=$(HDF5_FILE="$HDF5_FILE" DATASET="$DATASET" "${PYTHON_RUNNER[@]}" - <<'PY'
import os
import h5py

path = os.environ["HDF5_FILE"]
dataset = os.environ["DATASET"]
with h5py.File(path, "r") as handle:
    data = handle[dataset]
    print(int(data.size) * data.dtype.itemsize)
PY
)

MB_S=$(BYTES="$DATASET_BYTES" SECONDS="$ELAPSED_SECONDS" "${PYTHON_RUNNER[@]}" - <<'PY'
import os
bytes_ = float(os.environ["BYTES"])
seconds = float(os.environ["SECONDS"])
if seconds <= 0:
    print("0.00")
else:
    print(f"{(bytes_ / seconds) / (1024.0 * 1024.0):.2f}")
PY
)

VALUE=""
if [ "$MODE" = "compute-avg" ]; then
    VALUE=$(tail -n 1 "$TEMP_OUTPUT" | tr -d '[:space:]')
fi

mkdir -p "$(dirname "$CSV_FILE")"
if [ ! -f "$CSV_FILE" ] || [ ! -s "$CSV_FILE" ]; then
    echo "timestamp,test,impl,file,dataset,seconds,mb_s,value" >> "$CSV_FILE"
fi

echo "$TIMESTAMP,$MODE,systemds,$HDF5_FILE,$DATASET,$ELAPSED_SECONDS,$MB_S,$VALUE" >> "$CSV_FILE"
