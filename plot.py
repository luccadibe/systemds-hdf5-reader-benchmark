import argparse
import os
import sys

import pandas as pd
import seaborn as sns
from matplotlib import pyplot as plt


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", default="results/benchmarks.csv")
    parser.add_argument("--out-dir", default="results")
    return parser.parse_args()


def load_data(path):
    if not os.path.exists(path):
        raise FileNotFoundError(f"CSV not found: {path}")
    data = pd.read_csv(path)
    for col in ["test", "impl", "file", "dataset"]:
        if col in data.columns:
            data[col] = data[col].astype(str).str.strip()
    for col in ["seconds", "mb_s", "value"]:
        if col in data.columns:
            data[col] = pd.to_numeric(data[col], errors="coerce")
    return data


def plot_metric(data, metric, out_dir):
    filtered = data.dropna(subset=[metric])
    if filtered.empty:
        return

    datasets = sorted(filtered["dataset"].dropna().unique())
    impls = sorted(filtered["impl"].dropna().unique())
    tests = sorted(filtered["test"].dropna().unique())

    sns.set_theme(style="whitegrid")
    plot = sns.catplot(
        data=filtered,
        x="dataset",
        y=metric,
        hue="impl",
        col="test" if len(tests) > 1 else None,
        order=datasets or None,
        hue_order=impls or None,
        kind="bar",
        height=4,
        aspect=1.2,
        sharey=False,
    )
    plot.set_axis_labels("dataset", metric)
    plot.fig.suptitle(f"{metric} by dataset and implementation", y=1.05)

    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, f"plot_{metric}.png")
    plot.fig.savefig(out_path, dpi=150, bbox_inches="tight")
    plt.close(plot.fig)


def main():
    args = parse_args()
    try:
        data = load_data(args.csv)
    except Exception as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    plot_metric(data, "mb_s", args.out_dir)
    plot_metric(data, "seconds", args.out_dir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
