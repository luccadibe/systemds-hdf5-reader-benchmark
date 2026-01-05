# HDF5 Java JNI Benchmark

This benchmark uses the `hdf5-java-jni` dependency (JNI implementation) to read
HDF5 datasets and write timing results into the shared CSV file.

## Requirements

- Java 21
- Maven 3.6+
- HDF5 native library (`libhdf5_java.so`)

## HDF5 Native Library Setup

The HDF5 Java JNI library requires the native library `libhdf5_java.so` to be available.
This library is not included in the Maven dependency and must be obtained separately.

### Download Pre-built HDF5

1. Download HDF5 2.0.0 from the [HDF Group website](https://www.hdfgroup.org/downloads/hdf5/)
   or [GitHub releases](https://github.com/HDFGroup/hdf5/releases)

2. Extract the archive and locate `libhdf5_java.so` (usually in `HDF_Group/HDF5/2.0.0/lib/`)

3. Set the `HDF5_LIB_DIR` environment variable to point to the directory containing the library:
   ```bash
   export HDF5_LIB_DIR=/path/to/hdf5/lib
   ```

## Build

```bash
bash build.sh
```

The  JAR will be created at:

```
target/hdf5-benchmark-jni-1.0.0-jar-with-dependencies.jar
```

## Usage

The benchmark is invoked by `benchmarks/run_java.sh`. You can also run it directly:

```bash
java -Xmx56g -Xms56g -jar target/hdf5-benchmark-jni-1.0.0-jar-with-dependencies.jar \
  --test read \
  --file /path/to/validation.h5 \
  --csv /path/to/results/benchmarks.csv \
  --dataset sen1
```
