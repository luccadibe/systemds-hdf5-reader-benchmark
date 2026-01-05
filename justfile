default:
    @just --list

data-download url="https://tubcloud.tu-berlin.de/s/HP6LqPBxG2jg5SC/download/validation.h5":
    mkdir -p data
    curl -L "{{url}}" -o data/validation.h5

clear-cache:
    sync
    if [ -w /proc/sys/vm/drop_caches ]; then echo 3 > /proc/sys/vm/drop_caches; else sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'; fi

build-java:
    cd java-hdf5-jni && bash build.sh

run-systemds-read dataset="sen1":
    @just clear-cache
    benchmarks/run_systemds.sh read "{{dataset}}" "data/validation.h5" "results/benchmarks.csv"

run-h5py-read dataset="sen1":
    @just clear-cache
    benchmarks/run_h5py.sh read "{{dataset}}" "data/validation.h5" "results/benchmarks.csv"

run-java-read dataset="sen1":
    @just clear-cache
    benchmarks/run_java.sh read "{{dataset}}" "data/validation.h5" "results/benchmarks.csv"

run-all-read dataset="sen1":
    @just run-systemds-read "{{dataset}}"
    @just run-h5py-read "{{dataset}}"
    @just run-java-read "{{dataset}}"

run-systemds-compute-avg dataset="sen1":
    @just clear-cache
    benchmarks/run_systemds.sh compute-avg "{{dataset}}" "data/validation.h5" "results/benchmarks.csv"

run-h5py-compute-avg dataset="sen1":
    @just clear-cache
    benchmarks/run_h5py.sh compute-avg "{{dataset}}" "data/validation.h5" "results/benchmarks.csv"

run-java-compute-avg dataset="sen1":
    @just clear-cache
    benchmarks/run_java.sh compute-avg "{{dataset}}" "data/validation.h5" "results/benchmarks.csv"

run-all-compute-avg dataset="sen1":
    @just run-systemds-compute-avg "{{dataset}}"
    @just run-h5py-compute-avg "{{dataset}}"
    @just run-java-compute-avg "{{dataset}}"

bench-disk:
    benchmarks/disk.sh

plot:
    uv run plot.py
