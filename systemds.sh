#!/bin/bash

# SystemDS execution script with custom JVM settings
# Uses absolute paths to SystemDS jar and lib directory

SYSTEMDS_DIR="${SYSTEMDS_DIR:-$HOME/temp/systemds}"
SYSTEMDS_TARGET="$SYSTEMDS_DIR/target"
SYSTEMDS_JAR="$SYSTEMDS_TARGET/SystemDS.jar"
SYSTEMDS_LIB="$SYSTEMDS_TARGET/lib"
JAVA17_BIN="${JAVA17_BIN:-/usr/lib/jvm/java-17-openjdk-amd64/bin/java}"

# Check if jar exists
if [ ! -f "$SYSTEMDS_JAR" ]; then
    echo "Error: SystemDS.jar not found at $SYSTEMDS_JAR" >&2
    exit 1
fi

# Check if lib directory exists
if [ ! -d "$SYSTEMDS_LIB" ]; then
    echo "Error: lib directory not found at $SYSTEMDS_LIB" >&2
    exit 1
fi

if [ ! -x "$JAVA17_BIN" ]; then
    JAVA17_BIN="$(command -v java || true)"
fi

if [ -z "$JAVA17_BIN" ] || [ ! -x "$JAVA17_BIN" ]; then
    echo "Error: Java 17 binary not found. Set JAVA17_BIN." >&2
    exit 1
fi

"$JAVA17_BIN" \
    --enable-preview \
    --add-modules jdk.incubator.vector \
    -Xmx56g -Xms56g -Xmn28g \
    -Dsysds.hdf5.read.mmap=true \
    -Dsysds.hdf5.read.map.bytes=268435456 \
    -Dsysds.hdf5.read.skip.nnz=true \
    -Dsysds.hdf5.read.parallel.min.bytes=67108864 \
    -Dsysds.hdf5.read.force.dense=true \
    -Dsysds.hdf5.read.trace=true \
    --add-opens=java.base/java.nio=ALL-UNNAMED \
    --add-opens=java.base/java.io=ALL-UNNAMED \
    --add-opens=java.base/java.util=ALL-UNNAMED \
    --add-opens=java.base/java.lang=ALL-UNNAMED \
    --add-opens=java.base/java.lang.ref=ALL-UNNAMED \
    --add-opens=java.base/java.util.concurrent=ALL-UNNAMED \
    --add-opens=java.base/sun.nio.ch=ALL-UNNAMED \
    -cp "$SYSTEMDS_LIB/*:$SYSTEMDS_JAR" \
    org.apache.sysds.api.DMLScript \
    "$@"
