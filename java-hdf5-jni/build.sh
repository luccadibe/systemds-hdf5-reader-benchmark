#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

JAVA21_HOME="${JAVA21_HOME:-}"
if [ -z "$JAVA21_HOME" ]; then
    if [ -d "/usr/lib/jvm/java-21-openjdk-amd64" ]; then
        JAVA21_HOME="/usr/lib/jvm/java-21-openjdk-amd64"
    else
        JAVA21_HOME=$(find /usr/lib/jvm -name "java-21-openjdk-amd64" -type d 2>/dev/null | head -1)
    fi
fi

if [ -z "$JAVA21_HOME" ] || [ ! -x "$JAVA21_HOME/bin/java" ]; then
    echo "Error: Java 21 not found. Set JAVA21_HOME or install openjdk-21-jdk." >&2
    exit 1
fi

if ! command -v mvn >/dev/null 2>&1; then
    echo "Error: Maven is not installed." >&2
    exit 1
fi

export JAVA_HOME="$JAVA21_HOME"
export PATH="$JAVA21_HOME/bin:$PATH"

mvn clean package
