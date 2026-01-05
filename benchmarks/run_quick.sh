#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

"$SCRIPT_DIR/run_all.sh" "$@"

CSV_FILE="$REPO_DIR/results/benchmarks.csv"
if [ -f "$CSV_FILE" ]; then
    tail -n 12 "$CSV_FILE"
fi
