#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

MODE="${1:-read}"
shift || true

if [ "$MODE" != "read" ] && [ "$MODE" != "compute-avg" ]; then
    echo "Usage: $0 [read|compute-avg] [dataset ...]" >&2
    exit 1
fi

if [ "$#" -gt 0 ]; then
    DATASETS=("$@")
else
    DATASETS=("sen1" "sen2" "label")
fi

HDF5_FILE="$REPO_DIR/data/validation.h5"
CSV_FILE="$REPO_DIR/results/benchmarks.csv"
TIMESTAMP=$(python3 - <<'PY'
from datetime import datetime, timezone
ts = datetime.now(timezone.utc).isoformat(timespec="seconds")
print(ts.replace("+00:00", "Z"))
PY
)

clear_cache() {
    sync
    if [ -w /proc/sys/vm/drop_caches ]; then
        echo 3 > /proc/sys/vm/drop_caches
    else
        sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'
    fi
}

for dataset in "${DATASETS[@]}"; do
    clear_cache
    "$SCRIPT_DIR/run_systemds.sh" "$MODE" "$dataset" "$HDF5_FILE" "$CSV_FILE" "$TIMESTAMP"
    clear_cache
    "$SCRIPT_DIR/run_h5py.sh" "$MODE" "$dataset" "$HDF5_FILE" "$CSV_FILE" "$TIMESTAMP"
    clear_cache
    "$SCRIPT_DIR/run_java.sh" "$MODE" "$dataset" "$HDF5_FILE" "$CSV_FILE" "$TIMESTAMP"
done
