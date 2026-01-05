package com.benchmark;

import hdf.hdf5lib.H5;
import hdf.hdf5lib.HDF5Constants;
import hdf.hdf5lib.exceptions.HDF5Exception;

import java.io.BufferedWriter;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.time.Instant;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

public class HDF5Benchmark {
    private static final String[] CSV_HEADER = {
        "timestamp", "test", "impl", "file", "dataset", "seconds", "mb_s", "value"
    };

    public static void main(String[] args) {
        Args parsed = Args.parse(args);
        if (!parsed.valid) {
            System.err.println("Usage: --test <read|compute-avg> --file <hdf5_file> --csv <csv_file> --dataset <name> [...]");
            System.exit(1);
        }

        try {
            run(parsed);
        } catch (Exception ex) {
            System.err.println("Error: " + ex.getMessage());
            System.exit(1);
        }
    }

    private static void run(Args args) throws Exception {
        Path csvPath = Path.of(args.csvFile);
        ensureCsv(csvPath);

        String timestamp = args.timestamp;
        if (timestamp == null || timestamp.isEmpty()) {
            timestamp = DateTimeFormatter.ISO_INSTANT.format(
                Instant.now().truncatedTo(ChronoUnit.SECONDS).atOffset(ZoneOffset.UTC)
            );
        }

        long fileId = H5.H5Fopen(args.hdf5File, HDF5Constants.H5F_ACC_RDONLY, HDF5Constants.H5P_DEFAULT);
        if (fileId < 0) {
            throw new IllegalStateException("failed to open HDF5 file: " + args.hdf5File);
        }

        try {
            for (String datasetName : args.datasets) {
                BenchmarkResult result = benchmarkDataset(fileId, datasetName, args.test);
                appendCsvRow(csvPath, timestamp, args.test, args.impl, args.hdf5File, datasetName, result);
            }
        } finally {
            H5.H5Fclose(fileId);
        }
    }

    private static BenchmarkResult benchmarkDataset(long fileId, String datasetName, String test)
        throws HDF5Exception {
        long datasetId = H5.H5Dopen(fileId, datasetName, HDF5Constants.H5P_DEFAULT);
        if (datasetId < 0) {
            throw new HDF5Exception("failed to open dataset: " + datasetName);
        }

        long dataspaceId = -1;
        long datatypeId = -1;

        try {
            dataspaceId = H5.H5Dget_space(datasetId);
            if (dataspaceId < 0) {
                throw new HDF5Exception("failed to get dataspace for dataset: " + datasetName);
            }

            int rank = H5.H5Sget_simple_extent_ndims(dataspaceId);
            long[] dims = new long[rank];
            long[] maxDims = new long[rank];
            H5.H5Sget_simple_extent_dims(dataspaceId, dims, maxDims);

            datatypeId = H5.H5Dget_type(datasetId);
            int typeSize = (int) H5.H5Tget_size(datatypeId);

            long totalElements = 1;
            for (long dim : dims) {
                totalElements *= dim;
            }

            if (totalElements > Integer.MAX_VALUE) {
                throw new IllegalStateException("dataset too large for JVM array: " + datasetName);
            }

            long totalBytes = totalElements * typeSize;
            int elements = (int) totalElements;

            double[] data = null;
            float[] floatData = null;

            long startTime = System.nanoTime();
            if (typeSize == 8) {
                data = new double[elements];
                H5.H5Dread_double(datasetId, datatypeId, HDF5Constants.H5S_ALL,
                    HDF5Constants.H5S_ALL, HDF5Constants.H5P_DEFAULT, data);
            } else if (typeSize == 4) {
                floatData = new float[elements];
                H5.H5Dread_float(datasetId, datatypeId, HDF5Constants.H5S_ALL,
                    HDF5Constants.H5S_ALL, HDF5Constants.H5P_DEFAULT, floatData);
            } else {
                data = new double[elements];
                H5.H5Dread_double(datasetId, datatypeId, HDF5Constants.H5S_ALL,
                    HDF5Constants.H5S_ALL, HDF5Constants.H5P_DEFAULT, data);
            }

            double value = 0.0;
            if ("compute-avg".equals(test)) {
                if (data != null) {
                    value = mean(data);
                } else if (floatData != null) {
                    value = mean(floatData);
                }
            }

            long endTime = System.nanoTime();
            double seconds = (endTime - startTime) / 1_000_000_000.0;
            double mbPerSecond = seconds > 0
                ? (totalBytes / seconds) / (1024.0 * 1024.0)
                : 0.0;

            return new BenchmarkResult(seconds, mbPerSecond, "compute-avg".equals(test) ? value : null);
        } finally {
            if (datatypeId >= 0) {
                H5.H5Tclose(datatypeId);
            }
            if (dataspaceId >= 0) {
                H5.H5Sclose(dataspaceId);
            }
            H5.H5Dclose(datasetId);
        }
    }

