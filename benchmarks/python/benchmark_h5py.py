import argparse
import csv
import os
import sys
import time
from datetime import datetime, timezone

import h5py
import numpy as np


CSV_HEADER = ["timestamp", "test", "impl", "file", "dataset", "seconds", "mb_s", "value"]


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--test", choices=["read", "compute-avg"], default="read")
    parser.add_argument("--file", required=True)
    parser.add_argument("--csv", required=True)
    parser.add_argument("--dataset", action="append", required=True)
    parser.add_argument("--impl", default="h5py")
    parser.add_argument("--timestamp", default="")
    return parser.parse_args()


def iso_timestamp(value):
    if value:
        return value
    ts = datetime.now(timezone.utc).isoformat(timespec="seconds")
    return ts.replace("+00:00", "Z")


def ensure_csv(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if not os.path.exists(path) or os.path.getsize(path) == 0:
        with open(path, "w", newline="") as handle:
            writer = csv.writer(handle)
            writer.writerow(CSV_HEADER)


def append_csv_row(path, row):
    with open(path, "a", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(row)


def run_dataset(hdf5_file, dataset_name, test):
    with h5py.File(hdf5_file, "r") as handle:
        if dataset_name not in handle:
            raise KeyError(f"dataset not found: {dataset_name}")
        dataset = handle[dataset_name]
        total_bytes = int(dataset.size) * dataset.dtype.itemsize

        start = time.perf_counter()
        data = dataset[()]
        value = ""
        if test == "compute-avg":
            value = float(np.mean(data)) if data.size else 0.0
        end = time.perf_counter()

    seconds = end - start
    mb_s = (total_bytes / seconds) / (1024.0 * 1024.0) if seconds > 0 else 0.0
    return seconds, mb_s, value


def main():
    args = parse_args()
    if not os.path.exists(args.file):
        print(f"Error: HDF5 file not found: {args.file}", file=sys.stderr)
        return 1

    ensure_csv(args.csv)
    timestamp = iso_timestamp(args.timestamp)

    for dataset in args.dataset:
        try:
            seconds, mb_s, value = run_dataset(args.file, dataset, args.test)
        except Exception as exc:
            print(f"Error: {exc}", file=sys.stderr)
            return 1

        row = [
            timestamp,
            args.test,
            args.impl,
            args.file,
            dataset,
            f"{seconds:.6f}",
            f"{mb_s:.2f}",
            "" if value == "" else format(value, ".10g"),
        ]
        append_csv_row(args.csv, row)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