    private static double mean(double[] data) {
        if (data.length == 0) {
            return 0.0;
        }
        double sum = 0.0;
        for (double v : data) {
            sum += v;
        }
        return sum / data.length;
    }

    private static double mean(float[] data) {
        if (data.length == 0) {
            return 0.0;
        }
        double sum = 0.0;
        for (float v : data) {
            sum += v;
        }
        return sum / data.length;
    }

    private static void ensureCsv(Path path) throws Exception {
        Path parent = path.getParent();
        if (parent != null) {
            Files.createDirectories(parent);
        }

        if (Files.exists(path) && Files.size(path) > 0) {
            return;
        }

        try (BufferedWriter writer = Files.newBufferedWriter(
            path, StandardOpenOption.CREATE, StandardOpenOption.APPEND)) {
            writer.write(String.join(",", CSV_HEADER));
            writer.newLine();
        }
    }

    private static void appendCsvRow(Path path, String timestamp, String test, String impl,
                                     String file, String dataset, BenchmarkResult result)
        throws Exception {
        String value = result.value == null ? "" : formatValue(result.value);
        String row = String.join(",",
            timestamp,
            test,
            impl,
            file,
            dataset,
            formatValue(result.seconds, 6),
            formatValue(result.mbPerSecond, 2),
            value
        );

        try (BufferedWriter writer = Files.newBufferedWriter(
            path, StandardOpenOption.CREATE, StandardOpenOption.APPEND)) {
            writer.write(row);
            writer.newLine();
        }
    }

    private static String formatValue(double value) {
        return formatValue(value, 10);
    }

    private static String formatValue(double value, int precision) {
        return String.format(Locale.US, "%." + precision + "f", value);
    }

    private static class BenchmarkResult {
        final double seconds;
        final double mbPerSecond;
        final Double value;

        BenchmarkResult(double seconds, double mbPerSecond, Double value) {
            this.seconds = seconds;
            this.mbPerSecond = mbPerSecond;
            this.value = value;
        }
    }

    private static class Args {
        final String test;
        final String hdf5File;
        final String csvFile;
        final String impl;
        final String timestamp;
        final List<String> datasets;
        final boolean valid;

        private Args(String test, String hdf5File, String csvFile, String impl,
                     String timestamp, List<String> datasets, boolean valid) {
            this.test = test;
            this.hdf5File = hdf5File;
            this.csvFile = csvFile;
            this.impl = impl;
            this.timestamp = timestamp;
            this.datasets = datasets;
            this.valid = valid;
        }

        static Args parse(String[] args) {
            String test = "read";
            String file = null;
            String csv = null;
            String impl = "java-jni";
            String timestamp = null;
            List<String> datasets = new ArrayList<>();

            for (int i = 0; i < args.length; i++) {
                String arg = args[i];
                switch (arg) {
                    case "--test":
                        if (i + 1 < args.length) {
                            test = args[++i];
                        }
                        break;
                    case "--file":
                        if (i + 1 < args.length) {
                            file = args[++i];
                        }
                        break;
                    case "--csv":
                        if (i + 1 < args.length) {
                            csv = args[++i];
                        }
                        break;
                    case "--dataset":
                        if (i + 1 < args.length) {
                            datasets.add(args[++i]);
                        }
                        break;
                    case "--impl":
                        if (i + 1 < args.length) {
                            impl = args[++i];
                        }
                        break;
                    case "--timestamp":
                        if (i + 1 < args.length) {
                            timestamp = args[++i];
                        }
                        break;
                    default:
                        datasets.add(arg);
                        break;
                }
            }

            boolean valid = file != null && csv != null && !datasets.isEmpty()
                && ("read".equals(test) || "compute-avg".equals(test));
            return new Args(test, file, csv, impl, timestamp, datasets, valid);
        }
    }
}
